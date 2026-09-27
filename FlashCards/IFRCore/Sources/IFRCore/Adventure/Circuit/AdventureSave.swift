import Foundation

public struct AdventureSave: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public var saveVersion: Int
    public var badges: Set<GymID>
    public var badgeQuestionIDs: [String: [String]]
    public var eliteFourCleared: Bool
    public var championWins: Int
    public var hallOfFame: [Date]
    public var battlesWon: Int
    public var battlesLost: Int
    public var visitedAirportIDs: Set<String>
    public var defeatedTrainerIDs: Set<String>

    public static let new = AdventureSave(
        saveVersion: currentVersion, badges: [], badgeQuestionIDs: [:], eliteFourCleared: false,
        championWins: 0, hallOfFame: [], battlesWon: 0, battlesLost: 0, visitedAirportIDs: [],
        defeatedTrainerIDs: []
    )

    public init(
        saveVersion: Int, badges: Set<GymID>, badgeQuestionIDs: [String: [String]], eliteFourCleared: Bool,
        championWins: Int, hallOfFame: [Date], battlesWon: Int, battlesLost: Int, visitedAirportIDs: Set<String>,
        defeatedTrainerIDs: Set<String> = []
    ) {
        self.saveVersion = saveVersion
        self.badges = badges
        self.badgeQuestionIDs = badgeQuestionIDs
        self.eliteFourCleared = eliteFourCleared
        self.championWins = championWins
        self.hallOfFame = hallOfFame
        self.battlesWon = battlesWon
        self.battlesLost = battlesLost
        self.visitedAirportIDs = visitedAirportIDs
        self.defeatedTrainerIDs = defeatedTrainerIDs
    }

    private enum CodingKeys: String, CodingKey {
        case saveVersion, badges, badgeQuestionIDs, eliteFourCleared, championWins,
             hallOfFame, battlesWon, battlesLost, visitedAirportIDs, defeatedTrainerIDs
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let saveVersion = try container.decodeIfPresent(Int.self, forKey: .saveVersion) ?? Self.currentVersion
        guard saveVersion <= Self.currentVersion else {
            throw AdventureSaveError.newerThanApp(saveVersion)
        }
        self.saveVersion = saveVersion
        self.badges = try container.decodeIfPresent(Set<GymID>.self, forKey: .badges) ?? []
        self.badgeQuestionIDs = try container.decodeIfPresent([String: [String]].self, forKey: .badgeQuestionIDs) ?? [:]
        self.eliteFourCleared = try container.decodeIfPresent(Bool.self, forKey: .eliteFourCleared) ?? false
        self.championWins = try container.decodeIfPresent(Int.self, forKey: .championWins) ?? 0
        self.hallOfFame = try container.decodeIfPresent([Date].self, forKey: .hallOfFame) ?? []
        self.battlesWon = try container.decodeIfPresent(Int.self, forKey: .battlesWon) ?? 0
        self.battlesLost = try container.decodeIfPresent(Int.self, forKey: .battlesLost) ?? 0
        self.visitedAirportIDs = try container.decodeIfPresent(Set<String>.self, forKey: .visitedAirportIDs) ?? []
        self.defeatedTrainerIDs = try container.decodeIfPresent(Set<String>.self, forKey: .defeatedTrainerIDs) ?? []
    }
}
