import XCTest
@testable import IFRCore

final class BattleAnimationTests: XCTestCase {
    func testIntroSlidesEnemyFromRightAndPlayerFromLeftInTwelveFrames() {
        XCTAssertEqual(BattleIntro.totalFrames, 12)
        let start = BattleIntro.slideOffset(atFrame: 0)
        XCTAssertEqual(start.enemyX, 240)
        XCTAssertEqual(start.playerX, -32)
        let end = BattleIntro.slideOffset(atFrame: 12)
        XCTAssertEqual(end.enemyX, 176)
        XCTAssertEqual(end.playerX, 24)
    }

    func testVictoryDropIsFourPixelsPerFrameThenNil() {
        XCTAssertEqual(VictoryAnimation.dropOffset(atFrame: 0), 4)
        XCTAssertEqual(VictoryAnimation.dropOffset(atFrame: 1), 8)
        XCTAssertEqual(VictoryAnimation.dropOffset(atFrame: 7), 32)
        XCTAssertNil(VictoryAnimation.dropOffset(atFrame: 8))
    }

    func testBadgeScaleGrowsOneToFourOverEightFrames() {
        XCTAssertEqual(VictoryAnimation.badgeScale(atFrame: 0), 1)
        XCTAssertEqual(VictoryAnimation.badgeScale(atFrame: 8), 4)
        XCTAssertLessThanOrEqual(VictoryAnimation.badgeScale(atFrame: 4), 4)
        XCTAssertGreaterThanOrEqual(VictoryAnimation.badgeScale(atFrame: 4), 1)
    }

    func testDefeatFadeStepReachesFifteenAtFrameThirty() {
        XCTAssertEqual(DefeatAnimation.totalFrames, 30)
        XCTAssertEqual(DefeatAnimation.fadeStep(atFrame: 0), 0)
        XCTAssertEqual(DefeatAnimation.fadeStep(atFrame: 30), 15)
    }
}
