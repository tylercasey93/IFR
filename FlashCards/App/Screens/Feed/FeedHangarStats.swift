// App/Screens/Feed/FeedHangarStats.swift
import Foundation

/// Aggregates feed progress for the Progress tab's Hangar section. Pure
/// compute over closures (not the store itself) so it's trivially
/// unit-testable without UserDefaults.
struct FeedHangarStats {
    struct TopicStat: Identifiable {
        let topicArea: String
        let watched: Int
        let total: Int
        let quizAnswered: Int
        let quizCorrect: Int

        var id: String { topicArea }

        /// Mean of watched-fraction and latest-answer-correct fraction; an
        /// unanswered topic counts its quiz half as zero.
        var ringProgress: Double {
            guard total > 0 else { return 0 }
            let watchedFraction = Double(watched) / Double(total)
            let correctFraction = quizAnswered > 0 ? Double(quizCorrect) / Double(quizAnswered) : 0
            return (watchedFraction + correctFraction) / 2
        }
    }

    let lessonsWatched: Int
    let lessonsTotal: Int
    /// Latest-answer accuracy across all answered feed questions; nil before
    /// any answer exists.
    let quizAccuracy: Double?
    /// First-appearance order, video lessons only.
    let topics: [TopicStat]

    static func compute(lessons: [FeedLesson],
                        isWatched: (String) -> Bool,
                        quizResult: (String, Int) -> Bool?) -> FeedHangarStats {
        let videoLessons = lessons.filter(\.hasVideo)

        var topicOrder: [String] = []
        var byTopic: [String: [FeedLesson]] = [:]
        for lesson in videoLessons {
            if byTopic[lesson.topicArea] == nil { topicOrder.append(lesson.topicArea) }
            byTopic[lesson.topicArea, default: []].append(lesson)
        }

        var totalAnswered = 0
        var totalCorrect = 0
        let topics = topicOrder.map { topic -> TopicStat in
            let group = byTopic[topic] ?? []
            var answered = 0
            var correct = 0
            for lesson in group {
                for index in lesson.quiz.indices {
                    if let result = quizResult(lesson.id, index) {
                        answered += 1
                        if result { correct += 1 }
                    }
                }
            }
            totalAnswered += answered
            totalCorrect += correct
            return TopicStat(topicArea: topic,
                             watched: group.filter { isWatched($0.id) }.count,
                             total: group.count,
                             quizAnswered: answered,
                             quizCorrect: correct)
        }

        return FeedHangarStats(
            lessonsWatched: videoLessons.filter { isWatched($0.id) }.count,
            lessonsTotal: videoLessons.count,
            quizAccuracy: totalAnswered > 0 ? Double(totalCorrect) / Double(totalAnswered) : nil,
            topics: topics
        )
    }
}
