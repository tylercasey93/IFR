import Foundation

public enum TrainerApproach {
    public static func position(from start: GridPoint, toward player: GridPoint, step: Int) -> GridPoint {
        let dx = sign(player.x - start.x)
        let dy = sign(player.y - start.y)
        let distance = abs(player.x - start.x) + abs(player.y - start.y)
        let stepsTaken = min(step, max(distance - 1, 0))
        return GridPoint(x: start.x + dx * stepsTaken, y: start.y + dy * stepsTaken)
    }

    private static func sign(_ value: Int) -> Int {
        value == 0 ? 0 : (value > 0 ? 1 : -1)
    }
}
