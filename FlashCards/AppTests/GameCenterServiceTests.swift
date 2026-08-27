// AppTests/GameCenterServiceTests.swift
import XCTest
@testable import IFRFlashCards

/// Exercises GameCenterService's flush logic through the injected submit seam;
/// no GameKit involved. Queue state is asserted through the same UserDefaults
/// keys PendingScores persists to.
@MainActor
final class GameCenterServiceTests: XCTestCase {
    private func makeDefaults(_ name: String = #function) -> UserDefaults {
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func pendingScores(in defaults: UserDefaults) -> [String: Int] {
        defaults.dictionary(forKey: "pendingScores") as? [String: Int] ?? [:]
    }

    /// Flushes run in a MainActor Task; sleeping suspends this test so those
    /// tasks can make progress.
    private func waitUntil(timeout: TimeInterval = 2, _ condition: () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    func testSuccessfulFlushSubmitsAllBoardsAndEmptiesQueue() async {
        let defaults = makeDefaults()
        var submitted: [String: [Int]] = [:]
        let service = GameCenterService(defaults: defaults) { score, leaderboardID in
            submitted[leaderboardID, default: []].append(score)
        }
        service.isAuthenticated = true
        service.submitCurrentScores(weekly: 120, allTime: 900, longestStreak: 7)

        await waitUntil { self.pendingScores(in: defaults).isEmpty }
        XCTAssertEqual(submitted["ifr.weekly.xp"], [120])
        XCTAssertEqual(submitted["ifr.alltime.xp"], [900])
        XCTAssertEqual(submitted["ifr.longest.streak"], [7])
        XCTAssertTrue(pendingScores(in: defaults).isEmpty)
    }

    func testFailedFlushKeepsScoresQueuedForRetry() async {
        struct SubmitError: Error {}
        let defaults = makeDefaults()
        var attempts = 0
        let service = GameCenterService(defaults: defaults) { _, _ in
            attempts += 1
            throw SubmitError()
        }
        service.isAuthenticated = true
        service.submitCurrentScores(weekly: 120, allTime: 900, longestStreak: 7)

        await waitUntil { attempts >= 1 }
        // No retry-loop on failure — one attempt per trigger, scores stay queued.
        XCTAssertEqual(attempts, 1)
        XCTAssertEqual(pendingScores(in: defaults)["ifr.weekly.xp"], 120)
        XCTAssertEqual(pendingScores(in: defaults)["ifr.alltime.xp"], 900)
        XCTAssertEqual(pendingScores(in: defaults)["ifr.longest.streak"], 7)
    }

    func testHigherScoreDuringFlushIsResubmittedAutomatically() async {
        let defaults = makeDefaults()
        var weeklySubmissions: [Int] = []
        var injectedMidFlight = false
        var service: GameCenterService!
        service = GameCenterService(defaults: defaults) { score, leaderboardID in
            guard leaderboardID == "ifr.weekly.xp" else { return }
            weeklySubmissions.append(score)
            if !injectedMidFlight {
                injectedMidFlight = true
                // A study answer lands while this flush is in flight.
                service.submitCurrentScores(weekly: 150, allTime: 900, longestStreak: 7)
            }
        }
        service.isAuthenticated = true
        service.submitCurrentScores(weekly: 100, allTime: 900, longestStreak: 7)

        // The mid-flight 150 must go out without another XP event.
        await waitUntil { weeklySubmissions.contains(150) }
        XCTAssertEqual(weeklySubmissions, [100, 150])
        await waitUntil { self.pendingScores(in: defaults).isEmpty }
        XCTAssertTrue(pendingScores(in: defaults).isEmpty)
    }

    func testStaleWeeklyScoreFromPreviousWeekIsNeverSubmitted() async {
        let defaults = makeDefaults()
        // An unflushed weekly score persisted last week (e.g. offline Sunday
        // session, app closed before sign-in succeeded).
        let lastWeek = StudyStore.mondayWeekStart(for: .now, calendar: .current)
            .addingTimeInterval(-7 * 86_400)
        var seed = PendingScores(defaults: defaults)
        seed.record(leaderboardID: "ifr.weekly.xp", score: 500, weekStart: lastWeek)

        var weeklySubmissions: [Int] = []
        let service = GameCenterService(defaults: defaults) { score, leaderboardID in
            if leaderboardID == "ifr.weekly.xp" { weeklySubmissions.append(score) }
        }
        service.isAuthenticated = true
        // First study of the new week: the fresh weekly total is lower and
        // must win — last week's 500 belongs to a finished occurrence.
        service.submitCurrentScores(weekly: 20, allTime: 900, longestStreak: 7)

        await waitUntil { !weeklySubmissions.isEmpty }
        XCTAssertEqual(weeklySubmissions, [20])
    }
}
