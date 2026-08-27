import Foundation

public enum Category: String, Codable, CaseIterable, Sendable, Hashable {
    case regulations, weather, chartsAndPlanning, navigation
    case instrumentsAndSystems, approaches, emergencies, humanFactors

    public var displayName: String {
        switch self {
        case .regulations: "Regulations & Procedures"
        case .weather: "Weather & Weather Services"
        case .chartsAndPlanning: "En Route Charts & Flight Planning"
        case .navigation: "Navigation & Avionics"
        case .instrumentsAndSystems: "Flight Instruments & Systems"
        case .approaches: "Instrument Approaches"
        case .emergencies: "Emergencies, Lost Comms & ATC"
        case .humanFactors: "Human Factors & Aeromedical"
        }
    }

    /// Relative prominence on the real exam. Drives new-card priority and
    /// quiz weighting, and doubles as the mock-exam per-category count (sums to 60).
    public var examWeight: Int {
        switch self {
        case .regulations: 12
        case .weather: 12
        case .chartsAndPlanning: 8
        case .navigation: 7
        case .instrumentsAndSystems: 7
        case .approaches: 8
        case .emergencies: 4
        case .humanFactors: 2
        }
    }
}

public enum QuestionFormat: String, Codable, Sendable {
    case flashcard, multipleChoice, both
}

public struct SourceRef: Codable, Equatable, Sendable {
    public let document: String
    public let section: String
    public let url: URL

    public init(document: String, section: String, url: URL) {
        self.document = document
        self.section = section
        self.url = url
    }
}

public struct Question: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let category: Category
    public let acsCodes: [String]
    public let format: QuestionFormat
    public let front: String
    public let back: String
    public let options: [String]?
    public let correctIndex: Int?
    public let explanation: String
    public let source: SourceRef
    public let figure: String?
    public let difficulty: Int

    public var isMultipleChoiceCapable: Bool { format != .flashcard }
}
