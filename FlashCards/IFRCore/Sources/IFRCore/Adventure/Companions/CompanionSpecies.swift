import Foundation

public struct CompanionSpecies: Codable, Equatable, Sendable {
    public let category: Category
    public let stageNames: [String]
    public let spriteIDs: [String]

    public init(category: Category, stageNames: [String], spriteIDs: [String]) {
        self.category = category
        self.stageNames = stageNames
        self.spriteIDs = spriteIDs
    }
}
