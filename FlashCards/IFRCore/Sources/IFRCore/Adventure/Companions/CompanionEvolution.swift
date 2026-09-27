import Foundation

public struct CompanionEvolution: Equatable, Sendable {
    public let category: Category
    public let from: CompanionStage
    public let to: CompanionStage

    public init(category: Category, from: CompanionStage, to: CompanionStage) {
        self.category = category
        self.from = from
        self.to = to
    }
}
