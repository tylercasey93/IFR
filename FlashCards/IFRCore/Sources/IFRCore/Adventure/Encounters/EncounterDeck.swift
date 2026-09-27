import Foundation

public struct EncounterDeck: Sendable {
    private let engine: QuizEngine

    public init(scheduler: Scheduler) {
        engine = QuizEngine(scheduler: scheduler)
    }

    public func draw(
        count: Int,
        categories: [Category]?,
        bank: QuestionBank,
        states: [String: CardState],
        now: Date,
        using rng: inout some RandomNumberGenerator
    ) -> [Question] {
        let groups: [Category?] = categories.map { $0.map { Optional($0) } } ?? [nil]
        var drawn: [Question] = []
        var excluded: Set<String> = []
        for (index, category) in groups.enumerated() {
            let slotQuota = quota(for: index, groupCount: groups.count, count: count)
            let prefix = duePrefix(category: category, quota: slotQuota, bank: bank, states: states, now: now)
            drawn += prefix
            excluded.formUnion(prefix.map(\.id))
            let remaining = slotQuota - prefix.count
            let topped = topUp(category: category, remaining: remaining, excluding: excluded,
                                bank: bank, states: states, now: now, using: &rng)
            drawn += topped
            excluded.formUnion(topped.map(\.id))
        }
        return drawn
    }

    private func quota(for index: Int, groupCount: Int, count: Int) -> Int {
        let base = count / groupCount
        let remainder = count % groupCount
        return base + (index < remainder ? 1 : 0)
    }

    private func duePrefix(
        category: Category?, quota: Int, bank: QuestionBank, states: [String: CardState], now: Date
    ) -> [Question] {
        guard quota > 0 else { return [] }
        let session = StudyQueue.session(
            bank: bank, states: states, settings: StudySettings(newCardsPerDay: 0),
            newIntroducedToday: 0, now: now
        )
        let matching = session
            .filter(\.isMultipleChoiceCapable)
            .filter { category == nil || $0.category == category }
        return Array(matching.prefix(quota))
    }

    private func topUp(
        category: Category?, remaining: Int, excluding: Set<String>,
        bank: QuestionBank, states: [String: CardState], now: Date,
        using rng: inout some RandomNumberGenerator
    ) -> [Question] {
        guard remaining > 0 else { return [] }
        let pool = bank.questions.filter { !excluding.contains($0.id) }
        let bankExcludingChosen = QuestionBank(version: bank.version, questions: pool)
        let config = QuizConfig(category: category, length: remaining, isMockExam: false)
        return engine.makeQuiz(config: config, bank: bankExcludingChosen, states: states, now: now, using: &rng)
    }
}
