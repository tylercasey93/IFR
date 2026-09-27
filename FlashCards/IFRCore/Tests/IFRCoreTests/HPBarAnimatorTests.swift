import XCTest
@testable import IFRCore

final class HPBarAnimatorTests: XCTestCase {
    func testDisplayedHPStepsOneEveryTwoFrames() {
        XCTAssertEqual(HPBarAnimator.displayedHP(from: 20, to: 5, framesElapsed: 0), 20)
        XCTAssertEqual(HPBarAnimator.displayedHP(from: 20, to: 5, framesElapsed: 2), 19)
        XCTAssertEqual(HPBarAnimator.displayedHP(from: 20, to: 5, framesElapsed: 4), 18)
        XCTAssertEqual(HPBarAnimator.displayedHP(from: 0, to: 10, framesElapsed: 4), 2)
    }

    func testDisplayedHPNeverOvershootsTarget() {
        XCTAssertEqual(HPBarAnimator.displayedHP(from: 20, to: 5, framesElapsed: 100), 5)
        XCTAssertEqual(HPBarAnimator.displayedHP(from: 0, to: 10, framesElapsed: 100), 10)
    }

    func testFilledPixelsFloorsToWidth() {
        XCTAssertEqual(HPBarAnimator.filledPixels(hp: 42, max: 42, width: 48), 48)
        XCTAssertEqual(HPBarAnimator.filledPixels(hp: 25, max: 50, width: 48), 24)
        XCTAssertEqual(HPBarAnimator.filledPixels(hp: 1, max: 48, width: 48), 1)
    }

    func testBandThresholdsAtFiftyAndTwentyPercent() {
        XCTAssertEqual(HPBarAnimator.band(hp: 51, max: 100), .green)
        XCTAssertEqual(HPBarAnimator.band(hp: 50, max: 100), .amber)
        XCTAssertEqual(HPBarAnimator.band(hp: 20, max: 100), .amber)
        XCTAssertEqual(HPBarAnimator.band(hp: 19, max: 100), .red)
    }

    func testShakeOffsetsAreMinusTwoTwoMinusOneOneZero() {
        XCTAssertEqual(HPBarAnimator.shakeOffset(atFrame: 0), -2)
        XCTAssertEqual(HPBarAnimator.shakeOffset(atFrame: 2), 2)
        XCTAssertEqual(HPBarAnimator.shakeOffset(atFrame: 4), -1)
        XCTAssertEqual(HPBarAnimator.shakeOffset(atFrame: 6), 1)
        XCTAssertEqual(HPBarAnimator.shakeOffset(atFrame: 8), 0)
        XCTAssertEqual(HPBarAnimator.shakeOffset(atFrame: 9), 0)
    }
}
