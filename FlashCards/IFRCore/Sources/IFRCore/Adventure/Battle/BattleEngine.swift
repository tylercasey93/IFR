import Foundation

public enum BattleEngine {
    public static func start(
        opponent: Opponent, deck: [Question], playerMaxHP: Int, missDamage: Int? = nil
    ) -> BattleState {
        BattleState(
            opponent: opponent, deck: deck, cursor: 0, playerHP: playerMaxHP, playerMaxHP: playerMaxHP,
            opponentHP: opponent.maxHP, missDamage: missDamage ?? opponent.tier.missDamage,
            reviveArmed: false, results: [], turns: [], outcome: nil
        )
    }

    public static func answer(
        _ state: BattleState, selectedIndex: Int, answerSeconds: Double
    ) -> (state: BattleState, events: [BattleEvent]) {
        guard state.outcome == nil, let question = state.currentQuestion else { return (state, []) }
        let isCorrect = selectedIndex == question.correctIndex
        var next = state
        next.results.append(isCorrect)
        let events = isCorrect
            ? correctTurn(&next, question: question, selectedIndex: selectedIndex, answerSeconds: answerSeconds)
            : wrongTurn(&next, question: question, selectedIndex: selectedIndex)
        return (next, events)
    }

    public static func useItem(_ state: BattleState, effect: ItemEffect) -> BattleState {
        switch effect {
        case .heal(let amount):
            var next = state
            next.playerHP = min(next.playerMaxHP, next.playerHP + amount)
            return next
        case .reviveOnce:
            var next = state
            next.reviveArmed = true
            return next
        case .repel, .directTo:
            return state
        }
    }

    public static func forfeit(_ state: BattleState) -> (state: BattleState, events: [BattleEvent]) {
        guard state.outcome == nil else { return (state, []) }
        var next = state
        next.outcome = .lost
        return (next, [.playerFainted])
    }

    private static func correctTurn(
        _ state: inout BattleState, question: Question, selectedIndex: Int, answerSeconds: Double
    ) -> [BattleEvent] {
        let hit = Damage.hit(difficulty: question.difficulty, answerSeconds: answerSeconds)
        let damage = min(state.opponent.tier.damage(for: hit), state.opponentHP)
        state.opponentHP -= damage
        recordTurn(&state, question: question, selectedIndex: selectedIndex, isCorrect: true, hit: hit, damageToPlayer: 0)
        state.cursor += 1
        if state.opponent.tier.runsEveryQuestion { return [.opponentHit(hit, damage: damage)] + championClose(&state) }
        if state.opponentHP <= 0 {
            state.outcome = .won
            return [.opponentHit(hit, damage: damage), .opponentFainted]
        }
        return [.opponentHit(hit, damage: damage)] + advanceOrExhaust(&state)
    }

    private static func wrongTurn(
        _ state: inout BattleState, question: Question, selectedIndex: Int
    ) -> [BattleEvent] {
        let damage = min(state.missDamage, state.playerHP)
        state.playerHP -= damage
        recordTurn(&state, question: question, selectedIndex: selectedIndex, isCorrect: false, hit: nil, damageToPlayer: damage)
        state.cursor += 1
        if state.opponent.tier.runsEveryQuestion {
            return [.playerHurt(damage), .explanation(question.explanation)] + championClose(&state)
        }
        if state.playerHP <= 0 { return [.playerHurt(damage)] + faintOrRevive(&state, question: question) }
        return [.playerHurt(damage), .explanation(question.explanation)] + advanceOrExhaust(&state)
    }

    private static func recordTurn(
        _ state: inout BattleState, question: Question, selectedIndex: Int,
        isCorrect: Bool, hit: Hit?, damageToPlayer: Int
    ) {
        state.turns.append(BattleTurnResult(
            questionID: question.id, selectedIndex: selectedIndex, isCorrect: isCorrect,
            grade: Grade(mcCorrect: isCorrect), hit: hit, damageToPlayer: damageToPlayer
        ))
    }

    private static func faintOrRevive(_ state: inout BattleState, question: Question) -> [BattleEvent] {
        guard state.reviveArmed else {
            state.outcome = .lost
            return [.explanation(question.explanation), .playerFainted]
        }
        state.reviveArmed = false
        state.playerHP = state.playerMaxHP / 2
        return [.revived(state.playerHP), .explanation(question.explanation)] + advanceOrExhaust(&state)
    }

    private static func advanceOrExhaust(_ state: inout BattleState) -> [BattleEvent] {
        guard state.cursor < state.deck.count else {
            state.outcome = .lost
            return [.deckExhausted]
        }
        return [.questionPresented(state.deck[state.cursor])]
    }

    private static func championClose(_ state: inout BattleState) -> [BattleEvent] {
        guard state.cursor >= state.deck.count else {
            return [.questionPresented(state.deck[state.cursor])]
        }
        if state.opponentHP <= 0 {
            state.outcome = .won
            return [.opponentFainted]
        }
        state.outcome = .lost
        return [.playerFainted]
    }
}
