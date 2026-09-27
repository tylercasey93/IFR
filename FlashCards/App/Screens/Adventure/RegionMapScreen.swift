import SwiftUI
import IFRCore

struct RegionMapScreen: View {
    @Environment(StudyStore.self) private var store
    @Environment(\.displayScale) private var displayScale
    let content: AdventureContent
    let startBattle: (BattleRun) -> Void

    @State private var dialogue: DialogueScript?
    @State private var challengeableGymID: GymID?
    @State private var showingEliteFour = false
    @State private var showingChampion = false
    @State private var showingBadgeCase = false
    @State private var showingHallOfFame = false

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
            ToolbarItem { Button("Badges") { showingBadgeCase = true }.accessibilityIdentifier("badgeCase") }
            ToolbarItem { Button("Hall of Fame") { showingHallOfFame = true }.accessibilityIdentifier("hallOfFame") }
        }
        .navigationDestination(isPresented: $showingEliteFour) { EliteFourScreen(content: content) }
        .navigationDestination(isPresented: $showingChampion) { ChampionScreen(content: content) }
        .navigationDestination(isPresented: $showingBadgeCase) { BadgeCaseScreen(content: content) }
        .navigationDestination(isPresented: $showingHallOfFame) { HallOfFameScreen() }
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
        switch airport.role {
        case .gym:
            tapGym(airport)
        case .eliteFour:
            tapEliteFour()
        case .champion:
            tapChampion()
        case .waypoint:
            break
        }
    }

    private func tapGym(_ airport: Airport) {
        guard let gymID = airport.gymID, let gym = content.gyms.first(where: { $0.id == gymID }) else { return }
        let result = GymApproach.approaching(gym, content: content, save: store.adventureSave)
        dialogue = result.dialogue
        challengeableGymID = result.challengeableGymID
    }

    private func tapEliteFour() {
        challengeableGymID = nil
        if let locked = GymApproach.eliteFourLockedDialogue(content: content, save: store.adventureSave) {
            dialogue = locked
        } else {
            showingEliteFour = true
        }
    }

    private func tapChampion() {
        challengeableGymID = nil
        if let locked = GymApproach.championLockedDialogue(content: content, save: store.adventureSave) {
            dialogue = locked
        } else {
            showingChampion = true
        }
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
