import XCTest
@testable import IFRCore

final class TypewriterTests: XCTestCase {
    private let welcomeText = "Welcome to the Victor region. Dr. Hypoxia is waiting at KHYP."

    func testWrapsOnWordBoundaryAtTwentyEightColumns() {
        let pages = Typewriter.paginate(welcomeText, columns: 28, rows: 2)
        let lines = pages.flatMap { $0.lines }
        XCTAssertEqual(lines, ["Welcome to the Victor", "region. Dr. Hypoxia is", "waiting at KHYP."])
        for line in lines {
            XCTAssertLessThanOrEqual(line.count, 28)
        }
    }

    func testBreaksPagesEveryTwoRows() {
        let pages = Typewriter.paginate(welcomeText, columns: 28, rows: 2)
        XCTAssertEqual(pages.count, 2)
        XCTAssertEqual(pages[0].lines, ["Welcome to the Victor", "region. Dr. Hypoxia is"])
        XCTAssertEqual(pages[1].lines, ["waiting at KHYP."])
    }

    func testRevealsOneCharacterEveryTwoFrames() {
        let page = TypewriterPage(lines: ["Hello"])
        XCTAssertEqual(Typewriter.revealCost(of: page, holding: false), [2, 4, 6, 8, 10])
        XCTAssertEqual(Typewriter.visibleCharacters(of: page, atFrame: 5, holding: false), 2)
    }

    func testHoldingRevealsOneCharacterPerFrame() {
        let page = TypewriterPage(lines: ["Hello"])
        XCTAssertEqual(Typewriter.revealCost(of: page, holding: true), [1, 2, 3, 4, 5])
        XCTAssertEqual(Typewriter.visibleCharacters(of: page, atFrame: 3, holding: true), 3)
    }

    func testPeriodQuestionExclamationAddEightFramePause() {
        let periodPage = TypewriterPage(lines: ["Hi. X"])
        XCTAssertEqual(Typewriter.revealCost(of: periodPage, holding: false), [2, 4, 6, 16, 18])
        let questionPage = TypewriterPage(lines: ["Hi? X"])
        XCTAssertEqual(Typewriter.revealCost(of: questionPage, holding: false), [2, 4, 6, 16, 18])
        let exclamationPage = TypewriterPage(lines: ["Hi! X"])
        XCTAssertEqual(Typewriter.revealCost(of: exclamationPage, holding: false), [2, 4, 6, 16, 18])
    }

    func testCommaAddsFourFramePause() {
        let page = TypewriterPage(lines: ["Hi, X"])
        XCTAssertEqual(Typewriter.revealCost(of: page, holding: false), [2, 4, 6, 12, 14])
    }

    func testHoldingSkipsPunctuationPauses() {
        let page = TypewriterPage(lines: ["A. B"])
        XCTAssertEqual(Typewriter.revealCost(of: page, holding: true), [1, 2, 3, 4])
        XCTAssertTrue(Typewriter.isComplete(page, atFrame: 4, holding: true))
        XCTAssertFalse(Typewriter.isComplete(page, atFrame: 3, holding: true))
    }

    func testIsCompleteWhenAllCharactersVisible() {
        let page = TypewriterPage(lines: ["Hi"])
        XCTAssertFalse(Typewriter.isComplete(page, atFrame: 3, holding: false))
        XCTAssertTrue(Typewriter.isComplete(page, atFrame: 4, holding: false))
    }

    func testCursorBlinksWithThirtyFramePeriod() {
        XCTAssertTrue(Typewriter.cursorVisible(atFrame: 0))
        XCTAssertTrue(Typewriter.cursorVisible(atFrame: 14))
        XCTAssertFalse(Typewriter.cursorVisible(atFrame: 15))
        XCTAssertFalse(Typewriter.cursorVisible(atFrame: 29))
        XCTAssertTrue(Typewriter.cursorVisible(atFrame: 30))
    }
}
