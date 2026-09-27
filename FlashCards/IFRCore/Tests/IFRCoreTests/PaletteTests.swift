import XCTest
@testable import IFRCore

final class PaletteTests: XCTestCase {
    func testPaletteHasSixteenEntries() {
        XCTAssertEqual(Palette.entries.count, 16)
    }

    func testPaletteContainsPanelAccentAndAmberBytes() {
        XCTAssertEqual(Palette.entries[1], PaletteColor(r: 0x1A, g: 0x1F, b: 0x1C))
        XCTAssertEqual(Palette.entries[4], PaletteColor(r: 0x5C, g: 0xC7, b: 0x8C))
        XCTAssertEqual(Palette.entries[7], PaletteColor(r: 0xF5, g: 0xBA, b: 0x3B))
    }
}
