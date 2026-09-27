import XCTest
@testable import IFRCore

final class TileMapTests: XCTestCase {
    private func decode(_ json: String) throws -> TileMap {
        try JSONDecoder().decode(TileMap.self, from: Data(json.utf8))
    }

    private let fiveByFiveJSON = """
    {"width": 5, "height": 5, "rows": ["#####", "#.=~#", "#Dw.#", "#.B.#", "#####"]}
    """

    func testRowsDecodeThroughGlyphs() throws {
        let map = try decode(fiveByFiveJSON)
        XCTAssertEqual(map[GridPoint(x: 0, y: 0)], .terrain)
        XCTAssertEqual(map[GridPoint(x: 1, y: 1)], .ground)
        XCTAssertEqual(map[GridPoint(x: 2, y: 1)], .airway)
        XCTAssertEqual(map[GridPoint(x: 3, y: 1)], .cloud)
        XCTAssertEqual(map[GridPoint(x: 1, y: 2)], .door)
        XCTAssertEqual(map[GridPoint(x: 2, y: 2)], .water)
        XCTAssertEqual(map[GridPoint(x: 2, y: 3)], .building)
    }

    func testRaggedRowsRejected() throws {
        let json = """
        {"width": 5, "height": 5, "rows": ["#####", "#.=~#", "#Dw.#", "#.B.", "#####"]}
        """
        XCTAssertThrowsError(try decode(json)) { error in
            XCTAssertEqual(error as? AdventureContentError, .raggedRows)
        }
    }

    func testUnknownGlyphRejectedWithCoordinates() throws {
        let json = """
        {"width": 5, "height": 5, "rows": ["#####", "#.X~#", "#Dw.#", "#.B.#", "#####"]}
        """
        XCTAssertThrowsError(try decode(json)) { error in
            XCTAssertEqual(error as? AdventureContentError, .unknownTile(x: 2, y: 1))
        }
    }

    func testBorderIsTerrain() throws {
        let json = """
        {"width": 5, "height": 5, "rows": ["Z####", "#.=~#", "#Dw.#", "#.B.#", "#####"]}
        """
        XCTAssertThrowsError(try decode(json)) { error in
            XCTAssertEqual(error as? AdventureContentError, .unknownTile(x: 0, y: 0))
        }
    }

    func testWalkabilityPerKind() {
        XCTAssertTrue(TileKind.ground.isWalkable)
        XCTAssertTrue(TileKind.airway.isWalkable)
        XCTAssertTrue(TileKind.cloud.isWalkable)
        XCTAssertTrue(TileKind.door.isWalkable)
        XCTAssertTrue(TileKind.sign.isWalkable)
        XCTAssertFalse(TileKind.water.isWalkable)
        XCTAssertFalse(TileKind.terrain.isWalkable)
        XCTAssertFalse(TileKind.building.isWalkable)
    }

    func testBlocksSightPerKind() {
        XCTAssertTrue(TileKind.terrain.blocksSight)
        XCTAssertTrue(TileKind.building.blocksSight)
        XCTAssertFalse(TileKind.ground.blocksSight)
        XCTAssertFalse(TileKind.airway.blocksSight)
        XCTAssertFalse(TileKind.cloud.blocksSight)
        XCTAssertFalse(TileKind.water.blocksSight)
        XCTAssertFalse(TileKind.door.blocksSight)
        XCTAssertFalse(TileKind.sign.blocksSight)
    }

    func testSubscriptOutOfBoundsIsNil() throws {
        let map = try decode(fiveByFiveJSON)
        XCTAssertNil(map[GridPoint(x: -1, y: 0)])
        XCTAssertNil(map[GridPoint(x: 0, y: -1)])
        XCTAssertNil(map[GridPoint(x: 5, y: 0)])
        XCTAssertNil(map[GridPoint(x: 0, y: 5)])
    }
}
