import XCTest
@testable import IFRCore

final class OverworldTurnTests: XCTestCase {
    private func makeMap(
        _ rows: [[TileKind]],
        doorAirportIDs: [GridPoint: String] = [:],
        signTexts: [GridPoint: String] = [:],
        itemDropItemIDs: [GridPoint: String] = [:],
        areas: [TileArea] = []
    ) -> TileMap {
        TileMap(
            width: rows.first?.count ?? 0, height: rows.count, rows: rows,
            doorAirportIDs: doorAirportIDs, signTexts: signTexts, itemDropItemIDs: itemDropItemIDs,
            areas: areas
        )
    }

    private let ground = TileKind.ground
    private let cloud = TileKind.cloud
    private let door = TileKind.door
    private let sign = TileKind.sign

    private func groundRows(_ width: Int, _ height: Int) -> [[TileKind]] {
        Array(repeating: Array(repeating: ground, count: width), count: height)
    }

    private func makeState(
        x: Int, y: Int, facing: Direction = .down, pendingPath: [GridPoint] = [],
        stepsSinceEncounter: Int = 0, suppressedTrainerID: String? = nil
    ) -> OverworldState {
        OverworldState(
            position: GridPoint(x: x, y: y), facing: facing, pendingPath: pendingPath,
            stepsSinceEncounter: stepsSinceEncounter, suppressedTrainerID: suppressedTrainerID
        )
    }

    private func makeTrainer(
        id: String, position: GridPoint, facing: Direction, range: Int = 3
    ) -> Trainer {
        Trainer(
            id: id, name: "Trainer", nameplateName: "T", spriteID: "trainer-student",
            position: position, facing: facing, range: range, questionCount: 4,
            categories: [.humanFactors], dialogue: DialogueRefs(intro: "i", win: "w", lose: "l")
        )
    }

    private func makeRival(at: GridPoint, afterBadges: Int = 0) -> RivalSpec {
        RivalSpec(
            name: "Skyler", nameplateName: "SKYLER", spriteID: "rival", questionCount: 6,
            encounters: [RivalEncounter(at: at, afterBadges: afterBadges, dialogue: DialogueRefs(intro: "i", win: "w", lose: "l"))]
        )
    }

    func testCloudEncounterClearsPendingPath() {
        var rows = groundRows(3, 3)
        rows[0][1] = cloud
        let map = makeMap(rows, areas: [TileArea(id: "a", category: .weather, rect: GridRect(x: 1, y: 0, w: 1, h: 1))])
        let state = makeState(x: 1, y: 1, pendingPath: [GridPoint(x: 2, y: 2)], stepsSinceEncounter: 23)
        var rng = SeededRNG(seed: 7)
        let result = OverworldTurn.advancing(
            state, direction: .up, save: .new, map: map, trainers: [], rival: nil, using: &rng
        )
        XCTAssertEqual(result.outcome, .encounter(category: .weather))
        XCTAssertEqual(result.state.pendingPath, [])
        XCTAssertEqual(result.state.stepsSinceEncounter, 0)
    }

    func testSightingClearsPendingPath() {
        let map = makeMap(groundRows(3, 3))
        let trainer = makeTrainer(id: "t1", position: GridPoint(x: 2, y: 2), facing: .left, range: 2)
        let state = makeState(x: 1, y: 1, facing: .right, pendingPath: [GridPoint(x: 2, y: 2)])
        var rng = SeededRNG(seed: 7)
        let result = OverworldTurn.advancing(
            state, direction: .down, save: .new, map: map, trainers: [trainer], rival: nil, using: &rng
        )
        XCTAssertEqual(result.outcome, .sighted(trainer))
        XCTAssertEqual(result.state.pendingPath, [])
    }

    func testRepelDecrementsPerStepAndFreezesPityCounter() {
        var rows = groundRows(3, 3)
        rows[0][1] = cloud
        let map = makeMap(rows)
        let state = makeState(x: 1, y: 1, stepsSinceEncounter: 10)
        var save = AdventureSave.new
        save.repelStepsLeft = 5
        var rng = SeededRNG(seed: 7)
        let result = OverworldTurn.advancing(
            state, direction: .up, save: save, map: map, trainers: [], rival: nil, using: &rng
        )
        XCTAssertEqual(result.save.repelStepsLeft, 4)
        XCTAssertEqual(result.state.stepsSinceEncounter, 10)
        XCTAssertEqual(result.outcome, .none)
    }

    func testTriggeredEncounterResetsPityCounter() {
        var rows = groundRows(3, 3)
        rows[0][1] = cloud
        let map = makeMap(rows, areas: [TileArea(id: "a", category: .navigation, rect: GridRect(x: 1, y: 0, w: 1, h: 1))])
        let state = makeState(x: 1, y: 1, stepsSinceEncounter: 23)
        var rng = SeededRNG(seed: 7)
        let result = OverworldTurn.advancing(
            state, direction: .up, save: .new, map: map, trainers: [], rival: nil, using: &rng
        )
        XCTAssertEqual(result.state.stepsSinceEncounter, 0)
        XCTAssertEqual(result.outcome, .encounter(category: .navigation))
    }

    func testNonCloudStepResetsPityCounter() {
        let map = makeMap(groundRows(3, 3))
        let state = makeState(x: 1, y: 1, stepsSinceEncounter: 15)
        var rng = SeededRNG(seed: 7)
        let result = OverworldTurn.advancing(
            state, direction: .up, save: .new, map: map, trainers: [], rival: nil, using: &rng
        )
        XCTAssertEqual(result.state.stepsSinceEncounter, 0)
    }

    func testPickupOutcomeAddsItemToSaveOnce() {
        let map = makeMap(groundRows(3, 3), itemDropItemIDs: [GridPoint(x: 1, y: 0): "potion"])
        let state = makeState(x: 1, y: 1)
        var rng = SeededRNG(seed: 7)
        let first = OverworldTurn.advancing(
            state, direction: .up, save: .new, map: map, trainers: [], rival: nil, using: &rng
        )
        XCTAssertEqual(first.outcome, .pickup("potion"))
        XCTAssertTrue(first.save.collectedItemIDs.contains("potion"))
        let second = OverworldTurn.advancing(
            state, direction: .up, save: first.save, map: map, trainers: [], rival: nil, using: &rng
        )
        XCTAssertEqual(second.outcome, .none)
    }

    func testWarpAndSignPassThrough() {
        var rows = groundRows(3, 3)
        rows[0][1] = door
        rows[1][0] = sign
        let map = makeMap(
            rows,
            doorAirportIDs: [GridPoint(x: 1, y: 0): "KHYP"],
            signTexts: [GridPoint(x: 0, y: 1): "FIELD ELEVATION 8000"]
        )
        var rng = SeededRNG(seed: 7)
        let warpResult = OverworldTurn.advancing(
            makeState(x: 1, y: 1), direction: .up, save: .new, map: map, trainers: [], rival: nil, using: &rng
        )
        XCTAssertEqual(warpResult.outcome, .warp("KHYP"))
        let signResult = OverworldTurn.advancing(
            makeState(x: 1, y: 1), direction: .left, save: .new, map: map, trainers: [], rival: nil, using: &rng
        )
        XCTAssertEqual(signResult.outcome, .sign("FIELD ELEVATION 8000"))
    }

    func testUndefeatedTrainersBlockTheStep() {
        let map = makeMap(groundRows(3, 3))
        let trainer = makeTrainer(id: "t1", position: GridPoint(x: 1, y: 0), facing: .down, range: 0)
        var rng = SeededRNG(seed: 7)
        let blockedResult = OverworldTurn.advancing(
            makeState(x: 1, y: 1), direction: .up, save: .new, map: map, trainers: [trainer], rival: nil, using: &rng
        )
        XCTAssertEqual(blockedResult.outcome, .blocked)
        XCTAssertEqual(blockedResult.state.position, GridPoint(x: 1, y: 1))
        var defeatedSave = AdventureSave.new
        defeatedSave.defeatedTrainerIDs = ["t1"]
        let openResult = OverworldTurn.advancing(
            makeState(x: 1, y: 1), direction: .up, save: defeatedSave, map: map, trainers: [trainer], rival: nil, using: &rng
        )
        XCTAssertEqual(openResult.state.position, GridPoint(x: 1, y: 0))
    }

    func testRivalFiresWhenStepLandsOnOrBesideEncounterTile() {
        let map = makeMap(groundRows(3, 3))
        let rival = makeRival(at: GridPoint(x: 2, y: 2))
        var rng = SeededRNG(seed: 7)
        let result = OverworldTurn.advancing(
            makeState(x: 1, y: 1, facing: .right), direction: .right, save: .new, map: map,
            trainers: [], rival: rival, using: &rng
        )
        XCTAssertEqual(result.outcome, .rival(encounterIndex: 0))
        XCTAssertEqual(result.state.pendingPath, [])
    }

    func testEncounterTakesPrecedenceOverSightingOnTheSameStep() {
        var rows = groundRows(3, 3)
        rows[0][1] = cloud
        let map = makeMap(rows, areas: [TileArea(id: "a", category: .weather, rect: GridRect(x: 1, y: 0, w: 1, h: 1))])
        let trainer = makeTrainer(id: "t1", position: GridPoint(x: 2, y: 0), facing: .left, range: 2)
        let state = makeState(x: 1, y: 1, stepsSinceEncounter: 23)
        var rng = SeededRNG(seed: 7)
        let result = OverworldTurn.advancing(
            state, direction: .up, save: .new, map: map, trainers: [trainer], rival: nil, using: &rng
        )
        XCTAssertEqual(result.outcome, .encounter(category: .weather))
    }

    func testTrainerThatBeatPlayerIsSuppressedUntilOutOfSight() {
        let map = makeMap(groundRows(5, 5))
        let trainer = makeTrainer(id: "t1", position: GridPoint(x: 0, y: 0), facing: .right, range: 3)
        let state = makeState(x: 1, y: 0, facing: .right, suppressedTrainerID: "t1")
        var rng = SeededRNG(seed: 7)
        let stillInSight = OverworldTurn.advancing(
            state, direction: .right, save: .new, map: map, trainers: [trainer], rival: nil, using: &rng
        )
        XCTAssertEqual(stillInSight.state.suppressedTrainerID, "t1")
        XCTAssertEqual(stillInSight.outcome, .none)
        let leavingSight = OverworldTurn.advancing(
            stillInSight.state, direction: .down, save: stillInSight.save, map: map,
            trainers: [trainer], rival: nil, using: &rng
        )
        XCTAssertNil(leavingSight.state.suppressedTrainerID)
        XCTAssertEqual(leavingSight.outcome, .none)
    }
}
