import XCTest
@testable import IFRCore

final class RespawnTests: XCTestCase {
    private func makeMap(doorAirportIDs: [GridPoint: String], spawn: GridPoint) -> TileMap {
        TileMap(
            width: 10, height: 10, rows: Array(repeating: Array(repeating: TileKind.ground, count: 10), count: 10),
            doorAirportIDs: doorAirportIDs, spawn: spawn
        )
    }

    func testLossPlacementIsNearestVisitedAirportDoorFacingDown() {
        let map = makeMap(
            doorAirportIDs: [
                GridPoint(x: 0, y: 0): "KHYP",
                GridPoint(x: 8, y: 8): "KGYR",
            ],
            spawn: GridPoint(x: 3, y: 3)
        )
        var save = AdventureSave.new
        save.position = GridPoint(x: 1, y: 1)
        save.visitedAirportIDs = ["KHYP", "KGYR"]
        let placement = Respawn.placement(save: save, map: map)
        XCTAssertEqual(placement.position, GridPoint(x: 0, y: 0))
        XCTAssertEqual(placement.facing, .down)
    }

    func testLossPlacementFallsBackToSpawnWhenNothingVisited() {
        let map = makeMap(doorAirportIDs: [GridPoint(x: 0, y: 0): "KHYP"], spawn: GridPoint(x: 3, y: 2))
        var save = AdventureSave.new
        save.position = GridPoint(x: 1, y: 1)
        save.visitedAirportIDs = []
        let placement = Respawn.placement(save: save, map: map)
        XCTAssertEqual(placement.position, GridPoint(x: 3, y: 2))
        XCTAssertEqual(placement.facing, .down)
    }
}
