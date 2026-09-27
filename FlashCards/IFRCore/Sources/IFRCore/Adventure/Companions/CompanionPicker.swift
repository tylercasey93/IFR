import Foundation

public enum CompanionPicker {
    public static func companion(for categories: [Category]?, stages: [Category: CompanionStage]) -> Category {
        if let categories, categories.count == 1, let only = categories.first {
            return only
        }
        let circuitOrder = GymID.allCases.map(\.category)
        let pool = categories ?? circuitOrder
        let candidates = pool.compactMap { category in stages[category].map { (category, $0) } }
        let best = candidates.max { lhs, rhs in
            isLower(lhs, than: rhs, circuitOrder: circuitOrder)
        }
        return best?.0 ?? circuitOrder[0]
    }

    private static func isLower(
        _ lhs: (Category, CompanionStage), than rhs: (Category, CompanionStage), circuitOrder: [Category]
    ) -> Bool {
        if lhs.1 != rhs.1 { return lhs.1.rawValue < rhs.1.rawValue }
        let leftIndex = circuitOrder.firstIndex(of: lhs.0) ?? Int.max
        let rightIndex = circuitOrder.firstIndex(of: rhs.0) ?? Int.max
        return leftIndex > rightIndex
    }
}
