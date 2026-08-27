import XCTest
@testable import IFRCore

final class StreakEngineTests: XCTestCase {
    var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }()
    lazy var engine = StreakEngine(calendar: calendar)

    private func day(_ n: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: n, hour: hour))!
    }

    func testFirstGoalStartsStreakAtOne() {
        let s = engine.recordGoalMet(on: day(1), state: StreakState())
        XCTAssertEqual(s.current, 1)
        XCTAssertEqual(s.longest, 1)
    }

    func testConsecutiveDaysExtend() {
        var s = engine.recordGoalMet(on: day(1), state: StreakState())
        s = engine.recordGoalMet(on: day(2), state: s)
        XCTAssertEqual(s.current, 2)
    }

    func testSameDayTwiceIsNoOp() {
        var s = engine.recordGoalMet(on: day(1, hour: 8), state: StreakState())
        s = engine.recordGoalMet(on: day(1, hour: 22), state: s)
        XCTAssertEqual(s.current, 1)
    }

    func testMissedDayWithoutFreezeResets() {
        var s = engine.recordGoalMet(on: day(1), state: StreakState())
        s = engine.recordGoalMet(on: day(3), state: s)
        XCTAssertEqual(s.current, 1)
        XCTAssertEqual(s.longest, 1)
    }

    func testFreezeCoversOneMissedDay() {
        var s = StreakState()
        s.freezes = 1
        s = engine.recordGoalMet(on: day(1), state: s)
        s = engine.recordGoalMet(on: day(3), state: s)
        XCTAssertEqual(s.current, 2)
        XCTAssertEqual(s.freezes, 0)
    }

    func testTwoMissedDaysWithOneFreezeResets() {
        var s = StreakState()
        s.freezes = 1
        s = engine.recordGoalMet(on: day(1), state: s)
        s = engine.recordGoalMet(on: day(4), state: s)
        XCTAssertEqual(s.current, 1)
        XCTAssertEqual(s.freezes, 0, "freeze is still consumed by the attempt")
    }

    func testSevenDayStreakEarnsFreezeCappedAtTwo() {
        var s = StreakState()
        for d in 1...21 { s = engine.recordGoalMet(on: day(d), state: s) }
        XCTAssertEqual(s.current, 21)
        XCTAssertEqual(s.freezes, 2, "earned 3, capped at 2")
    }

    func testLongestSurvivesReset() {
        var s = StreakState()
        for d in 1...5 { s = engine.recordGoalMet(on: day(d), state: s) }
        s = engine.recordGoalMet(on: day(10), state: s)
        XCTAssertEqual(s.longest, 5)
        XCTAssertEqual(s.current, 1)
    }

    func testMidnightBoundaryInTimezone() {
        var s = engine.recordGoalMet(on: day(1, hour: 23), state: StreakState())
        s = engine.recordGoalMet(on: day(2, hour: 0), state: s)
        XCTAssertEqual(s.current, 2, "23:59 and 00:01 local are different days")
    }

    func testOutOfOrderDateIsNoOp() {
        var s = engine.recordGoalMet(on: day(5), state: StreakState())
        let before = s
        s = engine.recordGoalMet(on: day(3), state: s)
        XCTAssertEqual(s, before, "earlier date must not change state or mint freezes")
    }

    func testDisplayStreakZeroWhenBrokenBeyondFreezes() {
        var s = engine.recordGoalMet(on: day(1), state: StreakState())
        XCTAssertEqual(engine.displayStreak(asOf: day(2), state: s), 1, "still recoverable today")
        XCTAssertEqual(engine.displayStreak(asOf: day(4), state: s), 0, "2 days missed, 0 freezes")
        s.freezes = 2
        XCTAssertEqual(engine.displayStreak(asOf: day(4), state: s), 1, "freezes keep it alive")
    }
}
