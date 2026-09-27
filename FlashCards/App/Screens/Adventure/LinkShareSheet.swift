import SwiftUI
import IFRCore

struct LinkShareSheet: View {
    @Environment(StudyStore.self) private var store
    let content: AdventureContent

    @State private var enteredCode: String = ""
    @State private var ownCode: String = ""
    @State private var activeBattle: BattleRun?
    @State private var battlesWonBeforeBattle = 0
    @State private var lastResult: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Your code") {
                    Text(ownCode)
                    ShareLink(item: shareText)
                }
                Section("Enter opponent code") {
                    TextField("Code", text: $enteredCode)
                        .accessibilityIdentifier("linkCodeField")
                    Button("Start") { start() }
                        .accessibilityIdentifier("linkStart")
                        .disabled(!isEnteredCodeValid)
                }
            }
            .navigationTitle("Link Battle")
        }
        .onAppear { generateOwnCode() }
        .accessibilityIdentifier("linkShareSheet")
        .fullScreenCover(item: $activeBattle) { run in
            BattleScreen(run: run).onDisappear { finish() }
        }
    }

    private var isEnteredCodeValid: Bool {
        LinkBattleCode.decode(enteredCode, bankVersion: store.bank.version) != nil
    }

    private var shareText: String {
        "\(ownCode) \(lastResult)"
    }

    private func generateOwnCode() {
        var rng = SystemRandomNumberGenerator()
        let seed = UInt32.random(in: 0...UInt32.max, using: &rng)
        ownCode = LinkBattleCode.encode(seed: seed, bankVersion: store.bank.version)
    }

    private func start() {
        guard let seed = LinkBattleCode.decode(enteredCode, bankVersion: store.bank.version) else { return }
        let deck = LinkBattleCode.deck(seed: seed, bank: store.bank, scheduler: Scheduler(), now: .now)
        let opponent = LinkBattleCode.opponent(code: enteredCode, deck: deck)
        battlesWonBeforeBattle = store.adventureSave.battlesWon
        activeBattle = BattleRun(
            opponent: opponent, deck: deck, playerMaxHP: PlayerHP.maximum(for: mixedLevel()), missDamage: nil,
            playerSpriteID: "player-back", playerPlateName: "PILOT",
            introDialogue: DialogueScript(pages: []), winDialogue: DialogueScript(pages: []),
            loseDialogue: DialogueScript(pages: []), firstTime: false, returnTo: nil, items: content.items)
    }

    private func mixedLevel() -> MasteryLevel {
        let retentions = store.reviewedRetentionByCategory().values
        let mean = retentions.isEmpty ? 0 : retentions.reduce(0, +) / Double(retentions.count)
        return MasteryLevel.level(forRetention: mean)
    }

    private func finish() {
        lastResult = store.adventureSave.battlesWon > battlesWonBeforeBattle ? "WON" : "LOST"
    }
}
