// App/Screens/Study/StudySessionView.swift
import SwiftUI
import IFRCore

struct StudySessionView: View {
    @Environment(StudyStore.self) private var store
    @State private var queue: [Question] = []
    @State private var index = 0
    /// One entry per answered card, parallel to `queue[0..<index]`. Grading is
    /// final — paging back re-shows the card read-only; it never re-submits.
    @State private var answers: [ReviewedAnswer] = []
    /// Non-nil while the user is paging back through answered cards.
    @State private var reviewIndex: Int?
    @State private var mcAdvanceTask: Task<Void, Never>?
    @State private var mcAnswered = false

    var body: some View {
        NavigationStack {
            Group {
                if index < queue.count || reviewIndex != nil {
                    session
                } else {
                    ContentUnavailableView(
                        queue.isEmpty ? "Nothing due right now" : "Session complete!",
                        systemImage: queue.isEmpty ? "checkmark.seal" : "party.popper",
                        description: Text(queue.isEmpty ? "Come back later or take a quiz."
                                                        : "\(queue.count) cards reviewed. 🔥"))
                }
            }
            .navigationTitle("Study")
            .onAppear { startSessionIfNeeded() }
        }
    }

    private var session: some View {
        let displayIndex = reviewIndex ?? index
        let question = queue[displayIndex]
        return VStack(spacing: 8) {
            ProgressView(value: Double(index), total: Double(queue.count))
                .padding(.horizontal)
            controls(for: question)
            ScrollView {
                CardView(question: question,
                         asMultipleChoice: question.isMultipleChoiceCapable,
                         onGrade: { grade in
                             answers.append(.grade(grade))
                             store.submitFlashcard(question, grade: grade)
                             advance()
                         },
                         onMCAnswer: { selected in
                             answers.append(.choice(selected))
                             store.submitMultipleChoice(question, selectedIndex: selected, inQuiz: false)
                             mcAnswered = true
                             // Deliberate: if the user tabs away mid-timer, the advance still
                             // fires in the background (answer already persisted; session
                             // resumes at the next card).
                             mcAdvanceTask = Task {
                                 try? await Task.sleep(for: .seconds(1.2))
                                 if !Task.isCancelled { advance() }
                             }
                         },
                         onSourceToggle: { open in
                             guard reviewIndex == nil else { return }
                             if open {
                                 // Pause auto-advance while the user reads the source.
                                 mcAdvanceTask?.cancel()
                             } else if question.isMultipleChoiceCapable && mcAnswered {
                                 // User finished reading; answer already persisted.
                                 advance()
                             }
                         },
                         reviewed: reviewIndex.map { answers[$0] })
            }
        }
    }

    /// Category caption centered over the card, with previous/next paging at
    /// the edges. Paging back shows answered cards read-only.
    private func controls(for question: Question) -> some View {
        ZStack {
            VStack(spacing: 2) {
                Text(question.category.displayName)
                    .font(.caption).foregroundStyle(.secondary)
                if let reviewIndex {
                    Text("Answered · \(reviewIndex + 1) of \(index)")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }
            HStack {
                if reviewIndex != nil {
                    Button { reviewOlder() } label: { Image(systemName: "chevron.left") }
                        .disabled(reviewIndex == 0)
                        .accessibilityIdentifier("reviewOlder")
                        .accessibilityLabel("Previous answered card")
                    Spacer()
                    Button { reviewNewer() } label: { Image(systemName: "chevron.right") }
                        .accessibilityIdentifier("reviewNewer")
                        .accessibilityLabel("Next card")
                } else if index > 0 {
                    Button { goBack() } label: { Image(systemName: "chevron.left") }
                        .accessibilityIdentifier("previousCard")
                        .accessibilityLabel("Previous question")
                    Spacer()
                }
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
        }
        .padding(.horizontal)
    }

    private func startSessionIfNeeded() {
        guard index >= queue.count, reviewIndex == nil else { return }
        queue = store.todaySession()
        index = 0
        answers = []
    }

    private func goBack() {
        // A pending MC auto-advance means the current card is already answered;
        // bank it so it becomes the card being reviewed.
        if mcAnswered { advance() }
        guard index > 0 else { return }
        reviewIndex = index - 1
    }

    private func reviewOlder() {
        guard let reviewIndex, reviewIndex > 0 else { return }
        self.reviewIndex = reviewIndex - 1
    }

    private func reviewNewer() {
        guard let reviewIndex else { return }
        // Past the newest answered card, resume the live question.
        self.reviewIndex = reviewIndex + 1 < index ? reviewIndex + 1 : nil
    }

    private func advance() {
        mcAdvanceTask?.cancel()
        mcAdvanceTask = nil
        mcAnswered = false
        index += 1
    }
}
