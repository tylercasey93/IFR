// App/Screens/Quiz/QuizSessionView.swift
import SwiftUI
import IFRCore

struct QuizSessionView: View {
    @Environment(StudyStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let questions: [Question]
    let isMockExam: Bool

    @State private var index = 0
    @State private var results: [Bool] = []
    @State private var missed: [Question] = []
    /// The option picked for each answered question, parallel to `results`.
    /// Feedback was already shown when the question was answered, so paging
    /// back to re-read it reveals nothing new — and never re-scores.
    @State private var selections: [Int] = []
    /// Non-nil while the user is paging back through answered questions.
    @State private var reviewIndex: Int?
    @State private var score: QuizScore?
    @State private var advanceTask: Task<Void, Never>?
    @State private var mcAnswered = false

    var body: some View {
        NavigationStack {
            Group {
                if let score {
                    ScoreReportView(score: score, missed: missed, results: results,
                                    questions: questions, done: { dismiss() })
                } else if questions.isEmpty {
                    VStack(spacing: 16) {
                        ContentUnavailableView("No questions available", systemImage: "tray",
                                               description: Text("This category has no quiz questions yet."))
                        Button("Done") { dismiss() }
                            .buttonStyle(.borderedProminent)
                    }
                } else if index < questions.count || reviewIndex != nil {
                    session
                }
            }
            .navigationTitle(isMockExam ? "Mock Exam" : "Quiz")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    // "Close" once the score report is showing — there's nothing
                    // left to quit out of at that point, just dismiss the sheet.
                    Button(score != nil ? "Close" : "Quit") {
                        advanceTask?.cancel()
                        advanceTask = nil
                        dismiss()
                    }
                }
            }
        }
    }

    private var session: some View {
        let displayIndex = reviewIndex ?? index
        let question = questions[displayIndex]
        return VStack(spacing: 8) {
            ProgressView(value: Double(index), total: Double(questions.count))
                .padding(.horizontal)
            controls
            ScrollView {
                CardView(question: question, asMultipleChoice: true,
                         onGrade: { _ in },
                         onMCAnswer: { selected in
                             selections.append(selected)
                             let correct = store.submitMultipleChoice(
                                 question, selectedIndex: selected, inQuiz: true)
                             results.append(correct)
                             if !correct { missed.append(question) }
                             mcAnswered = true
                             advanceTask = Task {
                                 try? await Task.sleep(for: .seconds(1.2))
                                 if !Task.isCancelled { advanceOrFinish() }
                             }
                         },
                         onSourceToggle: { open in
                             guard reviewIndex == nil else { return }
                             if open {
                                 // Pause auto-advance while the user reads the source.
                                 advanceTask?.cancel()
                             } else if mcAnswered {
                                 // User finished reading; answer already recorded.
                                 advanceOrFinish()
                             }
                         },
                         reviewed: reviewIndex.map { .choice(selections[$0]) })
            }
        }
    }

    private var controls: some View {
        ZStack {
            VStack(spacing: 2) {
                Text("Question \((reviewIndex ?? index) + 1) of \(questions.count)")
                    .font(.caption).foregroundStyle(.secondary)
                if reviewIndex != nil {
                    Text("Answered")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }
            HStack {
                if reviewIndex != nil {
                    Button { reviewOlder() } label: { Image(systemName: "chevron.left") }
                        .disabled(reviewIndex == 0)
                        .accessibilityIdentifier("reviewOlder")
                        .accessibilityLabel("Previous answered question")
                    Spacer()
                    Button { reviewNewer() } label: { Image(systemName: "chevron.right") }
                        .accessibilityIdentifier("reviewNewer")
                        .accessibilityLabel("Next question")
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

    private func goBack() {
        // A pending auto-advance means this question is already answered; bank
        // it first. On the last question that finishes the quiz instead.
        if mcAnswered { advanceOrFinish() }
        guard score == nil, index > 0 else { return }
        reviewIndex = index - 1
    }

    private func reviewOlder() {
        guard let reviewIndex, reviewIndex > 0 else { return }
        self.reviewIndex = reviewIndex - 1
    }

    private func reviewNewer() {
        guard let reviewIndex else { return }
        self.reviewIndex = reviewIndex + 1 < index ? reviewIndex + 1 : nil
    }

    private func advanceOrFinish() {
        advanceTask?.cancel()
        advanceTask = nil
        mcAnswered = false
        if index + 1 < questions.count {
            index += 1
        } else {
            score = store.finishQuiz(results: results, isMockExam: isMockExam)
        }
    }
}
