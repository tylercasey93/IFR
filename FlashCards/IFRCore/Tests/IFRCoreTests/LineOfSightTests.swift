import XCTest
@testable import IFRCore

final class LineOfSightTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeTrainer(
        id: String = "student-ana", position: GridPoint, facing: Direction, range: Int = 4,
        categories: [IFRCore.Category] = [.humanFactors], questionCount: Int = 4
    ) -> Trainer {
        Trainer(
            id: id, name: "Student Pilot Ana", nameplateName: "ANA", spriteID: "trainer-student",
            position: position, facing: facing, range: range, questionCount: questionCount,
            categories: categories, dialogue: DialogueRefs(intro: "ana-intro", win: "ana-win", lose: "ana-lose")
        )
    }

    private func makeMap(_ rows: [[TileKind]]) -> TileMap {
        TileMap(width: rows.first?.count ?? 0, height: rows.count, rows: rows)
    }

    private func openMap(width: Int = 6, height: Int = 6) -> TileMap {
        makeMap(Array(repeating: Array(repeating: TileKind.ground, count: width), count: height))
    }

    private func mcQuestion(_ id: String, _ category: IFRCore.Category) -> Question {
        Question(id: id, category: category, acsCodes: ["IR.I.A.K1"], format: .multipleChoice,
                 front: "f", back: "b", options: ["a", "b", "c"], correctIndex: 0, explanation: "e",
                 source: SourceRef(document: "d", section: "s", url: URL(string: "https://faa.gov")!),
                 figure: nil, difficulty: 1)
    }

    func testSeesPlayerWithinRangeAlongFacing() {
        let trainer = makeTrainer(position: GridPoint(x: 1, y: 1), facing: .right, range: 4)
        let seen = LineOfSight.trainerSeeing(GridPoint(x: 3, y: 1), trainers: [trainer], defeated: [], in: openMap())
        XCTAssertEqual(seen, trainer)
    }

    func testDoesNotSeeBehind() {
        let trainer = makeTrainer(position: GridPoint(x: 3, y: 1), facing: .right, range: 4)
        let seen = LineOfSight.trainerSeeing(GridPoint(x: 1, y: 1), trainers: [trainer], defeated: [], in: openMap())
        XCTAssertNil(seen)
    }

    func testTerrainAndBuildingsBlockSight() {
        var rows = Array(repeating: Array(repeating: TileKind.ground, count: 6), count: 6)
        rows[1][2] = .terrain
        let trainer = makeTrainer(position: GridPoint(x: 1, y: 1), facing: .right, range: 4)
        let seen = LineOfSight.trainerSeeing(GridPoint(x: 3, y: 1), trainers: [trainer], defeated: [], in: makeMap(rows))
        XCTAssertNil(seen)
    }

    func testRangeIsInclusive() {
        let trainer = makeTrainer(position: GridPoint(x: 1, y: 1), facing: .right, range: 4)
        let seen = LineOfSight.trainerSeeing(GridPoint(x: 5, y: 1), trainers: [trainer], defeated: [], in: openMap(width: 8))
        XCTAssertEqual(seen, trainer)
    }

    func testDefeatedTrainerNeverSees() {
        let trainer = makeTrainer(position: GridPoint(x: 1, y: 1), facing: .right, range: 4)
        let seen = LineOfSight.trainerSeeing(
            GridPoint(x: 3, y: 1), trainers: [trainer], defeated: [trainer.id], in: openMap()
        )
        XCTAssertNil(seen)
    }

    func testFirstTrainerInPlacementOrderWins() {
        let first = makeTrainer(id: "first", position: GridPoint(x: 1, y: 1), facing: .right, range: 4)
        let second = makeTrainer(id: "second", position: GridPoint(x: 0, y: 1), facing: .right, range: 4)
        let seen = LineOfSight.trainerSeeing(
            GridPoint(x: 3, y: 1), trainers: [first, second], defeated: [], in: openMap()
        )
        XCTAssertEqual(seen, first)
    }

    func testTrainerDeckDrawsFromTrainerCategories() {
        let scheduler = Scheduler()
        let deck = EncounterDeck(scheduler: scheduler)
        let trainer = makeTrainer(position: GridPoint(x: 1, y: 1), facing: .right, categories: [.humanFactors])
        let bank = QuestionBank(version: 1, questions: (0..<6).map { mcQuestion("hf-\($0)", .humanFactors) })
        var rng = SeededRNG(seed: 7)
        let drawn = deck.draw(
            count: trainer.questionCount, categories: trainer.categories, bank: bank,
            states: [:], now: now, using: &rng
        )
        XCTAssertEqual(drawn.count, trainer.questionCount)
        XCTAssertTrue(drawn.allSatisfy { $0.category == .humanFactors })
    }
}
