import Foundation

public struct GridPoint: Hashable, Codable, Sendable {
    public let x: Int
    public let y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }

    public func manhattanDistance(to other: GridPoint) -> Int {
        abs(x - other.x) + abs(y - other.y)
    }
}
