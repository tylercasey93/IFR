import Foundation

public struct WipeFrame: Equatable, Sendable {
    public let flashWhite: Bool?
    public let coveredRows: [Range<Int>]

    public init(flashWhite: Bool?, coveredRows: [Range<Int>]) {
        self.flashWhite = flashWhite
        self.coveredRows = coveredRows
    }
}

public enum BattleWipe {
    public static let totalFrames = 40
    private static let flashFrames = 16
    private static let bandCount = 8
    private static let bandHeight = PixelFrame.height / bandCount

    public static func frame(_ n: Int) -> WipeFrame {
        if n < flashFrames {
            return WipeFrame(flashWhite: (n / 4) % 2 == 0, coveredRows: [])
        }
        return WipeFrame(flashWhite: nil, coveredRows: closingBands(atFrame: n))
    }

    private static func closingBands(atFrame frame: Int) -> [Range<Int>] {
        let closingFrames = totalFrames - flashFrames
        let progress = min(frame - flashFrames + 1, closingFrames)
        let half = bandHeight / 2
        let coveredEachSide = (progress * half) / closingFrames
        guard coveredEachSide > 0 else { return [] }
        var rows: [Range<Int>] = []
        for band in 0..<bandCount {
            let start = band * bandHeight
            rows.append(start..<(start + coveredEachSide))
            rows.append((start + bandHeight - coveredEachSide)..<(start + bandHeight))
        }
        return rows
    }
}
