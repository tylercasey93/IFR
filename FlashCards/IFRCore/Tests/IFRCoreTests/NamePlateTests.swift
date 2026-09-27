import XCTest
@testable import IFRCore

final class NamePlateTests: XCTestCase {
    func testEnemyPlateIsTwelveTallWithoutNumbers() {
        let plate = NamePlate.enemy
        XCTAssertEqual(plate.origin, GridPoint(x: 16, y: 16))
        XCTAssertEqual(plate.showsNumbers, false)
        XCTAssertEqual(plate.height, 12)
        XCTAssertNil(plate.numbersRightEdge)
    }

    func testPlayerPlateIsTwentyTallWithNumbersEndingAtSixtyTwo() {
        let plate = NamePlate.player
        XCTAssertEqual(plate.origin, GridPoint(x: 144, y: 80))
        XCTAssertEqual(plate.showsNumbers, true)
        XCTAssertEqual(plate.height, 20)
        XCTAssertEqual(plate.numbersRightEdge, GridPoint(x: 206, y: 92))
    }

    func testNameAndBarOriginsOffsetFromPlateOrigin() {
        for plate in [NamePlate.enemy, NamePlate.player] {
            let origin = plate.origin
            XCTAssertEqual(plate.nameOrigin, GridPoint(x: origin.x + 2, y: origin.y + 1))
            XCTAssertEqual(plate.barOrigin, GridPoint(x: origin.x + 8, y: origin.y + 7))
        }
    }
}
