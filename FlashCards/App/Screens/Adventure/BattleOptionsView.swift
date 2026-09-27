import SwiftUI
import IFRCore

struct BattleOptionsView: View {
    let question: Question
    let answerRevealed: Bool
    let isEnabled: Bool
    let onSelect: (Int) -> Void

    @State private var showsSource = false

    var body: some View {
        VStack(spacing: 8) {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(question.options.indices, id: \.self) { index in
                        optionButton(index)
                    }
                }
            }
            Button("Source") { showsSource = true }
                .accessibilityIdentifier("battleSource")
        }
        .font(RetroTheme.pixelFont(size: 10))
        .sheet(isPresented: $showsSource) {
            SourceSheet(question: question, answerRevealed: answerRevealed)
        }
    }

    private func optionButton(_ index: Int) -> some View {
        Button(question.options[index]) { onSelect(index) }
            .disabled(!isEnabled)
            .buttonStyle(.bordered)
            .accessibilityIdentifier("battleOption-\(index)")
    }
}
