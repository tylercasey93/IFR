import Foundation

public enum IntegerScaler {
    public static func scale(viewWidth: Double, viewHeight: Double, displayScale: Double) -> Int {
        let widthScale = viewWidth * displayScale / Double(PixelFrame.width)
        let heightScale = viewHeight * displayScale / Double(PixelFrame.height)
        let scale = Int(min(widthScale, heightScale).rounded(.down))
        return max(1, scale)
    }

    public static func canvasSize(scale: Int, displayScale: Double) -> (width: Double, height: Double) {
        let width = Double(PixelFrame.width * scale) / displayScale
        let height = Double(PixelFrame.height * scale) / displayScale
        return (width, height)
    }
}
