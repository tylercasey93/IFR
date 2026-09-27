import Foundation
import CoreGraphics
import IFRCore

extension OverworldScreenModel {
    func step(at date: Date) {
        guard let direction = nextDirection() else { return }
        let result = OverworldTurn.advancing(
            state, direction: direction, save: save, map: map,
            trainers: content.trainers, rival: content.rival, using: &rng)
        state = result.state
        save = result.save
        stepPhaseStart = date
        handle(result.outcome)
    }

    func nextDirection() -> Direction? {
        guard let next = state.pendingPath.first else { return nil }
        if next.x == state.position.x + 1 { return .right }
        if next.x == state.position.x - 1 { return .left }
        if next.y == state.position.y + 1 { return .down }
        if next.y == state.position.y - 1 { return .up }
        return nil
    }

    func blockedPositions() -> Set<GridPoint> {
        Set(content.trainers.filter { !save.defeatedTrainerIDs.contains($0.id) }.map(\.position))
    }

    func cameraOrigin() -> GridPoint {
        Camera.origin(following: state.position, mapWidth: map.width, mapHeight: map.height,
                      viewportWidth: OverworldRenderer.viewportWidth, viewportHeight: OverworldRenderer.viewportHeight)
    }

    static func tile(at point: CGPoint, viewSize: CGSize, displayScale: Double, cameraOrigin: GridPoint) -> GridPoint {
        let scale = IntegerScaler.scale(viewWidth: viewSize.width, viewHeight: viewSize.height, displayScale: displayScale)
        let cell = Double(OverworldRenderer.cellSize * scale) / displayScale
        let dx = Int((point.x / cell).rounded(.down))
        let dy = Int((point.y / cell).rounded(.down))
        return GridPoint(x: cameraOrigin.x + dx, y: cameraOrigin.y + dy)
    }

    func handle(_ outcome: OverworldOutcome) {
        switch outcome {
        case .encounter(let category): presentCloudBattle(category: category)
        case .warp(let airportID): approachAirport(airportID)
        default: persistIfPathComplete()
        }
    }

    func persistIfPathComplete() {
        guard state.pendingPath.isEmpty else { return }
        persist()
    }
}
