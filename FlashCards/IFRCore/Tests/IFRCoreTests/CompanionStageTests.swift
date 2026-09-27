import XCTest
@testable import IFRCore

final class CompanionStageTests: XCTestCase {
    func testNoviceAndApprenticeAreHatchling() {
        XCTAssertEqual(CompanionStage.stage(for: .novice), .hatchling)
        XCTAssertEqual(CompanionStage.stage(for: .apprentice), .hatchling)
    }

    func testCompetentAndProficientAreJourneyman() {
        XCTAssertEqual(CompanionStage.stage(for: .competent), .journeyman)
        XCTAssertEqual(CompanionStage.stage(for: .proficient), .journeyman)
    }

    func testInstrumentMasterIsCaptain() {
        XCTAssertEqual(CompanionStage.stage(for: .instrumentMaster), .captain)
    }

    func testEvolvedWhenStageRises() {
        XCTAssertTrue(CompanionStage.evolved(from: .hatchling, to: .journeyman))
        XCTAssertTrue(CompanionStage.evolved(from: .journeyman, to: .captain))
    }

    func testNotEvolvedWhenStageFalls() {
        XCTAssertFalse(CompanionStage.evolved(from: .journeyman, to: .hatchling))
        XCTAssertFalse(CompanionStage.evolved(from: .captain, to: .captain))
    }
}
