import XCTest
@testable import IFRCore

final class RivalPlannerTests: XCTestCase {
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

    private func makeRival(at: GridPoint = GridPoint(x: 9, y: 1), afterBadges: Int = 1) -> RivalSpec {
        RivalSpec(
            name: "Skyler", nameplateName: "SKYLER", spriteID: "rival", questionCount: 6,
            encounters: [
                RivalEncounter(at: at, afterBadges: afterBadges, dialogue: DialogueRefs(intro: "i", win: "w", lose: "l")),
            ]
        )
    }

    private func makeSave(badges: Int, done: Set<Int> = []) -> AdventureSave {
        var save = AdventureSave.new
        save.badges = Set(GymID.allCases.prefix(badges))
        save.rivalEncountersDone = done
        return save
    }

    private func makeMap(_ rows: [[TileKind]]) -> TileMap {
        TileMap(width: rows.first?.count ?? 0, height: rows.count, rows: rows)
    }

    func testPicksThreeLowestRetentionCategories() {
        let retention: [IFRCore.Category: Double] = [
            .regulations: 0.9, .weather: 0.8, .chartsAndPlanning: 0.1,
            .navigation: 0.2, .instrumentsAndSystems: 0.3, .approaches: 0.95,
            .emergencies: 0.99, .humanFactors: 0.99,
        ]
        let weakest = RivalPlanner.weakestCategories(count: 3, retention: retention)
        XCTAssertEqual(weakest, [.chartsAndPlanning, .navigation, .instrumentsAndSystems])
    }

    func testTiesBreakByExamWeightDescending() {
        let retention: [IFRCore.Category: Double] = [
            .regulations: 0.5, .weather: 0.5, .chartsAndPlanning: 0.5,
            .navigation: 0.5, .instrumentsAndSystems: 0.5, .approaches: 0.5,
            .emergencies: 0.5, .humanFactors: 0.5,
        ]
        let weakest = RivalPlanner.weakestCategories(count: 2, retention: retention)
        XCTAssertEqual(weakest, [.regulations, .weather])
    }

    func testEncounterFiresOnceAtBadgeThreshold() {
        let spec = makeRival(at: GridPoint(x: 9, y: 1), afterBadges: 1)
        let readySave = makeSave(badges: 1)
        XCTAssertEqual(RivalPlanner.pendingEncounter(at: GridPoint(x: 9, y: 1), spec: spec, save: readySave), 0)
        XCTAssertEqual(RivalPlanner.pendingEncounter(at: GridPoint(x: 10, y: 1), spec: spec, save: readySave), 0)
        let doneSave = makeSave(badges: 1, done: [0])
        XCTAssertNil(RivalPlanner.pendingEncounter(at: GridPoint(x: 9, y: 1), spec: spec, save: doneSave))
    }

    func testEncounterDoesNotFireBelowBadgeThreshold() {
        let spec = makeRival(at: GridPoint(x: 9, y: 1), afterBadges: 4)
        let save = makeSave(badges: 3)
        XCTAssertNil(RivalPlanner.pendingEncounter(at: GridPoint(x: 9, y: 1), spec: spec, save: save))
    }

    func testRivalTileIsNeverBlockedForPathfinding() {
        var rows: [[TileKind]] = Array(repeating: Array(repeating: TileKind.ground, count: 5), count: 3)
        rows[1][2] = .ground
        let map = makeMap(rows)
        let rivalPosition = GridPoint(x: 2, y: 1)
        let blocked: Set<GridPoint> = []
        let path = Pathfinder.path(from: GridPoint(x: 0, y: 1), to: rivalPosition, in: map, blocked: blocked)
        XCTAssertEqual(path, [GridPoint(x: 1, y: 1), GridPoint(x: 2, y: 1)])
    }

    func testRivalDeckDrawsTwoFromEachWeakestCategory() {
        let bank = fullBank(perCategory: 6)
        let retention: [IFRCore.Category: Double] = [
            .regulations: 0.9, .weather: 0.9, .chartsAndPlanning: 0.1,
            .navigation: 0.2, .instrumentsAndSystems: 0.3, .approaches: 0.95,
            .emergencies: 0.99, .humanFactors: 0.99,
        ]
        let weakest = RivalPlanner.weakestCategories(count: 3, retention: retention)
        let circuitOrdered = GymID.allCases
            .map(\.category)
            .filter { weakest.contains($0) }
        let deckMaker = EncounterDeck(scheduler: scheduler)
        var rng = SeededRNG(seed: 7)
        let drawn = deckMaker.draw(count: 6, categories: circuitOrdered, bank: bank, states: [:],
                                   now: now, using: &rng)
        for category in circuitOrdered {
            XCTAssertEqual(drawn.filter { $0.category == category }.count, 2)
        }
    }

    func testRivalUsesTrainerTierAndXP() {
        let spec = makeRival()
        let opponent = spec.opponent(maxHP: 70)
        XCTAssertEqual(opponent.tier, .trainer)
        XCTAssertEqual(opponent.name, spec.name)
        XCTAssertEqual(opponent.nameplateName, spec.nameplateName)
        XCTAssertEqual(opponent.maxHP, 70)
        XCTAssertEqual(XPEngine.points(for: .trainerDefeated), 25)
    }

    func testOlderSaveWithoutRivalEncountersDecodes() throws {
        let json = "{\"badges\":[]}"
        let decoded = try JSONDecoder().decode(AdventureSave.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.rivalEncountersDone, [])
    }
}
