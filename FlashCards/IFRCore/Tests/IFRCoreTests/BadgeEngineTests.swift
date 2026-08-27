// IFRCore/Tests/IFRCoreTests/BadgeEngineTests.swift
import XCTest
@testable import IFRCore

final class BadgeEngineTests: XCTestCase {
    private func snapshot(
        totalReviews: Int = 0, streak: Int = 0, lastQuizPerfect: Bool = false,
        mockExamPassed: Bool = false, masteredCategories: Int = 0, hourOfDay: Int = 12,
        totalXP: Int = 0, quizzesCompleted: Int = 0, daysAwayBeforeToday: Int = 0
    ) -> BadgeSnapshot {
        BadgeSnapshot(totalReviews: totalReviews, streak: streak, lastQuizPerfect: lastQuizPerfect,
                      mockExamPassed: mockExamPassed, masteredCategories: masteredCategories,
                      hourOfDay: hourOfDay, totalXP: totalXP, quizzesCompleted: quizzesCompleted,
                      daysAwayBeforeToday: daysAwayBeforeToday)
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
}
