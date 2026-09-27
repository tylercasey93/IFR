import XCTest
@testable import IFRCore

final class PlayerHPTests: XCTestCase {
    func testMaximumHPGrowsTenPerMasteryLevel() {
        let expected = [100, 110, 120, 130, 140]
        let actual = MasteryLevel.allCases.map { PlayerHP.maximum(for: $0) }
        XCTAssertEqual(actual, expected)
    }

    func testMissDamageByTier() {
        let expected = [20, 30, 30, 30, 20, 30, 1]
        let actual: [BattleTier] = [.cloud, .trainer, .gym, .eliteFour, .tower, .link, .champion]
        XCTAssertEqual(actual.map(\.missDamage), expected)
    }

    func testChampionTierDealsOneForAnyHit() {
        let crit = Damage.hit(difficulty: 3, answerSeconds: 5)
        XCTAssertEqual(crit.amount, 18)
        XCTAssertEqual(BattleTier.champion.damage(for: crit), 1)
    }
}
