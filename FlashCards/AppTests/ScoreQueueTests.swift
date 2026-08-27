// AppTests/ScoreQueueTests.swift
import XCTest
@testable import IFRFlashCards

final class ScoreQueueTests: XCTestCase {
    func testPendingScoresPersistAndKeepMax() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        var queue = PendingScores(defaults: defaults)
        queue.record(leaderboardID: "ifr.weekly.xp", score: 100)
        queue.record(leaderboardID: "ifr.weekly.xp", score: 80)   // lower — ignored
        queue.record(leaderboardID: "ifr.weekly.xp", score: 250)  // higher — kept
        queue.record(leaderboardID: "ifr.alltime.xp", score: 900)

        let reloaded = PendingScores(defaults: defaults)
        XCTAssertEqual(reloaded.pending["ifr.weekly.xp"], 250)
        XCTAssertEqual(reloaded.pending["ifr.alltime.xp"], 900)

        var mutable = reloaded
        mutable.clear()
        XCTAssertTrue(PendingScores(defaults: defaults).pending.isEmpty)
    }

    func testConfirmRemovesEntryOnlyWhenValueUnchanged() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        var queue = PendingScores(defaults: defaults)
        queue.record(leaderboardID: "ifr.weekly.xp", score: 100)
        queue.record(leaderboardID: "ifr.alltime.xp", score: 900)

        // A flush snapshotted weekly=100, then a higher score landed mid-flight.
        queue.record(leaderboardID: "ifr.weekly.xp", score: 150)

        // Confirming the stale snapshot value must NOT drop the newer score.
        queue.confirm(leaderboardID: "ifr.weekly.xp", submitted: 100)
        XCTAssertEqual(queue.pending["ifr.weekly.xp"], 150)

        // Confirming the still-current value removes the entry.
        queue.confirm(leaderboardID: "ifr.alltime.xp", submitted: 900)
        XCTAssertNil(queue.pending["ifr.alltime.xp"])

        // Both outcomes persist across reload.
        let reloaded = PendingScores(defaults: defaults)
        XCTAssertEqual(reloaded.pending, ["ifr.weekly.xp": 150])
    }

    func testWeekStampedEntryIsReplacedNotMaxMergedAcrossWeeks() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let week1 = Date(timeIntervalSinceReferenceDate: 0)
        let week2 = week1.addingTimeInterval(7 * 86_400)

        var queue = PendingScores(defaults: defaults)
        queue.record(leaderboardID: "ifr.weekly.xp", score: 500, weekStart: week1)
        // Same week: normal max-wins merge.
        queue.record(leaderboardID: "ifr.weekly.xp", score: 300, weekStart: week1)
        XCTAssertEqual(queue.pending["ifr.weekly.xp"], 500)

        // New week: last week's 500 must not beat this week's 20.
        queue.record(leaderboardID: "ifr.weekly.xp", score: 20, weekStart: week2)
        XCTAssertEqual(queue.pending["ifr.weekly.xp"], 20)
    }

    func testRemoveExpiredDropsOnlyStaleWeekStampedEntries() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let week1 = Date(timeIntervalSinceReferenceDate: 0)
        let week2 = week1.addingTimeInterval(7 * 86_400)

        var queue = PendingScores(defaults: defaults)
        queue.record(leaderboardID: "ifr.weekly.xp", score: 500, weekStart: week1)
        queue.record(leaderboardID: "ifr.alltime.xp", score: 900)  // unstamped — never expires

        // Stamps survive a reload (the stale-week scenario spans app launches).
        var reloaded = PendingScores(defaults: defaults)
        reloaded.removeExpired(currentWeekStart: week2)
        XCTAssertNil(reloaded.pending["ifr.weekly.xp"])
        XCTAssertEqual(reloaded.pending["ifr.alltime.xp"], 900)
        XCTAssertEqual(PendingScores(defaults: defaults).pending, ["ifr.alltime.xp": 900])
    }

    func testRemoveExpiredKeepsCurrentWeekEntry() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let week1 = Date(timeIntervalSinceReferenceDate: 0)

        var queue = PendingScores(defaults: defaults)
        queue.record(leaderboardID: "ifr.weekly.xp", score: 500, weekStart: week1)
        queue.removeExpired(currentWeekStart: week1)
        XCTAssertEqual(queue.pending["ifr.weekly.xp"], 500)
    }
}
