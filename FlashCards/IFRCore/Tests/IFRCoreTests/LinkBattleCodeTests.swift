import XCTest
@testable import IFRCore

final class LinkBattleCodeTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let scheduler = Scheduler()

    private func mcQuestion(_ id: String, _ category: IFRCore.Category, difficulty: Int = 1) -> Question {
        Question(id: id, category: category, acsCodes: ["IR.I.A.K1"], format: .multipleChoice,
                 front: "f", back: "b", options: ["a", "b", "c"], correctIndex: 0, explanation: "e",
                 source: SourceRef(document: "d", section: "s", url: URL(string: "https://faa.gov")!),
                 figure: nil, difficulty: difficulty)
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

    func testCodeIsSevenCrockfordCharacters() {
        let code = LinkBattleCode.encode(seed: 12345, bankVersion: 1)
        XCTAssertEqual(code.count, 7)
        XCTAssertTrue(code.allSatisfy { LinkBattleCode.alphabet.contains($0) })
    }

    func testCodeRoundTripsThirtyBitSeed() {
        let seed: UInt32 = 0x2A5C_9F03 & 0x3FFF_FFFF
        let code = LinkBattleCode.encode(seed: seed, bankVersion: 1)
        XCTAssertEqual(LinkBattleCode.decode(code, bankVersion: 1), seed)
    }

    func testSeedAboveThirtyBitsIsMasked() {
        let code = LinkBattleCode.encode(seed: 0xFFFF_FFFF, bankVersion: 1)
        XCTAssertEqual(LinkBattleCode.decode(code, bankVersion: 1), 0x3FFF_FFFF)
    }

    func testCodeFromOtherBankVersionIsNil() {
        let code = LinkBattleCode.encode(seed: 999, bankVersion: 1)
        XCTAssertNil(LinkBattleCode.decode(code, bankVersion: 2))
    }

    func testMalformedCodeIsNil() {
        let code = LinkBattleCode.encode(seed: 999, bankVersion: 1)
        XCTAssertNil(LinkBattleCode.decode(String(code.prefix(6)), bankVersion: 1))
        for badCharacter in ["I", "L", "O", "U"] {
            var mutated = Array(code)
            mutated[0] = Character(badCharacter)
            XCTAssertNil(LinkBattleCode.decode(String(mutated), bankVersion: 1))
        }
    }

    func testSameCodeSameDeckRegardlessOfStates() {
        let bank = fullBank(perCategory: 10)
        let first = LinkBattleCode.deck(seed: 42, bank: bank, scheduler: scheduler, now: now)
        let second = LinkBattleCode.deck(seed: 42, bank: bank, scheduler: scheduler, now: now)
        XCTAssertEqual(first.map(\.id), second.map(\.id))
    }

    func testLinkDeckHasTenMixedQuestions() {
        let bank = fullBank(perCategory: 10)
        let deck = LinkBattleCode.deck(seed: 42, bank: bank, scheduler: scheduler, now: now)
        XCTAssertEqual(deck.count, 10)
        XCTAssertGreaterThan(Set(deck.map(\.category)).count, 1)
    }

    func testLinkOpponentIsLinkPilotWithTunedHP() {
        let bank = fullBank(perCategory: 10)
        let deck = LinkBattleCode.deck(seed: 42, bank: bank, scheduler: scheduler, now: now)
        let opponent = LinkBattleCode.opponent(code: "ABCDEF1", deck: deck)
        XCTAssertEqual(opponent.id, "link-ABCDEF1")
        XCTAssertEqual(opponent.name, "LINK PILOT")
        XCTAssertEqual(opponent.nameplateName, "LINK")
        XCTAssertEqual(opponent.tier, .link)
        XCTAssertEqual(opponent.maxHP, OpponentHP.tuned(for: deck))
    }
}
