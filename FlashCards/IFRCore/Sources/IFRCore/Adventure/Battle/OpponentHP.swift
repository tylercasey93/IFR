public enum OpponentHP {
    public static func tuned(for questions: [Question], passMarkPercent: Int = 70) -> Int {
        let total = totalBaseDamage(of: questions)
        return (total * passMarkPercent + 99) / 100
    }

    public static func cloud(for question: Question) -> Int {
        Damage.hit(difficulty: question.difficulty, answerSeconds: 10).amount
    }

    private static func totalBaseDamage(of questions: [Question]) -> Int {
        questions.reduce(0) { $0 + Damage.hit(difficulty: $1.difficulty, answerSeconds: 10).amount }
    }
}
