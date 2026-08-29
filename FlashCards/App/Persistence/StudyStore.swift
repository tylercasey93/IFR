// App/Persistence/StudyStore.swift
import Foundation
import os
import SwiftData
import IFRCore

@Observable
@MainActor
final class StudyStore {
    private static let logger = Logger(subsystem: "com.tylercasey.ifrflashcards",
                                       category: "persistence")

    let bank: QuestionBank
    private let context: ModelContext
    private let scheduler = Scheduler()
    private let streakEngine = StreakEngine(calendar: .current)
    private let calendar = Calendar.current
    private var quizEngine: QuizEngine { QuizEngine(scheduler: scheduler) }
    // Concrete type required: QuizEngine.makeQuiz takes `inout some RandomNumberGenerator`.
    private var rng = SystemRandomNumberGenerator()

    /// Monotonic mutation counter — the only stored property behind the
    /// accessors below, which fetch from SwiftData on access and would
    /// otherwise give `@Observable` nothing to track (views would go stale
    /// after a mutation). Every public read touches it; every mutation path
    /// (afterAnswer / finishQuiz) bumps it.
    private(set) var revision = 0

    /// Task 7 (Game Center) assigns this to push fresh totals after XP changes.
    var onXPChanged: (() -> Void)?

    init(context: ModelContext, bank: QuestionBank) {
        self.context = context
        self.bank = bank
    }

    // MARK: - Fetch helpers

    private var settingsRecord: SettingsRecord {
        if let existing = try? context.fetch(FetchDescriptor<SettingsRecord>()).first { return existing }
        let created = SettingsRecord()
        context.insert(created)
        return created
    }

    private var streakRecord: StreakRecord {
        if let existing = try? context.fetch(FetchDescriptor<StreakRecord>()).first { return existing }
        let created = StreakRecord()
        context.insert(created)
        return created
    }

    private var allCardRecords: [CardStateRecord] {
        (try? context.fetch(FetchDescriptor<CardStateRecord>())) ?? []
    }

    private var cardStates: [String: CardState] {
        Dictionary(uniqueKeysWithValues: allCardRecords.map { ($0.questionID, $0.cardState) })
    }

    private func reviews(since start: Date) -> [ReviewRecord] {
        let predicate = #Predicate<ReviewRecord> { $0.date >= start }
        return (try? context.fetch(FetchDescriptor(predicate: predicate))) ?? []
    }

    // MARK: - Session

    var settings: SettingsRecord { settingsRecord }

    private var startOfToday: Date { calendar.startOfDay(for: .now) }

    private var newIntroducedToday: Int {
        allCardRecords.filter { $0.introducedOn >= startOfToday }.count
    }

    func todaySession() -> [Question] {
        _ = revision
        return StudyQueue.session(bank: bank, states: cardStates, settings: settingsRecord.studySettings,
                                  newIntroducedToday: newIntroducedToday, now: .now)
    }

    var dueCount: Int {
        _ = revision
        return cardStates.values.filter { $0.reps > 0 && $0.due <= .now }.count
    }

    var answeredToday: Int {
        _ = revision
        return reviews(since: startOfToday).count
    }

    var goalMetToday: Bool {
        _ = revision
        return answeredToday >= settingsRecord.dailyGoalCards && dueCount == 0
    }

    /// Whether today's daily-goal bonus has already been recorded. Unlike
    /// `goalMetToday`, this stays true even if cards fall due again later
    /// today — the goal was already banked.
    var goalRecordedToday: Bool {
        _ = revision
        return goalBonusAwardedToday
    }

    // MARK: - Answering

    func submitFlashcard(_ question: Question, grade: Grade) {
        applyReview(question, grade: grade)
        context.insert(ReviewRecord(date: .now, questionID: question.id,
                                    gradeRaw: grade.rawValue, wasCorrect: nil, inQuiz: false))
        addXP(XPEngine.points(for: .flashcardReview(grade: grade, difficulty: question.difficulty)),
              reason: "flashcard")
        afterAnswer()
    }

    @discardableResult
    func submitMultipleChoice(_ question: Question, selectedIndex: Int, inQuiz: Bool) -> Bool {
        let correct = selectedIndex == question.correctIndex
        applyReview(question, grade: Grade(mcCorrect: correct))
        context.insert(ReviewRecord(date: .now, questionID: question.id,
                                    gradeRaw: nil, wasCorrect: correct, inQuiz: inQuiz))
        let event: XPEvent = inQuiz
            ? .quizAnswer(correct: correct, difficulty: question.difficulty)
            : .reviewMC(correct: correct, difficulty: question.difficulty)
        addXP(XPEngine.points(for: event), reason: inQuiz ? "quiz" : "reviewMC")
        afterAnswer()
        return correct
    }

    private func applyReview(_ question: Question, grade: Grade) {
        // Convention (from core-package final review): a CardStateRecord is
        // persisted only after the card's first review — never pre-created
        // with reps == 0.
        if let record = allCardRecords.first(where: { $0.questionID == question.id }) {
            record.apply(scheduler.review(record.cardState, grade: grade, at: .now))
        } else {
            let reviewed = scheduler.review(.new(questionID: question.id), grade: grade, at: .now)
            context.insert(CardStateRecord(state: reviewed, introducedOn: .now))
        }
    }

    private func afterAnswer() {
        if goalMetToday && !goalBonusAwardedToday {
            addXP(XPEngine.points(for: .dailyGoalMet), reason: "dailyGoal")
            streakRecord.apply(streakEngine.recordGoalMet(on: .now, state: streakRecord.streakState))
        }
        awardBadges()
        saveContext()
        revision += 1
    }

    /// Non-throwing by design (answer submission must never crash the UI),
    /// but a failed save is logged rather than silently swallowed.
    private func saveContext() {
        do {
            try context.save()
        } catch {
            Self.logger.error("SwiftData save failed: \(String(describing: error), privacy: .public)")
        }
    }

    private var goalBonusAwardedToday: Bool {
        let start = startOfToday
        let predicate = #Predicate<XPRecord> { $0.date >= start && $0.reason == "dailyGoal" }
        return ((try? context.fetch(FetchDescriptor(predicate: predicate))) ?? []).isEmpty == false
    }

    // MARK: - Quiz

    func makeQuiz(config: QuizConfig) -> [Question] {
        quizEngine.makeQuiz(config: config, bank: bank, states: cardStates, now: .now, using: &rng)
    }

    func finishQuiz(results: [Bool], isMockExam: Bool) -> QuizScore {
        let score = QuizEngine.score(results: results)
        if isMockExam {
            addXP(XPEngine.points(for: .mockExamCompleted(passed: score.passed)), reason: "mockExam")
        }
        awardBadges(lastQuizPerfect: score.total > 0 && score.correct == score.total,
                    mockExamPassed: isMockExam && score.passed)
        saveContext()
        revision += 1
        return score
    }

    // MARK: - XP / streak / badges

    /// XP for feed activity (watching a lesson, first correct quiz answer).
    /// XP only, by design: no ReviewRecord/FSRS/streak/badge writes — the
    /// daily streak stays study-goal-driven. Callers dedupe (first watch,
    /// FeedProgressStore.claimQuizXP) before calling.
    func awardFeedXP(_ event: XPEvent, reason: String) {
        addXP(XPEngine.points(for: event), reason: reason)
        saveContext()
        revision += 1
    }

    private func addXP(_ amount: Int, reason: String) {
        context.insert(XPRecord(date: .now, amount: amount, reason: reason))
        onXPChanged?()
    }

    var totalXP: Int {
        _ = revision
        return ((try? context.fetch(FetchDescriptor<XPRecord>())) ?? []).reduce(0) { $0 + $1.amount }
    }

    /// Game Center's weekly leaderboard resets Monday 00:00, but
    /// `Calendar.current` weeks are locale-anchored (Sunday in the US), so
    /// the window is pinned to Monday explicitly.
    static func mondayWeekStart(for date: Date, calendar: Calendar) -> Date {
        var mondayAnchored = calendar
        mondayAnchored.firstWeekday = 2
        return mondayAnchored.dateInterval(of: .weekOfYear, for: date)?.start
            ?? mondayAnchored.startOfDay(for: date)
    }

    var weeklyXP: Int {
        _ = revision
        let weekStart = Self.mondayWeekStart(for: .now, calendar: calendar)
        let predicate = #Predicate<XPRecord> { $0.date >= weekStart }
        return ((try? context.fetch(FetchDescriptor(predicate: predicate))) ?? []).reduce(0) { $0 + $1.amount }
    }

    var streakDisplay: Int {
        _ = revision
        return streakEngine.displayStreak(asOf: .now, state: streakRecord.streakState)
    }

    var longestStreak: Int {
        _ = revision
        return streakRecord.longest
    }

    var freezes: Int {
        _ = revision
        return streakRecord.freezes
    }

    var earnedBadges: [Badge] {
        _ = revision
        return ((try? context.fetch(FetchDescriptor<BadgeRecord>())) ?? [])
            .compactMap { Badge(rawValue: $0.badgeRaw) }
    }

    private func awardBadges(lastQuizPerfect: Bool = false, mockExamPassed: Bool = false) {
        let allReviews = (try? context.fetch(FetchDescriptor<ReviewRecord>())) ?? []
        // Distinct quiz days. When called from finishQuiz, today's quiz
        // answers are already in ReviewRecord, so today is already counted —
        // no extra +1. (Known v1 limitation: multiple quizzes in one day
        // count once; affects badge timing only.)
        let quizCount = Set(allReviews.filter(\.inQuiz).map { calendar.startOfDay(for: $0.date) }).count
        let previousDay = allReviews.map(\.date).filter { $0 < startOfToday }.max()
        let daysAway = previousDay.map {
            calendar.dateComponents([.day], from: calendar.startOfDay(for: $0), to: startOfToday).day ?? 0
        } ?? 0
        // Build card states ONCE for all 8 categories — mastery(for:) would
        // refetch every CardStateRecord per category.
        let states = cardStates
        let mastered = IFRCore.Category.allCases
            .filter { categoryRetention(for: $0, states: states).level == .instrumentMaster }
            .count
        let snapshot = BadgeSnapshot(
            totalReviews: allReviews.count, streak: streakRecord.current,
            lastQuizPerfect: lastQuizPerfect, mockExamPassed: mockExamPassed,
            masteredCategories: mastered, hourOfDay: calendar.component(.hour, from: .now),
            totalXP: totalXP, quizzesCompleted: quizCount, daysAwayBeforeToday: daysAway)
        for badge in BadgeEngine.newlyEarned(snapshot: snapshot, already: Set(earnedBadges)) {
            context.insert(BadgeRecord(badge: badge, earnedOn: .now))
        }
    }

    // MARK: - Mastery / readiness

    func mastery(for category: IFRCore.Category) -> (retention: Double, level: MasteryLevel) {
        _ = revision
        return categoryRetention(for: category, states: cardStates)
    }

    private func categoryRetention(for category: IFRCore.Category,
                                   states: [String: CardState]) -> (retention: Double, level: MasteryLevel) {
        let calc = MasteryCalculator(scheduler: scheduler)
        let r = calc.categoryRetention(category, bank: bank, states: states, at: .now)
        return (r, MasteryLevel.level(forRetention: r))
    }

    func readiness(examDate: Date) -> Double {
        _ = revision
        return MasteryCalculator(scheduler: scheduler).readiness(bank: bank, states: cardStates, at: examDate)
    }
}
