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
}

public struct Airway: Codable, Equatable, Sendable {
    public let id: String
    public let from: String
    public let to: String
}

public struct RegionMap: Codable, Equatable, Sendable {
    public let airports: [Airport]
    public let airways: [Airway]
}
