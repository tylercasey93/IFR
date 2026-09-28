import Observation
import XCTest
import SwiftData
import IFRCore
@testable import IFRFlashCards

@MainActor
final class BattleScreenModelTests: XCTestCase {
    private func makeStore() throws -> StudyStore {
        let schema = Schema([CardStateRecord.self, ReviewRecord.self, XPRecord.self,
                             StreakRecord.self, BadgeRecord.self, SettingsRecord.self,
                             AdventureSaveRecord.self, BattleRecord.self])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return try StudyStore(context: ModelContext(container), bank: QuestionBank.load())
    }

    private func mcQuestion(_ id: String, difficulty: Int = 1) -> Question {
        let json = """
        {"id": "\(id)", "category": "humanFactors", "acsCodes": ["IR.I.A.K1"], "format": "multipleChoice",
         "front": "f", "back": "b", "options": ["a", "b", "c"], "correctIndex": 0, "explanation": "e",
         "source": {"document": "d", "section": "s", "url": "https://faa.gov"}, "figure": null,
         "difficulty": \(difficulty)}
        """
        return try! JSONDecoder().decode(Question.self, from: Data(json.utf8))
    }

    private func deck(_ count: Int) -> [Question] {
        (0..<count).map { mcQuestion("bq\($0)") }
    }

    private func opponent(maxHP: Int = 40) -> Opponent {
        Opponent(id: "hypoxia", name: "Dr. Hypoxia", nameplateName: "HYPOXIA", spriteID: "leader-hypoxia",
                 tier: .gym, maxHP: maxHP, gymID: "humanFactors", airportID: "KHYP")
    }

    private func run(deckCount: Int = 3, maxHP: Int = 40) -> BattleRun {
        BattleRun(opponent: opponent(maxHP: maxHP), deck: deck(deckCount), playerMaxHP: 100, missDamage: nil,
                 playerSpriteID: "player-back", playerPlateName: "PILOT",
                 introDialogue: DialogueScript(pages: ["Hi."]), winDialogue: DialogueScript(pages: ["Won."]),
                 loseDialogue: DialogueScript(pages: ["Lost."]), firstTime: true, returnTo: nil)
    }

    private func model(store: StudyStore, deckCount: Int = 3, maxHP: Int = 40,
                       now: Date = Date(timeIntervalSince1970: 1_800_000_000)) -> BattleScreenModel {
        BattleScreenModel(run: run(deckCount: deckCount, maxHP: maxHP), store: store, now: { now })
    }

    func testFrameIndexResetsOnPhaseChange() throws {
        let store = try makeStore()
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let m = model(store: store, now: base)
        m.advanceWipeIfComplete(at: base.addingTimeInterval(Double(BattleWipe.totalFrames) / 60))
        XCTAssertEqual(m.phase, .intro)
        XCTAssertEqual(m.frameIndex(at: base.addingTimeInterval(Double(BattleWipe.totalFrames) / 60)), 0)
    }

    func testPhaseTransitionsFollowTheTable() throws {
        let store = try makeStore()
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let m = model(store: store, deckCount: 1, now: base)
        XCTAssertEqual(m.phase, .wipe)
        let afterWipe = base.addingTimeInterval(Double(BattleWipe.totalFrames) / 60)
        m.advanceWipeIfComplete(at: afterWipe)
        XCTAssertEqual(m.phase, .intro)
        let afterIntro = afterWipe.addingTimeInterval(Double(BattleIntro.totalFrames) / 60)
        m.advanceIntroIfComplete(at: afterIntro)
        XCTAssertEqual(m.phase, .asking)
        m.stemDidFinishTyping()
        m.answer(selectedIndex: 0, at: afterIntro)
        XCTAssertEqual(m.phase, .resolving)
        while !m.pendingEvents.isEmpty {
            m.advanceResolving(at: afterIntro)
        }
        XCTAssertEqual(m.phase, .ended)
    }

    func testAnswerSecondsMeasuredFromOptionsBecomingTappable() throws {
        let store = try makeStore()
        let m = model(store: store, deckCount: 1)
        m.advanceWipeIfComplete(at: Date(timeIntervalSince1970: 1_800_000_001))
        m.advanceIntroIfComplete(at: Date(timeIntervalSince1970: 1_800_000_002))
        XCTAssertEqual(m.phase, .asking)
        m.stemDidFinishTyping()
        m.answer(selectedIndex: 0, at: Date(timeIntervalSince1970: 1_800_000_003))
        XCTAssertEqual(m.state.turns.count, 1)
    }

    func testAnswerCallsEngineThenStore() throws {
        let store = try makeStore()
        let m = model(store: store, deckCount: 1)
        m.advanceWipeIfComplete(at: Date(timeIntervalSince1970: 1_800_000_001))
        m.advanceIntroIfComplete(at: Date(timeIntervalSince1970: 1_800_000_002))
        m.stemDidFinishTyping()
        let xpBefore = store.totalXP
        m.answer(selectedIndex: 0, at: Date(timeIntervalSince1970: 1_800_000_003))
        XCTAssertTrue(store.totalXP > xpBefore)
        XCTAssertTrue(m.answerRevealed)
    }

    func testSourceButtonHidesAnswerUntilTurnAnswered() throws {
        let store = try makeStore()
        let m = model(store: store, deckCount: 1)
        XCTAssertFalse(m.answerRevealed)
        m.advanceWipeIfComplete(at: Date(timeIntervalSince1970: 1_800_000_001))
        m.advanceIntroIfComplete(at: Date(timeIntervalSince1970: 1_800_000_002))
        m.stemDidFinishTyping()
        m.answer(selectedIndex: 0, at: Date(timeIntervalSince1970: 1_800_000_003))
        XCTAssertTrue(m.answerRevealed)
    }

    private func runToEnded(_ m: BattleScreenModel, deckCount: Int, base: Date) {
        var now = base
        m.advanceWipeIfComplete(at: now)
        now = now.addingTimeInterval(Double(BattleWipe.totalFrames) / 60)
        m.advanceWipeIfComplete(at: now)
        m.advanceIntroIfComplete(at: now)
        now = now.addingTimeInterval(Double(BattleIntro.totalFrames) / 60)
        m.advanceIntroIfComplete(at: now)
        for _ in 0..<deckCount {
            m.stemDidFinishTyping()
            m.answer(selectedIndex: 0, at: now)
            while !m.pendingEvents.isEmpty {
                m.advanceResolving(at: now)
            }
        }
    }

    func testWinDialogueThenDismissCallsFinishBattle() throws {
        let store = try makeStore()
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let m = model(store: store, deckCount: 1, maxHP: 1, now: base)
        runToEnded(m, deckCount: 1, base: base)
        XCTAssertEqual(m.phase, .ended)
        XCTAssertEqual(m.state.outcome, .won)
        m.dismissEnded()
        XCTAssertEqual(m.finishBattleCallCount, 1)
        XCTAssertTrue(m.dismissed)
    }

    func testFinishBattleCalledExactlyOnceBeforeDismiss() throws {
        let store = try makeStore()
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let m = model(store: store, deckCount: 1, maxHP: 1, now: base)
        runToEnded(m, deckCount: 1, base: base)
        m.dismissEnded()
        m.dismissEnded()
        m.quit(at: base)
        XCTAssertEqual(m.finishBattleCallCount, 1)
    }

    func testQuitForfeitsThenFinishesBattle() throws {
        let store = try makeStore()
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let m = model(store: store, deckCount: 3, now: base)
        m.quit(at: base)
        XCTAssertEqual(m.phase, .ended)
        XCTAssertEqual(m.state.outcome, .lost)
        m.dismissEnded()
        XCTAssertEqual(m.finishBattleCallCount, 1)
    }

    func testSeedArgumentMakesDeckDeterministic() throws {
        let store = try makeStore()
        let a = BattleScreenModel(run: run(), store: store, makeRNG: { SeededRNG(seed: 7) })
        let b = BattleScreenModel(run: run(), store: store, makeRNG: { SeededRNG(seed: 7) })
        XCTAssertEqual(a.firstRandomValue(), b.firstRandomValue())
    }
}
