import XCTest
@testable import IFRCore

final class DamageTests: XCTestCase {
    func testBaseDamageIsEightTenTwelveByDifficulty() {
        XCTAssertEqual(Damage.hit(difficulty: 1, answerSeconds: 10).amount, 8)
        XCTAssertEqual(Damage.hit(difficulty: 2, answerSeconds: 10).amount, 10)
        XCTAssertEqual(Damage.hit(difficulty: 3, answerSeconds: 10).amount, 12)
    }

    func testCriticalUnderSixSecondsIsTwelveFifteenEighteen() {
        XCTAssertEqual(Damage.hit(difficulty: 1, answerSeconds: 5.9).amount, 12)
        XCTAssertEqual(Damage.hit(difficulty: 2, answerSeconds: 5.9).amount, 15)
        XCTAssertEqual(Damage.hit(difficulty: 3, answerSeconds: 5.9).amount, 18)
        XCTAssertTrue(Damage.hit(difficulty: 1, answerSeconds: 5.9).isCritical)
    }

    func testExactlySixSecondsIsNotCritical() {
        XCTAssertFalse(Damage.hit(difficulty: 1, answerSeconds: 6).isCritical)
        XCTAssertEqual(Damage.hit(difficulty: 1, answerSeconds: 6).amount, 8)
    }

    func testNegativeSecondsCountsAsCritical() {
        XCTAssertTrue(Damage.hit(difficulty: 1, answerSeconds: -1).isCritical)
        XCTAssertEqual(Damage.hit(difficulty: 1, answerSeconds: -1).amount, 12)
    }

    func testDifficultyThreeIsSuperEffective() {
        XCTAssertFalse(Damage.hit(difficulty: 1, answerSeconds: 10).isSuperEffective)
        XCTAssertFalse(Damage.hit(difficulty: 2, answerSeconds: 10).isSuperEffective)
        XCTAssertTrue(Damage.hit(difficulty: 3, answerSeconds: 10).isSuperEffective)
    }
}
