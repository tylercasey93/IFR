import XCTest
@testable import IFRCore

final class CircuitRulesTests: XCTestCase {
    func testFirstGymAlwaysUnlocked() {
        XCTAssertTrue(CircuitRules.isUnlocked(.humanFactors, save: .new))
    }

    func testGymUnlocksOnlyAfterPreviousBadge() {
        var save = AdventureSave.new
        XCTAssertFalse(CircuitRules.isUnlocked(.instrumentsAndSystems, save: save))
        save.badges = [.humanFactors]
        XCTAssertTrue(CircuitRules.isUnlocked(.instrumentsAndSystems, save: save))
    }

    func testEliteFourRequiresEightBadges() {
        var save = AdventureSave.new
        save.badges = Set(GymID.allCases.dropLast())
        XCTAssertFalse(CircuitRules.isEliteFourUnlocked(save: save))
        save.badges = Set(GymID.allCases)
        XCTAssertTrue(CircuitRules.isEliteFourUnlocked(save: save))
    }

    func testChampionRequiresEliteFourCleared() {
        var save = AdventureSave.new
        save.badges = Set(GymID.allCases)
        XCTAssertFalse(CircuitRules.isChampionUnlocked(save: save))
        save.eliteFourCleared = true
        XCTAssertTrue(CircuitRules.isChampionUnlocked(save: save))
    }

    func testClearedEliteFourAndChampionStayUnlocked() {
        var save = AdventureSave.new
        save.badges = Set(GymID.allCases)
        save.eliteFourCleared = true
        save.battlesLost += 1
        XCTAssertTrue(CircuitRules.isEliteFourUnlocked(save: save))
        XCTAssertTrue(CircuitRules.isChampionUnlocked(save: save))
    }
}
