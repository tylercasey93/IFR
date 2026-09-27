import XCTest
@testable import IFRCore

final class PixelFrameTests: XCTestCase {
    func testFrameHasThirtyEightThousandFourHundredPixels() {
        let frame = PixelFrame(fill: 1)
        XCTAssertEqual(frame.pixels.count, 38_400)
    }

    func testBlitSkipsTransparentPixels() throws {
        var frame = PixelFrame(fill: 1)
        let sprite = try PixelSprite(rows: [".f"])
        frame.blit(sprite, at: GridPoint(x: 0, y: 0))
        XCTAssertEqual(frame.pixels[0], 1)
        XCTAssertEqual(frame.pixels[1], 15)
    }

    func testBlitClipsAtFrameEdges() throws {
        var frame = PixelFrame(fill: 0)
        let sprite = try PixelSprite(rows: ["ff", "ff"])
        frame.blit(sprite, at: GridPoint(x: 236, y: 156))
        for y in 0..<PixelFrame.height {
            for x in 0..<PixelFrame.width {
                let value = frame.pixels[y * PixelFrame.width + x]
                if x >= 236 && x < 238 && y >= 156 && y < 158 {
                    XCTAssertEqual(value, 15)
                } else {
                    XCTAssertEqual(value, 0)
                }
            }
        }
    }

    func testFillRectSetsIndices() {
        var frame = PixelFrame(fill: 0)
        frame.fill(PixelRect(x: 2, y: 3, width: 4, height: 2), index: 7)
        for y in 3..<5 {
            for x in 2..<6 {
                XCTAssertEqual(frame.pixels[y * PixelFrame.width + x], 7)
            }
        }
        XCTAssertEqual(frame.pixels[0], 0)
    }

    func testFrameRectDrawsOuterAndInnerLines() {
        var frame = PixelFrame(fill: 0)
        frame.frame(PixelRect(x: 10, y: 10, width: 5, height: 5), outer: 6, inner: 9)
        XCTAssertEqual(frame.pixels[10 * PixelFrame.width + 10], 6)
        XCTAssertEqual(frame.pixels[11 * PixelFrame.width + 11], 9)
        XCTAssertEqual(frame.pixels[12 * PixelFrame.width + 12], 0)
    }

    func testLineDrawsBresenhamBetweenPoints() {
        var frame = PixelFrame(fill: 0)
        frame.line(from: GridPoint(x: 0, y: 0), to: GridPoint(x: 4, y: 2), index: 5)
        let expected: Set<Int> = [
            0 * PixelFrame.width + 0,
            1 * PixelFrame.width + 1,
            1 * PixelFrame.width + 2,
            2 * PixelFrame.width + 3,
            2 * PixelFrame.width + 4,
        ]
        let litPixels = Set(frame.pixels.indices.filter { frame.pixels[$0] == 5 })
        XCTAssertEqual(litPixels, expected)
    }

    func testCursorAndDialogueFrameRenderIntoPixelFrame() throws {
        var frame = PixelFrame(fill: 1)
        frame.frame(PixelRect(x: 0, y: 112, width: 240, height: 48), outer: 6, inner: 0)
        let cursor = try XCTUnwrap(SpriteCatalog.sprite(named: "cursor"))
        frame.blit(cursor, at: GridPoint(x: 224, y: 148))
        XCTAssertEqual(frame.pixels[112 * PixelFrame.width + 0], 6)
        XCTAssertEqual(frame.pixels[148 * PixelFrame.width + 224], 6)
    }
}
