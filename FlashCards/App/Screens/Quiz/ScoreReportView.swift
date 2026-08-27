// App/Screens/Quiz/ScoreReportView.swift
import SwiftUI
import IFRCore

struct ScoreReportView: View {
    let score: QuizScore
    let missed: [Question]
    let results: [Bool]
    let questions: [Question]
    let done: () -> Void

    @State private var reviewingMisses = false
    @State private var missIndex = 0
    @Environment(StudyStore.self) private var store

    private var byCategory: [(IFRCore.Category, Int, Int)] {
        IFRCore.Category.allCases.compactMap { category in
            let pairs = zip(questions, results).filter { $0.0.category == category }
            guard !pairs.isEmpty else { return nil }
            return (category, pairs.filter(\.1).count, pairs.count)
        }
    }

    var body: some View {
        if reviewingMisses, missIndex < missed.count {
            let question = missed[missIndex]
            VStack {
                Text("Reviewing misses (\(missIndex + 1)/\(missed.count))").font(.headline)
                ScrollView {
                    CardView(question: question, asMultipleChoice: false,
                             onGrade: { grade in
                                 store.submitFlashcard(question, grade: grade)
                                 missIndex += 1
                             },
                             onMCAnswer: { _ in })
                }
            }
        } else {
            List {
                Section {
                    VStack(spacing: 8) {
                        Text("\(score.percent)%")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundStyle(score.passed ? .green : .red)
                        Text(score.passed ? "PASS — 70% needed" : "Below the 70% pass mark")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                Section("By category") {
                    ForEach(byCategory, id: \.0) { category, correct, total in
                        LabeledContent(category.displayName, value: "\(correct)/\(total)")
                    }
                }
                Section {
                    if !missed.isEmpty {
                        if reviewingMisses && missIndex >= missed.count {
                            Text("Missed questions reviewed ✓")
                                .foregroundStyle(.secondary)
                        } else {
                            Button("Review \(missed.count) missed questions") { reviewingMisses = true }
                        }
                    }
                    Button("Done", action: done)
                }
            }
        }
    }
}
