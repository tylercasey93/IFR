// App/Screens/Progress/MasteryRing.swift
import SwiftUI
import IFRCore

struct MasteryRing: View {
    let category: IFRCore.Category
    let retention: Double
    let level: MasteryLevel

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().stroke(.quaternary, lineWidth: 6)
                Circle()
                    .trim(from: 0, to: retention)
                    .stroke(.tint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int((retention * 100).rounded()))")
                    .font(.headline.monospacedDigit())
            }
            .frame(width: 62, height: 62)
            Text(category.displayName)
                .font(.caption2).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(3, reservesSpace: true)
            Text(level.displayName).font(.caption2.bold()).foregroundStyle(.tint)
        }
    }
}
