import XCTest
@testable import IFRCore

final class BattleResolutionTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func mcQuestion(_ id: String, _ category: IFRCore.Category, difficulty: Int = 1) -> Question {
        Question(id: id, category: category, acsCodes: ["IR.I.A.K1"], format: .multipleChoice,
                 front: "f", back: "b", options: ["a", "b", "c"], correctIndex: 0, explanation: "e",
                 source: SourceRef(document: "d", section: "s", url: URL(string: "https://faa.gov")!),
                 figure: nil, difficulty: difficulty)
    }

    private func gym() -> Gym {
        Gym(id: .humanFactors, leaderName: "Dr. Hypoxia", nameplateName: "HYPOXIA",
            leaderSpriteID: "leader-hypoxia", badgeName: "Oxygen Badge", questionCount: 10,
            dialogue: DialogueRefs(intro: "hypoxia-intro", win: "hypoxia-win", lose: "hypoxia-lose"))
    }

    private func deck(_ count: Int) -> [Question] {
        (0..<count).map { mcQuestion("q\($0)", .humanFactors) }
    }

    func testGymOpponentCarriesGymIDAndAirport() {
        let opponent = gym().opponent(maxHP: 70, airportID: "KHYP")
        XCTAssertEqual(opponent.id, "humanFactors")
        XCTAssertEqual(opponent.gymID, "humanFactors")
        XCTAssertEqual(opponent.airportID, "KHYP")
        XCTAssertEqual(opponent.tier, .gym)
        XCTAssertEqual(opponent.maxHP, 70)
    }

    func testGymWinAddsBadgeQuestionIDsAndVisitedAirport() {
        let opponent = gym().opponent(maxHP: 70, airportID: "KHYP")
        let drawnDeck = deck(10)
        let result = BattleResolution.apply(.won, opponent: opponent, deck: drawnDeck, to: .new, at: now)
        XCTAssertEqual(result.badges, [.humanFactors])
        XCTAssertEqual(result.badgeQuestionIDs["humanFactors"], drawnDeck.map(\.id))
        XCTAssertEqual(result.visitedAirportIDs, ["KHYP"])
        XCTAssertEqual(result.battlesWon, 1)
    }

    func testRematchWinDoesNotDuplicateBadge() {
        let opponent = gym().opponent(maxHP: 70, airportID: "KHYP")
        let firstWin = BattleResolution.apply(.won, opponent: opponent, deck: deck(10), to: .new, at: now)
        let secondDeck = deck(10).map { Question(id: "r-\($0.id)", category: $0.category, acsCodes: $0.acsCodes,
                                                   format: $0.format, front: $0.front, back: $0.back, options: $0.options,
                                                   correctIndex: $0.correctIndex, explanation: $0.explanation,
                                                   source: $0.source, figure: $0.figure, difficulty: $0.difficulty) }
        let secondWin = BattleResolution.apply(.won, opponent: opponent, deck: secondDeck, to: firstWin, at: now)
        XCTAssertEqual(secondWin.badges, [.humanFactors])
        XCTAssertEqual(secondWin.badgeQuestionIDs["humanFactors"], secondDeck.map(\.id))
        XCTAssertEqual(secondWin.battlesWon, 2)
    }

    func testLossIncrementsBattlesLostOnly() {
        let opponent = gym().opponent(maxHP: 70, airportID: "KHYP")
        let result = BattleResolution.apply(.lost, opponent: opponent, deck: deck(10), to: .new, at: now)
        XCTAssertEqual(result.battlesLost, 1)
        XCTAssertEqual(result.battlesWon, 0)
        XCTAssertTrue(result.badges.isEmpty)
        XCTAssertTrue(result.visitedAirportIDs.isEmpty)
    }

    func testEliteWinCountsBattleWithoutClearing() {
        let opponent = Opponent(id: "elite-sierra", name: "Controller Sierra", nameplateName: "SIERRA",
                                 spriteID: "elite-sierra", tier: .eliteFour, maxHP: 84)
        let result = BattleResolution.apply(.won, opponent: opponent, deck: deck(12), to: .new, at: now)
        XCTAssertEqual(result.battlesWon, 1)
        XCTAssertFalse(result.eliteFourCleared)
        XCTAssertTrue(result.badges.isEmpty)
    }

    func testChampionWinAppendsHallOfFameDate() {
        let opponent = Opponent(id: "champion", name: "The DPE", nameplateName: "THE DPE",
                                 spriteID: "champion", tier: .champion, maxHP: 42)
        let result = BattleResolution.apply(.won, opponent: opponent, deck: deck(60), to: .new, at: now)
        XCTAssertEqual(result.hallOfFame, [now])
        XCTAssertEqual(result.championWins, 1)
    }
}
