public enum BattleTier: String, Codable, Sendable, CaseIterable {
    case cloud, trainer, gym, eliteFour, tower, link, champion

    private static let missDamageByTier: [BattleTier: Int] = [
        .cloud: 20, .trainer: 30, .gym: 30, .eliteFour: 30, .tower: 20, .link: 30, .champion: 1,
    ]

    public var missDamage: Int {
        Self.missDamageByTier[self] ?? 30
    }

    public var runsEveryQuestion: Bool {
        self == .champion
    }

    public func damage(for hit: Hit) -> Int {
        self == .champion ? 1 : hit.amount
    }
}
