// App/Screens/Feed/FeedQuizCard.swift
import SwiftUI

/// A full-page quiz interstitial shown right after a lesson video. Mirrors the
/// study CardView's multiple-choice interaction (thinMaterial options, instant
/// right/wrong reveal, haptics) at feed scale.
struct FeedQuizCard: View {
    let lesson: FeedLesson
    let questionIndex: Int
    @Environment(FeedProgressStore.self) private var progress
    @State private var selectedIndex: Int?

    private var question: FeedQuizQuestion { lesson.quiz[questionIndex] }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer(minLength: 0)

            Text("QUIZ · \(lesson.title.uppercased())")
                .placard()

            Text(question.question)
                .font(.title2.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 12) {
                ForEach(question.choices.indices, id: \.self) { index in
                    choiceButton(index)
                }
            }

            if let selectedIndex {
                explanation(correct: selectedIndex == question.correctIndex)
            }

            Spacer(minLength: 0)

            Label("Swipe up for the next one", systemImage: "chevron.up")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
        .padding(24)
        .background(Theme.panel.gradient)
        .onChange(of: questionIndex) { selectedIndex = nil }
    }

    private func choiceButton(_ index: Int) -> some View {
        Button {
            guard selectedIndex == nil else { return }
            withAnimation(.spring(duration: 0.3)) { selectedIndex = index }
            let correct = index == question.correctIndex
            if correct {
                Haptics.correct()
            } else {
                Haptics.incorrect()
            }
            progress.recordQuiz(lessonID: lesson.id, questionIndex: questionIndex, correct: correct)
        } label: {
            HStack {
                Text(question.choices[index])
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let selectedIndex {
                    if index == question.correctIndex {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    } else if index == selectedIndex {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("feedQuizOption-\(index)")
    }

    private func explanation(correct: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(correct ? "Correct" : "Not quite",
                  systemImage: correct ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(correct ? Theme.accent : Theme.amber)
            Text(question.explanation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.bezel, lineWidth: 1))
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}
