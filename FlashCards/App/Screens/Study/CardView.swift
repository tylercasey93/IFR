// App/Screens/Study/CardView.swift
import SwiftUI
import IFRCore

/// How an already-answered card was answered, kept so the user can page back
/// through the session and re-read the card with its answer revealed.
enum ReviewedAnswer: Equatable {
    case grade(Grade)
    case choice(Int)
}

/// One card: flashcard flip + self-grade, or MC options.
/// Calls exactly one of `onGrade` (flashcard self-grade) or `onMCAnswer`
/// (multiple-choice selection), exactly once per question.
/// With `reviewed` set the card is read-only: the answer is shown along with
/// how the user answered it, and no grading callback fires.
struct CardView: View {
    let question: Question
    let asMultipleChoice: Bool
    let onGrade: (Grade) -> Void
    let onMCAnswer: (Int) -> Void
    /// Notifies the container when the Source sheet opens (`true`) or closes (`false`).
    var onSourceToggle: ((Bool) -> Void)? = nil
    var reviewed: ReviewedAnswer? = nil

    @State private var flipped = false
    @State private var selectedIndex: Int?
    @State private var showSource = false

    var body: some View {
        VStack(spacing: 16) {
            if let figure = question.figure {
                Image(figure)
                    .resizable().scaledToFit().frame(maxHeight: 220)
            }
            Text(question.front)
                .font(.title3.weight(.medium))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding()

            if let reviewed {
                reviewBody(reviewed)
            } else if asMultipleChoice, let options = question.options {
                mcOptions(options)
            } else {
                flashcard
            }

            Button("Source", systemImage: "book") { showSource = true }
                .font(.footnote)
                .accessibilityIdentifier("sourceButton")
        }
        .padding()
        .sheet(isPresented: $showSource) {
            SourceSheet(question: question,
                        answerRevealed: flipped || selectedIndex != nil || reviewed != nil)
        }
        .onChange(of: showSource) { onSourceToggle?(showSource) }
        .onChange(of: question.id) {
            flipped = false
            selectedIndex = nil
        }
    }

    @ViewBuilder
    private var flashcard: some View {
        if flipped {
            VStack(spacing: 12) {
                answerPanel
                HStack {
                    gradeButton("Again", .again)
                    gradeButton("Hard", .hard)
                    gradeButton("Good", .good)
                    gradeButton("Easy", .easy)
                }
            }
            .transition(.opacity)
        } else {
            Button("Show answer") {
                Haptics.flip()
                withAnimation(.spring(duration: 0.35)) { flipped = true }
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("showAnswer")
        }
    }

    @ViewBuilder
    private func reviewBody(_ reviewed: ReviewedAnswer) -> some View {
        switch reviewed {
        case .grade(let grade):
            VStack(spacing: 12) {
                answerPanel
                Label("You rated this \(title(for: grade))", systemImage: "checkmark.circle")
                    .font(.footnote)
                    .foregroundStyle(color(for: grade))
            }
        case .choice(let selected):
            mcOptions(question.options ?? [], reviewSelection: selected)
        }
    }

    private var answerPanel: some View {
        Text(question.back)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding()
            .frame(maxWidth: .infinity)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func title(for grade: Grade) -> String {
        switch grade {
        case .again: "Again"
        case .hard: "Hard"
        case .good: "Good"
        case .easy: "Easy"
        }
    }

    private func color(for grade: Grade) -> Color {
        switch grade {
        case .again: .red
        case .hard: .orange
        case .good: .green
        case .easy: .blue
        }
    }

    private func gradeButton(_ title: String, _ grade: Grade) -> some View {
        Button(title) {
            if grade == .good || grade == .easy {
                Haptics.correct()
            }
            onGrade(grade)
        }
            .buttonStyle(.bordered)
            .tint(color(for: grade))
            .accessibilityIdentifier("grade-\(title)")
    }

    private func mcOptions(_ options: [String], reviewSelection: Int? = nil) -> some View {
        VStack(spacing: 10) {
            ForEach(options.indices, id: \.self) { index in
                let revealed = reviewSelection ?? selectedIndex
                Button {
                    guard reviewSelection == nil, selectedIndex == nil else { return }
                    selectedIndex = index
                    if index == question.correctIndex {
                        Haptics.correct()
                    } else {
                        Haptics.incorrect()
                    }
                    onMCAnswer(index)
                } label: {
                    HStack {
                        Text(options[index])
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let revealed {
                            if index == question.correctIndex {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            } else if index == revealed {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("mcOption-\(index)")
            }
        }
    }
}
