// App/Screens/Progress/MasteryRing.swift
import SwiftUI
import IFRCore

/// A titled progress ring. Generalized beyond bank categories so the feed's
/// Hangar section (whose topic areas don't map onto IFRCore.Category) can
/// reuse it; the category convenience init keeps existing call sites intact.
struct MasteryRing: View {
    let title: String
    let progress: Double
    let caption: String

    init(title: String, progress: Double, caption: String) {
        self.title = title
        self.progress = progress
        self.caption = caption
    }

    init(category: IFRCore.Category, retention: Double, level: MasteryLevel) {
        self.init(title: category.displayName, progress: retention,
                  caption: level.displayName)
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().stroke(.quaternary, lineWidth: 6)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(.tint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int((progress * 100).rounded()))")
                    .font(.headline.monospacedDigit())
            }
            .frame(width: 62, height: 62)
            Text(title)
                .font(.caption2).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(3, reservesSpace: true)
            Text(caption).font(.caption2.bold()).foregroundStyle(.tint)
        }
    }
}
