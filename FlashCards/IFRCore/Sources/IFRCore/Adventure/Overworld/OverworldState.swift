import Foundation

public struct OverworldState: Codable, Equatable, Sendable {
    public var position: GridPoint
    public var facing: Direction
    public var pendingPath: [GridPoint]
    public var stepsSinceEncounter: Int
    public var suppressedTrainerID: String?

    public init(
        position: GridPoint,
        facing: Direction,
        pendingPath: [GridPoint] = [],
        stepsSinceEncounter: Int = 0,
        suppressedTrainerID: String? = nil
    ) {
        self.position = position
        self.facing = facing
        self.pendingPath = pendingPath
        self.stepsSinceEncounter = stepsSinceEncounter
        self.suppressedTrainerID = suppressedTrainerID
    }

    public func stepping(_ direction: Direction, in map: TileMap, blocked: Set<GridPoint>) -> (OverworldState, OverworldEvent) {
        var turned = self
        turned.facing = direction
        let destination = destination(from: position, moving: direction)
        guard let kind = map[destination], kind.isWalkable, !blocked.contains(destination) else {
            return (turned, .blocked)
        }
        var moved = turned
        moved.position = destination
        return (moved, event(for: kind, at: destination, in: map))
    }

    private func destination(from origin: GridPoint, moving direction: Direction) -> GridPoint {
        GridPoint(x: origin.x + direction.delta.x, y: origin.y + direction.delta.y)
    }

    private func event(for kind: TileKind, at point: GridPoint, in map: TileMap) -> OverworldEvent {
        if kind == .door { return warpEvent(at: point, in: map) }
        if kind == .sign { return signEvent(at: point, in: map) }
        if kind == .cloud { return .cloud }
        if let itemID = map.itemDropItemIDs[point] { return .pickup(itemID) }
        return .none
    }

    private func warpEvent(at point: GridPoint, in map: TileMap) -> OverworldEvent {
        guard let airportID = map.doorAirportIDs[point] else { return .none }
        return .warp(airportID)
    }

    private func signEvent(at point: GridPoint, in map: TileMap) -> OverworldEvent {
        guard let text = map.signTexts[point] else { return .none }
        return .sign(text)
    }
}

public enum OverworldEvent: Equatable, Sendable {
    case none
    case blocked
    case warp(String)
    case sign(String)
    case pickup(String)
    case cloud
}
