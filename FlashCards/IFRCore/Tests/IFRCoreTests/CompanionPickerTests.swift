import XCTest
@testable import IFRCore

final class CompanionPickerTests: XCTestCase {
    func testSingleCategoryBattleUsesThatCompanion() {
        let stages: [IFRCore.Category: CompanionStage] = [
            .regulations: .captain,
            .weather: .hatchling,
        ]
        let chosen = CompanionPicker.companion(for: [.weather], stages: stages)
        XCTAssertEqual(chosen, .weather)
    }

    func testMixedBattleUsesHighestStageThenCircuitOrder() {
        let stages: [IFRCore.Category: CompanionStage] = [
            .humanFactors: .journeyman,
            .instrumentsAndSystems: .captain,
            .regulations: .captain,
            .navigation: .hatchling,
        ]
        let chosen = CompanionPicker.companion(
            for: [.humanFactors, .instrumentsAndSystems, .regulations, .navigation], stages: stages
        )
        XCTAssertEqual(chosen, .instrumentsAndSystems)
    }
}
