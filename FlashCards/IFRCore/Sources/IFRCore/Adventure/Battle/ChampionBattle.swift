import Foundation

public enum ChampionBattle {
    public static let opponentHP = 42
    public static let playerHP = 19

    public static func deck(
        bank: QuestionBank, states: [String: CardState], scheduler: Scheduler,
        now: Date, using rng: inout some RandomNumberGenerator
    ) -> [Question] {
        QuizEngine(scheduler: scheduler).makeQuiz(
            config: .mockExam, bank: bank, states: states, now: now, using: &rng
        )
    }

    public static func outcome(results: [Bool]) -> BattleOutcome {
        QuizEngine.score(results: results).passed ? .won : .lost
    }
}
