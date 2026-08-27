import XCTest
@testable import IFRCore

final class XPEngineTests: XCTestCase {
    func testFlashcardValues() {
        XCTAssertEqual(XPEngine.points(for: .flashcardReview(grade: .again, difficulty: 1)), 2)
        XCTAssertEqual(XPEngine.points(for: .flashcardReview(grade: .good, difficulty: 1)), 10)
        XCTAssertEqual(XPEngine.points(for: .flashcardReview(grade: .easy, difficulty: 3)), 15)
        XCTAssertEqual(XPEngine.points(for: .flashcardReview(grade: .again, difficulty: 3)), 2,
                       "no difficulty bonus on a miss")
    }

    func testReviewMCValues() {
        XCTAssertEqual(XPEngine.points(for: .reviewMC(correct: true, difficulty: 1)), 12)
        XCTAssertEqual(XPEngine.points(for: .reviewMC(correct: true, difficulty: 3)), 17)
        XCTAssertEqual(XPEngine.points(for: .reviewMC(correct: false, difficulty: 3)), 3)
    }

    func testQuizValues() {
        XCTAssertEqual(XPEngine.points(for: .quizAnswer(correct: true, difficulty: 1)), 15)
        XCTAssertEqual(XPEngine.points(for: .quizAnswer(correct: true, difficulty: 3)), 20)
        XCTAssertEqual(XPEngine.points(for: .quizAnswer(correct: false, difficulty: 1)), 3)
    }

    func testMilestones() {
        XCTAssertEqual(XPEngine.points(for: .mockExamCompleted(passed: true)), 100)
        XCTAssertEqual(XPEngine.points(for: .mockExamCompleted(passed: false)), 40)
        XCTAssertEqual(XPEngine.points(for: .dailyGoalMet), 50)
    }
}
