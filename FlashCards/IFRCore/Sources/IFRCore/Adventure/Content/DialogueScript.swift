import Foundation

public struct DialogueScript: Codable, Equatable, Sendable {
    public let pages: [String]
}

public enum SystemDialogueKey: String, CaseIterable, Sendable {
    case welcome
    case gymLocked
    case victory
    case whiteout
    case retreat
    case championPinned
    case superEffective
    case criticalHit
    case revived
}
