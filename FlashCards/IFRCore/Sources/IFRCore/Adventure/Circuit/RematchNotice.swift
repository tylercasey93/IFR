import Foundation

public struct RematchNotice: Equatable, Sendable {
    public let gym: GymID
    public let leaderName: String
    public let badgeName: String
    public let airportID: String

    public init(gym: GymID, leaderName: String, badgeName: String, airportID: String) {
        self.gym = gym
        self.leaderName = leaderName
        self.badgeName = badgeName
        self.airportID = airportID
    }

    public static func notice(for gym: GymID, content: AdventureContent) -> RematchNotice? {
        guard let gymSpec = content.gyms.first(where: { $0.id == gym }) else { return nil }
        guard let airport = content.region.airports.first(where: { $0.gymID == gym }) else { return nil }
        return RematchNotice(gym: gym, leaderName: gymSpec.leaderName, badgeName: gymSpec.badgeName, airportID: airport.id)
    }
}
