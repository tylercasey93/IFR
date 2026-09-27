public struct BattleTower: Equatable, Sendable {
    public static let questionsPerFloor = 5

    private static let leaderSpriteIDs = [
        "leader-hypoxia", "leader-gyro", "leader-reg", "leader-victor",
        "leader-plotter", "leader-nimbus", "leader-mayday", "leader-ilsa",
    ]

    public var floor: Int
    public var playerHP: Int
    public var playerMaxHP: Int

    public init(floor: Int, playerHP: Int, playerMaxHP: Int) {
        self.floor = floor
        self.playerHP = playerHP
        self.playerMaxHP = playerMaxHP
    }

    public static func start(playerMaxHP: Int) -> BattleTower {
        BattleTower(floor: 1, playerHP: playerMaxHP, playerMaxHP: playerMaxHP)
    }

    public static func missDamage(floor: Int) -> Int {
        20 + (floor - 1) * 5
    }

    public func opponent(forFloor floor: Int, deck: [Question]) -> Opponent {
        let index = (floor - 1) % Self.leaderSpriteIDs.count
        return Opponent(
            id: "tower-floor-\(floor)", name: "FLOOR \(floor) PILOT",
            nameplateName: String("FLOOR\(floor)".prefix(7)), spriteID: Self.leaderSpriteIDs[index],
            tier: .tower, maxHP: OpponentHP.tuned(for: deck)
        )
    }

    public func climbing(after battle: BattleState) -> BattleTower? {
        guard battle.outcome == .won else { return nil }
        return BattleTower(floor: floor + 1, playerHP: battle.playerHP, playerMaxHP: playerMaxHP)
    }
}
