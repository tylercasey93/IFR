import SwiftUI
import IFRCore

struct BattleTowerScreen: View {
    @Environment(StudyStore.self) private var store
    let content: AdventureContent

    @State private var tower: BattleTower?
    @State private var activeBattle: BattleRun?
    @State private var battlesWonBeforeBattle = 0

    var body: some View {
        VStack {
            if let tower {
                Text("Floor \(tower.floor)")
                    .accessibilityIdentifier("towerFloor")
                Button("Challenge") { startBattle(tower: tower) }
                    .accessibilityIdentifier("towerChallenge")
            } else {
                ProgressView()
            }
        }
        .accessibilityIdentifier("battleTowerScreen")
        .navigationTitle("Battle Tower")
        .onAppear { startTowerIfNeeded() }
        .fullScreenCover(item: $activeBattle) { run in
            BattleScreen(run: run)
                .onDisappear { battleDismissed() }
        }
    }

    private func startTowerIfNeeded() {
        guard tower == nil else { return }
        tower = BattleTower.start(playerMaxHP: Self.startingMaxHP(store: store))
    }

    private func startBattle(tower: BattleTower) {
        let deck = store.drawEncounterDeck(count: BattleTower.questionsPerFloor, categories: nil)
        let opponent = tower.opponent(forFloor: tower.floor, deck: deck)
        battlesWonBeforeBattle = store.adventureSave.battlesWon
        activeBattle = BattleRun(
            opponent: opponent, deck: deck, playerMaxHP: tower.playerMaxHP,
            missDamage: BattleTower.missDamage(floor: tower.floor), playerSpriteID: "player-back",
            playerPlateName: "PILOT", introDialogue: DialogueScript(pages: []),
            winDialogue: DialogueScript(pages: []), loseDialogue: DialogueScript(pages: []),
            firstTime: false, returnTo: nil, items: content.items)
    }

    private func battleDismissed() {
        activeBattle = nil
        guard let currentTower = tower else { return }
        guard store.adventureSave.battlesWon > battlesWonBeforeBattle else {
            tower = nil
            return
        }
        tower = BattleTower(floor: currentTower.floor + 1, playerHP: currentTower.playerMaxHP,
                            playerMaxHP: currentTower.playerMaxHP)
    }

    private static func startingMaxHP(store: StudyStore) -> Int {
        let retentions = store.reviewedRetentionByCategory().values
        let mean = retentions.isEmpty ? 0 : retentions.reduce(0, +) / Double(retentions.count)
        return PlayerHP.maximum(for: MasteryLevel.level(forRetention: mean))
    }
}
