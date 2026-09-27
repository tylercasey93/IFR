import SwiftUI
import IFRCore

struct BattleScreen: View {
    @Environment(StudyStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale
    let run: BattleRun

    @State private var model: BattleScreenModel?

    var body: some View {
        Group {
            if let model {
                content(model: model)
            } else {
                Color.clear.onAppear { model = BattleScreenModel(run: run, store: store) }
            }
        }
    }

    private func content(model: BattleScreenModel) -> some View {
        GeometryReader { geometry in
            TimelineView(.animation) { context in
                let scale = IntegerScaler.scale(viewWidth: geometry.size.width, viewHeight: geometry.size.height,
                                                displayScale: displayScale)
                let frame = renderedFrame(model: model, at: context.date)
                VStack(spacing: 0) {
                    ZStack {
                        GBAScreen(frame: frame)
                        HPBarView(plate: .enemy, name: model.state.opponent.nameplateName,
                                 hp: model.state.opponentHP, maxHP: model.state.opponent.maxHP,
                                 scale: scale, displayScale: displayScale)
                        HPBarView(plate: .player, name: run.playerPlateName,
                                 hp: model.state.playerHP, maxHP: model.state.playerMaxHP,
                                 scale: scale, displayScale: displayScale)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { handleTap(model: model, at: context.date) }
                    if model.phase == .asking, let question = model.state.currentQuestion {
                        BattleOptionsView(question: question, answerRevealed: model.answerRevealed,
                                          isEnabled: true,
                                          onSelect: { index in model.answer(selectedIndex: index, at: context.date) })
                    }
                }
                .onChange(of: context.date) { _, date in advance(model: model, at: date) }
                .onChange(of: model.dismissed) { _, done in if done { dismiss() } }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Quit") { model.quit(at: context.date) }
                            .accessibilityIdentifier("battleQuit")
                    }
                }
            }
        }
    }

    private func renderedFrame(model: BattleScreenModel, at date: Date) -> PixelFrame {
        BattleRenderer.frame(state: model.state, displayedPlayerHP: model.state.playerHP,
                             displayedOpponentHP: model.state.opponentHP, playerSpriteID: run.playerSpriteID,
                             atFrame: model.frameIndex(at: date), phase: model.phase)
    }

    private func advance(model: BattleScreenModel, at date: Date) {
        model.advanceWipeIfComplete(at: date)
        model.advanceIntroIfComplete(at: date)
        model.advanceResolving(at: date)
        if model.phase == .asking { model.stemDidFinishTyping() }
    }

    private func handleTap(model: BattleScreenModel, at date: Date) {
        if model.phase == .ended { model.dismissEnded() }
    }
}
