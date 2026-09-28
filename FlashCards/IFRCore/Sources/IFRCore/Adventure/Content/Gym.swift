import Foundation

public struct DialogueRefs: Codable, Equatable, Sendable {
    public let intro: String
    public let win: String
    public let lose: String

    public init(intro: String, win: String, lose: String) {
        self.intro = intro
        self.win = win
        self.lose = lose
    }
}

public struct Gym: Codable, Equatable, Sendable {
    public let id: GymID
    public let leaderName: String
    public let nameplateName: String
    public let leaderSpriteID: String
    public let badgeName: String
    public let questionCount: Int
    public let dialogue: DialogueRefs

    public init(
        id: GymID, leaderName: String, nameplateName: String, leaderSpriteID: String,
        badgeName: String, questionCount: Int, dialogue: DialogueRefs
    ) {
        self.id = id
        self.leaderName = leaderName
        self.nameplateName = nameplateName
        self.leaderSpriteID = leaderSpriteID
        self.badgeName = badgeName
        self.questionCount = questionCount
        self.dialogue = dialogue
    }

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

    public init(
        id: String, order: Int, name: String, nameplateName: String, spriteID: String,
        categories: [Category], questionCount: Int, dialogue: DialogueRefs
    ) {
        self.id = id
        self.order = order
        self.name = name
        self.nameplateName = nameplateName
        self.spriteID = spriteID
        self.categories = categories
        self.questionCount = questionCount
        self.dialogue = dialogue
    }
}

public struct ChampionSpec: Codable, Equatable, Sendable {
    public let name: String
    public let nameplateName: String
    public let spriteID: String
    public let dialogue: DialogueRefs

    public init(name: String, nameplateName: String, spriteID: String, dialogue: DialogueRefs) {
        self.name = name
        self.nameplateName = nameplateName
        self.spriteID = spriteID
        self.dialogue = dialogue
    }
}
