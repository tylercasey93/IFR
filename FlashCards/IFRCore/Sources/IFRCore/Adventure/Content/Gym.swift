import Foundation

public struct DialogueRefs: Codable, Equatable, Sendable {
    public let intro: String
    public let win: String
    public let lose: String
}

public struct Gym: Codable, Equatable, Sendable {
    public let id: GymID
    public let leaderName: String
    public let nameplateName: String
    public let leaderSpriteID: String
    public let badgeName: String
    public let questionCount: Int
    public let dialogue: DialogueRefs

    public func opponent(maxHP: Int, airportID: String) -> Opponent {
        Opponent(
            id: id.rawValue, name: leaderName, nameplateName: nameplateName, spriteID: leaderSpriteID,
            tier: .gym, maxHP: maxHP, gymID: id.rawValue, airportID: airportID
        )
    }
}

public struct EliteMember: Codable, Equatable, Sendable {
    public let id: String
    public let order: Int
    public let name: String
    public let nameplateName: String
    public let spriteID: String
    public let categories: [Category]
    public let questionCount: Int
    public let dialogue: DialogueRefs
}

public struct ChampionSpec: Codable, Equatable, Sendable {
    public let name: String
    public let nameplateName: String
    public let spriteID: String
    public let dialogue: DialogueRefs
}
