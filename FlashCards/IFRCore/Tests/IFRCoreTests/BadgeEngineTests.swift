// IFRCore/Tests/IFRCoreTests/BadgeEngineTests.swift
import XCTest
@testable import IFRCore

final class BadgeEngineTests: XCTestCase {
    private func snapshot(
        totalReviews: Int = 0, streak: Int = 0, lastQuizPerfect: Bool = false,
        mockExamPassed: Bool = false, masteredCategories: Int = 0, hourOfDay: Int = 12,
        totalXP: Int = 0, quizzesCompleted: Int = 0, daysAwayBeforeToday: Int = 0,
        gymBadges: Int = 0, eliteFourCleared: Bool = false, championDefeated: Bool = false,
        bestTowerFloor: Int = 0
    ) -> BadgeSnapshot {
        BadgeSnapshot(totalReviews: totalReviews, streak: streak, lastQuizPerfect: lastQuizPerfect,
                      mockExamPassed: mockExamPassed, masteredCategories: masteredCategories,
                      hourOfDay: hourOfDay, totalXP: totalXP, quizzesCompleted: quizzesCompleted,
                      daysAwayBeforeToday: daysAwayBeforeToday, gymBadges: gymBadges,
                      eliteFourCleared: eliteFourCleared, championDefeated: championDefeated,
                      bestTowerFloor: bestTowerFloor)
    }

    private func nineLabelSnapshot() -> BadgeSnapshot {
        BadgeSnapshot(totalReviews: 1, streak: 0, lastQuizPerfect: false,
                      mockExamPassed: false, masteredCategories: 0, hourOfDay: 12,
                      totalXP: 0, quizzesCompleted: 0, daysAwayBeforeToday: 0)
    }

    func testFirstSessionBadge() {
        XCTAssertTrue(BadgeEngine.newlyEarned(snapshot: snapshot(totalReviews: 1), already: []).contains(.firstSession))
    }

    func testAlreadyEarnedNotReturned() {
        XCTAssertFalse(BadgeEngine.newlyEarned(snapshot: snapshot(totalReviews: 5), already: [.firstSession]).contains(.firstSession))
    }

    func testStreakBadges() {
        let earned = BadgeEngine.newlyEarned(snapshot: snapshot(streak: 30), already: [])
        XCTAssertTrue(earned.contains(.streak7))
        XCTAssertTrue(earned.contains(.streak30))
        XCTAssertFalse(earned.contains(.streak100))
    }

    func testHourBadges() {
        XCTAssertTrue(BadgeEngine.newlyEarned(snapshot: snapshot(totalReviews: 1, hourOfDay: 5), already: []).contains(.earlyBird))
        XCTAssertTrue(BadgeEngine.newlyEarned(snapshot: snapshot(totalReviews: 1, hourOfDay: 23), already: []).contains(.nightOwl))
        XCTAssertFalse(BadgeEngine.newlyEarned(snapshot: snapshot(totalReviews: 1, hourOfDay: 12), already: []).contains(.nightOwl))
    }

    func testComebackNeedsSevenDaysAway() {
        XCTAssertTrue(BadgeEngine.newlyEarned(snapshot: snapshot(totalReviews: 1, daysAwayBeforeToday: 7), already: []).contains(.comeback))
        XCTAssertFalse(BadgeEngine.newlyEarned(snapshot: snapshot(totalReviews: 1, daysAwayBeforeToday: 3), already: []).contains(.comeback))
    }

    func testMilestoneBadges() {
        let earned = BadgeEngine.newlyEarned(
            snapshot: snapshot(totalReviews: 500, lastQuizPerfect: true, mockExamPassed: true,
                               masteredCategories: 8, totalXP: 10_000, quizzesCompleted: 10),
            already: [])
        for badge in [Badge.reviews100, .reviews500, .perfectQuiz, .mockExamPassed,
                      .categoryMastered, .allCategoriesMastered, .xp10k, .quizzes10] {
            XCTAssertTrue(earned.contains(badge), "\(badge) should be earned")
        }
    }

    func testGymBadgeThresholdsAtOneFourEight() {
        let one = BadgeEngine.newlyEarned(snapshot: snapshot(gymBadges: 1), already: [])
        XCTAssertTrue(one.contains(.firstGymBadge))
        XCTAssertFalse(one.contains(.fourGymBadges))
        XCTAssertFalse(one.contains(.allGymBadges))

        let four = BadgeEngine.newlyEarned(snapshot: snapshot(gymBadges: 4), already: [])
        XCTAssertTrue(four.contains(.firstGymBadge))
        XCTAssertTrue(four.contains(.fourGymBadges))
        XCTAssertFalse(four.contains(.allGymBadges))

        let eight = BadgeEngine.newlyEarned(snapshot: snapshot(gymBadges: 8), already: [])
        XCTAssertTrue(eight.contains(.firstGymBadge))
        XCTAssertTrue(eight.contains(.fourGymBadges))
        XCTAssertTrue(eight.contains(.allGymBadges))
    }

    func testEliteFourAndChampionBadges() {
        let eliteFour = BadgeEngine.newlyEarned(snapshot: snapshot(eliteFourCleared: true), already: [])
        XCTAssertTrue(eliteFour.contains(.eliteFourCleared))
        XCTAssertFalse(eliteFour.contains(.regionChampion))

        let champion = BadgeEngine.newlyEarned(snapshot: snapshot(championDefeated: true), already: [])
        XCTAssertTrue(champion.contains(.regionChampion))
        XCTAssertFalse(champion.contains(.eliteFourCleared))
    }

    func testTowerFloorTenBadge() {
        XCTAssertFalse(BadgeEngine.newlyEarned(snapshot: snapshot(bestTowerFloor: 9), already: []).contains(.towerFloor10))
        XCTAssertTrue(BadgeEngine.newlyEarned(snapshot: snapshot(bestTowerFloor: 10), already: []).contains(.towerFloor10))
    }

    func testExistingSnapshotInitStillCompilesWithNineLabels() {
        let earned = BadgeEngine.newlyEarned(snapshot: nineLabelSnapshot(), already: [])
        XCTAssertTrue(earned.contains(.firstSession))
    }

    func testZeroAdventureStatsEarnNoAdventureBadges() {
        let earned = BadgeEngine.newlyEarned(snapshot: snapshot(), already: [])
        for badge in [Badge.firstGymBadge, .fourGymBadges, .allGymBadges,
                      .eliteFourCleared, .regionChampion, .towerFloor10] {
            XCTAssertFalse(earned.contains(badge), "\(badge) should not be earned")
        }
    }
}
