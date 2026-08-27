import XCTest
@testable import IFRCore

final class StudyQueueTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func question(_ id: String, _ category: IFRCore.Category) -> Question {
        Question(id: id, category: category, acsCodes: ["IR.I.A.K1"], format: .flashcard,
                 front: "f", back: "b", options: nil, correctIndex: nil, explanation: "e",
                 source: SourceRef(document: "d", section: "s", url: URL(string: "https://faa.gov")!),
                 figure: nil, difficulty: 1)
    }

    private func dueState(_ id: String, dueOffset: TimeInterval) -> CardState {
        var s = CardState.new(questionID: id)
        s.reps = 1
        s.due = now.addingTimeInterval(dueOffset)
        return s
    }

    func testDueCardsComeBeforeNewCards() {
        let bank = QuestionBank(version: 1, questions: [question("a", .weather), question("b", .weather)])
        let states = ["a": dueState("a", dueOffset: -60)]
        let session = StudyQueue.session(bank: bank, states: states,
                                         settings: StudySettings(), newIntroducedToday: 0, now: now)
        XCTAssertEqual(session.map(\.id), ["a", "b"])
    }

    func testFutureDueCardsExcluded() {
        let bank = QuestionBank(version: 1, questions: [question("a", .weather)])
        let states = ["a": dueState("a", dueOffset: 86_400)]
        let session = StudyQueue.session(bank: bank, states: states,
                                         settings: StudySettings(), newIntroducedToday: 0, now: now)
        XCTAssertTrue(session.isEmpty)
    }

    func testNewCardCapRespectsAlreadyIntroduced() {
        let bank = QuestionBank(version: 1, questions: (0..<30).map { question("q\($0)", .weather) })
        var settings = StudySettings()
        settings.newCardsPerDay = 20
        let session = StudyQueue.session(bank: bank, states: [:], settings: settings,
                                         newIntroducedToday: 15, now: now)
        XCTAssertEqual(session.count, 5)
    }

    func testLockedCategoriesYieldNoNewCards() {
        let bank = QuestionBank(version: 1, questions: [question("a", .weather), question("b", .approaches)])
        var settings = StudySettings()
        settings.unlockedCategories = [.approaches]
        let session = StudyQueue.session(bank: bank, states: [:], settings: settings,
                                         newIntroducedToday: 0, now: now)
        XCTAssertEqual(session.map(\.id), ["b"])
    }

    func testDueCardsInterleaveAcrossCategories() {
        let bank = QuestionBank(version: 1, questions: [
            question("w1", .weather), question("w2", .weather),
            question("r1", .regulations), question("r2", .regulations),
        ])
        let states = [
            "w1": dueState("w1", dueOffset: -400), "w2": dueState("w2", dueOffset: -300),
            "r1": dueState("r1", dueOffset: -200), "r2": dueState("r2", dueOffset: -100),
        ]
        let session = StudyQueue.session(bank: bank, states: states,
                                         settings: StudySettings(), newIntroducedToday: 0, now: now)
        let categories = session.map(\.category)
        XCTAssertNotEqual(categories[0], categories[1], "adjacent due cards alternate category")
        XCTAssertNotEqual(categories[2], categories[3])
    }

    func testNewCardsPrioritizedByExamWeight() {
        let bank = QuestionBank(version: 1, questions: [question("h", .humanFactors), question("r", .regulations)])
        var settings = StudySettings()
        settings.newCardsPerDay = 1
        let session = StudyQueue.session(bank: bank, states: [:], settings: settings,
                                         newIntroducedToday: 0, now: now)
        XCTAssertEqual(session.map(\.id), ["r"], "regulations (weight 12) beats human factors (weight 2)")
    }

    func testUnreviewedStateStillCountsAsNewCard() {
        // A CardState created via CardState.new(questionID:) (reps == 0)
        // present in `states` used to match neither the due filter
        // (reps > 0) nor the old fresh filter (states[id] == nil) — the
        // card vanished from every session. It must still surface as new.
        let bank = QuestionBank(version: 1, questions: [question("a", .weather)])
        let states = ["a": CardState.new(questionID: "a")]
        let session = StudyQueue.session(bank: bank, states: states,
                                         settings: StudySettings(), newIntroducedToday: 0, now: now)
        XCTAssertEqual(session.map(\.id), ["a"])
    }
}
