// IFRCore/Tests/IFRCoreTests/QuizEngineTests.swift
import XCTest
@testable import IFRCore

final class QuizEngineTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let scheduler = Scheduler()
    lazy var engine = QuizEngine(scheduler: scheduler)

    private func mcQuestion(_ id: String, _ category: IFRCore.Category) -> Question {
        Question(id: id, category: category, acsCodes: ["IR.I.A.K1"], format: .multipleChoice,
                 front: "f", back: "b", options: ["a", "b", "c"], correctIndex: 0, explanation: "e",
                 source: SourceRef(document: "d", section: "s", url: URL(string: "https://faa.gov")!),
                 figure: nil, difficulty: 1)
    }

    private func fullBank(perCategory: Int) -> QuestionBank {
        var questions: [Question] = []
        for category in IFRCore.Category.allCases {
            for i in 0..<perCategory {
                questions.append(mcQuestion("\(category.rawValue)-\(i)", category))
            }
        }
        return QuestionBank(version: 1, questions: questions)
    }

    func testQuizRespectsCategoryAndLength() {
        var rng = SeededRNG(seed: 7)
        let quiz = engine.makeQuiz(config: QuizConfig(category: .weather, length: 10, isMockExam: false),
                                   bank: fullBank(perCategory: 15), states: [:], now: now, using: &rng)
        XCTAssertEqual(quiz.count, 10)
        XCTAssertTrue(quiz.allSatisfy { $0.category == .weather })
        XCTAssertEqual(Set(quiz.map(\.id)).count, 10, "no repeats")
    }

    func testFlashcardOnlyQuestionsExcluded() {
        var flashcard = mcQuestion("fc", .weather)
        flashcard = Question(id: "fc", category: .weather, acsCodes: ["IR.I.B.K1"], format: .flashcard,
                             front: "f", back: "b", options: nil, correctIndex: nil, explanation: "e",
                             source: flashcard.source, figure: nil, difficulty: 1)
        let bank = QuestionBank(version: 1, questions: [flashcard, mcQuestion("mc", .weather)])
        var rng = SeededRNG(seed: 7)
        let quiz = engine.makeQuiz(config: QuizConfig(category: .weather, length: 5, isMockExam: false),
                                   bank: bank, states: [:], now: now, using: &rng)
        XCTAssertEqual(quiz.map(\.id), ["mc"])
    }

    func testMockExamMatchesBlueprint() {
        var rng = SeededRNG(seed: 7)
        let quiz = engine.makeQuiz(config: .mockExam, bank: fullBank(perCategory: 15),
                                   states: [:], now: now, using: &rng)
        XCTAssertEqual(quiz.count, 60)
        for category in IFRCore.Category.allCases {
            XCTAssertEqual(quiz.filter { $0.category == category }.count, category.examWeight,
                           "\(category) count matches examWeight")
        }
    }

    func testWeakAreaWeighting() {
        // 2 weather questions: one just reviewed (strong), one unseen (weak).
        // Over many 1-question quizzes, the weak one must be picked more often.
        let bank = QuestionBank(version: 1, questions: [mcQuestion("strong", .weather), mcQuestion("weak", .weather)])
        let states = ["strong": scheduler.review(.new(questionID: "strong"), grade: .good, at: now)]
        var weakPicks = 0
        var rng = SeededRNG(seed: 42)
        for _ in 0..<200 {
            let quiz = engine.makeQuiz(config: QuizConfig(category: .weather, length: 1, isMockExam: false),
                                       bank: bank, states: states, now: now, using: &rng)
            if quiz.first?.id == "weak" { weakPicks += 1 }
        }
        XCTAssertGreaterThan(weakPicks, 120, "weak card (weight ~1.25) beats strong card (~0.25)")
    }

    func testScoring() {
        let pass = QuizEngine.score(results: Array(repeating: true, count: 42) + Array(repeating: false, count: 18))
        XCTAssertEqual(pass.percent, 70)
        XCTAssertTrue(pass.passed)
        let fail = QuizEngine.score(results: Array(repeating: true, count: 41) + Array(repeating: false, count: 19))
        XCTAssertEqual(fail.percent, 68)
        XCTAssertFalse(fail.passed)
    }
}
