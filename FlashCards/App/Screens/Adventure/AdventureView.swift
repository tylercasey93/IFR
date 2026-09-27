import SwiftUI
import IFRCore

struct AdventureView: View {
    @Environment(StudyStore.self) private var store
    @State private var content: AdventureContent?
    @State private var activeBattle: BattleRun?

    private let seed: UInt64?

    init() {
        seed = AdventureView.readSeedArgument(CommandLine.arguments)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let content {
                    RegionMapScreen(content: content, startBattle: { activeBattle = $0 })
                } else {
                    ProgressView()
                        .onAppear { content = try? AdventureContent.load() }
                }
            }
        }
        .fullScreenCover(item: $activeBattle) { run in
            BattleScreen(run: run)
        }
    }

    private static func readSeedArgument(_ arguments: [String]) -> UInt64? {
        guard let flagIndex = arguments.firstIndex(of: "-adventureSeed"),
              arguments.indices.contains(flagIndex + 1) else { return nil }
        return UInt64(arguments[flagIndex + 1])
    }
}
