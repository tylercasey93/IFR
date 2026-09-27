import Foundation

public enum BattlePhase: Equatable, Sendable {
    case wipe, intro, asking, resolving, ended
}

public enum BattleRenderer {
    private static let opponentOrigin = GridPoint(x: 176, y: 8)
    private static let playerOrigin = GridPoint(x: 24, y: 64)
    private static let plateWidth = 64
    private static let plateBackground: UInt8 = 6
    private static let barWidth = 48
    private static let barHeight = 4
    private static let flashWhiteIndex: UInt8 = 15
    private static let flashInkIndex: UInt8 = 0
    private static let panelIndex: UInt8 = 1

    public static func frame(
        state: BattleState,
        displayedPlayerHP: Int,
        displayedOpponentHP: Int,
        playerSpriteID: String,
        atFrame frame: Int,
        phase: BattlePhase
    ) -> PixelFrame {
        var canvas = PixelFrame(fill: panelIndex)
        if phase == .wipe {
            applyWipe(&canvas, atFrame: frame)
            return canvas
        }
        drawSprites(&canvas, state: state, playerSpriteID: playerSpriteID, phase: phase, atFrame: frame)
        drawPlate(&canvas, plate: .enemy, hp: displayedOpponentHP, maxHP: state.opponent.maxHP)
        drawPlate(&canvas, plate: .player, hp: displayedPlayerHP, maxHP: state.playerMaxHP)
        return canvas
    }

    private static func drawSprites(
        _ canvas: inout PixelFrame, state: BattleState, playerSpriteID: String,
        phase: BattlePhase, atFrame frame: Int
    ) {
        let offsets = spriteOffsets(phase: phase, atFrame: frame)
        blitIfKnown(&canvas, spriteID: state.opponent.spriteID, at: GridPoint(x: offsets.enemyX, y: opponentOrigin.y))
        blitIfKnown(&canvas, spriteID: playerSpriteID, at: GridPoint(x: offsets.playerX, y: playerOrigin.y))
    }

    private static func spriteOffsets(phase: BattlePhase, atFrame frame: Int) -> (enemyX: Int, playerX: Int) {
        guard phase == .intro else { return (opponentOrigin.x, playerOrigin.x) }
        return BattleIntro.slideOffset(atFrame: frame)
    }

    private static func blitIfKnown(_ canvas: inout PixelFrame, spriteID: String, at point: GridPoint) {
        guard let sprite = SpriteCatalog.sprite(named: spriteID) else { return }
        canvas.blit(sprite, at: point)
    }

    private static func drawPlate(_ canvas: inout PixelFrame, plate: NamePlate, hp: Int, maxHP: Int) {
        let rect = PixelRect(x: plate.origin.x, y: plate.origin.y, width: plateWidth, height: plate.height)
        canvas.fill(rect, index: plateBackground)
        drawBar(&canvas, origin: plate.barOrigin, hp: hp, max: maxHP)
    }

    private static func drawBar(_ canvas: inout PixelFrame, origin: GridPoint, hp: Int, max: Int) {
        let filled = HPBarAnimator.filledPixels(hp: hp, max: max, width: barWidth)
        guard filled > 0 else { return }
        let index = colorIndex(for: HPBarAnimator.band(hp: hp, max: max))
        canvas.fill(PixelRect(x: origin.x, y: origin.y, width: filled, height: barHeight), index: index)
    }

    private static func colorIndex(for band: HPBand) -> UInt8 {
        switch band {
        case .green: return 4
        case .amber: return 7
        case .red: return 10
        }
    }

    private static func applyWipe(_ canvas: inout PixelFrame, atFrame frame: Int) {
        let wipeFrame = BattleWipe.frame(frame)
        if let flashWhite = wipeFrame.flashWhite {
            canvas = PixelFrame(fill: flashWhite ? flashWhiteIndex : flashInkIndex)
            return
        }
        for range in wipeFrame.coveredRows {
            canvas.fill(PixelRect(x: 0, y: range.lowerBound, width: PixelFrame.width, height: range.count),
                        index: flashInkIndex)
        }
    }
}
