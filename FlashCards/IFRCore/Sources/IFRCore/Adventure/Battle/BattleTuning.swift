import Foundation

public enum BattleTuning {
    public static func totalBaseDamage(of questions: [Question]) -> Int {
        questions.reduce(0) { $0 + Damage.hit(difficulty: $1.difficulty, answerSeconds: 10).amount }
    }

    public static func winsWithoutCriticals(deck: [Question], correctIndices: Set<Int>) -> Bool {
        winsWithCriticals(deck: deck, correctIndices: correctIndices, criticalIndices: [])
    }

    public static func winsWithCriticals(
        deck: [Question], correctIndices: Set<Int>, criticalIndices: Set<Int>
    ) -> Bool {
        let opponentHP = OpponentHP.tuned(for: deck)
        let damage = totalDamage(deck: deck, correctIndices: correctIndices, criticalIndices: criticalIndices)
        return damage >= opponentHP
    }

    private static func totalDamage(
        deck: [Question], correctIndices: Set<Int>, criticalIndices: Set<Int>
    ) -> Int {
        correctIndices.reduce(0) { total, index in
            let answerSeconds: Double = criticalIndices.contains(index) ? 0 : 10
            let hit = Damage.hit(difficulty: deck[index].difficulty, answerSeconds: answerSeconds)
            return total + hit.amount
        }
    }
}
