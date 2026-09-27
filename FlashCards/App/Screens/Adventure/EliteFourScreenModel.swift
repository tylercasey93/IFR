import Foundation
import IFRCore

@Observable
@MainActor
final class EliteFourScreenModel {
    private(set) var run: EliteFourRun
    private(set) var activeBattle: BattleRun?

    let content: AdventureContent
    private let store: StudyStore
    private var battlesWonBeforeBattle = 0

    init(content: AdventureContent, store: StudyStore) {
        self.content = content
        self.store = store
        run = EliteFourRun.start(playerMaxHP: EliteFourScreenModel.startingMaxHP(store: store))
    }

    var currentMember: EliteMember? {
        content.eliteFour.first { $0.order == run.memberIndex + 1 }
    }

    func challengeCurrentMember() {
        guard let member = currentMember else { return }
        let deck = store.drawEncounterDeck(count: member.questionCount, categories: member.categories)
        battlesWonBeforeBattle = store.adventureSave.battlesWon
        activeBattle = BattleRun(
            opponent: eliteOpponent(member: member, deck: deck), deck: deck, playerMaxHP: run.playerMaxHP,
            missDamage: nil, playerSpriteID: "player-back", playerPlateName: "PILOT",
            introDialogue: content.dialogue[member.dialogue.intro] ?? DialogueScript(pages: []),
            winDialogue: content.dialogue[member.dialogue.win] ?? DialogueScript(pages: []),
            loseDialogue: content.dialogue[member.dialogue.lose] ?? DialogueScript(pages: []),
            firstTime: false, returnTo: nil, items: content.items)
    }

    func clearActiveBattle() {
        activeBattle = nil
    }

    func battleDismissed() {
        activeBattle = nil
        guard store.adventureSave.battlesWon > battlesWonBeforeBattle else { return }
        run = EliteFourRun(memberIndex: run.memberIndex + 1, playerHP: run.playerMaxHP, playerMaxHP: run.playerMaxHP)
        if run.isCleared {
            store.finishEliteFourRun(run)
        }
    }

    private func eliteOpponent(member: EliteMember, deck: [Question]) -> Opponent {
        Opponent(id: member.id, name: member.name, nameplateName: member.nameplateName,
                spriteID: member.spriteID, tier: .eliteFour, maxHP: OpponentHP.tuned(for: deck))
    }

    private static func startingMaxHP(store: StudyStore) -> Int {
        let retentions = store.reviewedRetentionByCategory().values
        let mean = retentions.isEmpty ? 0 : retentions.reduce(0, +) / Double(retentions.count)
        return PlayerHP.maximum(for: MasteryLevel.level(forRetention: mean))
    }
}
