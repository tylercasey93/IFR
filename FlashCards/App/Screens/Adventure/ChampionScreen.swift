import SwiftUI
import IFRCore

struct ChampionScreen: View {
    @Environment(StudyStore.self) private var store
    let content: AdventureContent

    @State private var activeBattle: BattleRun?
    @State private var dialogue: DialogueScript?

    var body: some View {
        VStack {
            if let dialogue {
                DialogueBoxView(script: dialogue, scale: 1, displayScale: 1, onFinished: { self.dialogue = nil })
            }
            Button("Challenge") { startChampionBattle() }
                .accessibilityIdentifier("gym-champion")
        }
        .accessibilityIdentifier("championScreen")
        .onAppear { dialogue = content.dialogue[content.champion.dialogue.intro] }
        .fullScreenCover(item: $activeBattle) { run in
            BattleScreen(run: run)
        }
    }

    private func startChampionBattle() {
        let deck = store.championDeck()
        let opponent = Opponent(
            id: "champion", name: content.champion.name, nameplateName: content.champion.nameplateName,
            spriteID: content.champion.spriteID, tier: .champion, maxHP: ChampionBattle.opponentHP)
        activeBattle = BattleRun(
            opponent: opponent, deck: deck, playerMaxHP: ChampionBattle.playerHP, missDamage: nil,
            playerSpriteID: "player-back", playerPlateName: "PILOT",
            introDialogue: content.dialogue[content.champion.dialogue.intro] ?? DialogueScript(pages: []),
            winDialogue: content.dialogue[content.champion.dialogue.win] ?? DialogueScript(pages: []),
            loseDialogue: content.dialogue[content.champion.dialogue.lose] ?? DialogueScript(pages: []),
            firstTime: store.adventureSave.championWins == 0, returnTo: nil, items: content.items)
    }
}
