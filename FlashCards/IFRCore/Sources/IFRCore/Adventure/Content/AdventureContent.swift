import Foundation

public enum AdventureContentError: Error, Equatable, Sendable {
    case resourceMissing
    case duplicateID(String)
    case gymOrderMismatch
    case unknownReference(from: String, to: String)
    case emptyDialogue(String)
    case dialoguePageTooLong(String)
    case nameplateTooLong(String)
    case unknownSprite(String)
    case notEnoughQuestions(gymID: String)
    case offMap(String)
    case unknownTile(x: Int, y: Int)
    case raggedRows
    case unreachableDoor(airportID: String)
}

public struct AdventureContent: Codable, Sendable {
    public let version: Int
    public let region: RegionMap
    public let gyms: [Gym]
    public let eliteFour: [EliteMember]
    public let champion: ChampionSpec
    public let dialogue: [String: DialogueScript]
    public let system: [String: DialogueScript]
    public let items: [Item]
    public let tileMap: TileMap?
    public let trainers: [Trainer]
    public let rival: RivalSpec?
    public let companions: [CompanionSpecies]

    public init(
        version: Int, region: RegionMap, gyms: [Gym], eliteFour: [EliteMember], champion: ChampionSpec,
        dialogue: [String: DialogueScript], system: [String: DialogueScript], items: [Item],
        tileMap: TileMap? = nil, trainers: [Trainer] = [], rival: RivalSpec? = nil,
        companions: [CompanionSpecies] = []
    ) {
        self.version = version
        self.region = region
        self.gyms = gyms
        self.eliteFour = eliteFour
        self.champion = champion
        self.dialogue = dialogue
        self.system = system
        self.items = items
        self.tileMap = tileMap
        self.trainers = trainers
        self.rival = rival
        self.companions = companions
    }

    private enum CodingKeys: String, CodingKey {
        case version, region, gyms, eliteFour, champion, dialogue, system, items
        case tileMap, trainers, rival, companions
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        region = try container.decode(RegionMap.self, forKey: .region)
        gyms = try container.decode([Gym].self, forKey: .gyms)
        eliteFour = try container.decodeIfPresent([EliteMember].self, forKey: .eliteFour) ?? []
        champion = try container.decode(ChampionSpec.self, forKey: .champion)
        dialogue = try container.decodeIfPresent([String: DialogueScript].self, forKey: .dialogue) ?? [:]
        system = try container.decodeIfPresent([String: DialogueScript].self, forKey: .system) ?? [:]
        items = try container.decodeIfPresent([Item].self, forKey: .items) ?? []
        tileMap = try container.decodeIfPresent(TileMap.self, forKey: .tileMap)
        trainers = try container.decodeIfPresent([Trainer].self, forKey: .trainers) ?? []
        rival = try container.decodeIfPresent(RivalSpec.self, forKey: .rival)
        companions = try container.decodeIfPresent([CompanionSpecies].self, forKey: .companions) ?? []
    }

    public static func load() throws -> AdventureContent {
        guard let url = Bundle.module.url(forResource: "adventure-v1", withExtension: "json") else {
            throw AdventureContentError.resourceMissing
        }
        let content = try JSONDecoder().decode(AdventureContent.self, from: Data(contentsOf: url))
        try content.validate()
        return content
    }

    public func systemLine(_ key: SystemDialogueKey, filling values: [String: String] = [:]) -> DialogueScript {
        DialogueTemplate.filled(system[key.rawValue] ?? DialogueScript(pages: []), with: values)
    }

    func opponentNames() -> [String] {
        gyms.map(\.leaderName) + eliteFour.map(\.name) + [champion.name]
    }
}
