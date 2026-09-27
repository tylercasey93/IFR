import XCTest
@testable import IFRCore

final class BattleDialogueTests: XCTestCase {
    private let intro = DialogueScript(pages: ["intro"])
    private let win = DialogueScript(pages: ["win"])
    private let lose = DialogueScript(pages: ["lose"])

    func testNoOutcomeShowsIntro() {
        let result = BattleDialogue.current(outcome: nil, intro: intro, win: win, lose: lose)
        XCTAssertEqual(result, intro)
    }

    func testWonOutcomeShowsWin() {
        let result = BattleDialogue.current(outcome: .won, intro: intro, win: win, lose: lose)
        XCTAssertEqual(result, win)
    }

    func testLostOutcomeShowsLose() {
        let result = BattleDialogue.current(outcome: .lost, intro: intro, win: win, lose: lose)
        XCTAssertEqual(result, lose)
    }
}
