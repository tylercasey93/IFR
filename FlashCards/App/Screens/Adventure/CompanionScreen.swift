import SwiftUI
import IFRCore

struct CompanionScreen: View {
    @Environment(StudyStore.self) private var store
    let content: AdventureContent

    var body: some View {
        List(IFRCore.Category.allCases, id: \.self) { category in
            HStack {
                Text(category.displayName)
                Spacer()
                Text(stageName(for: category))
            }
            .accessibilityIdentifier("companionSlot-\(category.rawValue)")
        }
        .navigationTitle("Companions")
    }

    private func stageName(for category: IFRCore.Category) -> String {
        let stage = CompanionStage.stage(for: store.adventureMastery(for: category).level)
        guard let species = content.companions.first(where: { $0.category == category }),
              species.stageNames.indices.contains(stage.rawValue - 1) else {
            return category.displayName
        }
        return species.stageNames[stage.rawValue - 1]
    }
}
