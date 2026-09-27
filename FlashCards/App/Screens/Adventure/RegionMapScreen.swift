import SwiftUI
import IFRCore

struct RegionMapScreen: View {
    @Environment(StudyStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let content: AdventureContent
    let onSelect: (Airport) -> Void

    var body: some View {
        List(targets, id: \.id) { airport in
            Button(airport.name) { select(airport) }
                .accessibilityIdentifier("directTo-\(airport.id)")
        }
        .accessibilityIdentifier("directToPicker")
    }

    private var targets: [Airport] {
        DirectTo.targets(save: store.adventureSave, region: content.region)
    }

    private func select(_ airport: Airport) {
        onSelect(airport)
        dismiss()
    }
}
