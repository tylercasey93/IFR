import XCTest
@testable import IFRCore

final class StringLiteralStripperTests: XCTestCase {
    func testKeepsCodeAndDropsLiterals() {
        let source = "let url = \"https://faa.gov\"\nlet text = \"\"\"\n// not a comment\n\"\"\"\nlet a = \"\\(b[\"c\"])\"\n"
        let code = StringLiteralStripper.strip(source)
        XCTAssertEqual(code, "let url = \nlet text = \nlet a = \n")
    }

    func testKeepsRealComments() {
        let code = StringLiteralStripper.strip("let x = \"a\" // trailing\n/* block */")
        XCTAssertEqual(code, "let x =  // trailing\n/* block */")
    }
}
