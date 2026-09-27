import Foundation

public enum BattleIntro {
    public static let totalFrames = 12
    private static let enemyStartX = 240
    private static let enemyEndX = 176
    private static let playerStartX = -32
    private static let playerEndX = 24

    public static func slideOffset(atFrame frame: Int) -> (enemyX: Int, playerX: Int) {
        let clamped = min(max(frame, 0), totalFrames)
        let enemyX = enemyStartX + ((enemyEndX - enemyStartX) * clamped) / totalFrames
        let playerX = playerStartX + ((playerEndX - playerStartX) * clamped) / totalFrames
        return (enemyX, playerX)
    }
}
