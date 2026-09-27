import XCTest
@testable import IFRCore

final class OverworldRendererTests: XCTestCase {
    private func groundRows(_ width: Int, _ height: Int) -> [[TileKind]] {
        Array(repeating: Array(repeating: TileKind.ground, count: width), count: height)
    }

    private func makeMap(_ rows: [[TileKind]]) -> TileMap {
        TileMap(width: rows.first?.count ?? 0, height: rows.count, rows: rows)
    }

    private func makeState(x: Int, y: Int, facing: Direction = .down, pendingPath: [GridPoint] = []) -> OverworldState {
        OverworldState(position: GridPoint(x: x, y: y), facing: facing, pendingPath: pendingPath)
    }

    private func makeTrainer(id: String, position: GridPoint, spriteID: String = "trainer-student") -> Trainer {
        Trainer(
            id: id, name: "Trainer", nameplateName: "T", spriteID: spriteID,
            position: position, facing: .down, range: 3, questionCount: 4,
            categories: [.humanFactors], dialogue: DialogueRefs(intro: "i", win: "w", lose: "l")
        )
    }

    private func cameraOrigin(for state: OverworldState, map: TileMap) -> GridPoint {
        Camera.origin(
            following: state.position, mapWidth: map.width, mapHeight: map.height,
            viewportWidth: OverworldRenderer.viewportWidth, viewportHeight: OverworldRenderer.viewportHeight
        )
    }

    private func screenPoint(_ tile: GridPoint, origin: GridPoint) -> GridPoint {
        GridPoint(x: (tile.x - origin.x) * OverworldRenderer.cellSize, y: (tile.y - origin.y) * OverworldRenderer.cellSize)
    }

    private func pixel(_ frame: PixelFrame, at point: GridPoint) -> UInt8 {
        frame.pixels[point.y * PixelFrame.width + point.x]
    }

    func testRendersViewportTilesFromCameraOrigin() {
        var rows = groundRows(40, 30)
        rows[15][20] = .water
        let map = makeMap(rows)
        let state = makeState(x: 20, y: 15)
        let frame = OverworldRenderer.frame(map: map, state: state, trainers: [], defeated: [], atFrame: 0)
        let waterSprite = SpriteCatalog.sprite(named: TileSprites.name(for: .water))!
        let origin = cameraOrigin(for: state, map: map)
        let point = screenPoint(GridPoint(x: 20, y: 15), origin: origin)
        XCTAssertEqual(pixel(frame, at: point), waterSprite[0, 0])
    }

    func testPlayerDrawnAtCentre() {
        let map = makeMap(groundRows(40, 30))
        let state = makeState(x: 20, y: 15, facing: .down)
        let frame = OverworldRenderer.frame(map: map, state: state, trainers: [], defeated: [], atFrame: 0)
        let sprite = SpriteCatalog.sprite(named: "walker-down-0")!
        let centre = GridPoint(
            x: (OverworldRenderer.viewportWidth / 2) * OverworldRenderer.cellSize,
            y: (OverworldRenderer.viewportHeight / 2) * OverworldRenderer.cellSize
        )
        XCTAssertEqual(pixel(frame, at: centre), sprite[0, 0])
    }

    func testPathPreviewDrawnAlongPendingPath() {
        let map = makeMap(groundRows(40, 30))
        let state = makeState(x: 20, y: 15, pendingPath: [GridPoint(x: 21, y: 15)])
        let frame = OverworldRenderer.frame(map: map, state: state, trainers: [], defeated: [], atFrame: 0)
        let marker = SpriteCatalog.sprite(named: "path-marker")!
        let origin = cameraOrigin(for: state, map: map)
        let point = screenPoint(GridPoint(x: 21, y: 15), origin: origin)
        let centre = GridPoint(x: point.x + 7, y: point.y + 7)
        XCTAssertEqual(pixel(frame, at: centre), marker[7, 7])
    }

    func testWalkFrameAlternatesEveryFourFrames() {
        let map = makeMap(groundRows(40, 30))
        let state = makeState(x: 20, y: 15)
        let earlyFrame = OverworldRenderer.frame(map: map, state: state, trainers: [], defeated: [], atFrame: 0)
        let sameGroupFrame = OverworldRenderer.frame(map: map, state: state, trainers: [], defeated: [], atFrame: 3)
        let laterFrame = OverworldRenderer.frame(map: map, state: state, trainers: [], defeated: [], atFrame: 4)
        XCTAssertEqual(earlyFrame, sameGroupFrame)
        XCTAssertNotEqual(earlyFrame, laterFrame)
    }

    func testUndefeatedTrainersDrawnAndDefeatedOnesToo() {
        let map = makeMap(groundRows(40, 30))
        let state = makeState(x: 20, y: 15)
        let trainer = makeTrainer(id: "t1", position: GridPoint(x: 22, y: 15))
        let undefeatedFrame = OverworldRenderer.frame(map: map, state: state, trainers: [trainer], defeated: [], atFrame: 0)
        let defeatedFrame = OverworldRenderer.frame(map: map, state: state, trainers: [trainer], defeated: ["t1"], atFrame: 0)
        XCTAssertEqual(undefeatedFrame, defeatedFrame)
        let sprite = SpriteCatalog.sprite(named: "trainer-student")!
        let origin = cameraOrigin(for: state, map: map)
        let point = screenPoint(GridPoint(x: 22, y: 15), origin: origin)
        XCTAssertEqual(pixel(undefeatedFrame, at: point), sprite[0, 0])
    }
}
