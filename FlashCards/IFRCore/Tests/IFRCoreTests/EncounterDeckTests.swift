import XCTest
@testable import IFRCore

final class EncounterDeckTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let scheduler = Scheduler()
    lazy var deck = EncounterDeck(scheduler: scheduler)

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

    private func dueState(_ id: String, dueOffset: TimeInterval) -> CardState {
        var s = CardState.new(questionID: id)
        s.reps = 1
        s.due = now.addingTimeInterval(dueOffset)
        return s
    }

    func testDueCardsInCategoryComeFirstOldestFirst() {
        let bank = fullBank(perCategory: 5)
        let states = [
            "weather-0": dueState("weather-0", dueOffset: -300),
            "weather-1": dueState("weather-1", dueOffset: -200),
            "weather-2": dueState("weather-2", dueOffset: -100),
        ]
        var rng = SeededRNG(seed: 7)
        let drawn = deck.draw(count: 5, categories: [.weather], bank: bank, states: states,
                              now: now, using: &rng)
        XCTAssertEqual(Array(drawn.prefix(3).map(\.id)), ["weather-0", "weather-1", "weather-2"])
    }

    func testNilCategoriesKeepsQueueRoundRobinOrder() {
        let bank = QuestionBank(version: 1, questions: [
            mcQuestion("w1", .weather), mcQuestion("w2", .weather),
            mcQuestion("r1", .regulations), mcQuestion("r2", .regulations),
        ])
        let states = [
            "w1": dueState("w1", dueOffset: -400), "w2": dueState("w2", dueOffset: -300),
            "r1": dueState("r1", dueOffset: -200), "r2": dueState("r2", dueOffset: -100),
        ]
        let expected = StudyQueue.session(bank: bank, states: states,
                                          settings: StudySettings(newCardsPerDay: 0),
                                          newIntroducedToday: 0, now: now).map(\.id)
        var rng = SeededRNG(seed: 7)
        let drawn = deck.draw(count: 4, categories: nil, bank: bank, states: states,
                              now: now, using: &rng)
        XCTAssertEqual(drawn.map(\.id), expected)
    }

    func testFlashcardOnlyQuestionsAreExcluded() {
        var flashcard = mcQuestion("fc", .weather)
        flashcard = Question(id: "fc", category: .weather, acsCodes: ["IR.I.B.K1"], format: .flashcard,
                             front: "f", back: "b", options: nil, correctIndex: nil, explanation: "e",
                             source: flashcard.source, figure: nil, difficulty: 1)
        let bank = QuestionBank(version: 1, questions: [flashcard, mcQuestion("mc", .weather)])
        let states = [
            "fc": dueState("fc", dueOffset: -100),
            "mc": dueState("mc", dueOffset: -50),
        ]
        var rng = SeededRNG(seed: 7)
        let drawn = deck.draw(count: 5, categories: [.weather], bank: bank, states: states,
                              now: now, using: &rng)
        XCTAssertEqual(drawn.map(\.id), ["mc"])
    }

    func testTopsUpWithRetentionWeightedDrawWhenFewAreDue() {
        let bank = QuestionBank(version: 1, questions: [mcQuestion("strong", .weather), mcQuestion("weak", .weather)])
        let states = ["strong": scheduler.review(.new(questionID: "strong"), grade: .good, at: now)]
        var weakPicks = 0
        var rng = SeededRNG(seed: 42)
        for _ in 0..<200 {
            let drawn = deck.draw(count: 1, categories: [.weather], bank: bank, states: states,
                                  now: now, using: &rng)
            if drawn.first?.id == "weak" { weakPicks += 1 }
        }
        XCTAssertGreaterThan(weakPicks, 120, "weak card (weight ~1.25) beats strong card (~0.25)")
    }

    func testNeverPadsBeyondPool() {
        let bank = QuestionBank(version: 1, questions: (0..<6).map { mcQuestion("q\($0)", .weather) })
        var rng = SeededRNG(seed: 7)
        let drawn = deck.draw(count: 10, categories: nil, bank: bank, states: [:], now: now, using: &rng)
        XCTAssertEqual(drawn.count, 6)
    }

    func testNoDuplicateIDsInOneDraw() {
        let bank = fullBank(perCategory: 10)
        var states: [String: CardState] = [:]
        states["regulations-0"] = dueState("regulations-0", dueOffset: -100)
        states["regulations-1"] = dueState("regulations-1", dueOffset: -50)
        states["emergencies-0"] = dueState("emergencies-0", dueOffset: -80)
        var rng = SeededRNG(seed: 7)
        let drawn = deck.draw(count: 12, categories: [.regulations, .emergencies], bank: bank,
                              states: states, now: now, using: &rng)
        XCTAssertEqual(Set(drawn.map(\.id)).count, drawn.count)
    }

    func testSameSeedSameDraw() {
        let bank = fullBank(perCategory: 10)
        let states = ["weather-0": dueState("weather-0", dueOffset: -100)]
        var rng1 = SeededRNG(seed: 7)
        let first = deck.draw(count: 8, categories: [.weather, .regulations], bank: bank,
                              states: states, now: now, using: &rng1)
        var rng2 = SeededRNG(seed: 7)
        let second = deck.draw(count: 8, categories: [.weather, .regulations], bank: bank,
                               states: states, now: now, using: &rng2)
        XCTAssertEqual(first.map(\.id), second.map(\.id))
    }

    func testNilCategoriesDrawsAcrossAllCategories() {
        let bank = fullBank(perCategory: 10)
        var rng = SeededRNG(seed: 7)
        let drawn = deck.draw(count: 40, categories: nil, bank: bank, states: [:], now: now, using: &rng)
        XCTAssertGreaterThan(Set(drawn.map(\.category)).count, 1)
    }

    func testTwoCategoriesDrawHalfEach() {
        let bank = fullBank(perCategory: 10)
        var states: [String: CardState] = [:]
        for i in 0..<10 {
            states["regulations-\(i)"] = dueState("regulations-\(i)", dueOffset: TimeInterval(-100 - i))
        }
        var rng = SeededRNG(seed: 7)
        let drawn = deck.draw(count: 12, categories: [.regulations, .emergencies], bank: bank,
                              states: states, now: now, using: &rng)
        XCTAssertEqual(drawn.filter { $0.category == .regulations }.count, 6)
        XCTAssertEqual(drawn.filter { $0.category == .emergencies }.count, 6)
    }

    func testUnevenSplitGivesRemainderToEarliestCategory() {
        let bank = fullBank(perCategory: 10)
        var rng = SeededRNG(seed: 7)
        let drawn = deck.draw(count: 7, categories: [.weather, .regulations, .emergencies],
                              bank: bank, states: [:], now: now, using: &rng)
        XCTAssertEqual(drawn.filter { $0.category == .weather }.count, 3)
        XCTAssertEqual(drawn.filter { $0.category == .regulations }.count, 2)
        XCTAssertEqual(drawn.filter { $0.category == .emergencies }.count, 2)
    }

    func testDuePrefixContainsNoUnseenCards() {
        let bank = QuestionBank(version: 1, questions: (0..<6).map { mcQuestion("q\($0)", .weather) })
        let engine = QuizEngine(scheduler: scheduler)
        var rngA = SeededRNG(seed: 7)
        let empty = deck.draw(count: 4, categories: [.weather], bank: bank, states: [:], now: now, using: &rngA)
        var rngB = SeededRNG(seed: 7)
        let expectedEmpty = engine.makeQuiz(config: QuizConfig(category: .weather, length: 4, isMockExam: false),
                                            bank: bank, states: [:], now: now, using: &rngB)
        XCTAssertEqual(empty.map(\.id), expectedEmpty.map(\.id))

        let states = [
            "q0": dueState("q0", dueOffset: -200),
            "q1": dueState("q1", dueOffset: -100),
        ]
        var rngC = SeededRNG(seed: 7)
        let withDue = deck.draw(count: 4, categories: [.weather], bank: bank, states: states, now: now, using: &rngC)
        XCTAssertEqual(Array(withDue.prefix(2).map(\.id)), ["q0", "q1"])
        let dueIDs = Set(["q0", "q1"])
        XCTAssertTrue(withDue.dropFirst(2).allSatisfy { !dueIDs.contains($0.id) })
    }

    func testDueCardInAnyCategoryDrawsWithoutSettings() {
        let bank = QuestionBank(version: 1, questions: [mcQuestion("a", .approaches)])
        let states = ["a": dueState("a", dueOffset: -60)]
        var rng = SeededRNG(seed: 7)
        let drawn = deck.draw(count: 1, categories: [.approaches], bank: bank, states: states,
                              now: now, using: &rng)
        XCTAssertEqual(drawn.map(\.id), ["a"])
    }
}
