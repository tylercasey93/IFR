import Foundation

public enum OverworldOutcome: Equatable, Sendable {
    case none
    case blocked
    case warp(String)
    case sign(String)
    case pickup(String)
    case encounter(category: Category)
    case sighted(Trainer)
    case rival(encounterIndex: Int)
}
