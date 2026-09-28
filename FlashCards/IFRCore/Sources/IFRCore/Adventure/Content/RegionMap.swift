import Foundation

public enum AirportRole: String, Codable, Sendable {
    case gym
    case eliteFour
    case champion
    case waypoint
}

public struct Airport: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let position: GridPoint
    public let gymID: GymID?
    public let role: AirportRole

    public init(id: String, name: String, position: GridPoint, gymID: GymID?, role: AirportRole) {
        self.id = id
        self.name = name
        self.position = position
        self.gymID = gymID
        self.role = role
    }
}

public struct Airway: Codable, Equatable, Sendable {
    public let id: String
    public let from: String
    public let to: String

    public init(id: String, from: String, to: String) {
        self.id = id
        self.from = from
        self.to = to
    }
}

public struct RegionMap: Codable, Equatable, Sendable {
    public let airports: [Airport]
    public let airways: [Airway]

    public init(airports: [Airport], airways: [Airway]) {
        self.airports = airports
        self.airways = airways
    }
}
