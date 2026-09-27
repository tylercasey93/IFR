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
    public var collectedItemIDs: Set<String>
    public var inventory: [String: Int]
    public var repelStepsLeft: Int
    public var position: GridPoint?
    public var facing: Direction?
    public var rivalEncountersDone: Set<Int>
    public var seenCompanionStages: [String: Int]
    public var bestTowerFloor: Int
    public var lastRematchNotice: Date?

    public static let new = AdventureSave(
        saveVersion: currentVersion, badges: [], badgeQuestionIDs: [:], eliteFourCleared: false,
        championWins: 0, hallOfFame: [], battlesWon: 0, battlesLost: 0, visitedAirportIDs: [],
        defeatedTrainerIDs: [], collectedItemIDs: [], inventory: [:], repelStepsLeft: 0, position: nil,
        facing: nil, rivalEncountersDone: []
    )

    public init(
        saveVersion: Int, badges: Set<GymID>, badgeQuestionIDs: [String: [String]], eliteFourCleared: Bool,
        championWins: Int, hallOfFame: [Date], battlesWon: Int, battlesLost: Int, visitedAirportIDs: Set<String>,
        defeatedTrainerIDs: Set<String> = [], collectedItemIDs: Set<String> = [], inventory: [String: Int] = [:],
        repelStepsLeft: Int = 0, position: GridPoint? = nil, facing: Direction? = nil, rivalEncountersDone: Set<Int> = [],
        seenCompanionStages: [String: Int] = [:], bestTowerFloor: Int = 0, lastRematchNotice: Date? = nil
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
        self.collectedItemIDs = collectedItemIDs
        self.inventory = inventory
        self.repelStepsLeft = repelStepsLeft
        self.position = position
        self.facing = facing
        self.rivalEncountersDone = rivalEncountersDone
        self.seenCompanionStages = seenCompanionStages
        self.bestTowerFloor = bestTowerFloor
        self.lastRematchNotice = lastRematchNotice
    }

    private enum CodingKeys: String, CodingKey {
        case saveVersion, badges, badgeQuestionIDs, eliteFourCleared, championWins,
             hallOfFame, battlesWon, battlesLost, visitedAirportIDs, defeatedTrainerIDs,
             collectedItemIDs, inventory, repelStepsLeft, position, facing, rivalEncountersDone,
             seenCompanionStages, bestTowerFloor, lastRematchNotice
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
        self.collectedItemIDs = try container.decodeIfPresent(Set<String>.self, forKey: .collectedItemIDs) ?? []
        self.inventory = try container.decodeIfPresent([String: Int].self, forKey: .inventory) ?? [:]
        self.repelStepsLeft = try container.decodeIfPresent(Int.self, forKey: .repelStepsLeft) ?? 0
        self.position = try container.decodeIfPresent(GridPoint.self, forKey: .position)
        self.facing = try container.decodeIfPresent(Direction.self, forKey: .facing)
        self.rivalEncountersDone = try container.decodeIfPresent(Set<Int>.self, forKey: .rivalEncountersDone) ?? []
        self.seenCompanionStages = try container.decodeIfPresent([String: Int].self, forKey: .seenCompanionStages) ?? [:]
        self.bestTowerFloor = try container.decodeIfPresent(Int.self, forKey: .bestTowerFloor) ?? 0
        self.lastRematchNotice = try container.decodeIfPresent(Date.self, forKey: .lastRematchNotice)
    }
}
