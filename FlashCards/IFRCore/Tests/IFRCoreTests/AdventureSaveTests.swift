import XCTest
@testable import IFRCore

final class AdventureSaveTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testNewSaveHasNoBadgesAndVersionOne() {
        XCTAssertEqual(AdventureSave.new.badges, [])
        XCTAssertEqual(AdventureSave.new.saveVersion, 1)
    }

    func testSaveCodableRoundTrip() throws {
        var save = AdventureSave.new
        save.badges = [.humanFactors, .navigation]
        save.badgeQuestionIDs = ["humanFactors": ["hf-001", "hf-002"]]
        save.eliteFourCleared = true
        save.championWins = 2
        save.hallOfFame = [now]
        save.battlesWon = 5
        save.battlesLost = 2
        save.visitedAirportIDs = ["KHYP", "KGYR"]
        let data = try JSONEncoder().encode(save)
        let decoded = try JSONDecoder().decode(AdventureSave.self, from: data)
        XCTAssertEqual(decoded, save)
    }

    func testExampleSaveJSONDecodesVerbatim() throws {
        let json = """
        {
          "saveVersion": 1,
          "badges": ["humanFactors", "instrumentsAndSystems"],
          "badgeQuestionIDs": {"humanFactors": ["hf-001", "hf-004", "hf-007"]},
          "eliteFourCleared": false,
          "championWins": 0,
          "hallOfFame": [811123200],
          "battlesWon": 3,
          "battlesLost": 1,
          "visitedAirportIDs": ["KHYP", "KGYR"],
          "defeatedTrainerIDs": ["student-ana"],
          "collectedItemIDs": ["drop-1"],
          "inventory": {"potion": 1},
          "repelStepsLeft": 0,
          "position": {"x": 14, "y": 1},
          "facing": "right",
          "rivalEncountersDone": [0],
          "seenCompanionStages": {"humanFactors": 2},
          "bestTowerFloor": 4,
          "lastRematchNotice": 811123200
        }
        """
        let decoded = try JSONDecoder().decode(AdventureSave.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.saveVersion, 1)
        XCTAssertEqual(decoded.badges, [.humanFactors, .instrumentsAndSystems])
        XCTAssertEqual(decoded.badgeQuestionIDs, ["humanFactors": ["hf-001", "hf-004", "hf-007"]])
        XCTAssertEqual(decoded.eliteFourCleared, false)
        XCTAssertEqual(decoded.championWins, 0)
        XCTAssertEqual(decoded.hallOfFame, [Date(timeIntervalSinceReferenceDate: 811123200)])
        XCTAssertEqual(decoded.battlesWon, 3)
        XCTAssertEqual(decoded.battlesLost, 1)
        XCTAssertEqual(decoded.visitedAirportIDs, ["KHYP", "KGYR"])
        XCTAssertEqual(decoded.position, GridPoint(x: 14, y: 1))
        XCTAssertEqual(decoded.facing, .right)
    }

    func testDecodingOlderSaveMissingKeysUsesDefaults() throws {
        let json = "{\"badges\":[]}"
        let decoded = try JSONDecoder().decode(AdventureSave.self, from: Data(json.utf8))
        XCTAssertEqual(decoded, AdventureSave.new)
    }

    func testOlderSaveWithoutDefeatedTrainerIDsDecodes() throws {
        let json = "{\"badges\":[]}"
        let decoded = try JSONDecoder().decode(AdventureSave.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.defeatedTrainerIDs, [])
    }

    func testOlderSaveWithoutInventoryDecodes() throws {
        let json = "{\"badges\":[]}"
        let decoded = try JSONDecoder().decode(AdventureSave.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.inventory, [:])
    }

    func testOlderSaveWithoutRivalEncountersDecodes() throws {
        let json = "{\"badges\":[]}"
        let decoded = try JSONDecoder().decode(AdventureSave.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.rivalEncountersDone, [])
    }

    func testOlderSaveWithoutPositionDecodes() throws {
        let json = "{\"badges\":[]}"
        let decoded = try JSONDecoder().decode(AdventureSave.self, from: Data(json.utf8))
        XCTAssertNil(decoded.position)
        XCTAssertNil(decoded.facing)
    }

    func testSeenCompanionStagesDecodeWithDefault() throws {
        let json = "{\"badges\":[]}"
        let decoded = try JSONDecoder().decode(AdventureSave.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.seenCompanionStages, [:])
        XCTAssertEqual(decoded.seenCompanionStages["humanFactors"] ?? CompanionStage.hatchling.rawValue, CompanionStage.hatchling.rawValue)
    }

    func testOlderSaveWithoutRematchNoticeDecodes() throws {
        let json = "{\"badges\":[]}"
        let decoded = try JSONDecoder().decode(AdventureSave.self, from: Data(json.utf8))
        XCTAssertNil(decoded.lastRematchNotice)
    }

    func testSaveFromNewerVersionThrows() {
        let json = "{\"saveVersion\": 2}"
        XCTAssertThrowsError(try JSONDecoder().decode(AdventureSave.self, from: Data(json.utf8))) {
            XCTAssertEqual($0 as? AdventureSaveError, .newerThanApp(2))
        }
    }
}
