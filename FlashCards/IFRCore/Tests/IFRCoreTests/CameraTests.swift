import XCTest
@testable import IFRCore

final class CameraTests: XCTestCase {
    func testCameraCentresOnPlayer() {
        let origin = Camera.origin(following: GridPoint(x: 20, y: 15), mapWidth: 40, mapHeight: 30)
        XCTAssertEqual(origin, GridPoint(x: 13, y: 10))
    }

    func testCameraClampsAtMapEdges() {
        let topLeft = Camera.origin(following: GridPoint(x: 0, y: 0), mapWidth: 40, mapHeight: 30)
        XCTAssertEqual(topLeft, GridPoint(x: 0, y: 0))
        let bottomRight = Camera.origin(following: GridPoint(x: 39, y: 29), mapWidth: 40, mapHeight: 30)
        XCTAssertEqual(bottomRight, GridPoint(x: 25, y: 20))
    }
}
