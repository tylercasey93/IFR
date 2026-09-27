import SwiftUI
import IFRCore

struct BadgeCaseScreen: View {
    @Environment(StudyStore.self) private var store
    let content: AdventureContent

    var body: some View {
        List(GymID.allCases, id: \.self) { gymID in
            HStack {
                Text(badgeName(for: gymID))
                Spacer()
                Text(isEarned(gymID) ? "Earned" : "Locked")
            }
            .accessibilityIdentifier("badgeSlot-\(gymID.rawValue)")
            .accessibilityValue(isEarned(gymID) ? "earned" : "locked")
        }
        .navigationTitle("Badges")
    }

    private func isEarned(_ gymID: GymID) -> Bool {
        store.adventureSave.badges.contains(gymID)
    }

    private func badgeName(for gymID: GymID) -> String {
        content.gyms.first { $0.id == gymID }?.badgeName ?? gymID.rawValue
    }
}
