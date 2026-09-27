import XCTest
@testable import IFRCore

final class BattleTuningTests: XCTestCase {
    private func mcQuestion(_ id: String, _ category: IFRCore.Category, difficulty: Int = 1) -> Question {
        Question(id: id, category: category, acsCodes: ["IR.I.A.K1"], format: .multipleChoice,
                 front: "f", back: "b", options: ["a", "b", "c"], correctIndex: 0, explanation: "e",
                 source: SourceRef(document: "d", section: "s", url: URL(string: "https://faa.gov")!),
                 figure: nil, difficulty: difficulty)
    }

    private func typicalDeck() -> [Question] {
        (0..<3).map { mcQuestion("d1-\($0)", .weather, difficulty: 1) }
            + (0..<4).map { mcQuestion("d2-\($0)", .weather, difficulty: 2) }
            + (0..<3).map { mcQuestion("d3-\($0)", .weather, difficulty: 3) }
    }

    private func combinations(_ elements: [Int], _ k: Int) -> [Set<Int>] {
        guard k > 0 else { return [[]] }
        guard elements.count >= k else { return [] }
        if k == elements.count { return [Set(elements)] }
        let first = elements[0]
        let rest = Array(elements.dropFirst())
        let withFirst = combinations(rest, k - 1).map { $0.union([first]) }
        let withoutFirst = combinations(rest, k)
        return withFirst + withoutFirst
    }

    func testSixOfTenWithoutCritsNeverWinsTypicalDraw() {
        let deck = typicalDeck()
        let subsets = combinations(Array(0..<10), 6)
        XCTAssertEqual(subsets.count, 210)
        for subset in subsets {
            XCTAssertFalse(BattleTuning.winsWithoutCriticals(deck: deck, correctIndices: subset))
        }
    }

    func testSevenOfTenWithoutCritsWinsExactlyEightyOfOneTwentySubsets() {
        let deck = typicalDeck()
        let subsets = combinations(Array(0..<10), 7)
        XCTAssertEqual(subsets.count, 120)
        let winCount = subsets.filter { BattleTuning.winsWithoutCriticals(deck: deck, correctIndices: $0) }.count
        XCTAssertEqual(winCount, 80)
    }

    func testEightOfTenAlwaysWins() {
        let deck = typicalDeck()
        let subsets = combinations(Array(0..<10), 8)
        XCTAssertEqual(subsets.count, 45)
        for subset in subsets {
            XCTAssertTrue(BattleTuning.winsWithoutCriticals(deck: deck, correctIndices: subset))
        }
    }

    func testOneCriticalWinsAllButTheAllHardMissSevenOfTen() {
        let deck = typicalDeck()
        let subsets = combinations(Array(0..<10), 7)
        var losingSubsets: [Set<Int>] = []
        var winCount = 0
        for correct in subsets {
            let winsWithBestCrit = correct.contains { crit in
                BattleTuning.winsWithCriticals(deck: deck, correctIndices: correct, criticalIndices: [crit])
            }
            if winsWithBestCrit {
                winCount += 1
            } else {
                losingSubsets.append(correct)
            }
        }
        XCTAssertEqual(winCount, 119)
        XCTAssertEqual(losingSubsets, [Set(0...6)])
    }

    func testTwoCriticalsAlwaysWinSevenOfTen() {
        let deck = typicalDeck()
        let subsets = combinations(Array(0..<10), 7)
        for correct in subsets {
            for pair in combinations(Array(correct), 2) {
                XCTAssertTrue(BattleTuning.winsWithCriticals(deck: deck, correctIndices: correct, criticalIndices: pair))
            }
        }
    }

    func testRealBankMeanDamageNeedsSixPointFiveToSevenPointFiveCorrect() throws {
        let bank = try QuestionBank.load()
        for category in IFRCore.Category.allCases {
            let questions = bank.questions(in: category)
            let meanBaseDamage = Double(BattleTuning.totalBaseDamage(of: questions)) / Double(questions.count)
            let correctAnswersNeeded = 70 / meanBaseDamage
            XCTAssertTrue((6.5...7.5).contains(correctAnswersNeeded), "\(category) needs \(correctAnswersNeeded)")
        }
    }
}
