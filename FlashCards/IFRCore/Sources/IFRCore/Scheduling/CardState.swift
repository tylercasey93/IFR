import Foundation

public enum Grade: Int, Codable, CaseIterable, Sendable {
    case again = 1, hard, good, easy
}

public extension Grade {
    /// The single sanctioned mapping from a multiple-choice answer to a
    /// scheduler grade — used by both review-mode MC and quiz answers so
    /// the two flows can never diverge.
    init(mcCorrect: Bool) {
        self = mcCorrect ? .good : .again
    }
}

public struct CardState: Codable, Equatable, Sendable {
    public let questionID: String
    public var stability: Double
    public var difficulty: Double
    public var due: Date
    public var lastReview: Date?
    public var reps: Int
    public var lapses: Int

    public init(questionID: String, stability: Double, difficulty: Double,
                due: Date, lastReview: Date?, reps: Int, lapses: Int) {
        self.questionID = questionID
        self.stability = stability
        self.difficulty = difficulty
        self.due = due
        self.lastReview = lastReview
        self.reps = reps
        self.lapses = lapses
    }

    public static func new(questionID: String) -> CardState {
        CardState(questionID: questionID, stability: 0, difficulty: 0,
                  due: .distantPast, lastReview: nil, reps: 0, lapses: 0)
    }
}
