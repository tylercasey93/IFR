import Foundation
import IFRCore

@Observable
@MainActor
final class BattleScreenModel {
    private(set) var state: BattleState
    private(set) var phase: BattlePhase
    private(set) var phaseStart: Date
    private(set) var pendingEvents: [BattleEvent] = []
    private(set) var answerRevealed = false
    private(set) var finishBattleCallCount = 0
    private(set) var dismissed = false
    var showingBag = false

    let run: BattleRun
    private let store: StudyStore
    private let now: () -> Date
    private let continuousNow: () -> ContinuousClock.Instant
    private let makeRNG: () -> SeededRNG
    private var optionsTappableAt: ContinuousClock.Instant?

    init(
        run: BattleRun,
        store: StudyStore,
        now: @escaping () -> Date = { Date() },
        continuousNow: @escaping () -> ContinuousClock.Instant = { ContinuousClock.now },
        makeRNG: @escaping () -> SeededRNG = { SeededRNG(seed: UInt64(Date().timeIntervalSince1970)) }
    ) {
        self.run = run
        self.store = store
        self.now = now
        self.continuousNow = continuousNow
        self.makeRNG = makeRNG
        state = BattleEngine.start(opponent: run.opponent, deck: run.deck,
                                   playerMaxHP: run.playerMaxHP, missDamage: run.missDamage)
        phase = .wipe
        phaseStart = now()
    }

    func frameIndex(at date: Date) -> Int {
        max(0, Int((date.timeIntervalSince(phaseStart) * 60).rounded()))
    }

    func advanceWipeIfComplete(at date: Date) {
        guard phase == .wipe, frameIndex(at: date) >= BattleWipe.totalFrames else { return }
        transition(to: .intro, at: date)
    }

    func advanceIntroIfComplete(at date: Date) {
        guard phase == .intro, frameIndex(at: date) >= BattleIntro.totalFrames else { return }
        transition(to: .asking, at: date)
    }

    func stemDidFinishTyping() {
        guard phase == .asking, optionsTappableAt == nil else { return }
        optionsTappableAt = continuousNow()
    }

    func answer(selectedIndex: Int, at date: Date) {
        guard phase == .asking, let optionsTappableAt, let question = state.currentQuestion else { return }
        let seconds = self.seconds(from: optionsTappableAt, to: continuousNow())
        let (nextState, events) = BattleEngine.answer(state, selectedIndex: selectedIndex, answerSeconds: seconds)
        state = nextState
        store.submitAdventureAnswer(question, selectedIndex: selectedIndex)
        answerRevealed = true
        pendingEvents = events
        transition(to: .resolving, at: date)
    }

    func advanceResolving(at date: Date) {
        guard phase == .resolving, !pendingEvents.isEmpty else { return }
        let event = pendingEvents.removeFirst()
        guard pendingEvents.isEmpty else { return }
        switch event {
        case .questionPresented:
            answerRevealed = false
            optionsTappableAt = nil
            transition(to: .asking, at: date)
        case .opponentFainted, .playerFainted, .deckExhausted:
            transition(to: .ended, at: date)
        default:
            break
        }
    }

    func openBag() {
        showingBag = true
    }

    func useItem(_ item: Item) {
        showingBag = false
        state = BattleEngine.useItem(state, effect: item.effect)
        store.useInventoryItem(item.id)
    }

    func quit(at date: Date) {
        guard state.outcome == nil else { return }
        let (nextState, events) = BattleEngine.forfeit(state)
        state = nextState
        pendingEvents = events
        transition(to: .ended, at: date)
    }

    func dismissEnded() {
        guard phase == .ended, finishBattleCallCount == 0 else { return }
        store.finishBattle(state)
        finishBattleCallCount += 1
        dismissed = true
    }

    func firstRandomValue() -> UInt64 {
        var rng = makeRNG()
        return rng.next()
    }

    var currentDialogue: DialogueScript {
        BattleDialogue.current(
            outcome: state.outcome, intro: run.introDialogue, win: run.winDialogue, lose: run.loseDialogue)
    }

    private func transition(to newPhase: BattlePhase, at date: Date) {
        phase = newPhase
        phaseStart = date
    }

    private func seconds(from start: ContinuousClock.Instant, to end: ContinuousClock.Instant) -> Double {
        let duration = start.duration(to: end)
        let seconds = Double(duration.components.seconds)
        let attoseconds = Double(duration.components.attoseconds) / 1_000_000_000_000_000_000
        return seconds + attoseconds
    }
}
