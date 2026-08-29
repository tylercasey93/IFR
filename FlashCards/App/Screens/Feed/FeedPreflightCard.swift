// App/Screens/Feed/FeedPreflightCard.swift
import SwiftUI

/// Pretest card shown BEFORE a lesson's video (the "pretesting effect":
/// attempting an answer first improves learning from the video, even when the
/// guess is wrong). Records the guess and deliberately reveals nothing — the
/// video is the answer. First answer wins; revisits render read-only.
struct FeedPreflightCard: View {
    let lesson: FeedLesson
    @Environment(FeedProgressStore.self) private var progress
    @State private var selectedIndex: Int?

    private var question: FeedQuizQuestion { lesson.quiz[0] }
    private var alreadyAnswered: Bool { progress.preflightResult(lesson.id) != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer(minLength: 0)

            Text("YOUR AIRPLANE · \(lesson.title.uppercased())")
                .placard()

            Text("Before Duke says a word — what would you do?")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(question.question)
                .font(.title2.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 12) {
                ForEach(question.choices.indices, id: \.self) { index in
                    choiceButton(index)
                }
                noIdeaButton
            }

            if selectedIndex != nil || alreadyAnswered {
                Label("Roger. Answer's in the lesson — swipe up.", systemImage: "chevron.up")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.amber)
                    .transition(.opacity)
            }

            Spacer(minLength: 0)
        }
        .padding(24)
        .background(Theme.panel.gradient)
    }

    private func choiceButton(_ index: Int) -> some View {
        Button {
            answer(index)
        } label: {
            HStack {
                Text(question.choices[index])
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if selectedIndex == index {
                    // Logged, not graded: no right/wrong reveal here.
                    Image(systemName: "checkmark.circle").foregroundStyle(Theme.accent)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .opacity(alreadyAnswered && selectedIndex != index ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("feedPreflightOption-\(index)")
    }

    private var noIdeaButton: some View {
        Button {
            answer(nil)
        } label: {
            Text("No idea — show me")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
        .disabled(selectedIndex != nil || alreadyAnswered)
        .accessibilityIdentifier("feedPreflightNoIdea")
    }

    /// nil = "no idea", recorded as an incorrect pretest.
    private func answer(_ index: Int?) {
        guard selectedIndex == nil, !alreadyAnswered else { return }
        Haptics.flip()
        withAnimation(.spring(duration: 0.3)) { selectedIndex = index }
        progress.recordPreflight(lessonID: lesson.id,
                                 correct: index == question.correctIndex)
    }
}
