// App/Persistence/Records.swift
import Foundation
import SwiftData
import IFRCore

@Model
final class CardStateRecord {
    @Attribute(.unique) var questionID: String
    var stability: Double
    var difficulty: Double
    var due: Date
    var lastReview: Date?
    var reps: Int
    var lapses: Int
    var introducedOn: Date

    init(state: CardState, introducedOn: Date) {
        self.questionID = state.questionID
        self.stability = state.stability
        self.difficulty = state.difficulty
        self.due = state.due
        self.lastReview = state.lastReview
        self.reps = state.reps
        self.lapses = state.lapses
        self.introducedOn = introducedOn
    }

    var cardState: CardState {
        CardState(questionID: questionID, stability: stability, difficulty: difficulty,
                  due: due, lastReview: lastReview, reps: reps, lapses: lapses)
    }

    func apply(_ state: CardState) {
        stability = state.stability
        difficulty = state.difficulty
        due = state.due
        lastReview = state.lastReview
        reps = state.reps
        lapses = state.lapses
    }
}

@Model
final class ReviewRecord {
    var date: Date
    var questionID: String
    var gradeRaw: Int?
    var wasCorrect: Bool?
    var inQuiz: Bool

    init(date: Date, questionID: String, gradeRaw: Int?, wasCorrect: Bool?, inQuiz: Bool) {
        self.date = date
        self.questionID = questionID
        self.gradeRaw = gradeRaw
        self.wasCorrect = wasCorrect
        self.inQuiz = inQuiz
    }
}

@Model
final class XPRecord {
    var date: Date
    var amount: Int
    var reason: String

    init(date: Date, amount: Int, reason: String) {
        self.date = date
        self.amount = amount
        self.reason = reason
    }
}

@Model
final class StreakRecord {
    var current: Int = 0
    var longest: Int = 0
    var freezes: Int = 0
    var lastGoalDate: Date?
    var daysTowardFreeze: Int = 0

    init() {}

    var streakState: StreakState {
        StreakState(current: current, longest: longest, freezes: freezes,
                    lastGoalDate: lastGoalDate, daysTowardFreeze: daysTowardFreeze)
    }

    func apply(_ s: StreakState) {
        current = s.current
        longest = s.longest
        freezes = s.freezes
        lastGoalDate = s.lastGoalDate
        daysTowardFreeze = s.daysTowardFreeze
    }
}

@Model
final class BadgeRecord {
    @Attribute(.unique) var badgeRaw: String
    var earnedOn: Date

    init(badge: Badge, earnedOn: Date) {
        self.badgeRaw = badge.rawValue
        self.earnedOn = earnedOn
    }
}

@Model
final class SettingsRecord {
    var newCardsPerDay: Int = 20
    var dailyGoalCards: Int = 10
    var unlockedCategoriesRaw: [String] = IFRCore.Category.allCases.map(\.rawValue)
    var reminderHour: Int = 18
    var reminderMinute: Int = 0
    var reminderEnabled: Bool = true
    var streakRiskEnabled: Bool = true
    var examDate: Date?

    init() {}

    var studySettings: StudySettings {
        StudySettings(newCardsPerDay: newCardsPerDay,
                      unlockedCategories: Set(unlockedCategoriesRaw.compactMap(IFRCore.Category.init(rawValue:))),
                      dailyGoalCards: dailyGoalCards)
    }
}
