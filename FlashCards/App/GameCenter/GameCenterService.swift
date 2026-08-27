// App/GameCenter/GameCenterService.swift
import Foundation
import GameKit
import os
import UIKit

enum LeaderboardID {
    static let weeklyXP = "ifr.weekly.xp"
    static let allTimeXP = "ifr.alltime.xp"
    static let longestStreak = "ifr.longest.streak"
    static let all = [weeklyXP, allTimeXP, longestStreak]
}

/// Highest-score-wins outbox for offline submissions, persisted to UserDefaults.
///
/// Entries recorded with a `weekStart` belong to one occurrence of a weekly
/// recurring leaderboard. A stamp from a different week means that occurrence
/// has ended, so the entry is replaced or purged instead of max-merged —
/// otherwise last week's high score would be credited to the new week's board.
struct PendingScores {
    private static let key = "pendingScores"
    private static let weeksKey = "pendingScoreWeeks"
    private let defaults: UserDefaults
    private(set) var pending: [String: Int]
    private(set) var weeks: [String: Date]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        pending = defaults.dictionary(forKey: Self.key) as? [String: Int] ?? [:]
        weeks = defaults.dictionary(forKey: Self.weeksKey) as? [String: Date] ?? [:]
    }

    mutating func record(leaderboardID: String, score: Int, weekStart: Date? = nil) {
        // An existing entry stamped with a different week (or unstamped — data
        // persisted before stamps existed) predates this occurrence: start
        // fresh rather than max-merge across the weekly reset.
        if let weekStart, weeks[leaderboardID] != weekStart {
            pending[leaderboardID] = nil
            weeks[leaderboardID] = weekStart
        }
        pending[leaderboardID] = max(score, pending[leaderboardID] ?? 0)
        persist()
    }

    /// Removes the entry only if its pending value still equals `submitted` —
    /// a higher score recorded while the flush was in flight survives for the
    /// next flush instead of being silently dropped.
    mutating func confirm(leaderboardID: String, submitted: Int) {
        guard pending[leaderboardID] == submitted else { return }
        pending[leaderboardID] = nil
        weeks[leaderboardID] = nil
        persist()
    }

    /// Drops week-stamped entries whose occurrence has ended.
    mutating func removeExpired(currentWeekStart: Date) {
        for (leaderboardID, week) in weeks where week != currentWeekStart {
            pending[leaderboardID] = nil
            weeks[leaderboardID] = nil
        }
        persist()
    }

    mutating func clear() {
        pending = [:]
        weeks = [:]
        defaults.removeObject(forKey: Self.key)
        defaults.removeObject(forKey: Self.weeksKey)
    }

    private mutating func persist() {
        defaults.set(pending, forKey: Self.key)
        defaults.set(weeks, forKey: Self.weeksKey)
    }
}

struct LeaderboardEntry: Identifiable {
    let id: Int
    let rank: Int
    let displayName: String
    let score: Int
    let isLocalPlayer: Bool
}

@Observable
@MainActor
final class GameCenterService {
    private static let logger = Logger(subsystem: "com.tylercasey.ifrflashcards",
                                       category: "gamecenter")

    var isAuthenticated = false
    private var queue: PendingScores
    private var isFlushing = false
    /// Injection seam for tests; production submits through GameKit.
    private let submit: (_ score: Int, _ leaderboardID: String) async throws -> Void

    init(defaults: UserDefaults = .standard,
         submit: @escaping (_ score: Int, _ leaderboardID: String) async throws -> Void = { score, leaderboardID in
             try await GKLeaderboard.submitScore(score, context: 0,
                                                 player: GKLocalPlayer.local,
                                                 leaderboardIDs: [leaderboardID])
         }) {
        queue = PendingScores(defaults: defaults)
        self.submit = submit
    }

    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            guard let self else { return }
            if let error {
                Self.logger.error("Game Center auth failed: \(error, privacy: .public)")
            }
            if let viewController {
                self.present(viewController)
                return
            }
            // Trust the player state alone: GameKit re-invokes this handler on
            // every return to foreground, and a transient network error there
            // must not flip an authenticated player to signed-out for the rest
            // of the session.
            self.isAuthenticated = GKLocalPlayer.local.isAuthenticated
            Self.logger.info("Game Center authenticated: \(self.isAuthenticated)")
            if self.isAuthenticated { self.flushQueue() }
        }
    }

    /// Presents the GameKit sign-in controller on the top-most presented view
    /// controller — the root is covered whenever a sheet or the quiz
    /// fullScreenCover is up, and presenting on a covered root silently fails.
    /// At cold start no window may be key yet; retry briefly instead of
    /// dropping the controller (which made sign-in appear intermittent).
    private func present(_ viewController: UIViewController, attempt: Int = 0) {
        guard viewController.presentingViewController == nil else { return }
        if let top = Self.topPresenter() {
            top.present(viewController, animated: true)
        } else if attempt < 5 {
            Task {
                try? await Task.sleep(for: .milliseconds(500))
                self.present(viewController, attempt: attempt + 1)
            }
        } else {
            Self.logger.error("No window available to present Game Center sign-in")
        }
    }

    private static func topPresenter() -> UIViewController? {
        let root = UIApplication.shared.connectedScenes
            .compactMap { scene -> UIViewController? in
                guard let windowScene = scene as? UIWindowScene else { return nil }
                return (windowScene.keyWindow ?? windowScene.windows.first)?.rootViewController
            }
            .first
        guard var top = root else { return nil }
        while let presented = top.presentedViewController { top = presented }
        return top
    }

    func submitCurrentScores(weekly: Int, allTime: Int, longestStreak: Int) {
        queue.record(leaderboardID: LeaderboardID.weeklyXP, score: weekly,
                     weekStart: StudyStore.mondayWeekStart(for: .now, calendar: .current))
        queue.record(leaderboardID: LeaderboardID.allTimeXP, score: allTime)
        queue.record(leaderboardID: LeaderboardID.longestStreak, score: longestStreak)
        if isAuthenticated { flushQueue() }
    }

    private func flushQueue() {
        guard !isFlushing else { return }
        // A queued weekly score that crossed the Monday reset belongs to a
        // finished occurrence — drop it rather than credit it to the new week.
        queue.removeExpired(currentWeekStart: StudyStore.mondayWeekStart(for: .now, calendar: .current))
        let scores = queue.pending
        guard !scores.isEmpty else { return }
        isFlushing = true
        Task {
            do {
                for (leaderboardID, score) in scores {
                    try await submit(score, leaderboardID)
                    // Per-board confirmation: only removes the entry if no
                    // higher score was recorded while this flush was in flight.
                    queue.confirm(leaderboardID: leaderboardID, submitted: score)
                }
            } catch {
                Self.logger.error("Score submit failed: \(error, privacy: .public)")
                isFlushing = false
                return  // remainder stays queued; retried on next submit or auth
            }
            isFlushing = false
            // Scores recorded while this flush was in flight would otherwise
            // wait for the next XP event — possibly the next launch. Resubmit
            // now; success-only, so a dead network can't retry-loop.
            if !queue.pending.isEmpty { flushQueue() }
        }
    }

    func loadEntries(leaderboardID: String) async -> [LeaderboardEntry] {
        guard isAuthenticated else { return [] }
        do {
            let boards = try await GKLeaderboard.loadLeaderboards(IDs: [leaderboardID])
            guard let board = boards.first else { return [] }
            let (_, entries, _) = try await board.loadEntries(for: .global, timeScope: .allTime,
                                                              range: NSRange(location: 1, length: 10))
            return entries.enumerated().map { index, entry in
                LeaderboardEntry(id: index, rank: entry.rank,
                                 displayName: entry.player.displayName,
                                 score: entry.score,
                                 isLocalPlayer: entry.player.gamePlayerID == GKLocalPlayer.local.gamePlayerID)
            }
        } catch {
            Self.logger.error("Leaderboard \(leaderboardID, privacy: .public) load failed: \(error, privacy: .public)")
            return []
        }
    }
}
