import Foundation

public enum Direction: String, Codable, Sendable {
    case up
    case down
    case left
    case right

    public var delta: GridPoint {
        switch self {
        case .up: GridPoint(x: 0, y: -1)
        case .down: GridPoint(x: 0, y: 1)
        case .left: GridPoint(x: -1, y: 0)
        case .right: GridPoint(x: 1, y: 0)
        }
    }

    public var opposite: Direction {
        switch self {
        case .up: .down
        case .down: .up
        case .left: .right
        case .right: .left
        }
    }
}
