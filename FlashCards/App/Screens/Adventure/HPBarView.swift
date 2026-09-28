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
                .offset(x: points(plate.nameOrigin.x), y: points(plate.nameOrigin.y))
            if let numbersRightEdge = plate.numbersRightEdge {
                Text("\(hp)/\(maxHP)")
                    .font(RetroTheme.pixelFont(size: fontSize))
                    .foregroundStyle(.black)
                    .frame(width: points(numbersRightEdge.x), alignment: .trailing)
                    .offset(y: points(numbersRightEdge.y))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var fontSize: CGFloat {
        RetroTheme.pixelFontSize(scale: scale, displayScale: displayScale)
    }

    private func points(_ logical: Int) -> CGFloat {
        CGFloat(logical * scale) / displayScale
    }
}
