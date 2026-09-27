import Foundation

public enum Respawn {
    public static func placement(save: AdventureSave, map: TileMap) -> (position: GridPoint, facing: Direction) {
        guard let origin = save.position, let nearest = nearestVisitedDoor(save: save, map: map, from: origin) else {
            return (map.spawn, .down)
        }
        return (nearest, .down)
    }

    private static func nearestVisitedDoor(save: AdventureSave, map: TileMap, from origin: GridPoint) -> GridPoint? {
        let visitedDoors = map.doorAirportIDs.filter { save.visitedAirportIDs.contains($0.value) }.map(\.key)
        return visitedDoors.min { lhs, rhs in
            let leftDistance = lhs.manhattanDistance(to: origin)
            let rightDistance = rhs.manhattanDistance(to: origin)
            if leftDistance != rightDistance { return leftDistance < rightDistance }
            if lhs.y != rhs.y { return lhs.y < rhs.y }
            return lhs.x < rhs.x
        }
    }
}
