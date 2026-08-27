// App/Screens/Feed/FeedModels.swift
import Foundation

/// One "IFR in 30 Seconds" lesson as packaged by the video pipeline into
/// FeedMedia/lessons.json (see video-pipeline/scripts/build-app-content.mjs).
struct FeedLesson: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let topicArea: String
    let hook: String
    let hasVideo: Bool
    let references: FeedReferences
    let quiz: [FeedQuizQuestion]

    /// Bundle URL for this lesson's MP4, resolved against the FeedMedia
    /// folder reference. nil when the video wasn't rendered/bundled.
    var videoURL: URL? {
        guard hasVideo else { return nil }
        return Bundle.main.url(forResource: id, withExtension: "mp4",
                               subdirectory: "FeedMedia/Videos")
    }
}

struct FeedReferences: Codable, Hashable {
    let acs: [String]
    let faa: FeedFAAReference
}

struct FeedFAAReference: Codable, Hashable {
    let source: String
    let title: String
}

struct FeedQuizQuestion: Codable, Hashable {
    let question: String
    let choices: [String]
    let correctIndex: Int
    let explanation: String
}

/// A single page of the vertical feed: a lesson video, or one of its quiz
/// questions interleaved right after it.
enum FeedItem: Identifiable, Hashable {
    case video(FeedLesson)
    case quiz(FeedLesson, questionIndex: Int)

    var id: String {
        switch self {
        case .video(let lesson): return lesson.id
        case .quiz(let lesson, let index): return "\(lesson.id)#quiz\(index)"
        }
    }

    var lesson: FeedLesson {
        switch self {
        case .video(let lesson), .quiz(let lesson, _): return lesson
        }
    }
}

enum FeedContent {
    /// Decodes the bundled lesson pack. Missing pack (e.g. FeedMedia not yet
    /// generated) is a valid state — the feed shows an empty-state message.
    static func load() -> [FeedLesson] {
        guard let url = Bundle.main.url(forResource: "lessons", withExtension: "json",
                                        subdirectory: "FeedMedia"),
              let data = try? Data(contentsOf: url),
              let pack = try? JSONDecoder().decode(FeedLessonPack.self, from: data) else {
            return []
        }
        return pack.lessons
    }

    /// Videos first in authored order, each followed by its quiz questions.
    static func buildItems(from lessons: [FeedLesson]) -> [FeedItem] {
        var items: [FeedItem] = []
        for lesson in lessons where lesson.hasVideo {
            items.append(.video(lesson))
            for index in lesson.quiz.indices {
                items.append(.quiz(lesson, questionIndex: index))
            }
        }
        return items
    }
}

private struct FeedLessonPack: Codable {
    let version: Int
    let lessons: [FeedLesson]
}
