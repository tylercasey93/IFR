public enum CircuitRules {
    public static func isUnlocked(_ gym: GymID, save: AdventureSave) -> Bool {
        guard let previous = gym.previous else { return true }
        return save.badges.contains(previous)
    }

    public static func isEliteFourUnlocked(save: AdventureSave) -> Bool {
        save.badges.count >= GymID.allCases.count
    }

    public static func isChampionUnlocked(save: AdventureSave) -> Bool {
        save.eliteFourCleared
    }
}
