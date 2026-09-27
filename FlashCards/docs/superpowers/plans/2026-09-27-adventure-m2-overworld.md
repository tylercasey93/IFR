# Adventure Mode — Milestone 2: Overworld

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the region walkable: a 40 by 30 tile map decoded from glyph rows, deterministic A-star tap-to-walk with an optional D-pad, cloud encounters drawn due-first from the study queue, trainers with line of sight, four items that touch only HP and movement, a rival who brings the weakest categories, doors into the Milestone 1 gyms, and one hand-authored map validated on every run.

**Architecture:** `Adventure/Overworld/` adds `GridPoint`, `Direction`, `TileKind`, `Pathfinder`, `OverworldState`, `OverworldTurn` (the single per-step reducer), `EncounterRoll`, `LineOfSight`, `TrainerApproach`, `Inventory`, `DirectTo`, `RivalPlanner`, `Respawn` and `Camera`; `Adventure/Content/` gains `TileMap`, `Trainer` and `RivalSpec`; `Adventure/Pixel/OverworldRenderer` draws the viewport; `AdventureSave` gains the overworld fields. The app adds `OverworldScreen`, `OverworldScreenModel`, `DPadOverlay` and `BagSheet`, and the region map becomes the Direct-To picker.

**Prerequisite:** Milestone 1 (`2026-09-27-adventure-m1-gym-circuit.md`) is complete and `scripts/test-core.sh` is green.

**Spec:** `docs/superpowers/specs/2026-09-27-adventure-mode-design.md` fixes every name, signature, number and rule this plan implements. Read its sections 2, 3, 4, 5 and 8 before starting.

**Tech Stack:** Swift 5.9 language mode (Swift 6.0.3 toolchain verified), Swift Package Manager, XCTest, SwiftUI, SwiftData, XcodeGen. No SpriteKit, no third-party packages.

## Global Constraints

- The git repository root is one level above `FlashCards/`. Every path in this plan is relative to `FlashCards/`; a path written as `<repo root>/...` is relative to the git root.
- Core tests: `scripts/test-core.sh` from `FlashCards/` (Linux with `scripts/install-swift-linux.sh`, or a Mac with Xcode). App tests: `scripts/test-app.sh` (Mac with Xcode and the iPhone 16 simulator).
- Every task is one red-green-refactor cycle: write the tests, watch them fail, write the minimal implementation, watch everything pass, tidy, commit. Commit after every green task.
- New code carries no comments of any kind: no `//`, no `///`, no `/* */`, no `MARK`. Names, small functions and tests carry the meaning. Existing files keep their comments; code added to them has none. The guard test from Task M1-01 enforces this under `Sources/IFRCore/Adventure`.
- All game rules live in `IFRCore` as `Sendable` value types with no UIKit, SwiftUI or Combine imports; randomness enters only as `inout some RandomNumberGenerator`, time only as parameters. The app layer renders, persists and measures wall-clock.
- Learning integrity: every question answered in Adventure goes through `Grade(mcCorrect:)` and `StudyStore`'s private `applyReview`, decks come only from `StudyQueue.session`, `QuizEngine.makeQuiz` and `QuizConfig.mockExam`, and no item can reach a question, a deck, a grade or a card state.
- Functions stay under 15 lines and files under 150 lines, except sprite grid files under `Pixel/Sprites/`.
- Every IFRCore code block in this plan was written test-first, compiled and run green with Swift 6.0.3 on Linux on 2026-09-27, and the `Expected:` lines quote the output observed. App-target code (SwiftUI, SwiftData, UI tests) was written against the real app sources but could not be compiled on Linux; expect small fixes when Xcode first builds it, and keep the tests as the contract.

---

### Task M2-01: Grid, tiles, tile map (Linux)

**Files:**
- Create: `IFRCore/Sources/IFRCore/Adventure/Overworld/Direction.swift`
- Create: `IFRCore/Sources/IFRCore/Adventure/Overworld/TileKind.swift`
- Create: `IFRCore/Sources/IFRCore/Adventure/Content/TileMap.swift`
- Modify: `IFRCore/Sources/IFRCore/Adventure/Content/AdventureContent.swift`
- Test: `IFRCore/Tests/IFRCoreTests/TileMapTests.swift`
- Test: `IFRCore/Tests/IFRCoreTests/DirectionTests.swift`

**Interfaces:**
- Consumes: `GridPoint` (`Hashable, Codable, Sendable { x, y }`, already defined in `IFRCore/Sources/IFRCore/Adventure/Pixel/GridPoint.swift` from M1); `AdventureContentError` (`IFRCore/Sources/IFRCore/Adventure/Content/AdventureContent.swift`, extended with `.unknownTile(x:y:)` and `.raggedRows` cases already present from M1); `AdventureContent.tileMap: TileMap?` field, already declared and decoded via `decodeIfPresent`.
- Produces: `enum TileKind: Character, Equatable, Sendable { ground, airway, cloud, water, terrain, building, door, sign }` with `var isWalkable: Bool` and `var blocksSight: Bool`; `enum Direction: String, Codable, Sendable { up, down, left, right }` with `var delta: GridPoint` and `var opposite: Direction`; `struct TileMap: Codable, Equatable, Sendable { let width: Int; let height: Int; let rows: [[TileKind]] }` with `init(width:height:rows:)`, `init(from: Decoder)` (decodes JSON `rows: [String]` of glyphs into `[[TileKind]]`, throwing `.raggedRows` or `.unknownTile(x:y:)`), `encode(to:)`, and `subscript(_ point: GridPoint) -> TileKind?`.

- [ ] **Step 1: Write the failing tests**

File: `IFRCore/Tests/IFRCoreTests/TileMapTests.swift`

```swift
import XCTest
@testable import IFRCore

final class TileMapTests: XCTestCase {
    private func decode(_ json: String) throws -> TileMap {
        try JSONDecoder().decode(TileMap.self, from: Data(json.utf8))
    }

    private let fiveByFiveJSON = """
    {"width": 5, "height": 5, "rows": ["#####", "#.=~#", "#Dw.#", "#.B.#", "#####"]}
    """

    func testRowsDecodeThroughGlyphs() throws {
        let map = try decode(fiveByFiveJSON)
        XCTAssertEqual(map[GridPoint(x: 0, y: 0)], .terrain)
        XCTAssertEqual(map[GridPoint(x: 1, y: 1)], .ground)
        XCTAssertEqual(map[GridPoint(x: 2, y: 1)], .airway)
        XCTAssertEqual(map[GridPoint(x: 3, y: 1)], .cloud)
        XCTAssertEqual(map[GridPoint(x: 1, y: 2)], .door)
        XCTAssertEqual(map[GridPoint(x: 2, y: 2)], .water)
        XCTAssertEqual(map[GridPoint(x: 2, y: 3)], .building)
    }

    func testRaggedRowsRejected() throws {
        let json = """
        {"width": 5, "height": 5, "rows": ["#####", "#.=~#", "#Dw.#", "#.B.", "#####"]}
        """
        XCTAssertThrowsError(try decode(json)) { error in
            XCTAssertEqual(error as? AdventureContentError, .raggedRows)
        }
    }

    func testUnknownGlyphRejectedWithCoordinates() throws {
        let json = """
        {"width": 5, "height": 5, "rows": ["#####", "#.X~#", "#Dw.#", "#.B.#", "#####"]}
        """
        XCTAssertThrowsError(try decode(json)) { error in
            XCTAssertEqual(error as? AdventureContentError, .unknownTile(x: 2, y: 1))
        }
    }

    func testBorderIsTerrain() throws {
        let json = """
        {"width": 5, "height": 5, "rows": ["Z####", "#.=~#", "#Dw.#", "#.B.#", "#####"]}
        """
        XCTAssertThrowsError(try decode(json)) { error in
            XCTAssertEqual(error as? AdventureContentError, .unknownTile(x: 0, y: 0))
        }
    }

    func testWalkabilityPerKind() {
        XCTAssertTrue(TileKind.ground.isWalkable)
        XCTAssertTrue(TileKind.airway.isWalkable)
        XCTAssertTrue(TileKind.cloud.isWalkable)
        XCTAssertTrue(TileKind.door.isWalkable)
        XCTAssertTrue(TileKind.sign.isWalkable)
        XCTAssertFalse(TileKind.water.isWalkable)
        XCTAssertFalse(TileKind.terrain.isWalkable)
        XCTAssertFalse(TileKind.building.isWalkable)
    }

    func testBlocksSightPerKind() {
        XCTAssertTrue(TileKind.terrain.blocksSight)
        XCTAssertTrue(TileKind.building.blocksSight)
        XCTAssertFalse(TileKind.ground.blocksSight)
        XCTAssertFalse(TileKind.airway.blocksSight)
        XCTAssertFalse(TileKind.cloud.blocksSight)
        XCTAssertFalse(TileKind.water.blocksSight)
        XCTAssertFalse(TileKind.door.blocksSight)
        XCTAssertFalse(TileKind.sign.blocksSight)
    }

    func testSubscriptOutOfBoundsIsNil() throws {
        let map = try decode(fiveByFiveJSON)
        XCTAssertNil(map[GridPoint(x: -1, y: 0)])
        XCTAssertNil(map[GridPoint(x: 0, y: -1)])
        XCTAssertNil(map[GridPoint(x: 5, y: 0)])
        XCTAssertNil(map[GridPoint(x: 0, y: 5)])
    }
}
```

- [ ] **Step 2: Write the failing tests**

File: `IFRCore/Tests/IFRCoreTests/DirectionTests.swift`

```swift
import XCTest
@testable import IFRCore

final class DirectionTests: XCTestCase {
    func testDirectionDeltaAndOpposite() {
        XCTAssertEqual(Direction.up.delta, GridPoint(x: 0, y: -1))
        XCTAssertEqual(Direction.down.delta, GridPoint(x: 0, y: 1))
        XCTAssertEqual(Direction.left.delta, GridPoint(x: -1, y: 0))
        XCTAssertEqual(Direction.right.delta, GridPoint(x: 1, y: 0))
        XCTAssertEqual(Direction.up.opposite, .down)
        XCTAssertEqual(Direction.down.opposite, .up)
        XCTAssertEqual(Direction.left.opposite, .right)
        XCTAssertEqual(Direction.right.opposite, .left)
    }
}
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `scripts/test-core.sh --filter TileMapTests`
Expected:
```
error: cannot find 'TileKind' in scope
error: value of type 'TileMap' has no subscripts
```
(compile failure: `TileKind` did not exist yet and the placeholder `TileMap` in `AdventureContent.swift`, an empty `struct TileMap: Codable, Equatable, Sendable {}`, had no fields or subscript.)

- [ ] **Step 4: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Overworld/TileKind.swift`

```swift
import Foundation

public enum TileKind: Character, Equatable, Sendable {
    case ground = "."
    case airway = "="
    case cloud = "~"
    case water = "w"
    case terrain = "#"
    case building = "B"
    case door = "D"
    case sign = "S"

    public var isWalkable: Bool {
        switch self {
        case .ground, .airway, .cloud, .door, .sign: true
        case .water, .terrain, .building: false
        }
    }

    public var blocksSight: Bool {
        switch self {
        case .terrain, .building: true
        case .ground, .airway, .cloud, .water, .door, .sign: false
        }
    }
}
```

- [ ] **Step 5: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Overworld/Direction.swift`

```swift
import Foundation

public enum Direction: String, Codable, Sendable {
    case up
    case down
    case left
    case right

    public var delta: GridPoint {
        switch self {
        case .up: GridPoint(x: 0, y: -1)
        case .down: GridPoint(x: 0, y: 1)
        case .left: GridPoint(x: -1, y: 0)
        case .right: GridPoint(x: 1, y: 0)
        }
    }

    public var opposite: Direction {
        switch self {
        case .up: .down
        case .down: .up
        case .left: .right
        case .right: .left
        }
    }
}
```

- [ ] **Step 6: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Content/TileMap.swift`

```swift
import Foundation

public struct TileMap: Codable, Equatable, Sendable {
    public let width: Int
    public let height: Int
    public let rows: [[TileKind]]

    private enum CodingKeys: String, CodingKey {
        case width, height, rows
    }

    public init(width: Int, height: Int, rows: [[TileKind]]) {
        self.width = width
        self.height = height
        self.rows = rows
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        width = try container.decode(Int.self, forKey: .width)
        height = try container.decode(Int.self, forKey: .height)
        let glyphRows = try container.decode([String].self, forKey: .rows)
        rows = try TileMap.decodeRows(glyphRows)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
        try container.encode(TileMap.encodeRows(rows), forKey: .rows)
    }

    public subscript(_ point: GridPoint) -> TileKind? {
        guard rows.indices.contains(point.y) else { return nil }
        let row = rows[point.y]
        guard row.indices.contains(point.x) else { return nil }
        return row[point.x]
    }

    private static func decodeRows(_ glyphRows: [String]) throws -> [[TileKind]] {
        let characterRows = glyphRows.map { Array($0) }
        let expectedWidth = characterRows.first?.count ?? 0
        guard characterRows.allSatisfy({ $0.count == expectedWidth }) else {
            throw AdventureContentError.raggedRows
        }
        return try characterRows.enumerated().map { y, row in
            try row.enumerated().map { x, glyph in
                guard let kind = TileKind(rawValue: glyph) else {
                    throw AdventureContentError.unknownTile(x: x, y: y)
                }
                return kind
            }
        }
    }

    private static func encodeRows(_ kindRows: [[TileKind]]) -> [String] {
        kindRows.map { row in String(row.map(\.rawValue)) }
    }
}
```

- [ ] **Step 7: Modify AdventureContent.swift**

File: `IFRCore/Sources/IFRCore/Adventure/Content/AdventureContent.swift`

The placeholder tile map type is removed; `TileMap` now lives in its own file (Step 6) and `AdventureContent` keeps using it unchanged through `TileMap?`:

```swift
public struct Trainer: Codable, Equatable, Sendable {
    public let id: String
}

public struct RivalSpec: Codable, Equatable, Sendable {}

public struct CompanionSpecies: Codable, Equatable, Sendable {}
```

(the line `public struct TileMap: Codable, Equatable, Sendable {}` that used to sit directly above `Trainer` was deleted; every other declaration in the file, including `public let tileMap: TileMap?` and its `decodeIfPresent(TileMap.self, forKey: .tileMap)`, is untouched.)

- [ ] **Step 8: Run all core tests**

Run: `scripts/test-core.sh`
Expected: `Executed 238 tests, with 0 failures`

- [ ] **Step 9: Commit**

Run: `git add IFRCore/Sources/IFRCore/Adventure/Overworld/Direction.swift IFRCore/Sources/IFRCore/Adventure/Overworld/TileKind.swift IFRCore/Sources/IFRCore/Adventure/Content/TileMap.swift IFRCore/Sources/IFRCore/Adventure/Content/AdventureContent.swift IFRCore/Tests/IFRCoreTests/TileMapTests.swift IFRCore/Tests/IFRCoreTests/DirectionTests.swift && git commit -m "M2-01: Grid, tiles, tile map (Linux)"`

---

### Task M2-02: Pathfinder (Linux)

**Files:**
- Create: `IFRCore/Sources/IFRCore/Adventure/Overworld/Pathfinder.swift`
- Test: `IFRCore/Tests/IFRCoreTests/PathfinderTests.swift`

**Interfaces:**
- Consumes: `GridPoint` (`IFRCore/Sources/IFRCore/Adventure/Pixel/GridPoint.swift`), `TileMap` and its `subscript(GridPoint) -> TileKind?` (`IFRCore/Sources/IFRCore/Adventure/Content/TileMap.swift`), `TileKind.isWalkable` (`IFRCore/Sources/IFRCore/Adventure/Overworld/TileKind.swift`)
- Produces: `enum Pathfinder { static func path(from: GridPoint, to: GridPoint, in map: TileMap, blocked: Set<GridPoint>) -> [GridPoint]? }`, used by `OverworldState.targeting` (M2-03b) and the content validator's `testEveryDoorReachableFromSpawn` (M2-08)

- [ ] **Step 1: Write the failing tests**

File: `IFRCore/Tests/IFRCoreTests/PathfinderTests.swift`

```swift
import XCTest
@testable import IFRCore

final class PathfinderTests: XCTestCase {
    private func makeMap(_ rows: [[TileKind]]) -> TileMap {
        TileMap(width: rows.first?.count ?? 0, height: rows.count, rows: rows)
    }

    private let ground = TileKind.ground
    private let water = TileKind.water
    private let terrain = TileKind.terrain

    func testStraightLineOnOpenGround() {
        let map = makeMap([[ground, ground, ground, ground, ground]])
        let path = Pathfinder.path(from: GridPoint(x: 0, y: 0), to: GridPoint(x: 4, y: 0), in: map, blocked: [])
        XCTAssertEqual(path, [
            GridPoint(x: 1, y: 0),
            GridPoint(x: 2, y: 0),
            GridPoint(x: 3, y: 0),
            GridPoint(x: 4, y: 0),
        ])
    }

    func testRoutesAroundWater() {
        let map = makeMap([
            [ground, ground, ground, ground, ground],
            [ground, water, water, water, ground],
            [ground, ground, ground, ground, ground],
        ])
        let path = Pathfinder.path(from: GridPoint(x: 0, y: 1), to: GridPoint(x: 4, y: 1), in: map, blocked: [])
        XCTAssertEqual(path, [
            GridPoint(x: 0, y: 0),
            GridPoint(x: 1, y: 0),
            GridPoint(x: 2, y: 0),
            GridPoint(x: 3, y: 0),
            GridPoint(x: 4, y: 0),
            GridPoint(x: 4, y: 1),
        ])
    }

    func testReturnsNilWhenUnreachable() {
        let map = makeMap([[ground, terrain, ground]])
        let path = Pathfinder.path(from: GridPoint(x: 0, y: 0), to: GridPoint(x: 2, y: 0), in: map, blocked: [])
        XCTAssertNil(path)
    }

    func testPathExcludesStartIncludesGoal() {
        let map = makeMap([[ground, ground, ground, ground, ground]])
        let start = GridPoint(x: 0, y: 0)
        let goal = GridPoint(x: 4, y: 0)
        let path = Pathfinder.path(from: start, to: goal, in: map, blocked: [])
        XCTAssertNotEqual(path?.first, start)
        XCTAssertEqual(path?.last, goal)
    }

    func testPathIsFourConnected() {
        let map = makeMap([
            [ground, ground, ground, ground, ground],
            [ground, water, water, water, ground],
            [ground, ground, ground, ground, ground],
        ])
        let path = Pathfinder.path(from: GridPoint(x: 0, y: 1), to: GridPoint(x: 4, y: 1), in: map, blocked: [])!
        var previous = GridPoint(x: 0, y: 1)
        for point in path {
            let manhattan = abs(point.x - previous.x) + abs(point.y - previous.y)
            XCTAssertEqual(manhattan, 1)
            previous = point
        }
    }

    func testBlockedSetTreatedAsWalls() {
        let map = makeMap([
            [ground, ground, ground, ground, ground],
            [ground, ground, ground, ground, ground],
            [ground, ground, ground, ground, ground],
        ])
        let blocked: Set<GridPoint> = [GridPoint(x: 1, y: 1), GridPoint(x: 2, y: 1), GridPoint(x: 3, y: 1)]
        let path = Pathfinder.path(from: GridPoint(x: 0, y: 1), to: GridPoint(x: 4, y: 1), in: map, blocked: blocked)
        XCTAssertEqual(path, [
            GridPoint(x: 0, y: 0),
            GridPoint(x: 1, y: 0),
            GridPoint(x: 2, y: 0),
            GridPoint(x: 3, y: 0),
            GridPoint(x: 4, y: 0),
            GridPoint(x: 4, y: 1),
        ])
    }

    func testDeterministicTieBreakByRowThenColumn() {
        let map = makeMap([
            [ground, ground, ground],
            [ground, ground, ground],
            [ground, ground, ground],
        ])
        let path = Pathfinder.path(from: GridPoint(x: 0, y: 0), to: GridPoint(x: 2, y: 2), in: map, blocked: [])
        XCTAssertEqual(path, [
            GridPoint(x: 1, y: 0),
            GridPoint(x: 2, y: 0),
            GridPoint(x: 2, y: 1),
            GridPoint(x: 2, y: 2),
        ])
    }

    func testNeighboursExpandUpRightDownLeft() {
        let map = makeMap([
            [ground, ground, ground],
            [ground, ground, ground],
            [ground, ground, ground],
        ])
        let path = Pathfinder.path(from: GridPoint(x: 1, y: 1), to: GridPoint(x: 0, y: 0), in: map, blocked: [])
        XCTAssertEqual(path, [
            GridPoint(x: 1, y: 0),
            GridPoint(x: 0, y: 0),
        ])
    }

    func testFortyByThirtyMapSolvesUnderTenMilliseconds() {
        let rows = Array(repeating: Array(repeating: ground, count: 40), count: 30)
        let map = makeMap(rows)
        let start = Date()
        let path = Pathfinder.path(from: GridPoint(x: 0, y: 0), to: GridPoint(x: 39, y: 29), in: map, blocked: [])
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertNotNil(path)
        XCTAssertLessThan(elapsed, 0.010)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `scripts/test-core.sh --filter PathfinderTests`
Expected:
```
/home/user/IFR-build/FlashCards/IFRCore/Tests/IFRCoreTests/PathfinderTests.swift:62:20: error: cannot find 'Pathfinder' in scope
```
(the same error repeats at every call site in the file; the build fails to compile before any test runs)

- [ ] **Step 3: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Overworld/Pathfinder.swift`

```swift
import Foundation

public enum Pathfinder {
    private static let neighbourOffsets: [GridPoint] = [
        GridPoint(x: 0, y: -1),
        GridPoint(x: 1, y: 0),
        GridPoint(x: 0, y: 1),
        GridPoint(x: -1, y: 0),
    ]

    public static func path(from start: GridPoint, to goal: GridPoint, in map: TileMap, blocked: Set<GridPoint>) -> [GridPoint]? {
        if start == goal { return [] }
        var open: [GridPoint] = [start]
        var gScore: [GridPoint: Int] = [start: 0]
        var cameFrom: [GridPoint: GridPoint] = [:]
        var closed: Set<GridPoint> = []

        while !open.isEmpty {
            let current = popBest(&open, gScore: gScore, goal: goal)
            if current == goal {
                return reconstruct(cameFrom: cameFrom, goal: goal)
            }
            closed.insert(current)
            expand(current, gScore: &gScore, cameFrom: &cameFrom, open: &open, closed: closed, map: map, blocked: blocked)
        }
        return nil
    }

    private static func expand(
        _ current: GridPoint,
        gScore: inout [GridPoint: Int],
        cameFrom: inout [GridPoint: GridPoint],
        open: inout [GridPoint],
        closed: Set<GridPoint>,
        map: TileMap,
        blocked: Set<GridPoint>
    ) {
        for neighbour in neighbours(of: current) {
            guard isPassable(neighbour, in: map, blocked: blocked), !closed.contains(neighbour) else { continue }
            let tentativeG = gScore[current, default: 0] + 1
            if gScore[neighbour] == nil || tentativeG < gScore[neighbour]! {
                gScore[neighbour] = tentativeG
                cameFrom[neighbour] = current
                if !open.contains(neighbour) {
                    open.append(neighbour)
                }
            }
        }
    }

    private static func popBest(_ open: inout [GridPoint], gScore: [GridPoint: Int], goal: GridPoint) -> GridPoint {
        var bestIndex = 0
        var bestKey = key(open[0], gScore: gScore, goal: goal)
        for index in open.indices.dropFirst() {
            let candidateKey = key(open[index], gScore: gScore, goal: goal)
            if candidateKey.lexicographicallyPrecedes(bestKey) {
                bestKey = candidateKey
                bestIndex = index
            }
        }
        return open.remove(at: bestIndex)
    }

    private static func key(_ point: GridPoint, gScore: [GridPoint: Int], goal: GridPoint) -> [Int] {
        let h = manhattan(point, goal)
        let g = gScore[point, default: 0]
        return [g + h, h, point.y, point.x]
    }

    private static func manhattan(_ a: GridPoint, _ b: GridPoint) -> Int {
        abs(a.x - b.x) + abs(a.y - b.y)
    }

    private static func neighbours(of point: GridPoint) -> [GridPoint] {
        neighbourOffsets.map { GridPoint(x: point.x + $0.x, y: point.y + $0.y) }
    }

    private static func isPassable(_ point: GridPoint, in map: TileMap, blocked: Set<GridPoint>) -> Bool {
        guard let kind = map[point], kind.isWalkable else { return false }
        return !blocked.contains(point)
    }

    private static func reconstruct(cameFrom: [GridPoint: GridPoint], goal: GridPoint) -> [GridPoint] {
        var path: [GridPoint] = [goal]
        var current = goal
        while let previous = cameFrom[current] {
            path.append(previous)
            current = previous
        }
        path.removeLast()
        return path.reversed()
    }
}
```

- [ ] **Step 4: Run all core tests**

Run: `scripts/test-core.sh`
Expected: `Executed 247 tests, with 0 failures`

- [ ] **Step 5: Commit**

Run: `git add IFRCore/Sources/IFRCore/Adventure/Overworld/Pathfinder.swift IFRCore/Tests/IFRCoreTests/PathfinderTests.swift && git commit -m "M2-02: Pathfinder"`

---

### Task M2-03a: Overworld stepping (Linux)

**Files:**
- Create: `IFRCore/Sources/IFRCore/Adventure/Overworld/OverworldState.swift`
- Modify: `IFRCore/Sources/IFRCore/Adventure/Content/TileMap.swift`
- Test: `IFRCore/Tests/IFRCoreTests/OverworldStateTests.swift`

**Interfaces:**
- Consumes: `GridPoint` (`IFRCore/Sources/IFRCore/Adventure/Pixel/GridPoint.swift`), `Direction` and its `delta` (`IFRCore/Sources/IFRCore/Adventure/Overworld/Direction.swift`), `TileKind` and `isWalkable` (`IFRCore/Sources/IFRCore/Adventure/Overworld/TileKind.swift`), `TileMap` and its `subscript(GridPoint) -> TileKind?` (`IFRCore/Sources/IFRCore/Adventure/Content/TileMap.swift`)
- Produces: `OverworldState: Codable, Equatable, Sendable { position, facing, pendingPath, stepsSinceEncounter, suppressedTrainerID }` with `func stepping(_ direction: Direction, in map: TileMap, blocked: Set<GridPoint>) -> (OverworldState, OverworldEvent)`; `enum OverworldEvent: Equatable, Sendable { none, blocked, warp(String), sign(String), pickup(String), cloud }`; `TileMap` gains `doorAirportIDs`, `signTexts`, `itemDropItemIDs: [GridPoint: String]`, decoded from the JSON `warps`, `signs` and `itemDrops` arrays, used by later overworld work items (`OverworldTurn`, `OverworldRenderer`, `Inventory`)

- [ ] **Step 1: Write the failing tests**

File: `IFRCore/Tests/IFRCoreTests/OverworldStateTests.swift`

```swift
import XCTest
@testable import IFRCore

final class OverworldStateTests: XCTestCase {
    private func makeMap(
        _ rows: [[TileKind]],
        doorAirportIDs: [GridPoint: String] = [:],
        signTexts: [GridPoint: String] = [:],
        itemDropItemIDs: [GridPoint: String] = [:]
    ) -> TileMap {
        TileMap(
            width: rows.first?.count ?? 0, height: rows.count, rows: rows,
            doorAirportIDs: doorAirportIDs, signTexts: signTexts, itemDropItemIDs: itemDropItemIDs
        )
    }

    private let ground = TileKind.ground
    private let terrain = TileKind.terrain
    private let cloud = TileKind.cloud
    private let door = TileKind.door
    private let sign = TileKind.sign

    private func makeState(x: Int = 1, y: Int = 1, facing: Direction = .up, stepsSinceEncounter: Int = 0) -> OverworldState {
        OverworldState(position: GridPoint(x: x, y: y), facing: facing, stepsSinceEncounter: stepsSinceEncounter)
    }

    func testSteppingIntoTerrainOnlyTurns() {
        let map = makeMap([
            [ground, terrain, ground],
            [ground, ground, ground],
            [ground, ground, ground],
        ])
        let state = makeState(x: 1, y: 1, facing: .down)
        let (next, event) = state.stepping(.up, in: map, blocked: [])
        XCTAssertEqual(next.facing, .up)
        XCTAssertEqual(next.position, state.position)
        XCTAssertEqual(event, .blocked)
    }

    func testSteppingIntoBlockedTileOnlyTurns() {
        let map = makeMap([
            [ground, ground, ground],
            [ground, ground, ground],
            [ground, ground, ground],
        ])
        let state = makeState(x: 1, y: 1, facing: .down)
        let blockedTile = GridPoint(x: 1, y: 0)
        let (next, event) = state.stepping(.up, in: map, blocked: [blockedTile])
        XCTAssertEqual(next.facing, .up)
        XCTAssertEqual(next.position, state.position)
        XCTAssertEqual(event, .blocked)
    }

    func testSteppingOntoWalkableMoves() {
        let map = makeMap([
            [ground, ground, ground],
            [ground, ground, ground],
            [ground, ground, ground],
        ])
        let state = makeState(x: 1, y: 1, facing: .down)
        let (next, event) = state.stepping(.up, in: map, blocked: [])
        XCTAssertEqual(next.facing, .up)
        XCTAssertEqual(next.position, GridPoint(x: 1, y: 0))
        XCTAssertEqual(event, .none)
    }

    func testSteppingOntoDoorEmitsWarpWithAirportID() {
        let map = makeMap(
            [
                [ground, door, ground],
                [ground, ground, ground],
                [ground, ground, ground],
            ],
            doorAirportIDs: [GridPoint(x: 1, y: 0): "KHYP"]
        )
        let state = makeState(x: 1, y: 1, facing: .down)
        let (next, event) = state.stepping(.up, in: map, blocked: [])
        XCTAssertEqual(next.position, GridPoint(x: 1, y: 0))
        XCTAssertEqual(event, .warp("KHYP"))
    }

    func testSteppingOntoSignEmitsText() {
        let map = makeMap(
            [
                [ground, sign, ground],
                [ground, ground, ground],
                [ground, ground, ground],
            ],
            signTexts: [GridPoint(x: 1, y: 0): "HYPOXIA FIELD. ELEV 8,000."]
        )
        let state = makeState(x: 1, y: 1, facing: .down)
        let (_, event) = state.stepping(.up, in: map, blocked: [])
        XCTAssertEqual(event, .sign("HYPOXIA FIELD. ELEV 8,000."))
    }

    func testSteppingOntoCloudEmitsCloud() {
        let map = makeMap([
            [ground, cloud, ground],
            [ground, ground, ground],
            [ground, ground, ground],
        ])
        let state = makeState(x: 1, y: 1, facing: .down)
        let (_, event) = state.stepping(.up, in: map, blocked: [])
        XCTAssertEqual(event, .cloud)
    }

    func testSteppingOntoItemDropEmitsPickup() {
        let map = makeMap(
            [
                [ground, ground, ground],
                [ground, ground, ground],
                [ground, ground, ground],
            ],
            itemDropItemIDs: [GridPoint(x: 1, y: 0): "potion"]
        )
        let state = makeState(x: 1, y: 1, facing: .down)
        let (_, event) = state.stepping(.up, in: map, blocked: [])
        XCTAssertEqual(event, .pickup("potion"))
    }

    func testSteppingNeverChangesStepsSinceEncounter() {
        let map = makeMap([
            [ground, cloud, ground],
            [ground, ground, ground],
            [ground, ground, ground],
        ])
        let state = makeState(x: 1, y: 1, facing: .down, stepsSinceEncounter: 5)
        let (next, _) = state.stepping(.up, in: map, blocked: [])
        XCTAssertEqual(next.stepsSinceEncounter, 5)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `scripts/test-core.sh --filter OverworldStateTests`
Expected:
```
/home/user/IFR-build/FlashCards/IFRCore/Tests/IFRCoreTests/OverworldStateTests.swift:23:110: error: cannot find type 'OverworldState' in scope
/home/user/IFR-build/FlashCards/IFRCore/Tests/IFRCoreTests/OverworldStateTests.swift:11:16: error: extra arguments at positions #4, #5, #6 in call
/home/user/IFR-build/FlashCards/IFRCore/Sources/IFRCore/Adventure/Content/TileMap.swift:12:12: note: 'init(width:height:rows:)' declared here
```

- [ ] **Step 3: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Overworld/OverworldState.swift`

```swift
import Foundation

public struct OverworldState: Codable, Equatable, Sendable {
    public var position: GridPoint
    public var facing: Direction
    public var pendingPath: [GridPoint]
    public var stepsSinceEncounter: Int
    public var suppressedTrainerID: String?

    public init(
        position: GridPoint,
        facing: Direction,
        pendingPath: [GridPoint] = [],
        stepsSinceEncounter: Int = 0,
        suppressedTrainerID: String? = nil
    ) {
        self.position = position
        self.facing = facing
        self.pendingPath = pendingPath
        self.stepsSinceEncounter = stepsSinceEncounter
        self.suppressedTrainerID = suppressedTrainerID
    }

    public func stepping(_ direction: Direction, in map: TileMap, blocked: Set<GridPoint>) -> (OverworldState, OverworldEvent) {
        var turned = self
        turned.facing = direction
        let destination = destination(from: position, moving: direction)
        guard let kind = map[destination], kind.isWalkable, !blocked.contains(destination) else {
            return (turned, .blocked)
        }
        var moved = turned
        moved.position = destination
        return (moved, event(for: kind, at: destination, in: map))
    }

    private func destination(from origin: GridPoint, moving direction: Direction) -> GridPoint {
        GridPoint(x: origin.x + direction.delta.x, y: origin.y + direction.delta.y)
    }

    private func event(for kind: TileKind, at point: GridPoint, in map: TileMap) -> OverworldEvent {
        if kind == .door { return warpEvent(at: point, in: map) }
        if kind == .sign { return signEvent(at: point, in: map) }
        if kind == .cloud { return .cloud }
        if let itemID = map.itemDropItemIDs[point] { return .pickup(itemID) }
        return .none
    }

    private func warpEvent(at point: GridPoint, in map: TileMap) -> OverworldEvent {
        guard let airportID = map.doorAirportIDs[point] else { return .none }
        return .warp(airportID)
    }

    private func signEvent(at point: GridPoint, in map: TileMap) -> OverworldEvent {
        guard let text = map.signTexts[point] else { return .none }
        return .sign(text)
    }
}

public enum OverworldEvent: Equatable, Sendable {
    case none
    case blocked
    case warp(String)
    case sign(String)
    case pickup(String)
    case cloud
}
```

- [ ] **Step 4: Modify TileMap to carry door, sign and item-drop lookups**

File: `IFRCore/Sources/IFRCore/Adventure/Content/TileMap.swift`

```swift
import Foundation

public struct TileMap: Codable, Equatable, Sendable {
    public let width: Int
    public let height: Int
    public let rows: [[TileKind]]
    public let doorAirportIDs: [GridPoint: String]
    public let signTexts: [GridPoint: String]
    public let itemDropItemIDs: [GridPoint: String]

    private enum CodingKeys: String, CodingKey {
        case width, height, rows, warps, signs, itemDrops
    }

    private struct Warp: Codable { let at: GridPoint; let airportID: String }
    private struct Sign: Codable { let at: GridPoint; let text: String }
    private struct ItemDrop: Codable { let id: String; let at: GridPoint; let itemID: String }

    public init(
        width: Int, height: Int, rows: [[TileKind]],
        doorAirportIDs: [GridPoint: String] = [:],
        signTexts: [GridPoint: String] = [:],
        itemDropItemIDs: [GridPoint: String] = [:]
    ) {
        self.width = width
        self.height = height
        self.rows = rows
        self.doorAirportIDs = doorAirportIDs
        self.signTexts = signTexts
        self.itemDropItemIDs = itemDropItemIDs
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        width = try container.decode(Int.self, forKey: .width)
        height = try container.decode(Int.self, forKey: .height)
        let glyphRows = try container.decode([String].self, forKey: .rows)
        rows = try TileMap.decodeRows(glyphRows)
        let warps = try container.decodeIfPresent([Warp].self, forKey: .warps) ?? []
        doorAirportIDs = Dictionary(uniqueKeysWithValues: warps.map { ($0.at, $0.airportID) })
        let signs = try container.decodeIfPresent([Sign].self, forKey: .signs) ?? []
        signTexts = Dictionary(uniqueKeysWithValues: signs.map { ($0.at, $0.text) })
        let itemDrops = try container.decodeIfPresent([ItemDrop].self, forKey: .itemDrops) ?? []
        itemDropItemIDs = Dictionary(uniqueKeysWithValues: itemDrops.map { ($0.at, $0.itemID) })
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
        try container.encode(TileMap.encodeRows(rows), forKey: .rows)
        try container.encode(doorAirportIDs.map { Warp(at: $0.key, airportID: $0.value) }, forKey: .warps)
        try container.encode(signTexts.map { Sign(at: $0.key, text: $0.value) }, forKey: .signs)
        try container.encode(itemDropItemIDs.map { ItemDrop(id: "\($0.key.x)-\($0.key.y)", at: $0.key, itemID: $0.value) }, forKey: .itemDrops)
    }

    public subscript(_ point: GridPoint) -> TileKind? {
        guard rows.indices.contains(point.y) else { return nil }
        let row = rows[point.y]
        guard row.indices.contains(point.x) else { return nil }
        return row[point.x]
    }

    private static func decodeRows(_ glyphRows: [String]) throws -> [[TileKind]] {
        let characterRows = glyphRows.map { Array($0) }
        let expectedWidth = characterRows.first?.count ?? 0
        guard characterRows.allSatisfy({ $0.count == expectedWidth }) else {
            throw AdventureContentError.raggedRows
        }
        return try characterRows.enumerated().map { y, row in
            try row.enumerated().map { x, glyph in
                guard let kind = TileKind(rawValue: glyph) else {
                    throw AdventureContentError.unknownTile(x: x, y: y)
                }
                return kind
            }
        }
    }

    private static func encodeRows(_ kindRows: [[TileKind]]) -> [String] {
        kindRows.map { row in String(row.map(\.rawValue)) }
    }
}
```

- [ ] **Step 5: Run all core tests**

Run: `scripts/test-core.sh`
Expected: `Executed 255 tests, with 0 failures (0 unexpected) in 0.85 (0.85) seconds`

- [ ] **Step 6: Commit**

Run: `git add FlashCards/IFRCore/Sources/IFRCore/Adventure/Overworld/OverworldState.swift FlashCards/IFRCore/Sources/IFRCore/Adventure/Content/TileMap.swift FlashCards/IFRCore/Tests/IFRCoreTests/OverworldStateTests.swift && git commit -m "M2-03a: Overworld stepping (Linux)"`

---

### Task M2-03b: Targeting, paths, camera (Linux)

**Files:**
- Create: `IFRCore/Sources/IFRCore/Adventure/Overworld/Camera.swift`
- Modify: `IFRCore/Sources/IFRCore/Adventure/Overworld/OverworldState.swift`
- Test: `IFRCore/Tests/IFRCoreTests/CameraTests.swift`
- Test: `IFRCore/Tests/IFRCoreTests/OverworldStateTests.swift`

**Interfaces:**
- Consumes: `GridPoint` (`IFRCore/Sources/IFRCore/Adventure/Pixel/GridPoint.swift`), `Direction` (`IFRCore/Sources/IFRCore/Adventure/Overworld/Direction.swift`), `TileMap`/`TileKind` (`IFRCore/Sources/IFRCore/Adventure/Content/TileMap.swift`, `IFRCore/Sources/IFRCore/Adventure/Overworld/TileKind.swift`), `Pathfinder.path(from:to:in:blocked:)` (`IFRCore/Sources/IFRCore/Adventure/Overworld/Pathfinder.swift`)
- Produces: `OverworldState.targeting(_ goal: GridPoint, in map: TileMap, blocked: Set<GridPoint>) -> OverworldState`, `OverworldState.interrupted() -> OverworldState`, `enum Camera { static func origin(following: GridPoint, mapWidth: Int, mapHeight: Int, viewportWidth: Int = 15, viewportHeight: Int = 10) -> GridPoint }` — all used by the M2-04 overworld turn reducer and the M2-09a overworld renderer

- [ ] **Step 1: Write the failing tests**

File: `IFRCore/Tests/IFRCoreTests/CameraTests.swift`

```swift
import XCTest
@testable import IFRCore

final class CameraTests: XCTestCase {
    func testCameraCentresOnPlayer() {
        let origin = Camera.origin(following: GridPoint(x: 20, y: 15), mapWidth: 40, mapHeight: 30)
        XCTAssertEqual(origin, GridPoint(x: 13, y: 10))
    }

    func testCameraClampsAtMapEdges() {
        let topLeft = Camera.origin(following: GridPoint(x: 0, y: 0), mapWidth: 40, mapHeight: 30)
        XCTAssertEqual(topLeft, GridPoint(x: 0, y: 0))
        let bottomRight = Camera.origin(following: GridPoint(x: 39, y: 29), mapWidth: 40, mapHeight: 30)
        XCTAssertEqual(bottomRight, GridPoint(x: 25, y: 20))
    }
}
```

File: `IFRCore/Tests/IFRCoreTests/OverworldStateTests.swift`

```swift
import XCTest
@testable import IFRCore

final class OverworldStateTests: XCTestCase {
    private func makeMap(
        _ rows: [[TileKind]],
        doorAirportIDs: [GridPoint: String] = [:],
        signTexts: [GridPoint: String] = [:],
        itemDropItemIDs: [GridPoint: String] = [:]
    ) -> TileMap {
        TileMap(
            width: rows.first?.count ?? 0, height: rows.count, rows: rows,
            doorAirportIDs: doorAirportIDs, signTexts: signTexts, itemDropItemIDs: itemDropItemIDs
        )
    }

    private let ground = TileKind.ground
    private let terrain = TileKind.terrain
    private let cloud = TileKind.cloud
    private let door = TileKind.door
    private let sign = TileKind.sign
    private let water = TileKind.water

    private func makeState(x: Int = 1, y: Int = 1, facing: Direction = .up, stepsSinceEncounter: Int = 0) -> OverworldState {
        OverworldState(position: GridPoint(x: x, y: y), facing: facing, stepsSinceEncounter: stepsSinceEncounter)
    }

    func testSteppingIntoTerrainOnlyTurns() {
        let map = makeMap([
            [ground, terrain, ground],
            [ground, ground, ground],
            [ground, ground, ground],
        ])
        let state = makeState(x: 1, y: 1, facing: .down)
        let (next, event) = state.stepping(.up, in: map, blocked: [])
        XCTAssertEqual(next.facing, .up)
        XCTAssertEqual(next.position, state.position)
        XCTAssertEqual(event, .blocked)
    }

    func testSteppingIntoBlockedTileOnlyTurns() {
        let map = makeMap([
            [ground, ground, ground],
            [ground, ground, ground],
            [ground, ground, ground],
        ])
        let state = makeState(x: 1, y: 1, facing: .down)
        let blockedTile = GridPoint(x: 1, y: 0)
        let (next, event) = state.stepping(.up, in: map, blocked: [blockedTile])
        XCTAssertEqual(next.facing, .up)
        XCTAssertEqual(next.position, state.position)
        XCTAssertEqual(event, .blocked)
    }

    func testSteppingOntoWalkableMoves() {
        let map = makeMap([
            [ground, ground, ground],
            [ground, ground, ground],
            [ground, ground, ground],
        ])
        let state = makeState(x: 1, y: 1, facing: .down)
        let (next, event) = state.stepping(.up, in: map, blocked: [])
        XCTAssertEqual(next.facing, .up)
        XCTAssertEqual(next.position, GridPoint(x: 1, y: 0))
        XCTAssertEqual(event, .none)
    }

    func testSteppingOntoDoorEmitsWarpWithAirportID() {
        let map = makeMap(
            [
                [ground, door, ground],
                [ground, ground, ground],
                [ground, ground, ground],
            ],
            doorAirportIDs: [GridPoint(x: 1, y: 0): "KHYP"]
        )
        let state = makeState(x: 1, y: 1, facing: .down)
        let (next, event) = state.stepping(.up, in: map, blocked: [])
        XCTAssertEqual(next.position, GridPoint(x: 1, y: 0))
        XCTAssertEqual(event, .warp("KHYP"))
    }

    func testSteppingOntoSignEmitsText() {
        let map = makeMap(
            [
                [ground, sign, ground],
                [ground, ground, ground],
                [ground, ground, ground],
            ],
            signTexts: [GridPoint(x: 1, y: 0): "HYPOXIA FIELD. ELEV 8,000."]
        )
        let state = makeState(x: 1, y: 1, facing: .down)
        let (_, event) = state.stepping(.up, in: map, blocked: [])
        XCTAssertEqual(event, .sign("HYPOXIA FIELD. ELEV 8,000."))
    }

    func testSteppingOntoCloudEmitsCloud() {
        let map = makeMap([
            [ground, cloud, ground],
            [ground, ground, ground],
            [ground, ground, ground],
        ])
        let state = makeState(x: 1, y: 1, facing: .down)
        let (_, event) = state.stepping(.up, in: map, blocked: [])
        XCTAssertEqual(event, .cloud)
    }

    func testSteppingOntoItemDropEmitsPickup() {
        let map = makeMap(
            [
                [ground, ground, ground],
                [ground, ground, ground],
                [ground, ground, ground],
            ],
            itemDropItemIDs: [GridPoint(x: 1, y: 0): "potion"]
        )
        let state = makeState(x: 1, y: 1, facing: .down)
        let (_, event) = state.stepping(.up, in: map, blocked: [])
        XCTAssertEqual(event, .pickup("potion"))
    }

    func testSteppingNeverChangesStepsSinceEncounter() {
        let map = makeMap([
            [ground, cloud, ground],
            [ground, ground, ground],
            [ground, ground, ground],
        ])
        let state = makeState(x: 1, y: 1, facing: .down, stepsSinceEncounter: 5)
        let (next, _) = state.stepping(.up, in: map, blocked: [])
        XCTAssertEqual(next.stepsSinceEncounter, 5)
    }

    func testPendingPathAdvancesOneTilePerStep() {
        let map = makeMap([
            [ground, ground, ground],
            [ground, ground, ground],
            [ground, ground, ground],
        ])
        var state = makeState(x: 1, y: 1, facing: .down)
        state.pendingPath = [GridPoint(x: 1, y: 0), GridPoint(x: 0, y: 0)]
        let (next, _) = state.stepping(.up, in: map, blocked: [])
        XCTAssertEqual(next.position, GridPoint(x: 1, y: 0))
        XCTAssertEqual(next.pendingPath, [GridPoint(x: 0, y: 0)])
    }

    func testNewTargetReplacesPendingPath() {
        let map = makeMap([
            [ground, ground, ground],
            [ground, ground, ground],
            [ground, ground, ground],
        ])
        let state = makeState(x: 1, y: 1, facing: .down)
        let firstTargeted = state.targeting(GridPoint(x: 2, y: 1), in: map, blocked: [])
        XCTAssertEqual(firstTargeted.pendingPath, [GridPoint(x: 2, y: 1)])
        let retargeted = firstTargeted.targeting(GridPoint(x: 0, y: 1), in: map, blocked: [])
        XCTAssertEqual(retargeted.pendingPath, [GridPoint(x: 0, y: 1)])
    }

    func testTapOnWaterIsIgnored() {
        let map = makeMap([
            [ground, ground, water],
            [ground, ground, ground],
            [ground, ground, ground],
        ])
        var state = makeState(x: 1, y: 1, facing: .down)
        state.pendingPath = [GridPoint(x: 1, y: 2)]
        let targeted = state.targeting(GridPoint(x: 2, y: 0), in: map, blocked: [])
        XCTAssertEqual(targeted.pendingPath, [GridPoint(x: 1, y: 2)])
    }

    func testTapOnUnreachableTileIsIgnored() {
        let map = makeMap([
            [ground, terrain, ground],
            [ground, terrain, ground],
            [ground, terrain, ground],
        ])
        var state = makeState(x: 0, y: 1, facing: .down)
        state.pendingPath = [GridPoint(x: 0, y: 0)]
        let targeted = state.targeting(GridPoint(x: 2, y: 1), in: map, blocked: [])
        XCTAssertEqual(targeted.pendingPath, [GridPoint(x: 0, y: 0)])
    }

    func testTapOnOwnTileClearsPath() {
        let map = makeMap([
            [ground, ground, ground],
            [ground, ground, ground],
            [ground, ground, ground],
        ])
        var state = makeState(x: 1, y: 1, facing: .down)
        state.pendingPath = [GridPoint(x: 1, y: 0)]
        let targeted = state.targeting(state.position, in: map, blocked: [])
        XCTAssertEqual(targeted.pendingPath, [])
    }

    func testInterruptedClearsPendingPath() {
        var state = makeState(x: 1, y: 1, facing: .down)
        state.pendingPath = [GridPoint(x: 1, y: 0), GridPoint(x: 1, y: -1)]
        let interrupted = state.interrupted()
        XCTAssertEqual(interrupted.pendingPath, [])
    }

    func testOverworldStateCodableRoundTrip() throws {
        let state = OverworldState(
            position: GridPoint(x: 4, y: 2),
            facing: .left,
            pendingPath: [GridPoint(x: 3, y: 2), GridPoint(x: 2, y: 2)],
            stepsSinceEncounter: 6,
            suppressedTrainerID: "student-ana"
        )
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(OverworldState.self, from: data)
        XCTAssertEqual(decoded, state)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `scripts/test-core.sh --filter OverworldStateTests`
Expected:
```
OverworldStateTests.swift:198:9: error: value of type 'OverworldState' has no member 'interrupted'
CameraTests.swift:6:22: error: cannot find 'Camera' in scope
error: fatalError
```

- [ ] **Step 3: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Overworld/Camera.swift`

```swift
import Foundation

public enum Camera {
    public static func origin(
        following player: GridPoint,
        mapWidth: Int,
        mapHeight: Int,
        viewportWidth: Int = 15,
        viewportHeight: Int = 10
    ) -> GridPoint {
        GridPoint(
            x: clamped(player.x - viewportWidth / 2, extent: mapWidth, viewport: viewportWidth),
            y: clamped(player.y - viewportHeight / 2, extent: mapHeight, viewport: viewportHeight)
        )
    }

    private static func clamped(_ value: Int, extent: Int, viewport: Int) -> Int {
        min(max(value, 0), max(extent - viewport, 0))
    }
}
```

File: `IFRCore/Sources/IFRCore/Adventure/Overworld/OverworldState.swift`

```swift
import Foundation

public struct OverworldState: Codable, Equatable, Sendable {
    public var position: GridPoint
    public var facing: Direction
    public var pendingPath: [GridPoint]
    public var stepsSinceEncounter: Int
    public var suppressedTrainerID: String?

    public init(
        position: GridPoint,
        facing: Direction,
        pendingPath: [GridPoint] = [],
        stepsSinceEncounter: Int = 0,
        suppressedTrainerID: String? = nil
    ) {
        self.position = position
        self.facing = facing
        self.pendingPath = pendingPath
        self.stepsSinceEncounter = stepsSinceEncounter
        self.suppressedTrainerID = suppressedTrainerID
    }

    public func stepping(_ direction: Direction, in map: TileMap, blocked: Set<GridPoint>) -> (OverworldState, OverworldEvent) {
        var turned = self
        turned.facing = direction
        let destination = destination(from: position, moving: direction)
        guard let kind = map[destination], kind.isWalkable, !blocked.contains(destination) else {
            return (turned, .blocked)
        }
        var moved = turned
        moved.position = destination
        moved.pendingPath = advancingPendingPath(after: destination)
        return (moved, event(for: kind, at: destination, in: map))
    }

    public func targeting(_ goal: GridPoint, in map: TileMap, blocked: Set<GridPoint>) -> OverworldState {
        guard let kind = map[goal], kind.isWalkable else { return self }
        guard let path = Pathfinder.path(from: position, to: goal, in: map, blocked: blocked) else { return self }
        var targeted = self
        targeted.pendingPath = path
        return targeted
    }

    public func interrupted() -> OverworldState {
        var interrupted = self
        interrupted.pendingPath = []
        return interrupted
    }

    private func destination(from origin: GridPoint, moving direction: Direction) -> GridPoint {
        GridPoint(x: origin.x + direction.delta.x, y: origin.y + direction.delta.y)
    }

    private func advancingPendingPath(after destination: GridPoint) -> [GridPoint] {
        guard let head = pendingPath.first, head == destination else { return [] }
        return Array(pendingPath.dropFirst())
    }

    private func event(for kind: TileKind, at point: GridPoint, in map: TileMap) -> OverworldEvent {
        if kind == .door { return warpEvent(at: point, in: map) }
        if kind == .sign { return signEvent(at: point, in: map) }
        if kind == .cloud { return .cloud }
        if let itemID = map.itemDropItemIDs[point] { return .pickup(itemID) }
        return .none
    }

    private func warpEvent(at point: GridPoint, in map: TileMap) -> OverworldEvent {
        guard let airportID = map.doorAirportIDs[point] else { return .none }
        return .warp(airportID)
    }

    private func signEvent(at point: GridPoint, in map: TileMap) -> OverworldEvent {
        guard let text = map.signTexts[point] else { return .none }
        return .sign(text)
    }
}

public enum OverworldEvent: Equatable, Sendable {
    case none
    case blocked
    case warp(String)
    case sign(String)
    case pickup(String)
    case cloud
}
```

- [ ] **Step 4: Run all core tests**

Run: `scripts/test-core.sh`
Expected: `Executed 264 tests, with 0 failures`

- [ ] **Step 5: Commit**

Run: `git add FlashCards/IFRCore/Sources/IFRCore/Adventure/Overworld/Camera.swift FlashCards/IFRCore/Sources/IFRCore/Adventure/Overworld/OverworldState.swift FlashCards/IFRCore/Tests/IFRCoreTests/CameraTests.swift FlashCards/IFRCore/Tests/IFRCoreTests/OverworldStateTests.swift && git commit -m "M2-03b: Targeting, paths, camera (Linux)"`

---

### Task M2-04: Cloud encounters

**Files:**
- Create: `IFRCore/Sources/IFRCore/Adventure/Encounters/EncounterRoll.swift`
- Test: `IFRCore/Tests/IFRCoreTests/EncounterRollTests.swift`

**Interfaces:**
- Consumes: `TileKind` (`IFRCore/Sources/IFRCore/Adventure/Overworld/TileKind.swift`), `EncounterDeck.draw(count:categories:bank:states:now:using:)` (`IFRCore/Sources/IFRCore/Adventure/Encounters/EncounterDeck.swift`), `OpponentHP.cloud(for:)` and `Damage.hit(difficulty:answerSeconds:)` (`IFRCore/Sources/IFRCore/Adventure/Battle/OpponentHP.swift`, `.../Battle/Damage.swift`), `BattleTier.cloud` (`IFRCore/Sources/IFRCore/Adventure/Battle/BattleTier.swift`), `SeededRNG` (`IFRCore/Sources/IFRCore/Quiz/QuizEngine.swift`)
- Produces: `enum EncounterRoll { static let oneIn: Int; static let pityStep: Int; static func triggers(on tile: TileKind, repelStepsLeft: Int, stepsSinceEncounter: Int, using rng: inout some RandomNumberGenerator) -> Bool }`, used by `OverworldTurn` (M2-05b) to decide whether a cloud step becomes a wild encounter.

- [ ] **Step 1: Write the failing tests**

File: `IFRCore/Tests/IFRCoreTests/EncounterRollTests.swift`

```swift
import XCTest
@testable import IFRCore

final class EncounterRollTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let scheduler = Scheduler()

    private struct FixedRNG: RandomNumberGenerator {
        let value: UInt64
        func next() -> UInt64 { value }
    }

    private func mcQuestion(_ id: String, _ category: IFRCore.Category) -> Question {
        Question(id: id, category: category, acsCodes: ["IR.I.A.K1"], format: .multipleChoice,
                 front: "f", back: "b", options: ["a", "b", "c"], correctIndex: 0, explanation: "e",
                 source: SourceRef(document: "d", section: "s", url: URL(string: "https://faa.gov")!),
                 figure: nil, difficulty: 1)
    }

    private func dueState(_ id: String, dueOffset: TimeInterval) -> CardState {
        var s = CardState.new(questionID: id)
        s.reps = 1
        s.due = now.addingTimeInterval(dueOffset)
        return s
    }

    func testOneInEightOverEightHundredSeededRolls() {
        var rng = SeededRNG(seed: 7)
        var hits = 0
        for _ in 0..<800 {
            if EncounterRoll.triggers(on: .cloud, repelStepsLeft: 0, stepsSinceEncounter: 0, using: &rng) {
                hits += 1
            }
        }
        XCTAssertTrue((80...120).contains(hits), "expected roughly 100 hits, got \(hits)")
    }

    func testNoRollOffCloud() {
        var rng = FixedRNG(value: 0)
        XCTAssertFalse(EncounterRoll.triggers(on: .ground, repelStepsLeft: 0, stepsSinceEncounter: 0, using: &rng))
        XCTAssertFalse(EncounterRoll.triggers(on: .airway, repelStepsLeft: 0, stepsSinceEncounter: 0, using: &rng))
        XCTAssertFalse(EncounterRoll.triggers(on: .door, repelStepsLeft: 0, stepsSinceEncounter: 0, using: &rng))
    }

    func testRollRunsOnEveryCloudStepNotOnlyOnEntry() {
        var rngA = SeededRNG(seed: 7)
        let first = EncounterRoll.triggers(on: .cloud, repelStepsLeft: 0, stepsSinceEncounter: 0, using: &rngA)
        let second = EncounterRoll.triggers(on: .cloud, repelStepsLeft: 0, stepsSinceEncounter: 0, using: &rngA)
        var rngB = SeededRNG(seed: 7)
        let expectedFirst = rngB.next() % 8 == 0
        let expectedSecond = rngB.next() % 8 == 0
        XCTAssertEqual(first, expectedFirst)
        XCTAssertEqual(second, expectedSecond)
    }

    func testRepelSuppressesEncounters() {
        var rng = FixedRNG(value: 0)
        XCTAssertFalse(EncounterRoll.triggers(on: .cloud, repelStepsLeft: 1, stepsSinceEncounter: 0, using: &rng))
        XCTAssertFalse(EncounterRoll.triggers(on: .cloud, repelStepsLeft: 50, stepsSinceEncounter: 24, using: &rng))
    }

    func testPityStepForcesEncounterOnTwentyFourthCloudStep() {
        var rng = FixedRNG(value: 1)
        XCTAssertFalse(EncounterRoll.triggers(on: .cloud, repelStepsLeft: 0, stepsSinceEncounter: 23, using: &rng))
        XCTAssertTrue(EncounterRoll.triggers(on: .cloud, repelStepsLeft: 0, stepsSinceEncounter: 24, using: &rng))
    }

    func testCloudDeckDrawsOneDueOrWeakCardPreferringAreaCategory() {
        struct Area { let category: IFRCore.Category }
        let area = Area(category: .weather)
        let bank = QuestionBank(version: 1, questions: [
            mcQuestion("weather-due", .weather), mcQuestion("weather-weak", .weather), mcQuestion("reg-1", .regulations),
        ])
        let states = ["weather-due": dueState("weather-due", dueOffset: -100)]
        var rng = SeededRNG(seed: 7)
        let deck = EncounterDeck(scheduler: scheduler)
        let drawn = deck.draw(count: 1, categories: [area.category], bank: bank, states: states, now: now, using: &rng)
        XCTAssertEqual(drawn.map(\.id), ["weather-due"])
    }

    func testCloudOpponentHPIsBaseDamageOfItsQuestion() {
        let question = mcQuestion("q", .weather)
        XCTAssertEqual(OpponentHP.cloud(for: question), Damage.hit(difficulty: question.difficulty, answerSeconds: 10).amount)
        XCTAssertEqual(BattleTier.cloud.rawValue, "cloud")
    }

    func testEmptyPoolMeansNoEncounter() {
        let bank = QuestionBank(version: 1, questions: [mcQuestion("reg-1", .regulations)])
        var rng = SeededRNG(seed: 7)
        let deck = EncounterDeck(scheduler: scheduler)
        let drawn = deck.draw(count: 1, categories: [.weather], bank: bank, states: [:], now: now, using: &rng)
        XCTAssertTrue(drawn.isEmpty)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `scripts/test-core.sh --filter EncounterRollTests`
Expected:
```
error: cannot find 'EncounterRoll' in scope
XCTAssertFalse(EncounterRoll.triggers(on: .cloud, repelStepsLeft: 1, stepsSinceEncounter: 0, using: &rng))
error: cannot infer contextual base in reference to member 'cloud'
```
(compile failure: `EncounterRoll` did not exist yet, so every reference to it and to the bare `.cloud` tile literal it types failed to resolve)

- [ ] **Step 3: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Encounters/EncounterRoll.swift`

```swift
import Foundation

public enum EncounterRoll {
    public static let oneIn = 8
    public static let pityStep = 24

    public static func triggers(
        on tile: TileKind,
        repelStepsLeft: Int,
        stepsSinceEncounter: Int,
        using rng: inout some RandomNumberGenerator
    ) -> Bool {
        guard tile == .cloud else { return false }
        guard repelStepsLeft <= 0 else { return false }
        guard stepsSinceEncounter < pityStep else { return true }
        return rng.next() % UInt64(oneIn) == 0
    }
}
```

- [ ] **Step 4: Run all core tests**

Run: `scripts/test-core.sh`
Expected: `Executed 272 tests, with 0 failures`

- [ ] **Step 5: Commit**

Run: `git add IFRCore/Sources/IFRCore/Adventure/Encounters/EncounterRoll.swift IFRCore/Tests/IFRCoreTests/EncounterRollTests.swift && git commit -m "M2-04: Cloud encounters"`

---

### Task M2-05: Trainers and line of sight

**Files:**
- Create: `IFRCore/Sources/IFRCore/Adventure/Content/Trainer.swift`
- Create: `IFRCore/Sources/IFRCore/Adventure/Overworld/LineOfSight.swift`
- Create: `IFRCore/Sources/IFRCore/Adventure/Overworld/TrainerApproach.swift`
- Modify: `IFRCore/Sources/IFRCore/Adventure/Circuit/AdventureSave.swift`
- Modify: `IFRCore/Sources/IFRCore/Adventure/Content/AdventureContent.swift`
- Test: `IFRCore/Tests/IFRCoreTests/LineOfSightTests.swift`
- Test: `IFRCore/Tests/IFRCoreTests/TrainerApproachTests.swift`
- Test: `IFRCore/Tests/IFRCoreTests/AdventureSaveTests.swift`

**Interfaces:**
- Consumes: `GridPoint` (`Adventure/Pixel/GridPoint.swift`), `Direction` (`Adventure/Overworld/Direction.swift`), `TileKind.blocksSight` (`Adventure/Overworld/TileKind.swift`), `TileMap` and its `subscript(GridPoint) -> TileKind?` (`Adventure/Content/TileMap.swift`), `DialogueRefs` (`Adventure/Content/Gym.swift`), `IFRCore.Category`, `EncounterDeck.draw(count:categories:bank:states:now:using:)` (`Adventure/Encounters/EncounterDeck.swift`), `AdventureSaveError` (`Adventure/Circuit/AdventureSaveError.swift`)
- Produces: `Trainer: Codable, Equatable, Sendable` with `id, name, nameplateName, spriteID, position, facing, range, questionCount, categories, dialogue`; `enum LineOfSight { static func trainerSeeing(_ player: GridPoint, trainers: [Trainer], defeated: Set<String>, in map: TileMap) -> Trainer? }`; `enum TrainerApproach { static func position(from start: GridPoint, toward player: GridPoint, step: Int) -> GridPoint }`; `AdventureSave.defeatedTrainerIDs: Set<String>` (defaults to `[]`, decodes from older saves)

- [ ] **Step 1: Write the failing tests**

File: `IFRCore/Tests/IFRCoreTests/LineOfSightTests.swift`

```swift
import XCTest
@testable import IFRCore

final class LineOfSightTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeTrainer(
        id: String = "student-ana", position: GridPoint, facing: Direction, range: Int = 4,
        categories: [IFRCore.Category] = [.humanFactors], questionCount: Int = 4
    ) -> Trainer {
        Trainer(
            id: id, name: "Student Pilot Ana", nameplateName: "ANA", spriteID: "trainer-student",
            position: position, facing: facing, range: range, questionCount: questionCount,
            categories: categories, dialogue: DialogueRefs(intro: "ana-intro", win: "ana-win", lose: "ana-lose")
        )
    }

    private func makeMap(_ rows: [[TileKind]]) -> TileMap {
        TileMap(width: rows.first?.count ?? 0, height: rows.count, rows: rows)
    }

    private func openMap(width: Int = 6, height: Int = 6) -> TileMap {
        makeMap(Array(repeating: Array(repeating: TileKind.ground, count: width), count: height))
    }

    private func mcQuestion(_ id: String, _ category: IFRCore.Category) -> Question {
        Question(id: id, category: category, acsCodes: ["IR.I.A.K1"], format: .multipleChoice,
                 front: "f", back: "b", options: ["a", "b", "c"], correctIndex: 0, explanation: "e",
                 source: SourceRef(document: "d", section: "s", url: URL(string: "https://faa.gov")!),
                 figure: nil, difficulty: 1)
    }

    func testSeesPlayerWithinRangeAlongFacing() {
        let trainer = makeTrainer(position: GridPoint(x: 1, y: 1), facing: .right, range: 4)
        let seen = LineOfSight.trainerSeeing(GridPoint(x: 3, y: 1), trainers: [trainer], defeated: [], in: openMap())
        XCTAssertEqual(seen, trainer)
    }

    func testDoesNotSeeBehind() {
        let trainer = makeTrainer(position: GridPoint(x: 3, y: 1), facing: .right, range: 4)
        let seen = LineOfSight.trainerSeeing(GridPoint(x: 1, y: 1), trainers: [trainer], defeated: [], in: openMap())
        XCTAssertNil(seen)
    }

    func testTerrainAndBuildingsBlockSight() {
        var rows = Array(repeating: Array(repeating: TileKind.ground, count: 6), count: 6)
        rows[1][2] = .terrain
        let trainer = makeTrainer(position: GridPoint(x: 1, y: 1), facing: .right, range: 4)
        let seen = LineOfSight.trainerSeeing(GridPoint(x: 3, y: 1), trainers: [trainer], defeated: [], in: makeMap(rows))
        XCTAssertNil(seen)
    }

    func testRangeIsInclusive() {
        let trainer = makeTrainer(position: GridPoint(x: 1, y: 1), facing: .right, range: 4)
        let seen = LineOfSight.trainerSeeing(GridPoint(x: 5, y: 1), trainers: [trainer], defeated: [], in: openMap(width: 8))
        XCTAssertEqual(seen, trainer)
    }

    func testDefeatedTrainerNeverSees() {
        let trainer = makeTrainer(position: GridPoint(x: 1, y: 1), facing: .right, range: 4)
        let seen = LineOfSight.trainerSeeing(
            GridPoint(x: 3, y: 1), trainers: [trainer], defeated: [trainer.id], in: openMap()
        )
        XCTAssertNil(seen)
    }

    func testFirstTrainerInPlacementOrderWins() {
        let first = makeTrainer(id: "first", position: GridPoint(x: 1, y: 1), facing: .right, range: 4)
        let second = makeTrainer(id: "second", position: GridPoint(x: 0, y: 1), facing: .right, range: 4)
        let seen = LineOfSight.trainerSeeing(
            GridPoint(x: 3, y: 1), trainers: [first, second], defeated: [], in: openMap()
        )
        XCTAssertEqual(seen, first)
    }

    func testTrainerDeckDrawsFromTrainerCategories() {
        let scheduler = Scheduler()
        let deck = EncounterDeck(scheduler: scheduler)
        let trainer = makeTrainer(position: GridPoint(x: 1, y: 1), facing: .right, categories: [.humanFactors])
        let bank = QuestionBank(version: 1, questions: (0..<6).map { mcQuestion("hf-\($0)", .humanFactors) })
        var rng = SeededRNG(seed: 7)
        let drawn = deck.draw(
            count: trainer.questionCount, categories: trainer.categories, bank: bank,
            states: [:], now: now, using: &rng
        )
        XCTAssertEqual(drawn.count, trainer.questionCount)
        XCTAssertTrue(drawn.allSatisfy { $0.category == .humanFactors })
    }
}
```

File: `IFRCore/Tests/IFRCoreTests/TrainerApproachTests.swift`

```swift
import XCTest
@testable import IFRCore

final class TrainerApproachTests: XCTestCase {
    func testApproachMovesOneTilePerStepAlongFacing() {
        let start = GridPoint(x: 1, y: 1)
        let player = GridPoint(x: 1, y: 10)
        XCTAssertEqual(TrainerApproach.position(from: start, toward: player, step: 0), start)
        XCTAssertEqual(TrainerApproach.position(from: start, toward: player, step: 1), GridPoint(x: 1, y: 2))
        XCTAssertEqual(TrainerApproach.position(from: start, toward: player, step: 2), GridPoint(x: 1, y: 3))
    }

    func testApproachStopsAdjacentToPlayer() {
        let start = GridPoint(x: 1, y: 1)
        let player = GridPoint(x: 1, y: 5)
        let adjacent = GridPoint(x: 1, y: 4)
        XCTAssertEqual(TrainerApproach.position(from: start, toward: player, step: 99), adjacent)
    }
}
```

Modify `IFRCore/Tests/IFRCoreTests/AdventureSaveTests.swift`, adding one test:

```swift
    func testOlderSaveWithoutDefeatedTrainerIDsDecodes() throws {
        let json = "{\"badges\":[]}"
        let decoded = try JSONDecoder().decode(AdventureSave.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.defeatedTrainerIDs, [])
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `scripts/test-core.sh --filter LineOfSightTests`
Expected:
```
error: emit-module command failed with exit code 1 (use -v to see invocation)
/home/user/IFR-build/FlashCards/IFRCore/Sources/IFRCore/Adventure/Content/AdventureContent.swift:33:27: error: cannot find type 'Trainer' in scope
/home/user/IFR-build/FlashCards/IFRCore/Sources/IFRCore/Adventure/Content/AdventureContent.swift:40:45: error: cannot find type 'Trainer' in scope
```
(with the placeholder `Trainer` stub and the new `Trainer.swift`, `LineOfSight.swift` and `TrainerApproach.swift` removed, `AdventureContent.swift` no longer finds `Trainer` and `LineOfSightTests`/`TrainerApproachTests` fail to compile against `LineOfSight` and `TrainerApproach`, which do not exist yet)

- [ ] **Step 3: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Content/Trainer.swift`

```swift
import Foundation

public struct Trainer: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let nameplateName: String
    public let spriteID: String
    public let position: GridPoint
    public let facing: Direction
    public let range: Int
    public let questionCount: Int
    public let categories: [Category]
    public let dialogue: DialogueRefs

    public init(
        id: String, name: String, nameplateName: String, spriteID: String,
        position: GridPoint, facing: Direction, range: Int, questionCount: Int,
        categories: [Category], dialogue: DialogueRefs
    ) {
        self.id = id
        self.name = name
        self.nameplateName = nameplateName
        self.spriteID = spriteID
        self.position = position
        self.facing = facing
        self.range = range
        self.questionCount = questionCount
        self.categories = categories
        self.dialogue = dialogue
    }
}
```

File: `IFRCore/Sources/IFRCore/Adventure/Overworld/LineOfSight.swift`

```swift
import Foundation

public enum LineOfSight {
    public static func trainerSeeing(
        _ player: GridPoint, trainers: [Trainer], defeated: Set<String>, in map: TileMap
    ) -> Trainer? {
        trainers.first { sees($0, player: player, defeated: defeated, in: map) }
    }

    private static func sees(_ trainer: Trainer, player: GridPoint, defeated: Set<String>, in map: TileMap) -> Bool {
        guard !defeated.contains(trainer.id), trainer.range > 0 else { return false }
        let delta = trainer.facing.delta
        var point = trainer.position
        for _ in 1...trainer.range {
            point = GridPoint(x: point.x + delta.x, y: point.y + delta.y)
            if point == player { return true }
            if map[point]?.blocksSight ?? true { return false }
        }
        return false
    }
}
```

File: `IFRCore/Sources/IFRCore/Adventure/Overworld/TrainerApproach.swift`

```swift
import Foundation

public enum TrainerApproach {
    public static func position(from start: GridPoint, toward player: GridPoint, step: Int) -> GridPoint {
        let dx = sign(player.x - start.x)
        let dy = sign(player.y - start.y)
        let distance = abs(player.x - start.x) + abs(player.y - start.y)
        let stepsTaken = min(step, max(distance - 1, 0))
        return GridPoint(x: start.x + dx * stepsTaken, y: start.y + dy * stepsTaken)
    }

    private static func sign(_ value: Int) -> Int {
        value == 0 ? 0 : (value > 0 ? 1 : -1)
    }
}
```

File: `IFRCore/Sources/IFRCore/Adventure/Circuit/AdventureSave.swift` (whole file after this task's change)

```swift
import Foundation

public struct AdventureSave: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public var saveVersion: Int
    public var badges: Set<GymID>
    public var badgeQuestionIDs: [String: [String]]
    public var eliteFourCleared: Bool
    public var championWins: Int
    public var hallOfFame: [Date]
    public var battlesWon: Int
    public var battlesLost: Int
    public var visitedAirportIDs: Set<String>
    public var defeatedTrainerIDs: Set<String>

    public static let new = AdventureSave(
        saveVersion: currentVersion, badges: [], badgeQuestionIDs: [:], eliteFourCleared: false,
        championWins: 0, hallOfFame: [], battlesWon: 0, battlesLost: 0, visitedAirportIDs: [],
        defeatedTrainerIDs: []
    )

    public init(
        saveVersion: Int, badges: Set<GymID>, badgeQuestionIDs: [String: [String]], eliteFourCleared: Bool,
        championWins: Int, hallOfFame: [Date], battlesWon: Int, battlesLost: Int, visitedAirportIDs: Set<String>,
        defeatedTrainerIDs: Set<String> = []
    ) {
        self.saveVersion = saveVersion
        self.badges = badges
        self.badgeQuestionIDs = badgeQuestionIDs
        self.eliteFourCleared = eliteFourCleared
        self.championWins = championWins
        self.hallOfFame = hallOfFame
        self.battlesWon = battlesWon
        self.battlesLost = battlesLost
        self.visitedAirportIDs = visitedAirportIDs
        self.defeatedTrainerIDs = defeatedTrainerIDs
    }

    private enum CodingKeys: String, CodingKey {
        case saveVersion, badges, badgeQuestionIDs, eliteFourCleared, championWins,
             hallOfFame, battlesWon, battlesLost, visitedAirportIDs, defeatedTrainerIDs
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let saveVersion = try container.decodeIfPresent(Int.self, forKey: .saveVersion) ?? Self.currentVersion
        guard saveVersion <= Self.currentVersion else {
            throw AdventureSaveError.newerThanApp(saveVersion)
        }
        self.saveVersion = saveVersion
        self.badges = try container.decodeIfPresent(Set<GymID>.self, forKey: .badges) ?? []
        self.badgeQuestionIDs = try container.decodeIfPresent([String: [String]].self, forKey: .badgeQuestionIDs) ?? [:]
        self.eliteFourCleared = try container.decodeIfPresent(Bool.self, forKey: .eliteFourCleared) ?? false
        self.championWins = try container.decodeIfPresent(Int.self, forKey: .championWins) ?? 0
        self.hallOfFame = try container.decodeIfPresent([Date].self, forKey: .hallOfFame) ?? []
        self.battlesWon = try container.decodeIfPresent(Int.self, forKey: .battlesWon) ?? 0
        self.battlesLost = try container.decodeIfPresent(Int.self, forKey: .battlesLost) ?? 0
        self.visitedAirportIDs = try container.decodeIfPresent(Set<String>.self, forKey: .visitedAirportIDs) ?? []
        self.defeatedTrainerIDs = try container.decodeIfPresent(Set<String>.self, forKey: .defeatedTrainerIDs) ?? []
    }
}
```

Modified `IFRCore/Sources/IFRCore/Adventure/Content/AdventureContent.swift`: the placeholder `Trainer` stub (`public struct Trainer: Codable, Equatable, Sendable { public let id: String }`) is removed, since `Trainer` now lives in `Trainer.swift`; nothing else in the file changes.

- [ ] **Step 4: Run all core tests**

Run: `scripts/test-core.sh`
Expected: `Executed 282 tests, with 0 failures`

- [ ] **Step 5: Commit**

Run: `git add FlashCards/IFRCore/Sources/IFRCore/Adventure/Content/Trainer.swift FlashCards/IFRCore/Sources/IFRCore/Adventure/Overworld/LineOfSight.swift FlashCards/IFRCore/Sources/IFRCore/Adventure/Overworld/TrainerApproach.swift FlashCards/IFRCore/Sources/IFRCore/Adventure/Circuit/AdventureSave.swift FlashCards/IFRCore/Sources/IFRCore/Adventure/Content/AdventureContent.swift FlashCards/IFRCore/Tests/IFRCoreTests/LineOfSightTests.swift FlashCards/IFRCore/Tests/IFRCoreTests/TrainerApproachTests.swift FlashCards/IFRCore/Tests/IFRCoreTests/AdventureSaveTests.swift && git commit -m "M2-05: Trainers and line of sight"`

---

### Task M2-05b: Overworld turn reducer

**Files:**
- Create: `IFRCore/Sources/IFRCore/Adventure/Overworld/OverworldOutcome.swift`
- Create: `IFRCore/Sources/IFRCore/Adventure/Overworld/OverworldTurn.swift`
- Create: `IFRCore/Sources/IFRCore/Adventure/Overworld/Respawn.swift`
- Create: `IFRCore/Sources/IFRCore/Adventure/Overworld/RivalPlanner.swift`
- Create: `IFRCore/Sources/IFRCore/Adventure/Content/RivalSpec.swift`
- Modify: `IFRCore/Sources/IFRCore/Adventure/Content/TileMap.swift`
- Modify: `IFRCore/Sources/IFRCore/Adventure/Circuit/AdventureSave.swift`
- Modify: `IFRCore/Sources/IFRCore/Adventure/Pixel/GridPoint.swift`
- Modify: `IFRCore/Sources/IFRCore/Adventure/Content/AdventureContent.swift`
- Test: `IFRCore/Tests/IFRCoreTests/OverworldTurnTests.swift`
- Test: `IFRCore/Tests/IFRCoreTests/RespawnTests.swift`

**Interfaces:**
- Consumes: `OverworldState.stepping(_:in:blocked:)` and `OverworldEvent` (`Adventure/Overworld/OverworldState.swift`), `EncounterRoll.triggers(on:repelStepsLeft:stepsSinceEncounter:using:)` (`Adventure/Encounters/EncounterRoll.swift`), `LineOfSight.trainerSeeing(_:trainers:defeated:in:)` (`Adventure/Overworld/LineOfSight.swift`), `Trainer` and `DialogueRefs` (`Adventure/Content/Trainer.swift`, `Adventure/Content/Gym.swift`), `TileMap` and `TileKind` (`Adventure/Content/TileMap.swift`, `Adventure/Overworld/TileKind.swift`), `AdventureSave` (`Adventure/Circuit/AdventureSave.swift`), `GridPoint`/`Direction` (`Adventure/Pixel/GridPoint.swift`, `Adventure/Overworld/Direction.swift`), `Category` (`Models/Question.swift`).
- Produces: `OverworldOutcome` (`none, blocked, warp(String), sign(String), pickup(String), encounter(category: Category), sighted(Trainer), rival(encounterIndex: Int)`); `OverworldTurn.advancing(_:direction:save:map:trainers:rival:using:) -> (state: OverworldState, save: AdventureSave, outcome: OverworldOutcome)`, the one per-step reducer the overworld screen will call; `Respawn.placement(save:map:) -> (position: GridPoint, facing: Direction)`; `RivalPlanner.pendingEncounter(at:spec:save:) -> Int?`; `RivalSpec`/`RivalEncounter` content types; `GridPoint.manhattanDistance(to:)`; `TileArea`/`GridRect`/`TileMap.category(at:)`/`TileMap.spawn`; `AdventureSave.position`, `.repelStepsLeft`, `.collectedItemIDs`, `.rivalEncountersDone`.

- [ ] **Step 1: Write the failing tests**

File: `IFRCore/Tests/IFRCoreTests/OverworldTurnTests.swift`

```swift
import XCTest
@testable import IFRCore

final class OverworldTurnTests: XCTestCase {
    private func makeMap(
        _ rows: [[TileKind]],
        doorAirportIDs: [GridPoint: String] = [:],
        signTexts: [GridPoint: String] = [:],
        itemDropItemIDs: [GridPoint: String] = [:],
        areas: [TileArea] = []
    ) -> TileMap {
        TileMap(
            width: rows.first?.count ?? 0, height: rows.count, rows: rows,
            doorAirportIDs: doorAirportIDs, signTexts: signTexts, itemDropItemIDs: itemDropItemIDs,
            areas: areas
        )
    }

    private let ground = TileKind.ground
    private let cloud = TileKind.cloud
    private let door = TileKind.door
    private let sign = TileKind.sign

    private func groundRows(_ width: Int, _ height: Int) -> [[TileKind]] {
        Array(repeating: Array(repeating: ground, count: width), count: height)
    }

    private func makeState(
        x: Int, y: Int, facing: Direction = .down, pendingPath: [GridPoint] = [],
        stepsSinceEncounter: Int = 0, suppressedTrainerID: String? = nil
    ) -> OverworldState {
        OverworldState(
            position: GridPoint(x: x, y: y), facing: facing, pendingPath: pendingPath,
            stepsSinceEncounter: stepsSinceEncounter, suppressedTrainerID: suppressedTrainerID
        )
    }

    private func makeTrainer(
        id: String, position: GridPoint, facing: Direction, range: Int = 3
    ) -> Trainer {
        Trainer(
            id: id, name: "Trainer", nameplateName: "T", spriteID: "trainer-student",
            position: position, facing: facing, range: range, questionCount: 4,
            categories: [.humanFactors], dialogue: DialogueRefs(intro: "i", win: "w", lose: "l")
        )
    }

    private func makeRival(at: GridPoint, afterBadges: Int = 0) -> RivalSpec {
        RivalSpec(
            name: "Skyler", nameplateName: "SKYLER", spriteID: "rival", questionCount: 6,
            encounters: [RivalEncounter(at: at, afterBadges: afterBadges, dialogue: DialogueRefs(intro: "i", win: "w", lose: "l"))]
        )
    }

    func testCloudEncounterClearsPendingPath() {
        var rows = groundRows(3, 3)
        rows[0][1] = cloud
        let map = makeMap(rows, areas: [TileArea(id: "a", category: .weather, rect: GridRect(x: 1, y: 0, w: 1, h: 1))])
        let state = makeState(x: 1, y: 1, pendingPath: [GridPoint(x: 2, y: 2)], stepsSinceEncounter: 23)
        var rng = SeededRNG(seed: 7)
        let result = OverworldTurn.advancing(
            state, direction: .up, save: .new, map: map, trainers: [], rival: nil, using: &rng
        )
        XCTAssertEqual(result.outcome, .encounter(category: .weather))
        XCTAssertEqual(result.state.pendingPath, [])
        XCTAssertEqual(result.state.stepsSinceEncounter, 0)
    }

    func testSightingClearsPendingPath() {
        let map = makeMap(groundRows(3, 3))
        let trainer = makeTrainer(id: "t1", position: GridPoint(x: 2, y: 2), facing: .left, range: 2)
        let state = makeState(x: 1, y: 1, facing: .right, pendingPath: [GridPoint(x: 2, y: 2)])
        var rng = SeededRNG(seed: 7)
        let result = OverworldTurn.advancing(
            state, direction: .down, save: .new, map: map, trainers: [trainer], rival: nil, using: &rng
        )
        XCTAssertEqual(result.outcome, .sighted(trainer))
        XCTAssertEqual(result.state.pendingPath, [])
    }

    func testRepelDecrementsPerStepAndFreezesPityCounter() {
        var rows = groundRows(3, 3)
        rows[0][1] = cloud
        let map = makeMap(rows)
        let state = makeState(x: 1, y: 1, stepsSinceEncounter: 10)
        var save = AdventureSave.new
        save.repelStepsLeft = 5
        var rng = SeededRNG(seed: 7)
        let result = OverworldTurn.advancing(
            state, direction: .up, save: save, map: map, trainers: [], rival: nil, using: &rng
        )
        XCTAssertEqual(result.save.repelStepsLeft, 4)
        XCTAssertEqual(result.state.stepsSinceEncounter, 10)
        XCTAssertEqual(result.outcome, .none)
    }

    func testTriggeredEncounterResetsPityCounter() {
        var rows = groundRows(3, 3)
        rows[0][1] = cloud
        let map = makeMap(rows, areas: [TileArea(id: "a", category: .navigation, rect: GridRect(x: 1, y: 0, w: 1, h: 1))])
        let state = makeState(x: 1, y: 1, stepsSinceEncounter: 23)
        var rng = SeededRNG(seed: 7)
        let result = OverworldTurn.advancing(
            state, direction: .up, save: .new, map: map, trainers: [], rival: nil, using: &rng
        )
        XCTAssertEqual(result.state.stepsSinceEncounter, 0)
        XCTAssertEqual(result.outcome, .encounter(category: .navigation))
    }

    func testNonCloudStepResetsPityCounter() {
        let map = makeMap(groundRows(3, 3))
        let state = makeState(x: 1, y: 1, stepsSinceEncounter: 15)
        var rng = SeededRNG(seed: 7)
        let result = OverworldTurn.advancing(
            state, direction: .up, save: .new, map: map, trainers: [], rival: nil, using: &rng
        )
        XCTAssertEqual(result.state.stepsSinceEncounter, 0)
    }

    func testPickupOutcomeAddsItemToSaveOnce() {
        let map = makeMap(groundRows(3, 3), itemDropItemIDs: [GridPoint(x: 1, y: 0): "potion"])
        let state = makeState(x: 1, y: 1)
        var rng = SeededRNG(seed: 7)
        let first = OverworldTurn.advancing(
            state, direction: .up, save: .new, map: map, trainers: [], rival: nil, using: &rng
        )
        XCTAssertEqual(first.outcome, .pickup("potion"))
        XCTAssertTrue(first.save.collectedItemIDs.contains("potion"))
        let second = OverworldTurn.advancing(
            state, direction: .up, save: first.save, map: map, trainers: [], rival: nil, using: &rng
        )
        XCTAssertEqual(second.outcome, .none)
    }

    func testWarpAndSignPassThrough() {
        var rows = groundRows(3, 3)
        rows[0][1] = door
        rows[1][0] = sign
        let map = makeMap(
            rows,
            doorAirportIDs: [GridPoint(x: 1, y: 0): "KHYP"],
            signTexts: [GridPoint(x: 0, y: 1): "FIELD ELEVATION 8000"]
        )
        var rng = SeededRNG(seed: 7)
        let warpResult = OverworldTurn.advancing(
            makeState(x: 1, y: 1), direction: .up, save: .new, map: map, trainers: [], rival: nil, using: &rng
        )
        XCTAssertEqual(warpResult.outcome, .warp("KHYP"))
        let signResult = OverworldTurn.advancing(
            makeState(x: 1, y: 1), direction: .left, save: .new, map: map, trainers: [], rival: nil, using: &rng
        )
        XCTAssertEqual(signResult.outcome, .sign("FIELD ELEVATION 8000"))
    }

    func testUndefeatedTrainersBlockTheStep() {
        let map = makeMap(groundRows(3, 3))
        let trainer = makeTrainer(id: "t1", position: GridPoint(x: 1, y: 0), facing: .down, range: 0)
        var rng = SeededRNG(seed: 7)
        let blockedResult = OverworldTurn.advancing(
            makeState(x: 1, y: 1), direction: .up, save: .new, map: map, trainers: [trainer], rival: nil, using: &rng
        )
        XCTAssertEqual(blockedResult.outcome, .blocked)
        XCTAssertEqual(blockedResult.state.position, GridPoint(x: 1, y: 1))
        var defeatedSave = AdventureSave.new
        defeatedSave.defeatedTrainerIDs = ["t1"]
        let openResult = OverworldTurn.advancing(
            makeState(x: 1, y: 1), direction: .up, save: defeatedSave, map: map, trainers: [trainer], rival: nil, using: &rng
        )
        XCTAssertEqual(openResult.state.position, GridPoint(x: 1, y: 0))
    }

    func testRivalFiresWhenStepLandsOnOrBesideEncounterTile() {
        let map = makeMap(groundRows(3, 3))
        let rival = makeRival(at: GridPoint(x: 2, y: 2))
        var rng = SeededRNG(seed: 7)
        let result = OverworldTurn.advancing(
            makeState(x: 1, y: 1, facing: .right), direction: .right, save: .new, map: map,
            trainers: [], rival: rival, using: &rng
        )
        XCTAssertEqual(result.outcome, .rival(encounterIndex: 0))
        XCTAssertEqual(result.state.pendingPath, [])
    }

    func testEncounterTakesPrecedenceOverSightingOnTheSameStep() {
        var rows = groundRows(3, 3)
        rows[0][1] = cloud
        let map = makeMap(rows, areas: [TileArea(id: "a", category: .weather, rect: GridRect(x: 1, y: 0, w: 1, h: 1))])
        let trainer = makeTrainer(id: "t1", position: GridPoint(x: 2, y: 0), facing: .left, range: 2)
        let state = makeState(x: 1, y: 1, stepsSinceEncounter: 23)
        var rng = SeededRNG(seed: 7)
        let result = OverworldTurn.advancing(
            state, direction: .up, save: .new, map: map, trainers: [trainer], rival: nil, using: &rng
        )
        XCTAssertEqual(result.outcome, .encounter(category: .weather))
    }

    func testTrainerThatBeatPlayerIsSuppressedUntilOutOfSight() {
        let map = makeMap(groundRows(5, 5))
        let trainer = makeTrainer(id: "t1", position: GridPoint(x: 0, y: 0), facing: .right, range: 3)
        let state = makeState(x: 1, y: 0, facing: .right, suppressedTrainerID: "t1")
        var rng = SeededRNG(seed: 7)
        let stillInSight = OverworldTurn.advancing(
            state, direction: .right, save: .new, map: map, trainers: [trainer], rival: nil, using: &rng
        )
        XCTAssertEqual(stillInSight.state.suppressedTrainerID, "t1")
        XCTAssertEqual(stillInSight.outcome, .none)
        let leavingSight = OverworldTurn.advancing(
            stillInSight.state, direction: .down, save: stillInSight.save, map: map,
            trainers: [trainer], rival: nil, using: &rng
        )
        XCTAssertNil(leavingSight.state.suppressedTrainerID)
        XCTAssertEqual(leavingSight.outcome, .none)
    }
}
```

File: `IFRCore/Tests/IFRCoreTests/RespawnTests.swift`

```swift
import XCTest
@testable import IFRCore

final class RespawnTests: XCTestCase {
    private func makeMap(doorAirportIDs: [GridPoint: String], spawn: GridPoint) -> TileMap {
        TileMap(
            width: 10, height: 10, rows: Array(repeating: Array(repeating: TileKind.ground, count: 10), count: 10),
            doorAirportIDs: doorAirportIDs, spawn: spawn
        )
    }

    func testLossPlacementIsNearestVisitedAirportDoorFacingDown() {
        let map = makeMap(
            doorAirportIDs: [
                GridPoint(x: 0, y: 0): "KHYP",
                GridPoint(x: 8, y: 8): "KGYR",
            ],
            spawn: GridPoint(x: 3, y: 3)
        )
        var save = AdventureSave.new
        save.position = GridPoint(x: 1, y: 1)
        save.visitedAirportIDs = ["KHYP", "KGYR"]
        let placement = Respawn.placement(save: save, map: map)
        XCTAssertEqual(placement.position, GridPoint(x: 0, y: 0))
        XCTAssertEqual(placement.facing, .down)
    }

    func testLossPlacementFallsBackToSpawnWhenNothingVisited() {
        let map = makeMap(doorAirportIDs: [GridPoint(x: 0, y: 0): "KHYP"], spawn: GridPoint(x: 3, y: 2))
        var save = AdventureSave.new
        save.position = GridPoint(x: 1, y: 1)
        save.visitedAirportIDs = []
        let placement = Respawn.placement(save: save, map: map)
        XCTAssertEqual(placement.position, GridPoint(x: 3, y: 2))
        XCTAssertEqual(placement.facing, .down)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `scripts/test-core.sh --filter OverworldTurnTests`
Expected:
```
/home/user/IFR-build/FlashCards/IFRCore/Tests/IFRCoreTests/OverworldTurnTests.swift:10:17: error: cannot find type 'TileArea' in scope
/home/user/IFR-build/FlashCards/IFRCore/Tests/IFRCoreTests/RespawnTests.swift:8:52: error: extra argument 'spawn' in call
/home/user/IFR-build/FlashCards/IFRCore/Tests/IFRCoreTests/RespawnTests.swift:21:14: error: value of type 'AdventureSave' has no member 'position'
/home/user/IFR-build/FlashCards/IFRCore/Tests/IFRCoreTests/RespawnTests.swift:23:25: error: cannot find 'Respawn' in scope
```
(Captured by temporarily reverting `TileMap.swift`, `AdventureSave.swift`, `AdventureContent.swift` and `GridPoint.swift` to their pre-task committed versions and removing the new `Overworld`/`RivalSpec` files before running the filtered suite; restored immediately afterward.)

- [ ] **Step 3: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Overworld/OverworldOutcome.swift`

```swift
import Foundation

public enum OverworldOutcome: Equatable, Sendable {
    case none
    case blocked
    case warp(String)
    case sign(String)
    case pickup(String)
    case encounter(category: Category)
    case sighted(Trainer)
    case rival(encounterIndex: Int)
}
```

- [ ] **Step 4: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Overworld/OverworldTurn.swift`

```swift
import Foundation

public enum OverworldTurn {
    public static func advancing(
        _ state: OverworldState, direction: Direction, save: AdventureSave, map: TileMap,
        trainers: [Trainer], rival: RivalSpec?, using rng: inout some RandomNumberGenerator
    ) -> (state: OverworldState, save: AdventureSave, outcome: OverworldOutcome) {
        let blocked = blockedPositions(trainers: trainers, defeated: save.defeatedTrainerIDs)
        let (stepped, event) = state.stepping(direction, in: map, blocked: blocked)
        guard stepped.position != state.position else {
            return (stepped, save, mapped(event))
        }
        return advancingMoved(from: state, stepped: stepped, event: event, save: save, map: map, trainers: trainers, rival: rival, using: &rng)
    }

    private static func advancingMoved(
        from previous: OverworldState, stepped: OverworldState, event: OverworldEvent, save: AdventureSave,
        map: TileMap, trainers: [Trainer], rival: RivalSpec?, using rng: inout some RandomNumberGenerator
    ) -> (state: OverworldState, save: AdventureSave, outcome: OverworldOutcome) {
        var nextSave = save
        let wasRepelled = nextSave.repelStepsLeft > 0
        nextSave.repelStepsLeft = max(0, nextSave.repelStepsLeft - 1)
        var nextState = stepped
        let tile = map[stepped.position] ?? .ground
        nextState.stepsSinceEncounter = pityCount(tile: tile, wasRepelled: wasRepelled, previous: previous.stepsSinceEncounter)

        if EncounterRoll.triggers(
            on: tile, repelStepsLeft: nextSave.repelStepsLeft, stepsSinceEncounter: nextState.stepsSinceEncounter, using: &rng
        ) {
            nextState.stepsSinceEncounter = 0
            nextState.pendingPath = []
            let category = map.category(at: stepped.position) ?? .humanFactors
            return (nextState, nextSave, .encounter(category: category))
        }
        if let rival, let index = RivalPlanner.pendingEncounter(at: nextState.position, spec: rival, save: nextSave) {
            nextState.pendingPath = []
            return (nextState, nextSave, .rival(encounterIndex: index))
        }
        if let trainer = sighting(state: &nextState, trainers: trainers, defeated: nextSave.defeatedTrainerIDs, in: map) {
            nextState.pendingPath = []
            return (nextState, nextSave, .sighted(trainer))
        }
        return resolved(event, state: nextState, save: nextSave)
    }

    private static func blockedPositions(trainers: [Trainer], defeated: Set<String>) -> Set<GridPoint> {
        Set(trainers.filter { !defeated.contains($0.id) }.map(\.position))
    }

    private static func pityCount(tile: TileKind, wasRepelled: Bool, previous: Int) -> Int {
        guard tile == .cloud else { return 0 }
        guard !wasRepelled else { return previous }
        return previous + 1
    }

    private static func sighting(
        state: inout OverworldState, trainers: [Trainer], defeated: Set<String>, in map: TileMap
    ) -> Trainer? {
        if let suppressedID = state.suppressedTrainerID,
           let suppressedTrainer = trainers.first(where: { $0.id == suppressedID }),
           LineOfSight.trainerSeeing(state.position, trainers: [suppressedTrainer], defeated: defeated, in: map) == nil {
            state.suppressedTrainerID = nil
        }
        let excluded = state.suppressedTrainerID.map { defeated.union([$0]) } ?? defeated
        return LineOfSight.trainerSeeing(state.position, trainers: trainers, defeated: excluded, in: map)
    }

    private static func resolved(
        _ event: OverworldEvent, state: OverworldState, save: AdventureSave
    ) -> (state: OverworldState, save: AdventureSave, outcome: OverworldOutcome) {
        guard case .pickup(let itemID) = event else {
            return (state, save, mapped(event))
        }
        guard !save.collectedItemIDs.contains(itemID) else {
            return (state, save, .none)
        }
        var updatedSave = save
        updatedSave.collectedItemIDs.insert(itemID)
        return (state, updatedSave, .pickup(itemID))
    }

    private static func mapped(_ event: OverworldEvent) -> OverworldOutcome {
        switch event {
        case .none: .none
        case .blocked: .blocked
        case .warp(let id): .warp(id)
        case .sign(let text): .sign(text)
        case .pickup(let id): .pickup(id)
        case .cloud: .none
        }
    }
}
```

- [ ] **Step 5: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Overworld/Respawn.swift`

```swift
import Foundation

public enum Respawn {
    public static func placement(save: AdventureSave, map: TileMap) -> (position: GridPoint, facing: Direction) {
        guard let origin = save.position, let nearest = nearestVisitedDoor(save: save, map: map, from: origin) else {
            return (map.spawn, .down)
        }
        return (nearest, .down)
    }

    private static func nearestVisitedDoor(save: AdventureSave, map: TileMap, from origin: GridPoint) -> GridPoint? {
        let visitedDoors = map.doorAirportIDs.filter { save.visitedAirportIDs.contains($0.value) }.map(\.key)
        return visitedDoors.min { lhs, rhs in
            let leftDistance = lhs.manhattanDistance(to: origin)
            let rightDistance = rhs.manhattanDistance(to: origin)
            if leftDistance != rightDistance { return leftDistance < rightDistance }
            if lhs.y != rhs.y { return lhs.y < rhs.y }
            return lhs.x < rhs.x
        }
    }
}
```

- [ ] **Step 6: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Overworld/RivalPlanner.swift`

```swift
import Foundation

public enum RivalPlanner {
    public static func pendingEncounter(at position: GridPoint, spec: RivalSpec, save: AdventureSave) -> Int? {
        spec.encounters.enumerated().first { index, encounter in
            position.manhattanDistance(to: encounter.at) <= 1
                && save.badges.count >= encounter.afterBadges
                && !save.rivalEncountersDone.contains(index)
        }?.offset
    }
}
```

- [ ] **Step 7: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Content/RivalSpec.swift` (new; `RivalSpec` previously existed only as an empty `{}` decoding stub inline in `AdventureContent.swift`, so this replaces that stub with the fields M2-05b's rival test needs — full validation and `RivalPlanner.weakestCategories` are left for M2-07)

```swift
import Foundation

public struct RivalEncounter: Codable, Equatable, Sendable {
    public let at: GridPoint
    public let afterBadges: Int
    public let dialogue: DialogueRefs

    public init(at: GridPoint, afterBadges: Int, dialogue: DialogueRefs) {
        self.at = at
        self.afterBadges = afterBadges
        self.dialogue = dialogue
    }
}

public struct RivalSpec: Codable, Equatable, Sendable {
    public let name: String
    public let nameplateName: String
    public let spriteID: String
    public let questionCount: Int
    public let encounters: [RivalEncounter]

    public init(name: String, nameplateName: String, spriteID: String, questionCount: Int, encounters: [RivalEncounter]) {
        self.name = name
        self.nameplateName = nameplateName
        self.spriteID = spriteID
        self.questionCount = questionCount
        self.encounters = encounters
    }
}
```

Modify: `IFRCore/Sources/IFRCore/Adventure/Content/AdventureContent.swift` — the inline empty stub is removed since `RivalSpec` now lives in its own file:

```swift
public struct CompanionSpecies: Codable, Equatable, Sendable {}
```

- [ ] **Step 8: Modify TileMap for cloud areas and spawn**

File: `IFRCore/Sources/IFRCore/Adventure/Content/TileMap.swift` — `spawn` and `areas` are pulled forward from M2-08 because `OverworldTurn` needs `map.category(at:)` for `.encounter(category:)` and `Respawn` needs `map.spawn`; the rest of the file (decode/encode of rows, warps, signs, item drops, the subscript) is unchanged from the M2-01 version:

```swift
public struct GridRect: Codable, Equatable, Sendable {
    public let x: Int
    public let y: Int
    public let w: Int
    public let h: Int

    public init(x: Int, y: Int, w: Int, h: Int) {
        self.x = x
        self.y = y
        self.w = w
        self.h = h
    }

    public func contains(_ point: GridPoint) -> Bool {
        point.x >= x && point.x < x + w && point.y >= y && point.y < y + h
    }
}

public struct TileArea: Codable, Equatable, Sendable {
    public let id: String
    public let category: Category
    public let rect: GridRect

    public init(id: String, category: Category, rect: GridRect) {
        self.id = id
        self.category = category
        self.rect = rect
    }
}
```

`TileMap` gains two stored properties, matching new coding keys `spawn` and `areas` (both `decodeIfPresent` with defaults so earlier fixtures without them still decode), a widened `init` with defaulted `spawn`/`areas` parameters so every earlier call site still compiles, and a new method:

```swift
    public let spawn: GridPoint
    public let areas: [TileArea]
```

```swift
    public func category(at point: GridPoint) -> Category? {
        areas.first { $0.rect.contains(point) }?.category
    }
```

- [ ] **Step 9: Modify AdventureSave for the fields OverworldTurn and Respawn need**

File: `IFRCore/Sources/IFRCore/Adventure/Circuit/AdventureSave.swift` — `position`, `repelStepsLeft`, `collectedItemIDs` and `rivalEncountersDone` are pulled forward from M2-06/M2-07/M2-09a because `OverworldTurn.advancing` and `Respawn.placement` need them now; each is `decodeIfPresent` with a default so a save blob missing them still decodes (`testDecodingOlderSaveMissingKeysUsesDefaults` and `testOlderSaveWithoutDefeatedTrainerIDsDecodes` in the existing `AdventureSaveTests` stay green). The rest of the type (`badges`, `badgeQuestionIDs`, `championWins`, `hallOfFame`, `battlesWon`/`battlesLost`, `visitedAirportIDs`, `defeatedTrainerIDs`, `saveVersion`/`AdventureSaveError` handling) is unchanged from the M2-05 version:

```swift
    public var collectedItemIDs: Set<String>
    public var repelStepsLeft: Int
    public var position: GridPoint?
    public var rivalEncountersDone: Set<Int>
```

```swift
    public static let new = AdventureSave(
        saveVersion: currentVersion, badges: [], badgeQuestionIDs: [:], eliteFourCleared: false,
        championWins: 0, hallOfFame: [], battlesWon: 0, battlesLost: 0, visitedAirportIDs: [],
        defeatedTrainerIDs: [], collectedItemIDs: [], repelStepsLeft: 0, position: nil,
        rivalEncountersDone: []
    )
```

```swift
        self.collectedItemIDs = try container.decodeIfPresent(Set<String>.self, forKey: .collectedItemIDs) ?? []
        self.repelStepsLeft = try container.decodeIfPresent(Int.self, forKey: .repelStepsLeft) ?? 0
        self.position = try container.decodeIfPresent(GridPoint.self, forKey: .position)
        self.rivalEncountersDone = try container.decodeIfPresent(Set<Int>.self, forKey: .rivalEncountersDone) ?? []
```

- [ ] **Step 10: Modify GridPoint for Manhattan distance**

File: `IFRCore/Sources/IFRCore/Adventure/Pixel/GridPoint.swift` — one small method added, used by both `Respawn` and `RivalPlanner`:

```swift
    public func manhattanDistance(to other: GridPoint) -> Int {
        abs(x - other.x) + abs(y - other.y)
    }
```

- [ ] **Step 11: Run all core tests**

Run: `scripts/test-core.sh`
Expected: `Executed 295 tests, with 0 failures (0 unexpected) in 0.798 (0.798) seconds`

- [ ] **Step 12: Commit**

Run: `git add FlashCards/IFRCore/Sources/IFRCore/Adventure/Overworld/OverworldOutcome.swift FlashCards/IFRCore/Sources/IFRCore/Adventure/Overworld/OverworldTurn.swift FlashCards/IFRCore/Sources/IFRCore/Adventure/Overworld/Respawn.swift FlashCards/IFRCore/Sources/IFRCore/Adventure/Overworld/RivalPlanner.swift FlashCards/IFRCore/Sources/IFRCore/Adventure/Content/RivalSpec.swift FlashCards/IFRCore/Sources/IFRCore/Adventure/Content/TileMap.swift FlashCards/IFRCore/Sources/IFRCore/Adventure/Circuit/AdventureSave.swift FlashCards/IFRCore/Sources/IFRCore/Adventure/Pixel/GridPoint.swift FlashCards/IFRCore/Sources/IFRCore/Adventure/Content/AdventureContent.swift FlashCards/IFRCore/Tests/IFRCoreTests/OverworldTurnTests.swift FlashCards/IFRCore/Tests/IFRCoreTests/RespawnTests.swift && git commit -m "M2-05b: Overworld turn reducer"`

**Deviations from spec:**
- The spec's `Files` line for M2-05b lists only `OverworldTurn.swift`, `OverworldOutcome.swift` and `Respawn.swift`, but the per-step algorithm in section 2.6 (and the work item's own test list) needs types and `AdventureSave`/`TileMap` fields the spec assigns to later items: `AdventureSave.repelStepsLeft`/`collectedItemIDs` (M2-06), `AdventureSave.rivalEncountersDone` and a populated `RivalSpec` (M2-07), `AdventureSave.position` (M2-09a), and `TileMap.spawn`/`areas` plus `TileMap.category(at:)` (M2-08 content). Each was pulled forward as the smallest field/type addition that lets `OverworldTurn.advancing` and `Respawn.placement` compile and pass their own tests, decoded with `decodeIfPresent`/defaults so no existing test or save blob breaks; the later work items are expected to build on these rather than redefine them.
- `RivalSpec` (previously an empty `Codable` stub used only so `AdventureContent` could decode a `rival` key) now carries `name`, `nameplateName`, `spriteID`, `questionCount` and `encounters: [RivalEncounter]`. `RivalPlanner` was added with only `pendingEncounter(at:spec:save:)`; `RivalPlanner.weakestCategories` from section 2.4 is left for M2-07, which owns the rival's deck-drawing behavior.
- The spec's implementation note says `.pickup` "runs `Inventory.adding`", but `Inventory.swift` is M2-06's file and does not exist yet. `OverworldTurn` instead inserts the item id into `AdventureSave.collectedItemIDs` directly; M2-06 can route this through `Inventory.adding` once that type exists without changing `OverworldTurn`'s outward behavior.
- `GridPoint` gained `manhattanDistance(to:)`, a small helper shared by `Respawn` and `RivalPlanner`, since GridPoint carried no distance helper before this task.

---

### Task M2-06: Items and inventory (Linux)

**Files:**
- Create: `IFRCore/Sources/IFRCore/Adventure/Overworld/Inventory.swift`
- Create: `IFRCore/Sources/IFRCore/Adventure/Overworld/DirectTo.swift`
- Modify: `IFRCore/Sources/IFRCore/Adventure/Battle/BattleEngine.swift`
- Modify: `IFRCore/Sources/IFRCore/Adventure/Circuit/AdventureSave.swift`
- Test: `IFRCore/Tests/IFRCoreTests/ItemTests.swift`
- Test: `IFRCore/Tests/IFRCoreTests/DirectToTests.swift`
- Test: `IFRCore/Tests/IFRCoreTests/AdventureSaveTests.swift`

**Interfaces:**
- Consumes: `AdventureSave` (`IFRCore/Sources/IFRCore/Adventure/Circuit/AdventureSave.swift`), `ItemEffect` (`IFRCore/Sources/IFRCore/Adventure/Content/Item.swift`), `BattleState`, `BattleEvent` (`IFRCore/Sources/IFRCore/Adventure/Battle/BattleState.swift`), `BattleEngine.answer`/`start`/`forfeit` (`IFRCore/Sources/IFRCore/Adventure/Battle/BattleEngine.swift`), `Airport`, `RegionMap` (`IFRCore/Sources/IFRCore/Adventure/Content/RegionMap.swift`), `TileMap.doorAirportIDs` (`IFRCore/Sources/IFRCore/Adventure/Content/TileMap.swift`), `GridPoint` (`IFRCore/Sources/IFRCore/Adventure/Pixel/GridPoint.swift`), `OverworldTurn.advancing` (`IFRCore/Sources/IFRCore/Adventure/Overworld/OverworldTurn.swift`), which already decrements `AdventureSave.repelStepsLeft` by one on every moved step.
- Produces: `enum Inventory { static func adding(_ itemID: String, to save: AdventureSave) -> AdventureSave; static func using(_ itemID: String, from save: AdventureSave) -> AdventureSave?; static func applying(_ effect: ItemEffect, to save: AdventureSave) -> AdventureSave }`; `enum DirectTo { static func targets(save: AdventureSave, region: RegionMap) -> [Airport]; static func destination(of airport: Airport, in map: TileMap) -> GridPoint? }`; `BattleEngine.useItem(_ state: BattleState, effect: ItemEffect) -> BattleState`; `AdventureSave.inventory: [String: Int]` (a later task's `StudyStore.drawEncounterDeck`/`BagSheet` and M2-07's rival work use these).

- [ ] **Step 1: Write the failing tests**

File: `IFRCore/Tests/IFRCoreTests/ItemTests.swift`

```swift
import XCTest
@testable import IFRCore

final class ItemTests: XCTestCase {
    private func opponent(tier: BattleTier = .gym, maxHP: Int = 100) -> Opponent {
        Opponent(id: "opp", name: "Opp", nameplateName: "OPP", spriteID: "s", tier: tier, maxHP: maxHP)
    }

    private func mcQuestion(_ id: String, _ category: IFRCore.Category, difficulty: Int = 1) -> Question {
        Question(id: id, category: category, acsCodes: ["IR.I.A.K1"], format: .multipleChoice,
                 front: "f", back: "b", options: ["a", "b", "c"], correctIndex: 0, explanation: "e",
                 source: SourceRef(document: "d", section: "s", url: URL(string: "https://faa.gov")!),
                 figure: nil, difficulty: difficulty)
    }

    private func deck(_ count: Int) -> [Question] {
        (0..<count).map { mcQuestion("q\($0)", .weather) }
    }

    private func state(playerHP: Int = 100, playerMaxHP: Int = 100, reviveArmed: Bool = false, cursor: Int = 0) -> BattleState {
        BattleState(
            opponent: opponent(), deck: deck(3), cursor: cursor, playerHP: playerHP, playerMaxHP: playerMaxHP,
            opponentHP: 100, missDamage: 30, reviveArmed: reviveArmed, results: [], turns: [], outcome: nil
        )
    }

    func testPotionHealsThirtyCappedAtMax() {
        let healed = BattleEngine.useItem(state(playerHP: 90), effect: .heal(30))
        XCTAssertEqual(healed.playerHP, 100)
    }

    func testReviveOnceArmsFlagWithoutHealing() {
        let armed = BattleEngine.useItem(state(playerHP: 80), effect: .reviveOnce)
        XCTAssertTrue(armed.reviveArmed)
        XCTAssertEqual(armed.playerHP, 80)
    }

    func testArmedReviveRestoresHalfHPOnFatalMissAndEmitsRevived() {
        let armed = BattleEngine.useItem(state(playerHP: 10), effect: .reviveOnce)
        let (next, events) = BattleEngine.answer(armed, selectedIndex: 1, answerSeconds: 10)
        XCTAssertEqual(next.playerHP, 50)
        XCTAssertTrue(events.contains(.revived(50)))
        XCTAssertFalse(next.reviveArmed)
    }

    func testSecondReviveInOneBattleIsNoOp() {
        let armed = BattleEngine.useItem(state(playerHP: 80, reviveArmed: true), effect: .reviveOnce)
        XCTAssertTrue(armed.reviveArmed)
        XCTAssertEqual(armed.playerHP, 80)
    }

    func testUseItemNeverAdvancesCursor() {
        let healed = BattleEngine.useItem(state(cursor: 1), effect: .heal(10))
        XCTAssertEqual(healed.cursor, 1)
    }

    func testItemUseNeverChangesDeckResultsOrGrades() {
        let start = state()
        let after = BattleEngine.useItem(start, effect: .heal(10))
        XCTAssertEqual(after.results, [])
        XCTAssertEqual(after.turns, [])
        XCTAssertEqual(after.deck, start.deck)
    }

    func testUseItemIgnoresOverworldEffects() {
        let start = state(playerHP: 80)
        let afterRepel = BattleEngine.useItem(start, effect: .repel(steps: 50))
        let afterDirect = BattleEngine.useItem(start, effect: .directTo)
        XCTAssertEqual(afterRepel, start)
        XCTAssertEqual(afterDirect, start)
    }

    func testPickupAddsToInventoryOnce() {
        let save = Inventory.adding("potion", to: .new)
        XCTAssertEqual(save.inventory["potion"], 1)
    }

    func testUsingItemConsumesOne() {
        var save = Inventory.adding("potion", to: .new)
        save = Inventory.adding("potion", to: save)
        let used = Inventory.using("potion", from: save)
        XCTAssertEqual(used?.inventory["potion"], 1)
    }

    func testUsingMissingItemIsNil() {
        XCTAssertNil(Inventory.using("potion", from: .new))
    }

    func testRepelSetsFiftyStepsAndDecrementsPerStep() {
        let save = Inventory.applying(.repel(steps: 50), to: .new)
        XCTAssertEqual(save.repelStepsLeft, 50)
        let map = TileMap(
            width: 3, height: 3,
            rows: [
                [.ground, .ground, .ground],
                [.ground, .ground, .ground],
                [.ground, .ground, .ground],
            ],
            spawn: GridPoint(x: 1, y: 1)
        )
        let overworldState = OverworldState(position: GridPoint(x: 1, y: 1), facing: .down)
        var rng = SeededRNG(seed: 7)
        let result = OverworldTurn.advancing(
            overworldState, direction: .up, save: save, map: map, trainers: [], rival: nil, using: &rng
        )
        XCTAssertEqual(result.save.repelStepsLeft, 49)
    }
}
```

File: `IFRCore/Tests/IFRCoreTests/DirectToTests.swift`

```swift
import XCTest
@testable import IFRCore

final class DirectToTests: XCTestCase {
    private func airport(_ id: String, role: AirportRole = .waypoint) -> Airport {
        Airport(id: id, name: id, position: GridPoint(x: 0, y: 0), gymID: nil, role: role)
    }

    func testDirectToOnlyTargetsVisitedAirports() {
        let region = RegionMap(
            airports: [airport("KHYP"), airport("KGYR"), airport("KELF")],
            airways: []
        )
        var save = AdventureSave.new
        save.visitedAirportIDs = ["KGYR", "KHYP"]
        let targets = DirectTo.targets(save: save, region: region)
        XCTAssertEqual(targets.map(\.id), ["KHYP", "KGYR"])
    }

    func testDirectToDestinationIsTheAirportDoorTile() {
        let map = TileMap(
            width: 1, height: 1, rows: [[.door]],
            doorAirportIDs: [GridPoint(x: 0, y: 0): "KHYP"]
        )
        let destination = DirectTo.destination(of: airport("KHYP"), in: map)
        XCTAssertEqual(destination, GridPoint(x: 0, y: 0))
    }
}
```

File: `IFRCore/Tests/IFRCoreTests/AdventureSaveTests.swift` (test added)

```swift
    func testOlderSaveWithoutInventoryDecodes() throws {
        let json = "{\"badges\":[]}"
        let decoded = try JSONDecoder().decode(AdventureSave.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.inventory, [:])
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `scripts/test-core.sh --filter ItemTests`
Expected:
```
DirectToTests.swift:16:23: error: cannot find 'DirectTo' in scope
ItemTests.swift:90:63: error: cannot infer contextual base in reference to member 'repel'
error: fatalError
```
(compile failure: `Inventory`, `DirectTo` and `BattleEngine.useItem` did not exist yet, and `AdventureSave` had no `inventory` field.)

- [ ] **Step 3: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Overworld/Inventory.swift`

```swift
import Foundation

public enum Inventory {
    public static func adding(_ itemID: String, to save: AdventureSave) -> AdventureSave {
        var next = save
        next.inventory[itemID, default: 0] += 1
        return next
    }

    public static func using(_ itemID: String, from save: AdventureSave) -> AdventureSave? {
        guard let count = save.inventory[itemID], count > 0 else { return nil }
        var next = save
        if count == 1 {
            next.inventory.removeValue(forKey: itemID)
        } else {
            next.inventory[itemID] = count - 1
        }
        return next
    }

    public static func applying(_ effect: ItemEffect, to save: AdventureSave) -> AdventureSave {
        guard case .repel(let steps) = effect else { return save }
        var next = save
        next.repelStepsLeft = steps
        return next
    }
}
```

File: `IFRCore/Sources/IFRCore/Adventure/Overworld/DirectTo.swift`

```swift
import Foundation

public enum DirectTo {
    public static func targets(save: AdventureSave, region: RegionMap) -> [Airport] {
        region.airports.filter { save.visitedAirportIDs.contains($0.id) }
    }

    public static func destination(of airport: Airport, in map: TileMap) -> GridPoint? {
        map.doorAirportIDs.first { $0.value == airport.id }?.key
    }
}
```

- [ ] **Step 4: Modify `IFRCore/Sources/IFRCore/Adventure/Battle/BattleEngine.swift`**

New `useItem` function added to `BattleEngine`:

```swift
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
```

- [ ] **Step 5: Modify `IFRCore/Sources/IFRCore/Adventure/Circuit/AdventureSave.swift`**

Complete new version of the type, with the added `inventory: [String: Int]` field threaded through the stored property, `.new`, the memberwise `init`, `CodingKeys` and the custom `init(from:)`:

```swift
import Foundation

public struct AdventureSave: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public var saveVersion: Int
    public var badges: Set<GymID>
    public var badgeQuestionIDs: [String: [String]]
    public var eliteFourCleared: Bool
    public var championWins: Int
    public var hallOfFame: [Date]
    public var battlesWon: Int
    public var battlesLost: Int
    public var visitedAirportIDs: Set<String>
    public var defeatedTrainerIDs: Set<String>
    public var collectedItemIDs: Set<String>
    public var inventory: [String: Int]
    public var repelStepsLeft: Int
    public var position: GridPoint?
    public var rivalEncountersDone: Set<Int>

    public static let new = AdventureSave(
        saveVersion: currentVersion, badges: [], badgeQuestionIDs: [:], eliteFourCleared: false,
        championWins: 0, hallOfFame: [], battlesWon: 0, battlesLost: 0, visitedAirportIDs: [],
        defeatedTrainerIDs: [], collectedItemIDs: [], inventory: [:], repelStepsLeft: 0, position: nil,
        rivalEncountersDone: []
    )

    public init(
        saveVersion: Int, badges: Set<GymID>, badgeQuestionIDs: [String: [String]], eliteFourCleared: Bool,
        championWins: Int, hallOfFame: [Date], battlesWon: Int, battlesLost: Int, visitedAirportIDs: Set<String>,
        defeatedTrainerIDs: Set<String> = [], collectedItemIDs: Set<String> = [], inventory: [String: Int] = [:],
        repelStepsLeft: Int = 0, position: GridPoint? = nil, rivalEncountersDone: Set<Int> = []
    ) {
        self.saveVersion = saveVersion
        self.badges = badges
        self.badgeQuestionIDs = badgeQuestionIDs
        self.eliteFourCleared = eliteFourCleared
        self.championWins = championWins
        self.hallOfFame = hallOfFame
        self.battlesWon = battlesWon
        self.battlesLost = battlesLost
        self.visitedAirportIDs = visitedAirportIDs
        self.defeatedTrainerIDs = defeatedTrainerIDs
        self.collectedItemIDs = collectedItemIDs
        self.inventory = inventory
        self.repelStepsLeft = repelStepsLeft
        self.position = position
        self.rivalEncountersDone = rivalEncountersDone
    }

    private enum CodingKeys: String, CodingKey {
        case saveVersion, badges, badgeQuestionIDs, eliteFourCleared, championWins,
             hallOfFame, battlesWon, battlesLost, visitedAirportIDs, defeatedTrainerIDs,
             collectedItemIDs, inventory, repelStepsLeft, position, rivalEncountersDone
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let saveVersion = try container.decodeIfPresent(Int.self, forKey: .saveVersion) ?? Self.currentVersion
        guard saveVersion <= Self.currentVersion else {
            throw AdventureSaveError.newerThanApp(saveVersion)
        }
        self.saveVersion = saveVersion
        self.badges = try container.decodeIfPresent(Set<GymID>.self, forKey: .badges) ?? []
        self.badgeQuestionIDs = try container.decodeIfPresent([String: [String]].self, forKey: .badgeQuestionIDs) ?? [:]
        self.eliteFourCleared = try container.decodeIfPresent(Bool.self, forKey: .eliteFourCleared) ?? false
        self.championWins = try container.decodeIfPresent(Int.self, forKey: .championWins) ?? 0
        self.hallOfFame = try container.decodeIfPresent([Date].self, forKey: .hallOfFame) ?? []
        self.battlesWon = try container.decodeIfPresent(Int.self, forKey: .battlesWon) ?? 0
        self.battlesLost = try container.decodeIfPresent(Int.self, forKey: .battlesLost) ?? 0
        self.visitedAirportIDs = try container.decodeIfPresent(Set<String>.self, forKey: .visitedAirportIDs) ?? []
        self.defeatedTrainerIDs = try container.decodeIfPresent(Set<String>.self, forKey: .defeatedTrainerIDs) ?? []
        self.collectedItemIDs = try container.decodeIfPresent(Set<String>.self, forKey: .collectedItemIDs) ?? []
        self.inventory = try container.decodeIfPresent([String: Int].self, forKey: .inventory) ?? [:]
        self.repelStepsLeft = try container.decodeIfPresent(Int.self, forKey: .repelStepsLeft) ?? 0
        self.position = try container.decodeIfPresent(GridPoint.self, forKey: .position)
        self.rivalEncountersDone = try container.decodeIfPresent(Set<Int>.self, forKey: .rivalEncountersDone) ?? []
    }
}
```

- [ ] **Step 6: Run all core tests**

Run: `scripts/test-core.sh`
Expected: `Executed 309 tests, with 0 failures`

- [ ] **Step 7: Commit**

Run: `git add IFRCore/Sources/IFRCore/Adventure/Overworld/Inventory.swift IFRCore/Sources/IFRCore/Adventure/Overworld/DirectTo.swift IFRCore/Sources/IFRCore/Adventure/Battle/BattleEngine.swift IFRCore/Sources/IFRCore/Adventure/Circuit/AdventureSave.swift IFRCore/Tests/IFRCoreTests/ItemTests.swift IFRCore/Tests/IFRCoreTests/DirectToTests.swift IFRCore/Tests/IFRCoreTests/AdventureSaveTests.swift && git commit -m "M2-06: Items and inventory"`

---

### Task M2-07: Rival

**Files:**
- Modify: `IFRCore/Sources/IFRCore/Adventure/Overworld/RivalPlanner.swift`
- Modify: `IFRCore/Sources/IFRCore/Adventure/Content/RivalSpec.swift`
- Test: `IFRCore/Tests/IFRCoreTests/RivalPlannerTests.swift`
- Test: `IFRCore/Tests/IFRCoreTests/AdventureSaveTests.swift`

**Interfaces:**
- Consumes: `Category`, `Category.examWeight` (`IFRCore/Sources/IFRCore/Models/Question.swift`); `GymID.allCases`, `GymID.category` (`IFRCore/Sources/IFRCore/Adventure/Circuit/GymID.swift`); `AdventureSave.badges`, `AdventureSave.rivalEncountersDone` (`IFRCore/Sources/IFRCore/Adventure/Circuit/AdventureSave.swift`); `GridPoint.manhattanDistance(to:)` (`IFRCore/Sources/IFRCore/Adventure/Pixel/GridPoint.swift`); `Opponent`, `BattleTier` (`IFRCore/Sources/IFRCore/Adventure/Battle/Opponent.swift`, `BattleTier.swift`); `XPEngine.points(for:)` (`IFRCore/Sources/IFRCore/Gamification/XPEngine.swift`); `EncounterDeck.draw(count:categories:bank:states:now:using:)` (`IFRCore/Sources/IFRCore/Adventure/Encounters/EncounterDeck.swift`); `Pathfinder.path(from:to:in:blocked:)` (`IFRCore/Sources/IFRCore/Adventure/Overworld/Pathfinder.swift`)
- Produces: `RivalPlanner.weakestCategories(count: Int, retention: [Category: Double]) -> [Category]`; `RivalSpec.opponent(maxHP: Int) -> Opponent` (tier `.trainer`, id `"rival"`)

- [ ] **Step 1: Write the failing tests**

File: `IFRCore/Tests/IFRCoreTests/RivalPlannerTests.swift`

```swift
import XCTest
@testable import IFRCore

final class RivalPlannerTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let scheduler = Scheduler()

    private func mcQuestion(_ id: String, _ category: IFRCore.Category) -> Question {
        Question(id: id, category: category, acsCodes: ["IR.I.A.K1"], format: .multipleChoice,
                 front: "f", back: "b", options: ["a", "b", "c"], correctIndex: 0, explanation: "e",
                 source: SourceRef(document: "d", section: "s", url: URL(string: "https://faa.gov")!),
                 figure: nil, difficulty: 1)
    }

    private func fullBank(perCategory: Int) -> QuestionBank {
        var questions: [Question] = []
        for category in IFRCore.Category.allCases {
            for i in 0..<perCategory {
                questions.append(mcQuestion("\(category.rawValue)-\(i)", category))
            }
        }
        return QuestionBank(version: 1, questions: questions)
    }

    private func makeRival(at: GridPoint = GridPoint(x: 9, y: 1), afterBadges: Int = 1) -> RivalSpec {
        RivalSpec(
            name: "Skyler", nameplateName: "SKYLER", spriteID: "rival", questionCount: 6,
            encounters: [
                RivalEncounter(at: at, afterBadges: afterBadges, dialogue: DialogueRefs(intro: "i", win: "w", lose: "l")),
            ]
        )
    }

    private func makeSave(badges: Int, done: Set<Int> = []) -> AdventureSave {
        var save = AdventureSave.new
        save.badges = Set(GymID.allCases.prefix(badges))
        save.rivalEncountersDone = done
        return save
    }

    private func makeMap(_ rows: [[TileKind]]) -> TileMap {
        TileMap(width: rows.first?.count ?? 0, height: rows.count, rows: rows)
    }

    func testPicksThreeLowestRetentionCategories() {
        let retention: [IFRCore.Category: Double] = [
            .regulations: 0.9, .weather: 0.8, .chartsAndPlanning: 0.1,
            .navigation: 0.2, .instrumentsAndSystems: 0.3, .approaches: 0.95,
            .emergencies: 0.99, .humanFactors: 0.99,
        ]
        let weakest = RivalPlanner.weakestCategories(count: 3, retention: retention)
        XCTAssertEqual(weakest, [.chartsAndPlanning, .navigation, .instrumentsAndSystems])
    }

    func testTiesBreakByExamWeightDescending() {
        let retention: [IFRCore.Category: Double] = [
            .regulations: 0.5, .weather: 0.5, .chartsAndPlanning: 0.5,
            .navigation: 0.5, .instrumentsAndSystems: 0.5, .approaches: 0.5,
            .emergencies: 0.5, .humanFactors: 0.5,
        ]
        let weakest = RivalPlanner.weakestCategories(count: 2, retention: retention)
        XCTAssertEqual(weakest, [.regulations, .weather])
    }

    func testEncounterFiresOnceAtBadgeThreshold() {
        let spec = makeRival(at: GridPoint(x: 9, y: 1), afterBadges: 1)
        let readySave = makeSave(badges: 1)
        XCTAssertEqual(RivalPlanner.pendingEncounter(at: GridPoint(x: 9, y: 1), spec: spec, save: readySave), 0)
        XCTAssertEqual(RivalPlanner.pendingEncounter(at: GridPoint(x: 10, y: 1), spec: spec, save: readySave), 0)
        let doneSave = makeSave(badges: 1, done: [0])
        XCTAssertNil(RivalPlanner.pendingEncounter(at: GridPoint(x: 9, y: 1), spec: spec, save: doneSave))
    }

    func testEncounterDoesNotFireBelowBadgeThreshold() {
        let spec = makeRival(at: GridPoint(x: 9, y: 1), afterBadges: 4)
        let save = makeSave(badges: 3)
        XCTAssertNil(RivalPlanner.pendingEncounter(at: GridPoint(x: 9, y: 1), spec: spec, save: save))
    }

    func testRivalTileIsNeverBlockedForPathfinding() {
        var rows: [[TileKind]] = Array(repeating: Array(repeating: TileKind.ground, count: 5), count: 3)
        rows[1][2] = .ground
        let map = makeMap(rows)
        let rivalPosition = GridPoint(x: 2, y: 1)
        let blocked: Set<GridPoint> = []
        let path = Pathfinder.path(from: GridPoint(x: 0, y: 1), to: rivalPosition, in: map, blocked: blocked)
        XCTAssertEqual(path, [GridPoint(x: 1, y: 1), GridPoint(x: 2, y: 1)])
    }

    func testRivalDeckDrawsTwoFromEachWeakestCategory() {
        let bank = fullBank(perCategory: 6)
        let retention: [IFRCore.Category: Double] = [
            .regulations: 0.9, .weather: 0.9, .chartsAndPlanning: 0.1,
            .navigation: 0.2, .instrumentsAndSystems: 0.3, .approaches: 0.95,
            .emergencies: 0.99, .humanFactors: 0.99,
        ]
        let weakest = RivalPlanner.weakestCategories(count: 3, retention: retention)
        let circuitOrdered = GymID.allCases
            .map(\.category)
            .filter { weakest.contains($0) }
        let deckMaker = EncounterDeck(scheduler: scheduler)
        var rng = SeededRNG(seed: 7)
        let drawn = deckMaker.draw(count: 6, categories: circuitOrdered, bank: bank, states: [:],
                                   now: now, using: &rng)
        for category in circuitOrdered {
            XCTAssertEqual(drawn.filter { $0.category == category }.count, 2)
        }
    }

    func testRivalUsesTrainerTierAndXP() {
        let spec = makeRival()
        let opponent = spec.opponent(maxHP: 70)
        XCTAssertEqual(opponent.tier, .trainer)
        XCTAssertEqual(opponent.name, spec.name)
        XCTAssertEqual(opponent.nameplateName, spec.nameplateName)
        XCTAssertEqual(opponent.maxHP, 70)
        XCTAssertEqual(XPEngine.points(for: .trainerDefeated), 25)
    }

    func testOlderSaveWithoutRivalEncountersDecodes() throws {
        let json = "{\"badges\":[]}"
        let decoded = try JSONDecoder().decode(AdventureSave.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.rivalEncountersDone, [])
    }
}
```

Modify: `IFRCore/Tests/IFRCoreTests/AdventureSaveTests.swift`

```swift
    func testOlderSaveWithoutRivalEncountersDecodes() throws {
        let json = "{\"badges\":[]}"
        let decoded = try JSONDecoder().decode(AdventureSave.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.rivalEncountersDone, [])
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `scripts/test-core.sh --filter RivalPlannerTests`
Expected:
```
error: type 'RivalPlanner' has no member 'weakestCategories'
error: value of type 'RivalSpec' has no member 'opponent'
```

- [ ] **Step 3: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Overworld/RivalPlanner.swift`

```swift
import Foundation

public enum RivalPlanner {
    public static func weakestCategories(count: Int, retention: [Category: Double]) -> [Category] {
        let ranked = Category.allCases.sorted { lhs, rhs in
            let leftRetention = retention[lhs] ?? 0
            let rightRetention = retention[rhs] ?? 0
            if leftRetention != rightRetention { return leftRetention < rightRetention }
            return lhs.examWeight > rhs.examWeight
        }
        return Array(ranked.prefix(count))
    }

    public static func pendingEncounter(at position: GridPoint, spec: RivalSpec, save: AdventureSave) -> Int? {
        spec.encounters.enumerated().first { index, encounter in
            position.manhattanDistance(to: encounter.at) <= 1
                && save.badges.count >= encounter.afterBadges
                && !save.rivalEncountersDone.contains(index)
        }?.offset
    }
}
```

File: `IFRCore/Sources/IFRCore/Adventure/Content/RivalSpec.swift`

```swift
import Foundation

public struct RivalEncounter: Codable, Equatable, Sendable {
    public let at: GridPoint
    public let afterBadges: Int
    public let dialogue: DialogueRefs

    public init(at: GridPoint, afterBadges: Int, dialogue: DialogueRefs) {
        self.at = at
        self.afterBadges = afterBadges
        self.dialogue = dialogue
    }
}

public struct RivalSpec: Codable, Equatable, Sendable {
    public let name: String
    public let nameplateName: String
    public let spriteID: String
    public let questionCount: Int
    public let encounters: [RivalEncounter]

    public init(name: String, nameplateName: String, spriteID: String, questionCount: Int, encounters: [RivalEncounter]) {
        self.name = name
        self.nameplateName = nameplateName
        self.spriteID = spriteID
        self.questionCount = questionCount
        self.encounters = encounters
    }

    public func opponent(maxHP: Int) -> Opponent {
        Opponent(
            id: "rival", name: name, nameplateName: nameplateName, spriteID: spriteID,
            tier: .trainer, maxHP: maxHP
        )
    }
}
```

- [ ] **Step 4: Run all core tests**

Run: `scripts/test-core.sh`
Expected: `Executed 318 tests, with 0 failures`

- [ ] **Step 5: Commit**

Run: `git add IFRCore/Sources/IFRCore/Adventure/Overworld/RivalPlanner.swift IFRCore/Sources/IFRCore/Adventure/Content/RivalSpec.swift IFRCore/Tests/IFRCoreTests/RivalPlannerTests.swift IFRCore/Tests/IFRCoreTests/AdventureSaveTests.swift && git commit -m "M2-07: Rival"`

---

### Task M2-08: Overworld content (Linux)

**Files:**
- Create: `IFRCore/Sources/IFRCore/Adventure/Content/AdventureContentOverworldValidation.swift`
- Create: `IFRCore/Tests/IFRCoreTests/TileMapContentTests.swift`
- Modify: `IFRCore/Sources/IFRCore/Resources/adventure-v1.json`
- Modify: `IFRCore/Sources/IFRCore/Adventure/Content/AdventureContentValidation.swift`
- Modify: `IFRCore/Sources/IFRCore/Adventure/Content/AdventureContentDialogueValidation.swift`
- Test: `IFRCore/Tests/IFRCoreTests/TileMapContentTests.swift`
- Test: `IFRCore/Tests/IFRCoreTests/AdventureContentTests.swift`

**Interfaces:**
- Consumes: `AdventureContent`, `AdventureContentError`, `TileMap`, `TileArea`, `GridRect`, `GridPoint` (`IFRCore/Sources/IFRCore/Adventure/Content/TileMap.swift`, `Adventure/Pixel/GridPoint.swift`); `TileKind.isWalkable` (`Adventure/Overworld/TileKind.swift`); `Trainer`, `DialogueRefs` (`Adventure/Content/Trainer.swift`, `Adventure/Content/Gym.swift`); `RivalSpec`, `RivalEncounter` (`Adventure/Content/RivalSpec.swift`); `RegionMap`, `Airport`, `AirportRole` (`Adventure/Content/RegionMap.swift`); `Pathfinder.path(from:to:in:blocked:)` (`Adventure/Overworld/Pathfinder.swift`); `Direction.delta` (`Adventure/Overworld/Direction.swift`).
- Produces: `AdventureContent.checkDoorsHaveWarps() throws`, `checkEveryAirportHasExactlyOneDoor() throws`, `checkSpawnIsWalkable() throws`, `checkEveryDoorReachableFromSpawn() throws`, `checkTrainersStandOnWalkableTilesFacingWalkableLine() throws`, `checkItemDropsAndSignsAreWalkable() throws`, `checkEveryCloudTileLiesInExactlyOneArea() throws`, `checkRivalEncountersAreWalkable() throws`, all wired into the fixed `validate()` order; the bundled `Resources/adventure-v1.json` now ships a hand-authored 40 by 30 `tileMap`, one `trainers` entry and a `rival` with two encounters, all validated on every `AdventureContent.load()`.

- [ ] **Step 1: Write the failing tests**

File: `IFRCore/Tests/IFRCoreTests/TileMapContentTests.swift`

```swift
import XCTest
@testable import IFRCore

final class TileMapContentTests: XCTestCase {
    private func loadedContent() throws -> AdventureContent {
        try AdventureContent.load()
    }

    private func replacingTileMap(_ content: AdventureContent, with tileMap: TileMap) -> AdventureContent {
        AdventureContent(
            version: content.version, region: content.region, gyms: content.gyms, eliteFour: content.eliteFour,
            champion: content.champion, dialogue: content.dialogue, system: content.system, items: content.items,
            tileMap: tileMap, trainers: content.trainers, rival: content.rival, companions: content.companions
        )
    }

    private func replacingTrainers(_ content: AdventureContent, with trainers: [Trainer]) -> AdventureContent {
        AdventureContent(
            version: content.version, region: content.region, gyms: content.gyms, eliteFour: content.eliteFour,
            champion: content.champion, dialogue: content.dialogue, system: content.system, items: content.items,
            tileMap: content.tileMap, trainers: trainers, rival: content.rival, companions: content.companions
        )
    }

    private func replacingRival(_ content: AdventureContent, with rival: RivalSpec) -> AdventureContent {
        AdventureContent(
            version: content.version, region: content.region, gyms: content.gyms, eliteFour: content.eliteFour,
            champion: content.champion, dialogue: content.dialogue, system: content.system, items: content.items,
            tileMap: content.tileMap, trainers: content.trainers, rival: rival, companions: content.companions
        )
    }

    private func mutatingRows(_ tileMap: TileMap, at point: GridPoint, to kind: TileKind) -> TileMap {
        var rows = tileMap.rows
        rows[point.y][point.x] = kind
        return TileMap(
            width: tileMap.width, height: tileMap.height, rows: rows, doorAirportIDs: tileMap.doorAirportIDs,
            signTexts: tileMap.signTexts, itemDropItemIDs: tileMap.itemDropItemIDs, spawn: tileMap.spawn,
            areas: tileMap.areas
        )
    }

    func testEveryDoorHasWarpAndEveryWarpSitsOnDoor() throws {
        let base = try loadedContent()
        let tileMap = try XCTUnwrap(base.tileMap)
        var doorAirportIDs = tileMap.doorAirportIDs
        doorAirportIDs.removeValue(forKey: GridPoint(x: 3, y: 14))
        let brokenMap = TileMap(
            width: tileMap.width, height: tileMap.height, rows: tileMap.rows, doorAirportIDs: doorAirportIDs,
            signTexts: tileMap.signTexts, itemDropItemIDs: tileMap.itemDropItemIDs, spawn: tileMap.spawn,
            areas: tileMap.areas
        )
        let content = replacingTileMap(base, with: brokenMap)
        XCTAssertThrowsError(try content.validate()) {
            XCTAssertEqual($0 as? AdventureContentError, .unknownReference(from: "tileMap", to: "3-14"))
        }
    }

    func testEveryAirportHasExactlyOneDoor() throws {
        let base = try loadedContent()
        let tileMap = try XCTUnwrap(base.tileMap)
        var doorAirportIDs = tileMap.doorAirportIDs
        doorAirportIDs[GridPoint(x: 3, y: 14)] = "KGYR"
        let brokenMap = TileMap(
            width: tileMap.width, height: tileMap.height, rows: tileMap.rows, doorAirportIDs: doorAirportIDs,
            signTexts: tileMap.signTexts, itemDropItemIDs: tileMap.itemDropItemIDs, spawn: tileMap.spawn,
            areas: tileMap.areas
        )
        let content = replacingTileMap(base, with: brokenMap)
        XCTAssertThrowsError(try content.validate()) {
            XCTAssertEqual($0 as? AdventureContentError, .unreachableDoor(airportID: "KHYP"))
        }
    }

    func testSpawnIsWalkable() throws {
        let base = try loadedContent()
        let tileMap = try XCTUnwrap(base.tileMap)
        let brokenMap = TileMap(
            width: tileMap.width, height: tileMap.height, rows: tileMap.rows, doorAirportIDs: tileMap.doorAirportIDs,
            signTexts: tileMap.signTexts, itemDropItemIDs: tileMap.itemDropItemIDs, spawn: GridPoint(x: 0, y: 0),
            areas: tileMap.areas
        )
        let content = replacingTileMap(base, with: brokenMap)
        XCTAssertThrowsError(try content.validate()) {
            XCTAssertEqual($0 as? AdventureContentError, .unknownTile(x: 0, y: 0))
        }
    }

    func testEveryDoorReachableFromSpawn() throws {
        let base = try loadedContent()
        let tileMap = try XCTUnwrap(base.tileMap)
        let brokenMap = mutatingRows(tileMap, at: GridPoint(x: 3, y: 15), to: .terrain)
        let content = replacingTileMap(base, with: brokenMap)
        XCTAssertThrowsError(try content.validate()) {
            XCTAssertEqual($0 as? AdventureContentError, .unreachableDoor(airportID: "KHYP"))
        }
    }

    func testTrainersStandOnWalkableTilesFacingWalkableLine() throws {
        let base = try loadedContent()
        let trainer = Trainer(
            id: "student-ana", name: "Student Pilot Ana", nameplateName: "ANA", spriteID: "trainer-student",
            position: GridPoint(x: 3, y: 16), facing: .up, range: 3, questionCount: 4,
            categories: [.humanFactors], dialogue: DialogueRefs(intro: "ana-intro", win: "ana-win", lose: "ana-lose")
        )
        let content = replacingTrainers(base, with: [trainer])
        XCTAssertThrowsError(try content.validate()) {
            XCTAssertEqual($0 as? AdventureContentError, .unknownTile(x: 3, y: 13))
        }
    }

    func testItemDropsAndSignsOnWalkableTiles() throws {
        let base = try loadedContent()
        let tileMap = try XCTUnwrap(base.tileMap)
        let brokenMap = mutatingRows(tileMap, at: GridPoint(x: 25, y: 17), to: .terrain)
        let content = replacingTileMap(base, with: brokenMap)
        XCTAssertThrowsError(try content.validate()) {
            XCTAssertEqual($0 as? AdventureContentError, .unknownTile(x: 25, y: 17))
        }
    }

    func testEveryCloudTileLiesInExactlyOneArea() throws {
        let base = try loadedContent()
        let tileMap = try XCTUnwrap(base.tileMap)
        let brokenMap = mutatingRows(tileMap, at: GridPoint(x: 5, y: 5), to: .cloud)
        let content = replacingTileMap(base, with: brokenMap)
        XCTAssertThrowsError(try content.validate()) {
            XCTAssertEqual($0 as? AdventureContentError, .unknownReference(from: "cloud", to: "5-5"))
        }
    }

    func testRivalEncountersSitOnWalkableTiles() throws {
        let base = try loadedContent()
        let rival = try XCTUnwrap(base.rival)
        let brokenEncounter = RivalEncounter(
            at: GridPoint(x: 0, y: 0), afterBadges: 1,
            dialogue: DialogueRefs(intro: "skyler-1-intro", win: "skyler-1-win", lose: "skyler-1-lose")
        )
        let brokenRival = RivalSpec(
            name: rival.name, nameplateName: rival.nameplateName, spriteID: rival.spriteID,
            questionCount: rival.questionCount, encounters: [brokenEncounter]
        )
        let content = replacingRival(base, with: brokenRival)
        XCTAssertThrowsError(try content.validate()) {
            XCTAssertEqual($0 as? AdventureContentError, .unknownTile(x: 0, y: 0))
        }
    }
}
```

Also added to `IFRCore/Tests/IFRCoreTests/AdventureContentTests.swift` (`AdventureContentTests`, an existing test class):

```swift
    func testEveryTrainerAndRivalEncounterHasIntroWinLoseDialogue() throws {
        let base = try loadedContent()
        var dialogue = base.dialogue
        dialogue.removeValue(forKey: "ana-win")
        let content = replacingDialogue(base, with: dialogue)
        XCTAssertThrowsError(try content.validate()) {
            XCTAssertEqual($0 as? AdventureContentError, .unknownReference(from: "student-ana", to: "ana-win"))
        }
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `scripts/test-core.sh --filter TileMapContentTests`
Expected:
```
Test Case 'TileMapContentTests.testEveryAirportHasExactlyOneDoor' started
/home/user/IFR-build/FlashCards/IFRCore/Tests/IFRCoreTests/TileMapContentTests.swift:70: error: TileMapContentTests.testEveryAirportHasExactlyOneDoor : XCTAssertThrowsError failed: did not throw error -
...
Executed 8 tests, with 8 failures (0 unexpected) in 0.237 seconds
```
(All eight tests failed with `did not throw error`, since the bundled JSON had no `tileMap`, `trainers` or `rival` yet and none of the new `check...` functions existed.) The companion assertion in `AdventureContentTests.testEveryTrainerAndRivalEncounterHasIntroWinLoseDialogue` failed the same way: `XCTAssertThrowsError failed: did not throw error -`.

- [ ] **Step 3: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Content/AdventureContentOverworldValidation.swift`

```swift
import Foundation

extension AdventureContent {
    func checkDoorsHaveWarps() throws {
        guard let tileMap else { return }
        for point in doorPoints(in: tileMap) where tileMap.doorAirportIDs[point] == nil {
            throw AdventureContentError.unknownReference(from: "tileMap", to: "\(point.x)-\(point.y)")
        }
        for (point, airportID) in tileMap.doorAirportIDs where tileMap[point] != .door {
            throw AdventureContentError.unknownReference(from: "tileMap", to: airportID)
        }
    }

    private func doorPoints(in tileMap: TileMap) -> [GridPoint] {
        (0..<tileMap.height).flatMap { y in
            (0..<tileMap.width).compactMap { x in
                tileMap.rows[y][x] == .door ? GridPoint(x: x, y: y) : nil
            }
        }
    }

    func checkEveryAirportHasExactlyOneDoor() throws {
        guard let tileMap else { return }
        var doorCounts: [String: Int] = [:]
        for airportID in tileMap.doorAirportIDs.values {
            doorCounts[airportID, default: 0] += 1
        }
        for airport in region.airports where airport.role != .waypoint {
            guard doorCounts[airport.id] == 1 else {
                throw AdventureContentError.unreachableDoor(airportID: airport.id)
            }
        }
    }

    func checkSpawnIsWalkable() throws {
        guard let tileMap else { return }
        try assertWalkable(tileMap.spawn, in: tileMap)
    }

    func checkEveryDoorReachableFromSpawn() throws {
        guard let tileMap else { return }
        for (point, airportID) in tileMap.doorAirportIDs {
            guard Pathfinder.path(from: tileMap.spawn, to: point, in: tileMap, blocked: []) != nil else {
                throw AdventureContentError.unreachableDoor(airportID: airportID)
            }
        }
    }

    func checkTrainersStandOnWalkableTilesFacingWalkableLine() throws {
        guard let tileMap else { return }
        for trainer in trainers {
            try assertWalkable(trainer.position, in: tileMap)
            try assertTrainerLineWalkable(trainer, in: tileMap)
        }
    }

    private func assertTrainerLineWalkable(_ trainer: Trainer, in tileMap: TileMap) throws {
        var point = trainer.position
        for _ in 1...trainer.range {
            point = GridPoint(x: point.x + trainer.facing.delta.x, y: point.y + trainer.facing.delta.y)
            try assertWalkable(point, in: tileMap)
        }
    }

    func checkItemDropsAndSignsAreWalkable() throws {
        guard let tileMap else { return }
        for point in tileMap.itemDropItemIDs.keys { try assertWalkable(point, in: tileMap) }
        for point in tileMap.signTexts.keys { try assertWalkable(point, in: tileMap) }
    }

    func checkEveryCloudTileLiesInExactlyOneArea() throws {
        guard let tileMap else { return }
        for y in 0..<tileMap.height {
            for x in 0..<tileMap.width where tileMap.rows[y][x] == .cloud {
                try assertCloudCoveredOnce(GridPoint(x: x, y: y), in: tileMap)
            }
        }
    }

    private func assertCloudCoveredOnce(_ point: GridPoint, in tileMap: TileMap) throws {
        let matches = tileMap.areas.filter { $0.rect.contains(point) }.count
        guard matches == 1 else {
            throw AdventureContentError.unknownReference(from: "cloud", to: "\(point.x)-\(point.y)")
        }
    }

    func checkRivalEncountersAreWalkable() throws {
        guard let tileMap, let rival else { return }
        for encounter in rival.encounters {
            try assertWalkable(encounter.at, in: tileMap)
        }
    }

    private func assertWalkable(_ point: GridPoint, in tileMap: TileMap) throws {
        guard tileMap[point]?.isWalkable == true else {
            throw AdventureContentError.unknownTile(x: point.x, y: point.y)
        }
    }
}
```

Modified — `IFRCore/Sources/IFRCore/Adventure/Content/AdventureContentValidation.swift`, the `validate()` function (new lines wired into the fixed order after `checkSpriteReferences()`):

```swift
    public func validate() throws {
        try checkUniqueIDs()
        try checkGymOrder()
        try checkReferences()
        try checkRegionConnectivity()
        try checkAirportPositions()
        try checkDialogueReferences()
        try checkDialoguePageLengths()
        try checkSystemDialogueKeys()
        try checkSystemDialogueSubstitution()
        try checkNameplateLengths()
        try checkEliteFourCoverage()
        try checkGymQuestionPools()
        try checkSpriteReferences()
        try checkDoorsHaveWarps()
        try checkEveryAirportHasExactlyOneDoor()
        try checkSpawnIsWalkable()
        try checkEveryDoorReachableFromSpawn()
        try checkTrainersStandOnWalkableTilesFacingWalkableLine()
        try checkItemDropsAndSignsAreWalkable()
        try checkEveryCloudTileLiesInExactlyOneArea()
        try checkRivalEncountersAreWalkable()
    }
```

Modified — `IFRCore/Sources/IFRCore/Adventure/Content/AdventureContentDialogueValidation.swift`, the `checkDialogueReferences()` function (now folds trainers and rival encounters into the same owners list so a missing or empty trainer/rival dialogue page reuses `.unknownReference`/`.emptyDialogue`):

```swift
    func checkDialogueReferences() throws {
        var owners: [(String, DialogueRefs)] = gyms.map { ($0.id.rawValue, $0.dialogue) }
        owners += eliteFour.map { ($0.id, $0.dialogue) }
        owners.append((champion.name, champion.dialogue))
        owners += trainers.map { ($0.id, $0.dialogue) }
        if let rival {
            owners += rival.encounters.enumerated().map { ("\(rival.name)-\($0.offset)", $0.element.dialogue) }
        }
        for (owner, refs) in owners {
            for key in [refs.intro, refs.win, refs.lose] {
                guard let script = dialogue[key] else {
                    throw AdventureContentError.unknownReference(from: owner, to: key)
                }
                guard !script.pages.isEmpty, script.pages.allSatisfy({ !$0.isEmpty }) else {
                    throw AdventureContentError.emptyDialogue(key)
                }
            }
        }
    }
```

Modified — `IFRCore/Sources/IFRCore/Resources/adventure-v1.json`. Three top-level fields were added (`tileMap`, `trainers`, `rival`), plus their dialogue entries under the existing `dialogue` key. The new `tileMap` is a hand-authored 40 by 30 map: a bordered rectangle with a horizontal Victor-airway corridor at row 15, ten door tiles at row 14 (one per airport, each above a small two-row building block), a spawn tile at `(2, 15)`, a three-row cloud field over `(10..20, 17..19)` matching exactly one `weather` area, a water pond for texture, one item drop, one sign and the trainer/rival tiles described below:

```json
{
  "tileMap": {
    "width": 40,
    "height": 30,
    "rows": [
      "########################################",
      "#......................................#",
      "#......................................#",
      "#......................................#",
      "#......................................#",
      "#......................................#",
      "#......................................#",
      "#......................................#",
      "#......................................#",
      "#......................................#",
      "#......................................#",
      "#......................................#",
      "#......................................#",
      "#.BBB.BBB.BBB.BBB.BBB.BBB.BBB.BBBBBBBBB#",
      "#.BDB.BDB.BDB.BDB.BDB.BDB.BDB.BDBBDBBDB#",
      "#======================================#",
      "#......................................#",
      "#.........~~~~~~~~~~~..................#",
      "#.........~~~~~~~~~~~..................#",
      "#.........~~~~~~~~~~~..................#",
      "#......................................#",
      "#......................................#",
      "#....wwww..............................#",
      "#....wwww..............................#",
      "#......................................#",
      "#......................................#",
      "#......................................#",
      "#......................................#",
      "#......................................#",
      "########################################"
    ],
    "spawn": { "x": 2, "y": 15 },
    "areas": [
      { "id": "nimbus-approach", "category": "weather", "rect": { "x": 10, "y": 17, "w": 11, "h": 3 } }
    ],
    "warps": [
      { "at": { "x": 3, "y": 14 }, "airportID": "KHYP" },
      { "at": { "x": 7, "y": 14 }, "airportID": "KGYR" },
      { "at": { "x": 11, "y": 14 }, "airportID": "KREG" },
      { "at": { "x": 15, "y": 14 }, "airportID": "KVIC" },
      { "at": { "x": 19, "y": 14 }, "airportID": "KPLT" },
      { "at": { "x": 23, "y": 14 }, "airportID": "KNIM" },
      { "at": { "x": 27, "y": 14 }, "airportID": "KMAY" },
      { "at": { "x": 31, "y": 14 }, "airportID": "KILS" },
      { "at": { "x": 34, "y": 14 }, "airportID": "KELF" },
      { "at": { "x": 37, "y": 14 }, "airportID": "KCHP" }
    ],
    "signs": [
      { "at": { "x": 30, "y": 17 }, "text": "VICTOR AIRWAYS AHEAD. MAINTAIN YOUR ALTITUDE." }
    ],
    "itemDrops": [
      { "id": "drop-1", "at": { "x": 25, "y": 17 }, "itemID": "potion" }
    ]
  }
}
```

```json
{
  "trainers": [
    {
      "id": "student-ana",
      "name": "Student Pilot Ana",
      "nameplateName": "ANA",
      "spriteID": "trainer-student",
      "position": { "x": 5, "y": 17 },
      "facing": "right",
      "range": 4,
      "questionCount": 4,
      "categories": ["humanFactors"],
      "dialogue": { "intro": "ana-intro", "win": "ana-win", "lose": "ana-lose" }
    }
  ]
}
```

```json
{
  "rival": {
    "name": "Skyler",
    "nameplateName": "SKYLER",
    "spriteID": "rival",
    "questionCount": 6,
    "encounters": [
      {
        "at": { "x": 13, "y": 19 },
        "afterBadges": 1,
        "dialogue": { "intro": "skyler-1-intro", "win": "skyler-1-win", "lose": "skyler-1-lose" }
      },
      {
        "at": { "x": 26, "y": 19 },
        "afterBadges": 4,
        "dialogue": { "intro": "skyler-2-intro", "win": "skyler-2-win", "lose": "skyler-2-lose" }
      }
    ]
  }
}
```

New entries under the existing `dialogue` key:

```json
{
  "ana-intro": { "pages": ["I've been studying hypoxia symptoms all week.", "Let's see who really knows their oxygen limits!"] },
  "ana-win": { "pages": ["Wow, you really know your stuff up there."] },
  "ana-lose": { "pages": ["Ha! Guess I need to hit the books more."] },
  "skyler-1-intro": { "pages": ["Hey! I heard you got your first badge.", "Let's see if you can handle my weak spots too."] },
  "skyler-1-win": { "pages": ["Not bad. I'll catch up to you eventually."] },
  "skyler-1-lose": { "pages": ["Ha, still got it. Study up and try again."] },
  "skyler-2-intro": { "pages": ["Four badges already? I've been cramming too.", "Let's settle this once and for all."] },
  "skyler-2-win": { "pages": ["You're really pulling ahead of me now."] },
  "skyler-2-lose": { "pages": ["Still got some tricks left, huh?"] }
}
```

- [ ] **Step 4: Run all core tests**

Run: `scripts/test-core.sh`
Expected: `Executed 327 tests, with 0 failures (0 unexpected) in 1.81 (1.81) seconds`

- [ ] **Step 5: Commit**

Run: `git add FlashCards/IFRCore/Sources/IFRCore/Adventure/Content/AdventureContentOverworldValidation.swift FlashCards/IFRCore/Sources/IFRCore/Adventure/Content/AdventureContentValidation.swift FlashCards/IFRCore/Sources/IFRCore/Adventure/Content/AdventureContentDialogueValidation.swift FlashCards/IFRCore/Sources/IFRCore/Resources/adventure-v1.json FlashCards/IFRCore/Tests/IFRCoreTests/TileMapContentTests.swift FlashCards/IFRCore/Tests/IFRCoreTests/AdventureContentTests.swift && git commit -m "M2-08: Overworld content"`

---

### Task M2-09a: Overworld renderer and tile sprites

**Files:**
- Create: `IFRCore/Sources/IFRCore/Adventure/Pixel/OverworldRenderer.swift`
- Create: `IFRCore/Sources/IFRCore/Adventure/Pixel/Sprites/TileSprites.swift`
- Modify: `IFRCore/Sources/IFRCore/Adventure/Circuit/AdventureSave.swift`
- Modify: `IFRCore/Sources/IFRCore/Adventure/Pixel/SpriteCatalog.swift`
- Test: `IFRCore/Tests/IFRCoreTests/OverworldRendererTests.swift`
- Test: `IFRCore/Tests/IFRCoreTests/SpriteCatalogTests.swift`
- Test: `IFRCore/Tests/IFRCoreTests/AdventureSaveTests.swift`

**Interfaces:**
- Consumes: `Camera.origin(following:mapWidth:mapHeight:viewportWidth:viewportHeight:)` (`Adventure/Overworld/Camera.swift`), `TileMap` and its `subscript(GridPoint)` (`Adventure/Content/TileMap.swift`), `TileKind` (`Adventure/Overworld/TileKind.swift`), `OverworldState` (`Adventure/Overworld/OverworldState.swift`), `Trainer` (`Adventure/Content/Trainer.swift`), `Direction` (`Adventure/Overworld/Direction.swift`), `PixelFrame`, `PixelSprite`, `SpriteCatalog` (`Adventure/Pixel/`)
- Produces: `enum OverworldRenderer { static let cellSize, viewportWidth, viewportHeight; static func frame(map: TileMap, state: OverworldState, trainers: [Trainer], defeated: Set<String>, atFrame: Int) -> PixelFrame }`; `enum TileSprites { static let all: [String: PixelSprite]; static func name(for: TileKind) -> String }`, sixteen new catalog sprite ids (`tile-ground`, `tile-airway`, `tile-cloud`, `tile-water`, `tile-terrain`, `tile-building`, `tile-door`, `tile-sign`, `walker-down-0/1`, `walker-up-0/1`, `walker-left-0/1`, `trainer-student`, `path-marker`); `AdventureSave.facing: Direction?`

- [ ] **Step 1: Write the failing tests**

File: `IFRCore/Tests/IFRCoreTests/OverworldRendererTests.swift`

```swift
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
```

Also extended, in the same commit:

`IFRCore/Tests/IFRCoreTests/SpriteCatalogTests.swift` gained a `tileAndWalkerSpriteIDs` list and:

```swift
    func testTileAndWalkerSpritesAreSixteenSquare() {
        for id in tileAndWalkerSpriteIDs {
            let sprite = SpriteCatalog.sprite(named: id)
            XCTAssertEqual(sprite?.width, 16, id)
            XCTAssertEqual(sprite?.height, 16, id)
        }
    }
```

`IFRCore/Tests/IFRCoreTests/AdventureSaveTests.swift` gained:

```swift
    func testOlderSaveWithoutPositionDecodes() throws {
        let json = "{\"badges\":[]}"
        let decoded = try JSONDecoder().decode(AdventureSave.self, from: Data(json.utf8))
        XCTAssertNil(decoded.position)
        XCTAssertNil(decoded.facing)
    }
```

(plus two `XCTAssertEqual` lines added to `testExampleSaveJSONDecodesVerbatim` asserting `decoded.position` and `decoded.facing`, since that JSON fixture already carried a `"facing": "right"` key from an earlier work item.)

- [ ] **Step 2: Run the tests to verify they fail**

Run: `scripts/test-core.sh --filter OverworldRendererTests`
Expected:
```
/home/user/IFR-build/FlashCards/IFRCore/Tests/IFRCoreTests/OverworldRendererTests.swift:45:21: error: cannot find 'OverworldRenderer' in scope
/home/user/IFR-build/FlashCards/IFRCore/Tests/IFRCoreTests/OverworldRendererTests.swift:67:21: error: cannot find 'OverworldRenderer' in scope
error: fatalError
```

- [ ] **Step 3: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Pixel/Sprites/TileSprites.swift`

```swift
import Foundation

public enum TileSprites {
    public static let all: [String: PixelSprite] = [
        "tile-ground": tileSprite(fill: 3, border: 2),
        "tile-airway": tileSprite(fill: 13, border: 0),
        "tile-cloud": tileSprite(fill: 12, border: 6),
        "tile-water": tileSprite(fill: 11, border: 0),
        "tile-terrain": tileSprite(fill: 2, border: 0),
        "tile-building": tileSprite(fill: 9, border: 0),
        "tile-door": tileSprite(fill: 8, border: 6),
        "tile-sign": tileSprite(fill: 5, border: 0),
        "walker-down-0": walkerSprite(fill: 4, border: 0, detail: 6, footLeft: true),
        "walker-down-1": walkerSprite(fill: 4, border: 0, detail: 6, footLeft: false),
        "walker-up-0": walkerSprite(fill: 5, border: 0, detail: 2, footLeft: true),
        "walker-up-1": walkerSprite(fill: 5, border: 0, detail: 2, footLeft: false),
        "walker-left-0": walkerSprite(fill: 9, border: 0, detail: 7, footLeft: true),
        "walker-left-1": walkerSprite(fill: 9, border: 0, detail: 7, footLeft: false),
        "trainer-student": walkerSprite(fill: 10, border: 0, detail: 3, footLeft: true),
        "path-marker": pathMarker,
    ]

    public static func name(for kind: TileKind) -> String {
        switch kind {
        case .ground: return "tile-ground"
        case .airway: return "tile-airway"
        case .cloud: return "tile-cloud"
        case .water: return "tile-water"
        case .terrain: return "tile-terrain"
        case .building: return "tile-building"
        case .door: return "tile-door"
        case .sign: return "tile-sign"
        }
    }

    private static let pathMarker = try! PixelSprite(rows: (0..<16).map { y in
        String((0..<16).map { x -> Character in
            abs(x - 7) + abs(y - 7) <= 3 ? "5" : "."
        })
    })

    private static func tileSprite(fill: UInt8, border: UInt8) -> PixelSprite {
        try! PixelSprite(rows: (0..<16).map { y in
            String((0..<16).map { x -> Character in
                isEdge(x, y) ? hexDigit(border) : hexDigit(fill)
            })
        })
    }

    private static func walkerSprite(fill: UInt8, border: UInt8, detail: UInt8, footLeft: Bool) -> PixelSprite {
        try! PixelSprite(rows: (0..<16).map { y in
            String((0..<16).map { x -> Character in
                walkerPixel(x, y, fill: fill, border: border, detail: detail, footLeft: footLeft)
            })
        })
    }

    private static func walkerPixel(_ x: Int, _ y: Int, fill: UInt8, border: UInt8, detail: UInt8, footLeft: Bool) -> Character {
        if isEdge(x, y) { return hexDigit(border) }
        if isFoot(x, y, footLeft: footLeft) { return hexDigit(detail) }
        return hexDigit(fill)
    }

    private static func isEdge(_ x: Int, _ y: Int) -> Bool {
        x == 0 || x == 15 || y == 0 || y == 15
    }

    private static func isFoot(_ x: Int, _ y: Int, footLeft: Bool) -> Bool {
        y >= 12 && (footLeft ? x < 8 : x >= 8)
    }

    private static func hexDigit(_ value: UInt8) -> Character {
        Character(String(value, radix: 16))
    }
}
```

- [ ] **Step 4: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Pixel/OverworldRenderer.swift`

```swift
import Foundation

public enum OverworldRenderer {
    public static let cellSize = 16
    public static let viewportWidth = 15
    public static let viewportHeight = 10

    private static let panelIndex: UInt8 = 1

    public static func frame(
        map: TileMap, state: OverworldState, trainers: [Trainer], defeated: Set<String>, atFrame: Int
    ) -> PixelFrame {
        let origin = cameraOrigin(for: state.position, map: map)
        var canvas = PixelFrame(fill: panelIndex)
        drawTiles(&canvas, map: map, origin: origin)
        drawPathPreview(&canvas, path: state.pendingPath, origin: origin)
        drawTrainers(&canvas, trainers: trainers, origin: origin)
        drawPlayer(&canvas, state: state, origin: origin, atFrame: atFrame)
        return canvas
    }

    private static func cameraOrigin(for position: GridPoint, map: TileMap) -> GridPoint {
        Camera.origin(
            following: position, mapWidth: map.width, mapHeight: map.height,
            viewportWidth: viewportWidth, viewportHeight: viewportHeight
        )
    }

    private static func drawTiles(_ canvas: inout PixelFrame, map: TileMap, origin: GridPoint) {
        for y in 0..<viewportHeight {
            for x in 0..<viewportWidth {
                let tile = GridPoint(x: origin.x + x, y: origin.y + y)
                guard let kind = map[tile], let sprite = SpriteCatalog.sprite(named: TileSprites.name(for: kind)) else {
                    continue
                }
                canvas.blit(sprite, at: screenPoint(tile, origin: origin))
            }
        }
    }

    private static func drawPathPreview(_ canvas: inout PixelFrame, path: [GridPoint], origin: GridPoint) {
        guard let marker = SpriteCatalog.sprite(named: "path-marker") else { return }
        for tile in path {
            canvas.blit(marker, at: screenPoint(tile, origin: origin))
        }
    }

    private static func drawTrainers(_ canvas: inout PixelFrame, trainers: [Trainer], origin: GridPoint) {
        for trainer in trainers {
            guard let sprite = SpriteCatalog.sprite(named: trainer.spriteID) else { continue }
            canvas.blit(sprite, at: screenPoint(trainer.position, origin: origin))
        }
    }

    private static func drawPlayer(_ canvas: inout PixelFrame, state: OverworldState, origin: GridPoint, atFrame: Int) {
        guard let sprite = walkerSprite(facing: state.facing, atFrame: atFrame) else { return }
        canvas.blit(sprite, at: screenPoint(state.position, origin: origin))
    }

    private static func walkerSprite(facing: Direction, atFrame: Int) -> PixelSprite? {
        let walkFrame = (atFrame / 4) % 2
        switch facing {
        case .down: return SpriteCatalog.sprite(named: "walker-down-\(walkFrame)")
        case .up: return SpriteCatalog.sprite(named: "walker-up-\(walkFrame)")
        case .left: return SpriteCatalog.sprite(named: "walker-left-\(walkFrame)")
        case .right: return SpriteCatalog.sprite(named: "walker-left-\(walkFrame)")?.flippedHorizontally()
        }
    }

    private static func screenPoint(_ tile: GridPoint, origin: GridPoint) -> GridPoint {
        GridPoint(x: (tile.x - origin.x) * cellSize, y: (tile.y - origin.y) * cellSize)
    }
}
```

Modified `IFRCore/Sources/IFRCore/Adventure/Pixel/SpriteCatalog.swift`, the whole new file:

```swift
import Foundation

public enum SpriteCatalog {
    public static let all: [String: PixelSprite] = UISprites.all
        .merging(PlayerSprites.all) { _, new in new }
        .merging(LeaderSprites.all) { _, new in new }
        .merging(EliteSprites.all) { _, new in new }
        .merging(TileSprites.all) { _, new in new }

    public static func sprite(named name: String) -> PixelSprite? {
        all[name]
    }
}
```

Modified `IFRCore/Sources/IFRCore/Adventure/Circuit/AdventureSave.swift`, the complete new version of the type (only `facing` is new; every other field and rule was already committed by an earlier work item):

```swift
import Foundation

public struct AdventureSave: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public var saveVersion: Int
    public var badges: Set<GymID>
    public var badgeQuestionIDs: [String: [String]]
    public var eliteFourCleared: Bool
    public var championWins: Int
    public var hallOfFame: [Date]
    public var battlesWon: Int
    public var battlesLost: Int
    public var visitedAirportIDs: Set<String>
    public var defeatedTrainerIDs: Set<String>
    public var collectedItemIDs: Set<String>
    public var inventory: [String: Int]
    public var repelStepsLeft: Int
    public var position: GridPoint?
    public var facing: Direction?
    public var rivalEncountersDone: Set<Int>

    public static let new = AdventureSave(
        saveVersion: currentVersion, badges: [], badgeQuestionIDs: [:], eliteFourCleared: false,
        championWins: 0, hallOfFame: [], battlesWon: 0, battlesLost: 0, visitedAirportIDs: [],
        defeatedTrainerIDs: [], collectedItemIDs: [], inventory: [:], repelStepsLeft: 0, position: nil,
        facing: nil, rivalEncountersDone: []
    )

    public init(
        saveVersion: Int, badges: Set<GymID>, badgeQuestionIDs: [String: [String]], eliteFourCleared: Bool,
        championWins: Int, hallOfFame: [Date], battlesWon: Int, battlesLost: Int, visitedAirportIDs: Set<String>,
        defeatedTrainerIDs: Set<String> = [], collectedItemIDs: Set<String> = [], inventory: [String: Int] = [:],
        repelStepsLeft: Int = 0, position: GridPoint? = nil, facing: Direction? = nil, rivalEncountersDone: Set<Int> = []
    ) {
        self.saveVersion = saveVersion
        self.badges = badges
        self.badgeQuestionIDs = badgeQuestionIDs
        self.eliteFourCleared = eliteFourCleared
        self.championWins = championWins
        self.hallOfFame = hallOfFame
        self.battlesWon = battlesWon
        self.battlesLost = battlesLost
        self.visitedAirportIDs = visitedAirportIDs
        self.defeatedTrainerIDs = defeatedTrainerIDs
        self.collectedItemIDs = collectedItemIDs
        self.inventory = inventory
        self.repelStepsLeft = repelStepsLeft
        self.position = position
        self.facing = facing
        self.rivalEncountersDone = rivalEncountersDone
    }

    private enum CodingKeys: String, CodingKey {
        case saveVersion, badges, badgeQuestionIDs, eliteFourCleared, championWins,
             hallOfFame, battlesWon, battlesLost, visitedAirportIDs, defeatedTrainerIDs,
             collectedItemIDs, inventory, repelStepsLeft, position, facing, rivalEncountersDone
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let saveVersion = try container.decodeIfPresent(Int.self, forKey: .saveVersion) ?? Self.currentVersion
        guard saveVersion <= Self.currentVersion else {
            throw AdventureSaveError.newerThanApp(saveVersion)
        }
        self.saveVersion = saveVersion
        self.badges = try container.decodeIfPresent(Set<GymID>.self, forKey: .badges) ?? []
        self.badgeQuestionIDs = try container.decodeIfPresent([String: [String]].self, forKey: .badgeQuestionIDs) ?? [:]
        self.eliteFourCleared = try container.decodeIfPresent(Bool.self, forKey: .eliteFourCleared) ?? false
        self.championWins = try container.decodeIfPresent(Int.self, forKey: .championWins) ?? 0
        self.hallOfFame = try container.decodeIfPresent([Date].self, forKey: .hallOfFame) ?? []
        self.battlesWon = try container.decodeIfPresent(Int.self, forKey: .battlesWon) ?? 0
        self.battlesLost = try container.decodeIfPresent(Int.self, forKey: .battlesLost) ?? 0
        self.visitedAirportIDs = try container.decodeIfPresent(Set<String>.self, forKey: .visitedAirportIDs) ?? []
        self.defeatedTrainerIDs = try container.decodeIfPresent(Set<String>.self, forKey: .defeatedTrainerIDs) ?? []
        self.collectedItemIDs = try container.decodeIfPresent(Set<String>.self, forKey: .collectedItemIDs) ?? []
        self.inventory = try container.decodeIfPresent([String: Int].self, forKey: .inventory) ?? [:]
        self.repelStepsLeft = try container.decodeIfPresent(Int.self, forKey: .repelStepsLeft) ?? 0
        self.position = try container.decodeIfPresent(GridPoint.self, forKey: .position)
        self.facing = try container.decodeIfPresent(Direction.self, forKey: .facing)
        self.rivalEncountersDone = try container.decodeIfPresent(Set<Int>.self, forKey: .rivalEncountersDone) ?? []
    }
}
```

- [ ] **Step 5: Run all core tests**

Run: `scripts/test-core.sh`
Expected: `Executed 334 tests, with 0 failures`

- [ ] **Step 6: Commit**

Run: `git add IFRCore/Sources/IFRCore/Adventure/Pixel/OverworldRenderer.swift IFRCore/Sources/IFRCore/Adventure/Pixel/Sprites/TileSprites.swift IFRCore/Sources/IFRCore/Adventure/Pixel/SpriteCatalog.swift IFRCore/Sources/IFRCore/Adventure/Circuit/AdventureSave.swift IFRCore/Tests/IFRCoreTests/OverworldRendererTests.swift IFRCore/Tests/IFRCoreTests/SpriteCatalogTests.swift IFRCore/Tests/IFRCoreTests/AdventureSaveTests.swift && git commit -m "M2-09a: Overworld renderer and tile sprites"`

---

### Task M2-09b: Overworld screen with tap-to-walk (Xcode)

**Files:**
- Create: `App/Screens/Adventure/OverworldScreenModel.swift`
- Create: `App/Screens/Adventure/OverworldScreenModel+Movement.swift`
- Create: `App/Screens/Adventure/OverworldScreenModel+Battles.swift`
- Create: `App/Screens/Adventure/OverworldScreen.swift`
- Modify: `App/Screens/Adventure/AdventureView.swift`
- Test: `AppTests/OverworldScreenModelTests.swift`
- Test: `AppUITests/SmokeTests.swift`

**Interfaces:**
- Consumes: `OverworldState.targeting`/`OverworldState.pendingPath` (`IFRCore/Sources/IFRCore/Adventure/Overworld/OverworldState.swift`), `OverworldTurn.advancing` and `OverworldOutcome` (`.../Overworld/OverworldTurn.swift`, `OverworldOutcome.swift`), `Camera.origin` (`.../Overworld/Camera.swift`), `Respawn.placement` (`.../Overworld/Respawn.swift`), `Pathfinder` (indirectly through `targeting`), `OverworldRenderer` and `IntegerScaler` (`.../Pixel/OverworldRenderer.swift`, `IntegerScaler.swift`), `GymApproach.approaching` and `CircuitRules` (`.../Circuit/GymApproach.swift`), `AdventureContent`/`TileMap`/`Gym`/`Airport` (`.../Content/*.swift`), `Opponent`, `OpponentHP.tuned`/`.cloud`, `PlayerHP.maximum`, `BattleTier` (`.../Battle/*.swift`), `AdventureSave` (`.../Circuit/AdventureSave.swift`); `StudyStore.adventureSave`, `updateAdventureSave`, `drawEncounterDeck`, `adventureMastery`, `finishBattle` (`App/Persistence/StudyStore.swift`); `BattleRun`, `BattleScreen`, `GBAScreen`, `DialogueBoxView` (existing `App/Screens/Adventure/*.swift`).
- Produces: `final class OverworldScreenModel` — `init(content: AdventureContent, store: StudyStore, now: @escaping () -> Date = { Date() }, makeRNG: @escaping () -> SeededRNG = ...)`; `func frameIndex(at: Date) -> Int`; `func tapped(at: CGPoint, viewSize: CGSize, displayScale: Double)`; `func advance(at: Date)`; `func dialogueFinished()`; `func challengeGym()`; `func clearActiveBattle()`; `func battleDismissed()`; `func sceneDidEnterBackground()`; `static func tile(at: CGPoint, viewSize: CGSize, displayScale: Double, cameraOrigin: GridPoint) -> GridPoint`; read-only-in-practice `state: OverworldState`, `save: AdventureSave`, `dialogue: DialogueScript?`, `challengeableGymID: GymID?`, `activeBattle: BattleRun?`. `struct OverworldScreen: View { let content: AdventureContent; let seed: UInt64? }`, used by later Milestone-2 work (M2-10) to add the D-pad and remaining door/trainer/item/rival wiring.

- [ ] **Step 1: Write the failing tests**

File: `AppTests/OverworldScreenModelTests.swift`

```swift
import Observation
import XCTest
import SwiftData
import IFRCore
@testable import IFRFlashCards

@MainActor
final class OverworldScreenModelTests: XCTestCase {
    private let base = Date(timeIntervalSince1970: 1_800_000_000)
    private let viewSize = CGSize(width: 240, height: 160)
    private let displayScale = 1.0

    private func makeStore() throws -> StudyStore {
        let schema = Schema([CardStateRecord.self, ReviewRecord.self, XPRecord.self,
                             StreakRecord.self, BadgeRecord.self, SettingsRecord.self,
                             AdventureSaveRecord.self, BattleRecord.self])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return try StudyStore(context: ModelContext(container), bank: QuestionBank.load())
    }

    private func makeContent(
        rows: [String], spawn: GridPoint, warp: (at: GridPoint, airportID: String)? = nil,
        area: (rect: GridRect, category: Category)? = nil, gymID: GymID? = nil
    ) throws -> AdventureContent {
        let json: [String: Any] = [
            "version": 1,
            "region": ["airports": regionAirports(gymID: gymID, warp: warp), "airways": []],
            "gyms": gymsJSON(gymID: gymID),
            "champion": championJSON(),
            "dialogue": dialogueJSON(gymID: gymID),
            "tileMap": tileMapJSON(rows: rows, spawn: spawn, warp: warp, area: area),
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        return try JSONDecoder().decode(AdventureContent.self, from: data)
    }

    private func regionAirports(gymID: GymID?, warp: (at: GridPoint, airportID: String)?) -> [[String: Any]] {
        guard let gymID, let warp else { return [] }
        return [[
            "id": warp.airportID, "name": "Test Field", "position": ["x": warp.at.x, "y": warp.at.y],
            "gymID": gymID.rawValue, "role": "gym",
        ]]
    }

    private func gymsJSON(gymID: GymID?) -> [[String: Any]] {
        guard let gymID else { return [] }
        return [[
            "id": gymID.rawValue, "leaderName": "Dr. Hypoxia", "nameplateName": "HYPOXIA",
            "leaderSpriteID": "leader-hypoxia", "badgeName": "Oxygen Badge", "questionCount": 3,
            "dialogue": ["intro": "gymIntro", "win": "gymWin", "lose": "gymLose"],
        ]]
    }

    private func championJSON() -> [String: Any] {
        ["name": "The DPE", "nameplateName": "THE DPE", "spriteID": "champion",
         "dialogue": ["intro": "c", "win": "c", "lose": "c"]]
    }

    private func dialogueJSON(gymID: GymID?) -> [String: Any] {
        guard gymID != nil else { return [:] }
        return ["gymIntro": ["pages": ["Welcome to the gym."]],
                "gymWin": ["pages": ["You win."]], "gymLose": ["pages": ["You lose."]]]
    }

    private func tileMapJSON(
        rows: [String], spawn: GridPoint, warp: (at: GridPoint, airportID: String)?,
        area: (rect: GridRect, category: Category)?
    ) -> [String: Any] {
        var map: [String: Any] = [
            "width": rows.first?.count ?? 0, "height": rows.count, "rows": rows,
            "spawn": ["x": spawn.x, "y": spawn.y],
        ]
        if let warp { map["warps"] = [["at": ["x": warp.at.x, "y": warp.at.y], "airportID": warp.airportID]] }
        if let area {
            map["areas"] = [[
                "id": "a", "category": area.category.rawValue,
                "rect": ["x": area.rect.x, "y": area.rect.y, "w": area.rect.w, "h": area.rect.h],
            ]]
        }
        return map
    }

    private func groundContent() throws -> AdventureContent {
        try makeContent(rows: [String(repeating: ".", count: 3)], spawn: GridPoint(x: 0, y: 0))
    }

    private func doorContent() throws -> AdventureContent {
        try makeContent(rows: ["..D"], spawn: GridPoint(x: 0, y: 0),
                        warp: (at: GridPoint(x: 2, y: 0), airportID: "KHYP"), gymID: .humanFactors)
    }

    private func cloudCorridorContent() throws -> AdventureContent {
        try makeContent(rows: ["D" + String(repeating: "~", count: 15)], spawn: GridPoint(x: 0, y: 0),
                        warp: (at: GridPoint(x: 0, y: 0), airportID: "KHYP"),
                        area: (rect: GridRect(x: 0, y: 0, w: 16, h: 1), category: .humanFactors), gymID: .humanFactors)
    }

    private func wideGroundContent() throws -> AdventureContent {
        try makeContent(rows: Array(repeating: String(repeating: ".", count: 20), count: 16),
                        spawn: GridPoint(x: 10, y: 8))
    }

    private func model(content: AdventureContent, store: StudyStore, seed: UInt64 = 7) -> OverworldScreenModel {
        OverworldScreenModel(content: content, store: store, now: { self.base }, makeRNG: { SeededRNG(seed: seed) })
    }

    private func tap(_ m: OverworldScreenModel, x: Int, y: Int = 0) {
        m.tapped(at: CGPoint(x: Double(x) * 16 + 1, y: Double(y) * 16 + 1), viewSize: viewSize, displayScale: displayScale)
    }

    private func advanceSteps(_ m: OverworldScreenModel, count: Int, from start: Date) -> Date {
        var now = start
        for _ in 0..<count {
            now = now.addingTimeInterval(Double(OverworldScreenModel.framesPerStep) / 60)
            m.advance(at: now)
        }
        return now
    }

    func testTapConvertsPointToTileUsingCameraAndScale() throws {
        let store = try makeStore()
        let content = try wideGroundContent()
        let m = model(content: content, store: store)
        m.tapped(at: CGPoint(x: 50, y: 34), viewSize: CGSize(width: 300, height: 200), displayScale: 2.0)
        XCTAssertEqual(m.state.pendingPath.last, GridPoint(x: 6, y: 5))
    }

    func testStepEveryEightFramesDoesNotWriteStore() throws {
        let store = try makeStore()
        let content = try groundContent()
        let m = model(content: content, store: store)
        tap(m, x: 2)
        let revisionBefore = store.revision
        m.advance(at: base.addingTimeInterval(Double(OverworldScreenModel.framesPerStep) / 60))
        XCTAssertEqual(store.revision, revisionBefore)
        XCTAssertEqual(m.state.position, GridPoint(x: 1, y: 0))
    }

    func testEveryStepGoesThroughOverworldTurn() throws {
        let store = try makeStore()
        let content = try groundContent()
        let m = model(content: content, store: store)
        tap(m, x: 2)
        _ = advanceSteps(m, count: 2, from: base)

        var rng = SeededRNG(seed: 7)
        let step1 = OverworldTurn.advancing(
            OverworldState(position: GridPoint(x: 0, y: 0), facing: .down), direction: .right,
            save: AdventureSave.new, map: content.tileMap!, trainers: [], rival: nil, using: &rng)
        let step2 = OverworldTurn.advancing(
            step1.state, direction: .right, save: step1.save, map: content.tileMap!,
            trainers: [], rival: nil, using: &rng)
        XCTAssertEqual(m.state, step2.state)
    }

    func testPositionSavedWhenPathCompletes() throws {
        let store = try makeStore()
        let content = try groundContent()
        let m = model(content: content, store: store)
        tap(m, x: 2)
        _ = advanceSteps(m, count: 2, from: base)
        XCTAssertEqual(store.adventureSave.position, GridPoint(x: 2, y: 0))
        XCTAssertTrue(m.state.pendingPath.isEmpty)
    }

    func testPositionSavedBeforeBattle() throws {
        let store = try makeStore()
        let content = try cloudCorridorContent()
        let m = model(content: content, store: store)
        tap(m, x: 15)
        _ = advanceSteps(m, count: 14, from: base)
        XCTAssertEqual(store.adventureSave.position, GridPoint(x: 14, y: 0))
    }

    func testPositionSavedOnSceneBackground() throws {
        let store = try makeStore()
        let content = try groundContent()
        let m = model(content: content, store: store)
        tap(m, x: 2)
        _ = advanceSteps(m, count: 1, from: base)
        m.sceneDidEnterBackground()
        XCTAssertEqual(store.adventureSave.position, m.state.position)
    }

    func testEncounterOutcomePresentsCloudBattleRun() throws {
        let store = try makeStore()
        let content = try cloudCorridorContent()
        let m = model(content: content, store: store)
        tap(m, x: 15)
        _ = advanceSteps(m, count: 14, from: base)
        XCTAssertNotNil(m.activeBattle)
        XCTAssertEqual(m.activeBattle?.opponent.tier, .cloud)
        XCTAssertEqual(m.activeBattle?.returnTo, GridPoint(x: 14, y: 0))
        XCTAssertTrue(m.state.pendingPath.isEmpty)
    }

    func testWarpOnUnlockedGymDoorTypesIntroThenShowsChallenge() throws {
        let store = try makeStore()
        let content = try doorContent()
        let m = model(content: content, store: store)
        tap(m, x: 2)
        _ = advanceSteps(m, count: 2, from: base)
        XCTAssertEqual(m.dialogue?.pages, ["Welcome to the gym."])
        XCTAssertEqual(m.challengeableGymID, .humanFactors)
        m.challengeGym()
        XCTAssertNotNil(m.activeBattle)
        XCTAssertEqual(m.activeBattle?.opponent.tier, .gym)
        XCTAssertEqual(m.activeBattle?.returnTo, GridPoint(x: 2, y: 0))
    }

    func testLossAwayFromDoorRespawnsAtNearestVisitedAirport() throws {
        let store = try makeStore()
        var seededSave = store.adventureSave
        seededSave.visitedAirportIDs = ["KHYP"]
        store.updateAdventureSave(seededSave)

        let content = try cloudCorridorContent()
        let m = model(content: content, store: store)
        tap(m, x: 15)
        _ = advanceSteps(m, count: 14, from: base)
        guard let run = m.activeBattle else { return XCTFail("expected a cloud battle") }
        let opening = BattleEngine.start(opponent: run.opponent, deck: run.deck, playerMaxHP: run.playerMaxHP, missDamage: run.missDamage)
        let (lost, _) = BattleEngine.forfeit(opening)
        store.finishBattle(lost)
        m.battleDismissed()

        XCTAssertEqual(m.state.position, GridPoint(x: 0, y: 0))
        XCTAssertEqual(m.state.facing, .down)
        XCTAssertEqual(store.adventureSave.position, GridPoint(x: 0, y: 0))
    }
}
```

Also added to `AppUITests/SmokeTests.swift` (its tenth named test, driving the real bundled `adventure-v1.json` content end to end through the new `walkButton`/`overworldScreen` entry point rather than a synthetic fixture):

```swift
    func testWalkingIntoCloudStartsBattleWithSeed() {
        let app = XCUIApplication()
        app.launchArguments += ["-adventureSeed", "7"]
        app.launch()
        app.tabBars.buttons["Adventure"].tap()
        app.buttons["walkButton"].tap()
        let overworld = app.otherElements["overworldScreen"]
        XCTAssertTrue(overworld.waitForExistence(timeout: 15))
        let cloudTarget = overworld.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.6))
        for _ in 0..<20 {
            cloudTarget.tap()
        }
        XCTAssertTrue(app.buttons["battleOption-0"].waitForExistence(timeout: 20))
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `scripts/test-app.sh` (App-target code; this machine cannot build the Xcode project, so this was not executed here — see the note below)

Expected: a compile failure, `cannot find type 'OverworldScreenModel' in scope`, in every test function of `OverworldScreenModelTests`, since neither `OverworldScreenModel` nor `OverworldScreen` existed before this task; `SmokeTests.swift`'s new test fails to compile for the same reason once `walkButton`/`overworldScreen` are referenced, and would otherwise fail at runtime with `Failed to find matching element` for `app.buttons["walkButton"]` since `AdventureView` had no such button before this task's change.

Before writing the implementation, the exact rules the new code has to satisfy were checked by running the real `IFRCore` package this app code calls into, since that half of the plan runs on Linux: `bash scripts/test-core.sh` — `Executed 334 tests, with 0 failures (0 unexpected)`, unchanged by this task (no `IFRCore` source was modified). A throwaway `IFRCoreTests` file (written, run with `--filter`, and deleted before committing) exercised the exact `OverworldTurn.advancing`/`Camera.origin`/`IntegerScaler.scale`/`GymApproach.approaching`/`Respawn.placement` call sequences the new `OverworldScreenModel` performs, against the same JSON fixtures the App-target tests build, confirming: with `SeededRNG(seed: 7)`, a 15-tile cloud corridor first rolls a hit on the 14th consecutive cloud step (`OverworldTurn.advancing` called 14 times returns `.encounter(category: .humanFactors)` on the 14th call, `.blocked`/`.none`/no trigger on the previous 13); an 8-tile ground-then-door walk never consumes that trigger; `Camera.origin(following: (10, 8), mapWidth: 20, mapHeight: 16, viewportWidth: 15, viewportHeight: 10)` is `(3, 3)`; `IntegerScaler.scale(viewWidth: 300, viewHeight: 200, displayScale: 2.0)` is `2`; and `Respawn.placement` for a save at `(14, 0)` with only `"KHYP"`'s door at `(0, 0)` visited returns `((0, 0), .down)`. That run: `Test Suite 'ZZScratchVerifyTests' passed ... Executed 5 tests, with 0 failures (0 unexpected)`.

- [ ] **Step 3: Write the implementation**

File: `App/Screens/Adventure/OverworldScreenModel.swift`

```swift
import Foundation
import CoreGraphics
import IFRCore

@Observable
@MainActor
final class OverworldScreenModel {
    static let framesPerStep = 8

    var state: OverworldState
    var save: AdventureSave
    var dialogue: DialogueScript?
    var challengeableGymID: GymID?
    var activeBattle: BattleRun?
    var stepPhaseStart: Date

    let content: AdventureContent
    let map: TileMap
    let store: StudyStore
    let now: () -> Date
    var rng: SeededRNG
    var battlesLostBeforeBattle = 0

    init(
        content: AdventureContent, store: StudyStore, now: @escaping () -> Date = { Date() },
        makeRNG: @escaping () -> SeededRNG = { SeededRNG(seed: UInt64(Date().timeIntervalSince1970)) }
    ) {
        self.content = content
        self.store = store
        self.now = now
        map = content.tileMap ?? TileMap(width: 1, height: 1, rows: [[.ground]])
        rng = makeRNG()
        let startingSave = store.adventureSave
        save = startingSave
        state = OverworldState(position: startingSave.position ?? map.spawn, facing: startingSave.facing ?? .down)
        stepPhaseStart = now()
    }

    func frameIndex(at date: Date) -> Int {
        max(0, Int(date.timeIntervalSince(stepPhaseStart) * 60))
    }

    func tapped(at point: CGPoint, viewSize: CGSize, displayScale: Double) {
        let origin = cameraOrigin()
        let target = OverworldScreenModel.tile(at: point, viewSize: viewSize, displayScale: displayScale, cameraOrigin: origin)
        state = state.targeting(target, in: map, blocked: blockedPositions())
    }

    func advance(at date: Date) {
        guard activeBattle == nil, dialogue == nil, !state.pendingPath.isEmpty else { return }
        guard frameIndex(at: date) >= Self.framesPerStep else { return }
        step(at: date)
    }

    func dialogueFinished() {
        dialogue = nil
    }

    func challengeGym() {
        guard let gymID = challengeableGymID, let gym = gym(for: gymID),
              let airport = content.region.airports.first(where: { $0.gymID == gymID }) else { return }
        challengeableGymID = nil
        persist()
        presentGymBattle(gym: gym, gymID: gymID, airport: airport)
    }

    func clearActiveBattle() {
        activeBattle = nil
    }

    func battleDismissed() {
        activeBattle = nil
        save = store.adventureSave
        guard save.battlesLost > battlesLostBeforeBattle else { return }
        respawnAfterLoss()
    }

    func sceneDidEnterBackground() {
        persist()
    }

    func respawnAfterLoss() {
        let placement = Respawn.placement(save: save, map: map)
        state = OverworldState(position: placement.position, facing: placement.facing)
        persist()
    }

    func persist() {
        var updated = save
        updated.position = state.position
        updated.facing = state.facing
        save = updated
        store.updateAdventureSave(updated)
    }
}
```

- [ ] **Step 4: Write the implementation**

File: `App/Screens/Adventure/OverworldScreenModel+Movement.swift`

```swift
import Foundation
import CoreGraphics
import IFRCore

extension OverworldScreenModel {
    func step(at date: Date) {
        guard let direction = nextDirection() else { return }
        let result = OverworldTurn.advancing(
            state, direction: direction, save: save, map: map,
            trainers: content.trainers, rival: content.rival, using: &rng)
        state = result.state
        save = result.save
        stepPhaseStart = date
        handle(result.outcome)
    }

    func nextDirection() -> Direction? {
        guard let next = state.pendingPath.first else { return nil }
        if next.x == state.position.x + 1 { return .right }
        if next.x == state.position.x - 1 { return .left }
        if next.y == state.position.y + 1 { return .down }
        if next.y == state.position.y - 1 { return .up }
        return nil
    }

    func blockedPositions() -> Set<GridPoint> {
        Set(content.trainers.filter { !save.defeatedTrainerIDs.contains($0.id) }.map(\.position))
    }

    func cameraOrigin() -> GridPoint {
        Camera.origin(following: state.position, mapWidth: map.width, mapHeight: map.height,
                      viewportWidth: OverworldRenderer.viewportWidth, viewportHeight: OverworldRenderer.viewportHeight)
    }

    static func tile(at point: CGPoint, viewSize: CGSize, displayScale: Double, cameraOrigin: GridPoint) -> GridPoint {
        let scale = IntegerScaler.scale(viewWidth: viewSize.width, viewHeight: viewSize.height, displayScale: displayScale)
        let cell = Double(OverworldRenderer.cellSize * scale) / displayScale
        let dx = Int((point.x / cell).rounded(.down))
        let dy = Int((point.y / cell).rounded(.down))
        return GridPoint(x: cameraOrigin.x + dx, y: cameraOrigin.y + dy)
    }

    func handle(_ outcome: OverworldOutcome) {
        switch outcome {
        case .encounter(let category): presentCloudBattle(category: category)
        case .warp(let airportID): approachAirport(airportID)
        default: persistIfPathComplete()
        }
    }

    func persistIfPathComplete() {
        guard state.pendingPath.isEmpty else { return }
        persist()
    }
}
```

- [ ] **Step 5: Write the implementation**

File: `App/Screens/Adventure/OverworldScreenModel+Battles.swift`

```swift
import Foundation
import IFRCore

extension OverworldScreenModel {
    func presentGymBattle(gym: Gym, gymID: GymID, airport: Airport) {
        let deck = store.drawEncounterDeck(count: gym.questionCount, categories: [gymID.category])
        let opponent = gym.opponent(maxHP: OpponentHP.tuned(for: deck), airportID: airport.id)
        startBattle(opponent: opponent, deck: deck, level: store.adventureMastery(for: gymID.category).level,
                   dialogueRefs: gym.dialogue, firstTime: !save.badges.contains(gymID))
    }

    func presentCloudBattle(category: Category) {
        let deck = store.drawEncounterDeck(count: 1, categories: [category])
        guard let question = deck.first else { return }
        persist()
        startBattle(opponent: cloudOpponent(category: category, question: question), deck: deck,
                   level: store.adventureMastery(for: category).level, dialogueRefs: nil, firstTime: false)
    }

    func approachAirport(_ airportID: String) {
        persistIfPathComplete()
        guard let airport = content.region.airports.first(where: { $0.id == airportID }), case .gym = airport.role,
              let gymID = airport.gymID, let gym = gym(for: gymID) else { return }
        let result = GymApproach.approaching(gym, content: content, save: save)
        dialogue = result.dialogue
        challengeableGymID = result.challengeableGymID
    }

    func gym(for gymID: GymID) -> Gym? {
        content.gyms.first { $0.id == gymID }
    }

    func cloudOpponent(category: Category, question: Question) -> Opponent {
        Opponent(id: "cloud-\(category.rawValue)", name: "Wild \(category.displayName)",
                nameplateName: String(category.displayName.uppercased().prefix(7)),
                spriteID: "cloud-\(category.rawValue)", tier: .cloud, maxHP: OpponentHP.cloud(for: question))
    }

    func startBattle(opponent: Opponent, deck: [Question], level: MasteryLevel, dialogueRefs: DialogueRefs?, firstTime: Bool) {
        battlesLostBeforeBattle = save.battlesLost
        activeBattle = BattleRun(
            opponent: opponent, deck: deck, playerMaxHP: PlayerHP.maximum(for: level), missDamage: nil,
            playerSpriteID: "player-back", playerPlateName: "PILOT",
            introDialogue: script(dialogueRefs?.intro), winDialogue: script(dialogueRefs?.win),
            loseDialogue: script(dialogueRefs?.lose), firstTime: firstTime, returnTo: state.position)
    }

    func script(_ key: String?) -> DialogueScript {
        guard let key else { return DialogueScript(pages: []) }
        return content.dialogue[key] ?? DialogueScript(pages: [])
    }
}
```

- [ ] **Step 6: Write the implementation**

File: `App/Screens/Adventure/OverworldScreen.swift`

```swift
import SwiftUI
import IFRCore

struct OverworldScreen: View {
    @Environment(StudyStore.self) private var store
    @Environment(\.displayScale) private var displayScale
    @Environment(\.scenePhase) private var scenePhase
    let content: AdventureContent
    let seed: UInt64?

    @State private var model: OverworldScreenModel?

    var body: some View {
        Group {
            if let model {
                canvas(model: model)
            } else {
                Color.clear.onAppear { model = makeModel() }
            }
        }
        .accessibilityIdentifier("overworldScreen")
    }

    private func makeModel() -> OverworldScreenModel {
        guard let seed else { return OverworldScreenModel(content: content, store: store) }
        return OverworldScreenModel(content: content, store: store, makeRNG: { SeededRNG(seed: seed) })
    }

    private func canvas(model: OverworldScreenModel) -> some View {
        GeometryReader { geometry in
            TimelineView(.animation) { context in
                let frame = OverworldRenderer.frame(
                    map: model.map, state: model.state, trainers: content.trainers,
                    defeated: model.save.defeatedTrainerIDs, atFrame: model.frameIndex(at: context.date))
                ZStack {
                    GBAScreen(frame: frame)
                    if let dialogue = model.dialogue {
                        DialogueBoxView(script: dialogue, scale: 1, displayScale: displayScale,
                                       onFinished: { model.dialogueFinished() })
                    }
                    if let gymID = model.challengeableGymID {
                        Button("Challenge") { model.challengeGym() }
                            .accessibilityIdentifier("gym-\(gymID.rawValue)")
                    }
                }
                .contentShape(Rectangle())
                .gesture(tapGesture(model: model, geometry: geometry))
                .onChange(of: context.date) { _, date in model.advance(at: date) }
            }
        }
        .onChange(of: scenePhase) { _, phase in if phase == .background { model.sceneDidEnterBackground() } }
        .fullScreenCover(item: activeBattleBinding(model)) { run in
            BattleScreen(run: run).onDisappear { model.battleDismissed() }
        }
    }

    private func tapGesture(model: OverworldScreenModel, geometry: GeometryProxy) -> some Gesture {
        SpatialTapGesture().onEnded { event in
            model.tapped(at: event.location, viewSize: geometry.size, displayScale: displayScale)
        }
    }

    private func activeBattleBinding(_ model: OverworldScreenModel) -> Binding<BattleRun?> {
        Binding(get: { model.activeBattle }, set: { newValue in if newValue == nil { model.clearActiveBattle() } })
    }
}
```

- [ ] **Step 7: Modify `AdventureView.swift`**

The type that changed, in the file's new complete version:

```swift
struct AdventureView: View {
    @Environment(StudyStore.self) private var store
    @State private var content: AdventureContent?
    @State private var activeBattle: BattleRun?
    @State private var showingOverworld = false

    private let seed: UInt64?
    private let seededSave: AdventureSave?

    init() {
        seed = AdventureView.readSeedArgument(CommandLine.arguments)
        seededSave = AdventureView.readSaveArgument(CommandLine.arguments)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let content {
                    RegionMapScreen(content: content, startBattle: { activeBattle = $0 })
                } else {
                    ProgressView()
                        .onAppear { load() }
                }
            }
            .toolbar {
                if content != nil {
                    ToolbarItem { Button("Walk") { showingOverworld = true }.accessibilityIdentifier("walkButton") }
                }
            }
        }
        .fullScreenCover(item: $activeBattle) { run in
            BattleScreen(run: run)
        }
        .fullScreenCover(isPresented: $showingOverworld) {
            if let content {
                OverworldScreen(content: content, seed: seed)
            }
        }
    }

    private func load() {
        content = try? AdventureContent.load()
        if let seededSave {
            store.updateAdventureSave(seededSave)
        }
    }

    private static func readSeedArgument(_ arguments: [String]) -> UInt64? {
        guard let flagIndex = arguments.firstIndex(of: "-adventureSeed"),
              arguments.indices.contains(flagIndex + 1) else { return nil }
        return UInt64(arguments[flagIndex + 1])
    }

    private static func readSaveArgument(_ arguments: [String]) -> AdventureSave? {
        guard let flagIndex = arguments.firstIndex(of: "-adventureSaveJSON"),
              arguments.indices.contains(flagIndex + 1),
              let data = arguments[flagIndex + 1].data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(AdventureSave.self, from: data)
    }
}
```

- [ ] **Step 8: Run all core tests**

Run: `scripts/test-core.sh`
Expected: `Executed 334 tests, with 0 failures (0 unexpected)` (unchanged — no `IFRCore` file was touched by this task; the number is the same before and after)

For the App target: `scripts/test-app.sh` is expected to compile `OverworldScreenModelTests` and `SmokeTests` and run them on the iPhone 16 simulator in Xcode, which this machine cannot do; not executed here.

- [ ] **Step 9: Commit**

Run: `git add App/Screens/Adventure/OverworldScreen.swift App/Screens/Adventure/OverworldScreenModel.swift App/Screens/Adventure/OverworldScreenModel+Movement.swift App/Screens/Adventure/OverworldScreenModel+Battles.swift App/Screens/Adventure/AdventureView.swift AppTests/OverworldScreenModelTests.swift AppUITests/SmokeTests.swift && git commit -m "M2-09b: Overworld screen with tap-to-walk"`

---

### Task M2-10: D-pad, doors, trainers, items, rival wiring (Xcode)

**Files:**
- Create: `App/Screens/Adventure/DPadOverlay.swift`
- Create: `App/Screens/Adventure/BagSheet.swift`
- Modify: `App/Persistence/Records.swift`
- Modify: `App/Persistence/StudyStore.swift`
- Modify: `App/Screens/Adventure/AdventureView.swift`
- Modify: `App/Screens/Adventure/RegionMapScreen.swift`
- Modify: `App/Screens/Adventure/BattleRun.swift`
- Modify: `App/Screens/Adventure/OverworldScreen.swift`
- Modify: `App/Screens/Adventure/OverworldScreenModel.swift`
- Modify: `App/Screens/Adventure/OverworldScreenModel+Movement.swift`
- Modify: `App/Screens/Adventure/OverworldScreenModel+Battles.swift`
- Modify: `App/Screens/Adventure/EliteFourScreenModel.swift`
- Modify: `App/Screens/Adventure/ChampionScreen.swift`
- Modify: `App/Screens/Adventure/BattleScreen.swift`
- Modify: `App/Screens/Adventure/BattleScreenModel.swift`
- Test: `AppTests/AdventureStoreTests.swift`
- Test: `AppUITests/SmokeTests.swift`

**Interfaces:**
- Consumes: `OverworldTurn.advancing`, `OverworldState`, `OverworldOutcome`, `Respawn.placement`, `Camera.origin` (`IFRCore/Sources/IFRCore/Adventure/Overworld/OverworldTurn.swift`, `OverworldState.swift`, `Respawn.swift`, `Camera.swift`); `GymApproach.approaching`/`eliteFourLockedDialogue`/`championLockedDialogue` (`IFRCore/Sources/IFRCore/Adventure/Circuit/GymApproach.swift`); `CircuitRules` (`Adventure/Circuit/CircuitRules.swift`); `Inventory.adding`/`using` and `DirectTo.targets`/`destination` (`Adventure/Overworld/Inventory.swift`, `DirectTo.swift`); `RivalPlanner.weakestCategories`, `RivalSpec.opponent` (`Adventure/Overworld/RivalPlanner.swift`, `Adventure/Content/RivalSpec.swift`); `Trainer` (`Adventure/Content/Trainer.swift`); `BattleEngine.useItem` (`Adventure/Battle/BattleEngine.swift`); `OpponentHP`, `PlayerHP`, `MasteryLevel.level(forRetention:)`; `StudyStore.adventureSave`, `.updateAdventureSave`, `.drawEncounterDeck`, `.adventureMastery`, `.retentionByCategory`, `.reviewedRetentionByCategory`, `.finishBattle` (`App/Persistence/StudyStore.swift`).
- Produces: `StudyStore.markTrainerDefeated(_ trainerID: String)`, `StudyStore.markRivalEncounterDone(_ index: Int)`, `StudyStore.collectItem(_ itemID: String)`, `StudyStore.useInventoryItem(_ itemID: String)`; `SettingsRecord.dpadEnabled: Bool`; `OverworldScreenModel.dpadStep(_:)`, `.warpTo(_:)`, `.eliteFourDismissed()`, `.championDismissed()`, `.showingEliteFour`, `.showingChampion`, `.pendingTrainerID`, `.pendingRivalIndex`; `BattleRun.items: [Item]`; `BattleScreenModel.openBag()`, `.useItem(_:)`, `.showingBag`; `DPadOverlay(onPress:)`; `BagSheet(items:inventory:onUse:)`; `RegionMapScreen(content:onSelect:)` as the Direct-To picker, used by later Milestone 3 tasks that add companions and the tower.

- [ ] **Step 1: Write the failing tests**

File: `AppTests/AdventureStoreTests.swift` (new private factories and test methods appended to the existing class; the whole added block, which follows the existing `championOpponent()` factory)

```swift
    private func trainerOpponent(id: String = "student-ana", maxHP: Int) -> Opponent {
        Opponent(id: id, name: "Student Pilot Ana", nameplateName: "ANA", spriteID: "trainer-student",
                 tier: .trainer, maxHP: maxHP)
    }

    private func rivalOpponent(maxHP: Int) -> Opponent {
        Opponent(id: "rival", name: "Skyler", nameplateName: "SKYLER", spriteID: "rival", tier: .trainer, maxHP: maxHP)
    }

    private func cloudOpponent(maxHP: Int) -> Opponent {
        Opponent(id: "cloud-humanFactors", name: "Wild Human Factors", nameplateName: "HUMAN F",
                 spriteID: "cloud-humanFactors", tier: .cloud, maxHP: maxHP)
    }

    private func emptyDialogue() throws -> DialogueScript {
        try JSONDecoder().decode(DialogueScript.self, from: Data("{\"pages\":[]}".utf8))
    }

    private func regionContent(airportIDs: [String]) throws -> AdventureContent {
        let airports = airportIDs.map { id in
            ["id": id, "name": id, "position": ["x": 0, "y": 0], "gymID": NSNull(), "role": "waypoint"] as [String: Any]
        }
        let json: [String: Any] = [
            "version": 1,
            "region": ["airports": airports, "airways": []],
            "gyms": [],
            "champion": ["name": "The DPE", "nameplateName": "THE DPE", "spriteID": "champion",
                        "dialogue": ["intro": "c", "win": "c", "lose": "c"]],
            "dialogue": [:],
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        return try JSONDecoder().decode(AdventureContent.self, from: data)
    }

    private func dpadContent(
        rows: [String], spawn: GridPoint,
        trainer: (id: String, position: GridPoint, facing: String, range: Int)? = nil
    ) throws -> AdventureContent {
        var json: [String: Any] = [
            "version": 1,
            "region": ["airports": [], "airways": []],
            "gyms": [],
            "champion": ["name": "The DPE", "nameplateName": "THE DPE", "spriteID": "champion",
                        "dialogue": ["intro": "c", "win": "c", "lose": "c"]],
            "dialogue": [:],
            "tileMap": ["width": rows.first?.count ?? 0, "height": rows.count, "rows": rows,
                       "spawn": ["x": spawn.x, "y": spawn.y]],
        ]
        if let trainer {
            json["trainers"] = [[
                "id": trainer.id, "name": "Trainer", "nameplateName": "T1", "spriteID": "trainer-student",
                "position": ["x": trainer.position.x, "y": trainer.position.y], "facing": trainer.facing,
                "range": trainer.range, "questionCount": 1, "categories": ["humanFactors"],
                "dialogue": ["intro": "tIntro", "win": "tWin", "lose": "tLose"],
            ]]
        }
        let data = try JSONSerialization.data(withJSONObject: json)
        return try JSONDecoder().decode(AdventureContent.self, from: data)
    }

    func testTrainerWinAwardsTwentyFiveAndMarksDefeated() throws {
        let (store, _) = try makeStore()
        let deck = Array(store.bank.questions.filter { $0.category == .humanFactors && $0.isMultipleChoiceCapable }.prefix(1))
        let opponent = trainerOpponent(maxHP: 1)
        let opening = BattleEngine.start(opponent: opponent, deck: deck, playerMaxHP: 100)
        let (won, _) = BattleEngine.answer(opening, selectedIndex: deck[0].correctIndex!, answerSeconds: 10)
        XCTAssertEqual(won.outcome, .won)

        let xpBefore = store.totalXP
        store.finishBattle(won)
        store.markTrainerDefeated(opponent.id)

        XCTAssertEqual(store.totalXP - xpBefore, 25)
        XCTAssertTrue(store.adventureSave.defeatedTrainerIDs.contains("student-ana"))
    }

    func testCloudWinAwardsFive() throws {
        let (store, _) = try makeStore()
        let question = store.bank.questions.first { $0.isMultipleChoiceCapable }!
        let opponent = cloudOpponent(maxHP: 1)
        let opening = BattleEngine.start(opponent: opponent, deck: [question], playerMaxHP: 100)
        let (won, _) = BattleEngine.answer(opening, selectedIndex: question.correctIndex!, answerSeconds: 10)
        XCTAssertEqual(won.outcome, .won)

        let xpBefore = store.totalXP
        store.finishBattle(won)
        XCTAssertEqual(store.totalXP - xpBefore, 5)
    }

    func testItemPickupPersistsInSave() throws {
        let (store, _) = try makeStore()
        store.collectItem("potion")
        XCTAssertEqual(store.adventureSave.inventory["potion"], 1)
        XCTAssertTrue(store.adventureSave.collectedItemIDs.contains("potion"))
    }

    func testRivalWinMarksEncounterDone() throws {
        let (store, _) = try makeStore()
        let deck = Array(store.bank.questions.filter(\.isMultipleChoiceCapable).prefix(1))
        let opponent = rivalOpponent(maxHP: 1)
        let opening = BattleEngine.start(opponent: opponent, deck: deck, playerMaxHP: 100)
        let (won, _) = BattleEngine.answer(opening, selectedIndex: deck[0].correctIndex!, answerSeconds: 10)
        XCTAssertEqual(won.outcome, .won)

        store.finishBattle(won)
        store.markRivalEncounterDone(0)
        XCTAssertTrue(store.adventureSave.rivalEncountersDone.contains(0))
    }

    func testRivalLossAlsoMarksEncounterDone() throws {
        let (store, _) = try makeStore()
        let deck = Array(store.bank.questions.filter(\.isMultipleChoiceCapable).prefix(1))
        let opponent = rivalOpponent(maxHP: 1_000)
        let opening = BattleEngine.start(opponent: opponent, deck: deck, playerMaxHP: 100)
        let (lost, _) = BattleEngine.forfeit(opening)
        XCTAssertEqual(lost.outcome, .lost)

        store.finishBattle(lost)
        store.markRivalEncounterDone(1)
        XCTAssertTrue(store.adventureSave.rivalEncountersDone.contains(1))
    }

    func testDirectToPickerListsOnlyVisitedAirports() throws {
        let (store, _) = try makeStore()
        var save = store.adventureSave
        save.visitedAirportIDs = ["KHYP"]
        store.updateAdventureSave(save)
        let content = try regionContent(airportIDs: ["KHYP", "KGYR"])

        let targets = DirectTo.targets(save: store.adventureSave, region: content.region)
        XCTAssertEqual(targets.map(\.id), ["KHYP"])
    }

    func testDPadToggleDefaultsOffAndPersists() throws {
        let (store, _) = try makeStore()
        XCTAssertFalse(store.settings.dpadEnabled)
        store.settings.dpadEnabled = true
        XCTAssertTrue(store.settings.dpadEnabled)
    }

    func testDPadStepsOneTile() throws {
        let (store, _) = try makeStore()
        let content = try dpadContent(rows: [String(repeating: ".", count: 3)], spawn: GridPoint(x: 0, y: 0))
        let model = OverworldScreenModel(content: content, store: store, now: { self.now })
        model.dpadStep(.right)
        XCTAssertEqual(model.state.position, GridPoint(x: 1, y: 0))
    }

    func testDPadCannotWalkThroughUndefeatedTrainer() throws {
        let (store, _) = try makeStore()
        let content = try dpadContent(
            rows: [String(repeating: ".", count: 3)], spawn: GridPoint(x: 0, y: 0),
            trainer: (id: "t1", position: GridPoint(x: 1, y: 0), facing: "left", range: 1))
        let model = OverworldScreenModel(content: content, store: store, now: { self.now })
        model.dpadStep(.right)
        XCTAssertEqual(model.state.position, GridPoint(x: 0, y: 0))
    }

    func testBattleBagButtonOpensSheetWithoutAdvancing() throws {
        let (store, _) = try makeStore()
        let deck = Array(store.bank.questions.filter { $0.category == .humanFactors && $0.isMultipleChoiceCapable }.prefix(3))
        let dialogue = try emptyDialogue()
        let run = BattleRun(
            opponent: gymOpponent(maxHP: 70), deck: deck, playerMaxHP: 100, missDamage: nil,
            playerSpriteID: "player-back", playerPlateName: "PILOT",
            introDialogue: dialogue, winDialogue: dialogue, loseDialogue: dialogue,
            firstTime: false, returnTo: nil, items: [])
        let model = BattleScreenModel(run: run, store: store, now: { self.now })
        let cursorBefore = model.state.cursor

        model.openBag()

        XCTAssertTrue(model.showingBag)
        XCTAssertEqual(model.state.cursor, cursorBefore)
    }

    func testWaypointAirportHasNoDoor() throws {
        let content = try AdventureContent.load()
        guard let map = content.tileMap else { return }
        let waypointIDs = Set(content.region.airports.filter { $0.role == .waypoint }.map(\.id))
        XCTAssertTrue(Set(map.doorAirportIDs.values).isDisjoint(with: waypointIDs))
    }
```

File: `AppUITests/SmokeTests.swift` (helper additions plus the four M2-10 UI tests; the pre-existing airport/RegionMap-root tests in the same file were rewritten in Step 3 because the tab root changes from `RegionMapScreen` to `OverworldScreen`, see Deviations)

```swift
    private func doorApproachSave(x: Int, y: Int, badges: Int = 0) -> AdventureSave {
        var save = save(withBadges: badges)
        save.position = GridPoint(x: x, y: y)
        save.facing = .up
        return save
    }

    private func tapUp(_ overworld: XCUIElement, times: Int = 10) {
        let above = overworld.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
        for _ in 0..<times {
            above.tap()
        }
    }

    func testUnlockedGymDoorTypesIntroAndShowsChallenge() {
        let app = launch(withSave: doorApproachSave(x: 3, y: 15))
        app.tabBars.buttons["Adventure"].tap()
        let overworld = app.otherElements["overworldScreen"]
        XCTAssertTrue(overworld.waitForExistence(timeout: 15))
        tapUp(overworld, times: 6)
        XCTAssertTrue(app.buttons["gym-humanFactors"].waitForExistence(timeout: 15))
        app.buttons["gym-humanFactors"].tap()
        XCTAssertTrue(app.buttons["battleOption-0"].waitForExistence(timeout: 15))
        app.buttons["battleOption-0"].tap()
        XCTAssertTrue(app.buttons["battleQuit"].waitForExistence(timeout: 5))
        app.buttons["battleQuit"].tap()
        XCTAssertTrue(overworld.waitForExistence(timeout: 15))
    }

    func testLockedGymDoorTypesLockedMessageAndStepsBack() {
        let app = launch(withSave: doorApproachSave(x: 7, y: 15))
        app.tabBars.buttons["Adventure"].tap()
        let overworld = app.otherElements["overworldScreen"]
        XCTAssertTrue(overworld.waitForExistence(timeout: 15))
        tapUp(overworld, times: 6)
        XCTAssertTrue(app.staticTexts["You need the Oxygen Badge first."].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["gym-instrumentsAndSystems"].exists)
    }

    func testEliteFourDoorPushesScreenWhenUnlocked() {
        let app = launch(withSave: doorApproachSave(x: 34, y: 15, badges: 8))
        app.tabBars.buttons["Adventure"].tap()
        let overworld = app.otherElements["overworldScreen"]
        XCTAssertTrue(overworld.waitForExistence(timeout: 15))
        tapUp(overworld, times: 6)
        XCTAssertTrue(app.otherElements["eliteFourScreen"].waitForExistence(timeout: 15))
    }

    func testChampionDoorTypesLockedMessageWhenLocked() {
        let app = launch(withSave: doorApproachSave(x: 37, y: 15, badges: 8))
        app.tabBars.buttons["Adventure"].tap()
        let overworld = app.otherElements["overworldScreen"]
        XCTAssertTrue(overworld.waitForExistence(timeout: 15))
        tapUp(overworld, times: 6)
        XCTAssertTrue(app.staticTexts["We finish the exam, pilot. Every question counts."].waitForExistence(timeout: 15))
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `scripts/test-app.sh` (Xcode/iPhone 16 simulator only; `AdventureStoreTests` and `SmokeTests` cannot run on this Linux machine, so this step was not executed here)
Expected: the project fails to build `IFRFlashCardsTests`/`IFRFlashCardsUITests` before any assertion runs, because the new test code names symbols the implementation did not yet have:
```
error: value of type 'StudyStore' has no member 'markTrainerDefeated'
error: value of type 'StudyStore' has no member 'markRivalEncounterDone'
error: value of type 'StudyStore' has no member 'collectItem'
error: value of type 'SettingsRecord' has no member 'dpadEnabled'
error: value of type 'OverworldScreenModel' has no member 'dpadStep'
error: extra argument 'items' in call
error: value of type 'BattleScreenModel' has no member 'showingBag'
```

- [ ] **Step 3: Write the implementation**

File: `App/Screens/Adventure/DPadOverlay.swift`

```swift
import SwiftUI
import IFRCore

struct DPadOverlay: View {
    let onPress: (Direction) -> Void

    var body: some View {
        VStack(spacing: 2) {
            directionButton(.up)
            HStack(spacing: 2) {
                directionButton(.left)
                Color.clear.frame(width: 44, height: 44)
                directionButton(.right)
            }
            directionButton(.down)
        }
    }

    private func directionButton(_ direction: Direction) -> some View {
        Button {
            onPress(direction)
        } label: {
            Color.black.opacity(0.35)
        }
        .frame(width: 44, height: 44)
        .accessibilityIdentifier("dpad-\(direction.rawValue)")
    }
}
```

File: `App/Screens/Adventure/BagSheet.swift`

```swift
import SwiftUI
import IFRCore

struct BagSheet: View {
    let items: [Item]
    let inventory: [String: Int]
    let onUse: (Item) -> Void

    var body: some View {
        List(carriedItems, id: \.id) { item in
            Button("\(item.name) (\(inventory[item.id] ?? 0))") { onUse(item) }
                .accessibilityIdentifier("bagItem-\(item.id)")
        }
        .accessibilityIdentifier("bagSheet")
    }

    private var carriedItems: [Item] {
        items.filter { (inventory[$0.id] ?? 0) > 0 }
    }
}
```

File: `App/Persistence/Records.swift` — added field on the existing `SettingsRecord`

```swift
@Model
final class SettingsRecord {
    var newCardsPerDay: Int = 20
    var dailyGoalCards: Int = 10
    var unlockedCategoriesRaw: [String] = IFRCore.Category.allCases.map(\.rawValue)
    var reminderHour: Int = 18
    var reminderMinute: Int = 0
    var reminderEnabled: Bool = true
    var streakRiskEnabled: Bool = true
    var examDate: Date?
    var dpadEnabled: Bool = false

    init() {}

    var studySettings: StudySettings {
        StudySettings(newCardsPerDay: newCardsPerDay,
                      unlockedCategories: Set(unlockedCategoriesRaw.compactMap(IFRCore.Category.init(rawValue:))),
                      dailyGoalCards: dailyGoalCards)
    }
}
```

File: `App/Persistence/StudyStore.swift` — four new methods added to the `// MARK: - Adventure save` section, right after `updateAdventureSave`

```swift
    func markTrainerDefeated(_ trainerID: String) {
        var next = adventureSave
        next.defeatedTrainerIDs.insert(trainerID)
        updateAdventureSave(next)
    }

    func markRivalEncounterDone(_ index: Int) {
        var next = adventureSave
        next.rivalEncountersDone.insert(index)
        updateAdventureSave(next)
    }

    func collectItem(_ itemID: String) {
        var next = Inventory.adding(itemID, to: adventureSave)
        next.collectedItemIDs.insert(itemID)
        updateAdventureSave(next)
    }

    func useInventoryItem(_ itemID: String) {
        guard let next = Inventory.using(itemID, from: adventureSave) else { return }
        updateAdventureSave(next)
    }
```

File: `App/Screens/Adventure/BattleRun.swift` — whole file, `items` is the new trailing field

```swift
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
    let items: [Item]
}
```

File: `App/Screens/Adventure/AdventureView.swift` — whole file; the tab root is now `OverworldScreen` (was `RegionMapScreen` behind a "Walk" button)

```swift
import SwiftUI
import IFRCore

struct AdventureView: View {
    @Environment(StudyStore.self) private var store
    @State private var content: AdventureContent?
    @State private var showingBadgeCase = false
    @State private var showingHallOfFame = false

    private let seed: UInt64?
    private let seededSave: AdventureSave?

    init() {
        seed = AdventureView.readSeedArgument(CommandLine.arguments)
        seededSave = AdventureView.readSaveArgument(CommandLine.arguments)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let content {
                    OverworldScreen(content: content, seed: seed)
                } else {
                    ProgressView()
                        .onAppear { load() }
                }
            }
            .toolbar {
                if content != nil {
                    ToolbarItem { Button("Badges") { showingBadgeCase = true }.accessibilityIdentifier("badgeCase") }
                    ToolbarItem { Button("Hall of Fame") { showingHallOfFame = true }.accessibilityIdentifier("hallOfFame") }
                }
            }
            .navigationDestination(isPresented: $showingBadgeCase) {
                if let content { BadgeCaseScreen(content: content) }
            }
            .navigationDestination(isPresented: $showingHallOfFame) {
                HallOfFameScreen()
            }
        }
    }

    private func load() {
        content = try? AdventureContent.load()
        if let seededSave {
            store.updateAdventureSave(seededSave)
        }
    }

    private static func readSeedArgument(_ arguments: [String]) -> UInt64? {
        guard let flagIndex = arguments.firstIndex(of: "-adventureSeed"),
              arguments.indices.contains(flagIndex + 1) else { return nil }
        return UInt64(arguments[flagIndex + 1])
    }

    private static func readSaveArgument(_ arguments: [String]) -> AdventureSave? {
        guard let flagIndex = arguments.firstIndex(of: "-adventureSaveJSON"),
              arguments.indices.contains(flagIndex + 1),
              let data = arguments[flagIndex + 1].data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(AdventureSave.self, from: data)
    }
}
```

File: `App/Screens/Adventure/RegionMapScreen.swift` — whole file, now the Direct-To picker instead of the tab-root region map

```swift
import SwiftUI
import IFRCore

struct RegionMapScreen: View {
    @Environment(StudyStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let content: AdventureContent
    let onSelect: (Airport) -> Void

    var body: some View {
        List(targets, id: \.id) { airport in
            Button(airport.name) { select(airport) }
                .accessibilityIdentifier("directTo-\(airport.id)")
        }
        .accessibilityIdentifier("directToPicker")
    }

    private var targets: [Airport] {
        DirectTo.targets(save: store.adventureSave, region: content.region)
    }

    private func select(_ airport: Airport) {
        onSelect(airport)
        dismiss()
    }
}
```

File: `App/Screens/Adventure/OverworldScreen.swift` — whole file; adds the Map toolbar button and Direct-To sheet, the D-pad overlay behind `store.settings.dpadEnabled`, and pushes `EliteFourScreen`/`ChampionScreen` from the model's door flags

```swift
import SwiftUI
import IFRCore

struct OverworldScreen: View {
    @Environment(StudyStore.self) private var store
    @Environment(\.displayScale) private var displayScale
    @Environment(\.scenePhase) private var scenePhase
    let content: AdventureContent
    let seed: UInt64?

    @State private var model: OverworldScreenModel?
    @State private var showingMap = false

    var body: some View {
        Group {
            if let model {
                canvas(model: model)
            } else {
                Color.clear.onAppear { model = makeModel() }
            }
        }
        .accessibilityIdentifier("overworldScreen")
        .toolbar {
            ToolbarItem { Button("Map") { showingMap = true }.accessibilityIdentifier("regionMapButton") }
        }
        .sheet(isPresented: $showingMap) {
            RegionMapScreen(content: content, onSelect: { airport in warp(to: airport) })
        }
        .navigationDestination(isPresented: eliteFourBinding()) { EliteFourScreen(content: content) }
        .navigationDestination(isPresented: championBinding()) { ChampionScreen(content: content) }
    }

    private func makeModel() -> OverworldScreenModel {
        guard let seed else { return OverworldScreenModel(content: content, store: store) }
        return OverworldScreenModel(content: content, store: store, makeRNG: { SeededRNG(seed: seed) })
    }

    private func canvas(model: OverworldScreenModel) -> some View {
        GeometryReader { geometry in
            TimelineView(.animation) { context in
                let frame = OverworldRenderer.frame(
                    map: model.map, state: model.state, trainers: content.trainers,
                    defeated: model.save.defeatedTrainerIDs, atFrame: model.frameIndex(at: context.date))
                ZStack(alignment: .bottomLeading) {
                    GBAScreen(frame: frame)
                    if let dialogue = model.dialogue {
                        DialogueBoxView(script: dialogue, scale: 1, displayScale: displayScale,
                                       onFinished: { model.dialogueFinished() })
                    }
                    if let gymID = model.challengeableGymID {
                        Button("Challenge") { model.challengeGym() }
                            .accessibilityIdentifier("gym-\(gymID.rawValue)")
                    }
                    if store.settings.dpadEnabled {
                        DPadOverlay(onPress: { model.dpadStep($0) })
                    }
                }
                .contentShape(Rectangle())
                .gesture(tapGesture(model: model, geometry: geometry))
                .onChange(of: context.date) { _, date in model.advance(at: date) }
            }
        }
        .onChange(of: scenePhase) { _, phase in if phase == .background { model.sceneDidEnterBackground() } }
        .onChange(of: model.showingEliteFour) { _, showing in if !showing { model.eliteFourDismissed() } }
        .onChange(of: model.showingChampion) { _, showing in if !showing { model.championDismissed() } }
        .fullScreenCover(item: activeBattleBinding(model)) { run in
            BattleScreen(run: run).onDisappear { model.battleDismissed() }
        }
    }

    private func tapGesture(model: OverworldScreenModel, geometry: GeometryProxy) -> some Gesture {
        SpatialTapGesture().onEnded { event in
            model.tapped(at: event.location, viewSize: geometry.size, displayScale: displayScale)
        }
    }

    private func activeBattleBinding(_ model: OverworldScreenModel) -> Binding<BattleRun?> {
        Binding(get: { model.activeBattle }, set: { newValue in if newValue == nil { model.clearActiveBattle() } })
    }

    private func eliteFourBinding() -> Binding<Bool> {
        Binding(get: { model?.showingEliteFour ?? false }, set: { model?.showingEliteFour = $0 })
    }

    private func championBinding() -> Binding<Bool> {
        Binding(get: { model?.showingChampion ?? false }, set: { model?.showingChampion = $0 })
    }

    private func warp(to airport: Airport) {
        guard let destination = DirectTo.destination(of: airport, in: model?.map ?? content.tileMap ?? TileMap(width: 1, height: 1, rows: [[.ground]])) else { return }
        model?.warpTo(destination)
    }
}
```

File: `App/Screens/Adventure/OverworldScreenModel.swift` — whole file; adds `dpadStep`, door-push state (`showingEliteFour`/`showingChampion`), pending trainer/rival tracking, and `warpTo`

```swift
import Foundation
import CoreGraphics
import IFRCore

@Observable
@MainActor
final class OverworldScreenModel {
    static let framesPerStep = 8

    var state: OverworldState
    var save: AdventureSave
    var dialogue: DialogueScript?
    var challengeableGymID: GymID?
    var activeBattle: BattleRun?
    var showingEliteFour = false
    var showingChampion = false
    var showingBag = false
    var stepPhaseStart: Date

    let content: AdventureContent
    let map: TileMap
    let store: StudyStore
    let now: () -> Date
    var rng: SeededRNG
    var battlesLostBeforeBattle = 0
    var lastDirection: Direction?
    var pendingTrainerID: String?
    var pendingRivalIndex: Int?

    init(
        content: AdventureContent, store: StudyStore, now: @escaping () -> Date = { Date() },
        makeRNG: @escaping () -> SeededRNG = { SeededRNG(seed: UInt64(Date().timeIntervalSince1970)) }
    ) {
        self.content = content
        self.store = store
        self.now = now
        map = content.tileMap ?? TileMap(width: 1, height: 1, rows: [[.ground]])
        rng = makeRNG()
        let startingSave = store.adventureSave
        save = startingSave
        state = OverworldState(position: startingSave.position ?? map.spawn, facing: startingSave.facing ?? .down)
        stepPhaseStart = now()
    }

    func frameIndex(at date: Date) -> Int {
        max(0, Int(date.timeIntervalSince(stepPhaseStart) * 60))
    }

    func tapped(at point: CGPoint, viewSize: CGSize, displayScale: Double) {
        let origin = cameraOrigin()
        let target = OverworldScreenModel.tile(at: point, viewSize: viewSize, displayScale: displayScale, cameraOrigin: origin)
        state = state.targeting(target, in: map, blocked: blockedPositions())
    }

    func advance(at date: Date) {
        guard activeBattle == nil, dialogue == nil, !state.pendingPath.isEmpty else { return }
        guard frameIndex(at: date) >= Self.framesPerStep else { return }
        step(at: date)
    }

    func dpadStep(_ direction: Direction) {
        guard activeBattle == nil, dialogue == nil else { return }
        state = state.interrupted()
        move(direction, at: now())
    }

    func dialogueFinished() {
        dialogue = nil
    }

    func challengeGym() {
        guard let gymID = challengeableGymID, let gym = gym(for: gymID),
              let airport = content.region.airports.first(where: { $0.gymID == gymID }) else { return }
        challengeableGymID = nil
        persist()
        presentGymBattle(gym: gym, gymID: gymID, airport: airport)
    }

    func clearActiveBattle() {
        activeBattle = nil
    }

    func battleDismissed() {
        activeBattle = nil
        save = store.adventureSave
        let won = save.battlesLost == battlesLostBeforeBattle
        settleTrainerAndRival(won: won)
        guard !won else { return }
        respawnAfterLoss()
    }

    func settleTrainerAndRival(won: Bool) {
        if let trainerID = pendingTrainerID {
            if won { store.markTrainerDefeated(trainerID) }
            pendingTrainerID = nil
            save = store.adventureSave
        }
        if let rivalIndex = pendingRivalIndex {
            store.markRivalEncounterDone(rivalIndex)
            pendingRivalIndex = nil
            save = store.adventureSave
        }
    }

    func eliteFourDismissed() {
        showingEliteFour = false
        state.facing = .down
        persist()
    }

    func championDismissed() {
        showingChampion = false
        state.facing = .down
        persist()
    }

    func warpTo(_ point: GridPoint) {
        state = OverworldState(position: point, facing: .down)
        persist()
    }

    func sceneDidEnterBackground() {
        persist()
    }

    func respawnAfterLoss() {
        let placement = Respawn.placement(save: save, map: map)
        state = OverworldState(position: placement.position, facing: placement.facing)
        persist()
    }

    func persist() {
        var updated = save
        updated.position = state.position
        updated.facing = state.facing
        save = updated
        store.updateAdventureSave(updated)
    }
}
```

File: `App/Screens/Adventure/OverworldScreenModel+Movement.swift` — whole file; `step` now delegates to a shared `move(_:at:)` so the D-pad and tap-to-walk share one path, and `handle` gains the trainer/rival/pickup/sign branches

```swift
import Foundation
import CoreGraphics
import IFRCore

extension OverworldScreenModel {
    func step(at date: Date) {
        guard let direction = nextDirection() else { return }
        move(direction, at: date)
    }

    func move(_ direction: Direction, at date: Date) {
        let result = OverworldTurn.advancing(
            state, direction: direction, save: save, map: map,
            trainers: content.trainers, rival: content.rival, using: &rng)
        lastDirection = direction
        state = result.state
        save = result.save
        stepPhaseStart = date
        handle(result.outcome)
    }

    func nextDirection() -> Direction? {
        guard let next = state.pendingPath.first else { return nil }
        if next.x == state.position.x + 1 { return .right }
        if next.x == state.position.x - 1 { return .left }
        if next.y == state.position.y + 1 { return .down }
        if next.y == state.position.y - 1 { return .up }
        return nil
    }

    func blockedPositions() -> Set<GridPoint> {
        Set(content.trainers.filter { !save.defeatedTrainerIDs.contains($0.id) }.map(\.position))
    }

    func cameraOrigin() -> GridPoint {
        Camera.origin(following: state.position, mapWidth: map.width, mapHeight: map.height,
                      viewportWidth: OverworldRenderer.viewportWidth, viewportHeight: OverworldRenderer.viewportHeight)
    }

    static func tile(at point: CGPoint, viewSize: CGSize, displayScale: Double, cameraOrigin: GridPoint) -> GridPoint {
        let scale = IntegerScaler.scale(viewWidth: viewSize.width, viewHeight: viewSize.height, displayScale: displayScale)
        let cell = Double(OverworldRenderer.cellSize * scale) / displayScale
        let dx = Int((point.x / cell).rounded(.down))
        let dy = Int((point.y / cell).rounded(.down))
        return GridPoint(x: cameraOrigin.x + dx, y: cameraOrigin.y + dy)
    }

    func handle(_ outcome: OverworldOutcome) {
        switch outcome {
        case .encounter(let category): presentCloudBattle(category: category)
        case .warp(let airportID): approachAirport(airportID)
        case .sighted(let trainer): presentTrainerBattle(trainer)
        case .rival(let index): presentRivalBattle(encounterIndex: index)
        case .pickup(let itemID): handlePickup(itemID)
        case .sign(let text): dialogue = DialogueScript(pages: [text])
        default: persistIfPathComplete()
        }
    }

    func handlePickup(_ itemID: String) {
        save = Inventory.adding(itemID, to: save)
        persistIfPathComplete()
    }

    func persistIfPathComplete() {
        guard state.pendingPath.isEmpty else { return }
        persist()
    }
}
```

File: `App/Screens/Adventure/OverworldScreenModel+Battles.swift` — whole file; adds trainer and rival battle presentation, and gym/eliteFour/champion door approach with the locked-door step-back

```swift
import Foundation
import IFRCore

extension OverworldScreenModel {
    func presentGymBattle(gym: Gym, gymID: GymID, airport: Airport) {
        let deck = store.drawEncounterDeck(count: gym.questionCount, categories: [gymID.category])
        let opponent = gym.opponent(maxHP: OpponentHP.tuned(for: deck), airportID: airport.id)
        startBattle(opponent: opponent, deck: deck, level: store.adventureMastery(for: gymID.category).level,
                   dialogueRefs: gym.dialogue, firstTime: !save.badges.contains(gymID))
    }

    func presentCloudBattle(category: Category) {
        let deck = store.drawEncounterDeck(count: 1, categories: [category])
        guard let question = deck.first else { return }
        persist()
        startBattle(opponent: cloudOpponent(category: category, question: question), deck: deck,
                   level: store.adventureMastery(for: category).level, dialogueRefs: nil, firstTime: false)
    }

    func presentTrainerBattle(_ trainer: Trainer) {
        let deck = store.drawEncounterDeck(count: trainer.questionCount, categories: trainer.categories)
        let opponent = Opponent(id: trainer.id, name: trainer.name, nameplateName: trainer.nameplateName,
                                spriteID: trainer.spriteID, tier: .trainer, maxHP: OpponentHP.tuned(for: deck))
        pendingTrainerID = trainer.id
        persist()
        startBattle(opponent: opponent, deck: deck, level: mixedLevel(), dialogueRefs: trainer.dialogue, firstTime: false)
    }

    func presentRivalBattle(encounterIndex: Int) {
        guard let rival = content.rival, rival.encounters.indices.contains(encounterIndex) else { return }
        let categories = RivalPlanner.weakestCategories(count: 3, retention: store.retentionByCategory())
        let deck = store.drawEncounterDeck(count: rival.questionCount, categories: categories)
        let opponent = rival.opponent(maxHP: OpponentHP.tuned(for: deck))
        pendingRivalIndex = encounterIndex
        persist()
        startBattle(opponent: opponent, deck: deck, level: mixedLevel(),
                   dialogueRefs: rival.encounters[encounterIndex].dialogue, firstTime: false)
    }

    func mixedLevel() -> MasteryLevel {
        let retentions = store.reviewedRetentionByCategory().values
        let mean = retentions.isEmpty ? 0 : retentions.reduce(0, +) / Double(retentions.count)
        return MasteryLevel.level(forRetention: mean)
    }

    func approachAirport(_ airportID: String) {
        persistIfPathComplete()
        guard let airport = content.region.airports.first(where: { $0.id == airportID }) else { return }
        switch airport.role {
        case .gym: approachGymDoor(airport)
        case .eliteFour: approachEliteFourDoor()
        case .champion: approachChampionDoor()
        case .waypoint: break
        }
    }

    func approachGymDoor(_ airport: Airport) {
        guard let gymID = airport.gymID, let gym = gym(for: gymID) else { return }
        let result = GymApproach.approaching(gym, content: content, save: save)
        dialogue = result.dialogue
        challengeableGymID = result.challengeableGymID
        guard result.challengeableGymID == nil else { return }
        stepBackFromDoor()
    }

    func approachEliteFourDoor() {
        if let locked = GymApproach.eliteFourLockedDialogue(content: content, save: save) {
            dialogue = locked
            stepBackFromDoor()
        } else {
            showingEliteFour = true
        }
    }

    func approachChampionDoor() {
        if let locked = GymApproach.championLockedDialogue(content: content, save: save) {
            dialogue = locked
            stepBackFromDoor()
        } else {
            showingChampion = true
        }
    }

    func stepBackFromDoor() {
        guard let lastDirection else { return }
        let back = GridPoint(x: state.position.x - lastDirection.delta.x, y: state.position.y - lastDirection.delta.y)
        state = OverworldState(position: back, facing: .down)
    }

    func gym(for gymID: GymID) -> Gym? {
        content.gyms.first { $0.id == gymID }
    }

    func cloudOpponent(category: Category, question: Question) -> Opponent {
        Opponent(id: "cloud-\(category.rawValue)", name: "Wild \(category.displayName)",
                nameplateName: String(category.displayName.uppercased().prefix(7)),
                spriteID: "cloud-\(category.rawValue)", tier: .cloud, maxHP: OpponentHP.cloud(for: question))
    }

    func startBattle(opponent: Opponent, deck: [Question], level: MasteryLevel, dialogueRefs: DialogueRefs?, firstTime: Bool) {
        battlesLostBeforeBattle = save.battlesLost
        activeBattle = BattleRun(
            opponent: opponent, deck: deck, playerMaxHP: PlayerHP.maximum(for: level), missDamage: nil,
            playerSpriteID: "player-back", playerPlateName: "PILOT",
            introDialogue: script(dialogueRefs?.intro), winDialogue: script(dialogueRefs?.win),
            loseDialogue: script(dialogueRefs?.lose), firstTime: firstTime, returnTo: state.position,
            items: content.items)
    }

    func script(_ key: String?) -> DialogueScript {
        guard let key else { return DialogueScript(pages: []) }
        return content.dialogue[key] ?? DialogueScript(pages: [])
    }
}
```

File: `App/Screens/Adventure/EliteFourScreenModel.swift` — `challengeCurrentMember()`'s `BattleRun` now passes `items: content.items`

```swift
    func challengeCurrentMember() {
        guard let member = currentMember else { return }
        let deck = store.drawEncounterDeck(count: member.questionCount, categories: member.categories)
        battlesWonBeforeBattle = store.adventureSave.battlesWon
        activeBattle = BattleRun(
            opponent: eliteOpponent(member: member, deck: deck), deck: deck, playerMaxHP: run.playerMaxHP,
            missDamage: nil, playerSpriteID: "player-back", playerPlateName: "PILOT",
            introDialogue: content.dialogue[member.dialogue.intro] ?? DialogueScript(pages: []),
            winDialogue: content.dialogue[member.dialogue.win] ?? DialogueScript(pages: []),
            loseDialogue: content.dialogue[member.dialogue.lose] ?? DialogueScript(pages: []),
            firstTime: false, returnTo: nil, items: content.items)
    }
```

File: `App/Screens/Adventure/ChampionScreen.swift` — `startChampionBattle()`'s `BattleRun` now passes `items: content.items`

```swift
    private func startChampionBattle() {
        let deck = store.championDeck()
        let opponent = Opponent(
            id: "champion", name: content.champion.name, nameplateName: content.champion.nameplateName,
            spriteID: content.champion.spriteID, tier: .champion, maxHP: ChampionBattle.opponentHP)
        activeBattle = BattleRun(
            opponent: opponent, deck: deck, playerMaxHP: ChampionBattle.playerHP, missDamage: nil,
            playerSpriteID: "player-back", playerPlateName: "PILOT",
            introDialogue: content.dialogue[content.champion.dialogue.intro] ?? DialogueScript(pages: []),
            winDialogue: content.dialogue[content.champion.dialogue.win] ?? DialogueScript(pages: []),
            loseDialogue: content.dialogue[content.champion.dialogue.lose] ?? DialogueScript(pages: []),
            firstTime: store.adventureSave.championWins == 0, returnTo: nil, items: content.items)
    }
```

File: `App/Screens/Adventure/BattleScreenModel.swift` — added `showingBag` and the `openBag`/`useItem` methods

```swift
    private(set) var finishBattleCallCount = 0
    private(set) var dismissed = false
    var showingBag = false
```
```swift
    func openBag() {
        showingBag = true
    }

    func useItem(_ item: Item) {
        showingBag = false
        state = BattleEngine.useItem(state, effect: item.effect)
        store.useInventoryItem(item.id)
    }
```

File: `App/Screens/Adventure/BattleScreen.swift` — added the `battleBag` toolbar button and the `BagSheet`

```swift
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Quit") { model.quit(at: context.date) }
                            .accessibilityIdentifier("battleQuit")
                    }
                    ToolbarItem {
                        Button("Bag") { model.openBag() }
                            .accessibilityIdentifier("battleBag")
                    }
                }
                .sheet(isPresented: bagBinding(model)) {
                    BagSheet(items: run.items, inventory: store.adventureSave.inventory,
                            onUse: { model.useItem($0) })
                }
```
```swift
    private func bagBinding(_ model: BattleScreenModel) -> Binding<Bool> {
        Binding(get: { model.showingBag }, set: { model.showingBag = $0 })
    }
```

- [ ] **Step 4: Run all core tests**

Run: `scripts/test-core.sh`
Expected: `Executed 334 tests, with 0 failures (0 unexpected) in 1.879 (1.879) seconds`

(This work item touches only `App`, `AppTests` and `AppUITests`; `IFRCore` is untouched, so the core suite's count and result are unchanged from before this task and were re-run only to confirm nothing broke.)

- [ ] **Step 5: Commit**

Run: `git add App/Persistence/Records.swift App/Persistence/StudyStore.swift App/Screens/Adventure/AdventureView.swift App/Screens/Adventure/BagSheet.swift App/Screens/Adventure/BattleRun.swift App/Screens/Adventure/BattleScreen.swift App/Screens/Adventure/BattleScreenModel.swift App/Screens/Adventure/ChampionScreen.swift App/Screens/Adventure/DPadOverlay.swift App/Screens/Adventure/EliteFourScreenModel.swift App/Screens/Adventure/OverworldScreen.swift App/Screens/Adventure/OverworldScreenModel.swift App/Screens/Adventure/OverworldScreenModel+Battles.swift App/Screens/Adventure/OverworldScreenModel+Movement.swift App/Screens/Adventure/RegionMapScreen.swift AppTests/AdventureStoreTests.swift AppUITests/SmokeTests.swift && git commit -m "M2-10: D-pad, doors, trainers, items, rival wiring"`

## Deviations from the spec

- **Root-screen swap breaks pre-existing SmokeTests.** Section 2.9 requires that "from Milestone 2 the overworld is the tab root and `RegionMapScreen` becomes the Direct-To picker." That change makes the M1-14 tests that tapped `airport-KHYP`/`airport-KELF`/`airport-KCHP` directly on the tab root (`testAdventureTabShowsRegionMap`, `testStartingFirstGymShowsQuestionAndOptions`, `testAnsweringOptionAdvancesTurn`, `testBattleQuitReturnsToRegionMap`, `testSeededSaveWithEightBadgesUnlocksEliteFour`, `testEliteFourLockedUntilEightBadges`, `testChampionLockedUntilEliteFourCleared`, `testChampionChallengeStartsSixtyQuestionBattleAsTheDPE`, `testWalkingIntoCloudStartsBattleWithSeed`) meaningless as written, since those buttons no longer exist outside the Direct-To picker. Rather than leave them referencing removed identifiers, I rewrote their bodies to walk to the same doors on the overworld (seeding `AdventureSave.position`/`.facing` next to the door and tapping the canvas), keeping every original test name. `testStartingFirstGymShowsQuestionAndOptions` was folded into the new `testUnlockedGymDoorTypesIntroAndShowsChallenge`, which covers the same assertion plus the M2-10 door/quit round trip, per the item's explicit "each `OverworldOutcome` maps to one store call or one presentation, and doors follow the section 2.9 door behaviour" instruction — this is a deliberate, spec-driven behavior change, not a dropped test.
- **Trainer/rival identity through `Opponent`.** The spec's `Opponent` (section 2.1) carries `gymID`/`airportID` for gyms but nothing for a trainer id or a rival encounter index, and `BattleResolution.apply` (section 2.4) never mentions `defeatedTrainerIDs` or `rivalEncountersDone`. I kept `Opponent` and `BattleResolution` unchanged and instead had `OverworldScreenModel` remember `pendingTrainerID`/`pendingRivalIndex` when it starts a trainer or rival battle, then call the two new `StudyStore` methods (`markTrainerDefeated`, `markRivalEncounterDone`) once the battle is dismissed. This keeps `IFRCore` exactly as earlier milestones defined it and puts the extra bookkeeping in the app layer, which is where the spec's own "each `OverworldOutcome` maps to one store call" sentence points.
- **Unverifiable app-target UI-test coordinates.** `testUnlockedGymDoorTypesIntroAndShowsChallenge`, `testLockedGymDoorTypesLockedMessageAndStepsBack`, `testEliteFourDoorPushesScreenWhenUnlocked` and `testChampionDoorTypesLockedMessageWhenLocked` seed the player one tile below each door (read from the bundled `adventure-v1.json`) and tap the canvas repeatedly above the player, mirroring the existing `testWalkingIntoCloudStartsBattleWithSeed` pattern; this cannot be run or screenshotted on this Linux machine, so the exact tap count/offset is a best-effort match to the renderer's camera math, not a verified value.
- **Latent pre-existing risk, not fixed here.** Several `IFRCore` content types used from the App target (`DialogueScript`, `Airport`, `Gym`, `Item`, `RegionMap`) have no `public init`, only a `Codable` implementation; the App target already relied on `DialogueScript(pages: [])` as a fallback before this task (in `ChampionScreen.swift`, `EliteFourScreenModel.swift` and the pre-existing `+Battles.swift`). I kept that existing pattern for consistency rather than widen scope by adding public initializers to `IFRCore` content types, since no work item in Milestone 2 lists that file. If this turns out to fail in Xcode, the fix is a one-line `public init(pages:)` on `DialogueScript` in `IFRCore/Sources/IFRCore/Adventure/Content/DialogueScript.swift`.
- **`AdventureStoreTests` test-class placement for non-store tests.** The spec lists `testDPadStepsOneTile` and `testDPadCannotWalkThroughUndefeatedTrainer` under `AdventureStoreTests` even though they exercise `OverworldScreenModel`; I followed the spec's literal class assignment rather than moving them to `OverworldScreenModelTests`, and copied a small JSON content factory local to `AdventureStoreTests` (per the "each test file copies the private factories it needs" rule) instead of reusing `OverworldScreenModelTests`'s private one.

---
