import XCTest
@testable import IFRCore

final class RematchAdvisorTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let scheduler = Scheduler()

    private func question(_ id: String, _ category: IFRCore.Category) -> Question {
        Question(id: id, category: category, acsCodes: ["IR.I.A.K1"], format: .flashcard,
                 front: "f", back: "b", options: nil, correctIndex: nil, explanation: "e",
                 source: SourceRef(document: "d", section: "s", url: URL(string: "https://faa.gov")!),
                 figure: nil, difficulty: 1)
    }

    private func badgedSave(_ gyms: GymID...) -> AdventureSave {
        var save = AdventureSave.new
        save.badges = Set(gyms)
        return save
    }

    func testBadgedGymBelowPointSixIsAtRisk() {
        let save = badgedSave(.humanFactors)
        let atRisk = RematchAdvisor.gymsAtRisk(
            save: save, categoryRetention: [.humanFactors: 0.59], badgeQuestionRetention: [.humanFactors: 0.9])
        XCTAssertEqual(atRisk, [.humanFactors])
    }

    func testFreshGymWinIsNotAtRisk() {
        let calc = MasteryCalculator(scheduler: scheduler)
        var questions: [Question] = []
        for i in 0..<100 {
            questions.append(question("hf-\(i)", .humanFactors))
        }
        let bank = QuestionBank(version: 1, questions: questions)
        var states: [String: CardState] = [:]
        for i in 0..<10 {
            states["hf-\(i)"] = scheduler.review(.new(questionID: "hf-\(i)"), grade: .good, at: now)
        }
        let retention = calc.reviewedRetention(.humanFactors, bank: bank, states: states, at: now)
        let save = badgedSave(.humanFactors)
        let atRisk = RematchAdvisor.gymsAtRisk(
            save: save, categoryRetention: [.humanFactors: retention], badgeQuestionRetention: [.humanFactors: retention])
        XCTAssertEqual(atRisk, [])
    }

    func testRetentionIgnoresUnseenCardsUntilCoverageMet() {
        let calc = MasteryCalculator(scheduler: scheduler)
        var questions: [Question] = []
        for i in 0..<15 {
            questions.append(question("hf-\(i)", .humanFactors))
        }
        let bank = QuestionBank(version: 1, questions: questions)
        var states: [String: CardState] = [:]
        for i in 0..<9 {
            states["hf-\(i)"] = scheduler.review(.new(questionID: "hf-\(i)"), grade: .good, at: now)
        }
        XCTAssertEqual(calc.reviewedRetention(.humanFactors, bank: bank, states: states, at: now), 0)
        states["hf-9"] = scheduler.review(.new(questionID: "hf-9"), grade: .good, at: now)
        let expected = states.values.map { scheduler.retrievability(of: $0, at: now) }
            .reduce(0, +) / Double(states.count)
        XCTAssertEqual(calc.reviewedRetention(.humanFactors, bank: bank, states: states, at: now), expected, accuracy: 0.0001)
    }

    func testBadgeQuestionsBelowThresholdFlagGymEvenWhenCategoryIsFine() {
        let save = badgedSave(.humanFactors)
        let atRisk = RematchAdvisor.gymsAtRisk(
            save: save, categoryRetention: [.humanFactors: 0.9], badgeQuestionRetention: [.humanFactors: 0.5])
        XCTAssertEqual(atRisk, [.humanFactors])
    }

    func testUnbadgedGymNeverAtRisk() {
        let atRisk = RematchAdvisor.gymsAtRisk(
            save: .new, categoryRetention: [.humanFactors: 0.1], badgeQuestionRetention: [.humanFactors: 0.1])
        XCTAssertEqual(atRisk, [])
    }

    func testThresholdIsInclusive() {
        let save = badgedSave(.humanFactors)
        let atRisk = RematchAdvisor.gymsAtRisk(
            save: save, categoryRetention: [.humanFactors: 0.6], badgeQuestionRetention: [.humanFactors: 0.9])
        XCTAssertEqual(atRisk, [.humanFactors])
    }

    func testSortedByLowestRetention() {
        let save = badgedSave(.humanFactors, .instrumentsAndSystems, .regulations)
        let atRisk = RematchAdvisor.gymsAtRisk(
            save: save,
            categoryRetention: [.humanFactors: 0.3, .instrumentsAndSystems: 0.55, .regulations: 0.1],
            badgeQuestionRetention: [.humanFactors: 0.5, .instrumentsAndSystems: 0.2, .regulations: 0.4])
        XCTAssertEqual(atRisk, [.regulations, .instrumentsAndSystems, .humanFactors])
    }
}
