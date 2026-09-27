import Foundation

public enum GymID: String, Codable, CaseIterable, Sendable {
    case humanFactors
    case instrumentsAndSystems
    case regulations
    case navigation
    case chartsAndPlanning
    case weather
    case emergencies
    case approaches

    public var category: Category {
        switch self {
        case .humanFactors: .humanFactors
        case .instrumentsAndSystems: .instrumentsAndSystems
        case .regulations: .regulations
        case .navigation: .navigation
        case .chartsAndPlanning: .chartsAndPlanning
        case .weather: .weather
        case .emergencies: .emergencies
        case .approaches: .approaches
        }
    }

    public var next: GymID? {
        neighbour(offset: 1)
    }

    public var previous: GymID? {
        neighbour(offset: -1)
    }

    private func neighbour(offset: Int) -> GymID? {
        let all = GymID.allCases
        guard let index = all.firstIndex(of: self) else { return nil }
        let target = index + offset
        guard all.indices.contains(target) else { return nil }
        return all[target]
    }
}
