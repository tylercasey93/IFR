// IFRCore/Tests/IFRCoreTests/MasteryTests.swift
import XCTest
@testable import IFRCore

final class MasteryTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let scheduler = Scheduler()
    lazy var calc = MasteryCalculator(scheduler: scheduler)

    private func question(_ id: String, _ category: IFRCore.Category) -> Question {
        Question(id: id, category: category, acsCodes: ["IR.I.A.K1"], format: .flashcard,
                 front: "f", back: "b", options: nil, correctIndex: nil, explanation: "e",
                 source: SourceRef(document: "d", section: "s", url: URL(string: "https://faa.gov")!),
                 figure: nil, difficulty: 1)
    }

    func testLevelThresholds() {
        XCTAssertEqual(MasteryLevel.level(forRetention: 0.0), .novice)
        XCTAssertEqual(MasteryLevel.level(forRetention: 0.19), .novice)
        XCTAssertEqual(MasteryLevel.level(forRetention: 0.2), .apprentice)
        XCTAssertEqual(MasteryLevel.level(forRetention: 0.45), .competent)
        XCTAssertEqual(MasteryLevel.level(forRetention: 0.65), .proficient)
        XCTAssertEqual(MasteryLevel.level(forRetention: 0.95), .instrumentMaster)
    }

    func testUnseenCategoryIsZero() {
        let bank = QuestionBank(version: 1, questions: [question("a", .weather)])
        XCTAssertEqual(calc.categoryRetention(.weather, bank: bank, states: [:], at: now), 0)
    }

    func testFreshlyReviewedCardScoresNearOne() {
        let bank = QuestionBank(version: 1, questions: [question("a", .weather)])
        let states = ["a": scheduler.review(.new(questionID: "a"), grade: .good, at: now)]
        let r = calc.categoryRetention(.weather, bank: bank, states: states, at: now.addingTimeInterval(60))
        XCTAssertGreaterThan(r, 0.95)
    }

    func testHalfSeenCategoryAveragesUnseenAsZero() {
        let bank = QuestionBank(version: 1, questions: [question("a", .weather), question("b", .weather)])
        let states = ["a": scheduler.review(.new(questionID: "a"), grade: .good, at: now)]
        let r = calc.categoryRetention(.weather, bank: bank, states: states, at: now.addingTimeInterval(60))
        XCTAssertEqual(r, 0.5, accuracy: 0.05)
    }

    func testReadinessAveragesAcrossWholeBank() {
        let bank = QuestionBank(version: 1, questions: [question("a", .weather), question("b", .regulations)])
        let states = [
            "a": scheduler.review(.new(questionID: "a"), grade: .good, at: now),
            "b": scheduler.review(.new(questionID: "b"), grade: .good, at: now),
        ]
        let r = calc.readiness(bank: bank, states: states, at: now.addingTimeInterval(60))
        XCTAssertGreaterThan(r, 0.95)
    }
}
