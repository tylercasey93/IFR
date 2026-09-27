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

    private let tileAndWalkerSpriteIDs = [
        "tile-ground", "tile-airway", "tile-cloud", "tile-water", "tile-terrain", "tile-building",
        "tile-door", "tile-sign", "walker-down-0", "walker-down-1", "walker-up-0", "walker-up-1",
        "walker-left-0", "walker-left-1", "trainer-student", "path-marker",
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

    func testTileAndWalkerSpritesAreSixteenSquare() {
        for id in tileAndWalkerSpriteIDs {
            let sprite = SpriteCatalog.sprite(named: id)
            XCTAssertEqual(sprite?.width, 16, id)
            XCTAssertEqual(sprite?.height, 16, id)
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

    func testNoSpriteIsAnEmptySilhouette() {
        for (id, sprite) in SpriteCatalog.all {
            var opaqueCount = 0
            for y in 0..<sprite.height {
                for x in 0..<sprite.width {
                    if sprite[x, y] != Palette.transparent {
                        opaqueCount += 1
                    }
                }
            }
            let minimum = sprite.width == 32 ? 128 : 12
            XCTAssertGreaterThanOrEqual(opaqueCount, minimum, id)
        }
    }
}
