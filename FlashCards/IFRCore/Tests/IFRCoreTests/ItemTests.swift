import XCTest
@testable import IFRCore

final class ItemTests: XCTestCase {
    private func opponent(tier: BattleTier = .gym, maxHP: Int = 100) -> Opponent {
        Opponent(id: "opp", name: "Opp", nameplateName: "OPP", spriteID: "s", tier: tier, maxHP: maxHP)
    }

    private func mcQuestion(_ id: String, _ category: IFRCore.Category, difficulty: Int = 1) -> Question {
        Question(id: id, category: category, acsCodes: ["IR.I.A.K1"], format: .multipleChoice,
                 front: "f", back: "b", options: ["a", "b", "c"], correctIndex: 0, explanation: "e",
                 source: SourceRef(document: "d", section: "s", url: URL(string: "https://faa.gov")!),
                 figure: nil, difficulty: difficulty)
    }

    private func deck(_ count: Int) -> [Question] {
        (0..<count).map { mcQuestion("q\($0)", .weather) }
    }

    private func state(playerHP: Int = 100, playerMaxHP: Int = 100, reviveArmed: Bool = false, cursor: Int = 0) -> BattleState {
        BattleState(
            opponent: opponent(), deck: deck(3), cursor: cursor, playerHP: playerHP, playerMaxHP: playerMaxHP,
            opponentHP: 100, missDamage: 30, reviveArmed: reviveArmed, results: [], turns: [], outcome: nil
        )
    }

    func testPotionHealsThirtyCappedAtMax() {
        let healed = BattleEngine.useItem(state(playerHP: 90), effect: .heal(30))
        XCTAssertEqual(healed.playerHP, 100)
    }

    func testReviveOnceArmsFlagWithoutHealing() {
        let armed = BattleEngine.useItem(state(playerHP: 80), effect: .reviveOnce)
        XCTAssertTrue(armed.reviveArmed)
        XCTAssertEqual(armed.playerHP, 80)
    }

    func testArmedReviveRestoresHalfHPOnFatalMissAndEmitsRevived() {
        let armed = BattleEngine.useItem(state(playerHP: 10), effect: .reviveOnce)
        let (next, events) = BattleEngine.answer(armed, selectedIndex: 1, answerSeconds: 10)
        XCTAssertEqual(next.playerHP, 50)
        XCTAssertTrue(events.contains(.revived(50)))
        XCTAssertFalse(next.reviveArmed)
    }

    func testSecondReviveInOneBattleIsNoOp() {
        let armed = BattleEngine.useItem(state(playerHP: 80, reviveArmed: true), effect: .reviveOnce)
        XCTAssertTrue(armed.reviveArmed)
        XCTAssertEqual(armed.playerHP, 80)
    }

    func testUseItemNeverAdvancesCursor() {
        let healed = BattleEngine.useItem(state(cursor: 1), effect: .heal(10))
        XCTAssertEqual(healed.cursor, 1)
    }

    func testItemUseNeverChangesDeckResultsOrGrades() {
        let start = state()
        let after = BattleEngine.useItem(start, effect: .heal(10))
        XCTAssertEqual(after.results, [])
        XCTAssertEqual(after.turns, [])
        XCTAssertEqual(after.deck, start.deck)
    }

    func testUseItemIgnoresOverworldEffects() {
        let start = state(playerHP: 80)
        let afterRepel = BattleEngine.useItem(start, effect: .repel(steps: 50))
        let afterDirect = BattleEngine.useItem(start, effect: .directTo)
        XCTAssertEqual(afterRepel, start)
        XCTAssertEqual(afterDirect, start)
    }

    func testPickupAddsToInventoryOnce() {
        let save = Inventory.adding("potion", to: .new)
        XCTAssertEqual(save.inventory["potion"], 1)
    }

    func testUsingItemConsumesOne() {
        var save = Inventory.adding("potion", to: .new)
        save = Inventory.adding("potion", to: save)
        let used = Inventory.using("potion", from: save)
        XCTAssertEqual(used?.inventory["potion"], 1)
    }

    func testUsingMissingItemIsNil() {
        XCTAssertNil(Inventory.using("potion", from: .new))
    }

    func testRepelSetsFiftyStepsAndDecrementsPerStep() {
        let save = Inventory.applying(.repel(steps: 50), to: .new)
        XCTAssertEqual(save.repelStepsLeft, 50)
        let map = TileMap(
            width: 3, height: 3,
            rows: [
                [.ground, .ground, .ground],
                [.ground, .ground, .ground],
                [.ground, .ground, .ground],
            ],
            spawn: GridPoint(x: 1, y: 1)
        )
        let overworldState = OverworldState(position: GridPoint(x: 1, y: 1), facing: .down)
        var rng = SeededRNG(seed: 7)
        let result = OverworldTurn.advancing(
            overworldState, direction: .up, save: save, map: map, trainers: [], rival: nil, using: &rng
        )
        XCTAssertEqual(result.save.repelStepsLeft, 49)
    }
}
