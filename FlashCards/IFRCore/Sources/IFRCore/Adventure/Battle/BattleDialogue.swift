public enum BattleDialogue {
    public static func current(
        outcome: BattleOutcome?, intro: DialogueScript, win: DialogueScript, lose: DialogueScript
    ) -> DialogueScript {
        switch outcome {
        case .won: win
        case .lost: lose
        case nil: intro
        }
    }
}
