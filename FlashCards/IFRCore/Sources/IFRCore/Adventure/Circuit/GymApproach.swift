public struct GymApproachResult: Equatable, Sendable {
    public let dialogue: DialogueScript
    public let challengeableGymID: GymID?
}

public enum GymApproach {
    public static func approaching(_ gym: Gym, content: AdventureContent, save: AdventureSave) -> GymApproachResult {
        guard CircuitRules.isUnlocked(gym.id, save: save) else {
            return GymApproachResult(
                dialogue: content.systemLine(.gymLocked, filling: ["badge": previousBadgeName(before: gym.id, content: content)]),
                challengeableGymID: nil
            )
        }
        return GymApproachResult(
            dialogue: content.dialogue[gym.dialogue.intro] ?? DialogueScript(pages: []),
            challengeableGymID: gym.id
        )
    }

    public static func eliteFourLockedDialogue(content: AdventureContent, save: AdventureSave) -> DialogueScript? {
        guard !CircuitRules.isEliteFourUnlocked(save: save) else { return nil }
        return content.systemLine(.gymLocked, filling: ["badge": nextMissingBadgeName(content: content, save: save)])
    }

    public static func championLockedDialogue(content: AdventureContent, save: AdventureSave) -> DialogueScript? {
        guard !CircuitRules.isChampionUnlocked(save: save) else { return nil }
        return content.systemLine(.championPinned)
    }

    static func previousBadgeName(before gymID: GymID, content: AdventureContent) -> String {
        guard let previous = gymID.previous, let previousGym = content.gyms.first(where: { $0.id == previous })
        else { return "" }
        return previousGym.badgeName
    }

    static func nextMissingBadgeName(content: AdventureContent, save: AdventureSave) -> String {
        guard let missing = GymID.allCases.first(where: { !save.badges.contains($0) }),
              let gym = content.gyms.first(where: { $0.id == missing }) else { return "" }
        return gym.badgeName
    }
}
