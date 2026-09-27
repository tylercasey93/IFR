# Adventure Mode — Milestone 1: Engine and Gym Circuit

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a complete, playable gym circuit as the fifth tab: a pure battle engine with GBA-style rendering primitives, an encounter deck composed from the existing spaced-repetition queue and quiz engine, validated content, a persisted save, the region map, the battle screen, eight gyms, the Elite Four and the Champion (the existing mock exam), with every answer routed through the existing review path.

**Architecture:** New IFRCore folder `Adventure/` (`Battle`, `Encounters`, `Content`, `Circuit`, `Pixel`) holds all rules and every pixel renderer as pure, deterministic value types; `App/Screens/Adventure/` rasterizes `PixelFrame`s with SwiftUI `Canvas`, overlays the pixel font, and drives the engine through a same-file `StudyStore` extension that persists one `AdventureSave` blob.

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

### Task M1-01: Toolchain check, CI and guard tests

**Files:**
- Create: `IFRCore/Sources/IFRCore/Adventure/.gitkeep` (keeps the empty `Adventure/` directory in git; SwiftPM ignores dotfiles)
- Create: `<repo root>/.github/workflows/core-tests.yml`
- Test: `IFRCore/Tests/IFRCoreTests/SourceGuardTests.swift`
- Test: `IFRCore/Tests/IFRCoreTests/StringLiteralStripper.swift` (test-target helper, no comments)
- Test: `IFRCore/Tests/IFRCoreTests/StringLiteralStripperTests.swift`

**Interfaces:**
- Consumes: `scripts/test-core.sh` and `scripts/install-swift-linux.sh` (existing Linux scripts); `#filePath` and `FileManager` from Foundation; the existing nine `IFRCoreTests` suites (54 tests), which must stay green.
- Produces: `StringLiteralStripper.strip(_ text: String) -> String` (test target only; strips single-line, multi-line and interpolated string literals so the comment guard can grep code alone); the guard class `SourceGuardTests`, which every later Adventure item must keep green; the empty `IFRCore/Sources/IFRCore/Adventure/` folder that M1-02 onward fill; CI running `scripts/test-core.sh` on every push and pull request.

- [ ] **Step 1: Write the failing tests**

File: `IFRCore/Tests/IFRCoreTests/SourceGuardTests.swift`

```swift
import XCTest
@testable import IFRCore

final class SourceGuardTests: XCTestCase {
    private let testFile = URL(fileURLWithPath: #filePath)
    private let forbiddenImports = ["import UIKit", "import SwiftUI", "import Combine"]
    private let forbiddenSchedulerCalls = [".review(", "CardState("]
    private let workflowMarkers = [
        "ubuntu-latest", "FlashCards/scripts/install-swift-linux.sh", "FlashCards/scripts/test-core.sh",
    ]

    private var sourcesRoot: URL {
        testFile.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/IFRCore")
    }

    private var adventureRoot: URL { sourcesRoot.appendingPathComponent("Adventure") }

    private func swiftFiles(under directory: URL) -> [URL] {
        let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil)
        let files = enumerator?.compactMap { $0 as? URL } ?? []
        return files.filter { $0.pathExtension == "swift" }.sorted { $0.path < $1.path }
    }

    private func repositoryRoot() -> URL? {
        var directory = testFile.deletingLastPathComponent()
        while directory.path != "/" {
            if FileManager.default.fileExists(atPath: directory.appendingPathComponent(".git").path) {
                return directory
            }
            directory = directory.deletingLastPathComponent()
        }
        return nil
    }

    private func assertNoFile(under directory: URL, contains fragments: [String]) throws {
        for file in swiftFiles(under: directory) {
            let text = try String(contentsOf: file, encoding: .utf8)
            for fragment in fragments {
                XCTAssertFalse(text.contains(fragment), "\(file.lastPathComponent) contains \(fragment)")
            }
        }
    }

    private func assertAdventureDirectoryExists() {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: adventureRoot.path, isDirectory: &isDirectory)
        XCTAssertTrue(exists && isDirectory.boolValue, "Sources/IFRCore/Adventure is missing")
    }

    func testIFRCoreSourcesImportOnlyFoundation() throws {
        XCTAssertFalse(swiftFiles(under: sourcesRoot).isEmpty, "no sources found at \(sourcesRoot.path)")
        try assertNoFile(under: sourcesRoot, contains: forbiddenImports)
    }

    func testAdventureSourcesNeverCallSchedulerReviewOrBuildCardState() throws {
        assertAdventureDirectoryExists()
        try assertNoFile(under: adventureRoot, contains: forbiddenSchedulerCalls)
    }

    func testAdventureSourcesContainNoComments() throws {
        assertAdventureDirectoryExists()
        for file in swiftFiles(under: adventureRoot) {
            let text = try String(contentsOf: file, encoding: .utf8)
            let code = StringLiteralStripper.strip(text)
            XCTAssertFalse(code.contains("//"), "\(file.lastPathComponent) contains a line comment")
            XCTAssertFalse(code.contains("/*"), "\(file.lastPathComponent) contains a block comment")
        }
    }

    func testCoreWorkflowInstallsSwiftThenRunsCoreScript() throws {
        let workflow = try coreWorkflowText()
        let positions = workflowMarkers.map { workflow.range(of: $0)?.lowerBound }
        let found = positions.compactMap { $0 }
        XCTAssertEqual(found.count, workflowMarkers.count, "workflow must name \(workflowMarkers)")
        XCTAssertEqual(found, found.sorted(), "install must come before the test script")
    }

    func testCoreWorkflowRunsOnPushAndPullRequest() throws {
        let workflow = try coreWorkflowText()
        XCTAssertTrue(workflow.contains("push"))
        XCTAssertTrue(workflow.contains("pull_request"))
    }

    private func coreWorkflowText() throws -> String {
        let root = try XCTUnwrap(repositoryRoot(), "no .git above \(testFile.path)")
        let workflow = root.appendingPathComponent(".github/workflows/core-tests.yml")
        return try String(contentsOf: workflow, encoding: .utf8)
    }
}
```

File: `IFRCore/Tests/IFRCoreTests/StringLiteralStripperTests.swift`

```swift
import XCTest
@testable import IFRCore

final class StringLiteralStripperTests: XCTestCase {
    func testKeepsCodeAndDropsLiterals() {
        let source = "let url = \"https://faa.gov\"\nlet text = \"\"\"\n// not a comment\n\"\"\"\nlet a = \"\\(b[\"c\"])\"\n"
        let code = StringLiteralStripper.strip(source)
        XCTAssertEqual(code, "let url = \nlet text = \nlet a = \n")
    }

    func testKeepsRealComments() {
        let code = StringLiteralStripper.strip("let x = \"a\" // trailing\n/* block */")
        XCTAssertEqual(code, "let x =  // trailing\n/* block */")
    }
}
```

File: `IFRCore/Tests/IFRCoreTests/StringLiteralStripper.swift`

```swift
struct StringLiteralStripper {
    private let characters: [Character]
    private var index = 0
    private var code = ""

    static func strip(_ text: String) -> String {
        var stripper = StringLiteralStripper(characters: Array(text))
        return stripper.stripped()
    }

    private init(characters: [Character]) {
        self.characters = characters
    }

    private mutating func stripped() -> String {
        while index < characters.count {
            if characters[index] == "\"" {
                skipLiteral()
            } else {
                code.append(characters[index])
                index += 1
            }
        }
        return code
    }

    private func hasTripleQuote(at position: Int) -> Bool {
        position + 2 < characters.count
            && characters[position...(position + 2)].allSatisfy { $0 == "\"" }
    }

    private mutating func skipLiteral() {
        let delimiterLength = hasTripleQuote(at: index) ? 3 : 1
        index += delimiterLength
        while index < characters.count {
            if characters[index] == "\\" {
                skipEscape()
            } else if closesLiteral(delimiterLength: delimiterLength) {
                index += delimiterLength
                return
            } else {
                index += 1
            }
        }
    }

    private func closesLiteral(delimiterLength: Int) -> Bool {
        delimiterLength == 3 ? hasTripleQuote(at: index) : characters[index] == "\""
    }

    private mutating func skipEscape() {
        index += 1
        guard index < characters.count else { return }
        if characters[index] == "(" {
            skipInterpolation()
        } else {
            index += 1
        }
    }

    private mutating func skipInterpolation() {
        var depth = 0
        repeat {
            if characters[index] == "\"" {
                skipLiteral()
                continue
            }
            depth += characters[index] == "(" ? 1 : characters[index] == ")" ? -1 : 0
            index += 1
        } while depth > 0 && index < characters.count
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `scripts/test-core.sh --filter SourceGuardTests`
Expected:
```
error: SourceGuardTests.testAdventureSourcesContainNoComments : XCTAssertTrue failed - Sources/IFRCore/Adventure is missing
error: SourceGuardTests.testAdventureSourcesNeverCallSchedulerReviewOrBuildCardState : XCTAssertTrue failed - Sources/IFRCore/Adventure is missing
error: SourceGuardTests.testCoreWorkflowInstallsSwiftThenRunsCoreScript : threw error "Error Domain=NSCocoaErrorDomain Code=260 "The file doesn’t exist.""
Executed 7 tests, with 4 failures (2 unexpected)
```
`testIFRCoreSourcesImportOnlyFoundation` passes from the start because the existing sources already import only Foundation. To see every guard go red, drop a probe file into `IFRCore/Sources/IFRCore/Adventure/` containing `#if os(iOS)` / `import UIKit` / `#endif`, a `// a comment` line and a `Scheduler().review(` call, run the filter again and expect:
```
error: SourceGuardTests.testAdventureSourcesContainNoComments : XCTAssertFalse failed - Probe.swift contains a line comment
error: SourceGuardTests.testAdventureSourcesNeverCallSchedulerReviewOrBuildCardState : XCTAssertFalse failed - Probe.swift contains .review(
error: SourceGuardTests.testIFRCoreSourcesImportOnlyFoundation : XCTAssertFalse failed - Probe.swift contains import UIKit
```
Delete the probe before continuing.

- [ ] **Step 3: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/.gitkeep`

An empty file. Git cannot record an empty directory, so this zero-byte dotfile holds `Sources/IFRCore/Adventure/` in place; SwiftPM ignores dotfiles, so no "unhandled file" warning appears. Later Adventure items add their Swift files beside it.

- [ ] **Step 4: Write the workflow**

File: `<repo root>/.github/workflows/core-tests.yml`

```yaml
name: Core tests

on:
  push:
  pull_request:

jobs:
  core-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install Swift
        run: sudo bash FlashCards/scripts/install-swift-linux.sh
      - name: Run IFRCore tests
        run: bash FlashCards/scripts/test-core.sh
```

The install script writes to `/opt/swift`, which the runner user cannot create without `sudo`; `scripts/test-core.sh` then finds `/opt/swift/usr/bin/swift` on its own.

- [ ] **Step 5: Run all core tests**

Run: `scripts/test-core.sh`
Expected: `Executed 61 tests, with 0 failures`

- [ ] **Step 6: Commit**

Run: `git add IFRCore/Tests/IFRCoreTests/SourceGuardTests.swift IFRCore/Tests/IFRCoreTests/StringLiteralStripper.swift IFRCore/Tests/IFRCoreTests/StringLiteralStripperTests.swift IFRCore/Sources/IFRCore/Adventure/.gitkeep ../.github/workflows/core-tests.yml && git commit -m "M1-01: Toolchain check, CI and guard tests"`

---

### Task M1-02: Battle math (Linux)

**Files:**
- Create: `IFRCore/Sources/IFRCore/Adventure/Battle/Damage.swift`
- Create: `IFRCore/Sources/IFRCore/Adventure/Battle/PlayerHP.swift`
- Create: `IFRCore/Sources/IFRCore/Adventure/Battle/BattleTier.swift`
- Create: `IFRCore/Sources/IFRCore/Adventure/Battle/OpponentHP.swift`
- Test: `IFRCore/Tests/IFRCoreTests/DamageTests.swift`
- Test: `IFRCore/Tests/IFRCoreTests/PlayerHPTests.swift`
- Test: `IFRCore/Tests/IFRCoreTests/OpponentHPTests.swift`

**Interfaces:**
- Consumes: `MasteryLevel` (`IFRCore/Sources/IFRCore/Progress/MasteryCalculator.swift`), `Question` (`IFRCore/Sources/IFRCore/Models/Question.swift`)
- Produces: `Hit: Equatable, Sendable { amount: Int, isCritical: Bool, isSuperEffective: Bool }`; `enum Damage { static func hit(difficulty: Int, answerSeconds: Double) -> Hit }`; `enum PlayerHP { static func maximum(for: MasteryLevel) -> Int }`; `enum BattleTier: String, Codable, Sendable, CaseIterable { case cloud, trainer, gym, eliteFour, tower, link, champion; var missDamage: Int; var runsEveryQuestion: Bool; func damage(for: Hit) -> Int }`; `enum OpponentHP { static func tuned(for: [Question], passMarkPercent: Int = 70) -> Int; static func cloud(for: Question) -> Int }` — all consumed by later Adventure battle work items (M1-03 `BattleEngine`, `BattleTuning`).

- [ ] **Step 1: Write the failing tests**

File: `IFRCore/Tests/IFRCoreTests/DamageTests.swift`

```swift
import XCTest
@testable import IFRCore

final class DamageTests: XCTestCase {
    func testBaseDamageIsEightTenTwelveByDifficulty() {
        XCTAssertEqual(Damage.hit(difficulty: 1, answerSeconds: 10).amount, 8)
        XCTAssertEqual(Damage.hit(difficulty: 2, answerSeconds: 10).amount, 10)
        XCTAssertEqual(Damage.hit(difficulty: 3, answerSeconds: 10).amount, 12)
    }

    func testCriticalUnderSixSecondsIsTwelveFifteenEighteen() {
        XCTAssertEqual(Damage.hit(difficulty: 1, answerSeconds: 5.9).amount, 12)
        XCTAssertEqual(Damage.hit(difficulty: 2, answerSeconds: 5.9).amount, 15)
        XCTAssertEqual(Damage.hit(difficulty: 3, answerSeconds: 5.9).amount, 18)
        XCTAssertTrue(Damage.hit(difficulty: 1, answerSeconds: 5.9).isCritical)
    }

    func testExactlySixSecondsIsNotCritical() {
        XCTAssertFalse(Damage.hit(difficulty: 1, answerSeconds: 6).isCritical)
        XCTAssertEqual(Damage.hit(difficulty: 1, answerSeconds: 6).amount, 8)
    }

    func testNegativeSecondsCountsAsCritical() {
        XCTAssertTrue(Damage.hit(difficulty: 1, answerSeconds: -1).isCritical)
        XCTAssertEqual(Damage.hit(difficulty: 1, answerSeconds: -1).amount, 12)
    }

    func testDifficultyThreeIsSuperEffective() {
        XCTAssertFalse(Damage.hit(difficulty: 1, answerSeconds: 10).isSuperEffective)
        XCTAssertFalse(Damage.hit(difficulty: 2, answerSeconds: 10).isSuperEffective)
        XCTAssertTrue(Damage.hit(difficulty: 3, answerSeconds: 10).isSuperEffective)
    }
}
```

- [ ] **Step 2: Write the failing tests**

File: `IFRCore/Tests/IFRCoreTests/PlayerHPTests.swift`

```swift
import XCTest
@testable import IFRCore

final class PlayerHPTests: XCTestCase {
    func testMaximumHPGrowsTenPerMasteryLevel() {
        let expected = [100, 110, 120, 130, 140]
        let actual = MasteryLevel.allCases.map { PlayerHP.maximum(for: $0) }
        XCTAssertEqual(actual, expected)
    }

    func testMissDamageByTier() {
        let expected = [20, 30, 30, 30, 20, 30, 1]
        let actual: [BattleTier] = [.cloud, .trainer, .gym, .eliteFour, .tower, .link, .champion]
        XCTAssertEqual(actual.map(\.missDamage), expected)
    }

    func testChampionTierDealsOneForAnyHit() {
        let crit = Damage.hit(difficulty: 3, answerSeconds: 5)
        XCTAssertEqual(crit.amount, 18)
        XCTAssertEqual(BattleTier.champion.damage(for: crit), 1)
    }
}
```

- [ ] **Step 3: Write the failing tests**

File: `IFRCore/Tests/IFRCoreTests/OpponentHPTests.swift`

```swift
import XCTest
@testable import IFRCore

final class OpponentHPTests: XCTestCase {
    private func mcQuestion(_ id: String, _ category: IFRCore.Category, difficulty: Int = 1) -> Question {
        Question(id: id, category: category, acsCodes: ["IR.I.A.K1"], format: .multipleChoice,
                 front: "f", back: "b", options: ["a", "b", "c"], correctIndex: 0, explanation: "e",
                 source: SourceRef(document: "d", section: "s", url: URL(string: "https://faa.gov")!),
                 figure: nil, difficulty: difficulty)
    }

    func testTunedHPIsSeventyPercentOfTotalBaseDamageRoundedUp() {
        let ten = (0..<10).map { mcQuestion("q\($0)", .weather, difficulty: 2) }
        XCTAssertEqual(OpponentHP.tuned(for: ten), 70)

        let three = (0..<3).map { mcQuestion("q\($0)", .weather, difficulty: 1) }
        XCTAssertEqual(OpponentHP.tuned(for: three), 17)
    }

    func testCloudHPEqualsBaseDamageOfItsQuestion() {
        XCTAssertEqual(OpponentHP.cloud(for: mcQuestion("d1", .weather, difficulty: 1)), 8)
        XCTAssertEqual(OpponentHP.cloud(for: mcQuestion("d2", .weather, difficulty: 2)), 10)
        XCTAssertEqual(OpponentHP.cloud(for: mcQuestion("d3", .weather, difficulty: 3)), 12)
    }
}
```

- [ ] **Step 4: Run the tests to verify they fail**

Run: `scripts/test-core.sh --filter DamageTests`
Expected:
```
/home/user/IFR-build-a/FlashCards/IFRCore/Tests/IFRCoreTests/PlayerHPTests.swift:7:56: error: cannot find 'PlayerHP' in scope
    7 |         let actual = MasteryLevel.allCases.map { PlayerHP.maximum(for: $0) }
/home/user/IFR-build-a/FlashCards/IFRCore/Tests/IFRCoreTests/PlayerHPTests.swift:13:22: error: cannot find type 'BattleTier' in scope
   13 |         let actual: [BattleTier] = [.cloud, .trainer, .gym, .eliteFour, .tower, .link, .champion]
/home/user/IFR-build-a/FlashCards/IFRCore/Tests/IFRCoreTests/PlayerHPTests.swift:18:20: error: cannot find 'Damage' in scope
error: fatalError
```

- [ ] **Step 5: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Battle/Damage.swift`

```swift
import Foundation

public struct Hit: Equatable, Sendable {
    public let amount: Int
    public let isCritical: Bool
    public let isSuperEffective: Bool

    public init(amount: Int, isCritical: Bool, isSuperEffective: Bool) {
        self.amount = amount
        self.isCritical = isCritical
        self.isSuperEffective = isSuperEffective
    }
}

public enum Damage {
    private static let difficultyPercentByDifficulty = [1: 100, 2: 125, 3: 150]

    public static func hit(difficulty: Int, answerSeconds: Double) -> Hit {
        let isCritical = answerSeconds < 6
        let criticalPercent = isCritical ? 150 : 100
        let difficultyPercent = difficultyPercentByDifficulty[difficulty] ?? 100
        let amount = 8 * difficultyPercent * criticalPercent / 10_000
        return Hit(amount: amount, isCritical: isCritical, isSuperEffective: difficulty == 3)
    }
}
```

- [ ] **Step 6: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Battle/PlayerHP.swift`

```swift
public enum PlayerHP {
    public static func maximum(for level: MasteryLevel) -> Int {
        100 + 10 * (level.rawValue - 1)
    }
}
```

- [ ] **Step 7: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Battle/BattleTier.swift`

```swift
public enum BattleTier: String, Codable, Sendable, CaseIterable {
    case cloud, trainer, gym, eliteFour, tower, link, champion

    private static let missDamageByTier: [BattleTier: Int] = [
        .cloud: 20, .trainer: 30, .gym: 30, .eliteFour: 30, .tower: 20, .link: 30, .champion: 1,
    ]

    public var missDamage: Int {
        Self.missDamageByTier[self] ?? 30
    }

    public var runsEveryQuestion: Bool {
        self == .champion
    }

    public func damage(for hit: Hit) -> Int {
        self == .champion ? 1 : hit.amount
    }
}
```

- [ ] **Step 8: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Battle/OpponentHP.swift`

```swift
public enum OpponentHP {
    public static func tuned(for questions: [Question], passMarkPercent: Int = 70) -> Int {
        let total = totalBaseDamage(of: questions)
        return (total * passMarkPercent + 99) / 100
    }

    public static func cloud(for question: Question) -> Int {
        Damage.hit(difficulty: question.difficulty, answerSeconds: 10).amount
    }

    private static func totalBaseDamage(of questions: [Question]) -> Int {
        questions.reduce(0) { $0 + Damage.hit(difficulty: $1.difficulty, answerSeconds: 10).amount }
    }
}
```

- [ ] **Step 9: Run all core tests**

Run: `scripts/test-core.sh`
Expected: `Executed 71 tests, with 0 failures`

- [ ] **Step 10: Commit**

Run: `git add IFRCore/Sources/IFRCore/Adventure/Battle IFRCore/Tests/IFRCoreTests/DamageTests.swift IFRCore/Tests/IFRCoreTests/PlayerHPTests.swift IFRCore/Tests/IFRCoreTests/OpponentHPTests.swift && git commit -m "M1-02: Battle math"`

---

### Task M1-03: Battle engine

**Files:**
- Create: `IFRCore/Sources/IFRCore/Adventure/Battle/Opponent.swift`
- Create: `IFRCore/Sources/IFRCore/Adventure/Battle/BattleState.swift`
- Create: `IFRCore/Sources/IFRCore/Adventure/Battle/BattleEngine.swift`
- Test: `IFRCore/Tests/IFRCoreTests/BattleEngineTests.swift`

**Interfaces:**
- Consumes: `Hit`, `Damage.hit(difficulty:answerSeconds:)` (`IFRCore/Sources/IFRCore/Adventure/Battle/Damage.swift`); `BattleTier` with `missDamage`, `runsEveryQuestion`, `damage(for:)` (`IFRCore/Sources/IFRCore/Adventure/Battle/BattleTier.swift`); `Question` (`IFRCore/Sources/IFRCore/Models/Question.swift`); `Grade(mcCorrect:)` (`IFRCore/Sources/IFRCore/Scheduling/CardState.swift`)
- Produces: `Opponent(id:name:nameplateName:spriteID:tier:maxHP:gymID:airportID:)`; `BattleTurnResult(questionID:selectedIndex:isCorrect:grade:hit:damageToPlayer:)`; `enum BattleOutcome { case won, lost }`; `enum BattleEvent { case questionPresented(Question), opponentHit(Hit, damage: Int), playerHurt(Int), explanation(String), revived(Int), opponentFainted, playerFainted, deckExhausted }`; `BattleState` with `currentQuestion: Question?`; `enum BattleEngine { static func start(opponent:deck:playerMaxHP:missDamage:) -> BattleState; static func answer(_:selectedIndex:answerSeconds:) -> (state: BattleState, events: [BattleEvent]); static func forfeit(_:) -> (state: BattleState, events: [BattleEvent]) }` — all consumed by the later M1-09b Elite Four/Champion adapters and the M1-15 battle screen model

- [ ] **Step 1: Write the failing tests**

File: `IFRCore/Tests/IFRCoreTests/BattleEngineTests.swift`

```swift
import XCTest
@testable import IFRCore

final class BattleEngineTests: XCTestCase {
    private func mcQuestion(_ id: String, _ category: IFRCore.Category, difficulty: Int = 1, explanation: String = "e") -> Question {
        Question(id: id, category: category, acsCodes: ["IR.I.A.K1"], format: .multipleChoice,
                 front: "f", back: "b", options: ["a", "b", "c"], correctIndex: 0, explanation: explanation,
                 source: SourceRef(document: "d", section: "s", url: URL(string: "https://faa.gov")!),
                 figure: nil, difficulty: difficulty)
    }

    private func deck(_ count: Int, difficulty: Int = 1) -> [Question] {
        (0..<count).map { mcQuestion("q\($0)", .weather, difficulty: difficulty) }
    }

    private func opponent(tier: BattleTier = .gym, maxHP: Int = 100) -> Opponent {
        Opponent(id: "opp", name: "Opp", nameplateName: "OPP", spriteID: "s", tier: tier, maxHP: maxHP)
    }

    func testStartPresentsFirstQuestionWithFullHP() {
        let state = BattleEngine.start(opponent: opponent(), deck: deck(3), playerMaxHP: 100)
        XCTAssertEqual(state.cursor, 0)
        XCTAssertEqual(state.playerHP, 100)
        XCTAssertEqual(state.opponentHP, 100)
        XCTAssertEqual(state.missDamage, BattleTier.gym.missDamage)
    }

    func testStartMissDamageOverrideIsKept() {
        let state = BattleEngine.start(opponent: opponent(), deck: deck(3), playerMaxHP: 100, missDamage: 35)
        XCTAssertEqual(state.missDamage, 35)
    }

    func testCorrectAnswerDamagesOpponentAndGradesGood() {
        let state = BattleEngine.start(opponent: opponent(maxHP: 100), deck: deck(3), playerMaxHP: 100)
        let (next, _) = BattleEngine.answer(state, selectedIndex: 0, answerSeconds: 10)
        XCTAssertEqual(next.opponentHP, 92)
        XCTAssertEqual(next.turns.last?.grade, .good)
    }

    func testWrongAnswerDamagesPlayerByTierAndGradesAgain() {
        let state = BattleEngine.start(opponent: opponent(maxHP: 100), deck: deck(3), playerMaxHP: 100)
        let (next, _) = BattleEngine.answer(state, selectedIndex: 1, answerSeconds: 10)
        XCTAssertEqual(next.playerHP, 70)
        XCTAssertEqual(next.turns.last?.grade, .again)
    }

    func testWrongAnswerEmitsExplanationEvent() {
        let state = BattleEngine.start(opponent: opponent(maxHP: 100), deck: deck(3), playerMaxHP: 100)
        let (_, events) = BattleEngine.answer(state, selectedIndex: 1, answerSeconds: 10)
        XCTAssertTrue(events.contains(.explanation("e")))
    }

    func testOpponentAtZeroEmitsFaintedAndWins() {
        let state = BattleEngine.start(opponent: opponent(maxHP: 5), deck: deck(3), playerMaxHP: 100)
        let (next, events) = BattleEngine.answer(state, selectedIndex: 0, answerSeconds: 10)
        let hit = Hit(amount: 8, isCritical: false, isSuperEffective: false)
        XCTAssertEqual(events, [.opponentHit(hit, damage: 5), .opponentFainted])
        XCTAssertEqual(next.outcome, .won)
    }

    func testPlayerAtZeroEmitsFaintedAndLoses() {
        let state = BattleEngine.start(opponent: opponent(maxHP: 100), deck: deck(3), playerMaxHP: 20)
        let (next, events) = BattleEngine.answer(state, selectedIndex: 1, answerSeconds: 10)
        XCTAssertEqual(events, [.playerHurt(20), .explanation("e"), .playerFainted])
        XCTAssertEqual(next.outcome, .lost)
    }

    func testDeckExhaustedWithOpponentStandingLoses() {
        let state = BattleEngine.start(opponent: opponent(maxHP: 1000), deck: deck(1), playerMaxHP: 100)
        let (next, events) = BattleEngine.answer(state, selectedIndex: 0, answerSeconds: 10)
        let hit = Hit(amount: 8, isCritical: false, isSuperEffective: false)
        XCTAssertEqual(events, [.opponentHit(hit, damage: 8), .deckExhausted])
        XCTAssertEqual(next.outcome, .lost)
    }

    func testAnswerAfterOutcomeIsNoOp() {
        let state = BattleEngine.start(opponent: opponent(maxHP: 5), deck: deck(3), playerMaxHP: 100)
        let (afterWin, _) = BattleEngine.answer(state, selectedIndex: 0, answerSeconds: 10)
        let (again, events) = BattleEngine.answer(afterWin, selectedIndex: 0, answerSeconds: 10)
        XCTAssertEqual(again, afterWin)
        XCTAssertTrue(events.isEmpty)
    }

    func testForfeitLosesWithoutFurtherReviews() {
        let state = BattleEngine.start(opponent: opponent(maxHP: 100), deck: deck(3), playerMaxHP: 100)
        let (next, events) = BattleEngine.forfeit(state)
        XCTAssertEqual(next.outcome, .lost)
        XCTAssertEqual(events, [.playerFainted])
        XCTAssertTrue(next.turns.isEmpty)
    }

    func testForfeitAfterOutcomeIsNoOp() {
        let state = BattleEngine.start(opponent: opponent(maxHP: 100), deck: deck(3), playerMaxHP: 100)
        let (first, _) = BattleEngine.forfeit(state)
        let (second, events) = BattleEngine.forfeit(first)
        XCTAssertEqual(second, first)
        XCTAssertTrue(events.isEmpty)
    }

    func testResultsMirrorTurnCorrectness() {
        var state = BattleEngine.start(opponent: opponent(maxHP: 1000), deck: deck(4), playerMaxHP: 1000)
        for index in [0, 1, 0, 1] {
            let (next, _) = BattleEngine.answer(state, selectedIndex: index, answerSeconds: 10)
            state = next
        }
        XCTAssertEqual(state.results, [true, false, true, false])
    }

    func testChampionRunsAllQuestionsWithBarsPinnedAtZero() {
        var state = BattleEngine.start(opponent: opponent(tier: .champion, maxHP: 42), deck: deck(60), playerMaxHP: 19)
        for turn in 0..<60 {
            let index = turn < 42 ? 0 : 1
            let (next, _) = BattleEngine.answer(state, selectedIndex: index, answerSeconds: 10)
            XCTAssertGreaterThanOrEqual(next.opponentHP, 0)
            XCTAssertGreaterThanOrEqual(next.playerHP, 0)
            if turn < 59 { XCTAssertNil(next.outcome) }
            state = next
        }
        XCTAssertEqual(state.outcome, .won)
    }

    func testEventOrderForEachAnswerCase() {
        let hit = Hit(amount: 8, isCritical: false, isSuperEffective: false)
        let baseDeck = deck(2)

        let standing = BattleEngine.start(opponent: opponent(maxHP: 100), deck: baseDeck, playerMaxHP: 100)
        let (_, correctStanding) = BattleEngine.answer(standing, selectedIndex: 0, answerSeconds: 10)
        XCTAssertEqual(correctStanding, [.opponentHit(hit, damage: 8), .questionPresented(baseDeck[1])])

        let faint = BattleEngine.start(opponent: opponent(maxHP: 5), deck: baseDeck, playerMaxHP: 100)
        let (_, correctFaint) = BattleEngine.answer(faint, selectedIndex: 0, answerSeconds: 10)
        XCTAssertEqual(correctFaint, [.opponentHit(hit, damage: 5), .opponentFainted])

        let wrongStanding = BattleEngine.start(opponent: opponent(maxHP: 100), deck: baseDeck, playerMaxHP: 100)
        let (_, wrongStandingEvents) = BattleEngine.answer(wrongStanding, selectedIndex: 1, answerSeconds: 10)
        XCTAssertEqual(wrongStandingEvents, [.playerHurt(30), .explanation("e"), .questionPresented(baseDeck[1])])

        var revive = BattleEngine.start(opponent: opponent(maxHP: 100), deck: baseDeck, playerMaxHP: 30)
        revive.reviveArmed = true
        let (_, reviveEvents) = BattleEngine.answer(revive, selectedIndex: 1, answerSeconds: 10)
        XCTAssertEqual(reviveEvents, [.playerHurt(30), .revived(15), .explanation("e"), .questionPresented(baseDeck[1])])

        let doom = BattleEngine.start(opponent: opponent(maxHP: 100), deck: baseDeck, playerMaxHP: 20)
        let (_, doomEvents) = BattleEngine.answer(doom, selectedIndex: 1, answerSeconds: 10)
        XCTAssertEqual(doomEvents, [.playerHurt(20), .explanation("e"), .playerFainted])

        let last = BattleEngine.start(opponent: opponent(maxHP: 1000), deck: deck(1), playerMaxHP: 100)
        let (_, lastEvents) = BattleEngine.answer(last, selectedIndex: 0, answerSeconds: 10)
        XCTAssertEqual(lastEvents, [.opponentHit(hit, damage: 8), .deckExhausted])
    }

    func testRevivedEventPrecedesExplanation() {
        var state = BattleEngine.start(opponent: opponent(maxHP: 100), deck: deck(2), playerMaxHP: 30)
        state.reviveArmed = true
        let (_, events) = BattleEngine.answer(state, selectedIndex: 1, answerSeconds: 10)
        let revivedIndex = events.firstIndex(of: .revived(15))
        let explanationIndex = events.firstIndex(of: .explanation("e"))
        XCTAssertNotNil(revivedIndex)
        XCTAssertNotNil(explanationIndex)
        XCTAssertLessThan(revivedIndex!, explanationIndex!)
    }

    func testBattleStateCodableRoundTrip() throws {
        let state = BattleEngine.start(opponent: opponent(maxHP: 100), deck: deck(3), playerMaxHP: 100)
        let (next, _) = BattleEngine.answer(state, selectedIndex: 0, answerSeconds: 10)
        let decoded = try JSONDecoder().decode(BattleState.self, from: JSONEncoder().encode(next))
        XCTAssertEqual(decoded, next)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `scripts/test-core.sh --filter BattleEngineTests`
Expected: `error: cannot find type 'Opponent' in scope` (and cascading `cannot find 'BattleEngine' in scope`, `cannot find type 'BattleState' in scope`) — `Opponent`, `BattleState` and `BattleEngine` did not exist yet.

- [ ] **Step 3: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Battle/Opponent.swift`

```swift
import Foundation

public struct Opponent: Equatable, Codable, Sendable {
    public let id: String
    public let name: String
    public let nameplateName: String
    public let spriteID: String
    public let tier: BattleTier
    public let maxHP: Int
    public let gymID: String?
    public let airportID: String?

    public init(
        id: String, name: String, nameplateName: String, spriteID: String,
        tier: BattleTier, maxHP: Int, gymID: String? = nil, airportID: String? = nil
    ) {
        self.id = id
        self.name = name
        self.nameplateName = nameplateName
        self.spriteID = spriteID
        self.tier = tier
        self.maxHP = maxHP
        self.gymID = gymID
        self.airportID = airportID
    }
}
```

- [ ] **Step 4: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Battle/BattleState.swift`

```swift
import Foundation

extension Hit: Codable {
    private enum CodingKeys: String, CodingKey {
        case amount, isCritical, isSuperEffective
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            amount: try container.decode(Int.self, forKey: .amount),
            isCritical: try container.decode(Bool.self, forKey: .isCritical),
            isSuperEffective: try container.decode(Bool.self, forKey: .isSuperEffective)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(amount, forKey: .amount)
        try container.encode(isCritical, forKey: .isCritical)
        try container.encode(isSuperEffective, forKey: .isSuperEffective)
    }
}

public struct BattleTurnResult: Equatable, Codable, Sendable {
    public let questionID: String
    public let selectedIndex: Int
    public let isCorrect: Bool
    public let grade: Grade
    public let hit: Hit?
    public let damageToPlayer: Int

    public init(
        questionID: String, selectedIndex: Int, isCorrect: Bool,
        grade: Grade, hit: Hit?, damageToPlayer: Int
    ) {
        self.questionID = questionID
        self.selectedIndex = selectedIndex
        self.isCorrect = isCorrect
        self.grade = grade
        self.hit = hit
        self.damageToPlayer = damageToPlayer
    }
}

public enum BattleOutcome: Equatable, Codable, Sendable {
    case won, lost
}

public enum BattleEvent: Equatable, Sendable {
    case questionPresented(Question)
    case opponentHit(Hit, damage: Int)
    case playerHurt(Int)
    case explanation(String)
    case revived(Int)
    case opponentFainted
    case playerFainted
    case deckExhausted
}

public struct BattleState: Equatable, Codable, Sendable {
    public var opponent: Opponent
    public var deck: [Question]
    public var cursor: Int
    public var playerHP: Int
    public var playerMaxHP: Int
    public var opponentHP: Int
    public var missDamage: Int
    public var reviveArmed: Bool
    public var results: [Bool]
    public var turns: [BattleTurnResult]
    public var outcome: BattleOutcome?

    public var currentQuestion: Question? {
        deck.indices.contains(cursor) ? deck[cursor] : nil
    }

    public init(
        opponent: Opponent, deck: [Question], cursor: Int, playerHP: Int, playerMaxHP: Int,
        opponentHP: Int, missDamage: Int, reviveArmed: Bool, results: [Bool],
        turns: [BattleTurnResult], outcome: BattleOutcome?
    ) {
        self.opponent = opponent
        self.deck = deck
        self.cursor = cursor
        self.playerHP = playerHP
        self.playerMaxHP = playerMaxHP
        self.opponentHP = opponentHP
        self.missDamage = missDamage
        self.reviveArmed = reviveArmed
        self.results = results
        self.turns = turns
        self.outcome = outcome
    }
}
```

- [ ] **Step 5: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Battle/BattleEngine.swift`

```swift
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
```

- [ ] **Step 6: Run all core tests**

Run: `scripts/test-core.sh`
Expected: `Executed 87 tests, with 0 failures`

- [ ] **Step 7: Commit**

Run: `git add IFRCore/Sources/IFRCore/Adventure/Battle/Opponent.swift IFRCore/Sources/IFRCore/Adventure/Battle/BattleState.swift IFRCore/Sources/IFRCore/Adventure/Battle/BattleEngine.swift IFRCore/Tests/IFRCoreTests/BattleEngineTests.swift && git commit -m "M1-03: Battle engine"`

---

### Task M1-04: Tuning proofs (Linux)

**Files:**
- Create: `IFRCore/Sources/IFRCore/Adventure/Battle/BattleTuning.swift`
- Test: `IFRCore/Tests/IFRCoreTests/BattleTuningTests.swift`

**Interfaces:**
- Consumes: `Damage.hit(difficulty:answerSeconds:) -> Hit` from `IFRCore/Sources/IFRCore/Adventure/Battle/Damage.swift`; `OpponentHP.tuned(for:passMarkPercent:) -> Int` from `IFRCore/Sources/IFRCore/Adventure/Battle/OpponentHP.swift`; `Question`, `Category`, `SourceRef` from `IFRCore/Sources/IFRCore/Models/Question.swift`; `QuestionBank.load()` and `QuestionBank.questions(in:)` from `IFRCore/Sources/IFRCore/Models/QuestionBank.swift`
- Produces: `enum BattleTuning { static func totalBaseDamage(of questions: [Question]) -> Int; static func winsWithoutCriticals(deck: [Question], correctIndices: Set<Int>) -> Bool; static func winsWithCriticals(deck: [Question], correctIndices: Set<Int>, criticalIndices: Set<Int>) -> Bool }`, used by later tuning/content tests that need to assert win/lose outcomes over concrete decks

- [ ] **Step 1: Write the failing tests**

File: `IFRCore/Tests/IFRCoreTests/BattleTuningTests.swift`

```swift
import XCTest
@testable import IFRCore

final class BattleTuningTests: XCTestCase {
    private func mcQuestion(_ id: String, _ category: IFRCore.Category, difficulty: Int = 1) -> Question {
        Question(id: id, category: category, acsCodes: ["IR.I.A.K1"], format: .multipleChoice,
                 front: "f", back: "b", options: ["a", "b", "c"], correctIndex: 0, explanation: "e",
                 source: SourceRef(document: "d", section: "s", url: URL(string: "https://faa.gov")!),
                 figure: nil, difficulty: difficulty)
    }

    private func typicalDeck() -> [Question] {
        (0..<3).map { mcQuestion("d1-\($0)", .weather, difficulty: 1) }
            + (0..<4).map { mcQuestion("d2-\($0)", .weather, difficulty: 2) }
            + (0..<3).map { mcQuestion("d3-\($0)", .weather, difficulty: 3) }
    }

    private func combinations(_ elements: [Int], _ k: Int) -> [Set<Int>] {
        guard k > 0 else { return [[]] }
        guard elements.count >= k else { return [] }
        if k == elements.count { return [Set(elements)] }
        let first = elements[0]
        let rest = Array(elements.dropFirst())
        let withFirst = combinations(rest, k - 1).map { $0.union([first]) }
        let withoutFirst = combinations(rest, k)
        return withFirst + withoutFirst
    }

    func testSixOfTenWithoutCritsNeverWinsTypicalDraw() {
        let deck = typicalDeck()
        let subsets = combinations(Array(0..<10), 6)
        XCTAssertEqual(subsets.count, 210)
        for subset in subsets {
            XCTAssertFalse(BattleTuning.winsWithoutCriticals(deck: deck, correctIndices: subset))
        }
    }

    func testSevenOfTenWithoutCritsWinsExactlyEightyOfOneTwentySubsets() {
        let deck = typicalDeck()
        let subsets = combinations(Array(0..<10), 7)
        XCTAssertEqual(subsets.count, 120)
        let winCount = subsets.filter { BattleTuning.winsWithoutCriticals(deck: deck, correctIndices: $0) }.count
        XCTAssertEqual(winCount, 80)
    }

    func testEightOfTenAlwaysWins() {
        let deck = typicalDeck()
        let subsets = combinations(Array(0..<10), 8)
        XCTAssertEqual(subsets.count, 45)
        for subset in subsets {
            XCTAssertTrue(BattleTuning.winsWithoutCriticals(deck: deck, correctIndices: subset))
        }
    }

    func testOneCriticalWinsAllButTheAllHardMissSevenOfTen() {
        let deck = typicalDeck()
        let subsets = combinations(Array(0..<10), 7)
        var losingSubsets: [Set<Int>] = []
        var winCount = 0
        for correct in subsets {
            let winsWithBestCrit = correct.contains { crit in
                BattleTuning.winsWithCriticals(deck: deck, correctIndices: correct, criticalIndices: [crit])
            }
            if winsWithBestCrit {
                winCount += 1
            } else {
                losingSubsets.append(correct)
            }
        }
        XCTAssertEqual(winCount, 119)
        XCTAssertEqual(losingSubsets, [Set(0...6)])
    }

    func testTwoCriticalsAlwaysWinSevenOfTen() {
        let deck = typicalDeck()
        let subsets = combinations(Array(0..<10), 7)
        for correct in subsets {
            for pair in combinations(Array(correct), 2) {
                XCTAssertTrue(BattleTuning.winsWithCriticals(deck: deck, correctIndices: correct, criticalIndices: pair))
            }
        }
    }

    func testRealBankMeanDamageNeedsSixPointFiveToSevenPointFiveCorrect() throws {
        let bank = try QuestionBank.load()
        for category in IFRCore.Category.allCases {
            let questions = bank.questions(in: category)
            let meanBaseDamage = Double(BattleTuning.totalBaseDamage(of: questions)) / Double(questions.count)
            let correctAnswersNeeded = 70 / meanBaseDamage
            XCTAssertTrue((6.5...7.5).contains(correctAnswersNeeded), "\(category) needs \(correctAnswersNeeded)")
        }
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `scripts/test-core.sh --filter BattleTuningTests`
Expected: `error: cannot find 'BattleTuning' in scope` (repeated for each call site in `BattleTuningTests.swift`, since `BattleTuning` does not exist yet)

- [ ] **Step 3: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Battle/BattleTuning.swift`

```swift
import Foundation

public enum BattleTuning {
    public static func totalBaseDamage(of questions: [Question]) -> Int {
        questions.reduce(0) { $0 + Damage.hit(difficulty: $1.difficulty, answerSeconds: 10).amount }
    }

    public static func winsWithoutCriticals(deck: [Question], correctIndices: Set<Int>) -> Bool {
        winsWithCriticals(deck: deck, correctIndices: correctIndices, criticalIndices: [])
    }

    public static func winsWithCriticals(
        deck: [Question], correctIndices: Set<Int>, criticalIndices: Set<Int>
    ) -> Bool {
        let opponentHP = OpponentHP.tuned(for: deck)
        let damage = totalDamage(deck: deck, correctIndices: correctIndices, criticalIndices: criticalIndices)
        return damage >= opponentHP
    }

    private static func totalDamage(
        deck: [Question], correctIndices: Set<Int>, criticalIndices: Set<Int>
    ) -> Int {
        correctIndices.reduce(0) { total, index in
            let answerSeconds: Double = criticalIndices.contains(index) ? 0 : 10
            let hit = Damage.hit(difficulty: deck[index].difficulty, answerSeconds: answerSeconds)
            return total + hit.amount
        }
    }
}
```

- [ ] **Step 4: Run all core tests**

Run: `scripts/test-core.sh`
Expected: `Executed 93 tests, with 0 failures`

- [ ] **Step 5: Commit**

Run: `git add IFRCore/Sources/IFRCore/Adventure/Battle/BattleTuning.swift IFRCore/Tests/IFRCoreTests/BattleTuningTests.swift && git commit -m "M1-04: Tuning proofs"`

---

### Task M1-05: Pixel primitives (Linux)

**Files:**
- Create: `IFRCore/Sources/IFRCore/Adventure/Pixel/GridPoint.swift`
- Create: `IFRCore/Sources/IFRCore/Adventure/Pixel/Palette.swift`
- Create: `IFRCore/Sources/IFRCore/Adventure/Pixel/PixelSprite.swift`
- Create: `IFRCore/Sources/IFRCore/Adventure/Pixel/PixelRect.swift`
- Create: `IFRCore/Sources/IFRCore/Adventure/Pixel/PixelFrame.swift`
- Create: `IFRCore/Sources/IFRCore/Adventure/Pixel/SpriteCatalog.swift`
- Create: `IFRCore/Sources/IFRCore/Adventure/Pixel/Sprites/UISprites.swift`
- Test: `IFRCore/Tests/IFRCoreTests/PaletteTests.swift`
- Test: `IFRCore/Tests/IFRCoreTests/PixelSpriteTests.swift`
- Test: `IFRCore/Tests/IFRCoreTests/PixelFrameTests.swift`

**Interfaces:**
- Consumes: nothing outside this task; only `Foundation`.
- Produces:
  - `GridPoint(x: Int, y: Int): Equatable, Sendable` — a cell/pixel coordinate used by every renderer signature the spec names (`PixelFrame.blit(_:at:)`, `PixelFrame.line(from:to:index:)`, and later `RegionMapRenderer`, `BattleRenderer`, `OverworldRenderer`). Not listed among M1-05's files in section 6, but required by the `PixelFrame` signatures section 2.5 specifies, so it is introduced here as the smallest deviation (see Deviations).
  - `PaletteColor(r: UInt8, g: UInt8, b: UInt8): Equatable, Sendable` and `enum Palette { static let transparent: UInt8 = 255; static let entries: [PaletteColor] }` (16 entries, in `Adventure/Pixel/Palette.swift`).
  - `enum PixelSpriteError: Error, Equatable { case raggedRows; case badCharacter(Character) }` and `struct PixelSprite: Equatable, Sendable` with `init(rows: [String]) throws`, `width`, `height`, `subscript(x:y:) -> UInt8`, `flippedHorizontally() -> PixelSprite`, `recoloured(_:) -> PixelSprite` (in `Adventure/Pixel/PixelSprite.swift`).
  - `struct PixelRect(x: Int, y: Int, width: Int, height: Int): Equatable, Sendable` (in `Adventure/Pixel/PixelRect.swift`).
  - `struct PixelFrame: Equatable, Sendable` with `static let width = 240`, `static let height = 160`, `pixels: [UInt8]`, `init(fill: UInt8)`, `mutating func blit(_ sprite: PixelSprite, at: GridPoint)`, `mutating func fill(_ rect: PixelRect, index: UInt8)`, `mutating func frame(_ rect: PixelRect, outer: UInt8, inner: UInt8)`, `mutating func line(from: GridPoint, to: GridPoint, index: UInt8)` (in `Adventure/Pixel/PixelFrame.swift`).
  - `enum SpriteCatalog { static let all: [String: PixelSprite]; static func sprite(named: String) -> PixelSprite? }` (in `Adventure/Pixel/SpriteCatalog.swift`), backed by `enum UISprites { static let all: [String: PixelSprite] }` (in `Adventure/Pixel/Sprites/UISprites.swift`), which supplies the `cursor` sprite used by later dialogue-box work.

- [ ] **Step 1: Write the failing tests**

File: `IFRCore/Tests/IFRCoreTests/PaletteTests.swift`

```swift
import XCTest
@testable import IFRCore

final class PaletteTests: XCTestCase {
    func testPaletteHasSixteenEntries() {
        XCTAssertEqual(Palette.entries.count, 16)
    }

    func testPaletteContainsPanelAccentAndAmberBytes() {
        XCTAssertEqual(Palette.entries[1], PaletteColor(r: 0x1A, g: 0x1F, b: 0x1C))
        XCTAssertEqual(Palette.entries[4], PaletteColor(r: 0x5C, g: 0xC7, b: 0x8C))
        XCTAssertEqual(Palette.entries[7], PaletteColor(r: 0xF5, g: 0xBA, b: 0x3B))
    }
}
```

- [ ] **Step 2: Write the failing tests**

File: `IFRCore/Tests/IFRCoreTests/PixelSpriteTests.swift`

```swift
import XCTest
@testable import IFRCore

final class PixelSpriteTests: XCTestCase {
    func testSpriteParsesWidthHeightAndIndices() throws {
        let sprite = try PixelSprite(rows: ["012", "345"])
        XCTAssertEqual(sprite.width, 3)
        XCTAssertEqual(sprite.height, 2)
        XCTAssertEqual(sprite[0, 0], 0)
        XCTAssertEqual(sprite[1, 0], 1)
        XCTAssertEqual(sprite[2, 0], 2)
        XCTAssertEqual(sprite[0, 1], 3)
        XCTAssertEqual(sprite[1, 1], 4)
        XCTAssertEqual(sprite[2, 1], 5)
    }

    func testSpriteRejectsRaggedRows() {
        XCTAssertThrowsError(try PixelSprite(rows: ["00", "0"])) { error in
            XCTAssertEqual(error as? PixelSpriteError, .raggedRows)
        }
    }

    func testSpriteRejectsUnknownCharacter() {
        XCTAssertThrowsError(try PixelSprite(rows: ["0x"])) { error in
            XCTAssertEqual(error as? PixelSpriteError, .badCharacter("x"))
        }
    }

    func testDotIsTransparentAndHexMapsToIndex() throws {
        let sprite = try PixelSprite(rows: [".f"])
        XCTAssertEqual(sprite[0, 0], Palette.transparent)
        XCTAssertEqual(sprite[1, 0], 15)
    }

    func testFlippedHorizontallyMirrorsColumns() throws {
        let sprite = try PixelSprite(rows: ["012"])
        let flipped = sprite.flippedHorizontally()
        XCTAssertEqual(flipped[0, 0], 2)
        XCTAssertEqual(flipped[1, 0], 1)
        XCTAssertEqual(flipped[2, 0], 0)
    }

    func testRecolouredReplacesMappedIndicesOnly() throws {
        let sprite = try PixelSprite(rows: ["012"])
        let recoloured = sprite.recoloured([1: 9])
        XCTAssertEqual(recoloured[0, 0], 0)
        XCTAssertEqual(recoloured[1, 0], 9)
        XCTAssertEqual(recoloured[2, 0], 2)
    }
}
```

- [ ] **Step 3: Write the failing tests**

File: `IFRCore/Tests/IFRCoreTests/PixelFrameTests.swift`

```swift
import XCTest
@testable import IFRCore

final class PixelFrameTests: XCTestCase {
    func testFrameHasThirtyEightThousandFourHundredPixels() {
        let frame = PixelFrame(fill: 1)
        XCTAssertEqual(frame.pixels.count, 38_400)
    }

    func testBlitSkipsTransparentPixels() throws {
        var frame = PixelFrame(fill: 1)
        let sprite = try PixelSprite(rows: [".f"])
        frame.blit(sprite, at: GridPoint(x: 0, y: 0))
        XCTAssertEqual(frame.pixels[0], 1)
        XCTAssertEqual(frame.pixels[1], 15)
    }

    func testBlitClipsAtFrameEdges() throws {
        var frame = PixelFrame(fill: 0)
        let sprite = try PixelSprite(rows: ["ff", "ff"])
        frame.blit(sprite, at: GridPoint(x: 236, y: 156))
        for y in 0..<PixelFrame.height {
            for x in 0..<PixelFrame.width {
                let value = frame.pixels[y * PixelFrame.width + x]
                if x >= 236 && x < 238 && y >= 156 && y < 158 {
                    XCTAssertEqual(value, 15)
                } else {
                    XCTAssertEqual(value, 0)
                }
            }
        }
    }

    func testFillRectSetsIndices() {
        var frame = PixelFrame(fill: 0)
        frame.fill(PixelRect(x: 2, y: 3, width: 4, height: 2), index: 7)
        for y in 3..<5 {
            for x in 2..<6 {
                XCTAssertEqual(frame.pixels[y * PixelFrame.width + x], 7)
            }
        }
        XCTAssertEqual(frame.pixels[0], 0)
    }

    func testFrameRectDrawsOuterAndInnerLines() {
        var frame = PixelFrame(fill: 0)
        frame.frame(PixelRect(x: 10, y: 10, width: 5, height: 5), outer: 6, inner: 9)
        XCTAssertEqual(frame.pixels[10 * PixelFrame.width + 10], 6)
        XCTAssertEqual(frame.pixels[11 * PixelFrame.width + 11], 9)
        XCTAssertEqual(frame.pixels[12 * PixelFrame.width + 12], 0)
    }

    func testLineDrawsBresenhamBetweenPoints() {
        var frame = PixelFrame(fill: 0)
        frame.line(from: GridPoint(x: 0, y: 0), to: GridPoint(x: 4, y: 2), index: 5)
        let expected: Set<Int> = [
            0 * PixelFrame.width + 0,
            1 * PixelFrame.width + 1,
            1 * PixelFrame.width + 2,
            2 * PixelFrame.width + 3,
            2 * PixelFrame.width + 4,
        ]
        let litPixels = Set(frame.pixels.indices.filter { frame.pixels[$0] == 5 })
        XCTAssertEqual(litPixels, expected)
    }

    func testCursorAndDialogueFrameRenderIntoPixelFrame() throws {
        var frame = PixelFrame(fill: 1)
        frame.frame(PixelRect(x: 0, y: 112, width: 240, height: 48), outer: 6, inner: 0)
        let cursor = try XCTUnwrap(SpriteCatalog.sprite(named: "cursor"))
        frame.blit(cursor, at: GridPoint(x: 224, y: 148))
        XCTAssertEqual(frame.pixels[112 * PixelFrame.width + 0], 6)
        XCTAssertEqual(frame.pixels[148 * PixelFrame.width + 224], 6)
    }
}
```

- [ ] **Step 4: Run the tests to verify they fail**

Run: `scripts/test-core.sh --filter "PixelSpriteTests|PixelFrameTests|PaletteTests"`
Expected:
```
error: cannot find 'Palette' in scope
error: cannot find 'PaletteColor' in scope
```
(with the implementation files absent, every reference to `Palette`, `PaletteColor`, `PixelSprite`, `PixelFrame`, `PixelRect`, `GridPoint` and `SpriteCatalog` fails to compile the same way.)

- [ ] **Step 5: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Pixel/GridPoint.swift`

```swift
import Foundation

public struct GridPoint: Hashable, Codable, Sendable {
    public let x: Int
    public let y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
}
```

- [ ] **Step 6: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Pixel/Palette.swift`

```swift
import Foundation

public struct PaletteColor: Equatable, Sendable {
    public let r: UInt8
    public let g: UInt8
    public let b: UInt8

    public init(r: UInt8, g: UInt8, b: UInt8) {
        self.r = r
        self.g = g
        self.b = b
    }
}

public enum Palette {
    public static let transparent: UInt8 = 255

    public static let entries: [PaletteColor] = [
        PaletteColor(r: 0x0A, g: 0x0C, b: 0x0B),
        PaletteColor(r: 0x1A, g: 0x1F, b: 0x1C),
        PaletteColor(r: 0x2E, g: 0x3A, b: 0x33),
        PaletteColor(r: 0x47, g: 0x60, b: 0x4F),
        PaletteColor(r: 0x5C, g: 0xC7, b: 0x8C),
        PaletteColor(r: 0x9F, g: 0xE6, b: 0xBC),
        PaletteColor(r: 0xE8, g: 0xF5, b: 0xEC),
        PaletteColor(r: 0xF5, g: 0xBA, b: 0x3B),
        PaletteColor(r: 0xB8, g: 0x79, b: 0x1A),
        PaletteColor(r: 0x7A, g: 0x3A, b: 0x1E),
        PaletteColor(r: 0xE0, g: 0x5A, b: 0x4E),
        PaletteColor(r: 0x3E, g: 0x6F, b: 0xA8),
        PaletteColor(r: 0x8F, g: 0xB8, b: 0xE8),
        PaletteColor(r: 0x6B, g: 0x6F, b: 0x6C),
        PaletteColor(r: 0xC9, g: 0xCD, b: 0xCA),
        PaletteColor(r: 0xFF, g: 0xFF, b: 0xFF),
    ]
}
```

- [ ] **Step 7: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Pixel/PixelSprite.swift`

```swift
import Foundation

public enum PixelSpriteError: Error, Equatable {
    case raggedRows
    case badCharacter(Character)
}

public struct PixelSprite: Equatable, Sendable {
    public let width: Int
    public let height: Int
    private let indices: [UInt8]

    public init(rows: [String]) throws {
        let charRows = rows.map { Array($0) }
        let width = charRows.first?.count ?? 0
        guard charRows.allSatisfy({ $0.count == width }) else {
            throw PixelSpriteError.raggedRows
        }
        var indices: [UInt8] = []
        indices.reserveCapacity(width * charRows.count)
        for row in charRows {
            for character in row {
                indices.append(try PixelSprite.index(for: character))
            }
        }
        self.width = width
        self.height = charRows.count
        self.indices = indices
    }

    private init(width: Int, height: Int, indices: [UInt8]) {
        self.width = width
        self.height = height
        self.indices = indices
    }

    public subscript(x: Int, y: Int) -> UInt8 {
        indices[y * width + x]
    }

    public func flippedHorizontally() -> PixelSprite {
        var flipped = indices
        for y in 0..<height {
            for x in 0..<width {
                flipped[y * width + x] = indices[y * width + (width - 1 - x)]
            }
        }
        return PixelSprite(width: width, height: height, indices: flipped)
    }

    public func recoloured(_ map: [UInt8: UInt8]) -> PixelSprite {
        PixelSprite(width: width, height: height, indices: indices.map { map[$0] ?? $0 })
    }

    private static func index(for character: Character) throws -> UInt8 {
        if character == "." {
            return Palette.transparent
        }
        if let value = character.hexDigitValue {
            return UInt8(value)
        }
        throw PixelSpriteError.badCharacter(character)
    }
}
```

- [ ] **Step 8: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Pixel/PixelRect.swift`

```swift
import Foundation

public struct PixelRect: Equatable, Sendable {
    public let x: Int
    public let y: Int
    public let width: Int
    public let height: Int

    public init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}
```

- [ ] **Step 9: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Pixel/PixelFrame.swift`

```swift
import Foundation

public struct PixelFrame: Equatable, Sendable {
    public static let width = 240
    public static let height = 160

    public var pixels: [UInt8]

    public init(fill: UInt8) {
        pixels = [UInt8](repeating: fill, count: PixelFrame.width * PixelFrame.height)
    }

    public mutating func blit(_ sprite: PixelSprite, at point: GridPoint) {
        for spriteY in 0..<sprite.height {
            let frameY = point.y + spriteY
            guard frameY >= 0, frameY < PixelFrame.height else { continue }
            for spriteX in 0..<sprite.width {
                let frameX = point.x + spriteX
                guard frameX >= 0, frameX < PixelFrame.width else { continue }
                let colour = sprite[spriteX, spriteY]
                guard colour != Palette.transparent else { continue }
                pixels[frameY * PixelFrame.width + frameX] = colour
            }
        }
    }

    public mutating func fill(_ rect: PixelRect, index: UInt8) {
        let minX = max(0, rect.x)
        let maxX = min(PixelFrame.width, rect.x + rect.width)
        let minY = max(0, rect.y)
        let maxY = min(PixelFrame.height, rect.y + rect.height)
        guard minX < maxX, minY < maxY else { return }
        for y in minY..<maxY {
            for x in minX..<maxX {
                pixels[y * PixelFrame.width + x] = index
            }
        }
    }

    public mutating func frame(_ rect: PixelRect, outer: UInt8, inner: UInt8) {
        drawOutline(rect, index: outer)
        let inset = PixelRect(x: rect.x + 1, y: rect.y + 1, width: rect.width - 2, height: rect.height - 2)
        guard inset.width > 0, inset.height > 0 else { return }
        drawOutline(inset, index: inner)
    }

    public mutating func line(from start: GridPoint, to end: GridPoint, index: UInt8) {
        var x0 = start.x
        var y0 = start.y
        let dx = abs(end.x - start.x)
        let sx = start.x < end.x ? 1 : -1
        let dy = -abs(end.y - start.y)
        let sy = start.y < end.y ? 1 : -1
        var err = dx + dy
        while true {
            setPixel(x0, y0, index: index)
            if x0 == end.x && y0 == end.y { break }
            let doubledError = 2 * err
            if doubledError >= dy {
                err += dy
                x0 += sx
            }
            if doubledError <= dx {
                err += dx
                y0 += sy
            }
        }
    }

    private mutating func drawOutline(_ rect: PixelRect, index: UInt8) {
        for x in rect.x..<(rect.x + rect.width) {
            setPixel(x, rect.y, index: index)
            setPixel(x, rect.y + rect.height - 1, index: index)
        }
        for y in rect.y..<(rect.y + rect.height) {
            setPixel(rect.x, y, index: index)
            setPixel(rect.x + rect.width - 1, y, index: index)
        }
    }

    private mutating func setPixel(_ x: Int, _ y: Int, index: UInt8) {
        guard x >= 0, x < PixelFrame.width, y >= 0, y < PixelFrame.height else { return }
        pixels[y * PixelFrame.width + x] = index
    }
}
```

- [ ] **Step 10: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Pixel/Sprites/UISprites.swift`

```swift
import Foundation

public enum UISprites {
    public static let all: [String: PixelSprite] = [
        "cursor": cursor,
    ]

    private static let cursor = try! PixelSprite(rows: [
        "6.......",
        "66......",
        "666.....",
        "6666....",
        "666.....",
        "66......",
        "6.......",
        "........",
    ])
}
```

- [ ] **Step 11: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Pixel/SpriteCatalog.swift`

```swift
import Foundation

public enum SpriteCatalog {
    public static let all: [String: PixelSprite] = UISprites.all

    public static func sprite(named name: String) -> PixelSprite? {
        all[name]
    }
}
```

- [ ] **Step 12: Run all core tests**

Run: `scripts/test-core.sh`
Expected: `Executed 76 tests, with 0 failures`

- [ ] **Step 13: Commit**

Run: `git add IFRCore/Sources/IFRCore/Adventure/Pixel IFRCore/Tests/IFRCoreTests/PaletteTests.swift IFRCore/Tests/IFRCoreTests/PixelSpriteTests.swift IFRCore/Tests/IFRCoreTests/PixelFrameTests.swift && git commit -m "M1-05: Pixel primitives (Linux)"`

---

### Task M1-06: Rendering spike (Xcode)

**Files:**
- Create: `IFRCore/Sources/IFRCore/Adventure/Pixel/IntegerScaler.swift`
- Create: `App/Screens/Adventure/PixelImageBuilder.swift`
- Create: `App/Screens/Adventure/SpriteRasterizer.swift`
- Create: `App/Screens/Adventure/GBAScreen.swift`
- Create: `App/Theme/RetroTheme.swift`
- Modify: `App/Theme/Haptics.swift`
- Test: `IFRCore/Tests/IFRCoreTests/IntegerScalerTests.swift`
- Test: `AppTests/PixelImageBuilderTests.swift`
- Test: `AppTests/FontBundlingTests.swift`

**Interfaces:**
- Consumes: `PixelFrame` (`IFRCore/Sources/IFRCore/Adventure/Pixel/PixelFrame.swift`), `Palette` (`IFRCore/Sources/IFRCore/Adventure/Pixel/Palette.swift`), `Theme.panel` (`App/Theme/Theme.swift`)
- Produces: `IntegerScaler.scale(viewWidth:viewHeight:displayScale:) -> Int`, `IntegerScaler.canvasSize(scale:displayScale:) -> (width: Double, height: Double)` in IFRCore, used by later Adventure screens to size the GBA canvas; `PixelImageBuilder.image(from: PixelFrame) -> CGImage?` and the same-interface fallback `SpriteRasterizer.image(from:scale:) -> CGImage?`, used by `GBAScreen` and later battle/overworld screens; `RetroTheme.pixelFont(size:) -> Font` and `RetroTheme.pixelFontSize(scale:displayScale:) -> CGFloat`, used by every screen that draws dialogue, nameplates or HP labels; `Haptics.critical()` and `Haptics.tick()`, used by later battle and dialogue work items.

- [ ] **Step 1: Write the failing tests**

File: `IFRCore/Tests/IFRCoreTests/IntegerScalerTests.swift`

```swift
import XCTest
@testable import IFRCore

final class IntegerScalerTests: XCTestCase {
    func testIPhoneFifteenWidthAtThreeXGivesScaleFour() {
        let scale = IntegerScaler.scale(viewWidth: 393, viewHeight: 700, displayScale: 3)
        XCTAssertEqual(scale, 4)
    }

    func testScaleNeverBelowOne() {
        let scale = IntegerScaler.scale(viewWidth: 100, viewHeight: 100, displayScale: 1)
        XCTAssertEqual(scale, 1)
    }

    func testHeightConstrainedViewUsesSmallerAxis() {
        let scale = IntegerScaler.scale(viewWidth: 1000, viewHeight: 200, displayScale: 1)
        XCTAssertEqual(scale, 1)
    }

    func testCanvasSizeIsExactMultipleOfLogicalSize() {
        let size = IntegerScaler.canvasSize(scale: 4, displayScale: 3)
        XCTAssertEqual(size.width, 320, accuracy: 0.001)
        XCTAssertEqual(size.height, 213.333, accuracy: 0.001)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `scripts/test-core.sh --filter IntegerScalerTests`
Expected:
```
/home/user/IFR-build-b/FlashCards/IFRCore/Tests/IFRCoreTests/IntegerScalerTests.swift:6:21: error: cannot find 'IntegerScaler' in scope
        let scale = IntegerScaler.scale(viewWidth: 393, viewHeight: 700, displayScale: 3)
                    `- error: cannot find 'IntegerScaler' in scope
error: fatalError
```

- [ ] **Step 3: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Pixel/IntegerScaler.swift`

```swift
import Foundation

public enum IntegerScaler {
    public static func scale(viewWidth: Double, viewHeight: Double, displayScale: Double) -> Int {
        let widthScale = viewWidth * displayScale / Double(PixelFrame.width)
        let heightScale = viewHeight * displayScale / Double(PixelFrame.height)
        let scale = Int(min(widthScale, heightScale).rounded(.down))
        return max(1, scale)
    }

    public static func canvasSize(scale: Int, displayScale: Double) -> (width: Double, height: Double) {
        let width = Double(PixelFrame.width * scale) / displayScale
        let height = Double(PixelFrame.height * scale) / displayScale
        return (width, height)
    }
}
```

- [ ] **Step 4: Run all core tests**

Run: `scripts/test-core.sh`
Expected: `Executed 110 tests, with 0 failures`

- [ ] **Step 5: Write the app-layer rendering (cannot be compiled on Linux; written to fit the existing SwiftUI code it sits beside, never run here)**

File: `App/Screens/Adventure/PixelImageBuilder.swift`

```swift
import CoreGraphics
import Foundation
import IFRCore

enum PixelImageBuilder {
    static func image(from frame: PixelFrame) -> CGImage? {
        let provider = CGDataProvider(data: rgbaData(from: frame) as CFData)
        guard let provider else { return nil }
        return CGImage(
            width: PixelFrame.width,
            height: PixelFrame.height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: PixelFrame.width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }

    private static func rgbaData(from frame: PixelFrame) -> Data {
        var bytes = [UInt8](repeating: 0, count: frame.pixels.count * 4)
        for (index, paletteIndex) in frame.pixels.enumerated() {
            let offset = index * 4
            guard paletteIndex != Palette.transparent else { continue }
            let colour = Palette.entries[Int(paletteIndex)]
            bytes[offset] = colour.r
            bytes[offset + 1] = colour.g
            bytes[offset + 2] = colour.b
            bytes[offset + 3] = 255
        }
        return Data(bytes)
    }
}
```

- [ ] **Step 6: Write the fallback rasterizer behind the same interface**

File: `App/Screens/Adventure/SpriteRasterizer.swift`

```swift
import CoreGraphics
import IFRCore

enum SpriteRasterizer {
    static func image(from frame: PixelFrame, scale: Int) -> CGImage? {
        let width = PixelFrame.width * scale
        let height = PixelFrame.height * scale
        let space = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.interpolationQuality = .none
        for y in 0..<PixelFrame.height {
            for x in 0..<PixelFrame.width {
                let paletteIndex = frame.pixels[y * PixelFrame.width + x]
                guard paletteIndex != Palette.transparent else { continue }
                let colour = Palette.entries[Int(paletteIndex)]
                context.setFillColor(
                    red: CGFloat(colour.r) / 255,
                    green: CGFloat(colour.g) / 255,
                    blue: CGFloat(colour.b) / 255,
                    alpha: 1
                )
                let deviceY = PixelFrame.height - 1 - y
                let rect = CGRect(x: x * scale, y: deviceY * scale, width: scale, height: scale)
                context.fill(rect)
            }
        }
        return context.makeImage()
    }
}
```

- [ ] **Step 7: Write the GBA screen**

File: `App/Screens/Adventure/GBAScreen.swift`

```swift
import SwiftUI
import IFRCore

struct GBAScreen: View {
    let frame: PixelFrame

    @Environment(\.displayScale) private var displayScale

    var body: some View {
        GeometryReader { geometry in
            let scale = IntegerScaler.scale(
                viewWidth: geometry.size.width,
                viewHeight: geometry.size.height,
                displayScale: displayScale
            )
            let canvas = IntegerScaler.canvasSize(scale: scale, displayScale: displayScale)
            canvasImage
                .frame(width: canvas.width, height: canvas.height)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .background(Theme.panel)
    }

    private var canvasImage: some View {
        Group {
            if let image = PixelImageBuilder.image(from: frame) {
                Image(decorative: image, scale: 1)
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Color.clear
            }
        }
    }
}
```

- [ ] **Step 8: Write the pixel font wrapper**

File: `App/Theme/RetroTheme.swift`

```swift
import SwiftUI
import UIKit

enum RetroTheme {
    static let pixelFontName = "PressStart2P-Regular"

    static func pixelFont(size: CGFloat) -> Font {
        guard UIFont(name: pixelFontName, size: size) != nil else {
            return Font.system(size: size, design: .monospaced)
        }
        return Font.custom(pixelFontName, size: size)
    }

    static func pixelFontSize(scale: Int, displayScale: CGFloat) -> CGFloat {
        8 * CGFloat(scale) / displayScale
    }
}
```

- [ ] **Step 9: Add the new haptics used by later battle and dialogue work**

File: `App/Theme/Haptics.swift`, `Haptics` enum:

```swift
@MainActor
enum Haptics {
    static func correct() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func incorrect() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
    static func flip() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func critical() { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
    static func tick() { UISelectionFeedbackGenerator().selectionChanged() }
}
```

- [ ] **Step 10: Write the app-target tests**

File: `AppTests/PixelImageBuilderTests.swift`

```swift
import XCTest
import IFRCore
@testable import IFRFlashCards

final class PixelImageBuilderTests: XCTestCase {
    private func bytes(of image: CGImage) -> [UInt8] {
        let data = image.dataProvider!.data as Data
        return [UInt8](data)
    }

    func testBuilderProducesTwoHundredFortyByOneSixtyImage() throws {
        let frame = PixelFrame(fill: 1)
        let image = try XCTUnwrap(PixelImageBuilder.image(from: frame))
        XCTAssertEqual(image.width, 240)
        XCTAssertEqual(image.height, 160)
    }

    func testPaletteIndexFourMapsToAccentRGBA() throws {
        let frame = PixelFrame(fill: 4)
        let image = try XCTUnwrap(PixelImageBuilder.image(from: frame))
        let pixels = bytes(of: image)
        XCTAssertEqual(pixels[0], 0x5C)
        XCTAssertEqual(pixels[1], 0xC7)
        XCTAssertEqual(pixels[2], 0x8C)
        XCTAssertEqual(pixels[3], 0xFF)
    }

    func testTransparentIndexMapsToZeroAlpha() throws {
        let frame = PixelFrame(fill: Palette.transparent)
        let image = try XCTUnwrap(PixelImageBuilder.image(from: frame))
        let pixels = bytes(of: image)
        XCTAssertEqual(pixels[3], 0)
    }
}
```

File: `AppTests/FontBundlingTests.swift`

```swift
import XCTest
import UIKit

final class FontBundlingTests: XCTestCase {
    private var fontURL: URL? {
        Bundle.main.url(forResource: "PressStart2P-Regular", withExtension: "ttf")
    }

    func testPixelFontIsRegistered() throws {
        guard fontURL != nil else {
            throw XCTSkip("PressStart2P-Regular.ttf is not bundled yet")
        }
        XCTAssertNotNil(UIFont(name: "PressStart2P-Regular", size: 8))
    }

    func testOpenFontLicenseIsBundledAndNamesVersionOnePointOne() throws {
        guard fontURL != nil else {
            throw XCTSkip("PressStart2P-Regular.ttf is not bundled yet")
        }
        let licenseURL = try XCTUnwrap(Bundle.main.url(forResource: "OFL", withExtension: "txt"))
        let text = try String(contentsOf: licenseURL, encoding: .utf8)
        XCTAssertTrue(text.contains("Version 1.1"))
    }
}
```

Expected on Xcode (`scripts/test-app.sh`): both `FontBundlingTests` cases report as skipped (`XCTSkip: PressStart2P-Regular.ttf is not bundled yet`) because `App/Fonts/PressStart2P-Regular.ttf` was not downloaded in this pass; `PixelImageBuilderTests` compiles and its three cases pass, since `PixelImageBuilder` only depends on `IFRCore` and `CoreGraphics`.

- [ ] **Step 11: Commit**

Run: `git add App/Screens/Adventure App/Theme/RetroTheme.swift App/Theme/Haptics.swift AppTests/PixelImageBuilderTests.swift AppTests/FontBundlingTests.swift IFRCore/Sources/IFRCore/Adventure/Pixel/IntegerScaler.swift IFRCore/Tests/IFRCoreTests/IntegerScalerTests.swift && git commit -m "M1-06: Rendering spike"`

---

### Task M1-07: Encounter deck (Linux)

**Files:**
- Create: `IFRCore/Sources/IFRCore/Adventure/Encounters/EncounterDeck.swift`
- Test: `IFRCore/Tests/IFRCoreTests/EncounterDeckTests.swift`

**Interfaces:**
- Consumes: `StudyQueue.session(bank:states:settings:newIntroducedToday:now:)` (`IFRCore/Sources/IFRCore/Scheduling/StudyQueue.swift`); `QuizEngine.makeQuiz(config:bank:states:now:using:)` and `QuizConfig` (`IFRCore/Sources/IFRCore/Quiz/QuizEngine.swift`); `Scheduler` (`IFRCore/Sources/IFRCore/Scheduling/Scheduler.swift`); `Question`, `QuestionBank`, `Category` (`IFRCore/Sources/IFRCore/Models/Question.swift`, `QuestionBank.swift`); `CardState` (`IFRCore/Sources/IFRCore/Scheduling/CardState.swift`).
- Produces: `EncounterDeck: Sendable` with `init(scheduler: Scheduler)` and `func draw(count: Int, categories: [Category]?, bank: QuestionBank, states: [String: CardState], now: Date, using rng: inout some RandomNumberGenerator) -> [Question]`, used by every future gym/trainer/Elite Four/cloud/rival/tower drawer.

- [ ] **Step 1: Write the failing tests**

File: `IFRCore/Tests/IFRCoreTests/EncounterDeckTests.swift`

```swift
import XCTest
@testable import IFRCore

final class EncounterDeckTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let scheduler = Scheduler()
    lazy var deck = EncounterDeck(scheduler: scheduler)

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

    private func dueState(_ id: String, dueOffset: TimeInterval) -> CardState {
        var s = CardState.new(questionID: id)
        s.reps = 1
        s.due = now.addingTimeInterval(dueOffset)
        return s
    }

    func testDueCardsInCategoryComeFirstOldestFirst() {
        let bank = fullBank(perCategory: 5)
        let states = [
            "weather-0": dueState("weather-0", dueOffset: -300),
            "weather-1": dueState("weather-1", dueOffset: -200),
            "weather-2": dueState("weather-2", dueOffset: -100),
        ]
        var rng = SeededRNG(seed: 7)
        let drawn = deck.draw(count: 5, categories: [.weather], bank: bank, states: states,
                              now: now, using: &rng)
        XCTAssertEqual(Array(drawn.prefix(3).map(\.id)), ["weather-0", "weather-1", "weather-2"])
    }

    func testNilCategoriesKeepsQueueRoundRobinOrder() {
        let bank = QuestionBank(version: 1, questions: [
            mcQuestion("w1", .weather), mcQuestion("w2", .weather),
            mcQuestion("r1", .regulations), mcQuestion("r2", .regulations),
        ])
        let states = [
            "w1": dueState("w1", dueOffset: -400), "w2": dueState("w2", dueOffset: -300),
            "r1": dueState("r1", dueOffset: -200), "r2": dueState("r2", dueOffset: -100),
        ]
        let expected = StudyQueue.session(bank: bank, states: states,
                                          settings: StudySettings(newCardsPerDay: 0),
                                          newIntroducedToday: 0, now: now).map(\.id)
        var rng = SeededRNG(seed: 7)
        let drawn = deck.draw(count: 4, categories: nil, bank: bank, states: states,
                              now: now, using: &rng)
        XCTAssertEqual(drawn.map(\.id), expected)
    }

    func testFlashcardOnlyQuestionsAreExcluded() {
        var flashcard = mcQuestion("fc", .weather)
        flashcard = Question(id: "fc", category: .weather, acsCodes: ["IR.I.B.K1"], format: .flashcard,
                             front: "f", back: "b", options: nil, correctIndex: nil, explanation: "e",
                             source: flashcard.source, figure: nil, difficulty: 1)
        let bank = QuestionBank(version: 1, questions: [flashcard, mcQuestion("mc", .weather)])
        let states = [
            "fc": dueState("fc", dueOffset: -100),
            "mc": dueState("mc", dueOffset: -50),
        ]
        var rng = SeededRNG(seed: 7)
        let drawn = deck.draw(count: 5, categories: [.weather], bank: bank, states: states,
                              now: now, using: &rng)
        XCTAssertEqual(drawn.map(\.id), ["mc"])
    }

    func testTopsUpWithRetentionWeightedDrawWhenFewAreDue() {
        let bank = QuestionBank(version: 1, questions: [mcQuestion("strong", .weather), mcQuestion("weak", .weather)])
        let states = ["strong": scheduler.review(.new(questionID: "strong"), grade: .good, at: now)]
        var weakPicks = 0
        var rng = SeededRNG(seed: 42)
        for _ in 0..<200 {
            let drawn = deck.draw(count: 1, categories: [.weather], bank: bank, states: states,
                                  now: now, using: &rng)
            if drawn.first?.id == "weak" { weakPicks += 1 }
        }
        XCTAssertGreaterThan(weakPicks, 120, "weak card (weight ~1.25) beats strong card (~0.25)")
    }

    func testNeverPadsBeyondPool() {
        let bank = QuestionBank(version: 1, questions: (0..<6).map { mcQuestion("q\($0)", .weather) })
        var rng = SeededRNG(seed: 7)
        let drawn = deck.draw(count: 10, categories: nil, bank: bank, states: [:], now: now, using: &rng)
        XCTAssertEqual(drawn.count, 6)
    }

    func testNoDuplicateIDsInOneDraw() {
        let bank = fullBank(perCategory: 10)
        var states: [String: CardState] = [:]
        states["regulations-0"] = dueState("regulations-0", dueOffset: -100)
        states["regulations-1"] = dueState("regulations-1", dueOffset: -50)
        states["emergencies-0"] = dueState("emergencies-0", dueOffset: -80)
        var rng = SeededRNG(seed: 7)
        let drawn = deck.draw(count: 12, categories: [.regulations, .emergencies], bank: bank,
                              states: states, now: now, using: &rng)
        XCTAssertEqual(Set(drawn.map(\.id)).count, drawn.count)
    }

    func testSameSeedSameDraw() {
        let bank = fullBank(perCategory: 10)
        let states = ["weather-0": dueState("weather-0", dueOffset: -100)]
        var rng1 = SeededRNG(seed: 7)
        let first = deck.draw(count: 8, categories: [.weather, .regulations], bank: bank,
                              states: states, now: now, using: &rng1)
        var rng2 = SeededRNG(seed: 7)
        let second = deck.draw(count: 8, categories: [.weather, .regulations], bank: bank,
                               states: states, now: now, using: &rng2)
        XCTAssertEqual(first.map(\.id), second.map(\.id))
    }

    func testNilCategoriesDrawsAcrossAllCategories() {
        let bank = fullBank(perCategory: 10)
        var rng = SeededRNG(seed: 7)
        let drawn = deck.draw(count: 40, categories: nil, bank: bank, states: [:], now: now, using: &rng)
        XCTAssertGreaterThan(Set(drawn.map(\.category)).count, 1)
    }

    func testTwoCategoriesDrawHalfEach() {
        let bank = fullBank(perCategory: 10)
        var states: [String: CardState] = [:]
        for i in 0..<10 {
            states["regulations-\(i)"] = dueState("regulations-\(i)", dueOffset: TimeInterval(-100 - i))
        }
        var rng = SeededRNG(seed: 7)
        let drawn = deck.draw(count: 12, categories: [.regulations, .emergencies], bank: bank,
                              states: states, now: now, using: &rng)
        XCTAssertEqual(drawn.filter { $0.category == .regulations }.count, 6)
        XCTAssertEqual(drawn.filter { $0.category == .emergencies }.count, 6)
    }

    func testUnevenSplitGivesRemainderToEarliestCategory() {
        let bank = fullBank(perCategory: 10)
        var rng = SeededRNG(seed: 7)
        let drawn = deck.draw(count: 7, categories: [.weather, .regulations, .emergencies],
                              bank: bank, states: [:], now: now, using: &rng)
        XCTAssertEqual(drawn.filter { $0.category == .weather }.count, 3)
        XCTAssertEqual(drawn.filter { $0.category == .regulations }.count, 2)
        XCTAssertEqual(drawn.filter { $0.category == .emergencies }.count, 2)
    }

    func testDuePrefixContainsNoUnseenCards() {
        let bank = QuestionBank(version: 1, questions: (0..<6).map { mcQuestion("q\($0)", .weather) })
        let engine = QuizEngine(scheduler: scheduler)
        var rngA = SeededRNG(seed: 7)
        let empty = deck.draw(count: 4, categories: [.weather], bank: bank, states: [:], now: now, using: &rngA)
        var rngB = SeededRNG(seed: 7)
        let expectedEmpty = engine.makeQuiz(config: QuizConfig(category: .weather, length: 4, isMockExam: false),
                                            bank: bank, states: [:], now: now, using: &rngB)
        XCTAssertEqual(empty.map(\.id), expectedEmpty.map(\.id))

        let states = [
            "q0": dueState("q0", dueOffset: -200),
            "q1": dueState("q1", dueOffset: -100),
        ]
        var rngC = SeededRNG(seed: 7)
        let withDue = deck.draw(count: 4, categories: [.weather], bank: bank, states: states, now: now, using: &rngC)
        XCTAssertEqual(Array(withDue.prefix(2).map(\.id)), ["q0", "q1"])
        let dueIDs = Set(["q0", "q1"])
        XCTAssertTrue(withDue.dropFirst(2).allSatisfy { !dueIDs.contains($0.id) })
    }

    func testDueCardInAnyCategoryDrawsWithoutSettings() {
        let bank = QuestionBank(version: 1, questions: [mcQuestion("a", .approaches)])
        let states = ["a": dueState("a", dueOffset: -60)]
        var rng = SeededRNG(seed: 7)
        let drawn = deck.draw(count: 1, categories: [.approaches], bank: bank, states: states,
                              now: now, using: &rng)
        XCTAssertEqual(drawn.map(\.id), ["a"])
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `scripts/test-core.sh --filter EncounterDeckTests`
Expected: `error: cannot infer key path type from context` (and `reference to member 'weather' cannot be resolved without a contextual type`) at every `\.id` / `.weather`-style call site, because `EncounterDeck` does not exist yet and the whole file fails to type-check.

- [ ] **Step 3: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Encounters/EncounterDeck.swift`

```swift
import Foundation

public struct EncounterDeck: Sendable {
    private let engine: QuizEngine

    public init(scheduler: Scheduler) {
        engine = QuizEngine(scheduler: scheduler)
    }

    public func draw(
        count: Int,
        categories: [Category]?,
        bank: QuestionBank,
        states: [String: CardState],
        now: Date,
        using rng: inout some RandomNumberGenerator
    ) -> [Question] {
        let groups: [Category?] = categories.map { $0.map { Optional($0) } } ?? [nil]
        var drawn: [Question] = []
        var excluded: Set<String> = []
        for (index, category) in groups.enumerated() {
            let slotQuota = quota(for: index, groupCount: groups.count, count: count)
            let prefix = duePrefix(category: category, quota: slotQuota, bank: bank, states: states, now: now)
            drawn += prefix
            excluded.formUnion(prefix.map(\.id))
            let remaining = slotQuota - prefix.count
            let topped = topUp(category: category, remaining: remaining, excluding: excluded,
                                bank: bank, states: states, now: now, using: &rng)
            drawn += topped
            excluded.formUnion(topped.map(\.id))
        }
        return drawn
    }

    private func quota(for index: Int, groupCount: Int, count: Int) -> Int {
        let base = count / groupCount
        let remainder = count % groupCount
        return base + (index < remainder ? 1 : 0)
    }

    private func duePrefix(
        category: Category?, quota: Int, bank: QuestionBank, states: [String: CardState], now: Date
    ) -> [Question] {
        guard quota > 0 else { return [] }
        let session = StudyQueue.session(
            bank: bank, states: states, settings: StudySettings(newCardsPerDay: 0),
            newIntroducedToday: 0, now: now
        )
        let matching = session
            .filter(\.isMultipleChoiceCapable)
            .filter { category == nil || $0.category == category }
        return Array(matching.prefix(quota))
    }

    private func topUp(
        category: Category?, remaining: Int, excluding: Set<String>,
        bank: QuestionBank, states: [String: CardState], now: Date,
        using rng: inout some RandomNumberGenerator
    ) -> [Question] {
        guard remaining > 0 else { return [] }
        let pool = bank.questions.filter { !excluding.contains($0.id) }
        let bankExcludingChosen = QuestionBank(version: bank.version, questions: pool)
        let config = QuizConfig(category: category, length: remaining, isMockExam: false)
        return engine.makeQuiz(config: config, bank: bankExcludingChosen, states: states, now: now, using: &rng)
    }
}
```

- [ ] **Step 4: Run all core tests**

Run: `scripts/test-core.sh`
Expected: `Executed 73 tests, with 0 failures`

- [ ] **Step 5: Commit**

Run: `git add FlashCards/IFRCore/Sources/IFRCore/Adventure/Encounters/EncounterDeck.swift FlashCards/IFRCore/Tests/IFRCoreTests/EncounterDeckTests.swift && git commit -m "M1-07: Encounter deck (Linux)"`

---

### Task M1-08a: Content model, decoding and JSON (Linux)

**Files:**
- Create: `IFRCore/Sources/IFRCore/Adventure/Circuit/GymID.swift`
- Create: `IFRCore/Sources/IFRCore/Adventure/Content/RegionMap.swift`
- Create: `IFRCore/Sources/IFRCore/Adventure/Content/Gym.swift`
- Create: `IFRCore/Sources/IFRCore/Adventure/Content/DialogueScript.swift`
- Create: `IFRCore/Sources/IFRCore/Adventure/Content/DialogueTemplate.swift`
- Create: `IFRCore/Sources/IFRCore/Adventure/Content/Item.swift`
- Create: `IFRCore/Sources/IFRCore/Adventure/Content/AdventureContent.swift`
- Create: `IFRCore/Sources/IFRCore/Resources/adventure-v1.json`
- Modify: `IFRCore/Package.swift`
- Test: `IFRCore/Tests/IFRCoreTests/GymIDTests.swift`
- Test: `IFRCore/Tests/IFRCoreTests/AdventureContentTests.swift`

**Interfaces:**
- Consumes: `IFRCore.Category` (`IFRCore/Sources/IFRCore/Models/Question.swift`); `Bundle.module` resource loading in the style of `QuestionBank.load()` (`IFRCore/Sources/IFRCore/Models/QuestionBank.swift`).
- Produces: `GymID: String, Codable, CaseIterable, Sendable` with `var category: Category`, `var next: GymID?`, `var previous: GymID?` (`Adventure/Circuit/GymID.swift`); `GridPoint`, `AirportRole`, `Airport`, `Airway`, `RegionMap` (`Adventure/Content/RegionMap.swift`); `DialogueRefs`, `Gym`, `EliteMember`, `ChampionSpec` (`Adventure/Content/Gym.swift`); `DialogueScript`, `SystemDialogueKey` (`Adventure/Content/DialogueScript.swift`); `enum DialogueTemplate { static func filled(_:with:) -> DialogueScript }` (`Adventure/Content/DialogueTemplate.swift`); `ItemEffect`, `Item` (`Adventure/Content/Item.swift`); `AdventureContentError`, placeholder `TileMap`, `Trainer`, `RivalSpec`, `CompanionSpecies`, and `AdventureContent` with `static func load() throws -> AdventureContent`, `func validate() throws`, `func systemLine(_:filling:) -> DialogueScript` (`Adventure/Content/AdventureContent.swift`). Later work items (M1-08b onward) use `AdventureContent`, `Gym`, `Item`/`ItemEffect`, `GymID` and extend `AdventureContent.validate()`.

- [ ] **Step 1: Write the failing tests**

File: `IFRCore/Tests/IFRCoreTests/GymIDTests.swift`

```swift
import XCTest
@testable import IFRCore

final class GymIDTests: XCTestCase {
    func testCircuitOrderMatchesSpec() {
        XCTAssertEqual(GymID.allCases, [
            .humanFactors, .instrumentsAndSystems, .regulations, .navigation,
            .chartsAndPlanning, .weather, .emergencies, .approaches,
        ])
    }

    func testNextChainsEndInNil() {
        var current: GymID? = .humanFactors
        var visited: [GymID] = []
        while let gym = current {
            visited.append(gym)
            current = gym.next
        }
        XCTAssertEqual(visited, GymID.allCases)
        XCTAssertNil(GymID.approaches.next)
    }

    func testEveryGymIDMapsToItsCategory() {
        XCTAssertEqual(GymID.humanFactors.category, IFRCore.Category.humanFactors)
        XCTAssertEqual(GymID.instrumentsAndSystems.category, IFRCore.Category.instrumentsAndSystems)
        XCTAssertEqual(GymID.regulations.category, IFRCore.Category.regulations)
        XCTAssertEqual(GymID.navigation.category, IFRCore.Category.navigation)
        XCTAssertEqual(GymID.chartsAndPlanning.category, IFRCore.Category.chartsAndPlanning)
        XCTAssertEqual(GymID.weather.category, IFRCore.Category.weather)
        XCTAssertEqual(GymID.emergencies.category, IFRCore.Category.emergencies)
        XCTAssertEqual(GymID.approaches.category, IFRCore.Category.approaches)
    }

    func testGymIDCategoriesCoverAllEightCategoriesOnce() {
        let categories = Set(GymID.allCases.map(\.category))
        XCTAssertEqual(categories, Set(IFRCore.Category.allCases))
    }
}
```

- [ ] **Step 2: Write the failing tests**

File: `IFRCore/Tests/IFRCoreTests/AdventureContentTests.swift`

```swift
import XCTest
@testable import IFRCore

final class AdventureContentTests: XCTestCase {
    private func makeAirport(
        id: String = "KHYP", name: String = "Hypoxia Field", position: GridPoint = GridPoint(x: 3, y: 12),
        gymID: GymID? = .humanFactors, role: AirportRole = .gym
    ) -> Airport {
        Airport(id: id, name: name, position: position, gymID: gymID, role: role)
    }

    private func makeEliteMember(
        id: String = "elite-sierra", order: Int = 1, name: String = "Controller Sierra",
        nameplateName: String = "SIERRA", spriteID: String = "elite-sierra",
        categories: [IFRCore.Category] = [.regulations], questionCount: Int = 12,
        dialogue: DialogueRefs = DialogueRefs(intro: "sierra-intro", win: "sierra-win", lose: "sierra-lose")
    ) -> EliteMember {
        EliteMember(id: id, order: order, name: name, nameplateName: nameplateName, spriteID: spriteID,
                    categories: categories, questionCount: questionCount, dialogue: dialogue)
    }

    private func makeContent(
        airports: [Airport] = [], airways: [Airway] = [], gyms: [Gym] = [], eliteFour: [EliteMember] = [],
        items: [Item] = [], trainers: [Trainer] = []
    ) -> AdventureContent {
        AdventureContent(
            version: 1, region: RegionMap(airports: airports, airways: airways), gyms: gyms, eliteFour: eliteFour,
            champion: ChampionSpec(
                name: "The DPE", nameplateName: "THE DPE", spriteID: "champion",
                dialogue: DialogueRefs(intro: "champion-intro", win: "champion-win", lose: "champion-lose")
            ),
            dialogue: [:], system: [:], items: items, trainers: trainers
        )
    }

    func testBundledAdventureContentLoadsAndValidates() throws {
        let content = try AdventureContent.load()
        XCTAssertFalse(content.gyms.isEmpty)
        XCTAssertEqual(Set(content.gyms.map(\.id)).count, content.gyms.count)
    }

    func testDecodesGymFromJSONFragment() throws {
        let json = """
        {"id": "humanFactors", "leaderName": "Dr. Hypoxia", "nameplateName": "HYPOXIA",
         "leaderSpriteID": "leader-hypoxia", "badgeName": "Oxygen Badge", "questionCount": 10,
         "dialogue": {"intro": "hypoxia-intro", "win": "hypoxia-win", "lose": "hypoxia-lose"}}
        """.data(using: .utf8)!
        let gym = try JSONDecoder().decode(Gym.self, from: json)
        XCTAssertEqual(gym.id, .humanFactors)
        XCTAssertEqual(gym.leaderName, "Dr. Hypoxia")
        XCTAssertEqual(gym.nameplateName, "HYPOXIA")
        XCTAssertEqual(gym.questionCount, 10)
        XCTAssertEqual(gym.dialogue.win, "hypoxia-win")
    }

    func testMissingOptionalSectionsDecodeAsEmpty() throws {
        let json = """
        {"version": 1,
         "region": {"airports": [], "airways": []},
         "gyms": [],
         "champion": {"name": "The DPE", "nameplateName": "THE DPE", "spriteID": "champion",
                      "dialogue": {"intro": "champion-intro", "win": "champion-win", "lose": "champion-lose"}}}
        """.data(using: .utf8)!
        let content = try JSONDecoder().decode(AdventureContent.self, from: json)
        XCTAssertNil(content.tileMap)
        XCTAssertTrue(content.trainers.isEmpty)
        XCTAssertNil(content.rival)
        XCTAssertTrue(content.companions.isEmpty)
        XCTAssertTrue(content.eliteFour.isEmpty)
        XCTAssertTrue(content.dialogue.isEmpty)
        XCTAssertTrue(content.system.isEmpty)
        XCTAssertTrue(content.items.isEmpty)
    }

    func testUnknownItemEffectKindFailsDecoding() {
        let json = #"{"kind": "instantMastery"}"#.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(ItemEffect.self, from: json))
    }

    func testItemEffectCasesAreOnlyHealReviveRepelDirectTo() throws {
        let heal = try JSONDecoder().decode(ItemEffect.self, from: #"{"kind": "heal", "amount": 30}"#.data(using: .utf8)!)
        let revive = try JSONDecoder().decode(ItemEffect.self, from: #"{"kind": "reviveOnce"}"#.data(using: .utf8)!)
        let repel = try JSONDecoder().decode(ItemEffect.self, from: #"{"kind": "repel", "steps": 50}"#.data(using: .utf8)!)
        let directTo = try JSONDecoder().decode(ItemEffect.self, from: #"{"kind": "directTo"}"#.data(using: .utf8)!)
        XCTAssertEqual(heal, .heal(30))
        XCTAssertEqual(revive, .reviveOnce)
        XCTAssertEqual(repel, .repel(steps: 50))
        XCTAssertEqual(directTo, .directTo)
    }

    func testDialogueTemplateFillsPlaceholders() {
        let script = DialogueScript(pages: [
            "Welcome, {leader}! Fly to {airport} to earn the {badge}. Beat {opponent}. {unknown}",
        ])
        let filled = DialogueTemplate.filled(script, with: [
            "leader": "Gyro", "airport": "KGYR", "badge": "Gyro Badge", "opponent": "Gyro",
        ])
        XCTAssertEqual(
            filled.pages.first,
            "Welcome, Gyro! Fly to KGYR to earn the Gyro Badge. Beat Gyro. {unknown}"
        )
    }

    func testDuplicateIDsAcrossAirportsGymsEliteItemsTrainersRejected() {
        let content = makeContent(
            airports: [makeAirport(id: "shared-id")],
            eliteFour: [makeEliteMember(id: "shared-id")]
        )
        XCTAssertThrowsError(try content.validate()) {
            XCTAssertEqual($0 as? AdventureContentError, .duplicateID("shared-id"))
        }
    }
}
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `scripts/test-core.sh --filter AdventureContentTests`
Expected: with none of `Adventure/Content/*.swift` or `Adventure/Circuit/GymID.swift` present, the build fails to compile, e.g.:
```
error: type 'Equatable' has no member 'directTo'
error: cannot find 'DialogueScript' in scope
error: cannot find 'DialogueTemplate' in scope
error: cannot find type 'AdventureContentError' in scope
```
(confirmed by temporarily removing the new `Adventure/Circuit` and `Adventure/Content` directories and rerunning the filtered test target: the suite fails with `error: fatalError` after these compile errors.)

- [ ] **Step 4: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Circuit/GymID.swift`

```swift
import Foundation

public enum GymID: String, Codable, CaseIterable, Sendable {
    case humanFactors
    case instrumentsAndSystems
    case regulations
    case navigation
    case chartsAndPlanning
    case weather
    case emergencies
    case approaches

    public var category: Category {
        switch self {
        case .humanFactors: .humanFactors
        case .instrumentsAndSystems: .instrumentsAndSystems
        case .regulations: .regulations
        case .navigation: .navigation
        case .chartsAndPlanning: .chartsAndPlanning
        case .weather: .weather
        case .emergencies: .emergencies
        case .approaches: .approaches
        }
    }

    public var next: GymID? {
        neighbour(offset: 1)
    }

    public var previous: GymID? {
        neighbour(offset: -1)
    }

    private func neighbour(offset: Int) -> GymID? {
        let all = GymID.allCases
        guard let index = all.firstIndex(of: self) else { return nil }
        let target = index + offset
        guard all.indices.contains(target) else { return nil }
        return all[target]
    }
}
```

- [ ] **Step 5: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Content/RegionMap.swift`

```swift
import Foundation

public enum AirportRole: String, Codable, Sendable {
    case gym
    case eliteFour
    case champion
    case waypoint
}

public struct Airport: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let position: GridPoint
    public let gymID: GymID?
    public let role: AirportRole
}

public struct Airway: Codable, Equatable, Sendable {
    public let id: String
    public let from: String
    public let to: String
}

public struct RegionMap: Codable, Equatable, Sendable {
    public let airports: [Airport]
    public let airways: [Airway]
}
```

- [ ] **Step 6: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Content/Gym.swift`

```swift
import Foundation

public struct DialogueRefs: Codable, Equatable, Sendable {
    public let intro: String
    public let win: String
    public let lose: String
}

public struct Gym: Codable, Equatable, Sendable {
    public let id: GymID
    public let leaderName: String
    public let nameplateName: String
    public let leaderSpriteID: String
    public let badgeName: String
    public let questionCount: Int
    public let dialogue: DialogueRefs
}

public struct EliteMember: Codable, Equatable, Sendable {
    public let id: String
    public let order: Int
    public let name: String
    public let nameplateName: String
    public let spriteID: String
    public let categories: [Category]
    public let questionCount: Int
    public let dialogue: DialogueRefs
}

public struct ChampionSpec: Codable, Equatable, Sendable {
    public let name: String
    public let nameplateName: String
    public let spriteID: String
    public let dialogue: DialogueRefs
}
```

- [ ] **Step 7: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Content/DialogueScript.swift`

```swift
import Foundation

public struct DialogueScript: Codable, Equatable, Sendable {
    public let pages: [String]
}

public enum SystemDialogueKey: String, CaseIterable, Sendable {
    case welcome
    case gymLocked
    case victory
    case whiteout
    case retreat
    case championPinned
    case superEffective
    case criticalHit
    case revived
}
```

- [ ] **Step 8: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Content/DialogueTemplate.swift`

```swift
import Foundation

public enum DialogueTemplate {
    public static func filled(_ script: DialogueScript, with values: [String: String]) -> DialogueScript {
        DialogueScript(pages: script.pages.map { filled($0, with: values) })
    }

    private static func filled(_ page: String, with values: [String: String]) -> String {
        values.reduce(page) { partial, entry in
            partial.replacingOccurrences(of: "{\(entry.key)}", with: entry.value)
        }
    }
}
```

- [ ] **Step 9: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Content/Item.swift`

```swift
import Foundation

public enum ItemEffect: Codable, Equatable, Sendable {
    case heal(Int)
    case reviveOnce
    case repel(steps: Int)
    case directTo

    private enum CodingKeys: String, CodingKey {
        case kind
        case amount
        case steps
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(String.self, forKey: .kind)
        switch kind {
        case "heal":
            self = .heal(try container.decode(Int.self, forKey: .amount))
        case "reviveOnce":
            self = .reviveOnce
        case "repel":
            self = .repel(steps: try container.decode(Int.self, forKey: .steps))
        case "directTo":
            self = .directTo
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .kind, in: container, debugDescription: "unknown item effect kind \(kind)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .heal(let amount):
            try container.encode("heal", forKey: .kind)
            try container.encode(amount, forKey: .amount)
        case .reviveOnce:
            try container.encode("reviveOnce", forKey: .kind)
        case .repel(let steps):
            try container.encode("repel", forKey: .kind)
            try container.encode(steps, forKey: .steps)
        case .directTo:
            try container.encode("directTo", forKey: .kind)
        }
    }
}

public struct Item: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let spriteID: String
    public let effect: ItemEffect
}
```

- [ ] **Step 10: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Content/AdventureContent.swift`

```swift
import Foundation

public enum AdventureContentError: Error, Equatable, Sendable {
    case resourceMissing
    case duplicateID(String)
    case gymOrderMismatch
    case unknownReference(from: String, to: String)
    case emptyDialogue(String)
    case dialoguePageTooLong(String)
    case nameplateTooLong(String)
    case unknownSprite(String)
    case notEnoughQuestions(gymID: String)
    case offMap(String)
    case unknownTile(x: Int, y: Int)
    case raggedRows
    case unreachableDoor(airportID: String)
}

public struct TileMap: Codable, Equatable, Sendable {}

public struct Trainer: Codable, Equatable, Sendable {
    public let id: String
}

public struct RivalSpec: Codable, Equatable, Sendable {}

public struct CompanionSpecies: Codable, Equatable, Sendable {}

public struct AdventureContent: Codable, Sendable {
    public let version: Int
    public let region: RegionMap
    public let gyms: [Gym]
    public let eliteFour: [EliteMember]
    public let champion: ChampionSpec
    public let dialogue: [String: DialogueScript]
    public let system: [String: DialogueScript]
    public let items: [Item]
    public let tileMap: TileMap?
    public let trainers: [Trainer]
    public let rival: RivalSpec?
    public let companions: [CompanionSpecies]

    public init(
        version: Int, region: RegionMap, gyms: [Gym], eliteFour: [EliteMember], champion: ChampionSpec,
        dialogue: [String: DialogueScript], system: [String: DialogueScript], items: [Item],
        tileMap: TileMap? = nil, trainers: [Trainer] = [], rival: RivalSpec? = nil,
        companions: [CompanionSpecies] = []
    ) {
        self.version = version
        self.region = region
        self.gyms = gyms
        self.eliteFour = eliteFour
        self.champion = champion
        self.dialogue = dialogue
        self.system = system
        self.items = items
        self.tileMap = tileMap
        self.trainers = trainers
        self.rival = rival
        self.companions = companions
    }

    private enum CodingKeys: String, CodingKey {
        case version, region, gyms, eliteFour, champion, dialogue, system, items
        case tileMap, trainers, rival, companions
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        region = try container.decode(RegionMap.self, forKey: .region)
        gyms = try container.decode([Gym].self, forKey: .gyms)
        eliteFour = try container.decodeIfPresent([EliteMember].self, forKey: .eliteFour) ?? []
        champion = try container.decode(ChampionSpec.self, forKey: .champion)
        dialogue = try container.decodeIfPresent([String: DialogueScript].self, forKey: .dialogue) ?? [:]
        system = try container.decodeIfPresent([String: DialogueScript].self, forKey: .system) ?? [:]
        items = try container.decodeIfPresent([Item].self, forKey: .items) ?? []
        tileMap = try container.decodeIfPresent(TileMap.self, forKey: .tileMap)
        trainers = try container.decodeIfPresent([Trainer].self, forKey: .trainers) ?? []
        rival = try container.decodeIfPresent(RivalSpec.self, forKey: .rival)
        companions = try container.decodeIfPresent([CompanionSpecies].self, forKey: .companions) ?? []
    }

    public static func load() throws -> AdventureContent {
        guard let url = Bundle.module.url(forResource: "adventure-v1", withExtension: "json") else {
            throw AdventureContentError.resourceMissing
        }
        let content = try JSONDecoder().decode(AdventureContent.self, from: Data(contentsOf: url))
        try content.validate()
        return content
    }

    public func systemLine(_ key: SystemDialogueKey, filling values: [String: String] = [:]) -> DialogueScript {
        DialogueTemplate.filled(system[key.rawValue] ?? DialogueScript(pages: []), with: values)
    }

    public func validate() throws {
        try checkUniqueIDs()
    }

    private func checkUniqueIDs() throws {
        let ids = region.airports.map(\.id)
            + gyms.map(\.id.rawValue)
            + eliteFour.map(\.id)
            + items.map(\.id)
            + trainers.map(\.id)
        var seen = Set<String>()
        for id in ids {
            guard seen.insert(id).inserted else { throw AdventureContentError.duplicateID(id) }
        }
    }
}
```

- [ ] **Step 11: Write the implementation**

File: `IFRCore/Sources/IFRCore/Resources/adventure-v1.json`

```json
{
  "version": 1,
  "region": {
    "airports": [
      {"id": "KHYP", "name": "Hypoxia Field", "position": {"x": 3, "y": 12}, "gymID": "humanFactors", "role": "gym"},
      {"id": "KGYR", "name": "Gyro Municipal", "position": {"x": 7, "y": 10}, "gymID": "instrumentsAndSystems", "role": "gym"},
      {"id": "KREG", "name": "Marshal Field", "position": {"x": 11, "y": 8}, "gymID": "regulations", "role": "gym"},
      {"id": "KVIC", "name": "Victor Intl", "position": {"x": 15, "y": 6}, "gymID": "navigation", "role": "gym"},
      {"id": "KPLT", "name": "Plotter County", "position": {"x": 19, "y": 4}, "gymID": "chartsAndPlanning", "role": "gym"},
      {"id": "KNIM", "name": "Nimbus Regional", "position": {"x": 21, "y": 8}, "gymID": "weather", "role": "gym"},
      {"id": "KMAY", "name": "Mayday Field", "position": {"x": 17, "y": 11}, "gymID": "emergencies", "role": "gym"},
      {"id": "KILS", "name": "Ilsa Approach", "position": {"x": 13, "y": 12}, "gymID": "approaches", "role": "gym"},
      {"id": "KELF", "name": "Four Corners Field", "position": {"x": 26, "y": 2}, "gymID": null, "role": "eliteFour"},
      {"id": "KCHP", "name": "Examiner's Office", "position": {"x": 28, "y": 6}, "gymID": null, "role": "champion"}
    ],
    "airways": [
      {"id": "V1", "from": "KHYP", "to": "KGYR"},
      {"id": "V2", "from": "KGYR", "to": "KREG"},
      {"id": "V3", "from": "KREG", "to": "KVIC"},
      {"id": "V4", "from": "KVIC", "to": "KPLT"},
      {"id": "V5", "from": "KPLT", "to": "KNIM"},
      {"id": "V6", "from": "KNIM", "to": "KMAY"},
      {"id": "V7", "from": "KMAY", "to": "KILS"},
      {"id": "V8", "from": "KPLT", "to": "KELF"},
      {"id": "V9", "from": "KELF", "to": "KCHP"}
    ]
  },
  "gyms": [
    {"id": "humanFactors", "leaderName": "Dr. Hypoxia", "nameplateName": "HYPOXIA", "leaderSpriteID": "leader-hypoxia",
     "badgeName": "Oxygen Badge", "questionCount": 10,
     "dialogue": {"intro": "hypoxia-intro", "win": "hypoxia-win", "lose": "hypoxia-lose"}},
    {"id": "instrumentsAndSystems", "leaderName": "Gyro", "nameplateName": "GYRO", "leaderSpriteID": "leader-gyro",
     "badgeName": "Gyro Badge", "questionCount": 10,
     "dialogue": {"intro": "gyro-intro", "win": "gyro-win", "lose": "gyro-lose"}},
    {"id": "regulations", "leaderName": "Marshal Reg", "nameplateName": "REG", "leaderSpriteID": "leader-reg",
     "badgeName": "Regulations Badge", "questionCount": 10,
     "dialogue": {"intro": "reg-intro", "win": "reg-win", "lose": "reg-lose"}},
    {"id": "navigation", "leaderName": "Victor", "nameplateName": "VICTOR", "leaderSpriteID": "leader-victor",
     "badgeName": "Navigation Badge", "questionCount": 10,
     "dialogue": {"intro": "victor-intro", "win": "victor-win", "lose": "victor-lose"}},
    {"id": "chartsAndPlanning", "leaderName": "Plotter", "nameplateName": "PLOTTER", "leaderSpriteID": "leader-plotter",
     "badgeName": "Charts Badge", "questionCount": 10,
     "dialogue": {"intro": "plotter-intro", "win": "plotter-win", "lose": "plotter-lose"}},
    {"id": "weather", "leaderName": "Nimbus", "nameplateName": "NIMBUS", "leaderSpriteID": "leader-nimbus",
     "badgeName": "Weather Badge", "questionCount": 10,
     "dialogue": {"intro": "nimbus-intro", "win": "nimbus-win", "lose": "nimbus-lose"}},
    {"id": "emergencies", "leaderName": "Mayday", "nameplateName": "MAYDAY", "leaderSpriteID": "leader-mayday",
     "badgeName": "Emergency Badge", "questionCount": 10,
     "dialogue": {"intro": "mayday-intro", "win": "mayday-win", "lose": "mayday-lose"}},
    {"id": "approaches", "leaderName": "Ilsa", "nameplateName": "ILSA", "leaderSpriteID": "leader-ilsa",
     "badgeName": "Approach Badge", "questionCount": 10,
     "dialogue": {"intro": "ilsa-intro", "win": "ilsa-win", "lose": "ilsa-lose"}}
  ],
  "eliteFour": [
    {"id": "elite-sierra", "order": 1, "name": "Controller Sierra", "nameplateName": "SIERRA", "spriteID": "elite-sierra",
     "questionCount": 12, "categories": ["regulations", "emergencies"],
     "dialogue": {"intro": "sierra-intro", "win": "sierra-win", "lose": "sierra-lose"}},
    {"id": "elite-tango", "order": 2, "name": "Briefer Tango", "nameplateName": "TANGO", "spriteID": "elite-tango",
     "questionCount": 12, "categories": ["weather", "chartsAndPlanning"],
     "dialogue": {"intro": "tango-intro", "win": "tango-win", "lose": "tango-lose"}},
    {"id": "elite-uniform", "order": 3, "name": "Examiner Uniform", "nameplateName": "UNIFORM", "spriteID": "elite-uniform",
     "questionCount": 12, "categories": ["navigation", "instrumentsAndSystems"],
     "dialogue": {"intro": "uniform-intro", "win": "uniform-win", "lose": "uniform-lose"}},
    {"id": "elite-whiskey", "order": 4, "name": "Captain Whiskey", "nameplateName": "WHISKEY", "spriteID": "elite-whiskey",
     "questionCount": 12, "categories": ["approaches", "humanFactors"],
     "dialogue": {"intro": "whiskey-intro", "win": "whiskey-win", "lose": "whiskey-lose"}}
  ],
  "champion": {"name": "The DPE", "nameplateName": "THE DPE", "spriteID": "champion",
               "dialogue": {"intro": "champion-intro", "win": "champion-win", "lose": "champion-lose"}},
  "dialogue": {
    "hypoxia-intro": {"pages": ["So you want to fly in the clouds? Prove you can think up there.", "Above 12,500 feet your brain runs short of oxygen. Has yours?"]},
    "hypoxia-win": {"pages": ["Your time of useful consciousness is impressive. Take the OXYGEN BADGE."]},
    "hypoxia-lose": {"pages": ["Cyanosis, euphoria, poor judgment. Go breathe and come back."]},
    "gyro-intro": {"pages": ["Spin, precess, tumble. My instruments never lie. Do yours?"]},
    "gyro-win": {"pages": ["Attitude, heading, turn. Take the GYRO BADGE."]},
    "gyro-lose": {"pages": ["Your vacuum pump just failed. Partial panel, pilot."]},
    "reg-intro": {"pages": ["Know the rules before you break the clouds. Recite them."]},
    "reg-win": {"pages": ["Clean logbook, clean checkride. Take the REGULATIONS BADGE."]},
    "reg-lose": {"pages": ["That is a violation waiting to happen. Study the FARs."]},
    "victor-intro": {"pages": ["Find your way from VOR to VOR, pilot. No shortcuts."]},
    "victor-win": {"pages": ["Right on course. Take the NAVIGATION BADGE."]},
    "victor-lose": {"pages": ["You are off the airway. Recompute and try again."]},
    "plotter-intro": {"pages": ["A good plan beats a good save every time."]},
    "plotter-win": {"pages": ["Fuel, weight, alternates all checked. Take the CHARTS BADGE."]},
    "plotter-lose": {"pages": ["Your flight plan would never have made it off the ground."]},
    "nimbus-intro": {"pages": ["Read the sky before it reads you."]},
    "nimbus-win": {"pages": ["You saw the front coming. Take the WEATHER BADGE."]},
    "nimbus-lose": {"pages": ["That cell was closer than you thought."]},
    "mayday-intro": {"pages": ["Engine out, lost comm, fire aboard. Stay calm and fly the plane."]},
    "mayday-win": {"pages": ["Textbook emergency handling. Take the EMERGENCY BADGE."]},
    "mayday-lose": {"pages": ["You froze at the worst moment. Drill it again."]},
    "ilsa-intro": {"pages": ["Down to minimums, needles alive. Show me a stable approach."]},
    "ilsa-win": {"pages": ["Right down the centerline. Take the APPROACH BADGE."]},
    "ilsa-lose": {"pages": ["You busted the missed approach point. Go around."]},
    "sierra-intro": {"pages": ["Regulations and emergencies together. Let's see your judgment."]},
    "sierra-win": {"pages": ["Solid judgment under pressure. Onward."]},
    "sierra-lose": {"pages": ["Judgment failed you there. Come back sharper."]},
    "tango-intro": {"pages": ["Weather and planning decide the flight before you start the engine."]},
    "tango-win": {"pages": ["You planned around every hazard. Onward."]},
    "tango-lose": {"pages": ["That plan would have flown you into the weather."]},
    "uniform-intro": {"pages": ["Navigate on instruments alone. No excuses."]},
    "uniform-win": {"pages": ["Needles pinned the whole way. Onward."]},
    "uniform-lose": {"pages": ["You lost situational awareness. Reset and rebrief."]},
    "whiskey-intro": {"pages": ["Approaches and human limits. The exam's last mile."]},
    "whiskey-win": {"pages": ["You held it together to minimums. The circuit is yours."]},
    "whiskey-lose": {"pages": ["Fatigue beat you today. Rest and return."]},
    "champion-intro": {"pages": ["We finish the exam, pilot. Every question counts."]},
    "champion-win": {"pages": ["Congratulations. You are the Region Champion."]},
    "champion-lose": {"pages": ["Close, but the DPE does not round up. Study on."]}
  },
  "system": {
    "welcome": {"pages": ["Welcome to the Victor region. {leader} is waiting at {airport}."]},
    "gymLocked": {"pages": ["You need the {badge} first."]},
    "victory": {"pages": ["{opponent} was defeated!"]},
    "whiteout": {"pages": ["You whited out... Your misses come back sooner."]},
    "retreat": {"pages": ["Out of questions. You retreat to the FBO."]},
    "championPinned": {"pages": ["We finish the exam, pilot. Every question counts."]},
    "superEffective": {"pages": ["It's super effective!"]},
    "criticalHit": {"pages": ["A critical hit!"]},
    "revived": {"pages": ["The oxygen mask brings you back!"]}
  },
  "items": [
    {"id": "potion", "name": "Potion", "spriteID": "item-potion", "effect": {"kind": "heal", "amount": 30}},
    {"id": "oxygen-mask", "name": "Oxygen Mask", "spriteID": "item-mask", "effect": {"kind": "reviveOnce"}},
    {"id": "vfr-window", "name": "VFR Window", "spriteID": "item-window", "effect": {"kind": "repel", "steps": 50}},
    {"id": "direct-to", "name": "Direct-To", "spriteID": "item-direct", "effect": {"kind": "directTo"}}
  ]
}
```

- [ ] **Step 12: Modify Package.swift**

File: `IFRCore/Package.swift`

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "IFRCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "IFRCore", targets: ["IFRCore"])],
    targets: [
        .target(
            name: "IFRCore",
            resources: [.copy("Resources/bank-v1.json"), .copy("Resources/adventure-v1.json")]
        ),
        .testTarget(name: "IFRCoreTests", dependencies: ["IFRCore"]),
    ]
)
```

- [ ] **Step 13: Run all core tests**

Run: `scripts/test-core.sh`
Expected: `Executed 84 tests, with 0 failures (0 unexpected) in 0.052 (0.052) seconds`

- [ ] **Step 14: Commit**

Run: `git add IFRCore/Sources/IFRCore/Adventure/Circuit IFRCore/Sources/IFRCore/Adventure/Content IFRCore/Sources/IFRCore/Resources/adventure-v1.json IFRCore/Package.swift IFRCore/Tests/IFRCoreTests/GymIDTests.swift IFRCore/Tests/IFRCoreTests/AdventureContentTests.swift && git commit -m "M1-08a: Content model, decoding and JSON"`

---

### Task M1-08b: Content validation

**Files:**
- Create: `IFRCore/Sources/IFRCore/Adventure/Content/AdventureContentValidation.swift`
- Create: `IFRCore/Sources/IFRCore/Adventure/Content/AdventureContentDialogueValidation.swift`
- Modify: `IFRCore/Sources/IFRCore/Adventure/Content/AdventureContent.swift`
- Modify: `IFRCore/Sources/IFRCore/Resources/adventure-v1.json`
- Test: `IFRCore/Tests/IFRCoreTests/AdventureContentTests.swift`

**Interfaces:**
- Consumes: `AdventureContent`, `AdventureContentError`, `Gym`, `EliteMember`, `ChampionSpec`, `DialogueRefs` (`Adventure/Content/AdventureContent.swift`, `Gym.swift`), `RegionMap`, `Airport`, `Airway`, `AirportRole` (`RegionMap.swift`), `GymID` (`Adventure/Circuit/GymID.swift`), `DialogueScript`, `SystemDialogueKey` (`DialogueScript.swift`), `Typewriter.paginate` (`Adventure/Pixel/Typewriter.swift`), `SpriteCatalog.sprite(named:)` (`Adventure/Pixel/SpriteCatalog.swift`), `QuestionBank.load()` / `questions(in:)` and `Question.isMultipleChoiceCapable` (`Models/QuestionBank.swift`, `Models/Question.swift`), `IFRCore.Category`.
- Produces: `AdventureContent.validate() throws` now runs the full fixed-order check list (`checkUniqueIDs`, `checkGymOrder`, `checkReferences`, `checkRegionConnectivity`, `checkAirportPositions`, `checkDialogueReferences`, `checkDialoguePageLengths`, `checkSystemDialogueKeys`, `checkSystemDialogueSubstitution`, `checkNameplateLengths`, `checkEliteFourCoverage`, `checkGymQuestionPools`, `checkSpriteReferences`); `AdventureContent.opponentNames() -> [String]` (internal helper used by the substitution check). Every later task that calls `AdventureContent.load()` now gets these guarantees enforced on every run.

- [ ] **Step 1: Write the failing tests**

File: `IFRCore/Tests/IFRCoreTests/AdventureContentTests.swift`

```swift
import XCTest
@testable import IFRCore

final class AdventureContentTests: XCTestCase {
    private func makeAirport(
        id: String = "KHYP", name: String = "Hypoxia Field", position: GridPoint = GridPoint(x: 3, y: 12),
        gymID: GymID? = .humanFactors, role: AirportRole = .gym
    ) -> Airport {
        Airport(id: id, name: name, position: position, gymID: gymID, role: role)
    }

    private func makeEliteMember(
        id: String = "elite-sierra", order: Int = 1, name: String = "Controller Sierra",
        nameplateName: String = "SIERRA", spriteID: String = "elite-sierra",
        categories: [IFRCore.Category] = [.regulations], questionCount: Int = 12,
        dialogue: DialogueRefs = DialogueRefs(intro: "sierra-intro", win: "sierra-win", lose: "sierra-lose")
    ) -> EliteMember {
        EliteMember(id: id, order: order, name: name, nameplateName: nameplateName, spriteID: spriteID,
                    categories: categories, questionCount: questionCount, dialogue: dialogue)
    }

    private func makeContent(
        airports: [Airport] = [], airways: [Airway] = [], gyms: [Gym] = [], eliteFour: [EliteMember] = [],
        items: [Item] = [], trainers: [Trainer] = []
    ) -> AdventureContent {
        AdventureContent(
            version: 1, region: RegionMap(airports: airports, airways: airways), gyms: gyms, eliteFour: eliteFour,
            champion: ChampionSpec(
                name: "The DPE", nameplateName: "THE DPE", spriteID: "champion",
                dialogue: DialogueRefs(intro: "champion-intro", win: "champion-win", lose: "champion-lose")
            ),
            dialogue: [:], system: [:], items: items, trainers: trainers
        )
    }

    func testBundledAdventureContentLoadsAndValidates() throws {
        let content = try AdventureContent.load()
        XCTAssertFalse(content.gyms.isEmpty)
        XCTAssertEqual(Set(content.gyms.map(\.id)).count, content.gyms.count)
    }

    func testDecodesGymFromJSONFragment() throws {
        let json = """
        {"id": "humanFactors", "leaderName": "Dr. Hypoxia", "nameplateName": "HYPOXIA",
         "leaderSpriteID": "leader-hypoxia", "badgeName": "Oxygen Badge", "questionCount": 10,
         "dialogue": {"intro": "hypoxia-intro", "win": "hypoxia-win", "lose": "hypoxia-lose"}}
        """.data(using: .utf8)!
        let gym = try JSONDecoder().decode(Gym.self, from: json)
        XCTAssertEqual(gym.id, .humanFactors)
        XCTAssertEqual(gym.leaderName, "Dr. Hypoxia")
        XCTAssertEqual(gym.nameplateName, "HYPOXIA")
        XCTAssertEqual(gym.questionCount, 10)
        XCTAssertEqual(gym.dialogue.win, "hypoxia-win")
    }

    func testMissingOptionalSectionsDecodeAsEmpty() throws {
        let json = """
        {"version": 1,
         "region": {"airports": [], "airways": []},
         "gyms": [],
         "champion": {"name": "The DPE", "nameplateName": "THE DPE", "spriteID": "champion",
                      "dialogue": {"intro": "champion-intro", "win": "champion-win", "lose": "champion-lose"}}}
        """.data(using: .utf8)!
        let content = try JSONDecoder().decode(AdventureContent.self, from: json)
        XCTAssertNil(content.tileMap)
        XCTAssertTrue(content.trainers.isEmpty)
        XCTAssertNil(content.rival)
        XCTAssertTrue(content.companions.isEmpty)
        XCTAssertTrue(content.eliteFour.isEmpty)
        XCTAssertTrue(content.dialogue.isEmpty)
        XCTAssertTrue(content.system.isEmpty)
        XCTAssertTrue(content.items.isEmpty)
    }

    func testUnknownItemEffectKindFailsDecoding() {
        let json = #"{"kind": "instantMastery"}"#.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(ItemEffect.self, from: json))
    }

    func testItemEffectCasesAreOnlyHealReviveRepelDirectTo() throws {
        let heal = try JSONDecoder().decode(ItemEffect.self, from: #"{"kind": "heal", "amount": 30}"#.data(using: .utf8)!)
        let revive = try JSONDecoder().decode(ItemEffect.self, from: #"{"kind": "reviveOnce"}"#.data(using: .utf8)!)
        let repel = try JSONDecoder().decode(ItemEffect.self, from: #"{"kind": "repel", "steps": 50}"#.data(using: .utf8)!)
        let directTo = try JSONDecoder().decode(ItemEffect.self, from: #"{"kind": "directTo"}"#.data(using: .utf8)!)
        XCTAssertEqual(heal, .heal(30))
        XCTAssertEqual(revive, .reviveOnce)
        XCTAssertEqual(repel, .repel(steps: 50))
        XCTAssertEqual(directTo, .directTo)
    }

    func testDialogueTemplateFillsPlaceholders() {
        let script = DialogueScript(pages: [
            "Welcome, {leader}! Fly to {airport} to earn the {badge}. Beat {opponent}. {unknown}",
        ])
        let filled = DialogueTemplate.filled(script, with: [
            "leader": "Gyro", "airport": "KGYR", "badge": "Gyro Badge", "opponent": "Gyro",
        ])
        XCTAssertEqual(
            filled.pages.first,
            "Welcome, Gyro! Fly to KGYR to earn the Gyro Badge. Beat Gyro. {unknown}"
        )
    }

    func testDuplicateIDsAcrossAirportsGymsEliteItemsTrainersRejected() {
        let content = makeContent(
            airports: [makeAirport(id: "shared-id")],
            eliteFour: [makeEliteMember(id: "shared-id")]
        )
        XCTAssertThrowsError(try content.validate()) {
            XCTAssertEqual($0 as? AdventureContentError, .duplicateID("shared-id"))
        }
    }

    private func loadedContent() throws -> AdventureContent {
        try AdventureContent.load()
    }

    private func replacingGyms(_ content: AdventureContent, with gyms: [Gym]) -> AdventureContent {
        AdventureContent(
            version: content.version, region: content.region, gyms: gyms, eliteFour: content.eliteFour,
            champion: content.champion, dialogue: content.dialogue, system: content.system, items: content.items,
            tileMap: content.tileMap, trainers: content.trainers, rival: content.rival, companions: content.companions
        )
    }

    private func replacingRegion(_ content: AdventureContent, with region: RegionMap) -> AdventureContent {
        AdventureContent(
            version: content.version, region: region, gyms: content.gyms, eliteFour: content.eliteFour,
            champion: content.champion, dialogue: content.dialogue, system: content.system, items: content.items,
            tileMap: content.tileMap, trainers: content.trainers, rival: content.rival, companions: content.companions
        )
    }

    private func replacingDialogue(_ content: AdventureContent, with dialogue: [String: DialogueScript]) -> AdventureContent {
        AdventureContent(
            version: content.version, region: content.region, gyms: content.gyms, eliteFour: content.eliteFour,
            champion: content.champion, dialogue: dialogue, system: content.system, items: content.items,
            tileMap: content.tileMap, trainers: content.trainers, rival: content.rival, companions: content.companions
        )
    }

    private func replacingSystem(_ content: AdventureContent, with system: [String: DialogueScript]) -> AdventureContent {
        AdventureContent(
            version: content.version, region: content.region, gyms: content.gyms, eliteFour: content.eliteFour,
            champion: content.champion, dialogue: content.dialogue, system: system, items: content.items,
            tileMap: content.tileMap, trainers: content.trainers, rival: content.rival, companions: content.companions
        )
    }

    private func replacingEliteFour(_ content: AdventureContent, with eliteFour: [EliteMember]) -> AdventureContent {
        AdventureContent(
            version: content.version, region: content.region, gyms: content.gyms, eliteFour: eliteFour,
            champion: content.champion, dialogue: content.dialogue, system: content.system, items: content.items,
            tileMap: content.tileMap, trainers: content.trainers, rival: content.rival, companions: content.companions
        )
    }

    private func replacingGym(_ content: AdventureContent, id: GymID, transform: (Gym) -> Gym) -> AdventureContent {
        replacingGyms(content, with: content.gyms.map { $0.id == id ? transform($0) : $0 })
    }

    func testGymsAppearInCircuitOrder() throws {
        var gyms = try loadedContent().gyms
        gyms.swapAt(0, 1)
        let content = replacingGyms(try loadedContent(), with: gyms)
        XCTAssertThrowsError(try content.validate()) {
            XCTAssertEqual($0 as? AdventureContentError, .gymOrderMismatch)
        }
    }

    func testEveryAirportGymIDAndAirwayEndpointResolves() throws {
        let base = try loadedContent()
        var airways = base.region.airways
        airways[0] = Airway(id: airways[0].id, from: airways[0].from, to: "ZZZZ")
        let region = RegionMap(airports: base.region.airports, airways: airways)
        let content = replacingRegion(base, with: region)
        XCTAssertThrowsError(try content.validate()) {
            XCTAssertEqual($0 as? AdventureContentError, .unknownReference(from: airways[0].id, to: "ZZZZ"))
        }
    }

    func testRegionIsConnectedFromFirstGym() throws {
        let base = try loadedContent()
        let airways = base.region.airways.filter { $0.id != "V7" }
        let region = RegionMap(airports: base.region.airports, airways: airways)
        let content = replacingRegion(base, with: region)
        XCTAssertThrowsError(try content.validate()) {
            XCTAssertEqual($0 as? AdventureContentError, .unreachableDoor(airportID: "KILS"))
        }
    }

    func testAirportPositionsFitTheRegionGrid() throws {
        let base = try loadedContent()
        let airports = base.region.airports.map { airport in
            airport.id == "KHYP"
                ? Airport(id: airport.id, name: airport.name, position: GridPoint(x: 30, y: airport.position.y),
                          gymID: airport.gymID, role: airport.role)
                : airport
        }
        let region = RegionMap(airports: airports, airways: base.region.airways)
        let content = replacingRegion(base, with: region)
        XCTAssertThrowsError(try content.validate()) {
            XCTAssertEqual($0 as? AdventureContentError, .offMap("KHYP"))
        }
    }

    func testEveryDialogueReferenceResolvesAndIsNonEmpty() throws {
        let base = try loadedContent()
        var dialogue = base.dialogue
        dialogue["hypoxia-intro"] = DialogueScript(pages: [])
        let content = replacingDialogue(base, with: dialogue)
        XCTAssertThrowsError(try content.validate()) {
            XCTAssertEqual($0 as? AdventureContentError, .emptyDialogue("hypoxia-intro"))
        }
    }

    func testDialoguePagesFitTwoRowsOfTwentyEightColumns() throws {
        let base = try loadedContent()
        var dialogue = base.dialogue
        let longPage = Array(repeating: "verylongword", count: 20).joined(separator: " ")
        dialogue["hypoxia-intro"] = DialogueScript(pages: [longPage])
        let content = replacingDialogue(base, with: dialogue)
        XCTAssertThrowsError(try content.validate()) {
            XCTAssertEqual($0 as? AdventureContentError, .dialoguePageTooLong("hypoxia-intro"))
        }
    }

    func testEverySystemDialogueKeyIsAuthored() throws {
        let base = try loadedContent()
        var system = base.system
        system.removeValue(forKey: "welcome")
        let content = replacingSystem(base, with: system)
        XCTAssertThrowsError(try content.validate()) {
            XCTAssertEqual($0 as? AdventureContentError, .unknownReference(from: "system", to: "welcome"))
        }
    }

    func testSystemDialogueFitsWithLongestSubstitution() throws {
        let base = try loadedContent()
        let content = replacingGym(base, id: .humanFactors) { gym in
            Gym(id: gym.id, leaderName: gym.leaderName,
                nameplateName: gym.nameplateName, leaderSpriteID: gym.leaderSpriteID,
                badgeName: "A Very Long Badge Name That Overflows The Dialogue Box By A Wide Margin",
                questionCount: gym.questionCount, dialogue: gym.dialogue)
        }
        XCTAssertThrowsError(try content.validate()) {
            XCTAssertEqual($0 as? AdventureContentError, .dialoguePageTooLong("gymLocked"))
        }
    }

    func testNameplateNamesAreAtMostSevenCharacters() throws {
        let base = try loadedContent()
        let content = replacingGym(base, id: .humanFactors) { gym in
            Gym(id: gym.id, leaderName: gym.leaderName, nameplateName: "TOOLONGNAME",
                leaderSpriteID: gym.leaderSpriteID, badgeName: gym.badgeName,
                questionCount: gym.questionCount, dialogue: gym.dialogue)
        }
        XCTAssertThrowsError(try content.validate()) {
            XCTAssertEqual($0 as? AdventureContentError, .nameplateTooLong("humanFactors"))
        }
    }

    func testEliteFourHasFourMembersCoveringAllCategoriesExactlyOnce() throws {
        let base = try loadedContent()
        var eliteFour = base.eliteFour
        eliteFour[0] = EliteMember(
            id: eliteFour[0].id, order: eliteFour[0].order, name: eliteFour[0].name,
            nameplateName: eliteFour[0].nameplateName, spriteID: eliteFour[0].spriteID,
            categories: [.regulations, .regulations], questionCount: eliteFour[0].questionCount,
            dialogue: eliteFour[0].dialogue
        )
        let content = replacingEliteFour(base, with: eliteFour)
        XCTAssertThrowsError(try content.validate()) {
            XCTAssertEqual($0 as? AdventureContentError, .duplicateID("regulations"))
        }
    }

    func testEveryGymCategoryHasEnoughMultipleChoiceQuestions() throws {
        let base = try loadedContent()
        let content = replacingGym(base, id: .humanFactors) { gym in
            Gym(id: gym.id, leaderName: gym.leaderName, nameplateName: gym.nameplateName,
                leaderSpriteID: gym.leaderSpriteID, badgeName: gym.badgeName,
                questionCount: 17, dialogue: gym.dialogue)
        }
        XCTAssertThrowsError(try content.validate()) {
            XCTAssertEqual($0 as? AdventureContentError, .notEnoughQuestions(gymID: "humanFactors"))
        }
    }

    func testEverySpriteIDResolvesInSpriteCatalog() throws {
        let base = try loadedContent()
        let content = replacingGym(base, id: .humanFactors) { gym in
            Gym(id: gym.id, leaderName: gym.leaderName, nameplateName: gym.nameplateName,
                leaderSpriteID: "nonexistent-sprite", badgeName: gym.badgeName,
                questionCount: gym.questionCount, dialogue: gym.dialogue)
        }
        XCTAssertThrowsError(try content.validate()) {
            XCTAssertEqual($0 as? AdventureContentError, .unknownSprite("nonexistent-sprite"))
        }
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `scripts/test-core.sh --filter AdventureContentTests`
Expected: with `validate()` still calling only `checkUniqueIDs()` (the M1-08a state), 12 of the 13 new tests fail with `XCTAssertThrowsError failed: did not throw error - `, e.g.:
```
AdventureContentTests.swift:166: error: ...testGymsAppearInCircuitOrder : XCTAssertThrowsError failed: did not throw error -
AdventureContentTests.swift:177: error: ...testEveryAirportGymIDAndAirwayEndpointResolves : XCTAssertThrowsError failed: did not throw error -
Executed 19 tests, with 12 failures (0 unexpected) in 0.012 (0.012) seconds
```

- [ ] **Step 3: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Content/AdventureContent.swift`

```swift
import Foundation

public enum AdventureContentError: Error, Equatable, Sendable {
    case resourceMissing
    case duplicateID(String)
    case gymOrderMismatch
    case unknownReference(from: String, to: String)
    case emptyDialogue(String)
    case dialoguePageTooLong(String)
    case nameplateTooLong(String)
    case unknownSprite(String)
    case notEnoughQuestions(gymID: String)
    case offMap(String)
    case unknownTile(x: Int, y: Int)
    case raggedRows
    case unreachableDoor(airportID: String)
}

public struct TileMap: Codable, Equatable, Sendable {}

public struct Trainer: Codable, Equatable, Sendable {
    public let id: String
}

public struct RivalSpec: Codable, Equatable, Sendable {}

public struct CompanionSpecies: Codable, Equatable, Sendable {}

public struct AdventureContent: Codable, Sendable {
    public let version: Int
    public let region: RegionMap
    public let gyms: [Gym]
    public let eliteFour: [EliteMember]
    public let champion: ChampionSpec
    public let dialogue: [String: DialogueScript]
    public let system: [String: DialogueScript]
    public let items: [Item]
    public let tileMap: TileMap?
    public let trainers: [Trainer]
    public let rival: RivalSpec?
    public let companions: [CompanionSpecies]

    public init(
        version: Int, region: RegionMap, gyms: [Gym], eliteFour: [EliteMember], champion: ChampionSpec,
        dialogue: [String: DialogueScript], system: [String: DialogueScript], items: [Item],
        tileMap: TileMap? = nil, trainers: [Trainer] = [], rival: RivalSpec? = nil,
        companions: [CompanionSpecies] = []
    ) {
        self.version = version
        self.region = region
        self.gyms = gyms
        self.eliteFour = eliteFour
        self.champion = champion
        self.dialogue = dialogue
        self.system = system
        self.items = items
        self.tileMap = tileMap
        self.trainers = trainers
        self.rival = rival
        self.companions = companions
    }

    private enum CodingKeys: String, CodingKey {
        case version, region, gyms, eliteFour, champion, dialogue, system, items
        case tileMap, trainers, rival, companions
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        region = try container.decode(RegionMap.self, forKey: .region)
        gyms = try container.decode([Gym].self, forKey: .gyms)
        eliteFour = try container.decodeIfPresent([EliteMember].self, forKey: .eliteFour) ?? []
        champion = try container.decode(ChampionSpec.self, forKey: .champion)
        dialogue = try container.decodeIfPresent([String: DialogueScript].self, forKey: .dialogue) ?? [:]
        system = try container.decodeIfPresent([String: DialogueScript].self, forKey: .system) ?? [:]
        items = try container.decodeIfPresent([Item].self, forKey: .items) ?? []
        tileMap = try container.decodeIfPresent(TileMap.self, forKey: .tileMap)
        trainers = try container.decodeIfPresent([Trainer].self, forKey: .trainers) ?? []
        rival = try container.decodeIfPresent(RivalSpec.self, forKey: .rival)
        companions = try container.decodeIfPresent([CompanionSpecies].self, forKey: .companions) ?? []
    }

    public static func load() throws -> AdventureContent {
        guard let url = Bundle.module.url(forResource: "adventure-v1", withExtension: "json") else {
            throw AdventureContentError.resourceMissing
        }
        let content = try JSONDecoder().decode(AdventureContent.self, from: Data(contentsOf: url))
        try content.validate()
        return content
    }

    public func systemLine(_ key: SystemDialogueKey, filling values: [String: String] = [:]) -> DialogueScript {
        DialogueTemplate.filled(system[key.rawValue] ?? DialogueScript(pages: []), with: values)
    }

    func opponentNames() -> [String] {
        gyms.map(\.leaderName) + eliteFour.map(\.name) + [champion.name]
    }
}
```

- [ ] **Step 4: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Content/AdventureContentValidation.swift`

```swift
import Foundation

extension AdventureContent {
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
    }

    private func checkUniqueIDs() throws {
        let ids = region.airports.map(\.id)
            + gyms.map(\.id.rawValue)
            + eliteFour.map(\.id)
            + items.map(\.id)
            + trainers.map(\.id)
        var seen = Set<String>()
        for id in ids {
            guard seen.insert(id).inserted else { throw AdventureContentError.duplicateID(id) }
        }
    }

    private func checkGymOrder() throws {
        let circuitIndices = gyms.map { GymID.allCases.firstIndex(of: $0.id) ?? -1 }
        guard circuitIndices == circuitIndices.sorted() else {
            throw AdventureContentError.gymOrderMismatch
        }
    }

    private func checkReferences() throws {
        let gymIDs = Set(gyms.map(\.id))
        let airportIDs = Set(region.airports.map(\.id))
        for airport in region.airports {
            if let gymID = airport.gymID, !gymIDs.contains(gymID) {
                throw AdventureContentError.unknownReference(from: airport.id, to: gymID.rawValue)
            }
        }
        for airway in region.airways {
            if !airportIDs.contains(airway.from) {
                throw AdventureContentError.unknownReference(from: airway.id, to: airway.from)
            }
            if !airportIDs.contains(airway.to) {
                throw AdventureContentError.unknownReference(from: airway.id, to: airway.to)
            }
        }
    }

    private func checkRegionConnectivity() throws {
        guard let firstGymID = gyms.first?.id,
              let start = region.airports.first(where: { $0.gymID == firstGymID })?.id
        else { return }
        var adjacency: [String: [String]] = [:]
        for airway in region.airways {
            adjacency[airway.from, default: []].append(airway.to)
            adjacency[airway.to, default: []].append(airway.from)
        }
        var reached: Set<String> = [start]
        var queue = [start]
        while let current = queue.first {
            queue.removeFirst()
            for neighbour in adjacency[current, default: []] where reached.insert(neighbour).inserted {
                queue.append(neighbour)
            }
        }
        for airport in region.airports where !reached.contains(airport.id) {
            throw AdventureContentError.unreachableDoor(airportID: airport.id)
        }
    }

    private func checkAirportPositions() throws {
        for airport in region.airports where airport.position.x >= 30 || airport.position.y >= 14 {
            throw AdventureContentError.offMap(airport.id)
        }
    }
}
```

- [ ] **Step 5: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Content/AdventureContentDialogueValidation.swift`

```swift
import Foundation

extension AdventureContent {
    func checkDialogueReferences() throws {
        var owners: [(String, DialogueRefs)] = gyms.map { ($0.id.rawValue, $0.dialogue) }
        owners += eliteFour.map { ($0.id, $0.dialogue) }
        owners.append((champion.name, champion.dialogue))
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

    func checkDialoguePageLengths() throws {
        for (key, script) in dialogue {
            for page in script.pages where Typewriter.paginate(page).count != 1 {
                throw AdventureContentError.dialoguePageTooLong(key)
            }
        }
    }

    func checkSystemDialogueKeys() throws {
        for key in SystemDialogueKey.allCases where system[key.rawValue] == nil {
            throw AdventureContentError.unknownReference(from: "system", to: key.rawValue)
        }
    }

    func checkSystemDialogueSubstitution() throws {
        let values = longestSubstitutionValues()
        for key in SystemDialogueKey.allCases {
            let filled = systemLine(key, filling: values)
            for page in filled.pages where Typewriter.paginate(page).count != 1 {
                throw AdventureContentError.dialoguePageTooLong(key.rawValue)
            }
        }
    }

    private func longestSubstitutionValues() -> [String: String] {
        [
            "badge": gyms.map(\.badgeName).max(by: { $0.count < $1.count }) ?? "",
            "leader": gyms.map(\.leaderName).max(by: { $0.count < $1.count }) ?? "",
            "airport": region.airports.map(\.id).max(by: { $0.count < $1.count }) ?? "",
            "opponent": opponentNames().max(by: { $0.count < $1.count }) ?? "",
        ]
    }

    func checkNameplateLengths() throws {
        var plates: [(String, String)] = gyms.map { ($0.id.rawValue, $0.nameplateName) }
        plates += eliteFour.map { ($0.id, $0.nameplateName) }
        plates.append((champion.name, champion.nameplateName))
        for (owner, nameplate) in plates where nameplate.count > 7 {
            throw AdventureContentError.nameplateTooLong(owner)
        }
    }

    func checkEliteFourCoverage() throws {
        var seen: Set<Category> = []
        for member in eliteFour {
            for category in member.categories {
                guard seen.insert(category).inserted else {
                    throw AdventureContentError.duplicateID(category.rawValue)
                }
            }
        }
        for category in Category.allCases where !seen.contains(category) {
            throw AdventureContentError.unknownReference(from: "eliteFour", to: category.rawValue)
        }
    }

    func checkGymQuestionPools() throws {
        let bank = try QuestionBank.load()
        for gym in gyms {
            let pool = bank.questions(in: gym.id.category).filter(\.isMultipleChoiceCapable)
            guard pool.count >= gym.questionCount else {
                throw AdventureContentError.notEnoughQuestions(gymID: gym.id.rawValue)
            }
        }
    }

    func checkSpriteReferences() throws {
        var sprites: [String] = gyms.map(\.leaderSpriteID) + eliteFour.map(\.spriteID)
        sprites.append(champion.spriteID)
        for spriteID in sprites where SpriteCatalog.sprite(named: spriteID) == nil {
            throw AdventureContentError.unknownSprite(spriteID)
        }
    }
}
```

- [ ] **Step 6: Modify the content resource so it satisfies its own new rules**

File: `IFRCore/Sources/IFRCore/Resources/adventure-v1.json`

The bundled dialogue and system pages were authored before pagination was enforced; several exceeded 28 columns by 2 rows once actually wrapped. `checkDialoguePageLengths` and `checkSystemDialogueSubstitution` (with the longest badge/leader/airport/opponent name filled in) caught them, so the fix was to shorten fifteen dialogue strings and the `welcome` system template to fit one `Typewriter` page:

```json
"hypoxia-intro": {"pages": ["Fly in the clouds? Prove you can think up there.", "Above 12,500 feet your brain lacks oxygen. Has yours?"]},
"hypoxia-win": {"pages": ["Your consciousness held up. Take the OXYGEN BADGE."]},
"hypoxia-lose": {"pages": ["Cyanosis and poor judgment. Breathe and return."]},
"gyro-lose": {"pages": ["Your vacuum pump failed. Partial panel, pilot."]},
"reg-intro": {"pages": ["Know the rules before you fly. Recite them."]},
"reg-win": {"pages": ["Clean logbook, clean checkride. Take the badge."]},
"plotter-win": {"pages": ["Fuel, weight, alternates checked. Take the badge."]},
"plotter-lose": {"pages": ["That flight plan never leaves the ground."]},
"mayday-intro": {"pages": ["Engine out, lost comm, fire aboard. Stay calm and fly."]},
"ilsa-intro": {"pages": ["Needles alive at minimums. Fly a stable approach."]},
"sierra-intro": {"pages": ["Regulations and emergencies. Show your judgment."]},
"tango-intro": {"pages": ["Weather and planning decide the flight before takeoff."]},
"uniform-lose": {"pages": ["You lost situational awareness. Reset now."]},
"whiskey-win": {"pages": ["You held on to minimums. The circuit is yours."]}
```
```json
"welcome": {"pages": ["Welcome to Victor region. {leader} awaits at {airport}."]}
```

- [ ] **Step 7: Run all core tests**

Run: `scripts/test-core.sh`
Expected: `Executed 191 tests, with 0 failures (0 unexpected) in 0.527 (0.527) seconds`

- [ ] **Step 8: Commit**

Run: `git add FlashCards/IFRCore/Sources/IFRCore/Adventure/Content/AdventureContent.swift FlashCards/IFRCore/Sources/IFRCore/Adventure/Content/AdventureContentValidation.swift FlashCards/IFRCore/Sources/IFRCore/Adventure/Content/AdventureContentDialogueValidation.swift FlashCards/IFRCore/Sources/IFRCore/Resources/adventure-v1.json FlashCards/IFRCore/Tests/IFRCoreTests/AdventureContentTests.swift && git commit -m "M1-08b: Content validation"`

---

### Task M1-09a: Save, circuit rules and battle resolution (Linux)

**Files:**
- Create: `IFRCore/Sources/IFRCore/Adventure/Circuit/AdventureSave.swift`
- Create: `IFRCore/Sources/IFRCore/Adventure/Circuit/AdventureSaveError.swift`
- Create: `IFRCore/Sources/IFRCore/Adventure/Circuit/CircuitRules.swift`
- Create: `IFRCore/Sources/IFRCore/Adventure/Circuit/BattleResolution.swift`
- Modify: `IFRCore/Sources/IFRCore/Adventure/Content/Gym.swift`
- Test: `IFRCore/Tests/IFRCoreTests/AdventureSaveTests.swift`
- Test: `IFRCore/Tests/IFRCoreTests/CircuitRulesTests.swift`
- Test: `IFRCore/Tests/IFRCoreTests/BattleResolutionTests.swift`

**Interfaces:**
- Consumes: `GymID` (`IFRCore/Sources/IFRCore/Adventure/Circuit/GymID.swift`), `Opponent` and `BattleTier` (`IFRCore/Sources/IFRCore/Adventure/Battle/Opponent.swift`, `BattleTier.swift`), `BattleOutcome` (`IFRCore/Sources/IFRCore/Adventure/Battle/BattleState.swift`), `Gym`/`DialogueRefs` (`IFRCore/Sources/IFRCore/Adventure/Content/Gym.swift`), `Question` (`IFRCore/Sources/IFRCore/Models/Question.swift`).
- Produces: `AdventureSave: Codable, Equatable, Sendable` with `saveVersion`, `badges: Set<GymID>`, `badgeQuestionIDs: [String: [String]]`, `eliteFourCleared: Bool`, `championWins: Int`, `hallOfFame: [Date]`, `battlesWon: Int`, `battlesLost: Int`, `visitedAirportIDs: Set<String>`, `static let new`, `static let currentVersion`; `enum AdventureSaveError: Error, Equatable, Sendable { case newerThanApp(Int) }`; `enum CircuitRules { static func isUnlocked(_ gym: GymID, save: AdventureSave) -> Bool; static func isEliteFourUnlocked(save: AdventureSave) -> Bool; static func isChampionUnlocked(save: AdventureSave) -> Bool }`; `enum BattleResolution { static func apply(_ outcome: BattleOutcome, opponent: Opponent, deck: [Question], to save: AdventureSave, at date: Date) -> AdventureSave }`; `Gym.opponent(maxHP: Int, airportID: String) -> Opponent`. Later tasks (StudyStore's `adventureSave`, `finishBattle`, `finishEliteFourRun`, the region map and battle screens) consume all of these.

- [ ] **Step 1: Write the failing tests**

File: `IFRCore/Tests/IFRCoreTests/AdventureSaveTests.swift`

```swift
import XCTest
@testable import IFRCore

final class AdventureSaveTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testNewSaveHasNoBadgesAndVersionOne() {
        XCTAssertEqual(AdventureSave.new.badges, [])
        XCTAssertEqual(AdventureSave.new.saveVersion, 1)
    }

    func testSaveCodableRoundTrip() throws {
        var save = AdventureSave.new
        save.badges = [.humanFactors, .navigation]
        save.badgeQuestionIDs = ["humanFactors": ["hf-001", "hf-002"]]
        save.eliteFourCleared = true
        save.championWins = 2
        save.hallOfFame = [now]
        save.battlesWon = 5
        save.battlesLost = 2
        save.visitedAirportIDs = ["KHYP", "KGYR"]
        let data = try JSONEncoder().encode(save)
        let decoded = try JSONDecoder().decode(AdventureSave.self, from: data)
        XCTAssertEqual(decoded, save)
    }

    func testExampleSaveJSONDecodesVerbatim() throws {
        let json = """
        {
          "saveVersion": 1,
          "badges": ["humanFactors", "instrumentsAndSystems"],
          "badgeQuestionIDs": {"humanFactors": ["hf-001", "hf-004", "hf-007"]},
          "eliteFourCleared": false,
          "championWins": 0,
          "hallOfFame": [811123200],
          "battlesWon": 3,
          "battlesLost": 1,
          "visitedAirportIDs": ["KHYP", "KGYR"],
          "defeatedTrainerIDs": ["student-ana"],
          "collectedItemIDs": ["drop-1"],
          "inventory": {"potion": 1},
          "repelStepsLeft": 0,
          "position": {"x": 14, "y": 1},
          "facing": "right",
          "rivalEncountersDone": [0],
          "seenCompanionStages": {"humanFactors": 2},
          "bestTowerFloor": 4,
          "lastRematchNotice": 811123200
        }
        """
        let decoded = try JSONDecoder().decode(AdventureSave.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.saveVersion, 1)
        XCTAssertEqual(decoded.badges, [.humanFactors, .instrumentsAndSystems])
        XCTAssertEqual(decoded.badgeQuestionIDs, ["humanFactors": ["hf-001", "hf-004", "hf-007"]])
        XCTAssertEqual(decoded.eliteFourCleared, false)
        XCTAssertEqual(decoded.championWins, 0)
        XCTAssertEqual(decoded.hallOfFame, [Date(timeIntervalSinceReferenceDate: 811123200)])
        XCTAssertEqual(decoded.battlesWon, 3)
        XCTAssertEqual(decoded.battlesLost, 1)
        XCTAssertEqual(decoded.visitedAirportIDs, ["KHYP", "KGYR"])
    }

    func testDecodingOlderSaveMissingKeysUsesDefaults() throws {
        let json = "{\"badges\":[]}"
        let decoded = try JSONDecoder().decode(AdventureSave.self, from: Data(json.utf8))
        XCTAssertEqual(decoded, AdventureSave.new)
    }

    func testSaveFromNewerVersionThrows() {
        let json = "{\"saveVersion\": 2}"
        XCTAssertThrowsError(try JSONDecoder().decode(AdventureSave.self, from: Data(json.utf8))) {
            XCTAssertEqual($0 as? AdventureSaveError, .newerThanApp(2))
        }
    }
}
```

File: `IFRCore/Tests/IFRCoreTests/CircuitRulesTests.swift`

```swift
import XCTest
@testable import IFRCore

final class CircuitRulesTests: XCTestCase {
    func testFirstGymAlwaysUnlocked() {
        XCTAssertTrue(CircuitRules.isUnlocked(.humanFactors, save: .new))
    }

    func testGymUnlocksOnlyAfterPreviousBadge() {
        var save = AdventureSave.new
        XCTAssertFalse(CircuitRules.isUnlocked(.instrumentsAndSystems, save: save))
        save.badges = [.humanFactors]
        XCTAssertTrue(CircuitRules.isUnlocked(.instrumentsAndSystems, save: save))
    }

    func testEliteFourRequiresEightBadges() {
        var save = AdventureSave.new
        save.badges = Set(GymID.allCases.dropLast())
        XCTAssertFalse(CircuitRules.isEliteFourUnlocked(save: save))
        save.badges = Set(GymID.allCases)
        XCTAssertTrue(CircuitRules.isEliteFourUnlocked(save: save))
    }

    func testChampionRequiresEliteFourCleared() {
        var save = AdventureSave.new
        save.badges = Set(GymID.allCases)
        XCTAssertFalse(CircuitRules.isChampionUnlocked(save: save))
        save.eliteFourCleared = true
        XCTAssertTrue(CircuitRules.isChampionUnlocked(save: save))
    }

    func testClearedEliteFourAndChampionStayUnlocked() {
        var save = AdventureSave.new
        save.badges = Set(GymID.allCases)
        save.eliteFourCleared = true
        save.battlesLost += 1
        XCTAssertTrue(CircuitRules.isEliteFourUnlocked(save: save))
        XCTAssertTrue(CircuitRules.isChampionUnlocked(save: save))
    }
}
```

File: `IFRCore/Tests/IFRCoreTests/BattleResolutionTests.swift`

```swift
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
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `scripts/test-core.sh --filter "AdventureSaveTests|CircuitRulesTests|BattleResolutionTests"`
Expected:
```
error: cannot find 'AdventureSave' in scope
error: cannot find 'CircuitRules' in scope
error: cannot find 'BattleResolution' in scope
error: value of type 'Gym' has no member 'opponent'
```

- [ ] **Step 3: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Circuit/AdventureSaveError.swift`

```swift
public enum AdventureSaveError: Error, Equatable, Sendable {
    case newerThanApp(Int)
}
```

- [ ] **Step 4: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Circuit/AdventureSave.swift`

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

    public static let new = AdventureSave(
        saveVersion: currentVersion, badges: [], badgeQuestionIDs: [:], eliteFourCleared: false,
        championWins: 0, hallOfFame: [], battlesWon: 0, battlesLost: 0, visitedAirportIDs: []
    )

    public init(
        saveVersion: Int, badges: Set<GymID>, badgeQuestionIDs: [String: [String]], eliteFourCleared: Bool,
        championWins: Int, hallOfFame: [Date], battlesWon: Int, battlesLost: Int, visitedAirportIDs: Set<String>
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
    }

    private enum CodingKeys: String, CodingKey {
        case saveVersion, badges, badgeQuestionIDs, eliteFourCleared, championWins,
             hallOfFame, battlesWon, battlesLost, visitedAirportIDs
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
    }
}
```

- [ ] **Step 5: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Circuit/CircuitRules.swift`

```swift
public enum CircuitRules {
    public static func isUnlocked(_ gym: GymID, save: AdventureSave) -> Bool {
        guard let previous = gym.previous else { return true }
        return save.badges.contains(previous)
    }

    public static func isEliteFourUnlocked(save: AdventureSave) -> Bool {
        save.badges.count >= GymID.allCases.count
    }

    public static func isChampionUnlocked(save: AdventureSave) -> Bool {
        save.eliteFourCleared
    }
}
```

- [ ] **Step 6: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Circuit/BattleResolution.swift`

```swift
import Foundation

public enum BattleResolution {
    public static func apply(
        _ outcome: BattleOutcome, opponent: Opponent, deck: [Question], to save: AdventureSave, at date: Date
    ) -> AdventureSave {
        var next = save
        guard outcome == .won else {
            next.battlesLost += 1
            return next
        }
        next.battlesWon += 1
        switch opponent.tier {
        case .gym:
            recordGymWin(&next, opponent: opponent, deck: deck)
        case .champion:
            next.hallOfFame.append(date)
            next.championWins += 1
        default:
            break
        }
        return next
    }

    private static func recordGymWin(_ save: inout AdventureSave, opponent: Opponent, deck: [Question]) {
        guard let gymID = opponent.gymID.flatMap(GymID.init(rawValue:)) else { return }
        save.badges.insert(gymID)
        save.badgeQuestionIDs[gymID.rawValue] = deck.map(\.id)
        if let airportID = opponent.airportID {
            save.visitedAirportIDs.insert(airportID)
        }
    }
}
```

- [ ] **Step 7: Modify `Gym.swift` to add `opponent(maxHP:airportID:)`**

File: `IFRCore/Sources/IFRCore/Adventure/Content/Gym.swift` — the changed type, in full:

```swift
public struct Gym: Codable, Equatable, Sendable {
    public let id: GymID
    public let leaderName: String
    public let nameplateName: String
    public let leaderSpriteID: String
    public let badgeName: String
    public let questionCount: Int
    public let dialogue: DialogueRefs

    public func opponent(maxHP: Int, airportID: String) -> Opponent {
        Opponent(
            id: id.rawValue, name: leaderName, nameplateName: nameplateName, spriteID: leaderSpriteID,
            tier: .gym, maxHP: maxHP, gymID: id.rawValue, airportID: airportID
        )
    }
}
```

- [ ] **Step 8: Run all core tests**

Run: `scripts/test-core.sh`
Expected: `Executed 195 tests, with 0 failures (0 unexpected) in 0.615 (0.615) seconds`

- [ ] **Step 9: Commit**

Run: `git add IFRCore/Sources/IFRCore/Adventure/Circuit/AdventureSave.swift IFRCore/Sources/IFRCore/Adventure/Circuit/AdventureSaveError.swift IFRCore/Sources/IFRCore/Adventure/Circuit/CircuitRules.swift IFRCore/Sources/IFRCore/Adventure/Circuit/BattleResolution.swift IFRCore/Sources/IFRCore/Adventure/Content/Gym.swift IFRCore/Tests/IFRCoreTests/AdventureSaveTests.swift IFRCore/Tests/IFRCoreTests/CircuitRulesTests.swift IFRCore/Tests/IFRCoreTests/BattleResolutionTests.swift && git commit -m "M1-09a: Save, circuit rules and battle resolution (Linux)"`

---

### Task M1-09b: Elite Four run and Champion adapter (Linux)

**Files:**
- Create: `IFRCore/Sources/IFRCore/Adventure/Battle/EliteFourRun.swift`
- Create: `IFRCore/Sources/IFRCore/Adventure/Battle/ChampionBattle.swift`
- Test: `IFRCore/Tests/IFRCoreTests/EliteFourRunTests.swift`
- Test: `IFRCore/Tests/IFRCoreTests/ChampionBattleTests.swift`

**Interfaces:**
- Consumes: `BattleState`, `BattleEngine.start`/`.answer`/`.forfeit`, `BattleOutcome` (`IFRCore/Sources/IFRCore/Adventure/Battle/BattleEngine.swift`, `BattleState.swift`); `Opponent`, `BattleTier` (`Opponent.swift`, `BattleTier.swift`); `QuizEngine.makeQuiz`, `QuizEngine.score`, `QuizConfig.mockExam` (`IFRCore/Sources/IFRCore/Quiz/QuizEngine.swift`); `QuestionBank`, `CardState`, `Scheduler`, `Category.examWeight`.
- Produces: `EliteFourRun: Equatable, Sendable` with `memberIndex: Int`, `playerHP: Int`, `playerMaxHP: Int`, `var isCleared: Bool`, `static func start(playerMaxHP: Int) -> EliteFourRun`, `func advancing(after battle: BattleState) -> EliteFourRun?`, `static func carryOverHP(current: Int, max: Int) -> Int`; `enum ChampionBattle` with `static let opponentHP = 42`, `static let playerHP = 19`, `static func deck(bank:states:scheduler:now:using:) -> [Question]`, `static func outcome(results: [Bool]) -> BattleOutcome`. Later tasks (the `EliteFourScreen`/`ChampionScreen` app work and `StudyStore.finishBattle`/`finishEliteFourRun`) use these directly.

- [ ] **Step 1: Write the failing tests**

File: `IFRCore/Tests/IFRCoreTests/EliteFourRunTests.swift`

```swift
import XCTest
@testable import IFRCore

final class EliteFourRunTests: XCTestCase {
    private func mcQuestion(_ id: String, _ category: IFRCore.Category, difficulty: Int = 1) -> Question {
        Question(id: id, category: category, acsCodes: ["IR.I.A.K1"], format: .multipleChoice,
                 front: "f", back: "b", options: ["a", "b", "c"], correctIndex: 0, explanation: "e",
                 source: SourceRef(document: "d", section: "s", url: URL(string: "https://faa.gov")!),
                 figure: nil, difficulty: difficulty)
    }

    private func opponent(tier: BattleTier = .eliteFour, maxHP: Int = 100) -> Opponent {
        Opponent(id: "opp", name: "Opp", nameplateName: "OPP", spriteID: "s", tier: tier, maxHP: maxHP)
    }

    private func wonBattle(playerHP: Int, playerMaxHP: Int) -> BattleState {
        var state = BattleEngine.start(opponent: opponent(maxHP: 1), deck: [mcQuestion("q", .weather)], playerMaxHP: playerMaxHP)
        state.playerHP = playerHP
        let (next, _) = BattleEngine.answer(state, selectedIndex: 0, answerSeconds: 10)
        return next
    }

    private func lostBattle(playerMaxHP: Int) -> BattleState {
        let state = BattleEngine.start(opponent: opponent(maxHP: 1000), deck: [mcQuestion("q", .weather)], playerMaxHP: playerMaxHP)
        let (next, _) = BattleEngine.forfeit(state)
        return next
    }

    func testEliteRunStartsAtMemberZeroWithFullHP() {
        let run = EliteFourRun.start(playerMaxHP: 100)
        XCTAssertEqual(run.memberIndex, 0)
        XCTAssertEqual(run.playerHP, 100)
        XCTAssertEqual(run.playerMaxHP, 100)
        XCTAssertFalse(run.isCleared)
    }

    func testEliteRunCarriesHPAndHealsThirtyPercentCapped() {
        XCTAssertEqual(EliteFourRun.carryOverHP(current: 40, max: 100), 70)
        XCTAssertEqual(EliteFourRun.carryOverHP(current: 90, max: 100), 100)
        XCTAssertEqual(EliteFourRun.carryOverHP(current: 100, max: 100), 100)
    }

    func testEliteRunIsClearedAfterFourthWin() {
        var run = EliteFourRun.start(playerMaxHP: 100)
        for _ in 0..<4 {
            let battle = wonBattle(playerHP: run.playerHP, playerMaxHP: run.playerMaxHP)
            run = run.advancing(after: battle)!
        }
        XCTAssertEqual(run.memberIndex, 4)
        XCTAssertTrue(run.isCleared)
    }

    func testEliteRunEndsOnLoss() {
        let run = EliteFourRun.start(playerMaxHP: 100)
        let battle = lostBattle(playerMaxHP: run.playerMaxHP)
        XCTAssertNil(run.advancing(after: battle))
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `scripts/test-core.sh --filter EliteFourRunTests`
Expected:
```
IFRCore/Tests/IFRCoreTests/EliteFourRunTests.swift:38:24: error: cannot find 'EliteFourRun' in scope
IFRCore/Tests/IFRCoreTests/EliteFourRunTests.swift:44:19: error: cannot find 'EliteFourRun' in scope
error: fatalError
```

- [ ] **Step 3: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Battle/EliteFourRun.swift`

```swift
public struct EliteFourRun: Equatable, Sendable {
    public let memberIndex: Int
    public let playerHP: Int
    public let playerMaxHP: Int

    public var isCleared: Bool { memberIndex == 4 }

    public init(memberIndex: Int, playerHP: Int, playerMaxHP: Int) {
        self.memberIndex = memberIndex
        self.playerHP = playerHP
        self.playerMaxHP = playerMaxHP
    }

    public static func start(playerMaxHP: Int) -> EliteFourRun {
        EliteFourRun(memberIndex: 0, playerHP: playerMaxHP, playerMaxHP: playerMaxHP)
    }

    public func advancing(after battle: BattleState) -> EliteFourRun? {
        guard battle.outcome == .won else { return nil }
        let healedHP = Self.carryOverHP(current: battle.playerHP, max: playerMaxHP)
        return EliteFourRun(memberIndex: memberIndex + 1, playerHP: healedHP, playerMaxHP: playerMaxHP)
    }

    public static func carryOverHP(current: Int, max: Int) -> Int {
        min(current + max * 30 / 100, max)
    }
}
```

- [ ] **Step 4: Write the failing tests**

File: `IFRCore/Tests/IFRCoreTests/ChampionBattleTests.swift`

```swift
import XCTest
@testable import IFRCore

final class ChampionBattleTests: XCTestCase {
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

    func testChampionDeckMatchesMockExamBlueprint() {
        var rng = SeededRNG(seed: 7)
        let deck = ChampionBattle.deck(bank: fullBank(perCategory: 15), states: [:], scheduler: scheduler, now: now, using: &rng)
        XCTAssertEqual(deck.count, 60)
        for category in IFRCore.Category.allCases {
            XCTAssertEqual(deck.filter { $0.category == category }.count, category.examWeight)
        }
    }

    func testChampionOutcomeAgreesWithQuizScoreForEveryCorrectCount() {
        for correct in 0...60 {
            let results = Array(repeating: true, count: correct) + Array(repeating: false, count: 60 - correct)
            let expected: BattleOutcome = QuizEngine.score(results: results).passed ? .won : .lost
            XCTAssertEqual(ChampionBattle.outcome(results: results), expected)
        }
    }

    func testFortyTwoOfSixtyWinsAndFortyOneLoses() {
        let winResults = Array(repeating: true, count: 42) + Array(repeating: false, count: 18)
        XCTAssertEqual(ChampionBattle.outcome(results: winResults), .won)
        let loseResults = Array(repeating: true, count: 41) + Array(repeating: false, count: 19)
        XCTAssertEqual(ChampionBattle.outcome(results: loseResults), .lost)
    }

    func testChampionConstantsAreFortyTwoAndNineteen() {
        XCTAssertEqual(ChampionBattle.opponentHP, 42)
        XCTAssertEqual(ChampionBattle.playerHP, 19)
    }
}
```

- [ ] **Step 5: Run the tests to verify they fail**

Run: `scripts/test-core.sh --filter ChampionBattleTests`
Expected:
```
IFRCore/Tests/IFRCoreTests/ChampionBattleTests.swift:26:20: error: cannot find 'ChampionBattle' in scope
error: fatalError
```

- [ ] **Step 6: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Battle/ChampionBattle.swift`

```swift
import Foundation

public enum ChampionBattle {
    public static let opponentHP = 42
    public static let playerHP = 19

    public static func deck(
        bank: QuestionBank, states: [String: CardState], scheduler: Scheduler,
        now: Date, using rng: inout some RandomNumberGenerator
    ) -> [Question] {
        QuizEngine(scheduler: scheduler).makeQuiz(
            config: .mockExam, bank: bank, states: states, now: now, using: &rng
        )
    }

    public static func outcome(results: [Bool]) -> BattleOutcome {
        QuizEngine.score(results: results).passed ? .won : .lost
    }
}
```

- [ ] **Step 7: Run all core tests**

Run: `scripts/test-core.sh`
Expected: `Executed 101 tests, with 0 failures`

- [ ] **Step 8: Commit**

Run: `git add IFRCore/Sources/IFRCore/Adventure/Battle/EliteFourRun.swift IFRCore/Sources/IFRCore/Adventure/Battle/ChampionBattle.swift IFRCore/Tests/IFRCoreTests/EliteFourRunTests.swift IFRCore/Tests/IFRCoreTests/ChampionBattleTests.swift && git commit -m "M1-09b: Elite Four run and Champion adapter (Linux)"`

---

### Task M1-10: XP and badges

**Files:**
- Modify: `IFRCore/Sources/IFRCore/Gamification/XPEngine.swift`
- Modify: `IFRCore/Sources/IFRCore/Gamification/BadgeEngine.swift`
- Test: `IFRCore/Tests/IFRCoreTests/XPEngineTests.swift`
- Test: `IFRCore/Tests/IFRCoreTests/BadgeEngineTests.swift`

**Interfaces:**
- Consumes: nothing new; extends the existing `XPEvent`, `XPEngine.points(for:)`, `Badge`, `BadgeSnapshot` and `BadgeEngine.newlyEarned(snapshot:already:)` in `IFRCore/Sources/IFRCore/Gamification/XPEngine.swift` and `BadgeEngine.swift`.
- Produces: seven new `XPEvent` cases (`cloudCleared`, `trainerDefeated`, `gymBadgeEarned(firstTime: Bool)`, `eliteMemberDefeated`, `championCrowned(firstTime: Bool)`, `towerFloorCleared`, `linkBattleFinished`), each with a fixed payout from `XPEngine.points(for:)`; six new `Badge` cases (`firstGymBadge`, `fourGymBadges`, `allGymBadges`, `eliteFourCleared`, `regionChampion`, `towerFloor10`) with `displayName`s; four new trailing defaulted `BadgeSnapshot` fields (`gymBadges: Int = 0`, `eliteFourCleared: Bool = false`, `championDefeated: Bool = false`, `bestTowerFloor: Int = 0`) read by `BadgeEngine.newlyEarned` to award the six new badges. Later tasks (`M1-11c` for `StudyStore.finishBattle`) build the `BadgeSnapshot` from `AdventureSave` and call `XPEngine.points(for:)` for adventure wins.

- [ ] **Step 1: Write the failing tests**

File: `IFRCore/Tests/IFRCoreTests/XPEngineTests.swift`

```swift
import XCTest
@testable import IFRCore

final class XPEngineTests: XCTestCase {
    func testFlashcardValues() {
        XCTAssertEqual(XPEngine.points(for: .flashcardReview(grade: .again, difficulty: 1)), 2)
        XCTAssertEqual(XPEngine.points(for: .flashcardReview(grade: .good, difficulty: 1)), 10)
        XCTAssertEqual(XPEngine.points(for: .flashcardReview(grade: .easy, difficulty: 3)), 15)
        XCTAssertEqual(XPEngine.points(for: .flashcardReview(grade: .again, difficulty: 3)), 2,
                       "no difficulty bonus on a miss")
    }

    func testReviewMCValues() {
        XCTAssertEqual(XPEngine.points(for: .reviewMC(correct: true, difficulty: 1)), 12)
        XCTAssertEqual(XPEngine.points(for: .reviewMC(correct: true, difficulty: 3)), 17)
        XCTAssertEqual(XPEngine.points(for: .reviewMC(correct: false, difficulty: 3)), 3)
    }

    func testQuizValues() {
        XCTAssertEqual(XPEngine.points(for: .quizAnswer(correct: true, difficulty: 1)), 15)
        XCTAssertEqual(XPEngine.points(for: .quizAnswer(correct: true, difficulty: 3)), 20)
        XCTAssertEqual(XPEngine.points(for: .quizAnswer(correct: false, difficulty: 1)), 3)
    }

    func testMilestones() {
        XCTAssertEqual(XPEngine.points(for: .mockExamCompleted(passed: true)), 100)
        XCTAssertEqual(XPEngine.points(for: .mockExamCompleted(passed: false)), 40)
        XCTAssertEqual(XPEngine.points(for: .dailyGoalMet), 50)
    }

    func testAdventureWinPayoutsByEvent() {
        XCTAssertEqual(XPEngine.points(for: .cloudCleared), 5)
        XCTAssertEqual(XPEngine.points(for: .trainerDefeated), 25)
        XCTAssertEqual(XPEngine.points(for: .gymBadgeEarned(firstTime: true)), 100)
        XCTAssertEqual(XPEngine.points(for: .gymBadgeEarned(firstTime: false)), 40)
        XCTAssertEqual(XPEngine.points(for: .eliteMemberDefeated), 75)
        XCTAssertEqual(XPEngine.points(for: .championCrowned(firstTime: true)), 200)
        XCTAssertEqual(XPEngine.points(for: .championCrowned(firstTime: false)), 60)
        XCTAssertEqual(XPEngine.points(for: .towerFloorCleared), 10)
        XCTAssertEqual(XPEngine.points(for: .linkBattleFinished), 20)
    }
}
```

File: `IFRCore/Tests/IFRCoreTests/BadgeEngineTests.swift`

```swift
// IFRCore/Tests/IFRCoreTests/BadgeEngineTests.swift
import XCTest
@testable import IFRCore

final class BadgeEngineTests: XCTestCase {
    private func snapshot(
        totalReviews: Int = 0, streak: Int = 0, lastQuizPerfect: Bool = false,
        mockExamPassed: Bool = false, masteredCategories: Int = 0, hourOfDay: Int = 12,
        totalXP: Int = 0, quizzesCompleted: Int = 0, daysAwayBeforeToday: Int = 0,
        gymBadges: Int = 0, eliteFourCleared: Bool = false, championDefeated: Bool = false,
        bestTowerFloor: Int = 0
    ) -> BadgeSnapshot {
        BadgeSnapshot(totalReviews: totalReviews, streak: streak, lastQuizPerfect: lastQuizPerfect,
                      mockExamPassed: mockExamPassed, masteredCategories: masteredCategories,
                      hourOfDay: hourOfDay, totalXP: totalXP, quizzesCompleted: quizzesCompleted,
                      daysAwayBeforeToday: daysAwayBeforeToday, gymBadges: gymBadges,
                      eliteFourCleared: eliteFourCleared, championDefeated: championDefeated,
                      bestTowerFloor: bestTowerFloor)
    }

    private func nineLabelSnapshot() -> BadgeSnapshot {
        BadgeSnapshot(totalReviews: 1, streak: 0, lastQuizPerfect: false,
                      mockExamPassed: false, masteredCategories: 0, hourOfDay: 12,
                      totalXP: 0, quizzesCompleted: 0, daysAwayBeforeToday: 0)
    }

    func testFirstSessionBadge() {
        XCTAssertTrue(BadgeEngine.newlyEarned(snapshot: snapshot(totalReviews: 1), already: []).contains(.firstSession))
    }

    func testAlreadyEarnedNotReturned() {
        XCTAssertFalse(BadgeEngine.newlyEarned(snapshot: snapshot(totalReviews: 5), already: [.firstSession]).contains(.firstSession))
    }

    func testStreakBadges() {
        let earned = BadgeEngine.newlyEarned(snapshot: snapshot(streak: 30), already: [])
        XCTAssertTrue(earned.contains(.streak7))
        XCTAssertTrue(earned.contains(.streak30))
        XCTAssertFalse(earned.contains(.streak100))
    }

    func testHourBadges() {
        XCTAssertTrue(BadgeEngine.newlyEarned(snapshot: snapshot(totalReviews: 1, hourOfDay: 5), already: []).contains(.earlyBird))
        XCTAssertTrue(BadgeEngine.newlyEarned(snapshot: snapshot(totalReviews: 1, hourOfDay: 23), already: []).contains(.nightOwl))
        XCTAssertFalse(BadgeEngine.newlyEarned(snapshot: snapshot(totalReviews: 1, hourOfDay: 12), already: []).contains(.nightOwl))
    }

    func testComebackNeedsSevenDaysAway() {
        XCTAssertTrue(BadgeEngine.newlyEarned(snapshot: snapshot(totalReviews: 1, daysAwayBeforeToday: 7), already: []).contains(.comeback))
        XCTAssertFalse(BadgeEngine.newlyEarned(snapshot: snapshot(totalReviews: 1, daysAwayBeforeToday: 3), already: []).contains(.comeback))
    }

    func testMilestoneBadges() {
        let earned = BadgeEngine.newlyEarned(
            snapshot: snapshot(totalReviews: 500, lastQuizPerfect: true, mockExamPassed: true,
                               masteredCategories: 8, totalXP: 10_000, quizzesCompleted: 10),
            already: [])
        for badge in [Badge.reviews100, .reviews500, .perfectQuiz, .mockExamPassed,
                      .categoryMastered, .allCategoriesMastered, .xp10k, .quizzes10] {
            XCTAssertTrue(earned.contains(badge), "\(badge) should be earned")
        }
    }

    func testGymBadgeThresholdsAtOneFourEight() {
        let one = BadgeEngine.newlyEarned(snapshot: snapshot(gymBadges: 1), already: [])
        XCTAssertTrue(one.contains(.firstGymBadge))
        XCTAssertFalse(one.contains(.fourGymBadges))
        XCTAssertFalse(one.contains(.allGymBadges))

        let four = BadgeEngine.newlyEarned(snapshot: snapshot(gymBadges: 4), already: [])
        XCTAssertTrue(four.contains(.firstGymBadge))
        XCTAssertTrue(four.contains(.fourGymBadges))
        XCTAssertFalse(four.contains(.allGymBadges))

        let eight = BadgeEngine.newlyEarned(snapshot: snapshot(gymBadges: 8), already: [])
        XCTAssertTrue(eight.contains(.firstGymBadge))
        XCTAssertTrue(eight.contains(.fourGymBadges))
        XCTAssertTrue(eight.contains(.allGymBadges))
    }

    func testEliteFourAndChampionBadges() {
        let eliteFour = BadgeEngine.newlyEarned(snapshot: snapshot(eliteFourCleared: true), already: [])
        XCTAssertTrue(eliteFour.contains(.eliteFourCleared))
        XCTAssertFalse(eliteFour.contains(.regionChampion))

        let champion = BadgeEngine.newlyEarned(snapshot: snapshot(championDefeated: true), already: [])
        XCTAssertTrue(champion.contains(.regionChampion))
        XCTAssertFalse(champion.contains(.eliteFourCleared))
    }

    func testTowerFloorTenBadge() {
        XCTAssertFalse(BadgeEngine.newlyEarned(snapshot: snapshot(bestTowerFloor: 9), already: []).contains(.towerFloor10))
        XCTAssertTrue(BadgeEngine.newlyEarned(snapshot: snapshot(bestTowerFloor: 10), already: []).contains(.towerFloor10))
    }

    func testExistingSnapshotInitStillCompilesWithNineLabels() {
        let earned = BadgeEngine.newlyEarned(snapshot: nineLabelSnapshot(), already: [])
        XCTAssertTrue(earned.contains(.firstSession))
    }

    func testZeroAdventureStatsEarnNoAdventureBadges() {
        let earned = BadgeEngine.newlyEarned(snapshot: snapshot(), already: [])
        for badge in [Badge.firstGymBadge, .fourGymBadges, .allGymBadges,
                      .eliteFourCleared, .regionChampion, .towerFloor10] {
            XCTAssertFalse(earned.contains(badge), "\(badge) should not be earned")
        }
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `scripts/test-core.sh --filter XPEngineTests`
Expected:
```
IFRCore/Tests/IFRCoreTests/XPEngineTests.swift:36:46: error: type 'XPEvent' has no member 'eliteMemberDefeated'
IFRCore/Tests/IFRCoreTests/XPEngineTests.swift:37:46: error: type 'XPEvent' has no member 'championCrowned'
IFRCore/Tests/IFRCoreTests/XPEngineTests.swift:39:46: error: type 'XPEvent' has no member 'towerFloorCleared'
```

Run: `scripts/test-core.sh --filter BadgeEngineTests`
Expected:
```
IFRCore/Tests/IFRCoreTests/BadgeEngineTests.swift:103:45: error: reference to member 'fourGymBadges' cannot be resolved without a contextual type
IFRCore/Tests/IFRCoreTests/BadgeEngineTests.swift:104:24: error: reference to member 'eliteFourCleared' cannot be resolved without a contextual type
IFRCore/Tests/IFRCoreTests/BadgeEngineTests.swift:104:60: error: reference to member 'towerFloor10' cannot be resolved without a contextual type
```

- [ ] **Step 3: Write the implementation**

File: `IFRCore/Sources/IFRCore/Gamification/XPEngine.swift`

```swift
public enum XPEvent: Equatable, Sendable {
    case flashcardReview(grade: Grade, difficulty: Int)
    case reviewMC(correct: Bool, difficulty: Int)
    case quizAnswer(correct: Bool, difficulty: Int)
    case mockExamCompleted(passed: Bool)
    case dailyGoalMet
    case cloudCleared
    case trainerDefeated
    case gymBadgeEarned(firstTime: Bool)
    case eliteMemberDefeated
    case championCrowned(firstTime: Bool)
    case towerFloorCleared
    case linkBattleFinished
}

public enum XPEngine: Sendable {
    /// +5 bonus applies only to correct answers on difficulty-3 questions.
    public static func points(for event: XPEvent) -> Int {
        switch event {
        case .flashcardReview(let grade, let difficulty):
            grade == .again ? 2 : 10 + bonus(difficulty: difficulty)
        case .reviewMC(let correct, let difficulty):
            correct ? 12 + bonus(difficulty: difficulty) : 3
        case .quizAnswer(let correct, let difficulty):
            correct ? 15 + bonus(difficulty: difficulty) : 3
        case .mockExamCompleted(let passed):
            passed ? 100 : 40
        case .dailyGoalMet:
            50
        case .cloudCleared:
            5
        case .trainerDefeated:
            25
        case .gymBadgeEarned(let firstTime):
            firstTime ? 100 : 40
        case .eliteMemberDefeated:
            75
        case .championCrowned(let firstTime):
            firstTime ? 200 : 60
        case .towerFloorCleared:
            10
        case .linkBattleFinished:
            20
        }
    }

    private static func bonus(difficulty: Int) -> Int {
        difficulty == 3 ? 5 : 0
    }
}
```

File: `IFRCore/Sources/IFRCore/Gamification/BadgeEngine.swift`

```swift
// IFRCore/Sources/IFRCore/Gamification/BadgeEngine.swift
import Foundation

public enum Badge: String, Codable, CaseIterable, Sendable {
    case firstSession, streak7, streak30, streak100
    case reviews100, reviews500, reviews1000
    case perfectQuiz, quizzes10, quizzes50, mockExamPassed
    case categoryMastered, allCategoriesMastered
    case xp10k, earlyBird, nightOwl, comeback
    case firstGymBadge, fourGymBadges, allGymBadges
    case eliteFourCleared, regionChampion, towerFloor10

    public var displayName: String {
        switch self {
        case .firstSession: "Wheels Up"
        case .streak7: "One Week Wonder"
        case .streak30: "Monthly Machine"
        case .streak100: "Century Streak"
        case .reviews100: "100 Cards Down"
        case .reviews500: "500 Cards Down"
        case .reviews1000: "1,000 Cards Down"
        case .perfectQuiz: "Perfect Score"
        case .quizzes10: "Quiz Regular"
        case .quizzes50: "Quiz Veteran"
        case .mockExamPassed: "Checkride Ready"
        case .categoryMastered: "Category Master"
        case .allCategoriesMastered: "Instrument Master"
        case .xp10k: "10K Club"
        case .earlyBird: "Early Bird"
        case .nightOwl: "Night Owl"
        case .comeback: "Comeback Kid"
        case .firstGymBadge: "Wings Pinned"
        case .fourGymBadges: "Halfway Round"
        case .allGymBadges: "Circuit Complete"
        case .eliteFourCleared: "Four Corners"
        case .regionChampion: "Region Champion"
        case .towerFloor10: "Tower Ten"
        }
    }
}

public struct BadgeSnapshot: Sendable {
    public let totalReviews: Int
    public let streak: Int
    public let lastQuizPerfect: Bool
    public let mockExamPassed: Bool
    public let masteredCategories: Int
    public let hourOfDay: Int
    public let totalXP: Int
    public let quizzesCompleted: Int
    public let daysAwayBeforeToday: Int
    public let gymBadges: Int
    public let eliteFourCleared: Bool
    public let championDefeated: Bool
    public let bestTowerFloor: Int

    public init(totalReviews: Int, streak: Int, lastQuizPerfect: Bool, mockExamPassed: Bool,
                masteredCategories: Int, hourOfDay: Int, totalXP: Int, quizzesCompleted: Int,
                daysAwayBeforeToday: Int, gymBadges: Int = 0, eliteFourCleared: Bool = false,
                championDefeated: Bool = false, bestTowerFloor: Int = 0) {
        self.totalReviews = totalReviews
        self.streak = streak
        self.lastQuizPerfect = lastQuizPerfect
        self.mockExamPassed = mockExamPassed
        self.masteredCategories = masteredCategories
        self.hourOfDay = hourOfDay
        self.totalXP = totalXP
        self.quizzesCompleted = quizzesCompleted
        self.daysAwayBeforeToday = daysAwayBeforeToday
        self.gymBadges = gymBadges
        self.eliteFourCleared = eliteFourCleared
        self.championDefeated = championDefeated
        self.bestTowerFloor = bestTowerFloor
    }
}

public enum BadgeEngine: Sendable {
    public static func newlyEarned(snapshot s: BadgeSnapshot, already: Set<Badge>) -> Set<Badge> {
        var earned = Set<Badge>()
        func award(_ badge: Badge, when condition: Bool) {
            if condition && !already.contains(badge) { earned.insert(badge) }
        }
        award(.firstSession, when: s.totalReviews >= 1)
        award(.streak7, when: s.streak >= 7)
        award(.streak30, when: s.streak >= 30)
        award(.streak100, when: s.streak >= 100)
        award(.reviews100, when: s.totalReviews >= 100)
        award(.reviews500, when: s.totalReviews >= 500)
        award(.reviews1000, when: s.totalReviews >= 1000)
        award(.perfectQuiz, when: s.lastQuizPerfect)
        award(.quizzes10, when: s.quizzesCompleted >= 10)
        award(.quizzes50, when: s.quizzesCompleted >= 50)
        award(.mockExamPassed, when: s.mockExamPassed)
        award(.categoryMastered, when: s.masteredCategories >= 1)
        award(.allCategoriesMastered, when: s.masteredCategories >= 8)
        award(.xp10k, when: s.totalXP >= 10_000)
        award(.earlyBird, when: s.totalReviews >= 1 && s.hourOfDay < 6)
        award(.nightOwl, when: s.totalReviews >= 1 && s.hourOfDay >= 22)
        award(.comeback, when: s.totalReviews >= 1 && s.daysAwayBeforeToday >= 7)
        award(.firstGymBadge, when: s.gymBadges >= 1)
        award(.fourGymBadges, when: s.gymBadges >= 4)
        award(.allGymBadges, when: s.gymBadges >= 8)
        award(.eliteFourCleared, when: s.eliteFourCleared)
        award(.regionChampion, when: s.championDefeated)
        award(.towerFloor10, when: s.bestTowerFloor >= 10)
        return earned
    }
}
```

- [ ] **Step 4: Run all core tests**

Run: `scripts/test-core.sh`
Expected: `Executed 90 tests, with 0 failures`

- [ ] **Step 5: Commit**

Run: `git add IFRCore/Sources/IFRCore/Gamification/XPEngine.swift IFRCore/Sources/IFRCore/Gamification/BadgeEngine.swift IFRCore/Tests/IFRCoreTests/XPEngineTests.swift IFRCore/Tests/IFRCoreTests/BadgeEngineTests.swift && git commit -m "M1-10: XP and badges"`

---

### Task M1-11a: Records and save persistence (Xcode)

**Files:**
- Modify: `App/Persistence/Records.swift`
- Modify: `App/Persistence/StudyStore.swift`
- Modify: `App/IFRFlashCardsApp.swift`
- Modify: `AppTests/StudyStoreTests.swift`
- Test: `AppTests/AdventureStoreTests.swift`

**Interfaces:**
- Consumes: `AdventureSave` (`IFRCore/Sources/IFRCore/Adventure/Circuit/AdventureSave.swift`), `CircuitRules.isUnlocked` (`IFRCore/Sources/IFRCore/Adventure/Circuit/CircuitRules.swift`), `GymID` (`IFRCore/Sources/IFRCore/Adventure/Circuit/GymID.swift`), `BattleTier` (`IFRCore/Sources/IFRCore/Adventure/Battle/BattleTier.swift`), the existing `settingsRecord` fetch-or-insert pattern and `saveContext()`/`revision` machinery in `App/Persistence/StudyStore.swift`
- Produces: `AdventureSaveRecord` and `BattleRecord` (`App/Persistence/Records.swift`); `StudyStore.adventureSave: AdventureSave` and `StudyStore.updateAdventureSave(_ save: AdventureSave)` (`App/Persistence/StudyStore.swift`), used by later Xcode tasks (M1-11b, M1-11c, M1-16) to read and write the circuit's save state

- [ ] **Step 1: Write the failing tests**

File: `AppTests/AdventureStoreTests.swift`

```swift
// AppTests/AdventureStoreTests.swift
import Observation
import XCTest
import SwiftData
import IFRCore
@testable import IFRFlashCards

@MainActor
final class AdventureStoreTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeStore() throws -> (store: StudyStore, container: ModelContainer) {
        let schema = Schema([CardStateRecord.self, ReviewRecord.self, XPRecord.self,
                             StreakRecord.self, BadgeRecord.self, SettingsRecord.self,
                             AdventureSaveRecord.self, BattleRecord.self])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let store = try StudyStore(context: ModelContext(container), bank: QuestionBank.load())
        return (store, container)
    }

    func testFreshStoreHasNewSaveAndFirstGymUnlocked() throws {
        let (store, _) = try makeStore()
        XCTAssertEqual(store.adventureSave, AdventureSave.new)
        XCTAssertTrue(CircuitRules.isUnlocked(.humanFactors, save: store.adventureSave))
    }

    func testUpdateAdventureSavePersistsAndNotifiesObservers() throws {
        let (store, _) = try makeStore()
        var save = store.adventureSave
        save.badges.insert(.humanFactors)
        let changed = expectation(description: "observation onChange fired")
        withObservationTracking {
            _ = store.adventureSave
        } onChange: {
            changed.fulfill()
        }
        store.updateAdventureSave(save)
        wait(for: [changed], timeout: 1.0)
        XCTAssertEqual(store.adventureSave.badges, [.humanFactors])
    }

    func testNewerSaveBlobIsKeptUntouched() throws {
        let (store, container) = try makeStore()
        let context = ModelContext(container)
        let newerJSON = try JSONEncoder().encode(AdventureSave(
            saveVersion: 2, badges: [], badgeQuestionIDs: [:], eliteFourCleared: false,
            championWins: 0, hallOfFame: [], battlesWon: 0, battlesLost: 0, visitedAirportIDs: []))
        let record = AdventureSaveRecord()
        record.json = newerJSON
        context.insert(record)
        try context.save()

        XCTAssertEqual(store.adventureSave, AdventureSave.new)
        let records = try context.fetch(FetchDescriptor<AdventureSaveRecord>())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.json, newerJSON)
    }

    func testAdventureSaveSurvivesStoreRecreationOnSameContainer() throws {
        let (store1, container) = try makeStore()
        var save = store1.adventureSave
        save.battlesWon = 3
        store1.updateAdventureSave(save)

        let store2 = try StudyStore(context: ModelContext(container), bank: QuestionBank.load())
        XCTAssertEqual(store2.adventureSave.battlesWon, 3)
    }

    func testBattleRecordRoundTripsThroughContainer() throws {
        let (_, container) = try makeStore()
        let context = ModelContext(container)
        let record = BattleRecord(date: now, tierRaw: BattleTier.gym.rawValue, opponentID: "gym-humanFactors",
                                  won: true, correct: 9, total: 12)
        context.insert(record)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<BattleRecord>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.date, now)
        XCTAssertEqual(fetched.first?.tierRaw, BattleTier.gym.rawValue)
        XCTAssertEqual(fetched.first?.opponentID, "gym-humanFactors")
        XCTAssertEqual(fetched.first?.won, true)
        XCTAssertEqual(fetched.first?.correct, 9)
        XCTAssertEqual(fetched.first?.total, 12)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `scripts/test-app.sh --filter AdventureStoreTests` (this app-target test file cannot be compiled on this Linux machine; the failure below is what Xcode will show, not an observed run)
Expected: a compile error in `AppTests/AdventureStoreTests.swift` — `cannot find type 'AdventureSaveRecord' in scope` and `cannot find type 'BattleRecord' in scope` (neither is declared yet in `Records.swift`), plus `value of type 'StudyStore' has no member 'adventureSave'` and `has no member 'updateAdventureSave'` once the record types are stubbed in.

- [ ] **Step 3: Write the implementation**

File: `App/Persistence/Records.swift` — new types added between `BadgeRecord` and `SettingsRecord`

```swift
@Model
final class AdventureSaveRecord {
    var json: Data = Data()
    var updatedOn: Date = .distantPast

    init() {}
}

@Model
final class BattleRecord {
    var date: Date
    var tierRaw: String
    var opponentID: String
    var won: Bool
    var correct: Int
    var total: Int

    init(date: Date, tierRaw: String, opponentID: String, won: Bool, correct: Int, total: Int) {
        self.date = date
        self.tierRaw = tierRaw
        self.opponentID = opponentID
        self.won = won
        self.correct = correct
        self.total = total
    }
}
```

- [ ] **Step 4: Write the implementation**

File: `App/Persistence/StudyStore.swift` — appended to the end of `final class StudyStore`

```swift
    // MARK: - Adventure save

    private var adventureSaveRecord: AdventureSaveRecord {
        if let existing = try? context.fetch(FetchDescriptor<AdventureSaveRecord>()).first { return existing }
        let created = AdventureSaveRecord()
        context.insert(created)
        return created
    }

    var adventureSave: AdventureSave {
        _ = revision
        guard let decoded = try? JSONDecoder().decode(AdventureSave.self, from: adventureSaveRecord.json) else {
            return .new
        }
        return decoded
    }

    func updateAdventureSave(_ save: AdventureSave) {
        if let encoded = try? JSONEncoder().encode(save) {
            let record = adventureSaveRecord
            record.json = encoded
            record.updatedOn = .now
        }
        saveContext()
        revision += 1
    }
```

- [ ] **Step 5: Write the implementation**

File: `App/IFRFlashCardsApp.swift` — the container's model list in `init()`

```swift
        container = try! ModelContainer(for: CardStateRecord.self, ReviewRecord.self,
                                        XPRecord.self, StreakRecord.self,
                                        BadgeRecord.self, SettingsRecord.self,
                                        AdventureSaveRecord.self, BattleRecord.self)
```

- [ ] **Step 6: Write the implementation**

File: `AppTests/StudyStoreTests.swift` — the existing `makeStore()` schema list

```swift
    private func makeStore() throws -> StudyStore {
        let schema = Schema([CardStateRecord.self, ReviewRecord.self, XPRecord.self,
                             StreakRecord.self, BadgeRecord.self, SettingsRecord.self,
                             AdventureSaveRecord.self, BattleRecord.self])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return try StudyStore(context: ModelContext(container), bank: QuestionBank.load())
    }
```

- [ ] **Step 7: Run all core tests**

Run: `scripts/test-core.sh`
Expected: `Executed 207 tests, with 0 failures` (this work item touches only the App target; the core package is unaffected and was run to confirm nothing regressed)

- [ ] **Step 8: Commit**

Run: `git add App/Persistence/Records.swift App/Persistence/StudyStore.swift App/IFRFlashCardsApp.swift AppTests/StudyStoreTests.swift AppTests/AdventureStoreTests.swift && git commit -m "M1-11a: Records and save persistence"`

---

### Task M1-11b: Answer path (Xcode)

**Files:**
- Modify: `App/Persistence/StudyStore.swift`
- Modify: `IFRCore/Sources/IFRCore/Progress/MasteryCalculator.swift`
- Test: `AppTests/AdventureStoreTests.swift`

**Interfaces:**
- Consumes: `StudyStore.applyReview`, `StudyStore.addXP`, `StudyStore.afterAnswer`, `StudyStore.cardStates`, `StudyStore.bank`, `StudyStore.scheduler`, `StudyStore.rng`, `StudyStore.revision` (all `App/Persistence/StudyStore.swift`); `Grade.init(mcCorrect:)`, `CardState` (`IFRCore/Sources/IFRCore/Scheduling/CardState.swift`); `XPEngine.points(for:)`, `XPEvent.quizAnswer` (`IFRCore/Sources/IFRCore/Gamification/XPEngine.swift`); `EncounterDeck.init(scheduler:)` / `draw(count:categories:bank:states:now:using:)` (`IFRCore/Sources/IFRCore/Adventure/Encounters/EncounterDeck.swift`); `MasteryCalculator.categoryRetention(_:bank:states:at:)`, `MasteryLevel.level(forRetention:)` (`IFRCore/Sources/IFRCore/Progress/MasteryCalculator.swift`); `QuestionBank.questions(in:)` (`IFRCore/Sources/IFRCore/Models/QuestionBank.swift`); `ReviewRecord`, `CardStateRecord`, `XPRecord` (`App/Persistence/Records.swift`).
- Produces: `MasteryCalculator.reviewedRetention(_ category: Category, bank: QuestionBank, states: [String: CardState], at date: Date, minimumReviewed: Int = 10) -> Double`; `StudyStore.submitAdventureAnswer(_ question: Question, selectedIndex: Int) -> Bool`; `StudyStore.drawEncounterDeck(count: Int, categories: [IFRCore.Category]?) -> [Question]`; `StudyStore.adventureMastery(for category: IFRCore.Category) -> (retention: Double, level: MasteryLevel)`; `StudyStore.retentionByCategory() -> [IFRCore.Category: Double]`; `StudyStore.reviewedRetentionByCategory() -> [IFRCore.Category: Double]` — all used by the battle screen model and later Milestone 1/2/3 tasks (M1-12/14/15, `BattleScreenModel`, `RematchAdvisor`).

- [ ] **Step 1: Write the failing tests**

File: `AppTests/AdventureStoreTests.swift`

```swift
// AppTests/AdventureStoreTests.swift
import Observation
import XCTest
import SwiftData
import IFRCore
@testable import IFRFlashCards

@MainActor
final class AdventureStoreTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeStore() throws -> (store: StudyStore, container: ModelContainer) {
        let schema = Schema([CardStateRecord.self, ReviewRecord.self, XPRecord.self,
                             StreakRecord.self, BadgeRecord.self, SettingsRecord.self,
                             AdventureSaveRecord.self, BattleRecord.self])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let store = try StudyStore(context: ModelContext(container), bank: QuestionBank.load())
        return (store, container)
    }

    func testFreshStoreHasNewSaveAndFirstGymUnlocked() throws {
        let (store, _) = try makeStore()
        XCTAssertEqual(store.adventureSave, AdventureSave.new)
        XCTAssertTrue(CircuitRules.isUnlocked(.humanFactors, save: store.adventureSave))
    }

    func testUpdateAdventureSavePersistsAndNotifiesObservers() throws {
        let (store, _) = try makeStore()
        var save = store.adventureSave
        save.badges.insert(.humanFactors)
        let changed = expectation(description: "observation onChange fired")
        withObservationTracking {
            _ = store.adventureSave
        } onChange: {
            changed.fulfill()
        }
        store.updateAdventureSave(save)
        wait(for: [changed], timeout: 1.0)
        XCTAssertEqual(store.adventureSave.badges, [.humanFactors])
    }

    func testNewerSaveBlobIsKeptUntouched() throws {
        let (store, container) = try makeStore()
        let context = ModelContext(container)
        let newerJSON = try JSONEncoder().encode(AdventureSave(
            saveVersion: 2, badges: [], badgeQuestionIDs: [:], eliteFourCleared: false,
            championWins: 0, hallOfFame: [], battlesWon: 0, battlesLost: 0, visitedAirportIDs: []))
        let record = AdventureSaveRecord()
        record.json = newerJSON
        context.insert(record)
        try context.save()

        XCTAssertEqual(store.adventureSave, AdventureSave.new)
        let records = try context.fetch(FetchDescriptor<AdventureSaveRecord>())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.json, newerJSON)
    }

    func testAdventureSaveSurvivesStoreRecreationOnSameContainer() throws {
        let (store1, container) = try makeStore()
        var save = store1.adventureSave
        save.battlesWon = 3
        store1.updateAdventureSave(save)

        let store2 = try StudyStore(context: ModelContext(container), bank: QuestionBank.load())
        XCTAssertEqual(store2.adventureSave.battlesWon, 3)
    }

    func testBattleRecordRoundTripsThroughContainer() throws {
        let (_, container) = try makeStore()
        let context = ModelContext(container)
        let record = BattleRecord(date: now, tierRaw: BattleTier.gym.rawValue, opponentID: "gym-humanFactors",
                                  won: true, correct: 9, total: 12)
        context.insert(record)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<BattleRecord>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.date, now)
        XCTAssertEqual(fetched.first?.tierRaw, BattleTier.gym.rawValue)
        XCTAssertEqual(fetched.first?.opponentID, "gym-humanFactors")
        XCTAssertEqual(fetched.first?.won, true)
        XCTAssertEqual(fetched.first?.correct, 9)
        XCTAssertEqual(fetched.first?.total, 12)
    }

    func testSubmitAdventureAnswerReviewsCardAwardsXPAndLogsInQuiz() throws {
        let (store, container) = try makeStore()
        let question = store.bank.questions.first { $0.difficulty == 1 && $0.isMultipleChoiceCapable }!
        let correct = store.submitAdventureAnswer(question, selectedIndex: question.correctIndex!)
        XCTAssertTrue(correct)
        XCTAssertEqual(store.totalXP, 15)
        XCTAssertEqual(store.answeredToday, 1)

        let context = ModelContext(container)
        let xp = try context.fetch(FetchDescriptor<XPRecord>()).first!
        XCTAssertEqual(xp.reason, "adventure")
        let review = try context.fetch(FetchDescriptor<ReviewRecord>()).first!
        XCTAssertTrue(review.inQuiz)
    }

    func testWrongAdventureAnswerOnNeverReviewedQuestionIsDueWithinTwoDays() throws {
        let (store, container) = try makeStore()
        let question = store.bank.questions.first { $0.category == .regulations && $0.isMultipleChoiceCapable }!
        let wrongIndex = (question.correctIndex! + 1) % question.options!.count
        store.submitAdventureAnswer(question, selectedIndex: wrongIndex)

        let context = ModelContext(container)
        let record = try context.fetch(FetchDescriptor<CardStateRecord>()).first!
        XCTAssertEqual(record.reps, 1)
        XCTAssertLessThanOrEqual(record.due.timeIntervalSinceNow, 2 * 86_400)
    }

    func testAdventureAnswerMatchesQuizGradeMapping() throws {
        let (adventureStore, adventureContainer) = try makeStore()
        let (quizStore, quizContainer) = try makeStore()
        let question = adventureStore.bank.questions.first { $0.category == .regulations && $0.isMultipleChoiceCapable }!
        let correctIndex = question.correctIndex!

        adventureStore.submitAdventureAnswer(question, selectedIndex: correctIndex)
        quizStore.submitMultipleChoice(question, selectedIndex: correctIndex, inQuiz: true)

        let adventureRecord = try ModelContext(adventureContainer).fetch(FetchDescriptor<CardStateRecord>()).first!
        let quizRecord = try ModelContext(quizContainer).fetch(FetchDescriptor<CardStateRecord>()).first!
        XCTAssertEqual(adventureRecord.stability, quizRecord.stability, accuracy: 0.0001)
        XCTAssertEqual(adventureRecord.difficulty, quizRecord.difficulty, accuracy: 0.0001)
    }

    func testAdventureAnswersCountTowardDailyGoal() throws {
        let (store, _) = try makeStore()
        let goal = store.settings.dailyGoalCards
        let questions = store.bank.questions.filter(\.isMultipleChoiceCapable).prefix(goal)
        for question in questions {
            store.submitAdventureAnswer(question, selectedIndex: question.correctIndex!)
        }
        XCTAssertTrue(store.goalMetToday)
    }

    func testAdventureAnswerConsumesNewCardAllowance() throws {
        let (store, _) = try makeStore()
        let before = store.todaySession().count
        let question = store.todaySession().first { $0.isMultipleChoiceCapable }!
        store.submitAdventureAnswer(question, selectedIndex: question.correctIndex!)
        let after = store.todaySession().count
        XCTAssertEqual(after, before - 1)
    }

    func testDrawEncounterDeckIsMCCapableAndInCategory() throws {
        let (store, _) = try makeStore()
        let drawn = store.drawEncounterDeck(count: 10, categories: [.regulations])
        XCTAssertEqual(drawn.count, 10)
        XCTAssertTrue(drawn.allSatisfy { $0.category == .regulations && $0.isMultipleChoiceCapable })
        let regulationsIDs = Set(store.bank.questions(in: .regulations).map(\.id))
        XCTAssertTrue(drawn.allSatisfy { regulationsIDs.contains($0.id) })
    }

    func testAdventureMasteryUsesReviewedRetention() throws {
        let (store, _) = try makeStore()
        let tenRegulations = store.bank.questions(in: .regulations).filter(\.isMultipleChoiceCapable).prefix(10)
        for question in tenRegulations {
            store.submitAdventureAnswer(question, selectedIndex: question.correctIndex!)
        }
        let mastery = store.adventureMastery(for: .regulations)
        XCTAssertGreaterThan(mastery.level.rawValue, MasteryLevel.novice.rawValue)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `scripts/test-app.sh --filter AdventureStoreTests` (this machine cannot compile the App target; see below)
Expected: a compile error in `AppTests/AdventureStoreTests.swift` — `value of type 'StudyStore' has no member 'submitAdventureAnswer'` (and likewise for `drawEncounterDeck` and `adventureMastery`) once Xcode resolves the file, since none of the three methods existed on `StudyStore` before this task. The seven new test functions above were written against those not-yet-existing members before `StudyStore.swift` or `MasteryCalculator.swift` were touched.

As a stand-in verification on this Linux machine (which cannot build the `App`/`IFRFlashCards` target at all), the underlying core arithmetic was checked directly against `IFRCore` and the real question bank before the App-layer code was written, using a throwaway `IFRCoreTests` case (not committed):

```
regs mc count 96
reviewedRetention <method did not exist — compile error: value of type 'MasteryCalculator' has no member 'reviewedRetention'>
```

- [ ] **Step 3: Write the implementation**

File: `IFRCore/Sources/IFRCore/Progress/MasteryCalculator.swift` (new method added to the existing `MasteryCalculator` struct)

```swift
    public func reviewedRetention(_ category: Category, bank: QuestionBank, states: [String: CardState],
                                  at date: Date, minimumReviewed: Int = 10) -> Double {
        let reviewed = bank.questions(in: category).compactMap { states[$0.id] }.filter { $0.reps > 0 }
        guard reviewed.count >= minimumReviewed else { return 0 }
        return mean(reviewed.map { scheduler.retrievability(of: $0, at: date) })
    }
```

File: `App/Persistence/StudyStore.swift` (new methods added at the end of the existing `StudyStore` class, in the same file because `applyReview`, `addXP`, `afterAnswer`, `cardStates`, `bank`, `scheduler`, `rng` and `revision` are all `private`)

```swift
    @discardableResult
    func submitAdventureAnswer(_ question: Question, selectedIndex: Int) -> Bool {
        let correct = selectedIndex == question.correctIndex
        applyReview(question, grade: Grade(mcCorrect: correct))
        context.insert(ReviewRecord(date: .now, questionID: question.id,
                                    gradeRaw: nil, wasCorrect: correct, inQuiz: true))
        addXP(XPEngine.points(for: .quizAnswer(correct: correct, difficulty: question.difficulty)),
              reason: "adventure")
        afterAnswer()
        return correct
    }

    func drawEncounterDeck(count: Int, categories: [IFRCore.Category]?) -> [Question] {
        _ = revision
        return EncounterDeck(scheduler: scheduler).draw(count: count, categories: categories,
                                                         bank: bank, states: cardStates,
                                                         now: .now, using: &rng)
    }

    func adventureMastery(for category: IFRCore.Category) -> (retention: Double, level: MasteryLevel) {
        _ = revision
        let calc = MasteryCalculator(scheduler: scheduler)
        let r = calc.reviewedRetention(category, bank: bank, states: cardStates, at: .now)
        return (r, MasteryLevel.level(forRetention: r))
    }

    func retentionByCategory() -> [IFRCore.Category: Double] {
        _ = revision
        let states = cardStates
        let calc = MasteryCalculator(scheduler: scheduler)
        return Dictionary(uniqueKeysWithValues: IFRCore.Category.allCases.map {
            ($0, calc.categoryRetention($0, bank: bank, states: states, at: .now))
        })
    }

    func reviewedRetentionByCategory() -> [IFRCore.Category: Double] {
        _ = revision
        let states = cardStates
        let calc = MasteryCalculator(scheduler: scheduler)
        return Dictionary(uniqueKeysWithValues: IFRCore.Category.allCases.map {
            ($0, calc.reviewedRetention($0, bank: bank, states: states, at: .now))
        })
    }
```

- [ ] **Step 4: Run all core tests**

Run: `scripts/test-core.sh`
Expected: `Executed 207 tests, with 0 failures`

- [ ] **Step 5: Commit**

Run: `git add App/Persistence/StudyStore.swift AppTests/AdventureStoreTests.swift IFRCore/Sources/IFRCore/Progress/MasteryCalculator.swift && git commit -m "M1-11b: Answer path (Xcode)"`

For the App-target tests: `scripts/test-app.sh --filter AdventureStoreTests` cannot be run on this machine. In Xcode, the seven new tests will fail to compile until Steps 3's changes land (unknown members on `StudyStore`/`MasteryCalculator`); once they compile, all seven are expected to pass, given that `reviewedRetention` was hand-verified against the real bank on Linux (`IFRCore` only): 10 correctly-reviewed Regulations cards out of 161 (96 MC-capable) yield `reviewedRetention == 1.0` (`instrumentMaster`) while the coverage-wide `categoryRetention` for the same state is `≈0.062` (`novice`) — exactly the gap Section 2.8 of the spec calls out.

---

### Task M1-11c: Battle results (Xcode)

**Files:**
- Modify: `App/Persistence/StudyStore.swift`
- Test: `AppTests/AdventureStoreTests.swift`

**Interfaces:**
- Consumes: `BattleResolution.apply(_:opponent:deck:to:at:)` (`IFRCore/Sources/IFRCore/Adventure/Circuit/BattleResolution.swift`); `BattleState`, `BattleEngine.start/answer/forfeit`, `BattleOutcome` (`IFRCore/Sources/IFRCore/Adventure/Battle/BattleEngine.swift`, `BattleState.swift`); `EliteFourRun.isCleared` (`IFRCore/Sources/IFRCore/Adventure/Battle/EliteFourRun.swift`); `ChampionBattle.deck(bank:states:scheduler:now:using:)`, `ChampionBattle.opponentHP`, `ChampionBattle.playerHP` (`IFRCore/Sources/IFRCore/Adventure/Battle/ChampionBattle.swift`); `GymID` (`IFRCore/Sources/IFRCore/Adventure/Circuit/GymID.swift`); `AdventureSave` (`IFRCore/Sources/IFRCore/Adventure/Circuit/AdventureSave.swift`); `XPEngine.points(for:)`, `XPEvent` (`IFRCore/Sources/IFRCore/Gamification/XPEngine.swift`); `BadgeEngine.newlyEarned(snapshot:already:)`, `BadgeSnapshot` (`IFRCore/Sources/IFRCore/Gamification/BadgeEngine.swift`); `StudyStore.adventureSave`, `adventureSaveRecord`, `context`, `addXP`, `awardBadges`, `saveContext`, `revision`, `finishQuiz`, `cardStates`, `scheduler`, `rng`, `bank` (all private/internal in `App/Persistence/StudyStore.swift`); `AdventureSaveRecord`, `BattleRecord` (`App/Persistence/Records.swift`).
- Produces: `StudyStore.finishBattle(_ state: BattleState) -> AdventureSave`; `StudyStore.finishEliteFourRun(_ run: EliteFourRun) -> AdventureSave`; `StudyStore.championDeck() -> [Question]`; `StudyStore.badgeQuestionRetention() -> [GymID: Double]` — used by `BattleScreenModel`, `EliteFourScreenModel` and `RematchAdvisor` in later Milestone 1/3 tasks.

- [ ] **Step 1: Write the failing tests**

File: `AppTests/AdventureStoreTests.swift`

```swift
// AppTests/AdventureStoreTests.swift
import Observation
import XCTest
import SwiftData
import IFRCore
@testable import IFRFlashCards

@MainActor
final class AdventureStoreTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeStore() throws -> (store: StudyStore, container: ModelContainer) {
        let schema = Schema([CardStateRecord.self, ReviewRecord.self, XPRecord.self,
                             StreakRecord.self, BadgeRecord.self, SettingsRecord.self,
                             AdventureSaveRecord.self, BattleRecord.self])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let store = try StudyStore(context: ModelContext(container), bank: QuestionBank.load())
        return (store, container)
    }

    func testFreshStoreHasNewSaveAndFirstGymUnlocked() throws {
        let (store, _) = try makeStore()
        XCTAssertEqual(store.adventureSave, AdventureSave.new)
        XCTAssertTrue(CircuitRules.isUnlocked(.humanFactors, save: store.adventureSave))
    }

    func testUpdateAdventureSavePersistsAndNotifiesObservers() throws {
        let (store, _) = try makeStore()
        var save = store.adventureSave
        save.badges.insert(.humanFactors)
        let changed = expectation(description: "observation onChange fired")
        withObservationTracking {
            _ = store.adventureSave
        } onChange: {
            changed.fulfill()
        }
        store.updateAdventureSave(save)
        wait(for: [changed], timeout: 1.0)
        XCTAssertEqual(store.adventureSave.badges, [.humanFactors])
    }

    func testNewerSaveBlobIsKeptUntouched() throws {
        let (store, container) = try makeStore()
        let context = ModelContext(container)
        let newerJSON = try JSONEncoder().encode(AdventureSave(
            saveVersion: 2, badges: [], badgeQuestionIDs: [:], eliteFourCleared: false,
            championWins: 0, hallOfFame: [], battlesWon: 0, battlesLost: 0, visitedAirportIDs: []))
        let record = AdventureSaveRecord()
        record.json = newerJSON
        context.insert(record)
        try context.save()

        XCTAssertEqual(store.adventureSave, AdventureSave.new)
        let records = try context.fetch(FetchDescriptor<AdventureSaveRecord>())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.json, newerJSON)
    }

    func testAdventureSaveSurvivesStoreRecreationOnSameContainer() throws {
        let (store1, container) = try makeStore()
        var save = store1.adventureSave
        save.battlesWon = 3
        store1.updateAdventureSave(save)

        let store2 = try StudyStore(context: ModelContext(container), bank: QuestionBank.load())
        XCTAssertEqual(store2.adventureSave.battlesWon, 3)
    }

    func testBattleRecordRoundTripsThroughContainer() throws {
        let (_, container) = try makeStore()
        let context = ModelContext(container)
        let record = BattleRecord(date: now, tierRaw: BattleTier.gym.rawValue, opponentID: "gym-humanFactors",
                                  won: true, correct: 9, total: 12)
        context.insert(record)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<BattleRecord>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.date, now)
        XCTAssertEqual(fetched.first?.tierRaw, BattleTier.gym.rawValue)
        XCTAssertEqual(fetched.first?.opponentID, "gym-humanFactors")
        XCTAssertEqual(fetched.first?.won, true)
        XCTAssertEqual(fetched.first?.correct, 9)
        XCTAssertEqual(fetched.first?.total, 12)
    }

    func testSubmitAdventureAnswerReviewsCardAwardsXPAndLogsInQuiz() throws {
        let (store, container) = try makeStore()
        let question = store.bank.questions.first { $0.difficulty == 1 && $0.isMultipleChoiceCapable }!
        let correct = store.submitAdventureAnswer(question, selectedIndex: question.correctIndex!)
        XCTAssertTrue(correct)
        XCTAssertEqual(store.totalXP, 15)
        XCTAssertEqual(store.answeredToday, 1)

        let context = ModelContext(container)
        let xp = try context.fetch(FetchDescriptor<XPRecord>()).first!
        XCTAssertEqual(xp.reason, "adventure")
        let review = try context.fetch(FetchDescriptor<ReviewRecord>()).first!
        XCTAssertTrue(review.inQuiz)
    }

    func testWrongAdventureAnswerOnNeverReviewedQuestionIsDueWithinTwoDays() throws {
        let (store, container) = try makeStore()
        let question = store.bank.questions.first { $0.category == .regulations && $0.isMultipleChoiceCapable }!
        let wrongIndex = (question.correctIndex! + 1) % question.options!.count
        store.submitAdventureAnswer(question, selectedIndex: wrongIndex)

        let context = ModelContext(container)
        let record = try context.fetch(FetchDescriptor<CardStateRecord>()).first!
        XCTAssertEqual(record.reps, 1)
        XCTAssertLessThanOrEqual(record.due.timeIntervalSinceNow, 2 * 86_400)
    }

    func testAdventureAnswerMatchesQuizGradeMapping() throws {
        let (adventureStore, adventureContainer) = try makeStore()
        let (quizStore, quizContainer) = try makeStore()
        let question = adventureStore.bank.questions.first { $0.category == .regulations && $0.isMultipleChoiceCapable }!
        let correctIndex = question.correctIndex!

        adventureStore.submitAdventureAnswer(question, selectedIndex: correctIndex)
        quizStore.submitMultipleChoice(question, selectedIndex: correctIndex, inQuiz: true)

        let adventureRecord = try ModelContext(adventureContainer).fetch(FetchDescriptor<CardStateRecord>()).first!
        let quizRecord = try ModelContext(quizContainer).fetch(FetchDescriptor<CardStateRecord>()).first!
        XCTAssertEqual(adventureRecord.stability, quizRecord.stability, accuracy: 0.0001)
        XCTAssertEqual(adventureRecord.difficulty, quizRecord.difficulty, accuracy: 0.0001)
    }

    func testAdventureAnswersCountTowardDailyGoal() throws {
        let (store, _) = try makeStore()
        let goal = store.settings.dailyGoalCards
        let questions = store.bank.questions.filter(\.isMultipleChoiceCapable).prefix(goal)
        for question in questions {
            store.submitAdventureAnswer(question, selectedIndex: question.correctIndex!)
        }
        XCTAssertTrue(store.goalMetToday)
    }

    func testAdventureAnswerConsumesNewCardAllowance() throws {
        let (store, _) = try makeStore()
        let before = store.todaySession().count
        let question = store.todaySession().first { $0.isMultipleChoiceCapable }!
        store.submitAdventureAnswer(question, selectedIndex: question.correctIndex!)
        let after = store.todaySession().count
        XCTAssertEqual(after, before - 1)
    }

    func testDrawEncounterDeckIsMCCapableAndInCategory() throws {
        let (store, _) = try makeStore()
        let drawn = store.drawEncounterDeck(count: 10, categories: [.regulations])
        XCTAssertEqual(drawn.count, 10)
        XCTAssertTrue(drawn.allSatisfy { $0.category == .regulations && $0.isMultipleChoiceCapable })
        let regulationsIDs = Set(store.bank.questions(in: .regulations).map(\.id))
        XCTAssertTrue(drawn.allSatisfy { regulationsIDs.contains($0.id) })
    }

    func testAdventureMasteryUsesReviewedRetention() throws {
        let (store, _) = try makeStore()
        let tenRegulations = store.bank.questions(in: .regulations).filter(\.isMultipleChoiceCapable).prefix(10)
        for question in tenRegulations {
            store.submitAdventureAnswer(question, selectedIndex: question.correctIndex!)
        }
        let mastery = store.adventureMastery(for: .regulations)
        XCTAssertGreaterThan(mastery.level.rawValue, MasteryLevel.novice.rawValue)
    }

    private func gymOpponent(gymID: GymID = .humanFactors, airportID: String = "KHYP", maxHP: Int) -> Opponent {
        Opponent(id: gymID.rawValue, name: "Dr. Hypoxia", nameplateName: "HYPOXIA", spriteID: "leader-hypoxia",
                 tier: .gym, maxHP: maxHP, gymID: gymID.rawValue, airportID: airportID)
    }

    private func championOpponent() -> Opponent {
        Opponent(id: "champion", name: "The DPE", nameplateName: "THE DPE", spriteID: "champion",
                 tier: .champion, maxHP: ChampionBattle.opponentHP)
    }

    func testFinishGymBattleAwardsBadgeXPAndBattleRecord() throws {
        let (store, container) = try makeStore()
        let deck = Array(store.bank.questions.filter { $0.category == .humanFactors && $0.isMultipleChoiceCapable }.prefix(10))
        let opening = BattleEngine.start(opponent: gymOpponent(maxHP: 1), deck: deck, playerMaxHP: 100)
        let (won, _) = BattleEngine.answer(opening, selectedIndex: opening.currentQuestion!.correctIndex!, answerSeconds: 10)
        XCTAssertEqual(won.outcome, .won)

        let save = store.finishBattle(won)
        XCTAssertEqual(save.badges, [.humanFactors])
        XCTAssertEqual(save.badgeQuestionIDs["humanFactors"], deck.map(\.id))
        XCTAssertEqual(store.totalXP, 100)
        XCTAssertTrue(store.earnedBadges.contains(.firstGymBadge))

        let records = try ModelContext(container).fetch(FetchDescriptor<BattleRecord>())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.won, true)
        XCTAssertEqual(records.first?.opponentID, "humanFactors")
    }

    func testFinishLostBattleAwardsNothingButKeepsReviews() throws {
        let (store, container) = try makeStore()
        let reviewedQuestion = store.bank.questions.first(where: \.isMultipleChoiceCapable)!
        store.submitAdventureAnswer(reviewedQuestion, selectedIndex: reviewedQuestion.correctIndex!)
        let xpBeforeBattle = store.totalXP

        let deck = Array(store.bank.questions.filter { $0.category == .humanFactors && $0.isMultipleChoiceCapable }.prefix(10))
        let opening = BattleEngine.start(opponent: gymOpponent(maxHP: 1_000), deck: deck, playerMaxHP: 100)
        let (lost, _) = BattleEngine.forfeit(opening)

        let save = store.finishBattle(lost)
        XCTAssertTrue(save.badges.isEmpty)
        XCTAssertEqual(save.battlesLost, 1)
        XCTAssertEqual(store.totalXP, xpBeforeBattle)
        XCTAssertFalse(store.earnedBadges.contains(.firstGymBadge))
        XCTAssertEqual(try ModelContext(container).fetch(FetchDescriptor<ReviewRecord>()).count, 1)
    }

    func testFinishForfeitedChampionBattleSkipsMockExam() throws {
        let (store, _) = try makeStore()
        let opening = BattleEngine.start(opponent: championOpponent(), deck: store.championDeck(),
                                         playerMaxHP: ChampionBattle.playerHP)
        let (forfeited, _) = BattleEngine.forfeit(opening)

        let save = store.finishBattle(forfeited)
        XCTAssertEqual(save.championWins, 0)
        XCTAssertFalse(store.earnedBadges.contains(.mockExamPassed))
        XCTAssertFalse(store.earnedBadges.contains(.regionChampion))
        XCTAssertEqual(store.totalXP, 0)
    }

    func testFinishChampionBattleAlsoFinishesMockExam() throws {
        let (store, _) = try makeStore()
        var state = BattleEngine.start(opponent: championOpponent(), deck: store.championDeck(),
                                       playerMaxHP: ChampionBattle.playerHP)
        while let question = state.currentQuestion {
            (state, _) = BattleEngine.answer(state, selectedIndex: question.correctIndex!, answerSeconds: 10)
        }
        XCTAssertEqual(state.outcome, .won)
        XCTAssertEqual(state.results.count, 60)

        let save = store.finishBattle(state)
        XCTAssertEqual(save.championWins, 1)
        XCTAssertEqual(store.totalXP, 300)
        XCTAssertTrue(store.earnedBadges.contains(.mockExamPassed))
        XCTAssertTrue(store.earnedBadges.contains(.regionChampion))
    }

    func testFinishEliteFourRunSetsClearedOnlyWhenRunIsCleared() throws {
        let (store, _) = try makeStore()
        let partial = EliteFourRun(memberIndex: 2, playerHP: 50, playerMaxHP: 100)
        let saveAfterPartial = store.finishEliteFourRun(partial)
        XCTAssertFalse(saveAfterPartial.eliteFourCleared)
        XCTAssertFalse(store.earnedBadges.contains(.eliteFourCleared))

        let cleared = EliteFourRun(memberIndex: 4, playerHP: 50, playerMaxHP: 100)
        let saveAfterCleared = store.finishEliteFourRun(cleared)
        XCTAssertTrue(saveAfterCleared.eliteFourCleared)
        XCTAssertTrue(store.earnedBadges.contains(.eliteFourCleared))
    }

    func testChampionDeckHasSixtyQuestionsInMockExamBlueprint() throws {
        let (store, _) = try makeStore()
        let deck = store.championDeck()
        XCTAssertEqual(deck.count, 60)
        for category in IFRCore.Category.allCases {
            XCTAssertEqual(deck.filter { $0.category == category }.count, category.examWeight)
        }
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `scripts/test-app.sh --filter AdventureStoreTests` (this machine cannot compile the App target; see below)
Expected: a compile error in `AppTests/AdventureStoreTests.swift` — `value of type 'StudyStore' has no member 'finishBattle'` (and likewise for `finishEliteFourRun` and `championDeck`) once Xcode resolves the file, since none of the three methods existed on `StudyStore` before this task. The six new test functions above (`testFinishGymBattleAwardsBadgeXPAndBattleRecord` through `testChampionDeckHasSixtyQuestionsInMockExamBlueprint`) were written against those not-yet-existing members before `StudyStore.swift` was touched.

- [ ] **Step 3: Write the implementation**

File: `App/Persistence/StudyStore.swift` (new methods added at the end of the existing `StudyStore` class, and `awardBadges` extended to read `AdventureSave` fields into `BadgeSnapshot`, because `context`, `addXP`, `awardBadges`, `saveContext`, `revision`, `finishQuiz`, `cardStates`, `bank`, `scheduler` and `rng` are all `private`)

```swift
    private func awardBadges(lastQuizPerfect: Bool = false, mockExamPassed: Bool = false) {
        let allReviews = (try? context.fetch(FetchDescriptor<ReviewRecord>())) ?? []
        // Distinct quiz days. When called from finishQuiz, today's quiz
        // answers are already in ReviewRecord, so today is already counted —
        // no extra +1. (Known v1 limitation: multiple quizzes in one day
        // count once; affects badge timing only.)
        let quizCount = Set(allReviews.filter(\.inQuiz).map { calendar.startOfDay(for: $0.date) }).count
        let previousDay = allReviews.map(\.date).filter { $0 < startOfToday }.max()
        let daysAway = previousDay.map {
            calendar.dateComponents([.day], from: calendar.startOfDay(for: $0), to: startOfToday).day ?? 0
        } ?? 0
        // Build card states ONCE for all 8 categories — mastery(for:) would
        // refetch every CardStateRecord per category.
        let states = cardStates
        let mastered = IFRCore.Category.allCases
            .filter { categoryRetention(for: $0, states: states).level == .instrumentMaster }
            .count
        let save = adventureSave
        let snapshot = BadgeSnapshot(
            totalReviews: allReviews.count, streak: streakRecord.current,
            lastQuizPerfect: lastQuizPerfect, mockExamPassed: mockExamPassed,
            masteredCategories: mastered, hourOfDay: calendar.component(.hour, from: .now),
            totalXP: totalXP, quizzesCompleted: quizCount, daysAwayBeforeToday: daysAway,
            gymBadges: save.badges.count, eliteFourCleared: save.eliteFourCleared,
            championDefeated: save.championWins > 0, bestTowerFloor: 0)
        for badge in BadgeEngine.newlyEarned(snapshot: snapshot, already: Set(earnedBadges)) {
            context.insert(BadgeRecord(badge: badge, earnedOn: .now))
        }
    }
```

```swift
    func updateAdventureSave(_ save: AdventureSave) {
        writeAdventureSave(save)
        saveContext()
        revision += 1
    }
```

```swift
    @discardableResult
    func finishBattle(_ state: BattleState) -> AdventureSave {
        let outcome = state.outcome ?? .lost
        let previous = adventureSave
        let next = BattleResolution.apply(outcome, opponent: state.opponent, deck: state.deck, to: previous, at: .now)
        insertBattleRecord(for: state, outcome: outcome)
        writeAdventureSave(next)
        awardBattleXP(state: state, outcome: outcome, previous: previous)
        awardBadges()
        saveContext()
        revision += 1
        return next
    }

    func finishEliteFourRun(_ run: EliteFourRun) -> AdventureSave {
        var next = adventureSave
        if run.isCleared {
            next.eliteFourCleared = true
        }
        writeAdventureSave(next)
        awardBadges()
        saveContext()
        revision += 1
        return next
    }

    func championDeck() -> [Question] {
        _ = revision
        return ChampionBattle.deck(bank: bank, states: cardStates, scheduler: scheduler, now: .now, using: &rng)
    }

    func badgeQuestionRetention() -> [GymID: Double] {
        _ = revision
        let states = cardStates
        return adventureSave.badgeQuestionIDs.reduce(into: [GymID: Double]()) { result, entry in
            guard let gymID = GymID(rawValue: entry.key) else { return }
            let values = entry.value.map { states[$0].map { scheduler.retrievability(of: $0, at: .now) } ?? 0 }
            result[gymID] = values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
        }
    }

    private func insertBattleRecord(for state: BattleState, outcome: BattleOutcome) {
        context.insert(BattleRecord(
            date: .now, tierRaw: state.opponent.tier.rawValue, opponentID: state.opponent.id,
            won: outcome == .won, correct: state.results.filter { $0 }.count, total: state.results.count))
    }

    private func awardBattleXP(state: BattleState, outcome: BattleOutcome, previous: AdventureSave) {
        guard outcome == .won else { return }
        addXP(XPEngine.points(for: battleWinEvent(for: state, previous: previous)), reason: "adventureWin")
        if state.opponent.tier == .champion && state.results.count == 60 {
            finishQuiz(results: state.results, isMockExam: true)
        }
    }

    private func battleWinEvent(for state: BattleState, previous: AdventureSave) -> XPEvent {
        switch state.opponent.tier {
        case .cloud: return .cloudCleared
        case .trainer: return .trainerDefeated
        case .gym: return .gymBadgeEarned(firstTime: isFirstGymWin(for: state, previous: previous))
        case .eliteFour: return .eliteMemberDefeated
        case .champion: return .championCrowned(firstTime: previous.championWins == 0)
        case .tower: return .towerFloorCleared
        case .link: return .linkBattleFinished
        }
    }

    private func isFirstGymWin(for state: BattleState, previous: AdventureSave) -> Bool {
        guard let gymID = state.opponent.gymID.flatMap(GymID.init(rawValue:)) else { return true }
        return !previous.badges.contains(gymID)
    }

    private func writeAdventureSave(_ save: AdventureSave) {
        if let encoded = try? JSONEncoder().encode(save) {
            let record = adventureSaveRecord
            record.json = encoded
            record.updatedOn = .now
        }
    }
```

- [ ] **Step 4: Run all core tests**

Run: `scripts/test-core.sh`
Expected: `Executed 207 tests, with 0 failures`

- [ ] **Step 5: Commit**

Run: `git add App/Persistence/StudyStore.swift AppTests/AdventureStoreTests.swift && git commit -m "M1-11c: Battle results"`

---

### Task M1-12a: Typewriter (Linux)

**Files:**
- Create: `IFRCore/Sources/IFRCore/Adventure/Pixel/Typewriter.swift`
- Test: `IFRCore/Tests/IFRCoreTests/TypewriterTests.swift`

**Interfaces:**
- Consumes: nothing from elsewhere in Adventure; only `Foundation`.
- Produces: `TypewriterPage: Equatable, Sendable { lines: [String] }` and `enum Typewriter { static func paginate(_ text: String, columns: Int = 28, rows: Int = 2) -> [TypewriterPage]; static func revealCost(of page: TypewriterPage, holding: Bool) -> [Int]; static func visibleCharacters(of page: TypewriterPage, atFrame: Int, holding: Bool) -> Int; static func isComplete(_ page: TypewriterPage, atFrame: Int, holding: Bool) -> Bool; static func cursorVisible(atFrame: Int) -> Bool }`, in `IFRCore/Sources/IFRCore/Adventure/Pixel/Typewriter.swift`, for the dialogue box the app builds in Milestone 1/2 screens.

- [ ] **Step 1: Write the failing tests**

File: `IFRCore/Tests/IFRCoreTests/TypewriterTests.swift`

```swift
import XCTest
@testable import IFRCore

final class TypewriterTests: XCTestCase {
    private let welcomeText = "Welcome to the Victor region. Dr. Hypoxia is waiting at KHYP."

    func testWrapsOnWordBoundaryAtTwentyEightColumns() {
        let pages = Typewriter.paginate(welcomeText, columns: 28, rows: 2)
        let lines = pages.flatMap { $0.lines }
        XCTAssertEqual(lines, ["Welcome to the Victor", "region. Dr. Hypoxia is", "waiting at KHYP."])
        for line in lines {
            XCTAssertLessThanOrEqual(line.count, 28)
        }
    }

    func testBreaksPagesEveryTwoRows() {
        let pages = Typewriter.paginate(welcomeText, columns: 28, rows: 2)
        XCTAssertEqual(pages.count, 2)
        XCTAssertEqual(pages[0].lines, ["Welcome to the Victor", "region. Dr. Hypoxia is"])
        XCTAssertEqual(pages[1].lines, ["waiting at KHYP."])
    }

    func testRevealsOneCharacterEveryTwoFrames() {
        let page = TypewriterPage(lines: ["Hello"])
        XCTAssertEqual(Typewriter.revealCost(of: page, holding: false), [2, 4, 6, 8, 10])
        XCTAssertEqual(Typewriter.visibleCharacters(of: page, atFrame: 5, holding: false), 2)
    }

    func testHoldingRevealsOneCharacterPerFrame() {
        let page = TypewriterPage(lines: ["Hello"])
        XCTAssertEqual(Typewriter.revealCost(of: page, holding: true), [1, 2, 3, 4, 5])
        XCTAssertEqual(Typewriter.visibleCharacters(of: page, atFrame: 3, holding: true), 3)
    }

    func testPeriodQuestionExclamationAddEightFramePause() {
        let periodPage = TypewriterPage(lines: ["Hi. X"])
        XCTAssertEqual(Typewriter.revealCost(of: periodPage, holding: false), [2, 4, 6, 16, 18])
        let questionPage = TypewriterPage(lines: ["Hi? X"])
        XCTAssertEqual(Typewriter.revealCost(of: questionPage, holding: false), [2, 4, 6, 16, 18])
        let exclamationPage = TypewriterPage(lines: ["Hi! X"])
        XCTAssertEqual(Typewriter.revealCost(of: exclamationPage, holding: false), [2, 4, 6, 16, 18])
    }

    func testCommaAddsFourFramePause() {
        let page = TypewriterPage(lines: ["Hi, X"])
        XCTAssertEqual(Typewriter.revealCost(of: page, holding: false), [2, 4, 6, 12, 14])
    }

    func testHoldingSkipsPunctuationPauses() {
        let page = TypewriterPage(lines: ["A. B"])
        XCTAssertEqual(Typewriter.revealCost(of: page, holding: true), [1, 2, 3, 4])
        XCTAssertTrue(Typewriter.isComplete(page, atFrame: 4, holding: true))
        XCTAssertFalse(Typewriter.isComplete(page, atFrame: 3, holding: true))
    }

    func testIsCompleteWhenAllCharactersVisible() {
        let page = TypewriterPage(lines: ["Hi"])
        XCTAssertFalse(Typewriter.isComplete(page, atFrame: 3, holding: false))
        XCTAssertTrue(Typewriter.isComplete(page, atFrame: 4, holding: false))
    }

    func testCursorBlinksWithThirtyFramePeriod() {
        XCTAssertTrue(Typewriter.cursorVisible(atFrame: 0))
        XCTAssertTrue(Typewriter.cursorVisible(atFrame: 14))
        XCTAssertFalse(Typewriter.cursorVisible(atFrame: 15))
        XCTAssertFalse(Typewriter.cursorVisible(atFrame: 29))
        XCTAssertTrue(Typewriter.cursorVisible(atFrame: 30))
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `scripts/test-core.sh --filter TypewriterTests`
Expected:
```
error: cannot find 'Typewriter' in scope
```
(nine such errors, one per call site, because `Typewriter` and `TypewriterPage` do not exist yet)

- [ ] **Step 3: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Pixel/Typewriter.swift`

```swift
import Foundation

public struct TypewriterPage: Equatable, Sendable {
    public let lines: [String]

    public init(lines: [String]) {
        self.lines = lines
    }
}

public enum Typewriter {
    public static func paginate(_ text: String, columns: Int = 28, rows: Int = 2) -> [TypewriterPage] {
        let wrapped = wrappedLines(text, columns: columns)
        return stride(from: 0, to: wrapped.count, by: rows).map { start in
            let end = min(start + rows, wrapped.count)
            return TypewriterPage(lines: Array(wrapped[start..<end]))
        }
    }

    public static func revealCost(of page: TypewriterPage, holding: Bool) -> [Int] {
        var costs: [Int] = []
        var running = 0
        var previous: Character?
        for character in page.lines.joined() {
            running += step(after: previous, holding: holding)
            costs.append(running)
            previous = character
        }
        return costs
    }

    public static func visibleCharacters(of page: TypewriterPage, atFrame: Int, holding: Bool) -> Int {
        revealCost(of: page, holding: holding).filter { $0 <= atFrame }.count
    }

    public static func isComplete(_ page: TypewriterPage, atFrame: Int, holding: Bool) -> Bool {
        guard let last = revealCost(of: page, holding: holding).last else { return true }
        return atFrame >= last
    }

    public static func cursorVisible(atFrame: Int) -> Bool {
        let period = 30
        let cycle = ((atFrame % period) + period) % period
        return cycle < period / 2
    }

    private static func step(after previous: Character?, holding: Bool) -> Int {
        let base = holding ? 1 : 2
        return base + pause(after: previous, holding: holding)
    }

    private static func pause(after previous: Character?, holding: Bool) -> Int {
        guard !holding, let previous else { return 0 }
        if ".?!".contains(previous) { return 8 }
        if previous == "," { return 4 }
        return 0
    }

    private static func wrappedLines(_ text: String, columns: Int) -> [String] {
        var lines: [String] = []
        var currentLine = ""
        for word in text.split(separator: " ", omittingEmptySubsequences: true) {
            let candidate = currentLine.isEmpty ? String(word) : "\(currentLine) \(word)"
            if candidate.count > columns {
                lines.append(currentLine)
                currentLine = String(word)
            } else {
                currentLine = candidate
            }
        }
        if !currentLine.isEmpty {
            lines.append(currentLine)
        }
        return lines
    }
}
```

- [ ] **Step 4: Run all core tests**

Run: `scripts/test-core.sh`
Expected: `Executed 85 tests, with 0 failures`

- [ ] **Step 5: Commit**

Run: `git add IFRCore/Sources/IFRCore/Adventure/Pixel/Typewriter.swift IFRCore/Tests/IFRCoreTests/TypewriterTests.swift && git commit -m "M1-12a: Typewriter (Linux)"`

---

### Task M1-12b: HP bar, wipe, intro, victory and defeat (Linux)

**Files:**
- Create: `IFRCore/Sources/IFRCore/Adventure/Pixel/HPBarAnimator.swift`
- Create: `IFRCore/Sources/IFRCore/Adventure/Pixel/BattleWipe.swift`
- Create: `IFRCore/Sources/IFRCore/Adventure/Pixel/BattleIntro.swift`
- Create: `IFRCore/Sources/IFRCore/Adventure/Pixel/VictoryAnimation.swift`
- Create: `IFRCore/Sources/IFRCore/Adventure/Pixel/DefeatAnimation.swift`
- Test: `IFRCore/Tests/IFRCoreTests/HPBarAnimatorTests.swift`
- Test: `IFRCore/Tests/IFRCoreTests/BattleWipeTests.swift`
- Test: `IFRCore/Tests/IFRCoreTests/BattleAnimationTests.swift`

**Interfaces:**
- Consumes: `PixelFrame.height` (`IFRCore/Sources/IFRCore/Adventure/Pixel/PixelFrame.swift`) for `BattleWipe`'s band geometry.
- Produces:
  - `HPBand` (`.green`, `.amber`, `.red`)
  - `HPBarAnimator.displayedHP(from:to:framesElapsed:) -> Int`
  - `HPBarAnimator.filledPixels(hp:max:width:) -> Int`
  - `HPBarAnimator.band(hp:max:) -> HPBand`
  - `HPBarAnimator.shakeOffset(atFrame:) -> Int`
  - `WipeFrame` (`flashWhite: Bool?`, `coveredRows: [Range<Int>]`)
  - `BattleWipe.totalFrames` (`40`), `BattleWipe.frame(_:) -> WipeFrame`
  - `BattleIntro.totalFrames` (`12`), `BattleIntro.slideOffset(atFrame:) -> (enemyX: Int, playerX: Int)`
  - `VictoryAnimation.dropOffset(atFrame:) -> Int?`, `VictoryAnimation.badgeScale(atFrame:) -> Int`
  - `DefeatAnimation.totalFrames` (`30`), `DefeatAnimation.fadeStep(atFrame:) -> Int`

  These are consumed by the M1-15 battle renderer and screen model.

- [ ] **Step 1: Write the failing tests**

File: `IFRCore/Tests/IFRCoreTests/HPBarAnimatorTests.swift`

```swift
import XCTest
@testable import IFRCore

final class HPBarAnimatorTests: XCTestCase {
    func testDisplayedHPStepsOneEveryTwoFrames() {
        XCTAssertEqual(HPBarAnimator.displayedHP(from: 20, to: 5, framesElapsed: 0), 20)
        XCTAssertEqual(HPBarAnimator.displayedHP(from: 20, to: 5, framesElapsed: 2), 19)
        XCTAssertEqual(HPBarAnimator.displayedHP(from: 20, to: 5, framesElapsed: 4), 18)
        XCTAssertEqual(HPBarAnimator.displayedHP(from: 0, to: 10, framesElapsed: 4), 2)
    }

    func testDisplayedHPNeverOvershootsTarget() {
        XCTAssertEqual(HPBarAnimator.displayedHP(from: 20, to: 5, framesElapsed: 100), 5)
        XCTAssertEqual(HPBarAnimator.displayedHP(from: 0, to: 10, framesElapsed: 100), 10)
    }

    func testFilledPixelsFloorsToWidth() {
        XCTAssertEqual(HPBarAnimator.filledPixels(hp: 42, max: 42, width: 48), 48)
        XCTAssertEqual(HPBarAnimator.filledPixels(hp: 25, max: 50, width: 48), 24)
        XCTAssertEqual(HPBarAnimator.filledPixels(hp: 1, max: 48, width: 48), 1)
    }

    func testBandThresholdsAtFiftyAndTwentyPercent() {
        XCTAssertEqual(HPBarAnimator.band(hp: 51, max: 100), .green)
        XCTAssertEqual(HPBarAnimator.band(hp: 50, max: 100), .amber)
        XCTAssertEqual(HPBarAnimator.band(hp: 20, max: 100), .amber)
        XCTAssertEqual(HPBarAnimator.band(hp: 19, max: 100), .red)
    }

    func testShakeOffsetsAreMinusTwoTwoMinusOneOneZero() {
        XCTAssertEqual(HPBarAnimator.shakeOffset(atFrame: 0), -2)
        XCTAssertEqual(HPBarAnimator.shakeOffset(atFrame: 2), 2)
        XCTAssertEqual(HPBarAnimator.shakeOffset(atFrame: 4), -1)
        XCTAssertEqual(HPBarAnimator.shakeOffset(atFrame: 6), 1)
        XCTAssertEqual(HPBarAnimator.shakeOffset(atFrame: 8), 0)
        XCTAssertEqual(HPBarAnimator.shakeOffset(atFrame: 9), 0)
    }
}
```

- [ ] **Step 2: Write the failing tests**

File: `IFRCore/Tests/IFRCoreTests/BattleWipeTests.swift`

```swift
import XCTest
@testable import IFRCore

final class BattleWipeTests: XCTestCase {
    func testTotalWipeFramesIsForty() {
        XCTAssertEqual(BattleWipe.totalFrames, 40)
    }

    func testFirstSixteenFramesAlternateFlashEveryFourFrames() {
        XCTAssertEqual(BattleWipe.frame(0).flashWhite, true)
        XCTAssertEqual(BattleWipe.frame(3).flashWhite, true)
        XCTAssertEqual(BattleWipe.frame(4).flashWhite, false)
        XCTAssertEqual(BattleWipe.frame(7).flashWhite, false)
        XCTAssertEqual(BattleWipe.frame(8).flashWhite, true)
        XCTAssertEqual(BattleWipe.frame(12).flashWhite, false)
        XCTAssertEqual(BattleWipe.frame(15).flashWhite, false)
        XCTAssertEqual(BattleWipe.frame(16).flashWhite, nil)
    }

    func testBandsCloseTowardCentreOverTwentyFourFrames() {
        func coveredCount(_ n: Int) -> Int {
            BattleWipe.frame(n).coveredRows.reduce(0) { $0 + $1.count }
        }
        XCTAssertEqual(coveredCount(16), 0)
        XCTAssertLessThan(coveredCount(20), coveredCount(30))
        XCTAssertLessThan(coveredCount(30), coveredCount(39))
    }

    func testFinalWipeFrameCoversEveryRow() {
        let frame = BattleWipe.frame(39)
        var covered = Set<Int>()
        for range in frame.coveredRows {
            covered.formUnion(range)
        }
        XCTAssertEqual(covered, Set(0..<PixelFrame.height))
    }
}
```

- [ ] **Step 3: Write the failing tests**

File: `IFRCore/Tests/IFRCoreTests/BattleAnimationTests.swift`

```swift
import XCTest
@testable import IFRCore

final class BattleAnimationTests: XCTestCase {
    func testIntroSlidesEnemyFromRightAndPlayerFromLeftInTwelveFrames() {
        XCTAssertEqual(BattleIntro.totalFrames, 12)
        let start = BattleIntro.slideOffset(atFrame: 0)
        XCTAssertEqual(start.enemyX, 240)
        XCTAssertEqual(start.playerX, -32)
        let end = BattleIntro.slideOffset(atFrame: 12)
        XCTAssertEqual(end.enemyX, 176)
        XCTAssertEqual(end.playerX, 24)
    }

    func testVictoryDropIsFourPixelsPerFrameThenNil() {
        XCTAssertEqual(VictoryAnimation.dropOffset(atFrame: 0), 4)
        XCTAssertEqual(VictoryAnimation.dropOffset(atFrame: 1), 8)
        XCTAssertEqual(VictoryAnimation.dropOffset(atFrame: 7), 32)
        XCTAssertNil(VictoryAnimation.dropOffset(atFrame: 8))
    }

    func testBadgeScaleGrowsOneToFourOverEightFrames() {
        XCTAssertEqual(VictoryAnimation.badgeScale(atFrame: 0), 1)
        XCTAssertEqual(VictoryAnimation.badgeScale(atFrame: 8), 4)
        XCTAssertLessThanOrEqual(VictoryAnimation.badgeScale(atFrame: 4), 4)
        XCTAssertGreaterThanOrEqual(VictoryAnimation.badgeScale(atFrame: 4), 1)
    }

    func testDefeatFadeStepReachesFifteenAtFrameThirty() {
        XCTAssertEqual(DefeatAnimation.totalFrames, 30)
        XCTAssertEqual(DefeatAnimation.fadeStep(atFrame: 0), 0)
        XCTAssertEqual(DefeatAnimation.fadeStep(atFrame: 30), 15)
    }
}
```

- [ ] **Step 4: Run the tests to verify they fail**

Run: `scripts/test-core.sh --filter HPBarAnimatorTests`
Expected:
```
/home/user/IFR-build-b/FlashCards/IFRCore/Tests/IFRCoreTests/HPBarAnimatorTests.swift:32:24: error: cannot find 'HPBarAnimator' in scope
```
(the same "cannot find type/enum in scope" compile error is produced for `BattleWipe`, `WipeFrame`, `BattleIntro`, `VictoryAnimation` and `DefeatAnimation` before their files exist; the whole test target fails to build.)

- [ ] **Step 5: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Pixel/HPBarAnimator.swift`

```swift
import Foundation

public enum HPBand: Equatable, Sendable {
    case green
    case amber
    case red
}

public enum HPBarAnimator {
    private static let shakeOffsets = [-2, 2, -1, 1, 0]

    public static func displayedHP(from: Int, to: Int, framesElapsed: Int) -> Int {
        let steps = framesElapsed / 2
        if from <= to {
            return min(to, from + steps)
        }
        return max(to, from - steps)
    }

    public static func filledPixels(hp: Int, max: Int, width: Int = 48) -> Int {
        guard max > 0 else { return 0 }
        return (hp * width) / max
    }

    public static func band(hp: Int, max: Int) -> HPBand {
        guard max > 0 else { return .red }
        let percent = (hp * 100) / max
        if percent > 50 { return .green }
        if percent >= 20 { return .amber }
        return .red
    }

    public static func shakeOffset(atFrame frame: Int) -> Int {
        let index = min(max(frame, 0) / 2, shakeOffsets.count - 1)
        return shakeOffsets[index]
    }
}
```

- [ ] **Step 6: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Pixel/BattleWipe.swift`

```swift
import Foundation

public struct WipeFrame: Equatable, Sendable {
    public let flashWhite: Bool?
    public let coveredRows: [Range<Int>]

    public init(flashWhite: Bool?, coveredRows: [Range<Int>]) {
        self.flashWhite = flashWhite
        self.coveredRows = coveredRows
    }
}

public enum BattleWipe {
    public static let totalFrames = 40
    private static let flashFrames = 16
    private static let bandCount = 8
    private static let bandHeight = PixelFrame.height / bandCount

    public static func frame(_ n: Int) -> WipeFrame {
        if n < flashFrames {
            return WipeFrame(flashWhite: (n / 4) % 2 == 0, coveredRows: [])
        }
        return WipeFrame(flashWhite: nil, coveredRows: closingBands(atFrame: n))
    }

    private static func closingBands(atFrame frame: Int) -> [Range<Int>] {
        let closingFrames = totalFrames - flashFrames
        let progress = min(frame - flashFrames + 1, closingFrames)
        let half = bandHeight / 2
        let coveredEachSide = (progress * half) / closingFrames
        guard coveredEachSide > 0 else { return [] }
        var rows: [Range<Int>] = []
        for band in 0..<bandCount {
            let start = band * bandHeight
            rows.append(start..<(start + coveredEachSide))
            rows.append((start + bandHeight - coveredEachSide)..<(start + bandHeight))
        }
        return rows
    }
}
```

- [ ] **Step 7: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Pixel/BattleIntro.swift`

```swift
import Foundation

public enum BattleIntro {
    public static let totalFrames = 12
    private static let enemyStartX = 240
    private static let enemyEndX = 176
    private static let playerStartX = -32
    private static let playerEndX = 24

    public static func slideOffset(atFrame frame: Int) -> (enemyX: Int, playerX: Int) {
        let clamped = min(max(frame, 0), totalFrames)
        let enemyX = enemyStartX + ((enemyEndX - enemyStartX) * clamped) / totalFrames
        let playerX = playerStartX + ((playerEndX - playerStartX) * clamped) / totalFrames
        return (enemyX, playerX)
    }
}
```

- [ ] **Step 8: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Pixel/VictoryAnimation.swift`

```swift
import Foundation

public enum VictoryAnimation {
    private static let dropFrames = 8
    private static let dropPixelsPerFrame = 4
    private static let badgeGrowFrames = 8
    private static let badgeMinScale = 1
    private static let badgeMaxScale = 4

    public static func dropOffset(atFrame frame: Int) -> Int? {
        guard frame >= 0, frame < dropFrames else { return nil }
        return (frame + 1) * dropPixelsPerFrame
    }

    public static func badgeScale(atFrame frame: Int) -> Int {
        let clamped = min(max(frame, 0), badgeGrowFrames)
        return badgeMinScale + ((badgeMaxScale - badgeMinScale) * clamped) / badgeGrowFrames
    }
}
```

- [ ] **Step 9: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Pixel/DefeatAnimation.swift`

```swift
import Foundation

public enum DefeatAnimation {
    public static let totalFrames = 30
    private static let maxFadeStep = 15

    public static func fadeStep(atFrame frame: Int) -> Int {
        let clamped = min(max(frame, 0), totalFrames)
        return (maxFadeStep * clamped) / totalFrames
    }
}
```

- [ ] **Step 10: Run all core tests**

Run: `scripts/test-core.sh`
Expected: `Executed 98 tests, with 0 failures`

- [ ] **Step 11: Commit**

Run: `git add FlashCards/IFRCore/Sources/IFRCore/Adventure/Pixel/HPBarAnimator.swift FlashCards/IFRCore/Sources/IFRCore/Adventure/Pixel/BattleWipe.swift FlashCards/IFRCore/Sources/IFRCore/Adventure/Pixel/BattleIntro.swift FlashCards/IFRCore/Sources/IFRCore/Adventure/Pixel/VictoryAnimation.swift FlashCards/IFRCore/Sources/IFRCore/Adventure/Pixel/DefeatAnimation.swift FlashCards/IFRCore/Tests/IFRCoreTests/HPBarAnimatorTests.swift FlashCards/IFRCore/Tests/IFRCoreTests/BattleWipeTests.swift FlashCards/IFRCore/Tests/IFRCoreTests/BattleAnimationTests.swift && git commit -m "M1-12b: HP bar, wipe, intro, victory and defeat"`

---

### Task M1-12c: Name plates (Linux)

**Files:**
- Create: `IFRCore/Sources/IFRCore/Adventure/Pixel/NamePlate.swift`
- Test: `IFRCore/Tests/IFRCoreTests/NamePlateTests.swift`

**Interfaces:**
- Consumes: `GridPoint` (`IFRCore/Sources/IFRCore/Adventure/Pixel/GridPoint.swift`)
- Produces: `NamePlate: Equatable, Sendable` with `origin: GridPoint`, `showsNumbers: Bool`, `static let enemy`, `static let player`, `var height: Int`, `var nameOrigin: GridPoint`, `var barOrigin: GridPoint`, `var numbersRightEdge: GridPoint?`

- [ ] **Step 1: Write the failing tests**

File: `IFRCore/Tests/IFRCoreTests/NamePlateTests.swift`

```swift
import XCTest
@testable import IFRCore

final class NamePlateTests: XCTestCase {
    func testEnemyPlateIsTwelveTallWithoutNumbers() {
        let plate = NamePlate.enemy
        XCTAssertEqual(plate.origin, GridPoint(x: 16, y: 16))
        XCTAssertEqual(plate.showsNumbers, false)
        XCTAssertEqual(plate.height, 12)
        XCTAssertNil(plate.numbersRightEdge)
    }

    func testPlayerPlateIsTwentyTallWithNumbersEndingAtSixtyTwo() {
        let plate = NamePlate.player
        XCTAssertEqual(plate.origin, GridPoint(x: 144, y: 80))
        XCTAssertEqual(plate.showsNumbers, true)
        XCTAssertEqual(plate.height, 20)
        XCTAssertEqual(plate.numbersRightEdge, GridPoint(x: 206, y: 92))
    }

    func testNameAndBarOriginsOffsetFromPlateOrigin() {
        for plate in [NamePlate.enemy, NamePlate.player] {
            let origin = plate.origin
            XCTAssertEqual(plate.nameOrigin, GridPoint(x: origin.x + 2, y: origin.y + 1))
            XCTAssertEqual(plate.barOrigin, GridPoint(x: origin.x + 8, y: origin.y + 7))
        }
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `scripts/test-core.sh --filter NamePlateTests`
Expected:
```
error: cannot find 'NamePlate' in scope
```
(three occurrences, one per test, plus a build failure: `error: fatalError`)

- [ ] **Step 3: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Pixel/NamePlate.swift`

```swift
import Foundation

public struct NamePlate: Equatable, Sendable {
    public let origin: GridPoint
    public let showsNumbers: Bool

    public init(origin: GridPoint, showsNumbers: Bool) {
        self.origin = origin
        self.showsNumbers = showsNumbers
    }

    public static let enemy = NamePlate(origin: GridPoint(x: 16, y: 16), showsNumbers: false)
    public static let player = NamePlate(origin: GridPoint(x: 144, y: 80), showsNumbers: true)

    public var height: Int {
        showsNumbers ? 20 : 12
    }

    public var nameOrigin: GridPoint {
        GridPoint(x: origin.x + 2, y: origin.y + 1)
    }

    public var barOrigin: GridPoint {
        GridPoint(x: origin.x + 8, y: origin.y + 7)
    }

    public var numbersRightEdge: GridPoint? {
        guard showsNumbers else { return nil }
        return GridPoint(x: origin.x + 62, y: origin.y + 12)
    }
}
```

- [ ] **Step 4: Run all core tests**

Run: `scripts/test-core.sh`
Expected: `Executed 101 tests, with 0 failures`

- [ ] **Step 5: Commit**

Run: `git add IFRCore/Sources/IFRCore/Adventure/Pixel/NamePlate.swift IFRCore/Tests/IFRCoreTests/NamePlateTests.swift && git commit -m "M1-12c: Name plates"`

---

### Task M1-13: Sprite art for Milestone 1 (Linux)

**Files:**
- Create: `IFRCore/Sources/IFRCore/Adventure/Pixel/Sprites/PlayerSprites.swift`
- Create: `IFRCore/Sources/IFRCore/Adventure/Pixel/Sprites/LeaderSprites.swift`
- Create: `IFRCore/Sources/IFRCore/Adventure/Pixel/Sprites/EliteSprites.swift`
- Modify: `IFRCore/Sources/IFRCore/Adventure/Pixel/Sprites/UISprites.swift`
- Modify: `IFRCore/Sources/IFRCore/Adventure/Pixel/SpriteCatalog.swift`
- Test: `IFRCore/Tests/IFRCoreTests/SpriteCatalogTests.swift`

**Interfaces:**
- Consumes: `PixelSprite` (`init(rows:) throws`, `subscript(x:y:)`, `recoloured(_:)`) from `IFRCore/Sources/IFRCore/Adventure/Pixel/PixelSprite.swift`; `Palette.transparent` from `IFRCore/Sources/IFRCore/Adventure/Pixel/Palette.swift`; the existing `SpriteCatalog.all` / `SpriteCatalog.sprite(named:)` from `IFRCore/Sources/IFRCore/Adventure/Pixel/SpriteCatalog.swift`.
- Produces: `PlayerSprites.all: [String: PixelSprite]` and `PlayerSprites.battleSilhouette: PixelSprite` (the shared 32x32 base silhouette other battle sprites recolour); `LeaderSprites.all: [String: PixelSprite]` with the eight `leader-*` IDs; `EliteSprites.all: [String: PixelSprite]` with the four `elite-*` IDs plus `champion`; `UISprites.all` extended with `airport` and the eight `badge-*` IDs; `SpriteCatalog.all` now merges all four per-file dictionaries, so every Milestone 1 sprite ID resolves through `SpriteCatalog.sprite(named:)`.

- [ ] **Step 1: Write the failing tests**

File: `IFRCore/Tests/IFRCoreTests/SpriteCatalogTests.swift`

```swift
import XCTest
@testable import IFRCore

final class SpriteCatalogTests: XCTestCase {
    private let battleSpriteIDs = [
        "player-back",
        "leader-hypoxia", "leader-gyro", "leader-reg", "leader-victor",
        "leader-plotter", "leader-nimbus", "leader-mayday", "leader-ilsa",
        "elite-sierra", "elite-tango", "elite-uniform", "elite-whiskey",
        "champion",
    ]

    private let smallSpriteIDs = [
        "badge-humanFactors", "badge-instrumentsAndSystems", "badge-regulations", "badge-navigation",
        "badge-chartsAndPlanning", "badge-weather", "badge-emergencies", "badge-approaches",
        "airport", "cursor",
    ]

    func testEveryCatalogSpriteParses() {
        XCTAssertFalse(SpriteCatalog.all.isEmpty)
        for id in battleSpriteIDs + smallSpriteIDs {
            XCTAssertNotNil(SpriteCatalog.sprite(named: id), id)
        }
    }

    func testBattleSpritesAreThirtyTwoSquare() {
        for id in battleSpriteIDs {
            let sprite = SpriteCatalog.sprite(named: id)
            XCTAssertEqual(sprite?.width, 32, id)
            XCTAssertEqual(sprite?.height, 32, id)
        }
    }

    func testBadgesAirportAndCursorAreEightSquare() {
        for id in smallSpriteIDs {
            let sprite = SpriteCatalog.sprite(named: id)
            XCTAssertEqual(sprite?.width, 8, id)
            XCTAssertEqual(sprite?.height, 8, id)
        }
    }

    func testEverySpriteUsesAtMostFourIndicesPlusTransparent() {
        for (id, sprite) in SpriteCatalog.all {
            var indices = Set<UInt8>()
            for y in 0..<sprite.height {
                for x in 0..<sprite.width {
                    let value = sprite[x, y]
                    if value != Palette.transparent {
                        indices.insert(value)
                    }
                }
            }
            XCTAssertLessThanOrEqual(indices.count, 4, id)
        }
    }

    func testMilestoneOneSpriteIDsExist() {
        for id in battleSpriteIDs + smallSpriteIDs {
            XCTAssertNotNil(SpriteCatalog.sprite(named: id), id)
        }
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `scripts/test-core.sh --filter SpriteCatalogTests`
Expected:
```
/home/user/IFR-build-b/FlashCards/IFRCore/Tests/IFRCoreTests/SpriteCatalogTests.swift:22: error: SpriteCatalogTests.testEveryCatalogSpriteParses : XCTAssertNotNil failed - player-back
...
Test Suite 'SpriteCatalogTests' failed at 2026-09-27 16:42:25.855
	 Executed 5 tests, with 92 failures (0 unexpected) in 0.003 (0.003) seconds
```
All 24 milestone-one sprite IDs were missing from `SpriteCatalog.all`, so `testEveryCatalogSpriteParses` and `testMilestoneOneSpriteIDsExist` failed with `XCTAssertNotNil failed` for each id; `testEverySpriteUsesAtMostFourIndicesPlusTransparent` passed vacuously since only `cursor` existed; the two shape tests failed too since `sprite(named:)` returned nil for every missing id.

- [ ] **Step 3: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Pixel/Sprites/PlayerSprites.swift`

```swift
import Foundation

public enum PlayerSprites {
    public static let all: [String: PixelSprite] = [
        "player-back": battleSilhouette,
    ]

    static let battleSilhouette = try! PixelSprite(rows: [
        "................................",
        "................................",
        "..............1111..............",
        "............11444411............",
        "...........1444444441...........",
        "...........1444444441...........",
        "...........1444444441...........",
        "...........1444444441...........",
        "...........1444444441...........",
        "...........1444444441...........",
        "............11444411............",
        "..............1441..............",
        "......11111111444411111111......",
        "......14444444499944444441......",
        "......14444444499944444441......",
        "......14444444499944444441......",
        "......14444444499944444441......",
        "......14444444499944444441......",
        "......14444444499944444441......",
        "......14444444499944444441......",
        "......14444444444444444441......",
        "......14444444444444444441......",
        "......11444444444444444411......",
        "........1444444444444441........",
        "........1444444444444441........",
        "........1444444444444441........",
        "........1444444444444441........",
        "........1444441111444441........",
        "........144441....144441........",
        "........144441....144441........",
        "........144441....144441........",
        "........111111....111111........",
    ])
}
```

- [ ] **Step 4: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Pixel/Sprites/LeaderSprites.swift`

```swift
import Foundation

public enum LeaderSprites {
    public static let all: [String: PixelSprite] = [
        "leader-hypoxia": hypoxia,
        "leader-gyro": gyro,
        "leader-reg": reg,
        "leader-victor": victor,
        "leader-plotter": plotter,
        "leader-nimbus": nimbus,
        "leader-mayday": mayday,
        "leader-ilsa": ilsa,
    ]

    private static let hypoxia = PlayerSprites.battleSilhouette.recoloured([1: 2, 4: 3, 9: 5])
    private static let gyro = PlayerSprites.battleSilhouette.recoloured([1: 4, 4: 5, 9: 6])
    private static let reg = PlayerSprites.battleSilhouette.recoloured([1: 7, 4: 8, 9: 9])
    private static let victor = PlayerSprites.battleSilhouette.recoloured([1: 10, 4: 11, 9: 12])
    private static let plotter = PlayerSprites.battleSilhouette.recoloured([1: 13, 4: 14, 9: 15])
    private static let nimbus = PlayerSprites.battleSilhouette.recoloured([1: 0, 4: 2, 9: 4])
    private static let mayday = PlayerSprites.battleSilhouette.recoloured([1: 1, 4: 3, 9: 5])
    private static let ilsa = PlayerSprites.battleSilhouette.recoloured([1: 6, 4: 8, 9: 10])
}
```

- [ ] **Step 5: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Pixel/Sprites/EliteSprites.swift`

```swift
import Foundation

public enum EliteSprites {
    public static let all: [String: PixelSprite] = [
        "elite-sierra": sierra,
        "elite-tango": tango,
        "elite-uniform": uniform,
        "elite-whiskey": whiskey,
        "champion": champion,
    ]

    private static let sierra = PlayerSprites.battleSilhouette.recoloured([1: 2, 4: 7, 9: 12])
    private static let tango = PlayerSprites.battleSilhouette.recoloured([1: 3, 4: 9, 9: 13])
    private static let uniform = PlayerSprites.battleSilhouette.recoloured([1: 5, 4: 10, 9: 14])
    private static let whiskey = PlayerSprites.battleSilhouette.recoloured([1: 1, 4: 6, 9: 11])
    private static let champion = PlayerSprites.battleSilhouette.recoloured([1: 7, 4: 11, 9: 15])
}
```

- [ ] **Step 6: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Pixel/Sprites/UISprites.swift` (complete new file)

```swift
import Foundation

public enum UISprites {
    public static let all: [String: PixelSprite] = [
        "cursor": cursor,
        "airport": airport,
        "badge-humanFactors": badgeHumanFactors,
        "badge-instrumentsAndSystems": badgeInstrumentsAndSystems,
        "badge-regulations": badgeRegulations,
        "badge-navigation": badgeNavigation,
        "badge-chartsAndPlanning": badgeChartsAndPlanning,
        "badge-weather": badgeWeather,
        "badge-emergencies": badgeEmergencies,
        "badge-approaches": badgeApproaches,
    ]

    private static let cursor = try! PixelSprite(rows: [
        "6.......",
        "66......",
        "666.....",
        "6666....",
        "666.....",
        "66......",
        "6.......",
        "........",
    ])

    private static let airport = try! PixelSprite(rows: [
        "...44...",
        "...44...",
        "...44...",
        "..4444..",
        ".444444.",
        "44444444",
        "...11...",
        "...11...",
    ])

    private static let badgeDiamond = try! PixelSprite(rows: [
        "........",
        "...99...",
        "..9779..",
        ".977779.",
        ".977779.",
        "..9779..",
        "...99...",
        "........",
    ])

    private static let badgeHumanFactors = badgeDiamond.recoloured([9: 2, 7: 5])
    private static let badgeInstrumentsAndSystems = badgeDiamond.recoloured([9: 4, 7: 6])
    private static let badgeRegulations = badgeDiamond.recoloured([9: 8, 7: 9])
    private static let badgeNavigation = badgeDiamond.recoloured([9: 10, 7: 12])
    private static let badgeChartsAndPlanning = badgeDiamond.recoloured([9: 13, 7: 15])
    private static let badgeWeather = badgeDiamond.recoloured([9: 0, 7: 2])
    private static let badgeEmergencies = badgeDiamond.recoloured([9: 1, 7: 3])
    private static let badgeApproaches = badgeDiamond.recoloured([9: 6, 7: 8])
}
```

- [ ] **Step 7: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Pixel/SpriteCatalog.swift` (complete new file)

```swift
import Foundation

public enum SpriteCatalog {
    public static let all: [String: PixelSprite] = UISprites.all
        .merging(PlayerSprites.all) { _, new in new }
        .merging(LeaderSprites.all) { _, new in new }
        .merging(EliteSprites.all) { _, new in new }

    public static func sprite(named name: String) -> PixelSprite? {
        all[name]
    }
}
```

- [ ] **Step 8: Run all core tests**

Run: `scripts/test-core.sh`
Expected: `Executed 106 tests, with 0 failures`

- [ ] **Step 9: Commit**

Run: `git add IFRCore/Sources/IFRCore/Adventure/Pixel/Sprites/PlayerSprites.swift IFRCore/Sources/IFRCore/Adventure/Pixel/Sprites/LeaderSprites.swift IFRCore/Sources/IFRCore/Adventure/Pixel/Sprites/EliteSprites.swift IFRCore/Sources/IFRCore/Adventure/Pixel/Sprites/UISprites.swift IFRCore/Sources/IFRCore/Adventure/Pixel/SpriteCatalog.swift IFRCore/Tests/IFRCoreTests/SpriteCatalogTests.swift && git commit -m "M1-13: Sprite art for Milestone 1"`

---

### Task M1-14: Region map screen and tab

**Files:**
- Create: `IFRCore/Sources/IFRCore/Adventure/Pixel/RegionMapRenderer.swift`
- Create: `App/Screens/Adventure/AdventureView.swift`
- Create: `App/Screens/Adventure/RegionMapScreen.swift`
- Create: `App/Screens/Adventure/DialogueBoxView.swift`
- Modify: `App/RootView.swift`
- Modify: `App/Notifications/NotificationScheduler.swift`
- Test: `IFRCore/Tests/IFRCoreTests/RegionMapRendererTests.swift`
- Test: `AppTests/NotificationSchedulerTests.swift`
- Test: `AppUITests/SmokeTests.swift`

**Interfaces:**
- Consumes: `RegionMap`, `Airport`, `AirportRole`, `Airway` (`IFRCore/Sources/IFRCore/Adventure/Content/RegionMap.swift`); `GymID`, `AdventureSave` (`Adventure/Circuit/GymID.swift`, `Adventure/Circuit/AdventureSave.swift`); `CircuitRules.isUnlocked/isEliteFourUnlocked/isChampionUnlocked` (`Adventure/Circuit/CircuitRules.swift`); `PixelFrame`, `GridPoint`, `PixelRect`, `SpriteCatalog.sprite(named:)`, `PixelSprite.recoloured(_:)` (`Adventure/Pixel/`); `AdventureContent`, `Gym`, `DialogueScript`, `SystemDialogueKey`, `AdventureContent.systemLine(_:filling:)` (`Adventure/Content/`); `OpponentHP.tuned(for:)`, `PlayerHP.maximum(for:)`, `Gym.opponent(maxHP:airportID:)` (`Adventure/Battle/`); `Typewriter.paginate/visibleCharacters/isComplete` (`Adventure/Pixel/Typewriter.swift`); app-side `StudyStore.adventureSave`, `drawEncounterDeck(count:categories:)`, `adventureMastery(for:)` (`App/Persistence/StudyStore.swift`); `BattleRun` (`App/Screens/Adventure/BattleRun.swift`); `BattleScreen`, `GBAScreen`, `RetroTheme.pixelFont(size:)`, `RetroTheme.pixelFontSize(scale:displayScale:)`, `Haptics.tick()`, `IntegerScaler.scale(viewWidth:viewHeight:displayScale:)`.
- Produces: `enum RegionMapRenderer { static let cellSize = 8; static let columns = 30; static let rows = 14; static func frame(region: RegionMap, save: AdventureSave, nextGym: GymID?, selected: String?) -> PixelFrame; static func cell(containing point: GridPoint) -> GridPoint }`, used by `RegionMapScreen` and by later work items (M1-16 and the overworld) for the same cell arithmetic; `struct AdventureView: View` (the fifth tab root); `struct RegionMapScreen: View` (buttons `airport-<id>`, `gym-<gymID>`, `badgeCase`, `hallOfFame`, identifier `regionMap`); `struct DialogueBoxView: View` (typewriter dialogue box reused by future battle/overworld screens); `AppTab.adventure` case; `NotificationScheduler.handledTab` mapping `"adventure"` to `.adventure`.

- [ ] **Step 1: Write the failing tests**

File: `IFRCore/Tests/IFRCoreTests/RegionMapRendererTests.swift`

```swift
import XCTest
@testable import IFRCore

final class RegionMapRendererTests: XCTestCase {
    private func makeAirport(
        id: String, x: Int, y: Int, gymID: GymID? = nil, role: AirportRole = .gym
    ) -> Airport {
        Airport(id: id, name: id, position: GridPoint(x: x, y: y), gymID: gymID, role: role)
    }

    private func makeSave(badges: Set<GymID> = []) -> AdventureSave {
        var save = AdventureSave.new
        save.badges = badges
        return save
    }

    private func pixel(_ frame: PixelFrame, _ x: Int, _ y: Int) -> UInt8 {
        frame.pixels[y * PixelFrame.width + x]
    }

    private func cellPixels(_ frame: PixelFrame, cell: GridPoint) -> [UInt8] {
        let originX = cell.x * RegionMapRenderer.cellSize
        let originY = cell.y * RegionMapRenderer.cellSize
        var values: [UInt8] = []
        for y in originY..<(originY + RegionMapRenderer.cellSize) {
            for x in originX..<(originX + RegionMapRenderer.cellSize) {
                values.append(pixel(frame, x, y))
            }
        }
        return values
    }

    func testLockedAirportsUseGreyIndex() {
        let khyp = makeAirport(id: "KHYP", x: 3, y: 12, gymID: .humanFactors, role: .gym)
        let region = RegionMap(airports: [khyp], airways: [])
        let frame = RegionMapRenderer.frame(region: region, save: makeSave(), nextGym: .instrumentsAndSystems, selected: nil)
        let cell = cellPixels(frame, cell: GridPoint(x: 3, y: 12))
        XCTAssertTrue(cell.contains(13))
        XCTAssertFalse(cell.contains(4))
        XCTAssertFalse(cell.contains(7))
    }

    func testBadgedAirportsUseAccentIndex() {
        let khyp = makeAirport(id: "KHYP", x: 3, y: 12, gymID: .humanFactors, role: .gym)
        let region = RegionMap(airports: [khyp], airways: [])
        let frame = RegionMapRenderer.frame(region: region, save: makeSave(badges: [.humanFactors]), nextGym: nil, selected: nil)
        let cell = cellPixels(frame, cell: GridPoint(x: 3, y: 12))
        XCTAssertTrue(cell.contains(4))
    }

    func testNextGymUsesAmberIndex() {
        let khyp = makeAirport(id: "KHYP", x: 3, y: 12, gymID: .humanFactors, role: .gym)
        let region = RegionMap(airports: [khyp], airways: [])
        let frame = RegionMapRenderer.frame(region: region, save: makeSave(), nextGym: .humanFactors, selected: nil)
        let cell = cellPixels(frame, cell: GridPoint(x: 3, y: 12))
        XCTAssertTrue(cell.contains(7))
    }

    func testAirwaysDrawnBetweenAirportCellCentres() {
        let khyp = makeAirport(id: "KHYP", x: 3, y: 12, gymID: .humanFactors, role: .gym)
        let kgyr = makeAirport(id: "KGYR", x: 9, y: 10, gymID: .instrumentsAndSystems, role: .gym)
        let airway = Airway(id: "V1", from: "KHYP", to: "KGYR")
        let region = RegionMap(airports: [khyp, kgyr], airways: [airway])
        let frame = RegionMapRenderer.frame(region: region, save: makeSave(), nextGym: nil, selected: nil)
        XCTAssertEqual(pixel(frame, 52, 92), 11)
    }

    func testCellContainingPointDividesByEight() {
        XCTAssertEqual(RegionMapRenderer.cell(containing: GridPoint(x: 20, y: 12)), GridPoint(x: 2, y: 1))
        XCTAssertEqual(RegionMapRenderer.cell(containing: GridPoint(x: 7, y: 7)), GridPoint(x: 0, y: 0))
        XCTAssertEqual(RegionMapRenderer.cell(containing: GridPoint(x: 239, y: 111)), GridPoint(x: 29, y: 13))
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `scripts/test-core.sh --filter RegionMapRendererTests`
Expected: `error: cannot find 'RegionMapRenderer' in scope` (also `'nil' requires a contextual type` at the call sites, from the missing `nextGym`/`selected` parameter types), reported for every use of `RegionMapRenderer` in the new test file.

- [ ] **Step 3: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Pixel/RegionMapRenderer.swift`

```swift
import Foundation

public enum RegionMapRenderer {
    public static let cellSize = 8
    public static let columns = 30
    public static let rows = 14

    private static let panelIndex: UInt8 = 1
    private static let airwayIndex: UInt8 = 11
    private static let lockedIndex: UInt8 = 13
    private static let badgedIndex: UInt8 = 4
    private static let nextGymIndex: UInt8 = 7
    private static let waypointIndex: UInt8 = 14
    private static let dialogueOuter: UInt8 = 6
    private static let dialogueInner: UInt8 = 0
    private static let dialogueBox = PixelRect(x: 0, y: 112, width: 240, height: 48)

    public static func frame(region: RegionMap, save: AdventureSave, nextGym: GymID?, selected: String?) -> PixelFrame {
        var canvas = PixelFrame(fill: panelIndex)
        drawAirways(&canvas, region: region)
        drawAirports(&canvas, region: region, save: save, nextGym: nextGym)
        canvas.frame(dialogueBox, outer: dialogueOuter, inner: dialogueInner)
        return canvas
    }

    public static func cell(containing point: GridPoint) -> GridPoint {
        GridPoint(x: point.x / cellSize, y: point.y / cellSize)
    }

    private static func drawAirways(_ canvas: inout PixelFrame, region: RegionMap) {
        let airportsByID = Dictionary(uniqueKeysWithValues: region.airports.map { ($0.id, $0) })
        for airway in region.airways {
            guard let from = airportsByID[airway.from], let to = airportsByID[airway.to] else { continue }
            canvas.line(from: cellCentre(of: from.position), to: cellCentre(of: to.position), index: airwayIndex)
        }
    }

    private static func drawAirports(
        _ canvas: inout PixelFrame, region: RegionMap, save: AdventureSave, nextGym: GymID?
    ) {
        guard let sprite = SpriteCatalog.sprite(named: "airport") else { return }
        for airport in region.airports {
            let colour = colourIndex(for: airport, save: save, nextGym: nextGym)
            let recoloured = sprite.recoloured([badgedIndex: colour])
            let origin = GridPoint(x: airport.position.x * cellSize, y: airport.position.y * cellSize)
            canvas.blit(recoloured, at: origin)
        }
    }

    private static func colourIndex(for airport: Airport, save: AdventureSave, nextGym: GymID?) -> UInt8 {
        switch airport.role {
        case .waypoint:
            return waypointIndex
        case .gym:
            return gymColourIndex(airport.gymID, save: save, nextGym: nextGym)
        case .eliteFour:
            return CircuitRules.isEliteFourUnlocked(save: save) ? nextGymIndex : lockedIndex
        case .champion:
            return CircuitRules.isChampionUnlocked(save: save) ? nextGymIndex : lockedIndex
        }
    }

    private static func gymColourIndex(_ gymID: GymID?, save: AdventureSave, nextGym: GymID?) -> UInt8 {
        guard let gymID else { return lockedIndex }
        if save.badges.contains(gymID) { return badgedIndex }
        if gymID == nextGym { return nextGymIndex }
        return lockedIndex
    }

    private static func cellCentre(of position: GridPoint) -> GridPoint {
        GridPoint(x: position.x * cellSize + cellSize / 2, y: position.y * cellSize + cellSize / 2)
    }
}
```

- [ ] **Step 4: Write the app-target files**

File: `App/Screens/Adventure/DialogueBoxView.swift`

```swift
import SwiftUI
import IFRCore

struct DialogueBoxView: View {
    let script: DialogueScript
    let scale: Int
    let displayScale: CGFloat
    var onFinished: () -> Void = {}

    @State private var pageIndex = 0
    @State private var phaseStart = Date()

    private var pages: [TypewriterPage] {
        script.pages.flatMap { Typewriter.paginate($0) }
    }

    var body: some View {
        TimelineView(.animation) { context in
            let frame = frameIndex(at: context.date)
            let page = currentPage
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(visibleLines(of: page, atFrame: frame).enumerated()), id: \.offset) { _, line in
                    Text(line)
                }
            }
            .font(RetroTheme.pixelFont(size: RetroTheme.pixelFontSize(scale: scale, displayScale: displayScale)))
            .foregroundStyle(.white)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { advance(atFrame: frame) }
        }
    }

    private var currentPage: TypewriterPage {
        pages.indices.contains(pageIndex) ? pages[pageIndex] : TypewriterPage(lines: [])
    }

    private func frameIndex(at date: Date) -> Int {
        max(0, Int(date.timeIntervalSince(phaseStart) * 60))
    }

    private func visibleLines(of page: TypewriterPage, atFrame frame: Int) -> [String] {
        var remaining = Typewriter.visibleCharacters(of: page, atFrame: frame, holding: false)
        return page.lines.map { line in
            let count = min(remaining, line.count)
            remaining -= count
            return String(line.prefix(count))
        }
    }

    private func advance(atFrame frame: Int) {
        Haptics.tick()
        guard Typewriter.isComplete(currentPage, atFrame: frame, holding: false) else { return }
        if pageIndex + 1 < pages.count {
            pageIndex += 1
            phaseStart = Date()
        } else {
            onFinished()
        }
    }
}
```

File: `App/Screens/Adventure/AdventureView.swift`

```swift
import SwiftUI
import IFRCore

struct AdventureView: View {
    @Environment(StudyStore.self) private var store
    @State private var content: AdventureContent?
    @State private var activeBattle: BattleRun?

    private let seed: UInt64?

    init() {
        seed = AdventureView.readSeedArgument(CommandLine.arguments)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let content {
                    RegionMapScreen(content: content, startBattle: { activeBattle = $0 })
                } else {
                    ProgressView()
                        .onAppear { content = try? AdventureContent.load() }
                }
            }
        }
        .fullScreenCover(item: $activeBattle) { run in
            BattleScreen(run: run)
        }
    }

    private static func readSeedArgument(_ arguments: [String]) -> UInt64? {
        guard let flagIndex = arguments.firstIndex(of: "-adventureSeed"),
              arguments.indices.contains(flagIndex + 1) else { return nil }
        return UInt64(arguments[flagIndex + 1])
    }
}
```

File: `App/Screens/Adventure/RegionMapScreen.swift`

```swift
import SwiftUI
import IFRCore

struct RegionMapScreen: View {
    @Environment(StudyStore.self) private var store
    @Environment(\.displayScale) private var displayScale
    let content: AdventureContent
    let startBattle: (BattleRun) -> Void

    @State private var dialogue: DialogueScript?
    @State private var challengeableGymID: GymID?

    var body: some View {
        GeometryReader { geometry in
            let scale = IntegerScaler.scale(
                viewWidth: geometry.size.width, viewHeight: geometry.size.height, displayScale: displayScale)
            ZStack {
                GBAScreen(frame: mapFrame)
                ForEach(content.region.airports, id: \.id) { airport in
                    airportButton(airport, scale: scale)
                }
                if let dialogue {
                    DialogueBoxView(script: dialogue, scale: scale, displayScale: displayScale,
                                    onFinished: { self.dialogue = nil })
                }
                if let challengeableGymID {
                    challengeButton(challengeableGymID)
                }
            }
        }
        .accessibilityIdentifier("regionMap")
        .toolbar {
            ToolbarItem { Button("Badges") {}.accessibilityIdentifier("badgeCase") }
            ToolbarItem { Button("Hall of Fame") {}.accessibilityIdentifier("hallOfFame") }
        }
    }

    private var mapFrame: PixelFrame {
        RegionMapRenderer.frame(region: content.region, save: store.adventureSave, nextGym: nextGym, selected: nil)
    }

    private var nextGym: GymID? {
        GymID.allCases.first { !store.adventureSave.badges.contains($0) }
    }

    private func airportButton(_ airport: Airport, scale: Int) -> some View {
        let side = CGFloat(RegionMapRenderer.cellSize * scale) / displayScale
        let originX = CGFloat(airport.position.x * RegionMapRenderer.cellSize * scale) / displayScale
        let originY = CGFloat(airport.position.y * RegionMapRenderer.cellSize * scale) / displayScale
        return Color.clear
            .frame(width: side, height: side)
            .contentShape(Rectangle())
            .position(x: originX + side / 2, y: originY + side / 2)
            .onTapGesture { tap(airport) }
            .accessibilityIdentifier("airport-\(airport.id)")
    }

    private func challengeButton(_ gymID: GymID) -> some View {
        Button("Challenge") { startGymBattle(gymID) }
            .accessibilityIdentifier("gym-\(gymID.rawValue)")
    }

    private func tap(_ airport: Airport) {
        guard airport.role == .gym, let gymID = airport.gymID,
              let gym = content.gyms.first(where: { $0.id == gymID }) else { return }
        if CircuitRules.isUnlocked(gymID, save: store.adventureSave) {
            dialogue = content.dialogue[gym.dialogue.intro]
            challengeableGymID = gymID
        } else {
            dialogue = content.systemLine(.gymLocked, filling: ["badge": previousBadgeName(before: gymID)])
            challengeableGymID = nil
        }
    }

    private func previousBadgeName(before gymID: GymID) -> String {
        guard let previous = gymID.previous, let previousGym = content.gyms.first(where: { $0.id == previous })
        else { return "" }
        return previousGym.badgeName
    }

    private func startGymBattle(_ gymID: GymID) {
        guard let airport = content.region.airports.first(where: { $0.gymID == gymID }),
              let gym = content.gyms.first(where: { $0.id == gymID }) else { return }
        let deck = store.drawEncounterDeck(count: gym.questionCount, categories: [gymID.category])
        let opponent = gym.opponent(maxHP: OpponentHP.tuned(for: deck), airportID: airport.id)
        let level = store.adventureMastery(for: gymID.category).level
        let run = BattleRun(
            opponent: opponent, deck: deck, playerMaxHP: PlayerHP.maximum(for: level), missDamage: nil,
            playerSpriteID: "player-back", playerPlateName: "PILOT",
            introDialogue: content.dialogue[gym.dialogue.intro] ?? DialogueScript(pages: []),
            winDialogue: content.dialogue[gym.dialogue.win] ?? DialogueScript(pages: []),
            loseDialogue: content.dialogue[gym.dialogue.lose] ?? DialogueScript(pages: []),
            firstTime: !store.adventureSave.badges.contains(gymID), returnTo: nil)
        challengeableGymID = nil
        startBattle(run)
    }
}
```

File: `App/RootView.swift` (changed lines)

```swift
enum AppTab: Hashable {
    case today, study, quiz, progress, adventure
}
```

```swift
            ProgressTabView()
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(AppTab.progress)
            AdventureView()
                .tabItem { Label("Adventure", systemImage: "gamecontroller.fill") }
                .tag(AppTab.adventure)
        }
```

File: `App/Notifications/NotificationScheduler.swift` (changed lines)

```swift
    static func handledTab(from userInfo: [AnyHashable: Any]) -> AppTab? {
        switch userInfo["tab"] as? String {
        case "study": .study
        case "today": .today
        case "adventure": .adventure
        default: nil
        }
    }
```

File: `AppTests/NotificationSchedulerTests.swift` (added test)

```swift
    func testHandledTabMapsAdventure() {
        XCTAssertEqual(NotificationScheduler.handledTab(from: ["tab": "adventure"]), .adventure)
    }
```

File: `AppUITests/SmokeTests.swift` (added test)

```swift
    func testAdventureTabShowsRegionMap() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["Adventure"].tap()
        XCTAssertTrue(app.otherElements["regionMap"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["airport-KHYP"].isHittable)
        XCTAssertTrue(app.buttons["badgeCase"].exists)
        XCTAssertTrue(app.buttons["hallOfFame"].exists)
    }
```

Expected for the app-target additions (not run on this Linux machine; `NotificationSchedulerTests` runs under `IFRFlashCardsTests` and `SmokeTests` under `IFRFlashCardsUITests` in Xcode on the iPhone 16 simulator via `scripts/test-app.sh`): `testHandledTabMapsAdventure` passes once `AppTab` gains `.adventure` and `handledTab` maps `"adventure"`; `testAdventureTabShowsRegionMap` passes once the fifth "Adventure" tab button exists, `RegionMapScreen`'s root view carries the `regionMap` accessibility identifier, and the `airport-KHYP`, `badgeCase` and `hallOfFame` controls are present and hittable — the same identifiers the already-committed `testStartingFirstGymShowsQuestionAndOptions`, `testAnsweringOptionAdvancesTurn` and `testBattleQuitReturnsToRegionMap` depend on.

- [ ] **Step 5: Run all core tests**

Run: `scripts/test-core.sh`
Expected: `Executed 216 tests, with 0 failures (0 unexpected) in 0.584 (0.584) seconds`

- [ ] **Step 6: Commit**

Run: `git add FlashCards/IFRCore/Sources/IFRCore/Adventure/Pixel/RegionMapRenderer.swift FlashCards/IFRCore/Tests/IFRCoreTests/RegionMapRendererTests.swift FlashCards/App/Screens/Adventure/AdventureView.swift FlashCards/App/Screens/Adventure/RegionMapScreen.swift FlashCards/App/Screens/Adventure/DialogueBoxView.swift FlashCards/App/RootView.swift FlashCards/App/Notifications/NotificationScheduler.swift FlashCards/AppTests/NotificationSchedulerTests.swift FlashCards/AppUITests/SmokeTests.swift && git commit -m "M1-14: Region map screen and tab"`

For app-target work use `scripts/test-app.sh` in the Run lines above; the Expected lines for `testHandledTabMapsAdventure` and `testAdventureTabShowsRegionMap` state what Xcode will show, as noted under Step 4, since these two tests cannot be compiled or run on this Linux machine.

---

### Task M1-15: Battle screen (Linux then Xcode)

**Files:**
- Create: `IFRCore/Sources/IFRCore/Adventure/Pixel/BattleRenderer.swift`
- Create: `App/Screens/Adventure/BattleRun.swift`
- Create: `App/Screens/Adventure/BattleScreenModel.swift`
- Create: `App/Screens/Adventure/BattleOptionsView.swift`
- Create: `App/Screens/Adventure/HPBarView.swift`
- Create: `App/Screens/Adventure/BattleScreen.swift`
- Test: `IFRCore/Tests/IFRCoreTests/BattleRendererTests.swift`
- Test: `AppTests/BattleScreenModelTests.swift`
- Test: `AppUITests/SmokeTests.swift` (three tests appended)

**Interfaces:**
- Consumes: `BattleState`, `BattleEngine.start/answer/forfeit`, `Opponent`, `BattleTier` (`IFRCore/Sources/IFRCore/Adventure/Battle/*.swift`); `NamePlate` (`Pixel/NamePlate.swift`); `HPBarAnimator`, `BattleWipe`, `BattleIntro` (`Pixel/HPBarAnimator.swift`, `Pixel/BattleWipe.swift`, `Pixel/BattleIntro.swift`); `PixelFrame`, `PixelRect`, `GridPoint`, `Palette` (`Pixel/PixelFrame.swift`, `Pixel/PixelRect.swift`, `Pixel/GridPoint.swift`, `Pixel/Palette.swift`); `SpriteCatalog` (`Pixel/SpriteCatalog.swift`); `SeededRNG` (`IFRCore/Sources/IFRCore/Quiz/QuizEngine.swift`); `DialogueScript` (`Adventure/Content/DialogueScript.swift`); app-side `StudyStore`, `GBAScreen`, `RetroTheme`, `SourceSheet`, `IntegerScaler` (`App/Persistence/StudyStore.swift`, `App/Screens/Adventure/GBAScreen.swift`, `App/Theme/RetroTheme.swift`, `App/Screens/Study/SourceSheet.swift`).
- Produces: `public enum BattlePhase { case wipe, intro, asking, resolving, ended }`; `public enum BattleRenderer { static func frame(state: BattleState, displayedPlayerHP: Int, displayedOpponentHP: Int, playerSpriteID: String, atFrame: Int, phase: BattlePhase) -> PixelFrame }`; `struct BattleRun: Identifiable`; `@Observable @MainActor final class BattleScreenModel`; `struct BattleOptionsView: View`; `struct HPBarView: View`; `struct BattleScreen: View`. M1-16 (Elite Four/Champion) presents further `BattleRun`s through `BattleScreen` and reuses `BattleScreenModel`.

- [ ] **Step 1: Write the failing tests (BattleRenderer, Linux)**

File: `IFRCore/Tests/IFRCoreTests/BattleRendererTests.swift`

```swift
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
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `scripts/test-core.sh --filter BattleRendererTests`
Expected: `error: cannot find 'BattleRenderer' in scope` (and a cascading `error: cannot infer contextual base in reference to member 'asking'`), confirmed by moving the not-yet-written implementation file aside and running the filtered suite before restoring it.

- [ ] **Step 3: Write the implementation (BattleRenderer, Linux)**

File: `IFRCore/Sources/IFRCore/Adventure/Pixel/BattleRenderer.swift`

```swift
import Foundation

public enum BattlePhase: Equatable, Sendable {
    case wipe, intro, asking, resolving, ended
}

public enum BattleRenderer {
    private static let opponentOrigin = GridPoint(x: 176, y: 8)
    private static let playerOrigin = GridPoint(x: 24, y: 64)
    private static let plateWidth = 64
    private static let plateBackground: UInt8 = 6
    private static let barWidth = 48
    private static let barHeight = 4
    private static let flashWhiteIndex: UInt8 = 15
    private static let flashInkIndex: UInt8 = 0
    private static let panelIndex: UInt8 = 1

    public static func frame(
        state: BattleState,
        displayedPlayerHP: Int,
        displayedOpponentHP: Int,
        playerSpriteID: String,
        atFrame frame: Int,
        phase: BattlePhase
    ) -> PixelFrame {
        var canvas = PixelFrame(fill: panelIndex)
        if phase == .wipe {
            applyWipe(&canvas, atFrame: frame)
            return canvas
        }
        drawSprites(&canvas, state: state, playerSpriteID: playerSpriteID, phase: phase, atFrame: frame)
        drawPlate(&canvas, plate: .enemy, hp: displayedOpponentHP, maxHP: state.opponent.maxHP)
        drawPlate(&canvas, plate: .player, hp: displayedPlayerHP, maxHP: state.playerMaxHP)
        return canvas
    }

    private static func drawSprites(
        _ canvas: inout PixelFrame, state: BattleState, playerSpriteID: String,
        phase: BattlePhase, atFrame frame: Int
    ) {
        let offsets = spriteOffsets(phase: phase, atFrame: frame)
        blitIfKnown(&canvas, spriteID: state.opponent.spriteID, at: GridPoint(x: offsets.enemyX, y: opponentOrigin.y))
        blitIfKnown(&canvas, spriteID: playerSpriteID, at: GridPoint(x: offsets.playerX, y: playerOrigin.y))
    }

    private static func spriteOffsets(phase: BattlePhase, atFrame frame: Int) -> (enemyX: Int, playerX: Int) {
        guard phase == .intro else { return (opponentOrigin.x, playerOrigin.x) }
        return BattleIntro.slideOffset(atFrame: frame)
    }

    private static func blitIfKnown(_ canvas: inout PixelFrame, spriteID: String, at point: GridPoint) {
        guard let sprite = SpriteCatalog.sprite(named: spriteID) else { return }
        canvas.blit(sprite, at: point)
    }

    private static func drawPlate(_ canvas: inout PixelFrame, plate: NamePlate, hp: Int, maxHP: Int) {
        let rect = PixelRect(x: plate.origin.x, y: plate.origin.y, width: plateWidth, height: plate.height)
        canvas.fill(rect, index: plateBackground)
        drawBar(&canvas, origin: plate.barOrigin, hp: hp, max: maxHP)
    }

    private static func drawBar(_ canvas: inout PixelFrame, origin: GridPoint, hp: Int, max: Int) {
        let filled = HPBarAnimator.filledPixels(hp: hp, max: max, width: barWidth)
        guard filled > 0 else { return }
        let index = colorIndex(for: HPBarAnimator.band(hp: hp, max: max))
        canvas.fill(PixelRect(x: origin.x, y: origin.y, width: filled, height: barHeight), index: index)
    }

    private static func colorIndex(for band: HPBand) -> UInt8 {
        switch band {
        case .green: return 4
        case .amber: return 7
        case .red: return 10
        }
    }

    private static func applyWipe(_ canvas: inout PixelFrame, atFrame frame: Int) {
        let wipeFrame = BattleWipe.frame(frame)
        if let flashWhite = wipeFrame.flashWhite {
            canvas = PixelFrame(fill: flashWhite ? flashWhiteIndex : flashInkIndex)
            return
        }
        for range in wipeFrame.coveredRows {
            canvas.fill(PixelRect(x: 0, y: range.lowerBound, width: PixelFrame.width, height: range.count),
                        index: flashInkIndex)
        }
    }
}
```

- [ ] **Step 4: Run all core tests**

Run: `scripts/test-core.sh`
Expected: `Executed 211 tests, with 0 failures`

- [ ] **Step 5: Write the app-layer files (Xcode, not compiled on this machine)**

File: `App/Screens/Adventure/BattleRun.swift`

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
}
```

File: `App/Screens/Adventure/BattleScreenModel.swift`

```swift
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
        max(0, Int(date.timeIntervalSince(phaseStart) * 60))
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
        switch state.outcome {
        case .won: run.winDialogue
        case .lost: run.loseDialogue
        case nil: run.introDialogue
        }
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
```

File: `App/Screens/Adventure/BattleOptionsView.swift`

```swift
import SwiftUI
import IFRCore

struct BattleOptionsView: View {
    let question: Question
    let answerRevealed: Bool
    let isEnabled: Bool
    let onSelect: (Int) -> Void

    @State private var showsSource = false

    var body: some View {
        VStack(spacing: 8) {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(question.options.indices, id: \.self) { index in
                        optionButton(index)
                    }
                }
            }
            Button("Source") { showsSource = true }
                .accessibilityIdentifier("battleSource")
        }
        .font(RetroTheme.pixelFont(size: 10))
        .sheet(isPresented: $showsSource) {
            SourceSheet(question: question, answerRevealed: answerRevealed)
        }
    }

    private func optionButton(_ index: Int) -> some View {
        Button(question.options[index]) { onSelect(index) }
            .disabled(!isEnabled)
            .buttonStyle(.bordered)
            .accessibilityIdentifier("battleOption-\(index)")
    }
}
```

File: `App/Screens/Adventure/HPBarView.swift`

```swift
import SwiftUI
import IFRCore

struct HPBarView: View {
    let plate: NamePlate
    let name: String
    let hp: Int
    let maxHP: Int
    let scale: Int
    let displayScale: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            Text(String(name.uppercased().prefix(7)))
                .font(RetroTheme.pixelFont(size: fontSize))
                .foregroundStyle(.black)
                .position(point(for: plate.nameOrigin))
            if let numbersRightEdge = plate.numbersRightEdge {
                Text("\(hp)/\(maxHP)")
                    .font(RetroTheme.pixelFont(size: fontSize))
                    .foregroundStyle(.black)
                    .position(point(for: numbersRightEdge))
            }
        }
    }

    private var fontSize: CGFloat {
        RetroTheme.pixelFontSize(scale: scale, displayScale: displayScale)
    }

    private func point(for origin: GridPoint) -> CGPoint {
        CGPoint(x: CGFloat(origin.x * scale) / displayScale, y: CGFloat(origin.y * scale) / displayScale)
    }
}
```

File: `App/Screens/Adventure/BattleScreen.swift`

```swift
import SwiftUI
import IFRCore

struct BattleScreen: View {
    @Environment(StudyStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale
    let run: BattleRun

    @State private var model: BattleScreenModel?

    var body: some View {
        Group {
            if let model {
                content(model: model)
            } else {
                Color.clear.onAppear { model = BattleScreenModel(run: run, store: store) }
            }
        }
    }

    private func content(model: BattleScreenModel) -> some View {
        GeometryReader { geometry in
            TimelineView(.animation) { context in
                let scale = IntegerScaler.scale(viewWidth: geometry.size.width, viewHeight: geometry.size.height,
                                                displayScale: displayScale)
                let frame = renderedFrame(model: model, at: context.date)
                VStack(spacing: 0) {
                    ZStack {
                        GBAScreen(frame: frame)
                        HPBarView(plate: .enemy, name: model.state.opponent.nameplateName,
                                 hp: model.state.opponentHP, maxHP: model.state.opponent.maxHP,
                                 scale: scale, displayScale: displayScale)
                        HPBarView(plate: .player, name: run.playerPlateName,
                                 hp: model.state.playerHP, maxHP: model.state.playerMaxHP,
                                 scale: scale, displayScale: displayScale)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { handleTap(model: model, at: context.date) }
                    if model.phase == .asking, let question = model.state.currentQuestion {
                        BattleOptionsView(question: question, answerRevealed: model.answerRevealed,
                                          isEnabled: true,
                                          onSelect: { index in model.answer(selectedIndex: index, at: context.date) })
                    }
                }
                .onChange(of: context.date) { _, date in advance(model: model, at: date) }
                .onChange(of: model.dismissed) { _, done in if done { dismiss() } }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Quit") { model.quit(at: context.date) }
                            .accessibilityIdentifier("battleQuit")
                    }
                }
            }
        }
    }

    private func renderedFrame(model: BattleScreenModel, at date: Date) -> PixelFrame {
        BattleRenderer.frame(state: model.state, displayedPlayerHP: model.state.playerHP,
                             displayedOpponentHP: model.state.opponentHP, playerSpriteID: run.playerSpriteID,
                             atFrame: model.frameIndex(at: date), phase: model.phase)
    }

    private func advance(model: BattleScreenModel, at date: Date) {
        model.advanceWipeIfComplete(at: date)
        model.advanceIntroIfComplete(at: date)
        model.advanceResolving(at: date)
        if model.phase == .asking { model.stemDidFinishTyping() }
    }

    private func handleTap(model: BattleScreenModel, at date: Date) {
        if model.phase == .ended { model.dismissEnded() }
    }
}
```

File: `AppTests/BattleScreenModelTests.swift`

```swift
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
        Question(id: id, category: .humanFactors, acsCodes: ["IR.I.A.K1"], format: .multipleChoice,
                 front: "f", back: "b", options: ["a", "b", "c"], correctIndex: 0, explanation: "e",
                 source: SourceRef(document: "d", section: "s", url: URL(string: "https://faa.gov")!),
                 figure: nil, difficulty: difficulty)
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
```

- [ ] **Step 6: Append the UI smoke tests**

File: `AppUITests/SmokeTests.swift` (three tests appended to the existing `SmokeTests` class)

```swift
    func testStartingFirstGymShowsQuestionAndOptions() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["Adventure"].tap()
        app.buttons["airport-KHYP"].tap()
        app.buttons["gym-humanFactors"].tap()
        XCTAssertTrue(app.buttons["battleOption-0"].waitForExistence(timeout: 15))
    }

    func testAnsweringOptionAdvancesTurn() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["Adventure"].tap()
        app.buttons["airport-KHYP"].tap()
        app.buttons["gym-humanFactors"].tap()
        XCTAssertTrue(app.buttons["battleOption-0"].waitForExistence(timeout: 15))
        app.buttons["battleOption-0"].tap()
        XCTAssertTrue(app.buttons["battleQuit"].waitForExistence(timeout: 5))
    }

    func testBattleQuitReturnsToRegionMap() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["Adventure"].tap()
        app.buttons["airport-KHYP"].tap()
        app.buttons["gym-humanFactors"].tap()
        XCTAssertTrue(app.buttons["battleQuit"].waitForExistence(timeout: 15))
        app.buttons["battleQuit"].tap()
        XCTAssertTrue(app.otherElements["regionMap"].waitForExistence(timeout: 15))
    }
```

Expected in Xcode: `BattleRendererTests` and the core suite build and pass as in Step 4; `BattleScreenModelTests` and the three `SmokeTests` additions build and pass once `AdventureSaveRecord`/`BattleRecord`, the `StudyStore` Adventure extension and `AdventureView`/`RegionMapScreen` (M1-11, M1-14) are present in the same checkout — see Deviations.

- [ ] **Step 7: Commit**

Run: `git add IFRCore/Sources/IFRCore/Adventure/Pixel/BattleRenderer.swift IFRCore/Tests/IFRCoreTests/BattleRendererTests.swift App/Screens/Adventure/BattleRun.swift App/Screens/Adventure/BattleScreenModel.swift App/Screens/Adventure/BattleOptionsView.swift App/Screens/Adventure/HPBarView.swift App/Screens/Adventure/BattleScreen.swift AppTests/BattleScreenModelTests.swift AppUITests/SmokeTests.swift && git commit -m "M1-15: Battle screen"`

## Deviations from spec

- This worktree (`adventure-build-c`) does not yet contain M1-11 (`StudyStore.submitAdventureAnswer`/`finishBattle`/`AdventureSaveRecord`/`BattleRecord`) or M1-14 (`AdventureView`, `RegionMapScreen`, `DialogueBoxView`, the `Adventure` tab in `RootView`), both of which M1-15 is specified to build on. `BattleScreenModel.swift`, `BattleScreen.swift` and `AppTests/BattleScreenModelTests.swift` reference `store.submitAdventureAnswer`, `store.finishBattle`, `AdventureSaveRecord` and `BattleRecord` exactly as section 2.9 documents them, and the three `SmokeTests` additions assume the `Adventure` tab, `airport-<id>` and `gym-<gymID>` buttons and a `regionMap` element from M1-14. None of this can compile until those work items land in the same checkout; this is unavoidable given the current worktree state and could not be verified with `scripts/test-app.sh` regardless, per the task's own constraints.
- `BattleScreen.swift` does not compose a separate `DialogueBoxView` (listed under M1-14's files, and not present here); intro/resolving/ended dialogue advancement is folded into `BattleScreen`'s own tap handler (`handleTap`) instead, to avoid speculatively defining a type that file's real owner will create.
- `BattleScreenModel`'s phase driver methods (`advanceWipeIfComplete`, `advanceIntroIfComplete`, `advanceResolving`) are separate, explicitly time-stamped calls rather than one internal `tick(at:)`, so `AppTests/BattleScreenModelTests.swift` can drive and assert each transition of the section 4 phase table deterministically without a live `TimelineView` clock.
- `RetroTheme.pixelFont`/`pixelFontSize` are used with their actual existing signatures (`pixelFont(size:)`, `pixelFontSize(scale:displayScale:)`), which differ slightly in shape from section 2.9's prose description (`pixelFont(scale:displayScale:)`); the already-committed M1-06 API was kept rather than duplicated or renamed.
- `HPBarView`/`BattleScreen` compute the SwiftUI overlay's scale locally via `IntegerScaler` inside a `GeometryReader`, since the already-committed `GBAScreen.swift` (M1-06) has no overlay hook and is not in this task's file list to modify.

## Core test output

`scripts/test-core.sh` (full suite, after Step 3): `Executed 211 tests, with 0 failures (0 unexpected) in 0.974 (0.974) seconds`

---

### Task M1-16: Elite Four, Champion, badge case, Hall of Fame (Xcode)

**Files:**
- Create: `App/Screens/Adventure/EliteFourScreenModel.swift`
- Create: `App/Screens/Adventure/EliteFourScreen.swift`
- Create: `App/Screens/Adventure/ChampionScreen.swift`
- Create: `App/Screens/Adventure/BadgeCaseScreen.swift`
- Create: `App/Screens/Adventure/HallOfFameScreen.swift`
- Modify: `App/Screens/Adventure/AdventureView.swift`
- Modify: `App/Screens/Adventure/RegionMapScreen.swift`
- Test: `AppTests/EliteFourScreenModelTests.swift`
- Test: `AppUITests/SmokeTests.swift`

**Interfaces:**
- Consumes: `EliteFourRun` (`IFRCore/Sources/IFRCore/Adventure/Battle/EliteFourRun.swift`), `ChampionBattle` (`IFRCore/Sources/IFRCore/Adventure/Battle/ChampionBattle.swift`), `CircuitRules` (`IFRCore/Sources/IFRCore/Adventure/Circuit/CircuitRules.swift`), `BattleEngine`/`BattleState`/`Opponent`/`OpponentHP`/`BattleTier` (`IFRCore/Sources/IFRCore/Adventure/Battle/`), `AdventureContent`/`EliteMember`/`ChampionSpec`/`Gym`/`DialogueScript`/`SystemDialogueKey` (`IFRCore/Sources/IFRCore/Adventure/Content/`), `GymID`/`AdventureSave` (`IFRCore/Sources/IFRCore/Adventure/Circuit/`), `StudyStore.drawEncounterDeck`/`finishBattle`/`finishEliteFourRun`/`championDeck`/`reviewedRetentionByCategory`/`adventureSave`/`updateAdventureSave` (`App/Persistence/StudyStore.swift`), `BattleRun` (`App/Screens/Adventure/BattleRun.swift`), `BattleScreen` (`App/Screens/Adventure/BattleScreen.swift`), `DialogueBoxView` (`App/Screens/Adventure/DialogueBoxView.swift`).
- Produces: `EliteFourScreenModel` (`@Observable @MainActor final class` with `init(content: AdventureContent, store: StudyStore)`, `run: EliteFourRun`, `currentMember: EliteMember?`, `activeBattle: BattleRun?`, `challengeCurrentMember()`, `battleDismissed()`, `clearActiveBattle()`), `EliteFourScreen(content:)`, `ChampionScreen(content:)`, `BadgeCaseScreen(content:)`, `HallOfFameScreen()` — all `View`s later tasks (M1-17) can wire from other doors.

- [ ] **Step 1: Write the failing tests**

File: `AppTests/EliteFourScreenModelTests.swift`

```swift
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
        while let question = state.currentQuestion {
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
```

File: `AppUITests/SmokeTests.swift` (new private helpers and new test functions added to the existing suite)

```swift
// AppUITests/SmokeTests.swift
import XCTest
import IFRCore

final class SmokeTests: XCTestCase {
    private func launch(withSave save: AdventureSave) -> XCUIApplication {
        let app = XCUIApplication()
        let data = try! JSONEncoder().encode(save)
        let json = String(data: data, encoding: .utf8)!
        app.launchArguments += ["-adventureSaveJSON", json]
        app.launch()
        return app
    }

    private func save(withBadges count: Int) -> AdventureSave {
        var save = AdventureSave.new
        save.badges = Set(GymID.allCases.prefix(count))
        return save
    }

    private func eliteFourClearedSave() -> AdventureSave {
        var save = save(withBadges: GymID.allCases.count)
        save.eliteFourCleared = true
        return save
    }

    private func hallOfFameSave() -> AdventureSave {
        var save = eliteFourClearedSave()
        save.hallOfFame = [Date(timeIntervalSince1970: 1_700_000_000), Date(timeIntervalSince1970: 1_800_000_000)]
        return save
    }

    // ... existing tests (testAppLaunches, testAdventureTabShowsRegionMap, etc.) unchanged ...

    func testSeededSaveWithEightBadgesUnlocksEliteFour() {
        let app = launch(withSave: save(withBadges: 8))
        app.tabBars.buttons["Adventure"].tap()
        app.buttons["airport-KELF"].tap()
        XCTAssertTrue(app.otherElements["eliteFourScreen"].waitForExistence(timeout: 15))
    }

    func testEliteFourLockedUntilEightBadges() {
        let app = launch(withSave: save(withBadges: 4))
        app.tabBars.buttons["Adventure"].tap()
        app.buttons["airport-KELF"].tap()
        XCTAssertTrue(app.staticTexts["You need the Charts Badge first."].waitForExistence(timeout: 15))
    }

    func testChampionLockedUntilEliteFourCleared() {
        let app = launch(withSave: save(withBadges: 8))
        app.tabBars.buttons["Adventure"].tap()
        app.buttons["airport-KCHP"].tap()
        XCTAssertTrue(app.staticTexts["You need to clear the Elite Four first."].waitForExistence(timeout: 15))
    }

    func testChampionChallengeStartsSixtyQuestionBattleAsTheDPE() {
        let app = launch(withSave: eliteFourClearedSave())
        app.tabBars.buttons["Adventure"].tap()
        app.buttons["airport-KCHP"].tap()
        XCTAssertTrue(app.buttons["gym-champion"].waitForExistence(timeout: 15))
        app.buttons["gym-champion"].tap()
        XCTAssertTrue(app.buttons["battleOption-0"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["THE DPE"].exists)
    }

    func testBadgeCaseShowsEightSlotsWithEarnedOnesLit() {
        let app = launch(withSave: save(withBadges: 2))
        app.tabBars.buttons["Adventure"].tap()
        app.buttons["badgeCase"].tap()
        XCTAssertTrue(app.cells["badgeSlot-approaches"].waitForExistence(timeout: 15))
        for gymID in GymID.allCases {
            XCTAssertTrue(app.cells["badgeSlot-\(gymID.rawValue)"].exists)
        }
        XCTAssertEqual(app.cells["badgeSlot-humanFactors"].value as? String, "earned")
        XCTAssertEqual(app.cells["badgeSlot-approaches"].value as? String, "locked")
    }

    func testHallOfFameListsChampionWinsNewestFirst() {
        let app = launch(withSave: hallOfFameSave())
        app.tabBars.buttons["Adventure"].tap()
        app.buttons["hallOfFame"].tap()
        XCTAssertTrue(app.cells["hallOfFameEntry-0"].waitForExistence(timeout: 15))
    }

    func testHallOfFameIsEmptyBeforeFirstChampionWin() {
        let app = launch(withSave: AdventureSave.new)
        app.tabBars.buttons["Adventure"].tap()
        app.buttons["hallOfFame"].tap()
        XCTAssertTrue(app.staticTexts["hallOfFameEmpty"].waitForExistence(timeout: 15))
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `scripts/test-app.sh --filter EliteFourScreenModelTests`
Expected: this is an Xcode-only app target and cannot be compiled on this Linux machine. Before the implementation exists, Xcode reports a build error such as `cannot find 'EliteFourScreenModel' in scope` at every `EliteFourScreenModel(content:store:)` call site in the test file, and the `SmokeTests` target fails to build with `cannot find 'GymID' in scope` (before `import IFRCore` resolves) or, once that import is added, with the UI test steps timing out because `airport-KELF` never reveals an `eliteFourScreen`, `gym-champion` button, `badgeSlot-<id>` cells or `hallOfFameEntry-0`/`hallOfFameEmpty` elements, none of which exist before this task's screens are added.

- [ ] **Step 3: Write the implementation**

File: `App/Screens/Adventure/EliteFourScreenModel.swift`

```swift
import Foundation
import IFRCore

@Observable
@MainActor
final class EliteFourScreenModel {
    private(set) var run: EliteFourRun
    private(set) var activeBattle: BattleRun?

    let content: AdventureContent
    private let store: StudyStore
    private var battlesWonBeforeBattle = 0

    init(content: AdventureContent, store: StudyStore) {
        self.content = content
        self.store = store
        run = EliteFourRun.start(playerMaxHP: EliteFourScreenModel.startingMaxHP(store: store))
    }

    var currentMember: EliteMember? {
        content.eliteFour.first { $0.order == run.memberIndex + 1 }
    }

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
            firstTime: false, returnTo: nil)
    }

    func clearActiveBattle() {
        activeBattle = nil
    }

    func battleDismissed() {
        activeBattle = nil
        guard store.adventureSave.battlesWon > battlesWonBeforeBattle else { return }
        run = EliteFourRun(memberIndex: run.memberIndex + 1, playerHP: run.playerMaxHP, playerMaxHP: run.playerMaxHP)
        if run.isCleared {
            store.finishEliteFourRun(run)
        }
    }

    private func eliteOpponent(member: EliteMember, deck: [Question]) -> Opponent {
        Opponent(id: member.id, name: member.name, nameplateName: member.nameplateName,
                spriteID: member.spriteID, tier: .eliteFour, maxHP: OpponentHP.tuned(for: deck))
    }

    private static func startingMaxHP(store: StudyStore) -> Int {
        let retentions = store.reviewedRetentionByCategory().values
        let mean = retentions.isEmpty ? 0 : retentions.reduce(0, +) / Double(retentions.count)
        return PlayerHP.maximum(for: MasteryLevel.level(forRetention: mean))
    }
}
```

File: `App/Screens/Adventure/EliteFourScreen.swift`

```swift
import SwiftUI
import IFRCore

struct EliteFourScreen: View {
    @Environment(StudyStore.self) private var store
    let content: AdventureContent

    @State private var model: EliteFourScreenModel?
    @State private var dialogue: DialogueScript?

    var body: some View {
        Group {
            if let model {
                memberView(model)
            } else {
                ProgressView()
                    .onAppear { model = EliteFourScreenModel(content: content, store: store) }
            }
        }
        .accessibilityIdentifier("eliteFourScreen")
    }

    private func memberView(_ model: EliteFourScreenModel) -> some View {
        VStack {
            if model.currentMember != nil {
                if let dialogue {
                    DialogueBoxView(script: dialogue, scale: 1, displayScale: 1, onFinished: { self.dialogue = nil })
                }
                Button("Challenge") { challenge(model: model) }
                    .accessibilityIdentifier("eliteFourChallenge")
            } else {
                Text("Elite Four cleared")
                    .accessibilityIdentifier("eliteFourCleared")
            }
        }
        .onAppear { showIntro(model: model) }
        .fullScreenCover(item: activeBattleBinding(model)) { run in
            BattleScreen(run: run)
                .onDisappear { model.battleDismissed() }
        }
    }

    private func challenge(model: EliteFourScreenModel) {
        dialogue = nil
        model.challengeCurrentMember()
    }

    private func showIntro(model: EliteFourScreenModel) {
        guard let member = model.currentMember else { return }
        dialogue = content.dialogue[member.dialogue.intro]
    }

    private func activeBattleBinding(_ model: EliteFourScreenModel) -> Binding<BattleRun?> {
        Binding(get: { model.activeBattle }, set: { newValue in if newValue == nil { model.clearActiveBattle() } })
    }
}
```

File: `App/Screens/Adventure/ChampionScreen.swift`

```swift
import SwiftUI
import IFRCore

struct ChampionScreen: View {
    @Environment(StudyStore.self) private var store
    let content: AdventureContent

    @State private var activeBattle: BattleRun?
    @State private var dialogue: DialogueScript?

    var body: some View {
        VStack {
            if let dialogue {
                DialogueBoxView(script: dialogue, scale: 1, displayScale: 1, onFinished: { self.dialogue = nil })
            }
            Button("Challenge") { startChampionBattle() }
                .accessibilityIdentifier("gym-champion")
        }
        .accessibilityIdentifier("championScreen")
        .onAppear { dialogue = content.dialogue[content.champion.dialogue.intro] }
        .fullScreenCover(item: $activeBattle) { run in
            BattleScreen(run: run)
        }
    }

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
            firstTime: store.adventureSave.championWins == 0, returnTo: nil)
    }
}
```

File: `App/Screens/Adventure/BadgeCaseScreen.swift`

```swift
import SwiftUI
import IFRCore

struct BadgeCaseScreen: View {
    @Environment(StudyStore.self) private var store
    let content: AdventureContent

    var body: some View {
        List(GymID.allCases, id: \.self) { gymID in
            HStack {
                Text(badgeName(for: gymID))
                Spacer()
                Text(isEarned(gymID) ? "Earned" : "Locked")
            }
            .accessibilityIdentifier("badgeSlot-\(gymID.rawValue)")
            .accessibilityValue(isEarned(gymID) ? "earned" : "locked")
        }
        .navigationTitle("Badges")
    }

    private func isEarned(_ gymID: GymID) -> Bool {
        store.adventureSave.badges.contains(gymID)
    }

    private func badgeName(for gymID: GymID) -> String {
        content.gyms.first { $0.id == gymID }?.badgeName ?? gymID.rawValue
    }
}
```

File: `App/Screens/Adventure/HallOfFameScreen.swift`

```swift
import SwiftUI
import IFRCore

struct HallOfFameScreen: View {
    @Environment(StudyStore.self) private var store

    var body: some View {
        Group {
            if sortedDates.isEmpty {
                Text("No champion wins yet.")
                    .accessibilityIdentifier("hallOfFameEmpty")
            } else {
                List(Array(sortedDates.enumerated()), id: \.offset) { index, date in
                    Text(date.formatted())
                        .accessibilityIdentifier("hallOfFameEntry-\(index)")
                }
            }
        }
        .navigationTitle("Hall of Fame")
    }

    private var sortedDates: [Date] {
        store.adventureSave.hallOfFame.sorted(by: >)
    }
}
```

File: `App/Screens/Adventure/AdventureView.swift` (complete new version)

```swift
import SwiftUI
import IFRCore

struct AdventureView: View {
    @Environment(StudyStore.self) private var store
    @State private var content: AdventureContent?
    @State private var activeBattle: BattleRun?

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
        }
        .fullScreenCover(item: $activeBattle) { run in
            BattleScreen(run: run)
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

File: `App/Screens/Adventure/RegionMapScreen.swift` — new/changed members (the rest of the file, including `mapFrame`, `nextGym`, `airportButton`, `challengeButton` and `startGymBattle`, is unchanged from M1-14/M1-15)

```swift
    @State private var dialogue: DialogueScript?
    @State private var challengeableGymID: GymID?
    @State private var showingEliteFour = false
    @State private var showingChampion = false
    @State private var showingBadgeCase = false
    @State private var showingHallOfFame = false

    var body: some View {
        GeometryReader { geometry in
            let scale = IntegerScaler.scale(
                viewWidth: geometry.size.width, viewHeight: geometry.size.height, displayScale: displayScale)
            ZStack {
                GBAScreen(frame: mapFrame)
                ForEach(content.region.airports, id: \.id) { airport in
                    airportButton(airport, scale: scale)
                }
                if let dialogue {
                    DialogueBoxView(script: dialogue, scale: scale, displayScale: displayScale,
                                    onFinished: { self.dialogue = nil })
                }
                if let challengeableGymID {
                    challengeButton(challengeableGymID)
                }
            }
        }
        .accessibilityIdentifier("regionMap")
        .toolbar {
            ToolbarItem { Button("Badges") { showingBadgeCase = true }.accessibilityIdentifier("badgeCase") }
            ToolbarItem { Button("Hall of Fame") { showingHallOfFame = true }.accessibilityIdentifier("hallOfFame") }
        }
        .navigationDestination(isPresented: $showingEliteFour) { EliteFourScreen(content: content) }
        .navigationDestination(isPresented: $showingChampion) { ChampionScreen(content: content) }
        .navigationDestination(isPresented: $showingBadgeCase) { BadgeCaseScreen(content: content) }
        .navigationDestination(isPresented: $showingHallOfFame) { HallOfFameScreen() }
    }
```

```swift
    private func tap(_ airport: Airport) {
        switch airport.role {
        case .gym:
            tapGym(airport)
        case .eliteFour:
            tapEliteFour()
        case .champion:
            tapChampion()
        case .waypoint:
            break
        }
    }

    private func tapGym(_ airport: Airport) {
        guard let gymID = airport.gymID, let gym = content.gyms.first(where: { $0.id == gymID }) else { return }
        if CircuitRules.isUnlocked(gymID, save: store.adventureSave) {
            dialogue = content.dialogue[gym.dialogue.intro]
            challengeableGymID = gymID
        } else {
            dialogue = content.systemLine(.gymLocked, filling: ["badge": previousBadgeName(before: gymID)])
            challengeableGymID = nil
        }
    }

    private func tapEliteFour() {
        challengeableGymID = nil
        if CircuitRules.isEliteFourUnlocked(save: store.adventureSave) {
            showingEliteFour = true
        } else {
            dialogue = content.systemLine(.gymLocked, filling: ["badge": nextMissingBadgeName()])
        }
    }

    private func tapChampion() {
        challengeableGymID = nil
        if CircuitRules.isChampionUnlocked(save: store.adventureSave) {
            showingChampion = true
        } else {
            dialogue = DialogueScript(pages: ["You need to clear the Elite Four first."])
        }
    }

    private func previousBadgeName(before gymID: GymID) -> String {
        guard let previous = gymID.previous, let previousGym = content.gyms.first(where: { $0.id == previous })
        else { return "" }
        return previousGym.badgeName
    }

    private func nextMissingBadgeName() -> String {
        guard let missing = GymID.allCases.first(where: { !store.adventureSave.badges.contains($0) }),
              let gym = content.gyms.first(where: { $0.id == missing }) else { return "" }
        return gym.badgeName
    }
```

- [ ] **Step 4: Run all core tests**

Run: `scripts/test-core.sh`
Expected: `Executed 216 tests, with 0 failures (0 unexpected) in 0.724 (0.724) seconds` — this task touches only `App/`, `AppTests/` and `AppUITests/`, so the IFRCore package and its Linux test suite are untouched and unaffected; the observed run after this task's changes stayed at `Executed 216 tests, with 0 failures`.

- [ ] **Step 5: Commit**

Run: `git add App/Screens/Adventure/EliteFourScreenModel.swift App/Screens/Adventure/EliteFourScreen.swift App/Screens/Adventure/ChampionScreen.swift App/Screens/Adventure/BadgeCaseScreen.swift App/Screens/Adventure/HallOfFameScreen.swift App/Screens/Adventure/AdventureView.swift App/Screens/Adventure/RegionMapScreen.swift AppTests/EliteFourScreenModelTests.swift AppUITests/SmokeTests.swift && git commit -m "M1-16: Elite Four, Champion, badge case, Hall of Fame"`

For app-target work, `scripts/test-app.sh --filter EliteFourScreenModelTests` and `scripts/test-app.sh --filter SmokeTests` are what Xcode would run; since this machine has no Xcode toolchain, the pass/fail of steps 2 and 4's app-target parts is stated from reading the existing `App`, `AppTests` and `AppUITests` code these new files build on (`BattleScreenModelTests.swift`'s `makeStore()`/`mcQuestion(_:)` pattern, `AdventureStoreTests.swift`'s `gymOpponent`/`championOpponent` pattern, `RegionMapScreen.swift`'s existing `tap`/`airportButton`/`challengeButton` structure, and `BattleScreen.swift`'s `fullScreenCover(item:)` usage), never claimed as run.

---

### Task M1-17: Refactor and content polish

**Files:**
- Create: `IFRCore/Sources/IFRCore/Adventure/Battle/BattleDialogue.swift`
- Create: `IFRCore/Sources/IFRCore/Adventure/Circuit/GymApproach.swift`
- Modify: `IFRCore/Sources/IFRCore/Resources/adventure-v1.json`
- Modify: `App/Screens/Adventure/BattleScreenModel.swift`
- Modify: `App/Screens/Adventure/RegionMapScreen.swift`
- Test: `IFRCore/Tests/IFRCoreTests/BattleDialogueTests.swift`
- Test: `IFRCore/Tests/IFRCoreTests/GymApproachTests.swift`
- Test: `IFRCore/Tests/IFRCoreTests/AdventureContentTests.swift`
- Test: `IFRCore/Tests/IFRCoreTests/SpriteCatalogTests.swift`
- Test: `IFRCore/Tests/IFRCoreTests/SourceGuardTests.swift`

**Interfaces:**
- Consumes: `CircuitRules.isUnlocked/isEliteFourUnlocked/isChampionUnlocked` (`IFRCore/Sources/IFRCore/Adventure/Circuit/CircuitRules.swift`), `AdventureContent.systemLine/dialogue/gyms` and `SystemDialogueKey` (`Adventure/Content/AdventureContent.swift`, `Adventure/Content/DialogueScript.swift`), `Gym`, `GymID`, `AdventureSave` (`Adventure/Content/Gym.swift`, `Adventure/Circuit/GymID.swift`, `Adventure/Circuit/AdventureSave.swift`), `BattleOutcome` and `BattleRun`'s `introDialogue/winDialogue/loseDialogue` (`Adventure/Battle/BattleState.swift`, `App/Screens/Adventure/BattleRun.swift`), `SpriteCatalog.all`, `Palette.transparent` (`Adventure/Pixel/SpriteCatalog.swift`, `Adventure/Pixel/Palette.swift`), `Typewriter.paginate` (`Adventure/Pixel/Typewriter.swift`, used indirectly through content validation).
- Produces: `BattleDialogue.current(outcome: BattleOutcome?, intro: DialogueScript, win: DialogueScript, lose: DialogueScript) -> DialogueScript`; `GymApproachResult { dialogue: DialogueScript; challengeableGymID: GymID? }`; `GymApproach.approaching(_ gym: Gym, content: AdventureContent, save: AdventureSave) -> GymApproachResult`; `GymApproach.eliteFourLockedDialogue(content:save:) -> DialogueScript?`; `GymApproach.championLockedDialogue(content:save:) -> DialogueScript?`. `BattleScreenModel` and `RegionMapScreen` call these instead of branching on `CircuitRules` or `state.outcome` themselves.

- [ ] **Step 1: Write the failing tests**

File: `IFRCore/Tests/IFRCoreTests/BattleDialogueTests.swift`

```swift
import XCTest
@testable import IFRCore

final class BattleDialogueTests: XCTestCase {
    private let intro = DialogueScript(pages: ["intro"])
    private let win = DialogueScript(pages: ["win"])
    private let lose = DialogueScript(pages: ["lose"])

    func testNoOutcomeShowsIntro() {
        let result = BattleDialogue.current(outcome: nil, intro: intro, win: win, lose: lose)
        XCTAssertEqual(result, intro)
    }

    func testWonOutcomeShowsWin() {
        let result = BattleDialogue.current(outcome: .won, intro: intro, win: win, lose: lose)
        XCTAssertEqual(result, win)
    }

    func testLostOutcomeShowsLose() {
        let result = BattleDialogue.current(outcome: .lost, intro: intro, win: win, lose: lose)
        XCTAssertEqual(result, lose)
    }
}
```

File: `IFRCore/Tests/IFRCoreTests/GymApproachTests.swift`

```swift
import XCTest
@testable import IFRCore

final class GymApproachTests: XCTestCase {
    private func loadedContent() throws -> AdventureContent {
        try AdventureContent.load()
    }

    private func gym(_ id: GymID, in content: AdventureContent) throws -> Gym {
        try XCTUnwrap(content.gyms.first { $0.id == id })
    }

    func testUnlockedGymShowsIntroDialogueAndIsChallengeable() throws {
        let content = try loadedContent()
        let result = GymApproach.approaching(try gym(.humanFactors, in: content), content: content, save: .new)
        XCTAssertEqual(result.dialogue, content.dialogue[content.gyms[0].dialogue.intro])
        XCTAssertEqual(result.challengeableGymID, .humanFactors)
    }

    func testLockedGymShowsGymLockedDialogueNamingThePreviousBadge() throws {
        let content = try loadedContent()
        let result = GymApproach.approaching(try gym(.instrumentsAndSystems, in: content), content: content, save: .new)
        let expectedBadge = try gym(.humanFactors, in: content).badgeName
        XCTAssertEqual(result.dialogue, content.systemLine(.gymLocked, filling: ["badge": expectedBadge]))
        XCTAssertNil(result.challengeableGymID)
    }

    func testFirstGymIsAlwaysUnlocked() throws {
        let content = try loadedContent()
        let result = GymApproach.approaching(try gym(.humanFactors, in: content), content: content, save: .new)
        XCTAssertEqual(result.challengeableGymID, .humanFactors)
    }

    func testEliteFourLockedDialogueNamesNextMissingBadge() throws {
        let content = try loadedContent()
        var save = AdventureSave.new
        save.badges = [.humanFactors]
        let dialogue = GymApproach.eliteFourLockedDialogue(content: content, save: save)
        let expectedBadge = try gym(.instrumentsAndSystems, in: content).badgeName
        XCTAssertEqual(dialogue, content.systemLine(.gymLocked, filling: ["badge": expectedBadge]))
    }

    func testEliteFourUnlockedDialogueIsNil() throws {
        let content = try loadedContent()
        var save = AdventureSave.new
        save.badges = Set(GymID.allCases)
        XCTAssertNil(GymApproach.eliteFourLockedDialogue(content: content, save: save))
    }

    func testChampionLockedDialogueIsChampionPinnedSystemLine() throws {
        let content = try loadedContent()
        let dialogue = GymApproach.championLockedDialogue(content: content, save: .new)
        XCTAssertEqual(dialogue, content.systemLine(.championPinned))
    }

    func testChampionUnlockedDialogueIsNil() throws {
        let content = try loadedContent()
        var save = AdventureSave.new
        save.eliteFourCleared = true
        XCTAssertNil(GymApproach.championLockedDialogue(content: content, save: save))
    }
}
```

Added to `IFRCore/Tests/IFRCoreTests/AdventureContentTests.swift` (goes after `testEverySpriteIDResolvesInSpriteCatalog`'s preceding test, before it in the class):

```swift
    func testEveryLeaderIntroHasTwoPagesAndWinLoseHaveOne() throws {
        let content = try loadedContent()
        for gym in content.gyms {
            let intro = try XCTUnwrap(content.dialogue[gym.dialogue.intro], gym.dialogue.intro)
            let win = try XCTUnwrap(content.dialogue[gym.dialogue.win], gym.dialogue.win)
            let lose = try XCTUnwrap(content.dialogue[gym.dialogue.lose], gym.dialogue.lose)
            XCTAssertEqual(intro.pages.count, 2, gym.dialogue.intro)
            XCTAssertEqual(win.pages.count, 1, gym.dialogue.win)
            XCTAssertEqual(lose.pages.count, 1, gym.dialogue.lose)
        }
    }

    func testEveryEliteAndChampionDialogueIsAuthored() throws {
        let content = try loadedContent()
        let refs = content.eliteFour.map(\.dialogue) + [content.champion.dialogue]
        for ref in refs {
            for key in [ref.intro, ref.win, ref.lose] {
                let script = try XCTUnwrap(content.dialogue[key], key)
                XCTAssertFalse(script.pages.isEmpty, key)
                for page in script.pages {
                    XCTAssertFalse(page.contains("TODO"), key)
                }
            }
        }
    }
```

Added to `IFRCore/Tests/IFRCoreTests/SpriteCatalogTests.swift` (goes inside the class, after `testMilestoneOneSpriteIDsExist`):

```swift
    func testNoSpriteIsAnEmptySilhouette() {
        for (id, sprite) in SpriteCatalog.all {
            var opaqueCount = 0
            for y in 0..<sprite.height {
                for x in 0..<sprite.width {
                    if sprite[x, y] != Palette.transparent {
                        opaqueCount += 1
                    }
                }
            }
            let minimum = sprite.width == 32 ? 128 : 12
            XCTAssertGreaterThanOrEqual(opaqueCount, minimum, id)
        }
    }
```

Added to `IFRCore/Tests/IFRCoreTests/SourceGuardTests.swift` (goes inside the class, before `testCoreWorkflowInstallsSwiftThenRunsCoreScript`):

```swift
    func testAdventureSourceFilesOutsideSpritesStayUnderOneHundredFiftyLines() throws {
        assertAdventureDirectoryExists()
        let spriteFragment = "Pixel/Sprites/"
        for file in swiftFiles(under: adventureRoot) where !file.path.contains(spriteFragment) {
            let text = try String(contentsOf: file, encoding: .utf8)
            let lineCount = text.split(separator: "\n", omittingEmptySubsequences: false).count
            XCTAssertLessThanOrEqual(lineCount, 150, file.lastPathComponent)
        }
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `scripts/test-core.sh --filter BattleDialogueTests` (with `BattleDialogue.swift` moved out of the source tree)
Expected:
```
error: cannot find 'BattleDialogue' in scope
```

Run: `scripts/test-core.sh --filter GymApproachTests` (with `GymApproach.swift` moved out of the source tree)
Expected: same shape, `error: cannot find 'GymApproach' in scope`.

Run: `scripts/test-core.sh --filter AdventureContentTests` (with the two `-intro` dialogue arrays still holding one page each, before the JSON was edited)
Expected:
```
AdventureContentTests.swift:296: error: AdventureContentTests.testEveryLeaderIntroHasTwoPagesAndWinLoseHaveOne : XCTAssertEqual failed: ("1") is not equal to ("2") - gyro-intro
... (six more, one per gym besides humanFactors)
Executed 21 tests, with 7 failures (0 unexpected)
```

- [ ] **Step 3: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Battle/BattleDialogue.swift`

```swift
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
```

File: `IFRCore/Sources/IFRCore/Adventure/Circuit/GymApproach.swift`

```swift
public struct GymApproachResult: Equatable, Sendable {
    public let dialogue: DialogueScript
    public let challengeableGymID: GymID?
}

public enum GymApproach {
    public static func approaching(_ gym: Gym, content: AdventureContent, save: AdventureSave) -> GymApproachResult {
        guard CircuitRules.isUnlocked(gym.id, save: save) else {
            return GymApproachResult(
                dialogue: content.systemLine(.gymLocked, filling: ["badge": previousBadgeName(before: gym.id, content: content)]),
                challengeableGymID: nil
            )
        }
        return GymApproachResult(
            dialogue: content.dialogue[gym.dialogue.intro] ?? DialogueScript(pages: []),
            challengeableGymID: gym.id
        )
    }

    public static func eliteFourLockedDialogue(content: AdventureContent, save: AdventureSave) -> DialogueScript? {
        guard !CircuitRules.isEliteFourUnlocked(save: save) else { return nil }
        return content.systemLine(.gymLocked, filling: ["badge": nextMissingBadgeName(content: content, save: save)])
    }

    public static func championLockedDialogue(content: AdventureContent, save: AdventureSave) -> DialogueScript? {
        guard !CircuitRules.isChampionUnlocked(save: save) else { return nil }
        return content.systemLine(.championPinned)
    }

    static func previousBadgeName(before gymID: GymID, content: AdventureContent) -> String {
        guard let previous = gymID.previous, let previousGym = content.gyms.first(where: { $0.id == previous })
        else { return "" }
        return previousGym.badgeName
    }

    static func nextMissingBadgeName(content: AdventureContent, save: AdventureSave) -> String {
        guard let missing = GymID.allCases.first(where: { !save.badges.contains($0) }),
              let gym = content.gyms.first(where: { $0.id == missing }) else { return "" }
        return gym.badgeName
    }
}
```

Content polish in `IFRCore/Sources/IFRCore/Resources/adventure-v1.json`: each of the seven non-`humanFactors` gym `*-intro` dialogue entries gained a second page (the leader's second taunt line), for example:

```json
"gyro-intro": {
  "pages": [
    "Spin, precess, tumble. My gauges never lie. Do yours?",
    "Trust your instruments over your inner ear."
  ]
}
```

and the system `championPinned` line, which had accidentally been authored as a duplicate of `champion-intro`, was rewritten to describe why the door is locked:

```json
"championPinned": {
  "pages": [
    "You must clear the Elite Four first."
  ]
}
```

`App/Screens/Adventure/BattleScreenModel.swift`, `currentDialogue` now delegates the rule to the engine instead of switching on `state.outcome` itself:

```swift
    var currentDialogue: DialogueScript {
        BattleDialogue.current(
            outcome: state.outcome, intro: run.introDialogue, win: run.winDialogue, lose: run.loseDialogue)
    }
```

`App/Screens/Adventure/RegionMapScreen.swift`, the three tap handlers and the two badge-name lookups they owned are replaced by calls into `GymApproach`:

```swift
    private func tapGym(_ airport: Airport) {
        guard let gymID = airport.gymID, let gym = content.gyms.first(where: { $0.id == gymID }) else { return }
        let result = GymApproach.approaching(gym, content: content, save: store.adventureSave)
        dialogue = result.dialogue
        challengeableGymID = result.challengeableGymID
    }

    private func tapEliteFour() {
        challengeableGymID = nil
        if let locked = GymApproach.eliteFourLockedDialogue(content: content, save: store.adventureSave) {
            dialogue = locked
        } else {
            showingEliteFour = true
        }
    }

    private func tapChampion() {
        challengeableGymID = nil
        if let locked = GymApproach.championLockedDialogue(content: content, save: store.adventureSave) {
            dialogue = locked
        } else {
            showingChampion = true
        }
    }
```

(The previously private `previousBadgeName(before:)` and `nextMissingBadgeName()` helpers are deleted from the view; their logic now lives in `GymApproach` and is Linux-tested there. `RegionMapScreen` no longer references `CircuitRules` at all — the unlock/lock decision and the champion door's former hardcoded string `"You need to clear the Elite Four first."` both moved into the engine and content.)

- [ ] **Step 4: Run all core tests**

Run: `scripts/test-core.sh`
Expected: `Executed 230 tests, with 0 failures (0 unexpected) in 0.993 (0.993) seconds`

- [ ] **Step 5: Commit**

Run: `git add FlashCards/IFRCore/Sources/IFRCore/Adventure/Battle/BattleDialogue.swift FlashCards/IFRCore/Sources/IFRCore/Adventure/Circuit/GymApproach.swift FlashCards/IFRCore/Sources/IFRCore/Resources/adventure-v1.json FlashCards/App/Screens/Adventure/BattleScreenModel.swift FlashCards/App/Screens/Adventure/RegionMapScreen.swift FlashCards/IFRCore/Tests/IFRCoreTests/BattleDialogueTests.swift FlashCards/IFRCore/Tests/IFRCoreTests/GymApproachTests.swift FlashCards/IFRCore/Tests/IFRCoreTests/AdventureContentTests.swift FlashCards/IFRCore/Tests/IFRCoreTests/SpriteCatalogTests.swift FlashCards/IFRCore/Tests/IFRCoreTests/SourceGuardTests.swift && git commit -m "M1-17: Refactor and content polish"`

---
