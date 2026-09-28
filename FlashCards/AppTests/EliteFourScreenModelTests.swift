import Observation
import XCTest
import SwiftData
import IFRCore
@testable import IFRFlashCards

@MainActor
final class EliteFourScreenModelTests: XCTestCase {
    private func makeStore() throws -> StudyStore {
        let schema = Schema([CardStateRecord.self, ReviewRecord.self, XPRecord.self,
                             StreakRecord.self, BadgeRecord.self, SettingsRecord.self,
                             AdventureSaveRecord.self, BattleRecord.self])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return try StudyStore(context: ModelContext(container), bank: QuestionBank.load())
    }

    private func eliteMember(_ id: String, order: Int, categories: [IFRCore.Category]) -> EliteMember {
        EliteMember(id: id, order: order, name: id, nameplateName: String(id.prefix(7)).uppercased(),
                   spriteID: id, categories: categories, questionCount: 12,
                   dialogue: DialogueRefs(intro: "\(id)-intro", win: "\(id)-win", lose: "\(id)-lose"))
    }

    private func fourMemberContent() -> AdventureContent {
        let members = [
            eliteMember("elite-sierra", order: 1, categories: [.regulations, .emergencies]),
            eliteMember("elite-tango", order: 2, categories: [.weather, .chartsAndPlanning]),
            eliteMember("elite-uniform", order: 3, categories: [.navigation, .instrumentsAndSystems]),
            eliteMember("elite-whiskey", order: 4, categories: [.approaches, .humanFactors]),
        ]
        let champion = ChampionSpec(name: "The DPE", nameplateName: "THE DPE", spriteID: "champion",
                                   dialogue: DialogueRefs(intro: "champion-intro", win: "champion-win",
                                                          lose: "champion-lose"))
        return AdventureContent(version: 1, region: RegionMap(airports: [], airways: []),
                                gyms: [], eliteFour: members, champion: champion,
                                dialogue: [:], system: [:], items: [])
    }

    private func winBattle(_ run: BattleRun) -> BattleState {
        var state = BattleEngine.start(opponent: run.opponent, deck: run.deck, playerMaxHP: run.playerMaxHP)
        while state.outcome == nil, let question = state.currentQuestion {
            (state, _) = BattleEngine.answer(state, selectedIndex: question.correctIndex!, answerSeconds: 10)
        }
        return state
    }

    func testEliteFourModelPresentsFourBattleRunsInOrder() throws {
        let store = try makeStore()
        let content = fourMemberContent()
        let model = EliteFourScreenModel(content: content, store: store)

        for (index, member) in content.eliteFour.enumerated() {
            model.challengeCurrentMember()
            let run = try XCTUnwrap(model.activeBattle)
            XCTAssertEqual(run.deck.count, member.questionCount)
            XCTAssertEqual(run.opponent.id, member.id)
            XCTAssertTrue(run.deck.allSatisfy { member.categories.contains($0.category) })

            let finished = winBattle(run)
            XCTAssertEqual(finished.outcome, .won)
            store.finishBattle(finished)
            model.battleDismissed()
            XCTAssertEqual(model.run.memberIndex, index + 1)
        }
        XCTAssertTrue(model.run.isCleared)
    }

    func testEliteFourLossRestartsAtMemberOne() throws {
        let store = try makeStore()
        let model = EliteFourScreenModel(content: fourMemberContent(), store: store)
        model.challengeCurrentMember()
        store.finishBattle(winBattle(try XCTUnwrap(model.activeBattle)))
        model.battleDismissed()
        XCTAssertEqual(model.run.memberIndex, 1)
        model.challengeCurrentMember()
        let second = try XCTUnwrap(model.activeBattle)
        let started = BattleEngine.start(opponent: second.opponent, deck: second.deck, playerMaxHP: second.playerMaxHP)
        store.finishBattle(BattleEngine.forfeit(started).state)
        model.battleDismissed()
        XCTAssertEqual(model.run.memberIndex, 0)
    }

    func testEliteFourScreenLeavingAbandonsRun() throws {
        let store = try makeStore()
        let content = fourMemberContent()
        let firstModel = EliteFourScreenModel(content: content, store: store)
        firstModel.challengeCurrentMember()
        let run = try XCTUnwrap(firstModel.activeBattle)
        let finished = winBattle(run)
        store.finishBattle(finished)
        firstModel.battleDismissed()
        XCTAssertEqual(firstModel.run.memberIndex, 1)

        let newModel = EliteFourScreenModel(content: content, store: store)
        XCTAssertEqual(newModel.run.memberIndex, 0)
    }
}
