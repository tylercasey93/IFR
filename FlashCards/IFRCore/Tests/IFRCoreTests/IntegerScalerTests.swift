import XCTest
@testable import IFRCore

final class IntegerScalerTests: XCTestCase {
    func testIPhoneFifteenWidthAtThreeXGivesScaleFour() {
        let scale = IntegerScaler.scale(viewWidth: 393, viewHeight: 700, displayScale: 3)
        XCTAssertEqual(scale, 4)
    }

    func testScaleNeverBelowOne() {
        let scale = IntegerScaler.scale(viewWidth: 100, viewHeight: 100, displayScale: 1)
        XCTAssertEqual(scale, 1)
    }

    func testHeightConstrainedViewUsesSmallerAxis() {
        let scale = IntegerScaler.scale(viewWidth: 1000, viewHeight: 200, displayScale: 1)
        XCTAssertEqual(scale, 1)
    }

    func testCanvasSizeIsExactMultipleOfLogicalSize() {
        let size = IntegerScaler.canvasSize(scale: 4, displayScale: 3)
        XCTAssertEqual(size.width, 320, accuracy: 0.001)
        XCTAssertEqual(size.height, 213.333, accuracy: 0.001)
    }
}
