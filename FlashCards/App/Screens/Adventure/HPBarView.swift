import SwiftUI
import IFRCore

struct HPBarView: View {
    let plate: NamePlate
    let name: String
    let hp: Int
    let maxHP: Int
    let scale: Int
    let displayScale: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            Text(String(name.uppercased().prefix(7)))
                .font(RetroTheme.pixelFont(size: fontSize))
                .foregroundStyle(.black)
                .position(point(for: plate.nameOrigin))
            if let numbersRightEdge = plate.numbersRightEdge {
                Text("\(hp)/\(maxHP)")
                    .font(RetroTheme.pixelFont(size: fontSize))
                    .foregroundStyle(.black)
                    .position(point(for: numbersRightEdge))
            }
        }
    }

    private var fontSize: CGFloat {
        RetroTheme.pixelFontSize(scale: scale, displayScale: displayScale)
    }

    private func point(for origin: GridPoint) -> CGPoint {
        CGPoint(x: CGFloat(origin.x * scale) / displayScale, y: CGFloat(origin.y * scale) / displayScale)
    }
}
