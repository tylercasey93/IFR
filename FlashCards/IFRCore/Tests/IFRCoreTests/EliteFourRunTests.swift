import XCTest
@testable import IFRCore

final class EliteFourRunTests: XCTestCase {
    private func mcQuestion(_ id: String, _ category: IFRCore.Category, difficulty: Int = 1) -> Question {
        Question(id: id, category: category, acsCodes: ["IR.I.A.K1"], format: .multipleChoice,
                 front: "f", back: "b", options: ["a", "b", "c"], correctIndex: 0, explanation: "e",
                 source: SourceRef(document: "d", section: "s", url: URL(string: "https://faa.gov")!),
                 figure: nil, difficulty: difficulty)
    }

    private func opponent(tier: BattleTier = .eliteFour, maxHP: Int = 100) -> Opponent {
        Opponent(id: "opp", name: "Opp", nameplateName: "OPP", spriteID: "s", tier: tier, maxHP: maxHP)
    }

    private func wonBattle(playerHP: Int, playerMaxHP: Int) -> BattleState {
        var state = BattleEngine.start(opponent: opponent(maxHP: 1), deck: [mcQuestion("q", .weather)], playerMaxHP: playerMaxHP)
        state.playerHP = playerHP
        let (next, _) = BattleEngine.answer(state, selectedIndex: 0, answerSeconds: 10)
        return next
    }

    private func lostBattle(playerMaxHP: Int) -> BattleState {
        let state = BattleEngine.start(opponent: opponent(maxHP: 1000), deck: [mcQuestion("q", .weather)], playerMaxHP: playerMaxHP)
        let (next, _) = BattleEngine.forfeit(state)
        return next
    }

    func testEliteRunStartsAtMemberZeroWithFullHP() {
        let run = EliteFourRun.start(playerMaxHP: 100)
        XCTAssertEqual(run.memberIndex, 0)
        XCTAssertEqual(run.playerHP, 100)
        XCTAssertEqual(run.playerMaxHP, 100)
        XCTAssertFalse(run.isCleared)
    }

    func testEliteRunCarriesHPAndHealsThirtyPercentCapped() {
        XCTAssertEqual(EliteFourRun.carryOverHP(current: 40, max: 100), 70)
        XCTAssertEqual(EliteFourRun.carryOverHP(current: 90, max: 100), 100)
        XCTAssertEqual(EliteFourRun.carryOverHP(current: 100, max: 100), 100)
    }

    func testEliteRunIsClearedAfterFourthWin() {
        var run = EliteFourRun.start(playerMaxHP: 100)
        for _ in 0..<4 {
            let battle = wonBattle(playerHP: run.playerHP, playerMaxHP: run.playerMaxHP)
            run = run.advancing(after: battle)!
        }
        XCTAssertEqual(run.memberIndex, 4)
        XCTAssertTrue(run.isCleared)
    }

    func testEliteRunEndsOnLoss() {
        let run = EliteFourRun.start(playerMaxHP: 100)
        let battle = lostBattle(playerMaxHP: run.playerMaxHP)
        XCTAssertNil(run.advancing(after: battle))
    }
}
