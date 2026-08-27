// App/Screens/Progress/ProgressTabView.swift
import SwiftUI
import IFRCore

struct ProgressTabView: View {
    @Environment(StudyStore.self) private var store

    private let columns = [GridItem(.adaptive(minimum: 100))]

    var body: some View {
        NavigationStack {
            List {
                Section("Category mastery") {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(IFRCore.Category.allCases, id: \.self) { category in
                            let m = store.mastery(for: category)
                            MasteryRing(category: category, retention: m.retention, level: m.level)
                        }
                    }
                    .padding(.vertical, 8)
                }
                if let examDate = store.settings.examDate {
                    Section("Exam readiness") {
                        let readiness = store.readiness(examDate: examDate)
                        LabeledContent("Predicted retention on exam day",
                                       value: "\(Int((readiness * 100).rounded()))%")
                        LabeledContent("Exam date", value: examDate.formatted(date: .abbreviated, time: .omitted))
                    }
                }
                Section("Badges (\(store.earnedBadges.count))") {
                    if store.earnedBadges.isEmpty {
                        Text("Fly a session to earn your first badge.").foregroundStyle(.secondary)
                    } else {
                        ForEach(store.earnedBadges, id: \.self) { badge in
                            Label(badge.displayName, systemImage: "medal.fill")
                        }
                    }
                }
                Section("Stats") {
                    LabeledContent("Total XP", value: "\(store.totalXP)")
                    LabeledContent("Longest streak", value: "\(store.longestStreak) days")
                }
                Section {
                    NavigationLink("Settings") { SettingsView() }
                }
            }
            .navigationTitle("Progress")
        }
    }
}
