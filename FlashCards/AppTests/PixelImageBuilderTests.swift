import XCTest
import IFRCore
@testable import IFRFlashCards

final class PixelImageBuilderTests: XCTestCase {
    private func bytes(of image: CGImage) -> [UInt8] {
        guard let data = image.dataProvider?.data else { return [] }
        return [UInt8](data as Data)
    }

    func testBuilderProducesTwoHundredFortyByOneSixtyImage() throws {
        let frame = PixelFrame(fill: 1)
        let image = try XCTUnwrap(PixelImageBuilder.image(from: frame))
        XCTAssertEqual(image.width, 240)
        XCTAssertEqual(image.height, 160)
    }

    func testPaletteIndexFourMapsToAccentRGBA() throws {
        let frame = PixelFrame(fill: 4)
        let image = try XCTUnwrap(PixelImageBuilder.image(from: frame))
        let pixels = bytes(of: image)
        XCTAssertEqual(pixels[0], 0x5C)
        XCTAssertEqual(pixels[1], 0xC7)
        XCTAssertEqual(pixels[2], 0x8C)
        XCTAssertEqual(pixels[3], 0xFF)
    }

    func testTransparentIndexMapsToZeroAlpha() throws {
        let frame = PixelFrame(fill: Palette.transparent)
        let image = try XCTUnwrap(PixelImageBuilder.image(from: frame))
        let pixels = bytes(of: image)
        XCTAssertEqual(pixels[3], 0)
    }
}
