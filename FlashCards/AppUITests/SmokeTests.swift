// AppUITests/SmokeTests.swift
import XCTest

final class SmokeTests: XCTestCase {
    func testAppLaunches() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 10))
    }

    func testStartSessionNavigatesToStudy() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["startSession"].tap()
        XCTAssertTrue(app.tabBars.buttons["Study"].isSelected)
    }

    func testSourceButtonOpensSheetBeforeAnswerWithoutSpoiler() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["startSession"].tap()
        // Works on both card types, before the answer is revealed.
        XCTAssertTrue(app.buttons["sourceButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["sourceButton"].isEnabled)
        app.buttons["sourceButton"].tap()
        XCTAssertTrue(app.navigationBars["Source"].waitForExistence(timeout: 5))
        // Answer stays hidden until the card is flipped or answered.
        XCTAssertFalse(app.staticTexts["Answer"].exists)
    }

    func testPreviousQuestionShowsAnsweredCardReadOnly() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["startSession"].tap()
        // Answer the first card, whichever type it is.
        if app.buttons["showAnswer"].waitForExistence(timeout: 5) {
            app.buttons["showAnswer"].tap()
            app.buttons["grade-Good"].tap()
        } else if app.buttons["mcOption-0"].waitForExistence(timeout: 5) {
            app.buttons["mcOption-0"].tap()
        }
        // Page back (the MC path first waits out the 1.2s auto-advance):
        // the answered card is re-shown read-only.
        XCTAssertTrue(app.buttons["previousCard"].waitForExistence(timeout: 5))
        app.buttons["previousCard"].tap()
        XCTAssertTrue(app.buttons["reviewNewer"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts
            .matching(NSPredicate(format: "label BEGINSWITH 'Answered'")).firstMatch.exists)
        // No grading controls while reviewing.
        XCTAssertFalse(app.buttons["showAnswer"].exists)
        // Paging forward past the newest answered card resumes the session.
        app.buttons["reviewNewer"].tap()
        XCTAssertTrue(app.buttons["previousCard"].waitForExistence(timeout: 5))
    }

    func testFlashcardFlipAndGrade() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["startSession"].tap()
        // First card may be MC or flashcard; handle flashcard path when present.
        if app.buttons["showAnswer"].waitForExistence(timeout: 5) {
            app.buttons["showAnswer"].tap()
            app.buttons["grade-Good"].tap()
        } else if app.buttons["mcOption-0"].waitForExistence(timeout: 5) {
            // First card is MC: answer it and confirm the app stays healthy.
            app.buttons["mcOption-0"].tap()
        }
        XCTAssertTrue(app.tabBars.buttons["Study"].isSelected)
    }
}
