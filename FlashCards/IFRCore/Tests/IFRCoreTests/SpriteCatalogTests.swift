import XCTest
@testable import IFRCore

final class SpriteCatalogTests: XCTestCase {
    private let battleSpriteIDs = [
        "player-back",
        "leader-hypoxia", "leader-gyro", "leader-reg", "leader-victor",
        "leader-plotter", "leader-nimbus", "leader-mayday", "leader-ilsa",
        "elite-sierra", "elite-tango", "elite-uniform", "elite-whiskey",
        "champion",
    ]

    private let smallSpriteIDs = [
        "badge-humanFactors", "badge-instrumentsAndSystems", "badge-regulations", "badge-navigation",
        "badge-chartsAndPlanning", "badge-weather", "badge-emergencies", "badge-approaches",
        "airport", "cursor",
    ]

    func testEveryCatalogSpriteParses() {
        XCTAssertFalse(SpriteCatalog.all.isEmpty)
        for id in battleSpriteIDs + smallSpriteIDs {
            XCTAssertNotNil(SpriteCatalog.sprite(named: id), id)
        }
    }

    func testBattleSpritesAreThirtyTwoSquare() {
        for id in battleSpriteIDs {
            let sprite = SpriteCatalog.sprite(named: id)
            XCTAssertEqual(sprite?.width, 32, id)
            XCTAssertEqual(sprite?.height, 32, id)
        }
    }

    func testBadgesAirportAndCursorAreEightSquare() {
        for id in smallSpriteIDs {
            let sprite = SpriteCatalog.sprite(named: id)
            XCTAssertEqual(sprite?.width, 8, id)
            XCTAssertEqual(sprite?.height, 8, id)
        }
    }

    func testEverySpriteUsesAtMostFourIndicesPlusTransparent() {
        for (id, sprite) in SpriteCatalog.all {
            var indices = Set<UInt8>()
            for y in 0..<sprite.height {
                for x in 0..<sprite.width {
                    let value = sprite[x, y]
                    if value != Palette.transparent {
                        indices.insert(value)
                    }
                }
            }
            XCTAssertLessThanOrEqual(indices.count, 4, id)
        }
    }

    func testMilestoneOneSpriteIDsExist() {
        for id in battleSpriteIDs + smallSpriteIDs {
            XCTAssertNotNil(SpriteCatalog.sprite(named: id), id)
        }
    }
}
