import XCTest
@testable import IFRCore

final class EncounterRollTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let scheduler = Scheduler()

    private struct FixedRNG: RandomNumberGenerator {
        let value: UInt64
        func next() -> UInt64 { value }
    }

    private func mcQuestion(_ id: String, _ category: IFRCore.Category) -> Question {
        Question(id: id, category: category, acsCodes: ["IR.I.A.K1"], format: .multipleChoice,
                 front: "f", back: "b", options: ["a", "b", "c"], correctIndex: 0, explanation: "e",
                 source: SourceRef(document: "d", section: "s", url: URL(string: "https://faa.gov")!),
                 figure: nil, difficulty: 1)
    }

    private func dueState(_ id: String, dueOffset: TimeInterval) -> CardState {
        var s = CardState.new(questionID: id)
        s.reps = 1
        s.due = now.addingTimeInterval(dueOffset)
        return s
    }

    func testOneInEightOverEightHundredSeededRolls() {
        var rng = SeededRNG(seed: 7)
        var hits = 0
        for _ in 0..<800 {
            if EncounterRoll.triggers(on: .cloud, repelStepsLeft: 0, stepsSinceEncounter: 0, using: &rng) {
                hits += 1
            }
        }
        XCTAssertTrue((80...120).contains(hits), "expected roughly 100 hits, got \(hits)")
    }

    func testNoRollOffCloud() {
        var rng = FixedRNG(value: 0)
        XCTAssertFalse(EncounterRoll.triggers(on: .ground, repelStepsLeft: 0, stepsSinceEncounter: 0, using: &rng))
        XCTAssertFalse(EncounterRoll.triggers(on: .airway, repelStepsLeft: 0, stepsSinceEncounter: 0, using: &rng))
        XCTAssertFalse(EncounterRoll.triggers(on: .door, repelStepsLeft: 0, stepsSinceEncounter: 0, using: &rng))
    }

    func testRollRunsOnEveryCloudStepNotOnlyOnEntry() {
        var rngA = SeededRNG(seed: 7)
        let first = EncounterRoll.triggers(on: .cloud, repelStepsLeft: 0, stepsSinceEncounter: 0, using: &rngA)
        let second = EncounterRoll.triggers(on: .cloud, repelStepsLeft: 0, stepsSinceEncounter: 0, using: &rngA)
        var rngB = SeededRNG(seed: 7)
        let expectedFirst = rngB.next() % 8 == 0
        let expectedSecond = rngB.next() % 8 == 0
        XCTAssertEqual(first, expectedFirst)
        XCTAssertEqual(second, expectedSecond)
    }

    func testRepelSuppressesEncounters() {
        var rng = FixedRNG(value: 0)
        XCTAssertFalse(EncounterRoll.triggers(on: .cloud, repelStepsLeft: 1, stepsSinceEncounter: 0, using: &rng))
        XCTAssertFalse(EncounterRoll.triggers(on: .cloud, repelStepsLeft: 50, stepsSinceEncounter: 24, using: &rng))
    }

    func testPityStepForcesEncounterOnTwentyFourthCloudStep() {
        var rng = FixedRNG(value: 1)
        XCTAssertFalse(EncounterRoll.triggers(on: .cloud, repelStepsLeft: 0, stepsSinceEncounter: 23, using: &rng))
        XCTAssertTrue(EncounterRoll.triggers(on: .cloud, repelStepsLeft: 0, stepsSinceEncounter: 24, using: &rng))
    }

    func testCloudDeckDrawsOneDueOrWeakCardPreferringAreaCategory() {
        struct Area { let category: IFRCore.Category }
        let area = Area(category: .weather)
        let bank = QuestionBank(version: 1, questions: [
            mcQuestion("weather-due", .weather), mcQuestion("weather-weak", .weather), mcQuestion("reg-1", .regulations),
        ])
        let states = ["weather-due": dueState("weather-due", dueOffset: -100)]
        var rng = SeededRNG(seed: 7)
        let deck = EncounterDeck(scheduler: scheduler)
        let drawn = deck.draw(count: 1, categories: [area.category], bank: bank, states: states, now: now, using: &rng)
        XCTAssertEqual(drawn.map(\.id), ["weather-due"])
    }

    func testCloudOpponentHPIsBaseDamageOfItsQuestion() {
        let question = mcQuestion("q", .weather)
        XCTAssertEqual(OpponentHP.cloud(for: question), Damage.hit(difficulty: question.difficulty, answerSeconds: 10).amount)
        XCTAssertEqual(BattleTier.cloud.rawValue, "cloud")
    }

    func testEmptyPoolMeansNoEncounter() {
        let bank = QuestionBank(version: 1, questions: [mcQuestion("reg-1", .regulations)])
        var rng = SeededRNG(seed: 7)
        let deck = EncounterDeck(scheduler: scheduler)
        let drawn = deck.draw(count: 1, categories: [.weather], bank: bank, states: [:], now: now, using: &rng)
        XCTAssertTrue(drawn.isEmpty)
    }
}
