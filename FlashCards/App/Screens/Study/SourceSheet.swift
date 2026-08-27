// App/Screens/Study/SourceSheet.swift
import SwiftUI
import IFRCore

struct SourceSheet: View {
    let question: Question
    /// The Answer section is hidden until the user has flipped or answered,
    /// so opening the source early can't spoil the card.
    let answerRevealed: Bool

    var body: some View {
        NavigationStack {
            List {
                if answerRevealed {
                    Section("Answer") {
                        Text(question.back)
                        Text(question.explanation).foregroundStyle(.secondary)
                    }
                }
                Section("Source") {
                    LabeledContent("Document", value: question.source.document)
                    LabeledContent("Section", value: question.source.section)
                    Link("Open FAA source", destination: question.source.url)
                }
                Section("ACS codes") {
                    Text(question.acsCodes.joined(separator: ", ")).font(.footnote.monospaced())
                }
            }
            .navigationTitle("Source")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}
