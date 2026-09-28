import Observation
import XCTest
import SwiftData
import IFRCore
@testable import IFRFlashCards

@MainActor
final class OverworldScreenModelTests: XCTestCase {
    private let base = Date(timeIntervalSince1970: 1_800_000_000)
    private let viewSize = CGSize(width: 240, height: 160)
    private let displayScale = 1.0

    private func makeStore() throws -> StudyStore {
        let schema = Schema([CardStateRecord.self, ReviewRecord.self, XPRecord.self,
                             StreakRecord.self, BadgeRecord.self, SettingsRecord.self,
                             AdventureSaveRecord.self, BattleRecord.self])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return try StudyStore(context: ModelContext(container), bank: QuestionBank.load())
    }

    private func makeContent(
        rows: [String], spawn: GridPoint, warp: (at: GridPoint, airportID: String)? = nil,
        area: (rect: GridRect, category: IFRCore.Category)? = nil, gymID: GymID? = nil
    ) throws -> AdventureContent {
        let json: [String: Any] = [
            "version": 1,
            "region": ["airports": regionAirports(gymID: gymID, warp: warp), "airways": []],
            "gyms": gymsJSON(gymID: gymID),
            "champion": championJSON(),
            "dialogue": dialogueJSON(gymID: gymID),
            "tileMap": tileMapJSON(rows: rows, spawn: spawn, warp: warp, area: area),
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        return try JSONDecoder().decode(AdventureContent.self, from: data)
    }

    private func regionAirports(gymID: GymID?, warp: (at: GridPoint, airportID: String)?) -> [[String: Any]] {
        guard let gymID, let warp else { return [] }
        return [[
            "id": warp.airportID, "name": "Test Field", "position": ["x": warp.at.x, "y": warp.at.y],
            "gymID": gymID.rawValue, "role": "gym",
        ]]
    }

    private func gymsJSON(gymID: GymID?) -> [[String: Any]] {
        guard let gymID else { return [] }
        return [[
            "id": gymID.rawValue, "leaderName": "Dr. Hypoxia", "nameplateName": "HYPOXIA",
            "leaderSpriteID": "leader-hypoxia", "badgeName": "Oxygen Badge", "questionCount": 3,
            "dialogue": ["intro": "gymIntro", "win": "gymWin", "lose": "gymLose"],
        ]]
    }

    private func championJSON() -> [String: Any] {
        ["name": "The DPE", "nameplateName": "THE DPE", "spriteID": "champion",
         "dialogue": ["intro": "c", "win": "c", "lose": "c"]]
    }

    private func dialogueJSON(gymID: GymID?) -> [String: Any] {
        guard gymID != nil else { return [:] }
        return ["gymIntro": ["pages": ["Welcome to the gym."]],
                "gymWin": ["pages": ["You win."]], "gymLose": ["pages": ["You lose."]]]
    }

    private func tileMapJSON(
        rows: [String], spawn: GridPoint, warp: (at: GridPoint, airportID: String)?,
        area: (rect: GridRect, category: IFRCore.Category)?
    ) -> [String: Any] {
        var map: [String: Any] = [
            "width": rows.first?.count ?? 0, "height": rows.count, "rows": rows,
            "spawn": ["x": spawn.x, "y": spawn.y],
        ]
        if let warp { map["warps"] = [["at": ["x": warp.at.x, "y": warp.at.y], "airportID": warp.airportID]] }
        if let area {
            map["areas"] = [[
                "id": "a", "category": area.category.rawValue,
                "rect": ["x": area.rect.x, "y": area.rect.y, "w": area.rect.w, "h": area.rect.h],
            ]]
        }
        return map
    }

    private func groundContent() throws -> AdventureContent {
        try makeContent(rows: [String(repeating: ".", count: 3)], spawn: GridPoint(x: 0, y: 0))
    }

    private func doorContent() throws -> AdventureContent {
        try makeContent(rows: ["..D"], spawn: GridPoint(x: 0, y: 0),
                        warp: (at: GridPoint(x: 2, y: 0), airportID: "KHYP"), gymID: .humanFactors)
    }

    private func cloudCorridorContent() throws -> AdventureContent {
        try makeContent(rows: ["D" + String(repeating: "~", count: 15)], spawn: GridPoint(x: 0, y: 0),
                        warp: (at: GridPoint(x: 0, y: 0), airportID: "KHYP"),
                        area: (rect: GridRect(x: 0, y: 0, w: 16, h: 1), category: .humanFactors), gymID: .humanFactors)
    }

    private func wideGroundContent() throws -> AdventureContent {
        try makeContent(rows: Array(repeating: String(repeating: ".", count: 20), count: 16),
                        spawn: GridPoint(x: 10, y: 8))
    }

    private func model(content: AdventureContent, store: StudyStore, seed: UInt64 = 7) -> OverworldScreenModel {
        OverworldScreenModel(content: content, store: store, now: { self.base }, makeRNG: { SeededRNG(seed: seed) })
    }

    private func tap(_ m: OverworldScreenModel, x: Int, y: Int = 0) {
        m.tapped(at: CGPoint(x: Double(x) * 16 + 1, y: Double(y) * 16 + 1), viewSize: viewSize, displayScale: displayScale)
    }

    private func advanceSteps(_ m: OverworldScreenModel, count: Int, from start: Date) -> Date {
        var now = start
        for _ in 0..<count {
            now = now.addingTimeInterval(Double(OverworldScreenModel.framesPerStep) / 60)
            m.advance(at: now)
        }
        return now
    }

    func testTapConvertsPointToTileUsingCameraAndScale() throws {
        let store = try makeStore()
        let content = try wideGroundContent()
        let m = model(content: content, store: store)
        m.tapped(at: CGPoint(x: 50, y: 34), viewSize: CGSize(width: 300, height: 200), displayScale: 2.0)
        XCTAssertEqual(m.state.pendingPath.last, GridPoint(x: 6, y: 5))
    }

    func testStepEveryEightFramesDoesNotWriteStore() throws {
        let store = try makeStore()
        let content = try groundContent()
        let m = model(content: content, store: store)
        tap(m, x: 2)
        let revisionBefore = store.revision
        m.advance(at: base.addingTimeInterval(Double(OverworldScreenModel.framesPerStep) / 60))
        XCTAssertEqual(store.revision, revisionBefore)
        XCTAssertEqual(m.state.position, GridPoint(x: 1, y: 0))
    }

    func testEveryStepGoesThroughOverworldTurn() throws {
        let store = try makeStore()
        let content = try groundContent()
        let m = model(content: content, store: store)
        tap(m, x: 2)
        _ = advanceSteps(m, count: 2, from: base)

        var rng = SeededRNG(seed: 7)
        let step1 = OverworldTurn.advancing(
            OverworldState(position: GridPoint(x: 0, y: 0), facing: .down), direction: .right,
            save: AdventureSave.new, map: content.tileMap!, trainers: [], rival: nil, using: &rng)
        let step2 = OverworldTurn.advancing(
            step1.state, direction: .right, save: step1.save, map: content.tileMap!,
            trainers: [], rival: nil, using: &rng)
        XCTAssertEqual(m.state, step2.state)
    }

    func testPositionSavedWhenPathCompletes() throws {
        let store = try makeStore()
        let content = try groundContent()
        let m = model(content: content, store: store)
        tap(m, x: 2)
        _ = advanceSteps(m, count: 2, from: base)
        XCTAssertEqual(store.adventureSave.position, GridPoint(x: 2, y: 0))
        XCTAssertTrue(m.state.pendingPath.isEmpty)
    }

    func testPositionSavedBeforeBattle() throws {
        let store = try makeStore()
        let content = try cloudCorridorContent()
        let m = model(content: content, store: store)
        tap(m, x: 15)
        _ = advanceSteps(m, count: 14, from: base)
        XCTAssertEqual(store.adventureSave.position, GridPoint(x: 14, y: 0))
    }

    func testPositionSavedOnSceneBackground() throws {
        let store = try makeStore()
        let content = try groundContent()
        let m = model(content: content, store: store)
        tap(m, x: 2)
        _ = advanceSteps(m, count: 1, from: base)
        m.sceneDidEnterBackground()
        XCTAssertEqual(store.adventureSave.position, m.state.position)
    }

    func testEncounterOutcomePresentsCloudBattleRun() throws {
        let store = try makeStore()
        let content = try cloudCorridorContent()
        let m = model(content: content, store: store)
        tap(m, x: 15)
        _ = advanceSteps(m, count: 14, from: base)
        XCTAssertNotNil(m.activeBattle)
        XCTAssertEqual(m.activeBattle?.opponent.tier, .cloud)
        XCTAssertEqual(m.activeBattle?.returnTo, GridPoint(x: 14, y: 0))
        XCTAssertTrue(m.state.pendingPath.isEmpty)
    }

    func testWarpOnUnlockedGymDoorTypesIntroThenShowsChallenge() throws {
        let store = try makeStore()
        let content = try doorContent()
        let m = model(content: content, store: store)
        tap(m, x: 2)
        _ = advanceSteps(m, count: 2, from: base)
        XCTAssertEqual(m.dialogue?.pages, ["Welcome to the gym."])
        XCTAssertEqual(m.challengeableGymID, .humanFactors)
        m.challengeGym()
        XCTAssertNotNil(m.activeBattle)
        XCTAssertEqual(m.activeBattle?.opponent.tier, .gym)
        XCTAssertEqual(m.activeBattle?.returnTo, GridPoint(x: 2, y: 0))
    }

    func testLossAwayFromDoorRespawnsAtNearestVisitedAirport() throws {
        let store = try makeStore()
        var seededSave = store.adventureSave
        seededSave.visitedAirportIDs = ["KHYP"]
        store.updateAdventureSave(seededSave)

        let content = try cloudCorridorContent()
        let m = model(content: content, store: store)
        tap(m, x: 15)
        _ = advanceSteps(m, count: 14, from: base)
        guard let run = m.activeBattle else { return XCTFail("expected a cloud battle") }
        let opening = BattleEngine.start(opponent: run.opponent, deck: run.deck, playerMaxHP: run.playerMaxHP, missDamage: run.missDamage)
        let (lost, _) = BattleEngine.forfeit(opening)
        store.finishBattle(lost)
        m.battleDismissed()

        XCTAssertEqual(m.state.position, GridPoint(x: 0, y: 0))
        XCTAssertEqual(m.state.facing, .down)
        XCTAssertEqual(store.adventureSave.position, GridPoint(x: 0, y: 0))
    }
}
