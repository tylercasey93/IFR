import XCTest
@testable import IFRCore

final class DirectionTests: XCTestCase {
    func testDirectionDeltaAndOpposite() {
        XCTAssertEqual(Direction.up.delta, GridPoint(x: 0, y: -1))
        XCTAssertEqual(Direction.down.delta, GridPoint(x: 0, y: 1))
        XCTAssertEqual(Direction.left.delta, GridPoint(x: -1, y: 0))
        XCTAssertEqual(Direction.right.delta, GridPoint(x: 1, y: 0))
        XCTAssertEqual(Direction.up.opposite, .down)
        XCTAssertEqual(Direction.down.opposite, .up)
        XCTAssertEqual(Direction.left.opposite, .right)
        XCTAssertEqual(Direction.right.opposite, .left)
    }
}
