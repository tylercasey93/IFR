import CoreGraphics
import Foundation
import IFRCore

enum PixelImageBuilder {
    static func image(from frame: PixelFrame) -> CGImage? {
        let provider = CGDataProvider(data: rgbaData(from: frame) as CFData)
        guard let provider else { return nil }
        return CGImage(
            width: PixelFrame.width,
            height: PixelFrame.height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: PixelFrame.width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }

    private static func rgbaData(from frame: PixelFrame) -> Data {
        var bytes = [UInt8](repeating: 0, count: frame.pixels.count * 4)
        for (index, paletteIndex) in frame.pixels.enumerated() {
            let offset = index * 4
            guard paletteIndex != Palette.transparent else { continue }
            let colour = Palette.entries[Int(paletteIndex)]
            bytes[offset] = colour.r
            bytes[offset + 1] = colour.g
            bytes[offset + 2] = colour.b
            bytes[offset + 3] = 255
        }
        return Data(bytes)
    }
}
