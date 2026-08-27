public enum XPEvent: Equatable, Sendable {
    case flashcardReview(grade: Grade, difficulty: Int)
    case reviewMC(correct: Bool, difficulty: Int)
    case quizAnswer(correct: Bool, difficulty: Int)
    case mockExamCompleted(passed: Bool)
    case dailyGoalMet
}

public enum XPEngine: Sendable {
    /// +5 bonus applies only to correct answers on difficulty-3 questions.
    public static func points(for event: XPEvent) -> Int {
        switch event {
        case .flashcardReview(let grade, let difficulty):
            grade == .again ? 2 : 10 + bonus(difficulty: difficulty)
        case .reviewMC(let correct, let difficulty):
            correct ? 12 + bonus(difficulty: difficulty) : 3
        case .quizAnswer(let correct, let difficulty):
            correct ? 15 + bonus(difficulty: difficulty) : 3
        case .mockExamCompleted(let passed):
            passed ? 100 : 40
        case .dailyGoalMet:
            50
        }
    }

    private static func bonus(difficulty: Int) -> Int {
        difficulty == 3 ? 5 : 0
    }
}
