import XCTest
@testable import IFRCore

final class SchedulerTests: XCTestCase {
    let scheduler = Scheduler()
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    func testNewCardGoodSchedulesInFuture() {
        let s = scheduler.review(.new(questionID: "q"), grade: .good, at: t0)
        XCTAssertGreaterThan(s.due, t0)
        XCTAssertEqual(s.reps, 1)
        XCTAssertEqual(s.lastReview, t0)
    }

    func testAgainIsSoonerThanGoodIsSoonerThanEasy() {
        let again = scheduler.review(.new(questionID: "q"), grade: .again, at: t0)
        let good = scheduler.review(.new(questionID: "q"), grade: .good, at: t0)
        let easy = scheduler.review(.new(questionID: "q"), grade: .easy, at: t0)
        XCTAssertLessThan(again.due, good.due)
        XCTAssertLessThan(good.due, easy.due)
    }

    func testAgainIncrementsLapsesOnReviewCard() {
        var s = scheduler.review(.new(questionID: "q"), grade: .good, at: t0)
        s = scheduler.review(s, grade: .again, at: s.due)
        XCTAssertEqual(s.lapses, 1)
    }

    func testIntervalGrowsAcrossSuccessfulReviews() {
        var s = scheduler.review(.new(questionID: "q"), grade: .good, at: t0)
        let firstInterval = s.due.timeIntervalSince(t0)
        let secondReviewDate = s.due
        s = scheduler.review(s, grade: .good, at: secondReviewDate)
        let secondInterval = s.due.timeIntervalSince(secondReviewDate)
        XCTAssertGreaterThan(secondInterval, firstInterval)
    }

    func testRetrievabilityIsZeroForUnseenAndDecays() {
        XCTAssertEqual(scheduler.retrievability(of: .new(questionID: "q"), at: t0), 0)
        let s = scheduler.review(.new(questionID: "q"), grade: .good, at: t0)
        let soon = scheduler.retrievability(of: s, at: t0.addingTimeInterval(3600))
        let later = scheduler.retrievability(of: s, at: t0.addingTimeInterval(30 * 86_400))
        XCTAssertGreaterThan(soon, later)
        XCTAssertGreaterThan(soon, 0.9)
    }

    func testGoldenValuesFirstReviewAndSecondGood() {
        // Golden regression values: FSRS-5 default-parameter reference
        // values, verified against swift-fsrs 5.0.0 source
        // (FSRSDefaults.defaultW / FSRSAlgorithm / LongTermScheduler).
        // The qualitative tests above would still pass with a transposed
        // weight index or a wrong constant; these exact pins would not.
        // Note: swift-fsrs 5.0.0 ships w[2] = 3.1262 (older FSRS-5 weight
        // snapshot), not the later canonical publication's 3.173.

        // First-review intervals in whole days at desiredRetention 0.9
        // (interval modifier is exactly 1.0 there), after cross-grade
        // ordering: again 1, hard 2, good 3, easy 15.
        let expectedIntervalDays: [Grade: Double] = [.again: 1, .hard: 2, .good: 3, .easy: 15]
        for (grade, days) in expectedIntervalDays {
            let s = scheduler.review(.new(questionID: "q"), grade: grade, at: t0)
            XCTAssertEqual(s.due.timeIntervalSince(t0) / 86_400, days, accuracy: 0.01,
                           "first-review interval for \(grade)")
        }

        // First `good`: stability == initStability(.good) == w[2] == 3.1262;
        // difficulty == D0(3) == w[4] - e^(w[5]*(3-1)) + 1 == 5.314577829571.
        let first = scheduler.review(.new(questionID: "q"), grade: .good, at: t0)
        XCTAssertEqual(first.stability, 3.1262, accuracy: 1e-6)
        XCTAssertEqual(first.difficulty, 5.314577829571, accuracy: 1e-6)

        // Second `good` exactly at the due date (elapsed = 3 days,
        // retrievability ~0.9035): next recall stability == 11.388439.
        let second = scheduler.review(first, grade: .good, at: first.due)
        XCTAssertEqual(second.stability, 11.388439, accuracy: 0.01)
    }

    func testGradeFromMCCorrect() {
        XCTAssertEqual(Grade(mcCorrect: true), .good)
        XCTAssertEqual(Grade(mcCorrect: false), .again)
    }

    func testGoldenValuesForgetAndHardEasyPaths() {
        // Extends testGoldenValuesFirstReviewAndSecondGood to pin the
        // forget path (nextForgetStability, w[11]-w[14]) and the
        // hard/easy recall multipliers (w[15], w[16]) against
        // transposition. Base state: first-reviewed `.good` at t0
        // (stability == w[2] == 3.1262, difficulty == D0(3) ==
        // 5.314577829571). Each branch reviews that SAME base state again,
        // exactly at its due date (elapsed == 3 days, retrievability
        // ~0.9034), with `.again`, `.hard`, and `.easy` respectively.
        let base = scheduler.review(.new(questionID: "q"), grade: .good, at: t0)
        XCTAssertEqual(base.stability, 3.1262, accuracy: 1e-6)
        let dueDate = base.due

        let again = scheduler.review(base, grade: .again, at: dueDate)
        XCTAssertEqual(again.stability, 1.096375, accuracy: 0.001,
                       "forget path (nextForgetStability, w[11]-w[14])")

        let hard = scheduler.review(base, grade: .hard, at: dueDate)
        XCTAssertEqual(hard.stability, 5.114921, accuracy: 0.001,
                       "recall path with hard multiplier w[15]")

        let easy = scheduler.review(base, grade: .easy, at: dueDate)
        XCTAssertEqual(easy.stability, 27.471714, accuracy: 0.001,
                       "recall path with easy multiplier w[16]")
    }

    func testCardStateCodableRoundTrip() throws {
        // Compare fields, not whole-struct equality: JSON's decimal encoding of
        // Date can lose sub-millisecond precision.
        let s = scheduler.review(.new(questionID: "q"), grade: .hard, at: t0)
        let decoded = try JSONDecoder().decode(CardState.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(decoded.questionID, s.questionID)
        XCTAssertEqual(decoded.reps, s.reps)
        XCTAssertEqual(decoded.lapses, s.lapses)
        XCTAssertEqual(decoded.stability, s.stability, accuracy: 1e-9)
        XCTAssertEqual(decoded.difficulty, s.difficulty, accuracy: 1e-9)
        XCTAssertEqual(decoded.due.timeIntervalSince1970, s.due.timeIntervalSince1970, accuracy: 0.001)
    }
}
