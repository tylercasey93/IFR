// App/GameCenter/LeaderboardView.swift
import SwiftUI

struct LeaderboardView: View {
    /// Keys the entry load on BOTH the selected board and auth state, so the
    /// list also loads when Game Center sign-in completes asynchronously
    /// after the view first appeared.
    private struct LoadKey: Hashable {
        let board: String
        let auth: Bool
    }

    @Environment(GameCenterService.self) private var gameCenter
    @State private var boardID = LeaderboardID.weeklyXP
    @State private var entries: [LeaderboardEntry] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LEADERBOARD").placard()
            Picker("Board", selection: $boardID) {
                Text("This week").tag(LeaderboardID.weeklyXP)
                Text("All time").tag(LeaderboardID.allTimeXP)
                Text("Streak").tag(LeaderboardID.longestStreak)
            }
            .pickerStyle(.segmented)

            if !gameCenter.isAuthenticated {
                Label("Sign in to Game Center to race your brother", systemImage: "trophy")
                    .foregroundStyle(.secondary)
            } else if entries.isEmpty {
                Text("No scores yet this period — first study session wins!")
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                ForEach(entries) { entry in
                    HStack {
                        Text("#\(entry.rank)").monospacedDigit().foregroundStyle(.secondary)
                        Text(entry.displayName).bold(entry.isLocalPlayer)
                        Spacer()
                        Text("\(entry.score)").monospacedDigit()
                    }
                }
            }
        }
        .instrumentPanel()
        .task(id: LoadKey(board: boardID, auth: gameCenter.isAuthenticated)) {
            entries = await gameCenter.loadEntries(leaderboardID: boardID)
        }
    }
}
