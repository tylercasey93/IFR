// IFRCore/Sources/IFRCore/Progress/MasteryCalculator.swift
import Foundation

public enum MasteryLevel: Int, CaseIterable, Sendable {
    case novice = 1, apprentice, competent, proficient, instrumentMaster

    public var displayName: String {
        switch self {
        case .novice: "Novice"
        case .apprentice: "Apprentice"
        case .competent: "Competent"
        case .proficient: "Proficient"
        case .instrumentMaster: "Instrument Master"
        }
    }

    public static func level(forRetention r: Double) -> MasteryLevel {
        switch r {
        case ..<0.2: .novice
        case ..<0.4: .apprentice
        case ..<0.6: .competent
        case ..<0.8: .proficient
        default: .instrumentMaster
        }
    }
}

public struct MasteryCalculator: Sendable {
    private let scheduler: Scheduler

    public init(scheduler: Scheduler) {
        self.scheduler = scheduler
    }

    /// Mean predicted recall over ALL cards in the category; unseen cards
    /// contribute 0, so mastery reflects true coverage of the material.
    public func categoryRetention(_ category: Category, bank: QuestionBank,
                                  states: [String: CardState], at date: Date) -> Double {
        mean(retention(of: bank.questions(in: category), states: states, at: date))
    }

    /// Predicted mean recall across the whole bank at `date` (e.g. exam day).
    public func readiness(bank: QuestionBank, states: [String: CardState], at date: Date) -> Double {
        mean(retention(of: bank.questions, states: states, at: date))
    }

    private func retention(of questions: [Question], states: [String: CardState], at date: Date) -> [Double] {
        questions.map { q in
            states[q.id].map { scheduler.retrievability(of: $0, at: date) } ?? 0
        }
    }

    private func mean(_ values: [Double]) -> Double {
        values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }
}
