import XCTest
@testable import IFRCore

final class CompanionContentTests: XCTestCase {
    private func loadCompanions() throws -> [CompanionSpecies] {
        try AdventureContent.load().companions
    }

    func testOneSpeciesPerCategoryWithThreeStages() throws {
        let companions = try loadCompanions()
        XCTAssertEqual(Set(companions.map(\.category)).count, IFRCore.Category.allCases.count)
        for category in IFRCore.Category.allCases {
            let species = companions.first { $0.category == category }
            XCTAssertNotNil(species, "missing companion for \(category.rawValue)")
            XCTAssertEqual(species?.stageNames.count, 3)
            XCTAssertEqual(species?.spriteIDs.count, 3)
        }
    }

    func testEveryCompanionSpriteIDResolves() throws {
        let companions = try loadCompanions()
        for species in companions {
            for spriteID in species.spriteIDs {
                XCTAssertNotNil(SpriteCatalog.sprite(named: spriteID), "missing sprite \(spriteID)")
            }
        }
    }
}
