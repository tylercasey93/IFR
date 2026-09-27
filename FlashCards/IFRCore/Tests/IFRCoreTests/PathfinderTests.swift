import XCTest
@testable import IFRCore

final class PathfinderTests: XCTestCase {
    private func makeMap(_ rows: [[TileKind]]) -> TileMap {
        TileMap(width: rows.first?.count ?? 0, height: rows.count, rows: rows)
    }

    private let ground = TileKind.ground
    private let water = TileKind.water
    private let terrain = TileKind.terrain

    func testStraightLineOnOpenGround() {
        let map = makeMap([[ground, ground, ground, ground, ground]])
        let path = Pathfinder.path(from: GridPoint(x: 0, y: 0), to: GridPoint(x: 4, y: 0), in: map, blocked: [])
        XCTAssertEqual(path, [
            GridPoint(x: 1, y: 0),
            GridPoint(x: 2, y: 0),
            GridPoint(x: 3, y: 0),
            GridPoint(x: 4, y: 0),
        ])
    }

    func testRoutesAroundWater() {
        let map = makeMap([
            [ground, ground, ground, ground, ground],
            [ground, water, water, water, ground],
            [ground, ground, ground, ground, ground],
        ])
        let path = Pathfinder.path(from: GridPoint(x: 0, y: 1), to: GridPoint(x: 4, y: 1), in: map, blocked: [])
        XCTAssertEqual(path, [
            GridPoint(x: 0, y: 0),
            GridPoint(x: 1, y: 0),
            GridPoint(x: 2, y: 0),
            GridPoint(x: 3, y: 0),
            GridPoint(x: 4, y: 0),
            GridPoint(x: 4, y: 1),
        ])
    }

    func testReturnsNilWhenUnreachable() {
        let map = makeMap([[ground, terrain, ground]])
        let path = Pathfinder.path(from: GridPoint(x: 0, y: 0), to: GridPoint(x: 2, y: 0), in: map, blocked: [])
        XCTAssertNil(path)
    }

    func testPathExcludesStartIncludesGoal() {
        let map = makeMap([[ground, ground, ground, ground, ground]])
        let start = GridPoint(x: 0, y: 0)
        let goal = GridPoint(x: 4, y: 0)
        let path = Pathfinder.path(from: start, to: goal, in: map, blocked: [])
        XCTAssertNotEqual(path?.first, start)
        XCTAssertEqual(path?.last, goal)
    }

    func testPathIsFourConnected() {
        let map = makeMap([
            [ground, ground, ground, ground, ground],
            [ground, water, water, water, ground],
            [ground, ground, ground, ground, ground],
        ])
        let path = Pathfinder.path(from: GridPoint(x: 0, y: 1), to: GridPoint(x: 4, y: 1), in: map, blocked: [])!
        var previous = GridPoint(x: 0, y: 1)
        for point in path {
            let manhattan = abs(point.x - previous.x) + abs(point.y - previous.y)
            XCTAssertEqual(manhattan, 1)
            previous = point
        }
    }

    func testBlockedSetTreatedAsWalls() {
        let map = makeMap([
            [ground, ground, ground, ground, ground],
            [ground, ground, ground, ground, ground],
            [ground, ground, ground, ground, ground],
        ])
        let blocked: Set<GridPoint> = [GridPoint(x: 1, y: 1), GridPoint(x: 2, y: 1), GridPoint(x: 3, y: 1)]
        let path = Pathfinder.path(from: GridPoint(x: 0, y: 1), to: GridPoint(x: 4, y: 1), in: map, blocked: blocked)
        XCTAssertEqual(path, [
            GridPoint(x: 0, y: 0),
            GridPoint(x: 1, y: 0),
            GridPoint(x: 2, y: 0),
            GridPoint(x: 3, y: 0),
            GridPoint(x: 4, y: 0),
            GridPoint(x: 4, y: 1),
        ])
    }

    func testDeterministicTieBreakByRowThenColumn() {
        let map = makeMap([
            [ground, ground, ground],
            [ground, ground, ground],
            [ground, ground, ground],
        ])
        let path = Pathfinder.path(from: GridPoint(x: 0, y: 0), to: GridPoint(x: 2, y: 2), in: map, blocked: [])
        XCTAssertEqual(path, [
            GridPoint(x: 1, y: 0),
            GridPoint(x: 2, y: 0),
            GridPoint(x: 2, y: 1),
            GridPoint(x: 2, y: 2),
        ])
    }

    func testNeighboursExpandUpRightDownLeft() {
        let map = makeMap([
            [ground, ground, ground],
            [ground, ground, ground],
            [ground, ground, ground],
        ])
        let path = Pathfinder.path(from: GridPoint(x: 1, y: 1), to: GridPoint(x: 0, y: 0), in: map, blocked: [])
        XCTAssertEqual(path, [
            GridPoint(x: 1, y: 0),
            GridPoint(x: 0, y: 0),
        ])
    }

    func testFortyByThirtyMapSolvesUnderTenMilliseconds() {
        let rows = Array(repeating: Array(repeating: ground, count: 40), count: 30)
        let map = makeMap(rows)
        let start = Date()
        let path = Pathfinder.path(from: GridPoint(x: 0, y: 0), to: GridPoint(x: 39, y: 29), in: map, blocked: [])
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertNotNil(path)
        XCTAssertLessThan(elapsed, 0.010)
    }
}
