import Foundation

public enum VictoryAnimation {
    private static let dropFrames = 8
    private static let dropPixelsPerFrame = 4
    private static let badgeGrowFrames = 8
    private static let badgeMinScale = 1
    private static let badgeMaxScale = 4

    public static func dropOffset(atFrame frame: Int) -> Int? {
        guard frame >= 0, frame < dropFrames else { return nil }
        return (frame + 1) * dropPixelsPerFrame
    }

    public static func badgeScale(atFrame frame: Int) -> Int {
        let clamped = min(max(frame, 0), badgeGrowFrames)
        return badgeMinScale + ((badgeMaxScale - badgeMinScale) * clamped) / badgeGrowFrames
    }
}
