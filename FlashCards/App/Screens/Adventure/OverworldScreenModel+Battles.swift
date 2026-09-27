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

    func presentTrainerBattle(_ trainer: Trainer) {
        let deck = store.drawEncounterDeck(count: trainer.questionCount, categories: trainer.categories)
        let opponent = Opponent(id: trainer.id, name: trainer.name, nameplateName: trainer.nameplateName,
                                spriteID: trainer.spriteID, tier: .trainer, maxHP: OpponentHP.tuned(for: deck))
        pendingTrainerID = trainer.id
        persist()
        startBattle(opponent: opponent, deck: deck, level: mixedLevel(), dialogueRefs: trainer.dialogue, firstTime: false)
    }

    func presentRivalBattle(encounterIndex: Int) {
        guard let rival = content.rival, rival.encounters.indices.contains(encounterIndex) else { return }
        let categories = RivalPlanner.weakestCategories(count: 3, retention: store.retentionByCategory())
        let deck = store.drawEncounterDeck(count: rival.questionCount, categories: categories)
        let opponent = rival.opponent(maxHP: OpponentHP.tuned(for: deck))
        pendingRivalIndex = encounterIndex
        persist()
        startBattle(opponent: opponent, deck: deck, level: mixedLevel(),
                   dialogueRefs: rival.encounters[encounterIndex].dialogue, firstTime: false)
    }

    func mixedLevel() -> MasteryLevel {
        let retentions = store.reviewedRetentionByCategory().values
        let mean = retentions.isEmpty ? 0 : retentions.reduce(0, +) / Double(retentions.count)
        return MasteryLevel.level(forRetention: mean)
    }

    func approachAirport(_ airportID: String) {
        persistIfPathComplete()
        guard let airport = content.region.airports.first(where: { $0.id == airportID }) else { return }
        switch airport.role {
        case .gym: approachGymDoor(airport)
        case .eliteFour: approachEliteFourDoor()
        case .champion: approachChampionDoor()
        case .waypoint: break
        }
    }

    func approachGymDoor(_ airport: Airport) {
        guard let gymID = airport.gymID, let gym = gym(for: gymID) else { return }
        let result = GymApproach.approaching(gym, content: content, save: save)
        dialogue = result.dialogue
        challengeableGymID = result.challengeableGymID
        guard result.challengeableGymID == nil else { return }
        stepBackFromDoor()
    }

    func approachEliteFourDoor() {
        if let locked = GymApproach.eliteFourLockedDialogue(content: content, save: save) {
            dialogue = locked
            stepBackFromDoor()
        } else {
            showingEliteFour = true
        }
    }

    func approachChampionDoor() {
        if let locked = GymApproach.championLockedDialogue(content: content, save: save) {
            dialogue = locked
            stepBackFromDoor()
        } else {
            showingChampion = true
        }
    }

    func stepBackFromDoor() {
        guard let lastDirection else { return }
        let back = GridPoint(x: state.position.x - lastDirection.delta.x, y: state.position.y - lastDirection.delta.y)
        state = OverworldState(position: back, facing: .down)
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
            loseDialogue: script(dialogueRefs?.lose), firstTime: firstTime, returnTo: state.position,
            items: content.items)
    }

    func script(_ key: String?) -> DialogueScript {
        guard let key else { return DialogueScript(pages: []) }
        return content.dialogue[key] ?? DialogueScript(pages: [])
    }
}
