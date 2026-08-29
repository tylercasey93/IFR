// App/Screens/Progress/SettingsView.swift
import SwiftUI
import IFRCore

struct SettingsView: View {
    @Environment(StudyStore.self) private var store
    @Environment(GameCenterService.self) private var gameCenter

    var body: some View {
        @Bindable var settings = store.settings
        Form {
            Section("Exam") {
                Toggle("Exam date set", isOn: Binding(
                    get: { settings.examDate != nil },
                    set: { settings.examDate = $0 ? Calendar.current.date(byAdding: .month, value: 2, to: .now) : nil }))
                if let _ = settings.examDate {
                    DatePicker("Exam date", selection: Binding(
                        get: { settings.examDate ?? .now },
                        set: { settings.examDate = $0 }), displayedComponents: .date)
                }
            }
            Section("Study") {
                Stepper("New cards/day: \(settings.newCardsPerDay)",
                        value: $settings.newCardsPerDay, in: 5...50, step: 5)
                Stepper("Daily goal: \(settings.dailyGoalCards) cards",
                        value: $settings.dailyGoalCards, in: 5...50, step: 5)
            }
            Section("Categories unlocked") {
                ForEach(IFRCore.Category.allCases, id: \.self) { category in
                    Toggle(category.displayName, isOn: Binding(
                        get: { settings.unlockedCategoriesRaw.contains(category.rawValue) },
                        set: { on in
                            if on {
                                settings.unlockedCategoriesRaw.append(category.rawValue)
                            } else {
                                settings.unlockedCategoriesRaw.removeAll { $0 == category.rawValue }
                            }
                        }))
                }
            }
            Section("Reminders") {
                Toggle("Daily reminder", isOn: $settings.reminderEnabled)
                if settings.reminderEnabled {
                    DatePicker("Time", selection: Binding(
                        get: {
                            Calendar.current.date(from: DateComponents(
                                hour: settings.reminderHour, minute: settings.reminderMinute)) ?? .now
                        },
                        set: {
                            let parts = Calendar.current.dateComponents([.hour, .minute], from: $0)
                            settings.reminderHour = parts.hour ?? 18
                            settings.reminderMinute = parts.minute ?? 0
                        }), displayedComponents: .hourAndMinute)
                }
                Toggle("Streak-at-risk alert", isOn: $settings.streakRiskEnabled)
                Toggle("Duke's daily brief", isOn: $settings.briefEnabled)
            }
            Section("Game Center") {
                if gameCenter.isAuthenticated {
                    Label("Signed in", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                } else {
                    Button("Sign in to Game Center") { gameCenter.authenticate() }
                }
            }
        }
        .navigationTitle("Settings")
    }
}
