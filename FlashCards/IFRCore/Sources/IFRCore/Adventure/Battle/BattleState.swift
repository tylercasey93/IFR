import Foundation

extension Hit: Codable {
    private enum CodingKeys: String, CodingKey {
        case amount, isCritical, isSuperEffective
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            amount: try container.decode(Int.self, forKey: .amount),
            isCritical: try container.decode(Bool.self, forKey: .isCritical),
            isSuperEffective: try container.decode(Bool.self, forKey: .isSuperEffective)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(amount, forKey: .amount)
        try container.encode(isCritical, forKey: .isCritical)
        try container.encode(isSuperEffective, forKey: .isSuperEffective)
    }
}

public struct BattleTurnResult: Equatable, Codable, Sendable {
    public let questionID: String
    public let selectedIndex: Int
    public let isCorrect: Bool
    public let grade: Grade
    public let hit: Hit?
    public let damageToPlayer: Int

    public init(
        questionID: String, selectedIndex: Int, isCorrect: Bool,
        grade: Grade, hit: Hit?, damageToPlayer: Int
    ) {
        self.questionID = questionID
        self.selectedIndex = selectedIndex
        self.isCorrect = isCorrect
        self.grade = grade
        self.hit = hit
        self.damageToPlayer = damageToPlayer
    }
}

public enum BattleOutcome: Equatable, Codable, Sendable {
    case won, lost
}

public enum BattleEvent: Equatable, Sendable {
    case questionPresented(Question)
    case opponentHit(Hit, damage: Int)
    case playerHurt(Int)
    case explanation(String)
    case revived(Int)
    case opponentFainted
    case playerFainted
    case deckExhausted
}

public struct BattleState: Equatable, Codable, Sendable {
    public var opponent: Opponent
    public var deck: [Question]
    public var cursor: Int
    public var playerHP: Int
    public var playerMaxHP: Int
    public var opponentHP: Int
    public var missDamage: Int
    public var reviveArmed: Bool
    public var results: [Bool]
    public var turns: [BattleTurnResult]
    public var outcome: BattleOutcome?

    public var currentQuestion: Question? {
        deck.indices.contains(cursor) ? deck[cursor] : nil
    }

    public init(
        opponent: Opponent, deck: [Question], cursor: Int, playerHP: Int, playerMaxHP: Int,
        opponentHP: Int, missDamage: Int, reviveArmed: Bool, results: [Bool],
        turns: [BattleTurnResult], outcome: BattleOutcome?
    ) {
        self.opponent = opponent
        self.deck = deck
        self.cursor = cursor
        self.playerHP = playerHP
        self.playerMaxHP = playerMaxHP
        self.opponentHP = opponentHP
        self.missDamage = missDamage
        self.reviveArmed = reviveArmed
        self.results = results
        self.turns = turns
        self.outcome = outcome
    }
}
