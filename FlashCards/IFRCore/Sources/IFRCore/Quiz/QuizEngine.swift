// IFRCore/Sources/IFRCore/Quiz/QuizEngine.swift
import Foundation

public struct QuizConfig: Equatable, Sendable {
    public var category: Category?
    public var length: Int
    public var isMockExam: Bool

    public init(category: Category?, length: Int, isMockExam: Bool) {
        self.category = category
        self.length = length
        self.isMockExam = isMockExam
    }

    public static let mockExam = QuizConfig(category: nil, length: 60, isMockExam: true)
}

public struct QuizScore: Equatable, Sendable {
    public let correct: Int
    public let total: Int

    public init(correct: Int, total: Int) {
        self.correct = correct
        self.total = total
    }
    public var percent: Int { total == 0 ? 0 : Int((Double(correct) / Double(total) * 100).rounded()) }
    public var passed: Bool { percent >= 70 }
}

/// Deterministic RNG for tests and reproducible shuffles (SplitMix64).
public struct SeededRNG: RandomNumberGenerator, Sendable {
    private var state: UInt64
    public init(seed: UInt64) { state = seed }
    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

public struct QuizEngine: Sendable {
    private let scheduler: Scheduler

    public init(scheduler: Scheduler) {
        self.scheduler = scheduler
    }

    /// Builds a quiz.
    ///
    /// When `config.isMockExam` is true, `config.category` and
    /// `config.length` are ignored: the mock exam always draws from every
    /// `Category`, sized per-category by `Category.examWeight` (the seed
    /// bank yields an 8-question "mock exam").
    ///
    /// In all cases — mock exam or targeted quiz — if the eligible pool
    /// (multiple-choice-capable questions, optionally filtered by
    /// category) is smaller than the requested count, the returned quiz is
    /// SHORT. It is never padded and never crashes. Callers/UIs must
    /// display the actual returned count rather than assuming the
    /// requested length was met.
    public func makeQuiz(
        config: QuizConfig,
        bank: QuestionBank,
        states: [String: CardState],
        now: Date,
        using rng: inout some RandomNumberGenerator
    ) -> [Question] {
        if config.isMockExam {
            var quiz: [Question] = []
            for category in Category.allCases {
                let pool = bank.questions(in: category).filter(\.isMultipleChoiceCapable)
                quiz += weightedSample(pool, count: category.examWeight, states: states, now: now, using: &rng)
            }
            return quiz.shuffled(using: &rng)
        }
        let pool = bank.questions
            .filter(\.isMultipleChoiceCapable)
            .filter { config.category == nil || $0.category == config.category }
        return weightedSample(pool, count: config.length, states: states, now: now, using: &rng)
    }

    public static func score(results: [Bool]) -> QuizScore {
        QuizScore(correct: results.filter { $0 }.count, total: results.count)
    }

    /// Roulette-wheel sampling without replacement. Weight = 1.25 − predicted
    /// retention, so weak/unseen cards (retention 0 → weight 1.25) are ~5×
    /// likelier than fresh ones (retention ~1 → weight 0.25).
    ///
    /// If `pool.count < count`, every eligible question is picked and the
    /// result is SHORT — this is by design (never padded, never a crash);
    /// see the `makeQuiz` doc comment.
    private func weightedSample(
        _ pool: [Question], count: Int, states: [String: CardState], now: Date,
        using rng: inout some RandomNumberGenerator
    ) -> [Question] {
        var remaining = pool.map { q -> (Question, Double) in
            let r = states[q.id].map { scheduler.retrievability(of: $0, at: now) } ?? 0
            return (q, 1.25 - r)
        }
        var picked: [Question] = []
        while picked.count < count, !remaining.isEmpty {
            let totalWeight = remaining.reduce(0) { $0 + $1.1 }
            var roll = Double.random(in: 0..<totalWeight, using: &rng)
            var index = remaining.count - 1
            for (i, entry) in remaining.enumerated() {
                if roll < entry.1 { index = i; break }
                roll -= entry.1
            }
            picked.append(remaining.remove(at: index).0)
        }
        return picked
    }
}
