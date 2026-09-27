import XCTest
@testable import IFRCore

final class BattleWipeTests: XCTestCase {
    func testTotalWipeFramesIsForty() {
        XCTAssertEqual(BattleWipe.totalFrames, 40)
    }

    func testFirstSixteenFramesAlternateFlashEveryFourFrames() {
        XCTAssertEqual(BattleWipe.frame(0).flashWhite, true)
        XCTAssertEqual(BattleWipe.frame(3).flashWhite, true)
        XCTAssertEqual(BattleWipe.frame(4).flashWhite, false)
        XCTAssertEqual(BattleWipe.frame(7).flashWhite, false)
        XCTAssertEqual(BattleWipe.frame(8).flashWhite, true)
        XCTAssertEqual(BattleWipe.frame(12).flashWhite, false)
        XCTAssertEqual(BattleWipe.frame(15).flashWhite, false)
        XCTAssertEqual(BattleWipe.frame(16).flashWhite, nil)
    }

    func testBandsCloseTowardCentreOverTwentyFourFrames() {
        func coveredCount(_ n: Int) -> Int {
            BattleWipe.frame(n).coveredRows.reduce(0) { $0 + $1.count }
        }
        XCTAssertEqual(coveredCount(16), 0)
        XCTAssertLessThan(coveredCount(20), coveredCount(30))
        XCTAssertLessThan(coveredCount(30), coveredCount(39))
    }

    func testFinalWipeFrameCoversEveryRow() {
        let frame = BattleWipe.frame(39)
        var covered = Set<Int>()
        for range in frame.coveredRows {
            covered.formUnion(range)
        }
        XCTAssertEqual(covered, Set(0..<PixelFrame.height))
    }
}
