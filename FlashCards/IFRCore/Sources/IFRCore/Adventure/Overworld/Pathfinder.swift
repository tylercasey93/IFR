import Foundation

public enum Pathfinder {
    private static let neighbourOffsets: [GridPoint] = [
        GridPoint(x: 0, y: -1),
        GridPoint(x: 1, y: 0),
        GridPoint(x: 0, y: 1),
        GridPoint(x: -1, y: 0),
    ]

    public static func path(from start: GridPoint, to goal: GridPoint, in map: TileMap, blocked: Set<GridPoint>) -> [GridPoint]? {
        if start == goal { return [] }
        var open: [GridPoint] = [start]
        var gScore: [GridPoint: Int] = [start: 0]
        var cameFrom: [GridPoint: GridPoint] = [:]
        var closed: Set<GridPoint> = []

        while !open.isEmpty {
            let current = popBest(&open, gScore: gScore, goal: goal)
            if current == goal {
                return reconstruct(cameFrom: cameFrom, goal: goal)
            }
            closed.insert(current)
            expand(current, gScore: &gScore, cameFrom: &cameFrom, open: &open, closed: closed, map: map, blocked: blocked)
        }
        return nil
    }

    private static func expand(
        _ current: GridPoint,
        gScore: inout [GridPoint: Int],
        cameFrom: inout [GridPoint: GridPoint],
        open: inout [GridPoint],
        closed: Set<GridPoint>,
        map: TileMap,
        blocked: Set<GridPoint>
    ) {
        for neighbour in neighbours(of: current) {
            guard isPassable(neighbour, in: map, blocked: blocked), !closed.contains(neighbour) else { continue }
            let tentativeG = gScore[current, default: 0] + 1
            if gScore[neighbour] == nil || tentativeG < gScore[neighbour]! {
                gScore[neighbour] = tentativeG
                cameFrom[neighbour] = current
                if !open.contains(neighbour) {
                    open.append(neighbour)
                }
            }
        }
    }

    private static func popBest(_ open: inout [GridPoint], gScore: [GridPoint: Int], goal: GridPoint) -> GridPoint {
        var bestIndex = 0
        var bestKey = key(open[0], gScore: gScore, goal: goal)
        for index in open.indices.dropFirst() {
            let candidateKey = key(open[index], gScore: gScore, goal: goal)
            if candidateKey.lexicographicallyPrecedes(bestKey) {
                bestKey = candidateKey
                bestIndex = index
            }
        }
        return open.remove(at: bestIndex)
    }

    private static func key(_ point: GridPoint, gScore: [GridPoint: Int], goal: GridPoint) -> [Int] {
        let h = manhattan(point, goal)
        let g = gScore[point, default: 0]
        return [g + h, h, point.y, point.x]
    }

    private static func manhattan(_ a: GridPoint, _ b: GridPoint) -> Int {
        abs(a.x - b.x) + abs(a.y - b.y)
    }

    private static func neighbours(of point: GridPoint) -> [GridPoint] {
        neighbourOffsets.map { GridPoint(x: point.x + $0.x, y: point.y + $0.y) }
    }

    private static func isPassable(_ point: GridPoint, in map: TileMap, blocked: Set<GridPoint>) -> Bool {
        guard let kind = map[point], kind.isWalkable else { return false }
        return !blocked.contains(point)
    }

    private static func reconstruct(cameFrom: [GridPoint: GridPoint], goal: GridPoint) -> [GridPoint] {
        var path: [GridPoint] = [goal]
        var current = goal
        while let previous = cameFrom[current] {
            path.append(previous)
            current = previous
        }
        path.removeLast()
        return path.reversed()
    }
}
