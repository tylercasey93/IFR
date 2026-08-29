import XCTest
@testable import IFRFlashCards

final class FeedHangarStatsTests: XCTestCase {
    private func lesson(_ id: String, topic: String, hasVideo: Bool = true,
                        quizCount: Int = 2) -> FeedLesson {
        FeedLesson(id: id, title: id, topicArea: topic, hook: "hook",
                   hasVideo: hasVideo,
                   references: FeedReferences(acs: ["IR.I.A"],
                                              faa: FeedFAAReference(source: "CFR", title: "t")),
                   quiz: (0..<quizCount).map { i in
                       FeedQuizQuestion(question: "q\(i)", choices: ["a", "b", "c", "d"],
                                        correctIndex: 0, explanation: "e")
                   })
    }

    func testPerTopicMath() {
        let lessons = [
            lesson("a", topic: "holding"),
            lesson("b", topic: "holding"),
            lesson("c", topic: "regs"),
            lesson("d", topic: "regs", hasVideo: false), // excluded everywhere
        ]
        let stats = FeedHangarStats.compute(
            lessons: lessons,
            isWatched: { ["a"].contains($0) },
            quizResult: { id, index in
                // "a": both right; "b": one wrong; "c": untouched.
                switch (id, index) {
                case ("a", _): true
                case ("b", 0): false
                default: nil
                }
            }
        )
        XCTAssertEqual(stats.lessonsTotal, 3)
        XCTAssertEqual(stats.lessonsWatched, 1)
        XCTAssertEqual(stats.quizAccuracy, 2.0 / 3.0)
        XCTAssertEqual(stats.topics.map(\.topicArea), ["holding", "regs"])

        let holding = stats.topics[0]
        XCTAssertEqual(holding.watched, 1)
        XCTAssertEqual(holding.total, 2)
        XCTAssertEqual(holding.quizAnswered, 3)
        XCTAssertEqual(holding.quizCorrect, 2)
        // (1/2 watched + 2/3 correct) / 2
        XCTAssertEqual(holding.ringProgress, (0.5 + 2.0 / 3.0) / 2, accuracy: 0.0001)

        let regs = stats.topics[1]
        XCTAssertEqual(regs.quizAnswered, 0)
        XCTAssertEqual(regs.ringProgress, 0, accuracy: 0.0001) // unwatched + unanswered
    }

    func testEmptyAccuracyIsNil() {
        let stats = FeedHangarStats.compute(lessons: [lesson("a", topic: "wx")],
                                            isWatched: { _ in false },
                                            quizResult: { _, _ in nil })
        XCTAssertNil(stats.quizAccuracy)
    }
}
