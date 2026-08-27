// This file is the designated home for FSRS-related scheduling logic in
// IFRCore. It does NOT import the `FSRS` module — see the note below.
//
// ADAPTATION NOTE (read before changing this file):
// swift-fsrs 5.0.0 (the only version available; tags checked: v4.1.0,
// v5.0.0) publicly exports its data types (`Card`, `Rating`, `CardState`,
// `FSRSParameters`, `ReviewLog`, `RecordLogItem`) but the entire
// computation engine is NOT public:
//   - `FSRS.init(parameters:)` has no `public` modifier -> "'FSRS'
//     initializer is inaccessible due to 'internal' protection level"
//     when called from this package with a plain `import FSRS`.
//   - `FSRS.next(card:now:grade:)`, `FSRSAlgorithm`'s formula methods, and
//     `FSRSDefaults.createEmptyCard` are likewise internal.
// The package's own test target only compiles because it uses
// `@testable import FSRS`. We tried that here too: it compiles under
// `swift build` (Debug) but fails under `swift build -c release` with
// "module 'FSRS' was not compiled for testing" — i.e. it would break the
// app's Release/Archive/TestFlight build (App T9), so it is not a safe
// adaptation for shipped code.
//
// Given that, this file implements the FSRS-5 scheduling formulas
// directly, in pure Swift, using the same default parameter weights
// published by the open-spaced-repetition project (the identical values
// live in swift-fsrs's own, but inaccessible, `FSRSDefaults.defaultW`,
// confirmed by reading its checked-out source). Specifically this mirrors
// the package's `LongTermScheduler` (i.e. `enableShortTerm == false`)
// code path: no separate new/learning/relearning short-interval steps,
// which matches `CardState` having no `state` field — a card is either
// unseen (`reps == 0`) or has been reviewed at least once.
//
// If a future task needs byte-identical output to the upstream engine
// (e.g. to match a reference test vector), the fix is to fork swift-fsrs
// with a small public wrapper around `FSRS`/`FSRSAlgorithm` and point
// Package.swift at that fork — not to import the current release as-is.
import Foundation

public struct Scheduler: Sendable {
    private let desiredRetention: Double
    private let intervalModifier: Double
    private let maximumInterval: Double = 36_500

    /// FSRS-5 default parameter weights, as published by
    /// open-spaced-repetition/fsrs4anki (identical to the values in
    /// swift-fsrs's internal `FSRSDefaults.defaultW`).
    private static let w: [Double] = [
        0.4072, 1.1829, 3.1262, 15.4722, 7.2102, 0.5316, 1.0651, 0.0234, 1.616,
        0.1544, 1.0824, 1.9813, 0.0953, 0.2975, 2.2042, 0.2407, 2.9466, 0.5034,
        0.6567,
    ]
    private static let decay = -0.5
    private static let factor = 19.0 / 81.0

    public init(desiredRetention: Double = 0.9) {
        self.desiredRetention = desiredRetention
        let r = min(max(desiredRetention, 0.0001), 1)
        self.intervalModifier = (pow(r, 1 / Scheduler.decay) - 1) / Scheduler.factor
    }

    public func review(_ state: CardState, grade: Grade, at date: Date) -> CardState {
        let outcomes: [Grade: (stability: Double, difficulty: Double)]

        // `stability`/`difficulty` are public `var`s on CardState (required
        // by the brief), so a caller could in principle hand us `reps > 0`
        // with `stability <= 0` without going through `.new()` or a prior
        // `review()`. Treat that the same as an unseen card rather than
        // feeding 0 into pow(_, negative-exponent) below, which produces
        // +inf/NaN that would otherwise survive the clamps unnoticed.
        if state.reps == 0 || state.stability <= 0 {
            outcomes = Dictionary(uniqueKeysWithValues: Grade.allCases.map { g in
                (g, (stability: Self.initStability(g), difficulty: Self.initDifficulty(g)))
            })
        } else {
            let last = state.lastReview ?? date
            let elapsedDays = max(0, date.timeIntervalSince(last) / 86_400)
            let r = Self.forgettingCurve(elapsedDays: elapsedDays, stability: state.stability)
            outcomes = Dictionary(uniqueKeysWithValues: Grade.allCases.map { g in
                let difficulty = Self.nextDifficulty(d: state.difficulty, grade: g)
                let stability = g == .again
                    ? Self.nextForgetStability(d: state.difficulty, s: state.stability, r: r)
                    : Self.nextRecallStability(d: state.difficulty, s: state.stability, r: r, grade: g)
                return (g, (stability: stability, difficulty: difficulty))
            })
        }

        let intervals = crossOrderedIntervalDays(stabilities: outcomes.mapValues(\.stability))
        let chosen = outcomes[grade]!
        let due = date.addingTimeInterval(Double(intervals[grade]!) * 86_400)

        return CardState(
            questionID: state.questionID,
            stability: chosen.stability,
            difficulty: chosen.difficulty,
            due: due,
            lastReview: date,
            reps: state.reps + 1,
            lapses: state.lapses + (grade == .again && state.reps > 0 ? 1 : 0)
        )
    }

    /// Predicted probability of recall at `date`. Unseen cards score 0.
    public func retrievability(of state: CardState, at date: Date) -> Double {
        guard state.reps > 0, let last = state.lastReview, state.stability > 0 else { return 0 }
        let elapsedDays = max(0, date.timeIntervalSince(last) / 86_400)
        return Self.forgettingCurve(elapsedDays: elapsedDays, stability: state.stability)
    }

    // MARK: - FSRS-5 formulas (see open-spaced-repetition/fsrs4anki wiki:
    // "The Algorithm"). Mirrors swift-fsrs's (inaccessible) FSRSAlgorithm.

    private func intervalDays(forStability s: Double) -> Int {
        let raw = (s * intervalModifier).rounded()
        return Int(min(max(1, raw), maximumInterval))
    }

    /// Applies the upstream LongTermScheduler's cross-grade interval
    /// ordering so again <= hard < good < easy strictly, even when raw
    /// per-grade intervals would tie or invert.
    private func crossOrderedIntervalDays(stabilities: [Grade: Double]) -> [Grade: Int] {
        let again = intervalDays(forStability: stabilities[.again]!)
        let hard = intervalDays(forStability: stabilities[.hard]!)
        let good = intervalDays(forStability: stabilities[.good]!)
        let easy = intervalDays(forStability: stabilities[.easy]!)
        return [
            .again: min(again, hard),
            .hard: max(hard, again + 1),
            .good: max(good, hard + 1),
            .easy: max(easy, good + 1),
        ]
    }

    private static func initStability(_ grade: Grade) -> Double {
        max(w[grade.rawValue - 1], 0.1)
    }

    private static func initDifficulty(_ grade: Grade) -> Double {
        constrainDifficulty(w[4] - exp((Double(grade.rawValue) - 1) * w[5]) + 1)
    }

    private static func nextDifficulty(d: Double, grade: Grade) -> Double {
        let nextD = d - (w[6] * (Double(grade.rawValue) - 3))
        return constrainDifficulty(meanReversion(initValue: initDifficulty(.easy), current: nextD))
    }

    private static func constrainDifficulty(_ r: Double) -> Double {
        min(max(r, 1), 10)
    }

    private static func meanReversion(initValue: Double, current: Double) -> Double {
        w[7] * initValue + (1 - w[7]) * current
    }

    private static func nextRecallStability(d: Double, s: Double, r: Double, grade: Grade) -> Double {
        let hardPenalty = grade == .hard ? w[15] : 1
        let easyBonus = grade == .easy ? w[16] : 1
        let value = s * (
            1 + exp(w[8]) * (11 - d) * pow(s, -w[9]) *
                (exp((1 - r) * w[10]) - 1) * hardPenalty * easyBonus
        )
        return min(max(value, 0.01), 36_500)
    }

    private static func nextForgetStability(d: Double, s: Double, r: Double) -> Double {
        let value = w[11] * pow(d, -w[12]) * (pow(s + 1, w[13]) - 1) * exp((1 - r) * w[14])
        return min(max(value, 0.01), 36_500)
    }

    private static func forgettingCurve(elapsedDays: Double, stability: Double) -> Double {
        pow(1 + (factor * elapsedDays) / stability, decay)
    }
}
