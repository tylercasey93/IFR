import XCTest
@testable import IFRCore

final class TrainerApproachTests: XCTestCase {
    func testApproachMovesOneTilePerStepAlongFacing() {
        let start = GridPoint(x: 1, y: 1)
        let player = GridPoint(x: 1, y: 10)
        XCTAssertEqual(TrainerApproach.position(from: start, toward: player, step: 0), start)
        XCTAssertEqual(TrainerApproach.position(from: start, toward: player, step: 1), GridPoint(x: 1, y: 2))
        XCTAssertEqual(TrainerApproach.position(from: start, toward: player, step: 2), GridPoint(x: 1, y: 3))
    }

    func testApproachStopsAdjacentToPlayer() {
        let start = GridPoint(x: 1, y: 1)
        let player = GridPoint(x: 1, y: 5)
        let adjacent = GridPoint(x: 1, y: 4)
        XCTAssertEqual(TrainerApproach.position(from: start, toward: player, step: 99), adjacent)
    }
}
