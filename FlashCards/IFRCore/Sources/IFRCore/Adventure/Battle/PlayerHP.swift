public enum PlayerHP {
    public static func maximum(for level: MasteryLevel) -> Int {
        100 + 10 * (level.rawValue - 1)
    }
}
