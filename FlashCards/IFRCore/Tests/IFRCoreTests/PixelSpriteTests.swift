import XCTest
@testable import IFRCore

final class PixelSpriteTests: XCTestCase {
    func testSpriteParsesWidthHeightAndIndices() throws {
        let sprite = try PixelSprite(rows: ["012", "345"])
        XCTAssertEqual(sprite.width, 3)
        XCTAssertEqual(sprite.height, 2)
        XCTAssertEqual(sprite[0, 0], 0)
        XCTAssertEqual(sprite[1, 0], 1)
        XCTAssertEqual(sprite[2, 0], 2)
        XCTAssertEqual(sprite[0, 1], 3)
        XCTAssertEqual(sprite[1, 1], 4)
        XCTAssertEqual(sprite[2, 1], 5)
    }

    func testSpriteRejectsRaggedRows() {
        XCTAssertThrowsError(try PixelSprite(rows: ["00", "0"])) { error in
            XCTAssertEqual(error as? PixelSpriteError, .raggedRows)
        }
    }

    func testSpriteRejectsUnknownCharacter() {
        XCTAssertThrowsError(try PixelSprite(rows: ["0x"])) { error in
            XCTAssertEqual(error as? PixelSpriteError, .badCharacter("x"))
        }
    }

    func testDotIsTransparentAndHexMapsToIndex() throws {
        let sprite = try PixelSprite(rows: [".f"])
        XCTAssertEqual(sprite[0, 0], Palette.transparent)
        XCTAssertEqual(sprite[1, 0], 15)
    }

    func testFlippedHorizontallyMirrorsColumns() throws {
        let sprite = try PixelSprite(rows: ["012"])
        let flipped = sprite.flippedHorizontally()
        XCTAssertEqual(flipped[0, 0], 2)
        XCTAssertEqual(flipped[1, 0], 1)
        XCTAssertEqual(flipped[2, 0], 0)
    }

    func testRecolouredReplacesMappedIndicesOnly() throws {
        let sprite = try PixelSprite(rows: ["012"])
        let recoloured = sprite.recoloured([1: 9])
        XCTAssertEqual(recoloured[0, 0], 0)
        XCTAssertEqual(recoloured[1, 0], 9)
        XCTAssertEqual(recoloured[2, 0], 2)
    }
}
