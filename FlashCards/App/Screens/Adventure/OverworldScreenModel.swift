import Foundation
import CoreGraphics
import IFRCore

@Observable
@MainActor
final class OverworldScreenModel {
    static let framesPerStep = 8

    var state: OverworldState
    var save: AdventureSave
    var dialogue: DialogueScript?
    var challengeableGymID: GymID?
    var activeBattle: BattleRun?
    var stepPhaseStart: Date

    let content: AdventureContent
    let map: TileMap
    let store: StudyStore
    let now: () -> Date
    var rng: SeededRNG
    var battlesLostBeforeBattle = 0

    init(
        content: AdventureContent, store: StudyStore, now: @escaping () -> Date = { Date() },
        makeRNG: @escaping () -> SeededRNG = { SeededRNG(seed: UInt64(Date().timeIntervalSince1970)) }
    ) {
        self.content = content
        self.store = store
        self.now = now
        map = content.tileMap ?? TileMap(width: 1, height: 1, rows: [[.ground]])
        rng = makeRNG()
        let startingSave = store.adventureSave
        save = startingSave
        state = OverworldState(position: startingSave.position ?? map.spawn, facing: startingSave.facing ?? .down)
        stepPhaseStart = now()
    }

    func frameIndex(at date: Date) -> Int {
        max(0, Int(date.timeIntervalSince(stepPhaseStart) * 60))
    }

    func tapped(at point: CGPoint, viewSize: CGSize, displayScale: Double) {
        let origin = cameraOrigin()
        let target = OverworldScreenModel.tile(at: point, viewSize: viewSize, displayScale: displayScale, cameraOrigin: origin)
        state = state.targeting(target, in: map, blocked: blockedPositions())
    }

    func advance(at date: Date) {
        guard activeBattle == nil, dialogue == nil, !state.pendingPath.isEmpty else { return }
        guard frameIndex(at: date) >= Self.framesPerStep else { return }
        step(at: date)
    }

    func dialogueFinished() {
        dialogue = nil
    }

    func challengeGym() {
        guard let gymID = challengeableGymID, let gym = gym(for: gymID),
              let airport = content.region.airports.first(where: { $0.gymID == gymID }) else { return }
        challengeableGymID = nil
        persist()
        presentGymBattle(gym: gym, gymID: gymID, airport: airport)
    }

    func clearActiveBattle() {
        activeBattle = nil
    }

    func battleDismissed() {
        activeBattle = nil
        save = store.adventureSave
        guard save.battlesLost > battlesLostBeforeBattle else { return }
        respawnAfterLoss()
    }

    func sceneDidEnterBackground() {
        persist()
    }

    func respawnAfterLoss() {
        let placement = Respawn.placement(save: save, map: map)
        state = OverworldState(position: placement.position, facing: placement.facing)
        persist()
    }

    func persist() {
        var updated = save
        updated.position = state.position
        updated.facing = state.facing
        save = updated
        store.updateAdventureSave(updated)
    }
}
