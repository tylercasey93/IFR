import Foundation

public enum OverworldTurn {
    public static func advancing(
        _ state: OverworldState, direction: Direction, save: AdventureSave, map: TileMap,
        trainers: [Trainer], rival: RivalSpec?, using rng: inout some RandomNumberGenerator
    ) -> (state: OverworldState, save: AdventureSave, outcome: OverworldOutcome) {
        let blocked = blockedPositions(trainers: trainers, defeated: save.defeatedTrainerIDs)
        let (stepped, event) = state.stepping(direction, in: map, blocked: blocked)
        guard stepped.position != state.position else {
            return (stepped, save, mapped(event))
        }
        return advancingMoved(from: state, stepped: stepped, event: event, save: save, map: map, trainers: trainers, rival: rival, using: &rng)
    }

    private static func advancingMoved(
        from previous: OverworldState, stepped: OverworldState, event: OverworldEvent, save: AdventureSave,
        map: TileMap, trainers: [Trainer], rival: RivalSpec?, using rng: inout some RandomNumberGenerator
    ) -> (state: OverworldState, save: AdventureSave, outcome: OverworldOutcome) {
        var nextSave = save
        let wasRepelled = nextSave.repelStepsLeft > 0
        nextSave.repelStepsLeft = max(0, nextSave.repelStepsLeft - 1)
        var nextState = stepped
        let tile = map[stepped.position] ?? .ground
        nextState.stepsSinceEncounter = pityCount(tile: tile, wasRepelled: wasRepelled, previous: previous.stepsSinceEncounter)

        if EncounterRoll.triggers(
            on: tile, repelStepsLeft: nextSave.repelStepsLeft, stepsSinceEncounter: nextState.stepsSinceEncounter, using: &rng
        ) {
            nextState.stepsSinceEncounter = 0
            nextState.pendingPath = []
            let category = map.category(at: stepped.position) ?? .humanFactors
            return (nextState, nextSave, .encounter(category: category))
        }
        if let rival, let index = RivalPlanner.pendingEncounter(at: nextState.position, spec: rival, save: nextSave) {
            nextState.pendingPath = []
            return (nextState, nextSave, .rival(encounterIndex: index))
        }
        if let trainer = sighting(state: &nextState, trainers: trainers, defeated: nextSave.defeatedTrainerIDs, in: map) {
            nextState.pendingPath = []
            return (nextState, nextSave, .sighted(trainer))
        }
        return resolved(event, state: nextState, save: nextSave)
    }

    private static func blockedPositions(trainers: [Trainer], defeated: Set<String>) -> Set<GridPoint> {
        Set(trainers.filter { !defeated.contains($0.id) }.map(\.position))
    }

    private static func pityCount(tile: TileKind, wasRepelled: Bool, previous: Int) -> Int {
        guard tile == .cloud else { return 0 }
        guard !wasRepelled else { return previous }
        return previous + 1
    }

    private static func sighting(
        state: inout OverworldState, trainers: [Trainer], defeated: Set<String>, in map: TileMap
    ) -> Trainer? {
        if let suppressedID = state.suppressedTrainerID,
           let suppressedTrainer = trainers.first(where: { $0.id == suppressedID }),
           LineOfSight.trainerSeeing(state.position, trainers: [suppressedTrainer], defeated: defeated, in: map) == nil {
            state.suppressedTrainerID = nil
        }
        let excluded = state.suppressedTrainerID.map { defeated.union([$0]) } ?? defeated
        return LineOfSight.trainerSeeing(state.position, trainers: trainers, defeated: excluded, in: map)
    }

    private static func resolved(
        _ event: OverworldEvent, state: OverworldState, save: AdventureSave
    ) -> (state: OverworldState, save: AdventureSave, outcome: OverworldOutcome) {
        guard case .pickup(let itemID) = event else {
            return (state, save, mapped(event))
        }
        guard !save.collectedItemIDs.contains(itemID) else {
            return (state, save, .none)
        }
        var updatedSave = save
        updatedSave.collectedItemIDs.insert(itemID)
        return (state, updatedSave, .pickup(itemID))
    }

    private static func mapped(_ event: OverworldEvent) -> OverworldOutcome {
        switch event {
        case .none: .none
        case .blocked: .blocked
        case .warp(let id): .warp(id)
        case .sign(let text): .sign(text)
        case .pickup(let id): .pickup(id)
        case .cloud: .none
        }
    }
}
