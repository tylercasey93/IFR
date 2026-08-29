import XCTest
@testable import IFRFlashCards

final class DukeQuipsTests: XCTestCase {
    func testPoolsNonEmpty() {
        XCTAssertFalse(DukeQuips.correct.isEmpty)
        XCTAssertFalse(DukeQuips.incorrect.isEmpty)
        XCTAssertFalse(DukeQuips.streak3.isEmpty)
        XCTAssertFalse(DukeQuips.streak5.isEmpty)
        XCTAssertFalse(DukeQuips.streak8.isEmpty)
    }

    func testTierSelection() {
        XCTAssertTrue(DukeQuips.correct.contains(DukeQuips.line(correct: true, streak: 1, seed: 7)))
        XCTAssertTrue(DukeQuips.streak3.contains(DukeQuips.line(correct: true, streak: 3, seed: 7)))
        XCTAssertTrue(DukeQuips.streak5.contains(DukeQuips.line(correct: true, streak: 6, seed: 7)))
        XCTAssertTrue(DukeQuips.streak8.contains(DukeQuips.line(correct: true, streak: 9, seed: 7)))
        // A wrong answer never gets a streak line.
        XCTAssertTrue(DukeQuips.incorrect.contains(DukeQuips.line(correct: false, streak: 9, seed: 7)))
    }

    func testDeterministicPerSeed() {
        XCTAssertEqual(DukeQuips.line(correct: true, streak: 1, seed: 42),
                       DukeQuips.line(correct: true, streak: 1, seed: 42))
        XCTAssertEqual(DukeQuips.line(correct: false, streak: 0, seed: Int.min),
                       DukeQuips.line(correct: false, streak: 0, seed: Int.min))
    }
}
