import Foundation

extension AdventureContent {
    public func validate() throws {
        try checkUniqueIDs()
        try checkGymOrder()
        try checkReferences()
        try checkRegionConnectivity()
        try checkAirportPositions()
        try checkDialogueReferences()
        try checkDialoguePageLengths()
        try checkSystemDialogueKeys()
        try checkSystemDialogueSubstitution()
        try checkNameplateLengths()
        try checkEliteFourCoverage()
        try checkGymQuestionPools()
        try checkSpriteReferences()
    }

    private func checkUniqueIDs() throws {
        let ids = region.airports.map(\.id)
            + gyms.map(\.id.rawValue)
            + eliteFour.map(\.id)
            + items.map(\.id)
            + trainers.map(\.id)
        var seen = Set<String>()
        for id in ids {
            guard seen.insert(id).inserted else { throw AdventureContentError.duplicateID(id) }
        }
    }

    private func checkGymOrder() throws {
        let circuitIndices = gyms.map { GymID.allCases.firstIndex(of: $0.id) ?? -1 }
        guard circuitIndices == circuitIndices.sorted() else {
            throw AdventureContentError.gymOrderMismatch
        }
    }

    private func checkReferences() throws {
        let gymIDs = Set(gyms.map(\.id))
        let airportIDs = Set(region.airports.map(\.id))
        for airport in region.airports {
            if let gymID = airport.gymID, !gymIDs.contains(gymID) {
                throw AdventureContentError.unknownReference(from: airport.id, to: gymID.rawValue)
            }
        }
        for airway in region.airways {
            if !airportIDs.contains(airway.from) {
                throw AdventureContentError.unknownReference(from: airway.id, to: airway.from)
            }
            if !airportIDs.contains(airway.to) {
                throw AdventureContentError.unknownReference(from: airway.id, to: airway.to)
            }
        }
    }

    private func checkRegionConnectivity() throws {
        guard let firstGymID = gyms.first?.id,
              let start = region.airports.first(where: { $0.gymID == firstGymID })?.id
        else { return }
        var adjacency: [String: [String]] = [:]
        for airway in region.airways {
            adjacency[airway.from, default: []].append(airway.to)
            adjacency[airway.to, default: []].append(airway.from)
        }
        var reached: Set<String> = [start]
        var queue = [start]
        while let current = queue.first {
            queue.removeFirst()
            for neighbour in adjacency[current, default: []] where reached.insert(neighbour).inserted {
                queue.append(neighbour)
            }
        }
        for airport in region.airports where !reached.contains(airport.id) {
            throw AdventureContentError.unreachableDoor(airportID: airport.id)
        }
    }

    private func checkAirportPositions() throws {
        for airport in region.airports where airport.position.x >= 30 || airport.position.y >= 14 {
            throw AdventureContentError.offMap(airport.id)
        }
    }
}
