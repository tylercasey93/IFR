import Foundation
import IFRCore

struct BattleRun: Identifiable {
    let id = UUID()
    let opponent: Opponent
    let deck: [Question]
    let playerMaxHP: Int
    let missDamage: Int?
    let playerSpriteID: String
    let playerPlateName: String
    let introDialogue: DialogueScript
    let winDialogue: DialogueScript
    let loseDialogue: DialogueScript
    let firstTime: Bool
    let returnTo: GridPoint?
    var items: [Item] = []
}
