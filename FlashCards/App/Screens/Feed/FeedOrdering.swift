// App/Screens/Feed/FeedOrdering.swift
import Foundation

/// Spaced-repetition-aware feed ordering. Pure and deterministic so it's
/// unit-testable and never reshuffles under the user's thumb:
///  1) unwatched lessons, in authored order — new material first;
///  2) watched lessons whose latest quiz answer is wrong, authored order —
///     misses resurface next;
///  3) the rest, oldest first-watch first — staleness drives review timing.
enum FeedOrdering {
    struct LessonSignal {
        let watchedAt: Date?
        let hasWrongLatestAnswer: Bool
    }

    static func ordered(_ lessons: [FeedLesson],
                        signal: (FeedLesson) -> LessonSignal) -> [FeedLesson] {
        let keyed = lessons.enumerated().map { index, lesson -> (key: SortKey, lesson: FeedLesson) in
            let s = signal(lesson)
            let key: SortKey
            if s.watchedAt == nil {
                key = SortKey(bucket: 0, date: .distantPast, authored: index)
            } else if s.hasWrongLatestAnswer {
                key = SortKey(bucket: 1, date: .distantPast, authored: index)
            } else {
                key = SortKey(bucket: 2, date: s.watchedAt ?? .distantPast, authored: index)
            }
            return (key, lesson)
        }
        return keyed.sorted { $0.key < $1.key }.map(\.lesson)
    }

    private struct SortKey: Comparable {
        let bucket: Int
        let date: Date
        let authored: Int

        static func < (lhs: SortKey, rhs: SortKey) -> Bool {
            if lhs.bucket != rhs.bucket { return lhs.bucket < rhs.bucket }
            if lhs.date != rhs.date { return lhs.date < rhs.date }
            return lhs.authored < rhs.authored
        }
    }
}
