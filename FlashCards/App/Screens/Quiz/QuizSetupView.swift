// App/Screens/Quiz/QuizSetupView.swift
import SwiftUI
import IFRCore

struct QuizSetupView: View {
    @Environment(StudyStore.self) private var store
    @State private var category: IFRCore.Category?
    @State private var length = 10
    @State private var activeQuiz: QuizRun?

    struct QuizRun: Identifiable {
        let id = UUID()
        let questions: [Question]
        let isMockExam: Bool
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Custom quiz") {
                    Picker("Category", selection: $category) {
                        Text("All categories").tag(IFRCore.Category?.none)
                        ForEach(IFRCore.Category.allCases, id: \.self) {
                            Text($0.displayName).tag(IFRCore.Category?.some($0))
                        }
                    }
                    Picker("Length", selection: $length) {
                        ForEach([10, 20, 60], id: \.self) { Text("\($0) questions") }
                    }
                    Button("Start quiz") {
                        let config = QuizConfig(category: category, length: length, isMockExam: false)
                        activeQuiz = QuizRun(questions: store.makeQuiz(config: config), isMockExam: false)
                    }
                }
                Section("The real thing") {
                    Button {
                        activeQuiz = QuizRun(questions: store.makeQuiz(config: .mockExam), isMockExam: true)
                    } label: {
                        Label("60-question mock exam", systemImage: "graduationcap.fill")
                    }
                }
            }
            .navigationTitle("Quiz")
            .fullScreenCover(item: $activeQuiz) { run in
                QuizSessionView(questions: run.questions, isMockExam: run.isMockExam)
            }
        }
    }
}
