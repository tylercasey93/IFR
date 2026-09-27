import Foundation

public enum EncounterRoll {
    public static let oneIn = 8
    public static let pityStep = 24

    public static func triggers(
        on tile: TileKind,
        repelStepsLeft: Int,
        stepsSinceEncounter: Int,
        using rng: inout some RandomNumberGenerator
    ) -> Bool {
        guard tile == .cloud else { return false }
        guard repelStepsLeft <= 0 else { return false }
        guard stepsSinceEncounter < pityStep else { return true }
        return rng.next() % UInt64(oneIn) == 0
    }
}
