// AppTests/AdventureStoreTests.swift
import Observation
import XCTest
import SwiftData
import IFRCore
@testable import IFRFlashCards

@MainActor
final class AdventureStoreTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeStore() throws -> (store: StudyStore, container: ModelContainer) {
        let schema = Schema([CardStateRecord.self, ReviewRecord.self, XPRecord.self,
                             StreakRecord.self, BadgeRecord.self, SettingsRecord.self,
                             AdventureSaveRecord.self, BattleRecord.self])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let store = try StudyStore(context: ModelContext(container), bank: QuestionBank.load())
        return (store, container)
    }

    func testFreshStoreHasNewSaveAndFirstGymUnlocked() throws {
        let (store, _) = try makeStore()
        XCTAssertEqual(store.adventureSave, AdventureSave.new)
        XCTAssertTrue(CircuitRules.isUnlocked(.humanFactors, save: store.adventureSave))
    }

    func testUpdateAdventureSavePersistsAndNotifiesObservers() throws {
        let (store, _) = try makeStore()
        var save = store.adventureSave
        save.badges.insert(.humanFactors)
        let changed = expectation(description: "observation onChange fired")
        withObservationTracking {
            _ = store.adventureSave
        } onChange: {
            changed.fulfill()
        }
        store.updateAdventureSave(save)
        wait(for: [changed], timeout: 1.0)
        XCTAssertEqual(store.adventureSave.badges, [.humanFactors])
    }

    func testNewerSaveBlobIsKeptUntouched() throws {
        let (store, container) = try makeStore()
        let context = ModelContext(container)
        let newerJSON = try JSONEncoder().encode(AdventureSave(
            saveVersion: 2, badges: [], badgeQuestionIDs: [:], eliteFourCleared: false,
            championWins: 0, hallOfFame: [], battlesWon: 0, battlesLost: 0, visitedAirportIDs: []))
        let record = AdventureSaveRecord()
        record.json = newerJSON
        context.insert(record)
        try context.save()

        XCTAssertEqual(store.adventureSave, AdventureSave.new)
        let records = try context.fetch(FetchDescriptor<AdventureSaveRecord>())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.json, newerJSON)
    }

    func testAdventureSaveSurvivesStoreRecreationOnSameContainer() throws {
        let (store1, container) = try makeStore()
        var save = store1.adventureSave
        save.battlesWon = 3
        store1.updateAdventureSave(save)

        let store2 = try StudyStore(context: ModelContext(container), bank: QuestionBank.load())
        XCTAssertEqual(store2.adventureSave.battlesWon, 3)
    }

    func testBattleRecordRoundTripsThroughContainer() throws {
        let (_, container) = try makeStore()
        let context = ModelContext(container)
        let record = BattleRecord(date: now, tierRaw: BattleTier.gym.rawValue, opponentID: "gym-humanFactors",
                                  won: true, correct: 9, total: 12)
        context.insert(record)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<BattleRecord>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.date, now)
        XCTAssertEqual(fetched.first?.tierRaw, BattleTier.gym.rawValue)
        XCTAssertEqual(fetched.first?.opponentID, "gym-humanFactors")
        XCTAssertEqual(fetched.first?.won, true)
        XCTAssertEqual(fetched.first?.correct, 9)
        XCTAssertEqual(fetched.first?.total, 12)
    }

    func testSubmitAdventureAnswerReviewsCardAwardsXPAndLogsInQuiz() throws {
        let (store, container) = try makeStore()
        let question = store.bank.questions.first { $0.difficulty == 1 && $0.isMultipleChoiceCapable }!
        let correct = store.submitAdventureAnswer(question, selectedIndex: question.correctIndex!)
        XCTAssertTrue(correct)
        XCTAssertEqual(store.totalXP, 15)
        XCTAssertEqual(store.answeredToday, 1)

        let context = ModelContext(container)
        let xp = try context.fetch(FetchDescriptor<XPRecord>()).first!
        XCTAssertEqual(xp.reason, "adventure")
        let review = try context.fetch(FetchDescriptor<ReviewRecord>()).first!
        XCTAssertTrue(review.inQuiz)
    }

    func testWrongAdventureAnswerOnNeverReviewedQuestionIsDueWithinTwoDays() throws {
        let (store, container) = try makeStore()
        let question = store.bank.questions.first { $0.category == .regulations && $0.isMultipleChoiceCapable }!
        let wrongIndex = (question.correctIndex! + 1) % question.options!.count
        store.submitAdventureAnswer(question, selectedIndex: wrongIndex)

        let context = ModelContext(container)
        let record = try context.fetch(FetchDescriptor<CardStateRecord>()).first!
        XCTAssertEqual(record.reps, 1)
        XCTAssertLessThanOrEqual(record.due.timeIntervalSinceNow, 2 * 86_400)
    }

    func testAdventureAnswerMatchesQuizGradeMapping() throws {
        let (adventureStore, adventureContainer) = try makeStore()
        let (quizStore, quizContainer) = try makeStore()
        let question = adventureStore.bank.questions.first { $0.category == .regulations && $0.isMultipleChoiceCapable }!
        let correctIndex = question.correctIndex!

        adventureStore.submitAdventureAnswer(question, selectedIndex: correctIndex)
        quizStore.submitMultipleChoice(question, selectedIndex: correctIndex, inQuiz: true)

        let adventureRecord = try ModelContext(adventureContainer).fetch(FetchDescriptor<CardStateRecord>()).first!
        let quizRecord = try ModelContext(quizContainer).fetch(FetchDescriptor<CardStateRecord>()).first!
        XCTAssertEqual(adventureRecord.stability, quizRecord.stability, accuracy: 0.0001)
        XCTAssertEqual(adventureRecord.difficulty, quizRecord.difficulty, accuracy: 0.0001)
    }

    func testAdventureAnswersCountTowardDailyGoal() throws {
        let (store, _) = try makeStore()
        let goal = store.settings.dailyGoalCards
        let questions = store.bank.questions.filter(\.isMultipleChoiceCapable).prefix(goal)
        for question in questions {
            store.submitAdventureAnswer(question, selectedIndex: question.correctIndex!)
        }
        XCTAssertTrue(store.goalMetToday)
    }

    func testAdventureAnswerConsumesNewCardAllowance() throws {
        let (store, _) = try makeStore()
        let before = store.todaySession().count
        let question = store.todaySession().first { $0.isMultipleChoiceCapable }!
        store.submitAdventureAnswer(question, selectedIndex: question.correctIndex!)
        let after = store.todaySession().count
        XCTAssertEqual(after, before - 1)
    }

    func testDrawEncounterDeckIsMCCapableAndInCategory() throws {
        let (store, _) = try makeStore()
        let drawn = store.drawEncounterDeck(count: 10, categories: [.regulations])
        XCTAssertEqual(drawn.count, 10)
        XCTAssertTrue(drawn.allSatisfy { $0.category == .regulations && $0.isMultipleChoiceCapable })
        let regulationsIDs = Set(store.bank.questions(in: .regulations).map(\.id))
        XCTAssertTrue(drawn.allSatisfy { regulationsIDs.contains($0.id) })
    }

    func testAdventureMasteryUsesReviewedRetention() throws {
        let (store, _) = try makeStore()
        let tenRegulations = store.bank.questions(in: .regulations).filter(\.isMultipleChoiceCapable).prefix(10)
        for question in tenRegulations {
            store.submitAdventureAnswer(question, selectedIndex: question.correctIndex!)
        }
        let mastery = store.adventureMastery(for: .regulations)
        XCTAssertGreaterThan(mastery.level.rawValue, MasteryLevel.novice.rawValue)
    }

    private func gymOpponent(gymID: GymID = .humanFactors, airportID: String = "KHYP", maxHP: Int) -> Opponent {
        Opponent(id: gymID.rawValue, name: "Dr. Hypoxia", nameplateName: "HYPOXIA", spriteID: "leader-hypoxia",
                 tier: .gym, maxHP: maxHP, gymID: gymID.rawValue, airportID: airportID)
    }

    private func championOpponent() -> Opponent {
        Opponent(id: "champion", name: "The DPE", nameplateName: "THE DPE", spriteID: "champion",
                 tier: .champion, maxHP: ChampionBattle.opponentHP)
    }

    func testFinishGymBattleAwardsBadgeXPAndBattleRecord() throws {
        let (store, container) = try makeStore()
        let deck = Array(store.bank.questions.filter { $0.category == .humanFactors && $0.isMultipleChoiceCapable }.prefix(10))
        let opening = BattleEngine.start(opponent: gymOpponent(maxHP: 1), deck: deck, playerMaxHP: 100)
        let (won, _) = BattleEngine.answer(opening, selectedIndex: opening.currentQuestion!.correctIndex!, answerSeconds: 10)
        XCTAssertEqual(won.outcome, .won)

        let save = store.finishBattle(won)
        XCTAssertEqual(save.badges, [.humanFactors])
        XCTAssertEqual(save.badgeQuestionIDs["humanFactors"], deck.map(\.id))
        XCTAssertEqual(store.totalXP, 100)
        XCTAssertTrue(store.earnedBadges.contains(.firstGymBadge))

        let records = try ModelContext(container).fetch(FetchDescriptor<BattleRecord>())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.won, true)
        XCTAssertEqual(records.first?.opponentID, "humanFactors")
    }

    func testFinishLostBattleAwardsNothingButKeepsReviews() throws {
        let (store, container) = try makeStore()
        let reviewedQuestion = store.bank.questions.first(where: \.isMultipleChoiceCapable)!
        store.submitAdventureAnswer(reviewedQuestion, selectedIndex: reviewedQuestion.correctIndex!)
        let xpBeforeBattle = store.totalXP

        let deck = Array(store.bank.questions.filter { $0.category == .humanFactors && $0.isMultipleChoiceCapable }.prefix(10))
        let opening = BattleEngine.start(opponent: gymOpponent(maxHP: 1_000), deck: deck, playerMaxHP: 100)
        let (lost, _) = BattleEngine.forfeit(opening)

        let save = store.finishBattle(lost)
        XCTAssertTrue(save.badges.isEmpty)
        XCTAssertEqual(save.battlesLost, 1)
        XCTAssertEqual(store.totalXP, xpBeforeBattle)
        XCTAssertFalse(store.earnedBadges.contains(.firstGymBadge))
        XCTAssertEqual(try ModelContext(container).fetch(FetchDescriptor<ReviewRecord>()).count, 1)
    }

    func testFinishForfeitedChampionBattleSkipsMockExam() throws {
        let (store, _) = try makeStore()
        let opening = BattleEngine.start(opponent: championOpponent(), deck: store.championDeck(),
                                         playerMaxHP: ChampionBattle.playerHP)
        let (forfeited, _) = BattleEngine.forfeit(opening)

        let save = store.finishBattle(forfeited)
        XCTAssertEqual(save.championWins, 0)
        XCTAssertFalse(store.earnedBadges.contains(.mockExamPassed))
        XCTAssertFalse(store.earnedBadges.contains(.regionChampion))
        XCTAssertEqual(store.totalXP, 0)
    }

    func testFinishChampionBattleAlsoFinishesMockExam() throws {
        let (store, _) = try makeStore()
        var state = BattleEngine.start(opponent: championOpponent(), deck: store.championDeck(),
                                       playerMaxHP: ChampionBattle.playerHP)
        while let question = state.currentQuestion {
            (state, _) = BattleEngine.answer(state, selectedIndex: question.correctIndex!, answerSeconds: 10)
        }
        XCTAssertEqual(state.outcome, .won)
        XCTAssertEqual(state.results.count, 60)

        let save = store.finishBattle(state)
        XCTAssertEqual(save.championWins, 1)
        XCTAssertEqual(store.totalXP, 300)
        XCTAssertTrue(store.earnedBadges.contains(.mockExamPassed))
        XCTAssertTrue(store.earnedBadges.contains(.regionChampion))
    }

    func testFinishEliteFourRunSetsClearedOnlyWhenRunIsCleared() throws {
        let (store, _) = try makeStore()
        let partial = EliteFourRun(memberIndex: 2, playerHP: 50, playerMaxHP: 100)
        let saveAfterPartial = store.finishEliteFourRun(partial)
        XCTAssertFalse(saveAfterPartial.eliteFourCleared)
        XCTAssertFalse(store.earnedBadges.contains(.eliteFourCleared))

        let cleared = EliteFourRun(memberIndex: 4, playerHP: 50, playerMaxHP: 100)
        let saveAfterCleared = store.finishEliteFourRun(cleared)
        XCTAssertTrue(saveAfterCleared.eliteFourCleared)
        XCTAssertTrue(store.earnedBadges.contains(.eliteFourCleared))
    }

    func testChampionDeckHasSixtyQuestionsInMockExamBlueprint() throws {
        let (store, _) = try makeStore()
        let deck = store.championDeck()
        XCTAssertEqual(deck.count, 60)
        for category in IFRCore.Category.allCases {
            XCTAssertEqual(deck.filter { $0.category == category }.count, category.examWeight)
        }
    }
}
