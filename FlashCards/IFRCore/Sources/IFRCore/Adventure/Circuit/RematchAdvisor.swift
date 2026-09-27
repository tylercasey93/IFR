import Foundation

public enum RematchAdvisor {
    public static func gymsAtRisk(
        save: AdventureSave, categoryRetention: [GymID: Double], badgeQuestionRetention: [GymID: Double],
        threshold: Double = 0.6
    ) -> [GymID] {
        save.badges
            .map { ($0, lowerRetention($0, categoryRetention: categoryRetention, badgeQuestionRetention: badgeQuestionRetention)) }
            .filter { $0.1 <= threshold }
            .sorted { $0.1 < $1.1 }
            .map(\.0)
    }

    private static func lowerRetention(
        _ gym: GymID, categoryRetention: [GymID: Double], badgeQuestionRetention: [GymID: Double]
    ) -> Double {
        min(categoryRetention[gym] ?? 0, badgeQuestionRetention[gym] ?? 0)
    }
}
