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

    func testEvolutionPlaysOnceWhenMasteryCrossesStage() throws {
        let (store, _) = try makeStore()
        let tenRegulations = store.bank.questions(in: .regulations).filter(\.isMultipleChoiceCapable).prefix(10)
        for question in tenRegulations {
            store.submitAdventureAnswer(question, selectedIndex: question.correctIndex!)
        }
        let expectedStage = CompanionStage.stage(for: store.adventureMastery(for: .regulations).level)

        let evolutions = store.pendingEvolutions()

        XCTAssertEqual(evolutions, [CompanionEvolution(category: .regulations, from: .hatchling, to: expectedStage)])
        XCTAssertTrue(store.pendingEvolutions().isEmpty)
    }

    func testStageFallStoresSilently() throws {
        let (store, _) = try makeStore()
        var save = store.adventureSave
        save.seenCompanionStages[IFRCore.Category.regulations.rawValue] = CompanionStage.captain.rawValue
        store.updateAdventureSave(save)

        let evolutions = store.pendingEvolutions()

        XCTAssertTrue(evolutions.isEmpty)
        XCTAssertEqual(store.adventureSave.seenCompanionStages[IFRCore.Category.regulations.rawValue], CompanionStage.hatchling.rawValue)
    }

    private func gymOpponent(gymID: GymID = .humanFactors, airportID: String = "KHYP", maxHP: Int) -> Opponent {
        Opponent(id: gymID.rawValue, name: "Dr. Hypoxia", nameplateName: "HYPOXIA", spriteID: "leader-hypoxia",
                 tier: .gym, maxHP: maxHP, gymID: gymID.rawValue, airportID: airportID)
    }

    private func championOpponent() -> Opponent {
        Opponent(id: "champion", name: "The DPE", nameplateName: "THE DPE", spriteID: "champion",
                 tier: .champion, maxHP: ChampionBattle.opponentHP)
    }

    private func trainerOpponent(id: String = "student-ana", maxHP: Int) -> Opponent {
        Opponent(id: id, name: "Student Pilot Ana", nameplateName: "ANA", spriteID: "trainer-student",
                 tier: .trainer, maxHP: maxHP)
    }

    private func rivalOpponent(maxHP: Int) -> Opponent {
        Opponent(id: "rival", name: "Skyler", nameplateName: "SKYLER", spriteID: "rival", tier: .trainer, maxHP: maxHP)
    }

    private func cloudOpponent(maxHP: Int) -> Opponent {
        Opponent(id: "cloud-humanFactors", name: "Wild Human Factors", nameplateName: "HUMAN F",
                 spriteID: "cloud-humanFactors", tier: .cloud, maxHP: maxHP)
    }

    private func emptyDialogue() throws -> DialogueScript {
        try JSONDecoder().decode(DialogueScript.self, from: Data("{\"pages\":[]}".utf8))
    }

    private func regionContent(airportIDs: [String]) throws -> AdventureContent {
        let airports = airportIDs.map { id in
            ["id": id, "name": id, "position": ["x": 0, "y": 0], "gymID": NSNull(), "role": "waypoint"] as [String: Any]
        }
        let json: [String: Any] = [
            "version": 1,
            "region": ["airports": airports, "airways": []],
            "gyms": [],
            "champion": ["name": "The DPE", "nameplateName": "THE DPE", "spriteID": "champion",
                        "dialogue": ["intro": "c", "win": "c", "lose": "c"]],
            "dialogue": [:],
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        return try JSONDecoder().decode(AdventureContent.self, from: data)
    }

    private func dpadContent(
        rows: [String], spawn: GridPoint,
        trainer: (id: String, position: GridPoint, facing: String, range: Int)? = nil
    ) throws -> AdventureContent {
        var json: [String: Any] = [
            "version": 1,
            "region": ["airports": [], "airways": []],
            "gyms": [],
            "champion": ["name": "The DPE", "nameplateName": "THE DPE", "spriteID": "champion",
                        "dialogue": ["intro": "c", "win": "c", "lose": "c"]],
            "dialogue": [:],
            "tileMap": ["width": rows.first?.count ?? 0, "height": rows.count, "rows": rows,
                       "spawn": ["x": spawn.x, "y": spawn.y]],
        ]
        if let trainer {
            json["trainers"] = [[
                "id": trainer.id, "name": "Trainer", "nameplateName": "T1", "spriteID": "trainer-student",
                "position": ["x": trainer.position.x, "y": trainer.position.y], "facing": trainer.facing,
                "range": trainer.range, "questionCount": 1, "categories": ["humanFactors"],
                "dialogue": ["intro": "tIntro", "win": "tWin", "lose": "tLose"],
            ]]
        }
        let data = try JSONSerialization.data(withJSONObject: json)
        return try JSONDecoder().decode(AdventureContent.self, from: data)
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

    func testTrainerWinAwardsTwentyFiveAndMarksDefeated() throws {
        let (store, _) = try makeStore()
        let deck = Array(store.bank.questions.filter { $0.category == .humanFactors && $0.isMultipleChoiceCapable }.prefix(1))
        let opponent = trainerOpponent(maxHP: 1)
        let opening = BattleEngine.start(opponent: opponent, deck: deck, playerMaxHP: 100)
        let (won, _) = BattleEngine.answer(opening, selectedIndex: deck[0].correctIndex!, answerSeconds: 10)
        XCTAssertEqual(won.outcome, .won)

        let xpBefore = store.totalXP
        store.finishBattle(won)
        store.markTrainerDefeated(opponent.id)

        XCTAssertEqual(store.totalXP - xpBefore, 25)
        XCTAssertTrue(store.adventureSave.defeatedTrainerIDs.contains("student-ana"))
    }

    func testCloudWinAwardsFive() throws {
        let (store, _) = try makeStore()
        let question = store.bank.questions.first { $0.isMultipleChoiceCapable }!
        let opponent = cloudOpponent(maxHP: 1)
        let opening = BattleEngine.start(opponent: opponent, deck: [question], playerMaxHP: 100)
        let (won, _) = BattleEngine.answer(opening, selectedIndex: question.correctIndex!, answerSeconds: 10)
        XCTAssertEqual(won.outcome, .won)

        let xpBefore = store.totalXP
        store.finishBattle(won)
        XCTAssertEqual(store.totalXP - xpBefore, 5)
    }

    func testItemPickupPersistsInSave() throws {
        let (store, _) = try makeStore()
        store.collectItem("potion")
        XCTAssertEqual(store.adventureSave.inventory["potion"], 1)
        XCTAssertTrue(store.adventureSave.collectedItemIDs.contains("potion"))
    }

    func testRivalWinMarksEncounterDone() throws {
        let (store, _) = try makeStore()
        let deck = Array(store.bank.questions.filter(\.isMultipleChoiceCapable).prefix(1))
        let opponent = rivalOpponent(maxHP: 1)
        let opening = BattleEngine.start(opponent: opponent, deck: deck, playerMaxHP: 100)
        let (won, _) = BattleEngine.answer(opening, selectedIndex: deck[0].correctIndex!, answerSeconds: 10)
        XCTAssertEqual(won.outcome, .won)

        store.finishBattle(won)
        store.markRivalEncounterDone(0)
        XCTAssertTrue(store.adventureSave.rivalEncountersDone.contains(0))
    }

    func testRivalLossAlsoMarksEncounterDone() throws {
        let (store, _) = try makeStore()
        let deck = Array(store.bank.questions.filter(\.isMultipleChoiceCapable).prefix(1))
        let opponent = rivalOpponent(maxHP: 1_000)
        let opening = BattleEngine.start(opponent: opponent, deck: deck, playerMaxHP: 100)
        let (lost, _) = BattleEngine.forfeit(opening)
        XCTAssertEqual(lost.outcome, .lost)

        store.finishBattle(lost)
        store.markRivalEncounterDone(1)
        XCTAssertTrue(store.adventureSave.rivalEncountersDone.contains(1))
    }

    func testDirectToPickerListsOnlyVisitedAirports() throws {
        let (store, _) = try makeStore()
        var save = store.adventureSave
        save.visitedAirportIDs = ["KHYP"]
        store.updateAdventureSave(save)
        let content = try regionContent(airportIDs: ["KHYP", "KGYR"])

        let targets = DirectTo.targets(save: store.adventureSave, region: content.region)
        XCTAssertEqual(targets.map(\.id), ["KHYP"])
    }

    func testDPadToggleDefaultsOffAndPersists() throws {
        let (store, _) = try makeStore()
        XCTAssertFalse(store.settings.dpadEnabled)
        store.settings.dpadEnabled = true
        XCTAssertTrue(store.settings.dpadEnabled)
    }

    func testDPadStepsOneTile() throws {
        let (store, _) = try makeStore()
        let content = try dpadContent(rows: [String(repeating: ".", count: 3)], spawn: GridPoint(x: 0, y: 0))
        let model = OverworldScreenModel(content: content, store: store, now: { self.now })
        model.dpadStep(.right)
        XCTAssertEqual(model.state.position, GridPoint(x: 1, y: 0))
    }

    func testDPadCannotWalkThroughUndefeatedTrainer() throws {
        let (store, _) = try makeStore()
        let content = try dpadContent(
            rows: [String(repeating: ".", count: 3)], spawn: GridPoint(x: 0, y: 0),
            trainer: (id: "t1", position: GridPoint(x: 1, y: 0), facing: "left", range: 1))
        let model = OverworldScreenModel(content: content, store: store, now: { self.now })
        model.dpadStep(.right)
        XCTAssertEqual(model.state.position, GridPoint(x: 0, y: 0))
    }

    func testBattleBagButtonOpensSheetWithoutAdvancing() throws {
        let (store, _) = try makeStore()
        let deck = Array(store.bank.questions.filter { $0.category == .humanFactors && $0.isMultipleChoiceCapable }.prefix(3))
        let dialogue = try emptyDialogue()
        let run = BattleRun(
            opponent: gymOpponent(maxHP: 70), deck: deck, playerMaxHP: 100, missDamage: nil,
            playerSpriteID: "player-back", playerPlateName: "PILOT",
            introDialogue: dialogue, winDialogue: dialogue, loseDialogue: dialogue,
            firstTime: false, returnTo: nil, items: [])
        let model = BattleScreenModel(run: run, store: store, now: { self.now })
        let cursorBefore = model.state.cursor

        model.openBag()

        XCTAssertTrue(model.showingBag)
        XCTAssertEqual(model.state.cursor, cursorBefore)
    }

    func testWaypointAirportHasNoDoor() throws {
        let content = try AdventureContent.load()
        guard let map = content.tileMap else { return }
        let waypointIDs = Set(content.region.airports.filter { $0.role == .waypoint }.map(\.id))
        XCTAssertTrue(Set(map.doorAirportIDs.values).isDisjoint(with: waypointIDs))
    }
}
