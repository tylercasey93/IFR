import Foundation

public enum RivalPlanner {
    public static func pendingEncounter(at position: GridPoint, spec: RivalSpec, save: AdventureSave) -> Int? {
        spec.encounters.enumerated().first { index, encounter in
            position.manhattanDistance(to: encounter.at) <= 1
                && save.badges.count >= encounter.afterBadges
                && !save.rivalEncountersDone.contains(index)
        }?.offset
    }
}
