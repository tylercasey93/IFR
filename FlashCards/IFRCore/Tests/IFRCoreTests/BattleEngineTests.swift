import XCTest
@testable import IFRCore

final class BattleEngineTests: XCTestCase {
    private func mcQuestion(_ id: String, _ category: IFRCore.Category, difficulty: Int = 1, explanation: String = "e") -> Question {
        Question(id: id, category: category, acsCodes: ["IR.I.A.K1"], format: .multipleChoice,
                 front: "f", back: "b", options: ["a", "b", "c"], correctIndex: 0, explanation: explanation,
                 source: SourceRef(document: "d", section: "s", url: URL(string: "https://faa.gov")!),
                 figure: nil, difficulty: difficulty)
    }

    private func deck(_ count: Int, difficulty: Int = 1) -> [Question] {
        (0..<count).map { mcQuestion("q\($0)", .weather, difficulty: difficulty) }
    }

    private func opponent(tier: BattleTier = .gym, maxHP: Int = 100) -> Opponent {
        Opponent(id: "opp", name: "Opp", nameplateName: "OPP", spriteID: "s", tier: tier, maxHP: maxHP)
    }

    func testStartPresentsFirstQuestionWithFullHP() {
        let state = BattleEngine.start(opponent: opponent(), deck: deck(3), playerMaxHP: 100)
        XCTAssertEqual(state.cursor, 0)
        XCTAssertEqual(state.playerHP, 100)
        XCTAssertEqual(state.opponentHP, 100)
        XCTAssertEqual(state.missDamage, BattleTier.gym.missDamage)
    }

    func testStartMissDamageOverrideIsKept() {
        let state = BattleEngine.start(opponent: opponent(), deck: deck(3), playerMaxHP: 100, missDamage: 35)
        XCTAssertEqual(state.missDamage, 35)
    }

    func testCorrectAnswerDamagesOpponentAndGradesGood() {
        let state = BattleEngine.start(opponent: opponent(maxHP: 100), deck: deck(3), playerMaxHP: 100)
        let (next, _) = BattleEngine.answer(state, selectedIndex: 0, answerSeconds: 10)
        XCTAssertEqual(next.opponentHP, 92)
        XCTAssertEqual(next.turns.last?.grade, .good)
    }

    func testWrongAnswerDamagesPlayerByTierAndGradesAgain() {
        let state = BattleEngine.start(opponent: opponent(maxHP: 100), deck: deck(3), playerMaxHP: 100)
        let (next, _) = BattleEngine.answer(state, selectedIndex: 1, answerSeconds: 10)
        XCTAssertEqual(next.playerHP, 70)
        XCTAssertEqual(next.turns.last?.grade, .again)
    }

    func testWrongAnswerEmitsExplanationEvent() {
        let state = BattleEngine.start(opponent: opponent(maxHP: 100), deck: deck(3), playerMaxHP: 100)
        let (_, events) = BattleEngine.answer(state, selectedIndex: 1, answerSeconds: 10)
        XCTAssertTrue(events.contains(.explanation("e")))
    }

    func testOpponentAtZeroEmitsFaintedAndWins() {
        let state = BattleEngine.start(opponent: opponent(maxHP: 5), deck: deck(3), playerMaxHP: 100)
        let (next, events) = BattleEngine.answer(state, selectedIndex: 0, answerSeconds: 10)
        let hit = Hit(amount: 8, isCritical: false, isSuperEffective: false)
        XCTAssertEqual(events, [.opponentHit(hit, damage: 5), .opponentFainted])
        XCTAssertEqual(next.outcome, .won)
    }

    func testPlayerAtZeroEmitsFaintedAndLoses() {
        let state = BattleEngine.start(opponent: opponent(maxHP: 100), deck: deck(3), playerMaxHP: 20)
        let (next, events) = BattleEngine.answer(state, selectedIndex: 1, answerSeconds: 10)
        XCTAssertEqual(events, [.playerHurt(20), .explanation("e"), .playerFainted])
        XCTAssertEqual(next.outcome, .lost)
    }

    func testDeckExhaustedWithOpponentStandingLoses() {
        let state = BattleEngine.start(opponent: opponent(maxHP: 1000), deck: deck(1), playerMaxHP: 100)
        let (next, events) = BattleEngine.answer(state, selectedIndex: 0, answerSeconds: 10)
        let hit = Hit(amount: 8, isCritical: false, isSuperEffective: false)
        XCTAssertEqual(events, [.opponentHit(hit, damage: 8), .deckExhausted])
        XCTAssertEqual(next.outcome, .lost)
    }

    func testAnswerAfterOutcomeIsNoOp() {
        let state = BattleEngine.start(opponent: opponent(maxHP: 5), deck: deck(3), playerMaxHP: 100)
        let (afterWin, _) = BattleEngine.answer(state, selectedIndex: 0, answerSeconds: 10)
        let (again, events) = BattleEngine.answer(afterWin, selectedIndex: 0, answerSeconds: 10)
        XCTAssertEqual(again, afterWin)
        XCTAssertTrue(events.isEmpty)
    }

    func testForfeitLosesWithoutFurtherReviews() {
        let state = BattleEngine.start(opponent: opponent(maxHP: 100), deck: deck(3), playerMaxHP: 100)
        let (next, events) = BattleEngine.forfeit(state)
        XCTAssertEqual(next.outcome, .lost)
        XCTAssertEqual(events, [.playerFainted])
        XCTAssertTrue(next.turns.isEmpty)
    }

    func testForfeitAfterOutcomeIsNoOp() {
        let state = BattleEngine.start(opponent: opponent(maxHP: 100), deck: deck(3), playerMaxHP: 100)
        let (first, _) = BattleEngine.forfeit(state)
        let (second, events) = BattleEngine.forfeit(first)
        XCTAssertEqual(second, first)
        XCTAssertTrue(events.isEmpty)
    }

    func testResultsMirrorTurnCorrectness() {
        var state = BattleEngine.start(opponent: opponent(maxHP: 1000), deck: deck(4), playerMaxHP: 1000)
        for index in [0, 1, 0, 1] {
            let (next, _) = BattleEngine.answer(state, selectedIndex: index, answerSeconds: 10)
            state = next
        }
        XCTAssertEqual(state.results, [true, false, true, false])
    }

    func testChampionRunsAllQuestionsWithBarsPinnedAtZero() {
        var state = BattleEngine.start(opponent: opponent(tier: .champion, maxHP: 42), deck: deck(60), playerMaxHP: 19)
        for turn in 0..<60 {
            let index = turn < 42 ? 0 : 1
            let (next, _) = BattleEngine.answer(state, selectedIndex: index, answerSeconds: 10)
            XCTAssertGreaterThanOrEqual(next.opponentHP, 0)
            XCTAssertGreaterThanOrEqual(next.playerHP, 0)
            if turn < 59 { XCTAssertNil(next.outcome) }
            state = next
        }
        XCTAssertEqual(state.outcome, .won)
    }

    func testEventOrderForEachAnswerCase() {
        let hit = Hit(amount: 8, isCritical: false, isSuperEffective: false)
        let baseDeck = deck(2)

        let standing = BattleEngine.start(opponent: opponent(maxHP: 100), deck: baseDeck, playerMaxHP: 100)
        let (_, correctStanding) = BattleEngine.answer(standing, selectedIndex: 0, answerSeconds: 10)
        XCTAssertEqual(correctStanding, [.opponentHit(hit, damage: 8), .questionPresented(baseDeck[1])])

        let faint = BattleEngine.start(opponent: opponent(maxHP: 5), deck: baseDeck, playerMaxHP: 100)
        let (_, correctFaint) = BattleEngine.answer(faint, selectedIndex: 0, answerSeconds: 10)
        XCTAssertEqual(correctFaint, [.opponentHit(hit, damage: 5), .opponentFainted])

        let wrongStanding = BattleEngine.start(opponent: opponent(maxHP: 100), deck: baseDeck, playerMaxHP: 100)
        let (_, wrongStandingEvents) = BattleEngine.answer(wrongStanding, selectedIndex: 1, answerSeconds: 10)
        XCTAssertEqual(wrongStandingEvents, [.playerHurt(30), .explanation("e"), .questionPresented(baseDeck[1])])

        var revive = BattleEngine.start(opponent: opponent(maxHP: 100), deck: baseDeck, playerMaxHP: 30)
        revive.reviveArmed = true
        let (_, reviveEvents) = BattleEngine.answer(revive, selectedIndex: 1, answerSeconds: 10)
        XCTAssertEqual(reviveEvents, [.playerHurt(30), .revived(15), .explanation("e"), .questionPresented(baseDeck[1])])

        let doom = BattleEngine.start(opponent: opponent(maxHP: 100), deck: baseDeck, playerMaxHP: 20)
        let (_, doomEvents) = BattleEngine.answer(doom, selectedIndex: 1, answerSeconds: 10)
        XCTAssertEqual(doomEvents, [.playerHurt(20), .explanation("e"), .playerFainted])

        let last = BattleEngine.start(opponent: opponent(maxHP: 1000), deck: deck(1), playerMaxHP: 100)
        let (_, lastEvents) = BattleEngine.answer(last, selectedIndex: 0, answerSeconds: 10)
        XCTAssertEqual(lastEvents, [.opponentHit(hit, damage: 8), .deckExhausted])
    }

    func testRevivedEventPrecedesExplanation() {
        var state = BattleEngine.start(opponent: opponent(maxHP: 100), deck: deck(2), playerMaxHP: 30)
        state.reviveArmed = true
        let (_, events) = BattleEngine.answer(state, selectedIndex: 1, answerSeconds: 10)
        let revivedIndex = events.firstIndex(of: .revived(15))
        let explanationIndex = events.firstIndex(of: .explanation("e"))
        XCTAssertNotNil(revivedIndex)
        XCTAssertNotNil(explanationIndex)
        XCTAssertLessThan(revivedIndex!, explanationIndex!)
    }

    func testBattleStateCodableRoundTrip() throws {
        let state = BattleEngine.start(opponent: opponent(maxHP: 100), deck: deck(3), playerMaxHP: 100)
        let (next, _) = BattleEngine.answer(state, selectedIndex: 0, answerSeconds: 10)
        let decoded = try JSONDecoder().decode(BattleState.self, from: JSONEncoder().encode(next))
        XCTAssertEqual(decoded, next)
    }
}
