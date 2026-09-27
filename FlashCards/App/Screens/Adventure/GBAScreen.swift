import SwiftUI
import IFRCore

struct GBAScreen: View {
    let frame: PixelFrame

    @Environment(\.displayScale) private var displayScale

    var body: some View {
        GeometryReader { geometry in
            let scale = IntegerScaler.scale(
                viewWidth: geometry.size.width,
                viewHeight: geometry.size.height,
                displayScale: displayScale
            )
            let canvas = IntegerScaler.canvasSize(scale: scale, displayScale: displayScale)
            canvasImage
                .frame(width: canvas.width, height: canvas.height)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .background(Theme.panel)
    }

    private var canvasImage: some View {
        Group {
            if let image = PixelImageBuilder.image(from: frame) {
                Image(decorative: image, scale: 1)
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Color.clear
            }
        }
    }
}
