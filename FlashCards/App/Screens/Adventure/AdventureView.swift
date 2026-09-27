import SwiftUI
import IFRCore

struct AdventureView: View {
    @Environment(StudyStore.self) private var store
    @State private var content: AdventureContent?
    @State private var activeBattle: BattleRun?
    @State private var showingOverworld = false

    private let seed: UInt64?
    private let seededSave: AdventureSave?

    init() {
        seed = AdventureView.readSeedArgument(CommandLine.arguments)
        seededSave = AdventureView.readSaveArgument(CommandLine.arguments)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let content {
                    RegionMapScreen(content: content, startBattle: { activeBattle = $0 })
                } else {
                    ProgressView()
                        .onAppear { load() }
                }
            }
            .toolbar {
                if content != nil {
                    ToolbarItem { Button("Walk") { showingOverworld = true }.accessibilityIdentifier("walkButton") }
                }
            }
        }
        .fullScreenCover(item: $activeBattle) { run in
            BattleScreen(run: run)
        }
        .fullScreenCover(isPresented: $showingOverworld) {
            if let content {
                OverworldScreen(content: content, seed: seed)
            }
        }
    }

    private func load() {
        content = try? AdventureContent.load()
        if let seededSave {
            store.updateAdventureSave(seededSave)
        }
    }

    private static func readSeedArgument(_ arguments: [String]) -> UInt64? {
        guard let flagIndex = arguments.firstIndex(of: "-adventureSeed"),
              arguments.indices.contains(flagIndex + 1) else { return nil }
        return UInt64(arguments[flagIndex + 1])
    }

    private static func readSaveArgument(_ arguments: [String]) -> AdventureSave? {
        guard let flagIndex = arguments.firstIndex(of: "-adventureSaveJSON"),
              arguments.indices.contains(flagIndex + 1),
              let data = arguments[flagIndex + 1].data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(AdventureSave.self, from: data)
    }
}
