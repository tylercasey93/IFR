import Foundation

public struct Trainer: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let nameplateName: String
    public let spriteID: String
    public let position: GridPoint
    public let facing: Direction
    public let range: Int
    public let questionCount: Int
    public let categories: [Category]
    public let dialogue: DialogueRefs

    public init(
        id: String, name: String, nameplateName: String, spriteID: String,
        position: GridPoint, facing: Direction, range: Int, questionCount: Int,
        categories: [Category], dialogue: DialogueRefs
    ) {
        self.id = id
        self.name = name
        self.nameplateName = nameplateName
        self.spriteID = spriteID
        self.position = position
        self.facing = facing
        self.range = range
        self.questionCount = questionCount
        self.categories = categories
        self.dialogue = dialogue
    }
}
