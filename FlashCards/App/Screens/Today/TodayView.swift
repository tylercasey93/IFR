// App/Screens/Today/TodayView.swift
import SwiftUI
import IFRCore

struct TodayView: View {
    @Environment(StudyStore.self) private var store
    let startStudying: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    heroPanel
                    LeaderboardView()
                }
                .padding()
            }
            .navigationTitle("Today")
        }
    }

    /// Data-block header: today's date, and the exam countdown when one is set.
    private var header: some View {
        HStack {
            Text(Date.now.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
                    .uppercased())
                .foregroundStyle(.secondary)
            Spacer()
            if let days = daysToExam {
                Text(days > 0 ? "EXAM IN \(days) DAYS" : "EXAM DAY")
                    .foregroundStyle(Theme.amber)
            }
        }
        .font(.caption.monospaced().weight(.medium))
        .padding(.horizontal, 4)
    }

    private var daysToExam: Int? {
        guard let examDate = store.settings.examDate else { return nil }
        let calendar = Calendar.current
        return calendar.dateComponents([.day],
                                       from: calendar.startOfDay(for: .now),
                                       to: calendar.startOfDay(for: examDate)).day
    }

    private var heroPanel: some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                InstrumentGauge(value: store.answeredToday, goal: store.settings.dailyGoalCards)
                VStack(alignment: .leading, spacing: 16) {
                    readout("\(store.streakDisplay)",
                            label: store.freezes > 0 ? "DAY STREAK · \(store.freezes)❄" : "DAY STREAK",
                            icon: "flame.fill", tint: Theme.amber)
                    readout("\(store.dueCount)", label: "CARDS DUE",
                            icon: "tray.full.fill", tint: Theme.accent)
                    readout("\(store.weeklyXP)", label: "XP THIS WEEK",
                            icon: "bolt.fill", tint: .secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button(action: startStudying) {
                Text("Start session")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("startSession")
        }
        .instrumentPanel()
    }

    private func readout(_ value: String, label: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(tint)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .monospacedDigit()
                Text(label).placard()
            }
        }
    }
}
