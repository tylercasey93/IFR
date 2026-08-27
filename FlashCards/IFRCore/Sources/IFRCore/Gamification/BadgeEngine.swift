// IFRCore/Sources/IFRCore/Gamification/BadgeEngine.swift
import Foundation

public enum Badge: String, Codable, CaseIterable, Sendable {
    case firstSession, streak7, streak30, streak100
    case reviews100, reviews500, reviews1000
    case perfectQuiz, quizzes10, quizzes50, mockExamPassed
    case categoryMastered, allCategoriesMastered
    case xp10k, earlyBird, nightOwl, comeback

    public var displayName: String {
        switch self {
        case .firstSession: "Wheels Up"
        case .streak7: "One Week Wonder"
        case .streak30: "Monthly Machine"
        case .streak100: "Century Streak"
        case .reviews100: "100 Cards Down"
        case .reviews500: "500 Cards Down"
        case .reviews1000: "1,000 Cards Down"
        case .perfectQuiz: "Perfect Score"
        case .quizzes10: "Quiz Regular"
        case .quizzes50: "Quiz Veteran"
        case .mockExamPassed: "Checkride Ready"
        case .categoryMastered: "Category Master"
        case .allCategoriesMastered: "Instrument Master"
        case .xp10k: "10K Club"
        case .earlyBird: "Early Bird"
        case .nightOwl: "Night Owl"
        case .comeback: "Comeback Kid"
        }
    }
}

public struct BadgeSnapshot: Sendable {
    public let totalReviews: Int
    public let streak: Int
    public let lastQuizPerfect: Bool
    public let mockExamPassed: Bool
    public let masteredCategories: Int
    public let hourOfDay: Int
    public let totalXP: Int
    public let quizzesCompleted: Int
    public let daysAwayBeforeToday: Int

    public init(totalReviews: Int, streak: Int, lastQuizPerfect: Bool, mockExamPassed: Bool,
                masteredCategories: Int, hourOfDay: Int, totalXP: Int, quizzesCompleted: Int,
                daysAwayBeforeToday: Int) {
        self.totalReviews = totalReviews
        self.streak = streak
        self.lastQuizPerfect = lastQuizPerfect
        self.mockExamPassed = mockExamPassed
        self.masteredCategories = masteredCategories
        self.hourOfDay = hourOfDay
        self.totalXP = totalXP
        self.quizzesCompleted = quizzesCompleted
        self.daysAwayBeforeToday = daysAwayBeforeToday
    }
}

public enum BadgeEngine: Sendable {
    public static func newlyEarned(snapshot s: BadgeSnapshot, already: Set<Badge>) -> Set<Badge> {
        var earned = Set<Badge>()
        func award(_ badge: Badge, when condition: Bool) {
            if condition && !already.contains(badge) { earned.insert(badge) }
        }
        award(.firstSession, when: s.totalReviews >= 1)
        award(.streak7, when: s.streak >= 7)
        award(.streak30, when: s.streak >= 30)
        award(.streak100, when: s.streak >= 100)
        award(.reviews100, when: s.totalReviews >= 100)
        award(.reviews500, when: s.totalReviews >= 500)
        award(.reviews1000, when: s.totalReviews >= 1000)
        award(.perfectQuiz, when: s.lastQuizPerfect)
        award(.quizzes10, when: s.quizzesCompleted >= 10)
        award(.quizzes50, when: s.quizzesCompleted >= 50)
        award(.mockExamPassed, when: s.mockExamPassed)
        award(.categoryMastered, when: s.masteredCategories >= 1)
        award(.allCategoriesMastered, when: s.masteredCategories >= 8)
        award(.xp10k, when: s.totalXP >= 10_000)
        award(.earlyBird, when: s.totalReviews >= 1 && s.hourOfDay < 6)
        award(.nightOwl, when: s.totalReviews >= 1 && s.hourOfDay >= 22)
        award(.comeback, when: s.totalReviews >= 1 && s.daysAwayBeforeToday >= 7)
        return earned
    }
}
