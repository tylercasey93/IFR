// AppTests/StudyStoreTests.swift
import Observation
import XCTest
import SwiftData
import IFRCore
@testable import IFRFlashCards

@MainActor
final class StudyStoreTests: XCTestCase {
    private func makeStore() throws -> StudyStore {
        let schema = Schema([CardStateRecord.self, ReviewRecord.self, XPRecord.self,
                             StreakRecord.self, BadgeRecord.self, SettingsRecord.self])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return try StudyStore(context: ModelContext(container), bank: QuestionBank.load())
    }

    func testSessionStartsWithNewCards() throws {
        let store = try makeStore()
        XCTAssertFalse(store.todaySession().isEmpty)
        XCTAssertEqual(store.dueCount, 0, "nothing reviewed yet, so nothing due")
    }

    func testSubmitFlashcardCreatesStateXPAndLog() throws {
        let store = try makeStore()
        let question = store.todaySession().first!
        store.submitFlashcard(question, grade: .good)
        XCTAssertEqual(store.answeredToday, 1)
        XCTAssertEqual(store.totalXP, 10)
        XCTAssertFalse(store.todaySession().map(\.id).contains(question.id),
                       "answered new card leaves today's session")
    }

    func testWrongMCAnswerReturnsFalseAndSchedulesAgain() throws {
        let store = try makeStore()
        let mc = store.bank.questions.first { $0.isMultipleChoiceCapable }!
        let wrongIndex = (mc.correctIndex! + 1) % mc.options!.count
        XCTAssertFalse(store.submitMultipleChoice(mc, selectedIndex: wrongIndex, inQuiz: false))
        XCTAssertEqual(store.totalXP, 3)
    }

    func testGoalMetStartsStreakAndAwardsBonusOnce() throws {
        let store = try makeStore()
        for question in store.todaySession().prefix(10) {
            store.submitFlashcard(question, grade: .good)
        }
        XCTAssertTrue(store.goalMetToday)
        XCTAssertEqual(store.streakDisplay, 1)
        let xpAfterGoal = store.totalXP
        store.submitFlashcard(store.todaySession().first!, grade: .good)
        // exactly one 50-XP goal bonus regardless of further answers
        XCTAssertEqual(store.totalXP, xpAfterGoal + 10)
    }

    func testQuizFinishAwardsMockBonus() throws {
        let store = try makeStore()
        let score = store.finishQuiz(results: Array(repeating: true, count: 42)
                                            + Array(repeating: false, count: 18),
                                     isMockExam: true)
        XCTAssertTrue(score.passed)
        XCTAssertEqual(store.totalXP, 100)
    }

    func testBadgeAwardedOnFirstReview() throws {
        let store = try makeStore()
        store.submitFlashcard(store.todaySession().first!, grade: .good)
        XCTAssertTrue(store.earnedBadges.contains(.firstSession))
    }

    func testSubmitFlashcardNotifiesObservers() throws {
        // StudyStore's accessors fetch from SwiftData on demand; without the
        // revision counter @Observable would have no stored dependency and
        // views reading dueCount/answeredToday would never invalidate.
        let store = try makeStore()
        let question = store.todaySession().first!
        let changed = expectation(description: "observation onChange fired")
        withObservationTracking {
            _ = store.dueCount
        } onChange: {
            changed.fulfill()
        }
        store.submitFlashcard(question, grade: .good)
        wait(for: [changed], timeout: 1.0)
    }

    func testWeekStartIsMondayAnchoredRegardlessOfLocale() {
        // US locale weeks are Sunday-anchored, but the Game Center weekly
        // board resets Monday 00:00 — pin the helper to Monday semantics.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        calendar.firstWeekday = 1 // Sunday-anchored, as in the US locale

        let expectedMonday = DateComponents(calendar: calendar,
                                            year: 2026, month: 7, day: 13).date!

        // Sunday 2026-07-19 12:00 belongs to the week that STARTED Monday 07-13.
        let sundayNoon = DateComponents(calendar: calendar,
                                        year: 2026, month: 7, day: 19, hour: 12).date!
        XCTAssertEqual(StudyStore.mondayWeekStart(for: sundayNoon, calendar: calendar),
                       expectedMonday)

        // A Monday maps to that same day's start.
        let mondayNoon = DateComponents(calendar: calendar,
                                        year: 2026, month: 7, day: 13, hour: 12).date!
        XCTAssertEqual(StudyStore.mondayWeekStart(for: mondayNoon, calendar: calendar),
                       expectedMonday)
    }
}
