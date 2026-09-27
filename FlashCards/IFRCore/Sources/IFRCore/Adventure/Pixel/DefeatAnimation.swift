import Foundation

public enum DefeatAnimation {
    public static let totalFrames = 30
    private static let maxFadeStep = 15

    public static func fadeStep(atFrame frame: Int) -> Int {
        let clamped = min(max(frame, 0), totalFrames)
        return (maxFadeStep * clamped) / totalFrames
    }
}
