import Foundation

public enum TileKind: Character, Equatable, Sendable {
    case ground = "."
    case airway = "="
    case cloud = "~"
    case water = "w"
    case terrain = "#"
    case building = "B"
    case door = "D"
    case sign = "S"

    public var isWalkable: Bool {
        switch self {
        case .ground, .airway, .cloud, .door, .sign: true
        case .water, .terrain, .building: false
        }
    }

    public var blocksSight: Bool {
        switch self {
        case .terrain, .building: true
        case .ground, .airway, .cloud, .water, .door, .sign: false
        }
    }
}
