import Foundation

public enum EvolutionRenderer {
    private static let panelIndex: UInt8 = 1
    private static let flashWhiteIndex: UInt8 = 15
    private static let flashInkIndex: UInt8 = 0
    private static let spriteOrigin = GridPoint(x: 96, y: 56)

    public static func frame(fromSpriteID: String, toSpriteID: String, atFrame frame: Int) -> PixelFrame {
        var canvas = PixelFrame(fill: panelIndex)
        let wipeFrame = BattleWipe.frame(min(frame, BattleWipe.totalFrames - 1))
        if let flashWhite = wipeFrame.flashWhite {
            return PixelFrame(fill: flashWhite ? flashWhiteIndex : flashInkIndex)
        }
        let spriteID = frame < BattleWipe.totalFrames ? fromSpriteID : toSpriteID
        if let sprite = SpriteCatalog.sprite(named: spriteID) {
            canvas.blit(sprite, at: spriteOrigin)
        }
        return canvas
    }
}
