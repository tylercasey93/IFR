import Foundation

public enum LineOfSight {
    public static func trainerSeeing(
        _ player: GridPoint, trainers: [Trainer], defeated: Set<String>, in map: TileMap
    ) -> Trainer? {
        trainers.first { sees($0, player: player, defeated: defeated, in: map) }
    }

    private static func sees(_ trainer: Trainer, player: GridPoint, defeated: Set<String>, in map: TileMap) -> Bool {
        guard !defeated.contains(trainer.id), trainer.range > 0 else { return false }
        let delta = trainer.facing.delta
        var point = trainer.position
        for _ in 1...trainer.range {
            point = GridPoint(x: point.x + delta.x, y: point.y + delta.y)
            if point == player { return true }
            if map[point]?.blocksSight ?? true { return false }
        }
        return false
    }
}
