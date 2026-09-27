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
}
