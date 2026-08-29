import XCTest
@testable import IFRFlashCards

final class FeedOrderingTests: XCTestCase {
    private func lesson(_ id: String) -> FeedLesson {
        FeedLesson(id: id, title: id, topicArea: "holding", hook: "hook",
                   hasVideo: true,
                   references: FeedReferences(acs: ["IR.III.B"],
                                              faa: FeedFAAReference(source: "AIM", title: "t")),
                   quiz: [])
    }

    func testUnwatchedFirstInAuthoredOrder() {
        let lessons = ["a", "b", "c"].map(lesson)
        let ordered = FeedOrdering.ordered(lessons) { l in
            .init(watchedAt: l.id == "b" ? Date() : nil, hasWrongLatestAnswer: false)
        }
        XCTAssertEqual(ordered.map(\.id), ["a", "c", "b"])
    }

    func testWrongAnswersBeatStaleness() {
        let lessons = ["a", "b", "c"].map(lesson)
        let old = Date(timeIntervalSinceNow: -86400 * 30)
        let ordered = FeedOrdering.ordered(lessons) { l in
            switch l.id {
            case "a": .init(watchedAt: old, hasWrongLatestAnswer: false)      // stale
            case "b": .init(watchedAt: Date(), hasWrongLatestAnswer: true)    // missed quiz
            default:  .init(watchedAt: Date(), hasWrongLatestAnswer: false)   // fresh
            }
        }
        XCTAssertEqual(ordered.map(\.id), ["b", "a", "c"])
    }

    func testLegacyWatchedIsMostStale() {
        let lessons = ["a", "b"].map(lesson)
        let ordered = FeedOrdering.ordered(lessons) { l in
            // "b" was watched pre-timestamps (.distantPast); "a" watched today.
            .init(watchedAt: l.id == "a" ? Date() : .distantPast,
                  hasWrongLatestAnswer: false)
        }
        XCTAssertEqual(ordered.map(\.id), ["b", "a"])
    }

    func testDeterministic() {
        let lessons = (0..<10).map { lesson("l\($0)") }
        let signal: (FeedLesson) -> FeedOrdering.LessonSignal = { _ in
            .init(watchedAt: nil, hasWrongLatestAnswer: false)
        }
        XCTAssertEqual(FeedOrdering.ordered(lessons, signal: signal).map(\.id),
                       FeedOrdering.ordered(lessons, signal: signal).map(\.id))
    }
}
