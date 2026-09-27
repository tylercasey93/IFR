import SwiftUI
import IFRCore

struct EliteFourScreen: View {
    @Environment(StudyStore.self) private var store
    let content: AdventureContent

    @State private var model: EliteFourScreenModel?
    @State private var dialogue: DialogueScript?

    var body: some View {
        Group {
            if let model {
                memberView(model)
            } else {
                ProgressView()
                    .onAppear { model = EliteFourScreenModel(content: content, store: store) }
            }
        }
        .accessibilityIdentifier("eliteFourScreen")
    }

    private func memberView(_ model: EliteFourScreenModel) -> some View {
        VStack {
            if model.currentMember != nil {
                if let dialogue {
                    DialogueBoxView(script: dialogue, scale: 1, displayScale: 1, onFinished: { self.dialogue = nil })
                }
                Button("Challenge") { challenge(model: model) }
                    .accessibilityIdentifier("eliteFourChallenge")
            } else {
                Text("Elite Four cleared")
                    .accessibilityIdentifier("eliteFourCleared")
            }
        }
        .onAppear { showIntro(model: model) }
        .fullScreenCover(item: activeBattleBinding(model)) { run in
            BattleScreen(run: run)
                .onDisappear { model.battleDismissed() }
        }
    }

    private func challenge(model: EliteFourScreenModel) {
        dialogue = nil
        model.challengeCurrentMember()
    }

    private func showIntro(model: EliteFourScreenModel) {
        guard let member = model.currentMember else { return }
        dialogue = content.dialogue[member.dialogue.intro]
    }

    private func activeBattleBinding(_ model: EliteFourScreenModel) -> Binding<BattleRun?> {
        Binding(get: { model.activeBattle }, set: { newValue in if newValue == nil { model.clearActiveBattle() } })
    }
}
