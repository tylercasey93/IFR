import XCTest
@testable import IFRCore

final class BattleTowerTests: XCTestCase {
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

    private func dueState(_ id: String, dueOffset: TimeInterval) -> CardState {
        var s = CardState.new(questionID: id)
        s.reps = 1
        s.due = now.addingTimeInterval(dueOffset)
        return s
    }

    private func deck(_ count: Int, difficulty: Int = 1) -> [Question] {
        (0..<count).map { mcQuestion("q\($0)", .humanFactors, difficulty: difficulty) }
    }

    func testFloorOneMissDamageIsTwenty() {
        XCTAssertEqual(BattleTower.missDamage(floor: 1), 20)
    }

    func testMissDamageRisesFivePerFloor() {
        XCTAssertEqual(BattleTower.missDamage(floor: 2), 25)
        XCTAssertEqual(BattleTower.missDamage(floor: 3), 30)
        XCTAssertEqual(BattleTower.missDamage(floor: 10), 65)
    }

    func testTowerFloorHasFiveQuestions() {
        XCTAssertEqual(BattleTower.questionsPerFloor, 5)
    }

    func testTowerOpponentIDNameAndSpriteFollowFloor() {
        let tower = BattleTower.start(playerMaxHP: 100)
        let towerDeck = deck(5)
        let opponent = tower.opponent(forFloor: 9, deck: towerDeck)
        XCTAssertEqual(opponent.id, "tower-floor-9")
        XCTAssertEqual(opponent.name, "FLOOR 9 PILOT")
        XCTAssertEqual(opponent.spriteID, "leader-hypoxia")
        XCTAssertEqual(tower.opponent(forFloor: 1, deck: towerDeck).spriteID, "leader-hypoxia")
        XCTAssertEqual(opponent.maxHP, OpponentHP.tuned(for: towerDeck))
    }

    func testNoHealBetweenFloors() {
        let tower = BattleTower(floor: 3, playerHP: 40, playerMaxHP: 100)
        let opponent = tower.opponent(forFloor: 3, deck: deck(5))
        var state = BattleEngine.start(opponent: opponent, deck: deck(1), playerMaxHP: tower.playerMaxHP,
                                       missDamage: BattleTower.missDamage(floor: 3))
        state.playerHP = 40
        (state, _) = BattleEngine.answer(state, selectedIndex: 0, answerSeconds: 10)
        state.outcome = .won

        let next = tower.climbing(after: state)

        XCTAssertEqual(next?.floor, 4)
        XCTAssertEqual(next?.playerHP, state.playerHP)
        XCTAssertEqual(next?.playerMaxHP, 100)
    }

    func testFaintEndsRun() {
        let tower = BattleTower(floor: 5, playerHP: 10, playerMaxHP: 100)
        let opponent = tower.opponent(forFloor: 5, deck: deck(5))
        let opening = BattleEngine.start(opponent: opponent, deck: deck(1), playerMaxHP: tower.playerMaxHP,
                                         missDamage: BattleTower.missDamage(floor: 5))
        let (lost, _) = BattleEngine.forfeit(opening)

        XCTAssertNil(tower.climbing(after: lost))
    }

    func testFloorDecksDrawDueFirstAcrossAllCategories() {
        let bank = fullBank(perCategory: 5)
        var states: [String: CardState] = [:]
        for category in IFRCore.Category.allCases {
            states["\(category.rawValue)-0"] = dueState("\(category.rawValue)-0", dueOffset: -300)
        }
        let encounterDeck = EncounterDeck(scheduler: scheduler)
        var rng = SeededRNG(seed: 7)
        let drawn = encounterDeck.draw(count: BattleTower.questionsPerFloor, categories: nil,
                                       bank: bank, states: states, now: now, using: &rng)
        let expected = StudyQueue.session(bank: bank, states: states,
                                          settings: StudySettings(newCardsPerDay: 0),
                                          newIntroducedToday: 0, now: now)
            .filter(\.isMultipleChoiceCapable)
            .prefix(BattleTower.questionsPerFloor)
            .map(\.id)
        XCTAssertEqual(drawn.count, BattleTower.questionsPerFloor)
        XCTAssertEqual(Array(drawn.prefix(expected.count)).map(\.id), expected)
    }
}
