import Foundation

public struct PixelFrame: Equatable, Sendable {
    public static let width = 240
    public static let height = 160

    public var pixels: [UInt8]

    public init(fill: UInt8) {
        pixels = [UInt8](repeating: fill, count: PixelFrame.width * PixelFrame.height)
    }

    public mutating func blit(_ sprite: PixelSprite, at point: GridPoint) {
        for spriteY in 0..<sprite.height {
            let frameY = point.y + spriteY
            guard frameY >= 0, frameY < PixelFrame.height else { continue }
            for spriteX in 0..<sprite.width {
                let frameX = point.x + spriteX
                guard frameX >= 0, frameX < PixelFrame.width else { continue }
                let colour = sprite[spriteX, spriteY]
                guard colour != Palette.transparent else { continue }
                pixels[frameY * PixelFrame.width + frameX] = colour
            }
        }
    }

    public mutating func fill(_ rect: PixelRect, index: UInt8) {
        let minX = max(0, rect.x)
        let maxX = min(PixelFrame.width, rect.x + rect.width)
        let minY = max(0, rect.y)
        let maxY = min(PixelFrame.height, rect.y + rect.height)
        guard minX < maxX, minY < maxY else { return }
        for y in minY..<maxY {
            for x in minX..<maxX {
                pixels[y * PixelFrame.width + x] = index
            }
        }
    }

    public mutating func frame(_ rect: PixelRect, outer: UInt8, inner: UInt8) {
        drawOutline(rect, index: outer)
        let inset = PixelRect(x: rect.x + 1, y: rect.y + 1, width: rect.width - 2, height: rect.height - 2)
        guard inset.width > 0, inset.height > 0 else { return }
        drawOutline(inset, index: inner)
    }

    public mutating func line(from start: GridPoint, to end: GridPoint, index: UInt8) {
        var x0 = start.x
        var y0 = start.y
        let dx = abs(end.x - start.x)
        let sx = start.x < end.x ? 1 : -1
        let dy = -abs(end.y - start.y)
        let sy = start.y < end.y ? 1 : -1
        var err = dx + dy
        while true {
            setPixel(x0, y0, index: index)
            if x0 == end.x && y0 == end.y { break }
            let doubledError = 2 * err
            if doubledError >= dy {
                err += dy
                x0 += sx
            }
            if doubledError <= dx {
                err += dx
                y0 += sy
            }
        }
    }

    private mutating func drawOutline(_ rect: PixelRect, index: UInt8) {
        for x in rect.x..<(rect.x + rect.width) {
            setPixel(x, rect.y, index: index)
            setPixel(x, rect.y + rect.height - 1, index: index)
        }
        for y in rect.y..<(rect.y + rect.height) {
            setPixel(rect.x, y, index: index)
            setPixel(rect.x + rect.width - 1, y, index: index)
        }
    }

    private mutating func setPixel(_ x: Int, _ y: Int, index: UInt8) {
        guard x >= 0, x < PixelFrame.width, y >= 0, y < PixelFrame.height else { return }
        pixels[y * PixelFrame.width + x] = index
    }
}
