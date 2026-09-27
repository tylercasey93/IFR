import Foundation

public enum OverworldRenderer {
    public static let cellSize = 16
    public static let viewportWidth = 15
    public static let viewportHeight = 10

    private static let panelIndex: UInt8 = 1

    public static func frame(
        map: TileMap, state: OverworldState, trainers: [Trainer], defeated: Set<String>, atFrame: Int
    ) -> PixelFrame {
        let origin = cameraOrigin(for: state.position, map: map)
        var canvas = PixelFrame(fill: panelIndex)
        drawTiles(&canvas, map: map, origin: origin)
        drawPathPreview(&canvas, path: state.pendingPath, origin: origin)
        drawTrainers(&canvas, trainers: trainers, origin: origin)
        drawPlayer(&canvas, state: state, origin: origin, atFrame: atFrame)
        return canvas
    }

    private static func cameraOrigin(for position: GridPoint, map: TileMap) -> GridPoint {
        Camera.origin(
            following: position, mapWidth: map.width, mapHeight: map.height,
            viewportWidth: viewportWidth, viewportHeight: viewportHeight
        )
    }

    private static func drawTiles(_ canvas: inout PixelFrame, map: TileMap, origin: GridPoint) {
        for y in 0..<viewportHeight {
            for x in 0..<viewportWidth {
                let tile = GridPoint(x: origin.x + x, y: origin.y + y)
                guard let kind = map[tile], let sprite = SpriteCatalog.sprite(named: TileSprites.name(for: kind)) else {
                    continue
                }
                canvas.blit(sprite, at: screenPoint(tile, origin: origin))
            }
        }
    }

    private static func drawPathPreview(_ canvas: inout PixelFrame, path: [GridPoint], origin: GridPoint) {
        guard let marker = SpriteCatalog.sprite(named: "path-marker") else { return }
        for tile in path {
            canvas.blit(marker, at: screenPoint(tile, origin: origin))
        }
    }

    private static func drawTrainers(_ canvas: inout PixelFrame, trainers: [Trainer], origin: GridPoint) {
        for trainer in trainers {
            guard let sprite = SpriteCatalog.sprite(named: trainer.spriteID) else { continue }
            canvas.blit(sprite, at: screenPoint(trainer.position, origin: origin))
        }
    }

    private static func drawPlayer(_ canvas: inout PixelFrame, state: OverworldState, origin: GridPoint, atFrame: Int) {
        guard let sprite = walkerSprite(facing: state.facing, atFrame: atFrame) else { return }
        canvas.blit(sprite, at: screenPoint(state.position, origin: origin))
    }

    private static func walkerSprite(facing: Direction, atFrame: Int) -> PixelSprite? {
        let walkFrame = (atFrame / 4) % 2
        switch facing {
        case .down: return SpriteCatalog.sprite(named: "walker-down-\(walkFrame)")
        case .up: return SpriteCatalog.sprite(named: "walker-up-\(walkFrame)")
        case .left: return SpriteCatalog.sprite(named: "walker-left-\(walkFrame)")
        case .right: return SpriteCatalog.sprite(named: "walker-left-\(walkFrame)")?.flippedHorizontally()
        }
    }

    private static func screenPoint(_ tile: GridPoint, origin: GridPoint) -> GridPoint {
        GridPoint(x: (tile.x - origin.x) * cellSize, y: (tile.y - origin.y) * cellSize)
    }
}
