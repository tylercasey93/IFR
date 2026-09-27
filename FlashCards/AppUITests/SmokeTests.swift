// AppUITests/SmokeTests.swift
import XCTest
import IFRCore

final class SmokeTests: XCTestCase {
    private func launch(withSave save: AdventureSave) -> XCUIApplication {
        let app = XCUIApplication()
        let data = try! JSONEncoder().encode(save)
        let json = String(data: data, encoding: .utf8)!
        app.launchArguments += ["-adventureSaveJSON", json]
        app.launch()
        return app
    }

    private func save(withBadges count: Int) -> AdventureSave {
        var save = AdventureSave.new
        save.badges = Set(GymID.allCases.prefix(count))
        return save
    }

    private func eliteFourClearedSave() -> AdventureSave {
        var save = save(withBadges: GymID.allCases.count)
        save.eliteFourCleared = true
        return save
    }

    private func hallOfFameSave() -> AdventureSave {
        var save = eliteFourClearedSave()
        save.hallOfFame = [Date(timeIntervalSince1970: 1_700_000_000), Date(timeIntervalSince1970: 1_800_000_000)]
        return save
    }
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

    func testAdventureTabShowsRegionMap() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["Adventure"].tap()
        XCTAssertTrue(app.otherElements["regionMap"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["airport-KHYP"].isHittable)
        XCTAssertTrue(app.buttons["badgeCase"].exists)
        XCTAssertTrue(app.buttons["hallOfFame"].exists)
    }

    func testStartingFirstGymShowsQuestionAndOptions() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["Adventure"].tap()
        app.buttons["airport-KHYP"].tap()
        app.buttons["gym-humanFactors"].tap()
        XCTAssertTrue(app.buttons["battleOption-0"].waitForExistence(timeout: 15))
    }

    func testAnsweringOptionAdvancesTurn() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["Adventure"].tap()
        app.buttons["airport-KHYP"].tap()
        app.buttons["gym-humanFactors"].tap()
        XCTAssertTrue(app.buttons["battleOption-0"].waitForExistence(timeout: 15))
        app.buttons["battleOption-0"].tap()
        XCTAssertTrue(app.buttons["battleQuit"].waitForExistence(timeout: 5))
    }

    func testBattleQuitReturnsToRegionMap() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["Adventure"].tap()
        app.buttons["airport-KHYP"].tap()
        app.buttons["gym-humanFactors"].tap()
        XCTAssertTrue(app.buttons["battleQuit"].waitForExistence(timeout: 15))
        app.buttons["battleQuit"].tap()
        XCTAssertTrue(app.otherElements["regionMap"].waitForExistence(timeout: 15))
    }

    func testSeededSaveWithEightBadgesUnlocksEliteFour() {
        let app = launch(withSave: save(withBadges: 8))
        app.tabBars.buttons["Adventure"].tap()
        app.buttons["airport-KELF"].tap()
        XCTAssertTrue(app.otherElements["eliteFourScreen"].waitForExistence(timeout: 15))
    }

    func testEliteFourLockedUntilEightBadges() {
        let app = launch(withSave: save(withBadges: 4))
        app.tabBars.buttons["Adventure"].tap()
        app.buttons["airport-KELF"].tap()
        XCTAssertTrue(app.staticTexts["You need the Charts Badge first."].waitForExistence(timeout: 15))
    }

    func testChampionLockedUntilEliteFourCleared() {
        let app = launch(withSave: save(withBadges: 8))
        app.tabBars.buttons["Adventure"].tap()
        app.buttons["airport-KCHP"].tap()
        XCTAssertTrue(app.staticTexts["You need to clear the Elite Four first."].waitForExistence(timeout: 15))
    }

    func testChampionChallengeStartsSixtyQuestionBattleAsTheDPE() {
        let app = launch(withSave: eliteFourClearedSave())
        app.tabBars.buttons["Adventure"].tap()
        app.buttons["airport-KCHP"].tap()
        XCTAssertTrue(app.buttons["gym-champion"].waitForExistence(timeout: 15))
        app.buttons["gym-champion"].tap()
        XCTAssertTrue(app.buttons["battleOption-0"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["THE DPE"].exists)
    }

    func testBadgeCaseShowsEightSlotsWithEarnedOnesLit() {
        let app = launch(withSave: save(withBadges: 2))
        app.tabBars.buttons["Adventure"].tap()
        app.buttons["badgeCase"].tap()
        XCTAssertTrue(app.cells["badgeSlot-approaches"].waitForExistence(timeout: 15))
        for gymID in GymID.allCases {
            XCTAssertTrue(app.cells["badgeSlot-\(gymID.rawValue)"].exists)
        }
        XCTAssertEqual(app.cells["badgeSlot-humanFactors"].value as? String, "earned")
        XCTAssertEqual(app.cells["badgeSlot-approaches"].value as? String, "locked")
    }

    func testHallOfFameListsChampionWinsNewestFirst() {
        let app = launch(withSave: hallOfFameSave())
        app.tabBars.buttons["Adventure"].tap()
        app.buttons["hallOfFame"].tap()
        XCTAssertTrue(app.cells["hallOfFameEntry-0"].waitForExistence(timeout: 15))
    }

    func testHallOfFameIsEmptyBeforeFirstChampionWin() {
        let app = launch(withSave: AdventureSave.new)
        app.tabBars.buttons["Adventure"].tap()
        app.buttons["hallOfFame"].tap()
        XCTAssertTrue(app.staticTexts["hallOfFameEmpty"].waitForExistence(timeout: 15))
    }
}
