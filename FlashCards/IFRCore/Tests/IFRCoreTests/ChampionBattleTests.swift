import XCTest
@testable import IFRCore

final class ChampionBattleTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let scheduler = Scheduler()

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

    func testChampionDeckMatchesMockExamBlueprint() {
        var rng = SeededRNG(seed: 7)
        let deck = ChampionBattle.deck(bank: fullBank(perCategory: 15), states: [:], scheduler: scheduler, now: now, using: &rng)
        XCTAssertEqual(deck.count, 60)
        for category in IFRCore.Category.allCases {
            XCTAssertEqual(deck.filter { $0.category == category }.count, category.examWeight)
        }
    }

    func testChampionOutcomeAgreesWithQuizScoreForEveryCorrectCount() {
        for correct in 0...60 {
            let results = Array(repeating: true, count: correct) + Array(repeating: false, count: 60 - correct)
            let expected: BattleOutcome = QuizEngine.score(results: results).passed ? .won : .lost
            XCTAssertEqual(ChampionBattle.outcome(results: results), expected)
        }
    }

    func testFortyTwoOfSixtyWinsAndFortyOneLoses() {
        let winResults = Array(repeating: true, count: 42) + Array(repeating: false, count: 18)
        XCTAssertEqual(ChampionBattle.outcome(results: winResults), .won)
        let loseResults = Array(repeating: true, count: 41) + Array(repeating: false, count: 19)
        XCTAssertEqual(ChampionBattle.outcome(results: loseResults), .lost)
    }

    func testChampionConstantsAreFortyTwoAndNineteen() {
        XCTAssertEqual(ChampionBattle.opponentHP, 42)
        XCTAssertEqual(ChampionBattle.playerHP, 19)
    }
}
