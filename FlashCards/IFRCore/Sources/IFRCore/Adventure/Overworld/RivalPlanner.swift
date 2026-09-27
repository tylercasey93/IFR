import Foundation

public enum RivalPlanner {
    public static func weakestCategories(count: Int, retention: [Category: Double]) -> [Category] {
        let ranked = Category.allCases.sorted { lhs, rhs in
            let leftRetention = retention[lhs] ?? 0
            let rightRetention = retention[rhs] ?? 0
            if leftRetention != rightRetention { return leftRetention < rightRetention }
            return lhs.examWeight > rhs.examWeight
        }
        return Array(ranked.prefix(count))
    }

    public static func pendingEncounter(at position: GridPoint, spec: RivalSpec, save: AdventureSave) -> Int? {
        spec.encounters.enumerated().first { index, encounter in
            position.manhattanDistance(to: encounter.at) <= 1
                && save.badges.count >= encounter.afterBadges
                && !save.rivalEncountersDone.contains(index)
        }?.offset
    }
}
