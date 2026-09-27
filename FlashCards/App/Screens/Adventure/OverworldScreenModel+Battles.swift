import Foundation
import IFRCore

extension OverworldScreenModel {
    func presentGymBattle(gym: Gym, gymID: GymID, airport: Airport) {
        let deck = store.drawEncounterDeck(count: gym.questionCount, categories: [gymID.category])
        let opponent = gym.opponent(maxHP: OpponentHP.tuned(for: deck), airportID: airport.id)
        startBattle(opponent: opponent, deck: deck, level: store.adventureMastery(for: gymID.category).level,
                   dialogueRefs: gym.dialogue, firstTime: !save.badges.contains(gymID))
    }

    func presentCloudBattle(category: Category) {
        let deck = store.drawEncounterDeck(count: 1, categories: [category])
        guard let question = deck.first else { return }
        persist()
        startBattle(opponent: cloudOpponent(category: category, question: question), deck: deck,
                   level: store.adventureMastery(for: category).level, dialogueRefs: nil, firstTime: false)
    }

    func approachAirport(_ airportID: String) {
        persistIfPathComplete()
        guard let airport = content.region.airports.first(where: { $0.id == airportID }), case .gym = airport.role,
              let gymID = airport.gymID, let gym = gym(for: gymID) else { return }
        let result = GymApproach.approaching(gym, content: content, save: save)
        dialogue = result.dialogue
        challengeableGymID = result.challengeableGymID
    }

    func gym(for gymID: GymID) -> Gym? {
        content.gyms.first { $0.id == gymID }
    }

    func cloudOpponent(category: Category, question: Question) -> Opponent {
        Opponent(id: "cloud-\(category.rawValue)", name: "Wild \(category.displayName)",
                nameplateName: String(category.displayName.uppercased().prefix(7)),
                spriteID: "cloud-\(category.rawValue)", tier: .cloud, maxHP: OpponentHP.cloud(for: question))
    }

    func startBattle(opponent: Opponent, deck: [Question], level: MasteryLevel, dialogueRefs: DialogueRefs?, firstTime: Bool) {
        battlesLostBeforeBattle = save.battlesLost
        activeBattle = BattleRun(
            opponent: opponent, deck: deck, playerMaxHP: PlayerHP.maximum(for: level), missDamage: nil,
            playerSpriteID: "player-back", playerPlateName: "PILOT",
            introDialogue: script(dialogueRefs?.intro), winDialogue: script(dialogueRefs?.win),
            loseDialogue: script(dialogueRefs?.lose), firstTime: firstTime, returnTo: state.position)
    }

    func script(_ key: String?) -> DialogueScript {
        guard let key else { return DialogueScript(pages: []) }
        return content.dialogue[key] ?? DialogueScript(pages: [])
    }
}
