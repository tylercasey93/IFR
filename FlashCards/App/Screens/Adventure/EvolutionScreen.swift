import SwiftUI
import IFRCore

struct EvolutionScreen: View {
    let evolution: CompanionEvolution
    let content: AdventureContent
    var onFinished: () -> Void = {}

    @Environment(\.displayScale) private var displayScale
    @State private var phaseStart = Date()

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation) { context in
                let frame = frameIndex(at: context.date)
                ZStack(alignment: .bottom) {
                    GBAScreen(frame: renderedFrame(atFrame: frame))
                    Text(caption(atFrame: frame))
                        .font(RetroTheme.pixelFont(size: RetroTheme.pixelFontSize(scale: 1, displayScale: displayScale)))
                        .foregroundStyle(.white)
                        .padding(.bottom, 12)
                }
                .contentShape(Rectangle())
                .onTapGesture { if frame >= BattleWipe.totalFrames { onFinished() } }
            }
        }
        .accessibilityIdentifier("evolutionScreen")
    }

    private func frameIndex(at date: Date) -> Int {
        max(0, Int(date.timeIntervalSince(phaseStart) * 60))
    }

    private func renderedFrame(atFrame frame: Int) -> PixelFrame {
        EvolutionRenderer.frame(
            fromSpriteID: spriteID(for: evolution.from), toSpriteID: spriteID(for: evolution.to), atFrame: frame)
    }

    private func species() -> CompanionSpecies? {
        content.companions.first { $0.category == evolution.category }
    }

    private func spriteID(for stage: CompanionStage) -> String {
        guard let species = species(), species.spriteIDs.indices.contains(stage.rawValue - 1) else { return "" }
        return species.spriteIDs[stage.rawValue - 1]
    }

    private func companionName(for stage: CompanionStage) -> String {
        guard let species = species(), species.stageNames.indices.contains(stage.rawValue - 1) else {
            return evolution.category.displayName
        }
        return species.stageNames[stage.rawValue - 1]
    }

    private func caption(atFrame frame: Int) -> String {
        frame >= BattleWipe.totalFrames ? "\(companionName(for: evolution.to)) evolved!" : ""
    }
}
