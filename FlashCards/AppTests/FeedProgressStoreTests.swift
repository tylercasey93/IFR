import XCTest
@testable import IFRFlashCards

@MainActor
final class FeedProgressStoreTests: XCTestCase {
    private func freshDefaults() -> UserDefaults {
        let suite = "FeedProgressStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    private func lesson(_ id: String, quizCount: Int = 2) -> FeedLesson {
        FeedLesson(id: id, title: id, topicArea: "regs", hook: "hook",
                   hasVideo: true,
                   references: FeedReferences(acs: ["IR.I.A"],
                                              faa: FeedFAAReference(source: "CFR", title: "t")),
                   quiz: (0..<quizCount).map { i in
                       FeedQuizQuestion(question: "q\(i)", choices: ["a", "b", "c", "d"],
                                        correctIndex: 0, explanation: "e")
                   })
    }

    /// A v1 blob (no v2 keys) must decode — losing it silently wipes progress.
    func testV1SnapshotMigration() {
        let defaults = freshDefaults()
        let v1 = #"{"watched":["01-craft"],"quizCorrect":{"01-craft#0":true}}"#
        defaults.set(Data(v1.utf8), forKey: "feedProgress.v1")

        let store = FeedProgressStore(defaults: defaults)
        XCTAssertTrue(store.isWatched("01-craft"))
        XCTAssertEqual(store.quizResult(lessonID: "01-craft", questionIndex: 0), true)
        // Legacy watched lessons read as most stale, not unwatched.
        XCTAssertEqual(store.watchedDate("01-craft"), .distantPast)
        XCTAssertNil(store.watchedDate("02-alternate"))
    }

    func testMarkWatchedStampsDate() {
        let store = FeedProgressStore(defaults: freshDefaults())
        store.markWatched("x")
        let stamped = store.watchedDate("x")
        XCTAssertNotNil(stamped)
        XCTAssertNotEqual(stamped, .distantPast)
        // Re-marking must not move the first-watch date.
        store.markWatched("x")
        XCTAssertEqual(store.watchedDate("x"), stamped)
    }

    func testPreflightFirstWriteWins() {
        let store = FeedProgressStore(defaults: freshDefaults())
        store.recordPreflight(lessonID: "x", correct: false)
        store.recordPreflight(lessonID: "x", correct: true)
        XCTAssertEqual(store.preflightResult("x"), false)
    }

    func testClaimQuizXPDedupes() {
        let store = FeedProgressStore(defaults: freshDefaults())
        XCTAssertTrue(store.claimQuizXP(lessonID: "x", questionIndex: 0))
        XCTAssertFalse(store.claimQuizXP(lessonID: "x", questionIndex: 0))
        XCTAssertTrue(store.claimQuizXP(lessonID: "x", questionIndex: 1))
    }

    func testWrongLatestAnswerSignal() {
        let store = FeedProgressStore(defaults: freshDefaults())
        let l = lesson("x")
        XCTAssertFalse(store.hasWrongLatestAnswer(l))
        store.recordQuiz(lessonID: "x", questionIndex: 1, correct: false)
        XCTAssertTrue(store.hasWrongLatestAnswer(l))
        store.recordQuiz(lessonID: "x", questionIndex: 1, correct: true)
        XCTAssertFalse(store.hasWrongLatestAnswer(l))
    }

    func testPersistsAcrossInstances() {
        let defaults = freshDefaults()
        FeedProgressStore(defaults: defaults).markWatched("x")
        XCTAssertTrue(FeedProgressStore(defaults: defaults).isWatched("x"))
    }
}
