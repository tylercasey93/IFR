import SwiftUI
import IFRCore

struct AdventureView: View {
    @Environment(StudyStore.self) private var store
    @State private var content: AdventureContent?
    @State private var showingBadgeCase = false
    @State private var showingHallOfFame = false
    @State private var showingCompanions = false
    @State private var showingLink = false
    @State private var evolutionQueue: [CompanionEvolution] = []

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
                    OverworldScreen(content: content, seed: seed, onBattleFinished: checkEvolutions)
                } else {
                    ProgressView()
                        .onAppear { load() }
                }
            }
            .toolbar {
                if content != nil {
                    ToolbarItem { Button("Badges") { showingBadgeCase = true }.accessibilityIdentifier("badgeCase") }
                    ToolbarItem { Button("Hall of Fame") { showingHallOfFame = true }.accessibilityIdentifier("hallOfFame") }
                    ToolbarItem { Button("Companions") { showingCompanions = true }.accessibilityIdentifier("companions") }
                    ToolbarItem { Button("Link") { showingLink = true }.accessibilityIdentifier("linkBattle") }
                }
            }
            .navigationDestination(isPresented: $showingBadgeCase) {
                if let content { BadgeCaseScreen(content: content) }
            }
            .navigationDestination(isPresented: $showingHallOfFame) {
                HallOfFameScreen()
            }
            .navigationDestination(isPresented: $showingCompanions) {
                if let content { CompanionScreen(content: content) }
            }
            .sheet(isPresented: $showingLink) {
                if let content { LinkShareSheet(content: content) }
            }
            .onAppear { checkEvolutions() }
            .fullScreenCover(isPresented: evolutionShowingBinding()) {
                if let content, let evolution = evolutionQueue.first {
                    EvolutionScreen(evolution: evolution, content: content, onFinished: { evolutionQueue.removeFirst() })
                }
            }
        }
    }

    private func load() {
        content = try? AdventureContent.load()
        if let seededSave {
            store.updateAdventureSave(seededSave)
        }
    }

    private func checkEvolutions() {
        evolutionQueue.append(contentsOf: store.pendingEvolutions())
    }

    private func evolutionShowingBinding() -> Binding<Bool> {
        Binding(get: { !evolutionQueue.isEmpty }, set: { showing in if !showing { evolutionQueue.removeAll() } })
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
