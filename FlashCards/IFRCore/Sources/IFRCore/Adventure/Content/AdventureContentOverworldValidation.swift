import Foundation

extension AdventureContent {
    func checkDoorsHaveWarps() throws {
        guard let tileMap else { return }
        for point in doorPoints(in: tileMap) where tileMap.doorAirportIDs[point] == nil {
            throw AdventureContentError.unknownReference(from: "tileMap", to: "\(point.x)-\(point.y)")
        }
        for (point, airportID) in tileMap.doorAirportIDs where tileMap[point] != .door {
            throw AdventureContentError.unknownReference(from: "tileMap", to: airportID)
        }
    }

    private func doorPoints(in tileMap: TileMap) -> [GridPoint] {
        (0..<tileMap.height).flatMap { y in
            (0..<tileMap.width).compactMap { x in
                tileMap.rows[y][x] == .door ? GridPoint(x: x, y: y) : nil
            }
        }
    }

    func checkEveryAirportHasExactlyOneDoor() throws {
        guard let tileMap else { return }
        var doorCounts: [String: Int] = [:]
        for airportID in tileMap.doorAirportIDs.values {
            doorCounts[airportID, default: 0] += 1
        }
        for airport in region.airports where airport.role != .waypoint {
            guard doorCounts[airport.id] == 1 else {
                throw AdventureContentError.unreachableDoor(airportID: airport.id)
            }
        }
    }

    func checkSpawnIsWalkable() throws {
        guard let tileMap else { return }
        try assertWalkable(tileMap.spawn, in: tileMap)
    }

    func checkEveryDoorReachableFromSpawn() throws {
        guard let tileMap else { return }
        for (point, airportID) in tileMap.doorAirportIDs {
            guard Pathfinder.path(from: tileMap.spawn, to: point, in: tileMap, blocked: []) != nil else {
                throw AdventureContentError.unreachableDoor(airportID: airportID)
            }
        }
    }

    func checkTrainersStandOnWalkableTilesFacingWalkableLine() throws {
        guard let tileMap else { return }
        for trainer in trainers {
            try assertWalkable(trainer.position, in: tileMap)
            try assertTrainerLineWalkable(trainer, in: tileMap)
        }
    }

    private func assertTrainerLineWalkable(_ trainer: Trainer, in tileMap: TileMap) throws {
        var point = trainer.position
        for _ in 1...trainer.range {
            point = GridPoint(x: point.x + trainer.facing.delta.x, y: point.y + trainer.facing.delta.y)
            try assertWalkable(point, in: tileMap)
        }
    }

    func checkItemDropsAndSignsAreWalkable() throws {
        guard let tileMap else { return }
        for point in tileMap.itemDropItemIDs.keys { try assertWalkable(point, in: tileMap) }
        for point in tileMap.signTexts.keys { try assertWalkable(point, in: tileMap) }
    }

    func checkEveryCloudTileLiesInExactlyOneArea() throws {
        guard let tileMap else { return }
        for y in 0..<tileMap.height {
            for x in 0..<tileMap.width where tileMap.rows[y][x] == .cloud {
                try assertCloudCoveredOnce(GridPoint(x: x, y: y), in: tileMap)
            }
        }
    }

    private func assertCloudCoveredOnce(_ point: GridPoint, in tileMap: TileMap) throws {
        let matches = tileMap.areas.filter { $0.rect.contains(point) }.count
        guard matches == 1 else {
            throw AdventureContentError.unknownReference(from: "cloud", to: "\(point.x)-\(point.y)")
        }
    }

    func checkRivalEncountersAreWalkable() throws {
        guard let tileMap, let rival else { return }
        for encounter in rival.encounters {
            try assertWalkable(encounter.at, in: tileMap)
        }
    }

    private func assertWalkable(_ point: GridPoint, in tileMap: TileMap) throws {
        guard tileMap[point]?.isWalkable == true else {
            throw AdventureContentError.unknownTile(x: point.x, y: point.y)
        }
    }
}
