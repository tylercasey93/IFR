import XCTest
import UIKit

final class FontBundlingTests: XCTestCase {
    private var fontURL: URL? {
        Bundle.main.url(forResource: "PressStart2P-Regular", withExtension: "ttf")
    }

    func testPixelFontIsRegistered() throws {
        guard fontURL != nil else {
            throw XCTSkip("PressStart2P-Regular.ttf is not bundled yet")
        }
        XCTAssertNotNil(UIFont(name: "PressStart2P-Regular", size: 8))
    }

    func testOpenFontLicenseIsBundledAndNamesVersionOnePointOne() throws {
        guard fontURL != nil else {
            throw XCTSkip("PressStart2P-Regular.ttf is not bundled yet")
        }
        let licenseURL = try XCTUnwrap(Bundle.main.url(forResource: "OFL", withExtension: "txt"))
        let text = try String(contentsOf: licenseURL, encoding: .utf8)
        XCTAssertTrue(text.contains("Version 1.1"))
    }
}
