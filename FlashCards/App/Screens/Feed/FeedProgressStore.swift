// App/Screens/Feed/FeedProgressStore.swift
import Foundation
import Observation

/// Watched/quiz/pre-flight state for the video feed, persisted to UserDefaults
/// under a namespaced key (same lightweight approach as GameCenter's
/// PendingScores — this is convenience state, deliberately outside SwiftData).
/// App-lifetime instance created in IFRFlashCardsApp so the feed, Progress
/// tab, and quiz cards share one live source of truth.
@Observable @MainActor
final class FeedProgressStore {
    private struct Snapshot: Codable {
        var watched: Set<String> = []
        var quizCorrect: [String: Bool] = [:]
        // v2 fields MUST stay Optional: synthesized Codable fails decoding on
        // missing keys for non-optionals (defaults don't apply), which would
        // silently wipe every v1 user's progress.
        var watchedAt: [String: Date]?
        var preflight: [String: Bool]?
        var xpAwardedQuiz: Set<String>?
    }

    private static let defaultsKey = "feedProgress.v1"
    private let defaults: UserDefaults
    private var snapshot: Snapshot

    /// Correct-answer streak for the current feed visit. Deliberately
    /// transient (not persisted): it powers Duke's escalating quips only.
    var sessionStreak = 0

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.defaultsKey),
           let decoded = try? JSONDecoder().decode(Snapshot.self, from: data) {
            snapshot = decoded
        } else {
            snapshot = Snapshot()
        }
    }

    // MARK: - Watched

    var watchedCount: Int { snapshot.watched.count }

    func isWatched(_ lessonID: String) -> Bool {
        snapshot.watched.contains(lessonID)
    }

    /// First-watch date; .distantPast for lessons watched before timestamps
    /// existed (treated as most stale by feed ordering); nil if unwatched.
    func watchedDate(_ lessonID: String) -> Date? {
        guard snapshot.watched.contains(lessonID) else { return nil }
        return snapshot.watchedAt?[lessonID] ?? .distantPast
    }

    func markWatched(_ lessonID: String) {
        guard !snapshot.watched.contains(lessonID) else { return }
        snapshot.watched.insert(lessonID)
        snapshot.watchedAt = snapshot.watchedAt ?? [:]
        snapshot.watchedAt?[lessonID] = .now
        save()
    }

    // MARK: - Quiz results

    /// Latest result for a quiz question, keyed lessonID#index. nil = unanswered.
    func quizResult(lessonID: String, questionIndex: Int) -> Bool? {
        snapshot.quizCorrect["\(lessonID)#\(questionIndex)"]
    }

    func recordQuiz(lessonID: String, questionIndex: Int, correct: Bool) {
        snapshot.quizCorrect["\(lessonID)#\(questionIndex)"] = correct
        save()
    }

    /// True when the lesson's latest answer on any question is wrong —
    /// the "needs review" signal for feed ordering.
    func hasWrongLatestAnswer(_ lesson: FeedLesson) -> Bool {
        lesson.quiz.indices.contains { quizResult(lessonID: lesson.id, questionIndex: $0) == false }
    }

    /// True when every quiz question of the lesson has been answered correctly
    /// at least once (its latest answer was correct).
    func passedQuiz(_ lesson: FeedLesson) -> Bool {
        lesson.quiz.indices.allSatisfy { quizResult(lessonID: lesson.id, questionIndex: $0) == true }
    }

    // MARK: - Pre-flight (pretest before the video)

    /// First answer wins: the pre-flight is a diagnostic of what you knew
    /// BEFORE the lesson, so re-answers never overwrite it.
    func recordPreflight(lessonID: String, correct: Bool) {
        guard snapshot.preflight?[lessonID] == nil else { return }
        snapshot.preflight = snapshot.preflight ?? [:]
        snapshot.preflight?[lessonID] = correct
        save()
    }

    func preflightResult(_ lessonID: String) -> Bool? {
        snapshot.preflight?[lessonID]
    }

    // MARK: - XP dedupe

    /// Claims the one-time XP award for a correctly answered feed question.
    /// Returns true only on the first claim, closing the answer-again-for-XP loop.
    @discardableResult
    func claimQuizXP(lessonID: String, questionIndex: Int) -> Bool {
        let key = "\(lessonID)#\(questionIndex)"
        if snapshot.xpAwardedQuiz?.contains(key) == true { return false }
        snapshot.xpAwardedQuiz = snapshot.xpAwardedQuiz ?? []
        snapshot.xpAwardedQuiz?.insert(key)
        save()
        return true
    }

    private func save() {
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: Self.defaultsKey)
        }
    }
}
