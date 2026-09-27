// App/RootView.swift
import SwiftUI

enum AppTab: Hashable {
    case today, study, quiz, progress, adventure
}

struct RootView: View {
    @Environment(StudyStore.self) private var store
    @State private var selectedTab: AppTab = .today
    let router: NotificationTapRouter

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView(startStudying: { selectedTab = .study })
                .tabItem { Label("Today", systemImage: "sun.max.fill") }
                .tag(AppTab.today)
            StudySessionView()
                .tabItem { Label("Study", systemImage: "rectangle.on.rectangle.angled") }
                .tag(AppTab.study)
            QuizSetupView()
                .tabItem { Label("Quiz", systemImage: "checklist") }
                .tag(AppTab.quiz)
            ProgressTabView()
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(AppTab.progress)
            AdventureView()
                .tabItem { Label("Adventure", systemImage: "gamecontroller.fill") }
                .tag(AppTab.adventure)
        }
        .onAppear {
            router.onTab = { selectedTab = $0 }
        }
    }
}
