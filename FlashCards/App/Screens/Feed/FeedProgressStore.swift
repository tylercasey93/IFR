// App/Screens/Feed/FeedProgressStore.swift
import Foundation
import Observation

/// Watched/quiz state for the video feed, persisted to UserDefaults under a
/// namespaced key (same lightweight approach as GameCenter's PendingScores —
/// this is convenience state, deliberately outside the SwiftData store).
@Observable @MainActor
final class FeedProgressStore {
    private struct Snapshot: Codable {
        var watched: Set<String> = []
        var quizCorrect: [String: Bool] = [:]
    }

    private static let defaultsKey = "feedProgress.v1"
    private var snapshot: Snapshot

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
           let decoded = try? JSONDecoder().decode(Snapshot.self, from: data) {
            snapshot = decoded
        } else {
            snapshot = Snapshot()
        }
    }

    var watchedCount: Int { snapshot.watched.count }

    func isWatched(_ lessonID: String) -> Bool {
        snapshot.watched.contains(lessonID)
    }

    func markWatched(_ lessonID: String) {
        guard !snapshot.watched.contains(lessonID) else { return }
        snapshot.watched.insert(lessonID)
        save()
    }

    /// Latest result for a quiz question, keyed lessonID#index. nil = unanswered.
    func quizResult(lessonID: String, questionIndex: Int) -> Bool? {
        snapshot.quizCorrect["\(lessonID)#\(questionIndex)"]
    }

    func recordQuiz(lessonID: String, questionIndex: Int, correct: Bool) {
        snapshot.quizCorrect["\(lessonID)#\(questionIndex)"] = correct
        save()
    }

    /// True when every quiz question of the lesson has been answered correctly
    /// at least once (its latest answer was correct).
    func passedQuiz(_ lesson: FeedLesson) -> Bool {
        lesson.quiz.indices.allSatisfy { quizResult(lessonID: lesson.id, questionIndex: $0) == true }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }
}
