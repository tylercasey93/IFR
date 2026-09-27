import Foundation

public struct RivalEncounter: Codable, Equatable, Sendable {
    public let at: GridPoint
    public let afterBadges: Int
    public let dialogue: DialogueRefs

    public init(at: GridPoint, afterBadges: Int, dialogue: DialogueRefs) {
        self.at = at
        self.afterBadges = afterBadges
        self.dialogue = dialogue
    }
}

public struct RivalSpec: Codable, Equatable, Sendable {
    public let name: String
    public let nameplateName: String
    public let spriteID: String
    public let questionCount: Int
    public let encounters: [RivalEncounter]

    public init(name: String, nameplateName: String, spriteID: String, questionCount: Int, encounters: [RivalEncounter]) {
        self.name = name
        self.nameplateName = nameplateName
        self.spriteID = spriteID
        self.questionCount = questionCount
        self.encounters = encounters
    }

    public func opponent(maxHP: Int) -> Opponent {
        Opponent(
            id: "rival", name: name, nameplateName: nameplateName, spriteID: spriteID,
            tier: .trainer, maxHP: maxHP
        )
    }
}
