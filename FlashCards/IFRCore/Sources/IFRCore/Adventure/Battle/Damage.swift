import Foundation

public struct Hit: Equatable, Sendable {
    public let amount: Int
    public let isCritical: Bool
    public let isSuperEffective: Bool

    public init(amount: Int, isCritical: Bool, isSuperEffective: Bool) {
        self.amount = amount
        self.isCritical = isCritical
        self.isSuperEffective = isSuperEffective
    }
}

public enum Damage {
    private static let difficultyPercentByDifficulty = [1: 100, 2: 125, 3: 150]

    public static func hit(difficulty: Int, answerSeconds: Double) -> Hit {
        let isCritical = answerSeconds < 6
        let criticalPercent = isCritical ? 150 : 100
        let difficultyPercent = difficultyPercentByDifficulty[difficulty] ?? 100
        let amount = 8 * difficultyPercent * criticalPercent / 10_000
        return Hit(amount: amount, isCritical: isCritical, isSuperEffective: difficulty == 3)
    }
}
