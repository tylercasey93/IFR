import XCTest
@testable import IFRCore

final class OverworldStateTests: XCTestCase {
    private func makeMap(
        _ rows: [[TileKind]],
        doorAirportIDs: [GridPoint: String] = [:],
        signTexts: [GridPoint: String] = [:],
        itemDropItemIDs: [GridPoint: String] = [:]
    ) -> TileMap {
        TileMap(
            width: rows.first?.count ?? 0, height: rows.count, rows: rows,
            doorAirportIDs: doorAirportIDs, signTexts: signTexts, itemDropItemIDs: itemDropItemIDs
        )
    }

    private let ground = TileKind.ground
    private let terrain = TileKind.terrain
    private let cloud = TileKind.cloud
    private let door = TileKind.door
    private let sign = TileKind.sign

    private func makeState(x: Int = 1, y: Int = 1, facing: Direction = .up, stepsSinceEncounter: Int = 0) -> OverworldState {
        OverworldState(position: GridPoint(x: x, y: y), facing: facing, stepsSinceEncounter: stepsSinceEncounter)
    }

    func testSteppingIntoTerrainOnlyTurns() {
        let map = makeMap([
            [ground, terrain, ground],
            [ground, ground, ground],
            [ground, ground, ground],
        ])
        let state = makeState(x: 1, y: 1, facing: .down)
        let (next, event) = state.stepping(.up, in: map, blocked: [])
        XCTAssertEqual(next.facing, .up)
        XCTAssertEqual(next.position, state.position)
        XCTAssertEqual(event, .blocked)
    }

    func testSteppingIntoBlockedTileOnlyTurns() {
        let map = makeMap([
            [ground, ground, ground],
            [ground, ground, ground],
            [ground, ground, ground],
        ])
        let state = makeState(x: 1, y: 1, facing: .down)
        let blockedTile = GridPoint(x: 1, y: 0)
        let (next, event) = state.stepping(.up, in: map, blocked: [blockedTile])
        XCTAssertEqual(next.facing, .up)
        XCTAssertEqual(next.position, state.position)
        XCTAssertEqual(event, .blocked)
    }

    func testSteppingOntoWalkableMoves() {
        let map = makeMap([
            [ground, ground, ground],
            [ground, ground, ground],
            [ground, ground, ground],
        ])
        let state = makeState(x: 1, y: 1, facing: .down)
        let (next, event) = state.stepping(.up, in: map, blocked: [])
        XCTAssertEqual(next.facing, .up)
        XCTAssertEqual(next.position, GridPoint(x: 1, y: 0))
        XCTAssertEqual(event, .none)
    }

    func testSteppingOntoDoorEmitsWarpWithAirportID() {
        let map = makeMap(
            [
                [ground, door, ground],
                [ground, ground, ground],
                [ground, ground, ground],
            ],
            doorAirportIDs: [GridPoint(x: 1, y: 0): "KHYP"]
        )
        let state = makeState(x: 1, y: 1, facing: .down)
        let (next, event) = state.stepping(.up, in: map, blocked: [])
        XCTAssertEqual(next.position, GridPoint(x: 1, y: 0))
        XCTAssertEqual(event, .warp("KHYP"))
    }

    func testSteppingOntoSignEmitsText() {
        let map = makeMap(
            [
                [ground, sign, ground],
                [ground, ground, ground],
                [ground, ground, ground],
            ],
            signTexts: [GridPoint(x: 1, y: 0): "HYPOXIA FIELD. ELEV 8,000."]
        )
        let state = makeState(x: 1, y: 1, facing: .down)
        let (_, event) = state.stepping(.up, in: map, blocked: [])
        XCTAssertEqual(event, .sign("HYPOXIA FIELD. ELEV 8,000."))
    }

    func testSteppingOntoCloudEmitsCloud() {
        let map = makeMap([
            [ground, cloud, ground],
            [ground, ground, ground],
            [ground, ground, ground],
        ])
        let state = makeState(x: 1, y: 1, facing: .down)
        let (_, event) = state.stepping(.up, in: map, blocked: [])
        XCTAssertEqual(event, .cloud)
    }

    func testSteppingOntoItemDropEmitsPickup() {
        let map = makeMap(
            [
                [ground, ground, ground],
                [ground, ground, ground],
                [ground, ground, ground],
            ],
            itemDropItemIDs: [GridPoint(x: 1, y: 0): "potion"]
        )
        let state = makeState(x: 1, y: 1, facing: .down)
        let (_, event) = state.stepping(.up, in: map, blocked: [])
        XCTAssertEqual(event, .pickup("potion"))
    }

    func testSteppingNeverChangesStepsSinceEncounter() {
        let map = makeMap([
            [ground, cloud, ground],
            [ground, ground, ground],
            [ground, ground, ground],
        ])
        let state = makeState(x: 1, y: 1, facing: .down, stepsSinceEncounter: 5)
        let (next, _) = state.stepping(.up, in: map, blocked: [])
        XCTAssertEqual(next.stepsSinceEncounter, 5)
    }
}
