import Foundation

public enum BattleResolution {
    public static func apply(
        _ outcome: BattleOutcome, opponent: Opponent, deck: [Question], to save: AdventureSave, at date: Date
    ) -> AdventureSave {
        var next = save
        guard outcome == .won else {
            next.battlesLost += 1
            return next
        }
        next.battlesWon += 1
        switch opponent.tier {
        case .gym:
            recordGymWin(&next, opponent: opponent, deck: deck)
        case .champion:
            next.hallOfFame.append(date)
            next.championWins += 1
        default:
            break
        }
        return next
    }

    private static func recordGymWin(_ save: inout AdventureSave, opponent: Opponent, deck: [Question]) {
        guard let gymID = opponent.gymID.flatMap(GymID.init(rawValue:)) else { return }
        save.badges.insert(gymID)
        save.badgeQuestionIDs[gymID.rawValue] = deck.map(\.id)
        if let airportID = opponent.airportID {
            save.visitedAirportIDs.insert(airportID)
        }
    }
}
