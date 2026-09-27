import Foundation

public struct GridPoint: Hashable, Codable, Sendable {
    public let x: Int
    public let y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
}

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
