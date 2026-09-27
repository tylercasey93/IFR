import SwiftUI
import IFRCore

struct RegionMapScreen: View {
    @Environment(StudyStore.self) private var store
    @Environment(\.displayScale) private var displayScale
    let content: AdventureContent
    let startBattle: (BattleRun) -> Void

    @State private var dialogue: DialogueScript?
    @State private var challengeableGymID: GymID?

    var body: some View {
        GeometryReader { geometry in
            let scale = IntegerScaler.scale(
                viewWidth: geometry.size.width, viewHeight: geometry.size.height, displayScale: displayScale)
            ZStack {
                GBAScreen(frame: mapFrame)
                ForEach(content.region.airports, id: \.id) { airport in
                    airportButton(airport, scale: scale)
                }
                if let dialogue {
                    DialogueBoxView(script: dialogue, scale: scale, displayScale: displayScale,
                                    onFinished: { self.dialogue = nil })
                }
                if let challengeableGymID {
                    challengeButton(challengeableGymID)
                }
            }
        }
        .accessibilityIdentifier("regionMap")
        .toolbar {
            ToolbarItem { Button("Badges") {}.accessibilityIdentifier("badgeCase") }
            ToolbarItem { Button("Hall of Fame") {}.accessibilityIdentifier("hallOfFame") }
        }
    }

    private var mapFrame: PixelFrame {
        RegionMapRenderer.frame(region: content.region, save: store.adventureSave, nextGym: nextGym, selected: nil)
    }

    private var nextGym: GymID? {
        GymID.allCases.first { !store.adventureSave.badges.contains($0) }
    }

    private func airportButton(_ airport: Airport, scale: Int) -> some View {
        let side = CGFloat(RegionMapRenderer.cellSize * scale) / displayScale
        let originX = CGFloat(airport.position.x * RegionMapRenderer.cellSize * scale) / displayScale
        let originY = CGFloat(airport.position.y * RegionMapRenderer.cellSize * scale) / displayScale
        return Color.clear
            .frame(width: side, height: side)
            .contentShape(Rectangle())
            .position(x: originX + side / 2, y: originY + side / 2)
            .onTapGesture { tap(airport) }
            .accessibilityIdentifier("airport-\(airport.id)")
    }

    private func challengeButton(_ gymID: GymID) -> some View {
        Button("Challenge") { startGymBattle(gymID) }
            .accessibilityIdentifier("gym-\(gymID.rawValue)")
    }

    private func tap(_ airport: Airport) {
        guard airport.role == .gym, let gymID = airport.gymID,
              let gym = content.gyms.first(where: { $0.id == gymID }) else { return }
        if CircuitRules.isUnlocked(gymID, save: store.adventureSave) {
            dialogue = content.dialogue[gym.dialogue.intro]
            challengeableGymID = gymID
        } else {
            dialogue = content.systemLine(.gymLocked, filling: ["badge": previousBadgeName(before: gymID)])
            challengeableGymID = nil
        }
    }

    private func previousBadgeName(before gymID: GymID) -> String {
        guard let previous = gymID.previous, let previousGym = content.gyms.first(where: { $0.id == previous })
        else { return "" }
        return previousGym.badgeName
    }

    private func startGymBattle(_ gymID: GymID) {
        guard let airport = content.region.airports.first(where: { $0.gymID == gymID }),
              let gym = content.gyms.first(where: { $0.id == gymID }) else { return }
        let deck = store.drawEncounterDeck(count: gym.questionCount, categories: [gymID.category])
        let opponent = gym.opponent(maxHP: OpponentHP.tuned(for: deck), airportID: airport.id)
        let level = store.adventureMastery(for: gymID.category).level
        let run = BattleRun(
            opponent: opponent, deck: deck, playerMaxHP: PlayerHP.maximum(for: level), missDamage: nil,
            playerSpriteID: "player-back", playerPlateName: "PILOT",
            introDialogue: content.dialogue[gym.dialogue.intro] ?? DialogueScript(pages: []),
            winDialogue: content.dialogue[gym.dialogue.win] ?? DialogueScript(pages: []),
            loseDialogue: content.dialogue[gym.dialogue.lose] ?? DialogueScript(pages: []),
            firstTime: !store.adventureSave.badges.contains(gymID), returnTo: nil)
        challengeableGymID = nil
        startBattle(run)
    }
}
