import Foundation

public struct Opponent: Equatable, Codable, Sendable {
    public let id: String
    public let name: String
    public let nameplateName: String
    public let spriteID: String
    public let tier: BattleTier
    public let maxHP: Int
    public let gymID: String?
    public let airportID: String?

    public init(
        id: String, name: String, nameplateName: String, spriteID: String,
        tier: BattleTier, maxHP: Int, gymID: String? = nil, airportID: String? = nil
    ) {
        self.id = id
        self.name = name
        self.nameplateName = nameplateName
        self.spriteID = spriteID
        self.tier = tier
        self.maxHP = maxHP
        self.gymID = gymID
        self.airportID = airportID
    }
}
