import XCTest
@testable import IFRCore

final class BattleRendererTests: XCTestCase {
    private func mcQuestion(_ id: String, _ category: IFRCore.Category, difficulty: Int = 1) -> Question {
        Question(id: id, category: category, acsCodes: ["IR.I.A.K1"], format: .multipleChoice,
                 front: "f", back: "b", options: ["a", "b", "c"], correctIndex: 0, explanation: "e",
                 source: SourceRef(document: "d", section: "s", url: URL(string: "https://faa.gov")!),
                 figure: nil, difficulty: difficulty)
    }

    private func deck(_ count: Int) -> [Question] {
        (0..<count).map { mcQuestion("q\($0)", .humanFactors) }
    }

    private func opponent(spriteID: String = "leader-hypoxia", maxHP: Int = 70) -> Opponent {
        Opponent(id: "hypoxia", name: "Dr. Hypoxia", nameplateName: "HYPOXIA", spriteID: spriteID,
                 tier: .gym, maxHP: maxHP)
    }

    private func state(maxHP: Int = 70, playerMaxHP: Int = 100) -> BattleState {
        BattleEngine.start(opponent: opponent(maxHP: maxHP), deck: deck(10), playerMaxHP: playerMaxHP)
    }

    private func pixel(_ frame: PixelFrame, _ x: Int, _ y: Int) -> UInt8 {
        frame.pixels[y * PixelFrame.width + x]
    }

    func testRendererPlacesOpponentAtOneSeventySixEight() {
        let frame = BattleRenderer.frame(state: state(), displayedPlayerHP: 100, displayedOpponentHP: 70,
                                         playerSpriteID: "player-back", atFrame: 0, phase: .asking)
        let sprite = SpriteCatalog.sprite(named: "leader-hypoxia")!
        for y in 0..<sprite.height {
            for x in 0..<sprite.width where sprite[x, y] != Palette.transparent {
                XCTAssertEqual(pixel(frame, 176 + x, 8 + y), sprite[x, y])
            }
        }
    }

    func testRendererUsesDisplayedHPForBars() {
        let frame = BattleRenderer.frame(state: state(), displayedPlayerHP: 100, displayedOpponentHP: 70,
                                         playerSpriteID: "player-back", atFrame: 0, phase: .asking)
        let barOrigin = NamePlate.enemy.barOrigin
        var filled = 0
        for x in barOrigin.x..<(barOrigin.x + 48) where pixel(frame, x, barOrigin.y) != 6 {
            filled += 1
        }
        XCTAssertEqual(filled, 48)
    }

    func testRendererAppliesIntroSlideOffset() {
        let frame = BattleRenderer.frame(state: state(), displayedPlayerHP: 100, displayedOpponentHP: 70,
                                         playerSpriteID: "player-back", atFrame: 6, phase: .intro)
        let offsets = BattleIntro.slideOffset(atFrame: 6)
        XCTAssertNotEqual(pixel(frame, offsets.enemyX + 14, 10), 1)
        XCTAssertEqual(pixel(frame, 176 + 14, 10), 1)
    }

    func testRendererLeavesNamePlateTextAreaUntouched() {
        let frame = BattleRenderer.frame(state: state(), displayedPlayerHP: 100, displayedOpponentHP: 70,
                                         playerSpriteID: "player-back", atFrame: 0, phase: .asking)
        let nameOrigin = NamePlate.enemy.nameOrigin
        for x in nameOrigin.x..<(nameOrigin.x + 40) {
            XCTAssertEqual(pixel(frame, x, nameOrigin.y), 6)
        }
    }
}
