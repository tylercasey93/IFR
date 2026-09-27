import SwiftUI
import IFRCore

struct HallOfFameScreen: View {
    @Environment(StudyStore.self) private var store

    var body: some View {
        Group {
            if sortedDates.isEmpty {
                Text("No champion wins yet.")
                    .accessibilityIdentifier("hallOfFameEmpty")
            } else {
                List(Array(sortedDates.enumerated()), id: \.offset) { index, date in
                    Text(date.formatted())
                        .accessibilityIdentifier("hallOfFameEntry-\(index)")
                }
            }
        }
        .navigationTitle("Hall of Fame")
    }

    private var sortedDates: [Date] {
        store.adventureSave.hallOfFame.sorted(by: >)
    }
}
