import Foundation

public enum HPBand: Equatable, Sendable {
    case green
    case amber
    case red
}

public enum HPBarAnimator {
    private static let shakeOffsets = [-2, 2, -1, 1, 0]

    public static func displayedHP(from: Int, to: Int, framesElapsed: Int) -> Int {
        let steps = framesElapsed / 2
        if from <= to {
            return min(to, from + steps)
        }
        return max(to, from - steps)
    }

    public static func filledPixels(hp: Int, max: Int, width: Int = 48) -> Int {
        guard max > 0 else { return 0 }
        return (hp * width) / max
    }

    public static func band(hp: Int, max: Int) -> HPBand {
        guard max > 0 else { return .red }
        let percent = (hp * 100) / max
        if percent > 50 { return .green }
        if percent >= 20 { return .amber }
        return .red
    }

    public static func shakeOffset(atFrame frame: Int) -> Int {
        let index = min(max(frame, 0) / 2, shakeOffsets.count - 1)
        return shakeOffsets[index]
    }
}
