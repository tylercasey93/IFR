public struct EliteFourRun: Equatable, Sendable {
    public let memberIndex: Int
    public let playerHP: Int
    public let playerMaxHP: Int

    public var isCleared: Bool { memberIndex == 4 }

    public init(memberIndex: Int, playerHP: Int, playerMaxHP: Int) {
        self.memberIndex = memberIndex
        self.playerHP = playerHP
        self.playerMaxHP = playerMaxHP
    }

    public static func start(playerMaxHP: Int) -> EliteFourRun {
        EliteFourRun(memberIndex: 0, playerHP: playerMaxHP, playerMaxHP: playerMaxHP)
    }

    public func advancing(after battle: BattleState) -> EliteFourRun? {
        guard battle.outcome == .won else { return nil }
        let healedHP = Self.carryOverHP(current: battle.playerHP, max: playerMaxHP)
        return EliteFourRun(memberIndex: memberIndex + 1, playerHP: healedHP, playerMaxHP: playerMaxHP)
    }

    public static func carryOverHP(current: Int, max: Int) -> Int {
        min(current + max * 30 / 100, max)
    }
}
