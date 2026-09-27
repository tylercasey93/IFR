import Foundation

public enum CompanionStage: Int, Codable, Equatable, Sendable {
    case hatchling = 1, journeyman, captain

    public static func stage(for level: MasteryLevel) -> CompanionStage {
        switch level.rawValue {
        case 1, 2: .hatchling
        case 3, 4: .journeyman
        default: .captain
        }
    }

    public static func evolved(from: CompanionStage, to: CompanionStage) -> Bool {
        to.rawValue > from.rawValue
    }
}
