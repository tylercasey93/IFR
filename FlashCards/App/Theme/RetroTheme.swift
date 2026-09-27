import SwiftUI
import UIKit

enum RetroTheme {
    static let pixelFontName = "PressStart2P-Regular"

    static func pixelFont(size: CGFloat) -> Font {
        guard UIFont(name: pixelFontName, size: size) != nil else {
            return Font.system(size: size, design: .monospaced)
        }
        return Font.custom(pixelFontName, size: size)
    }

    static func pixelFontSize(scale: Int, displayScale: CGFloat) -> CGFloat {
        8 * CGFloat(scale) / displayScale
    }
}
