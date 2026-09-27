import CoreGraphics
import IFRCore

enum SpriteRasterizer {
    static func image(from frame: PixelFrame, scale: Int) -> CGImage? {
        let width = PixelFrame.width * scale
        let height = PixelFrame.height * scale
        let space = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.interpolationQuality = .none
        for y in 0..<PixelFrame.height {
            for x in 0..<PixelFrame.width {
                let paletteIndex = frame.pixels[y * PixelFrame.width + x]
                guard paletteIndex != Palette.transparent else { continue }
                let colour = Palette.entries[Int(paletteIndex)]
                context.setFillColor(
                    red: CGFloat(colour.r) / 255,
                    green: CGFloat(colour.g) / 255,
                    blue: CGFloat(colour.b) / 255,
                    alpha: 1
                )
                let deviceY = PixelFrame.height - 1 - y
                let rect = CGRect(x: x * scale, y: deviceY * scale, width: scale, height: scale)
                context.fill(rect)
            }
        }
        return context.makeImage()
    }
}
