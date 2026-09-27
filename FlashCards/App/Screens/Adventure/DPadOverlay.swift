import SwiftUI
import IFRCore

struct DPadOverlay: View {
    let onPress: (Direction) -> Void

    var body: some View {
        VStack(spacing: 2) {
            directionButton(.up)
            HStack(spacing: 2) {
                directionButton(.left)
                Color.clear.frame(width: 44, height: 44)
                directionButton(.right)
            }
            directionButton(.down)
        }
    }

    private func directionButton(_ direction: Direction) -> some View {
        Button {
            onPress(direction)
        } label: {
            Color.black.opacity(0.35)
        }
        .frame(width: 44, height: 44)
        .accessibilityIdentifier("dpad-\(direction.rawValue)")
    }
}
