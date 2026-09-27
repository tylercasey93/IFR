import Foundation

public enum ItemEffect: Codable, Equatable, Sendable {
    case heal(Int)
    case reviveOnce
    case repel(steps: Int)
    case directTo

    private enum CodingKeys: String, CodingKey {
        case kind
        case amount
        case steps
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(String.self, forKey: .kind)
        switch kind {
        case "heal":
            self = .heal(try container.decode(Int.self, forKey: .amount))
        case "reviveOnce":
            self = .reviveOnce
        case "repel":
            self = .repel(steps: try container.decode(Int.self, forKey: .steps))
        case "directTo":
            self = .directTo
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .kind, in: container, debugDescription: "unknown item effect kind \(kind)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .heal(let amount):
            try container.encode("heal", forKey: .kind)
            try container.encode(amount, forKey: .amount)
        case .reviveOnce:
            try container.encode("reviveOnce", forKey: .kind)
        case .repel(let steps):
            try container.encode("repel", forKey: .kind)
            try container.encode(steps, forKey: .steps)
        case .directTo:
            try container.encode("directTo", forKey: .kind)
        }
    }
}

public struct Item: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let spriteID: String
    public let effect: ItemEffect
}
