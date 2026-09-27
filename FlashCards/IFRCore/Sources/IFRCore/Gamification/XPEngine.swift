public enum XPEvent: Equatable, Sendable {
    case flashcardReview(grade: Grade, difficulty: Int)
    case reviewMC(correct: Bool, difficulty: Int)
    case quizAnswer(correct: Bool, difficulty: Int)
    case mockExamCompleted(passed: Bool)
    case dailyGoalMet
    case cloudCleared
    case trainerDefeated
    case gymBadgeEarned(firstTime: Bool)
    case eliteMemberDefeated
    case championCrowned(firstTime: Bool)
    case towerFloorCleared
    case linkBattleFinished
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
        case .cloudCleared:
            5
        case .trainerDefeated:
            25
        case .gymBadgeEarned(let firstTime):
            firstTime ? 100 : 40
        case .eliteMemberDefeated:
            75
        case .championCrowned(let firstTime):
            firstTime ? 200 : 60
        case .towerFloorCleared:
            10
        case .linkBattleFinished:
            20
        }
    }

    private static func bonus(difficulty: Int) -> Int {
        difficulty == 3 ? 5 : 0
    }
}
