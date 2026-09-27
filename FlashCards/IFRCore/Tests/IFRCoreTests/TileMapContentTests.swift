import XCTest
@testable import IFRCore

final class TileMapContentTests: XCTestCase {
    private func loadedContent() throws -> AdventureContent {
        try AdventureContent.load()
    }

    private func replacingTileMap(_ content: AdventureContent, with tileMap: TileMap) -> AdventureContent {
        AdventureContent(
            version: content.version, region: content.region, gyms: content.gyms, eliteFour: content.eliteFour,
            champion: content.champion, dialogue: content.dialogue, system: content.system, items: content.items,
            tileMap: tileMap, trainers: content.trainers, rival: content.rival, companions: content.companions
        )
    }

    private func replacingTrainers(_ content: AdventureContent, with trainers: [Trainer]) -> AdventureContent {
        AdventureContent(
            version: content.version, region: content.region, gyms: content.gyms, eliteFour: content.eliteFour,
            champion: content.champion, dialogue: content.dialogue, system: content.system, items: content.items,
            tileMap: content.tileMap, trainers: trainers, rival: content.rival, companions: content.companions
        )
    }

    private func replacingRival(_ content: AdventureContent, with rival: RivalSpec) -> AdventureContent {
        AdventureContent(
            version: content.version, region: content.region, gyms: content.gyms, eliteFour: content.eliteFour,
            champion: content.champion, dialogue: content.dialogue, system: content.system, items: content.items,
            tileMap: content.tileMap, trainers: content.trainers, rival: rival, companions: content.companions
        )
    }

    private func mutatingRows(_ tileMap: TileMap, at point: GridPoint, to kind: TileKind) -> TileMap {
        var rows = tileMap.rows
        rows[point.y][point.x] = kind
        return TileMap(
            width: tileMap.width, height: tileMap.height, rows: rows, doorAirportIDs: tileMap.doorAirportIDs,
            signTexts: tileMap.signTexts, itemDropItemIDs: tileMap.itemDropItemIDs, spawn: tileMap.spawn,
            areas: tileMap.areas
        )
    }

    func testEveryDoorHasWarpAndEveryWarpSitsOnDoor() throws {
        let base = try loadedContent()
        let tileMap = try XCTUnwrap(base.tileMap)
        var doorAirportIDs = tileMap.doorAirportIDs
        doorAirportIDs.removeValue(forKey: GridPoint(x: 3, y: 14))
        let brokenMap = TileMap(
            width: tileMap.width, height: tileMap.height, rows: tileMap.rows, doorAirportIDs: doorAirportIDs,
            signTexts: tileMap.signTexts, itemDropItemIDs: tileMap.itemDropItemIDs, spawn: tileMap.spawn,
            areas: tileMap.areas
        )
        let content = replacingTileMap(base, with: brokenMap)
        XCTAssertThrowsError(try content.validate()) {
            XCTAssertEqual($0 as? AdventureContentError, .unknownReference(from: "tileMap", to: "3-14"))
        }
    }

    func testEveryAirportHasExactlyOneDoor() throws {
        let base = try loadedContent()
        let tileMap = try XCTUnwrap(base.tileMap)
        var doorAirportIDs = tileMap.doorAirportIDs
        doorAirportIDs[GridPoint(x: 3, y: 14)] = "KGYR"
        let brokenMap = TileMap(
            width: tileMap.width, height: tileMap.height, rows: tileMap.rows, doorAirportIDs: doorAirportIDs,
            signTexts: tileMap.signTexts, itemDropItemIDs: tileMap.itemDropItemIDs, spawn: tileMap.spawn,
            areas: tileMap.areas
        )
        let content = replacingTileMap(base, with: brokenMap)
        XCTAssertThrowsError(try content.validate()) {
            XCTAssertEqual($0 as? AdventureContentError, .unreachableDoor(airportID: "KHYP"))
        }
    }

    func testSpawnIsWalkable() throws {
        let base = try loadedContent()
        let tileMap = try XCTUnwrap(base.tileMap)
        let brokenMap = TileMap(
            width: tileMap.width, height: tileMap.height, rows: tileMap.rows, doorAirportIDs: tileMap.doorAirportIDs,
            signTexts: tileMap.signTexts, itemDropItemIDs: tileMap.itemDropItemIDs, spawn: GridPoint(x: 0, y: 0),
            areas: tileMap.areas
        )
        let content = replacingTileMap(base, with: brokenMap)
        XCTAssertThrowsError(try content.validate()) {
            XCTAssertEqual($0 as? AdventureContentError, .unknownTile(x: 0, y: 0))
        }
    }

    func testEveryDoorReachableFromSpawn() throws {
        let base = try loadedContent()
        let tileMap = try XCTUnwrap(base.tileMap)
        let brokenMap = mutatingRows(tileMap, at: GridPoint(x: 3, y: 15), to: .terrain)
        let content = replacingTileMap(base, with: brokenMap)
        XCTAssertThrowsError(try content.validate()) {
            XCTAssertEqual($0 as? AdventureContentError, .unreachableDoor(airportID: "KHYP"))
        }
    }

    func testTrainersStandOnWalkableTilesFacingWalkableLine() throws {
        let base = try loadedContent()
        let trainer = Trainer(
            id: "student-ana", name: "Student Pilot Ana", nameplateName: "ANA", spriteID: "trainer-student",
            position: GridPoint(x: 3, y: 16), facing: .up, range: 3, questionCount: 4,
            categories: [.humanFactors], dialogue: DialogueRefs(intro: "ana-intro", win: "ana-win", lose: "ana-lose")
        )
        let content = replacingTrainers(base, with: [trainer])
        XCTAssertThrowsError(try content.validate()) {
            XCTAssertEqual($0 as? AdventureContentError, .unknownTile(x: 3, y: 13))
        }
    }

    func testItemDropsAndSignsOnWalkableTiles() throws {
        let base = try loadedContent()
        let tileMap = try XCTUnwrap(base.tileMap)
        let brokenMap = mutatingRows(tileMap, at: GridPoint(x: 25, y: 17), to: .terrain)
        let content = replacingTileMap(base, with: brokenMap)
        XCTAssertThrowsError(try content.validate()) {
            XCTAssertEqual($0 as? AdventureContentError, .unknownTile(x: 25, y: 17))
        }
    }

    func testEveryCloudTileLiesInExactlyOneArea() throws {
        let base = try loadedContent()
        let tileMap = try XCTUnwrap(base.tileMap)
        let brokenMap = mutatingRows(tileMap, at: GridPoint(x: 5, y: 5), to: .cloud)
        let content = replacingTileMap(base, with: brokenMap)
        XCTAssertThrowsError(try content.validate()) {
            XCTAssertEqual($0 as? AdventureContentError, .unknownReference(from: "cloud", to: "5-5"))
        }
    }

    func testRivalEncountersSitOnWalkableTiles() throws {
        let base = try loadedContent()
        let rival = try XCTUnwrap(base.rival)
        let brokenEncounter = RivalEncounter(
            at: GridPoint(x: 0, y: 0), afterBadges: 1,
            dialogue: DialogueRefs(intro: "skyler-1-intro", win: "skyler-1-win", lose: "skyler-1-lose")
        )
        let brokenRival = RivalSpec(
            name: rival.name, nameplateName: rival.nameplateName, spriteID: rival.spriteID,
            questionCount: rival.questionCount, encounters: [brokenEncounter]
        )
        let content = replacingRival(base, with: brokenRival)
        XCTAssertThrowsError(try content.validate()) {
            XCTAssertEqual($0 as? AdventureContentError, .unknownTile(x: 0, y: 0))
        }
    }
}
