import Foundation

public struct StudySettings: Codable, Equatable, Sendable {
    public var newCardsPerDay: Int
    public var unlockedCategories: Set<Category>
    public var dailyGoalCards: Int

    public init(newCardsPerDay: Int = 20,
                unlockedCategories: Set<Category> = Set(Category.allCases),
                dailyGoalCards: Int = 10) {
        self.newCardsPerDay = newCardsPerDay
        self.unlockedCategories = unlockedCategories
        self.dailyGoalCards = dailyGoalCards
    }
}

public enum StudyQueue: Sendable {
    /// Builds today's session: due cards (round-robin interleaved across
    /// categories, oldest-due first within each), then new cards up to the
    /// remaining daily allowance, highest examWeight category first.
    ///
    /// `states` must be keyed by `questionID` — every entry's key is
    /// expected to equal that entry's own `.questionID` (i.e.
    /// `states[k]!.questionID == k`). Lookups below (`states[$0.id]`) rely
    /// on that invariant to match a `Question` to its `CardState`.
    ///
    /// `unlockedCategories` only gates which NEW (never-reviewed) cards may
    /// enter the session. A card that already has a due date keeps its
    /// schedule and remains eligible regardless of whether its category is
    /// currently locked.
    public static func session(
        bank: QuestionBank,
        states: [String: CardState],
        settings: StudySettings,
        newIntroducedToday: Int,
        now: Date
    ) -> [Question] {
        let byID = Dictionary(uniqueKeysWithValues: bank.questions.map { ($0.id, $0) })

        let dueStates = states.values
            .filter { $0.reps > 0 && $0.due <= now && byID[$0.questionID] != nil }
            .sorted { $0.due < $1.due }
        var buckets: [Category: [Question]] = [:]
        for state in dueStates {
            let q = byID[state.questionID]!
            buckets[q.category, default: []].append(q)
        }
        var due: [Question] = []
        var order = buckets.keys.sorted { $0.rawValue < $1.rawValue }
        while !order.isEmpty {
            for category in order {
                if let next = buckets[category]?.first {
                    due.append(next)
                    buckets[category]?.removeFirst()
                }
            }
            order = order.filter { !(buckets[$0] ?? []).isEmpty }
        }

        let allowance = max(0, settings.newCardsPerDay - newIntroducedToday)
        let fresh = bank.questions
            .filter { (states[$0.id]?.reps ?? 0) == 0 && settings.unlockedCategories.contains($0.category) }
            .sorted {
                if $0.category.examWeight != $1.category.examWeight {
                    return $0.category.examWeight > $1.category.examWeight
                }
                return $0.id < $1.id
            }
            .prefix(allowance)

        return due + Array(fresh)
    }
}
