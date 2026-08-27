import XCTest
@testable import IFRCore

final class BankValidationTests: XCTestCase {
    private func makeQuestion(
        id: String = "q1", category: IFRCore.Category = .weather, format: QuestionFormat = .flashcard,
        options: [String]? = nil, correctIndex: Int? = nil, difficulty: Int = 1
    ) -> Question {
        Question(id: id, category: category, acsCodes: ["IR.I.B.K1"], format: format,
                 front: "front", back: "back", options: options, correctIndex: correctIndex,
                 explanation: "why",
                 source: SourceRef(document: "AIM", section: "s", url: URL(string: "https://faa.gov")!),
                 figure: nil, difficulty: difficulty)
    }

    func testBundledBankLoadsAndValidates() throws {
        let bank = try QuestionBank.load()
        XCTAssertGreaterThanOrEqual(bank.questions.count, 800)
        XCTAssertEqual(Set(bank.questions.map(\.category)).count, 8, "bank covers all categories")
    }

    func testDuplicateIDFails() {
        let bank = QuestionBank(version: 1, questions: [makeQuestion(), makeQuestion()])
        XCTAssertThrowsError(try bank.validate()) {
            XCTAssertEqual($0 as? BankValidationError, .duplicateID("q1"))
        }
    }

    func testMCWithoutOptionsFails() {
        let bank = QuestionBank(version: 1, questions: [makeQuestion(format: .multipleChoice)])
        XCTAssertThrowsError(try bank.validate()) {
            XCTAssertEqual($0 as? BankValidationError, .missingOptions(id: "q1"))
        }
    }

    func testBadCorrectIndexFails() {
        let bank = QuestionBank(version: 1, questions:
            [makeQuestion(format: .multipleChoice, options: ["a", "b", "c"], correctIndex: 3)])
        XCTAssertThrowsError(try bank.validate()) {
            XCTAssertEqual($0 as? BankValidationError, .badCorrectIndex(id: "q1"))
        }
    }

    func testBadDifficultyFails() {
        let bank = QuestionBank(version: 1, questions: [makeQuestion(difficulty: 4)])
        XCTAssertThrowsError(try bank.validate()) {
            XCTAssertEqual($0 as? BankValidationError, .badDifficulty(id: "q1"))
        }
    }
}
