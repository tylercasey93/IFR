# Adventure Mode — Milestone 3: Companions, Rematches, Tower and Link

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One companion per category with three evolution stages tied to mastery, rematch notifications when a badge's category retention decays, a Battle Tower survival ladder with a Game Center board, link battles from a shared seven-character quiz seed, and optional chiptune sound behind a default-off toggle.

**Architecture:** `Adventure/Companions/`, `Adventure/Tower/` and `Adventure/Link/` add `CompanionStage`, `CompanionSpecies`, `CompanionPicker`, `BattleTower` and `LinkBattleCode`; `Adventure/Circuit/` gains `RematchAdvisor` and `RematchNotice`; `AdventureSave` gains the Milestone 3 fields. The app adds `CompanionScreen`, `EvolutionScreen`, `BattleTowerScreen`, `LinkShareSheet`, `App/Audio/Chiptune.swift`, the rematch request in `NotificationScheduler` and the tower leaderboard in `GameCenterService`.

**Prerequisite:** Milestones 1 and 2 are complete and `scripts/test-core.sh` is green.

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

### Task M3-01: Companion stages and content (Linux)

**Files:**
- Create: `IFRCore/Sources/IFRCore/Adventure/Companions/CompanionStage.swift`
- Create: `IFRCore/Sources/IFRCore/Adventure/Companions/CompanionSpecies.swift`
- Create: `IFRCore/Sources/IFRCore/Adventure/Companions/CompanionPicker.swift`
- Create: `IFRCore/Sources/IFRCore/Adventure/Pixel/Sprites/CompanionSprites.swift`
- Modify: `IFRCore/Sources/IFRCore/Adventure/Content/AdventureContent.swift`
- Modify: `IFRCore/Sources/IFRCore/Adventure/Pixel/SpriteCatalog.swift`
- Modify: `IFRCore/Sources/IFRCore/Resources/adventure-v1.json`
- Test: `IFRCore/Tests/IFRCoreTests/CompanionStageTests.swift`
- Test: `IFRCore/Tests/IFRCoreTests/CompanionPickerTests.swift`
- Test: `IFRCore/Tests/IFRCoreTests/CompanionContentTests.swift`

**Interfaces:**
- Consumes: `MasteryLevel` (`Progress/MasteryCalculator.swift`), `IFRCore.Category` and `GymID` (`Adventure/Circuit/GymID.swift`, whose `allCases` order is the circuit order), `AdventureContent`/`AdventureContent.load()` (`Adventure/Content/AdventureContent.swift`), `PixelSprite`/`recoloured(_:)` and `PlayerSprites.battleSilhouette` (`Adventure/Pixel/PixelSprite.swift`, `Adventure/Pixel/Sprites/PlayerSprites.swift`), `SpriteCatalog.sprite(named:)` (`Adventure/Pixel/SpriteCatalog.swift`)
- Produces: `CompanionStage: Int, Codable, Equatable, Sendable { hatchling = 1, journeyman, captain }` with `static func stage(for level: MasteryLevel) -> CompanionStage` and `static func evolved(from: CompanionStage, to: CompanionStage) -> Bool`; `CompanionSpecies: Codable, Equatable, Sendable { category: Category; stageNames: [String]; spriteIDs: [String] }` (replaces the Milestone-1 placeholder stub); `enum CompanionPicker { static func companion(for categories: [Category]?, stages: [Category: CompanionStage]) -> Category }`; `CompanionSprites.all: [String: PixelSprite]` merged into `SpriteCatalog.all`; eight `CompanionSpecies` entries (one per `Category`, three stage names and three sprite IDs each) in `adventure-v1.json`'s `companions` array, consumed by `AdventureContent.companions`

- [ ] **Step 1: Write the failing tests**

File: `IFRCore/Tests/IFRCoreTests/CompanionStageTests.swift`

```swift
import XCTest
@testable import IFRCore

final class CompanionStageTests: XCTestCase {
    func testNoviceAndApprenticeAreHatchling() {
        XCTAssertEqual(CompanionStage.stage(for: .novice), .hatchling)
        XCTAssertEqual(CompanionStage.stage(for: .apprentice), .hatchling)
    }

    func testCompetentAndProficientAreJourneyman() {
        XCTAssertEqual(CompanionStage.stage(for: .competent), .journeyman)
        XCTAssertEqual(CompanionStage.stage(for: .proficient), .journeyman)
    }

    func testInstrumentMasterIsCaptain() {
        XCTAssertEqual(CompanionStage.stage(for: .instrumentMaster), .captain)
    }

    func testEvolvedWhenStageRises() {
        XCTAssertTrue(CompanionStage.evolved(from: .hatchling, to: .journeyman))
        XCTAssertTrue(CompanionStage.evolved(from: .journeyman, to: .captain))
    }

    func testNotEvolvedWhenStageFalls() {
        XCTAssertFalse(CompanionStage.evolved(from: .journeyman, to: .hatchling))
        XCTAssertFalse(CompanionStage.evolved(from: .captain, to: .captain))
    }
}
```

File: `IFRCore/Tests/IFRCoreTests/CompanionPickerTests.swift`

```swift
import XCTest
@testable import IFRCore

final class CompanionPickerTests: XCTestCase {
    func testSingleCategoryBattleUsesThatCompanion() {
        let stages: [IFRCore.Category: CompanionStage] = [
            .regulations: .captain,
            .weather: .hatchling,
        ]
        let chosen = CompanionPicker.companion(for: [.weather], stages: stages)
        XCTAssertEqual(chosen, .weather)
    }

    func testMixedBattleUsesHighestStageThenCircuitOrder() {
        let stages: [IFRCore.Category: CompanionStage] = [
            .humanFactors: .journeyman,
            .instrumentsAndSystems: .captain,
            .regulations: .captain,
            .navigation: .hatchling,
        ]
        let chosen = CompanionPicker.companion(
            for: [.humanFactors, .instrumentsAndSystems, .regulations, .navigation], stages: stages
        )
        XCTAssertEqual(chosen, .instrumentsAndSystems)
    }
}
```

File: `IFRCore/Tests/IFRCoreTests/CompanionContentTests.swift`

```swift
import XCTest
@testable import IFRCore

final class CompanionContentTests: XCTestCase {
    private func loadCompanions() throws -> [CompanionSpecies] {
        try AdventureContent.load().companions
    }

    func testOneSpeciesPerCategoryWithThreeStages() throws {
        let companions = try loadCompanions()
        XCTAssertEqual(Set(companions.map(\.category)).count, IFRCore.Category.allCases.count)
        for category in IFRCore.Category.allCases {
            let species = companions.first { $0.category == category }
            XCTAssertNotNil(species, "missing companion for \(category.rawValue)")
            XCTAssertEqual(species?.stageNames.count, 3)
            XCTAssertEqual(species?.spriteIDs.count, 3)
        }
    }

    func testEveryCompanionSpriteIDResolves() throws {
        let companions = try loadCompanions()
        for species in companions {
            for spriteID in species.spriteIDs {
                XCTAssertNotNil(SpriteCatalog.sprite(named: spriteID), "missing sprite \(spriteID)")
            }
        }
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `scripts/test-core.sh --filter CompanionStageTests`
Expected:
```
CompanionStageTests.swift:25:54: error: cannot infer contextual base in reference to member 'journeyman'
CompanionStageTests.swift:26:24: error: cannot find 'CompanionStage' in scope
error: fatalError
```
(`CompanionPickerTests` and `CompanionContentTests` fail to compile the same way, on `CompanionStage`/`CompanionPicker` and on `AdventureContent.load().companions` not carrying real `category`/`stageNames`/`spriteIDs` fields, since `CompanionSpecies` was still the Milestone-1 empty placeholder `struct CompanionSpecies: Codable, Equatable, Sendable {}`.)

- [ ] **Step 3: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Companions/CompanionStage.swift`

```swift
import Foundation

public enum CompanionStage: Int, Codable, Equatable, Sendable {
    case hatchling = 1, journeyman, captain

    public static func stage(for level: MasteryLevel) -> CompanionStage {
        switch level.rawValue {
        case 1, 2: .hatchling
        case 3, 4: .journeyman
        default: .captain
        }
    }

    public static func evolved(from: CompanionStage, to: CompanionStage) -> Bool {
        to.rawValue > from.rawValue
    }
}
```

File: `IFRCore/Sources/IFRCore/Adventure/Companions/CompanionSpecies.swift`

```swift
import Foundation

public struct CompanionSpecies: Codable, Equatable, Sendable {
    public let category: Category
    public let stageNames: [String]
    public let spriteIDs: [String]

    public init(category: Category, stageNames: [String], spriteIDs: [String]) {
        self.category = category
        self.stageNames = stageNames
        self.spriteIDs = spriteIDs
    }
}
```

File: `IFRCore/Sources/IFRCore/Adventure/Companions/CompanionPicker.swift`

```swift
import Foundation

public enum CompanionPicker {
    public static func companion(for categories: [Category]?, stages: [Category: CompanionStage]) -> Category {
        if let categories, categories.count == 1, let only = categories.first {
            return only
        }
        let circuitOrder = GymID.allCases.map(\.category)
        let pool = categories ?? circuitOrder
        let candidates = pool.compactMap { category in stages[category].map { (category, $0) } }
        let best = candidates.max { lhs, rhs in
            isLower(lhs, than: rhs, circuitOrder: circuitOrder)
        }
        return best?.0 ?? circuitOrder[0]
    }

    private static func isLower(
        _ lhs: (Category, CompanionStage), than rhs: (Category, CompanionStage), circuitOrder: [Category]
    ) -> Bool {
        if lhs.1 != rhs.1 { return lhs.1.rawValue < rhs.1.rawValue }
        let leftIndex = circuitOrder.firstIndex(of: lhs.0) ?? Int.max
        let rightIndex = circuitOrder.firstIndex(of: rhs.0) ?? Int.max
        return leftIndex > rightIndex
    }
}
```

File: `IFRCore/Sources/IFRCore/Adventure/Pixel/Sprites/CompanionSprites.swift`

```swift
import Foundation

public enum CompanionSprites {
    public static let all: [String: PixelSprite] = [
        "comp-hf-1": hf1, "comp-hf-2": hf2, "comp-hf-3": hf3,
        "comp-ins-1": ins1, "comp-ins-2": ins2, "comp-ins-3": ins3,
        "comp-reg-1": reg1, "comp-reg-2": reg2, "comp-reg-3": reg3,
        "comp-nav-1": nav1, "comp-nav-2": nav2, "comp-nav-3": nav3,
        "comp-cnp-1": cnp1, "comp-cnp-2": cnp2, "comp-cnp-3": cnp3,
        "comp-wx-1": wx1, "comp-wx-2": wx2, "comp-wx-3": wx3,
        "comp-emg-1": emg1, "comp-emg-2": emg2, "comp-emg-3": emg3,
        "comp-app-1": app1, "comp-app-2": app2, "comp-app-3": app3,
    ]

    private static let hf1 = PlayerSprites.battleSilhouette.recoloured([1: 2, 4: 3, 9: 5])
    private static let hf2 = PlayerSprites.battleSilhouette.recoloured([1: 3, 4: 5, 9: 6])
    private static let hf3 = PlayerSprites.battleSilhouette.recoloured([1: 5, 4: 6, 9: 7])

    private static let ins1 = PlayerSprites.battleSilhouette.recoloured([1: 4, 4: 5, 9: 6])
    private static let ins2 = PlayerSprites.battleSilhouette.recoloured([1: 5, 4: 6, 9: 7])
    private static let ins3 = PlayerSprites.battleSilhouette.recoloured([1: 6, 4: 7, 9: 8])

    private static let reg1 = PlayerSprites.battleSilhouette.recoloured([1: 7, 4: 8, 9: 9])
    private static let reg2 = PlayerSprites.battleSilhouette.recoloured([1: 8, 4: 9, 9: 10])
    private static let reg3 = PlayerSprites.battleSilhouette.recoloured([1: 9, 4: 10, 9: 11])

    private static let nav1 = PlayerSprites.battleSilhouette.recoloured([1: 10, 4: 11, 9: 12])
    private static let nav2 = PlayerSprites.battleSilhouette.recoloured([1: 11, 4: 12, 9: 13])
    private static let nav3 = PlayerSprites.battleSilhouette.recoloured([1: 12, 4: 13, 9: 14])

    private static let cnp1 = PlayerSprites.battleSilhouette.recoloured([1: 13, 4: 14, 9: 15])
    private static let cnp2 = PlayerSprites.battleSilhouette.recoloured([1: 14, 4: 15, 9: 6])
    private static let cnp3 = PlayerSprites.battleSilhouette.recoloured([1: 15, 4: 6, 9: 7])

    private static let wx1 = PlayerSprites.battleSilhouette.recoloured([1: 0, 4: 2, 9: 4])
    private static let wx2 = PlayerSprites.battleSilhouette.recoloured([1: 1, 4: 3, 9: 5])
    private static let wx3 = PlayerSprites.battleSilhouette.recoloured([1: 2, 4: 4, 9: 6])

    private static let emg1 = PlayerSprites.battleSilhouette.recoloured([1: 1, 4: 3, 9: 5])
    private static let emg2 = PlayerSprites.battleSilhouette.recoloured([1: 2, 4: 4, 9: 6])
    private static let emg3 = PlayerSprites.battleSilhouette.recoloured([1: 3, 4: 5, 9: 7])

    private static let app1 = PlayerSprites.battleSilhouette.recoloured([1: 6, 4: 8, 9: 10])
    private static let app2 = PlayerSprites.battleSilhouette.recoloured([1: 7, 4: 9, 9: 11])
    private static let app3 = PlayerSprites.battleSilhouette.recoloured([1: 8, 4: 10, 9: 12])
}
```

- [ ] **Step 4: Modify `AdventureContent.swift` — drop the Milestone-1 placeholder**

The Milestone-1 file declared `CompanionSpecies` as an empty stub above `AdventureContent`; that declaration is removed now that `Companions/CompanionSpecies.swift` supplies the real type, so `AdventureContent.companions: [CompanionSpecies]` (unchanged) decodes real content:

```swift
public struct AdventureContent: Codable, Sendable {
    public let version: Int
    public let region: RegionMap
```

(the line `public struct CompanionSpecies: Codable, Equatable, Sendable {}` that previously sat just above this declaration is deleted.)

- [ ] **Step 5: Modify `SpriteCatalog.swift` — merge in the companion sprites**

```swift
import Foundation

public enum SpriteCatalog {
    public static let all: [String: PixelSprite] = UISprites.all
        .merging(PlayerSprites.all) { _, new in new }
        .merging(LeaderSprites.all) { _, new in new }
        .merging(EliteSprites.all) { _, new in new }
        .merging(TileSprites.all) { _, new in new }
        .merging(CompanionSprites.all) { _, new in new }

    public static func sprite(named name: String) -> PixelSprite? {
        all[name]
    }
}
```

- [ ] **Step 6: Modify `adventure-v1.json` — add the `companions` section**

```json
{
  "companions": [
    {
      "category": "humanFactors",
      "stageNames": ["Hypoxling", "Oxymander", "Pressurizor"],
      "spriteIDs": ["comp-hf-1", "comp-hf-2", "comp-hf-3"]
    },
    {
      "category": "instrumentsAndSystems",
      "stageNames": ["Gyrolet", "Gyrowing", "Gyrosteed"],
      "spriteIDs": ["comp-ins-1", "comp-ins-2", "comp-ins-3"]
    },
    {
      "category": "regulations",
      "stageNames": ["Regpup", "Regustar", "Regumarshal"],
      "spriteIDs": ["comp-reg-1", "comp-reg-2", "comp-reg-3"]
    },
    {
      "category": "navigation",
      "stageNames": ["Vectorlet", "Vectorwing", "Vectorlord"],
      "spriteIDs": ["comp-nav-1", "comp-nav-2", "comp-nav-3"]
    },
    {
      "category": "chartsAndPlanning",
      "stageNames": ["Plotlet", "Plotwing", "Plotmaster"],
      "spriteIDs": ["comp-cnp-1", "comp-cnp-2", "comp-cnp-3"]
    },
    {
      "category": "weather",
      "stageNames": ["Nimblet", "Nimbuswing", "Nimbustorm"],
      "spriteIDs": ["comp-wx-1", "comp-wx-2", "comp-wx-3"]
    },
    {
      "category": "emergencies",
      "stageNames": ["Maydaylet", "Maydaywing", "Maydayguard"],
      "spriteIDs": ["comp-emg-1", "comp-emg-2", "comp-emg-3"]
    },
    {
      "category": "approaches",
      "stageNames": ["Ilsalet", "Ilsawing", "Ilsapilot"],
      "spriteIDs": ["comp-app-1", "comp-app-2", "comp-app-3"]
    }
  ]
}
```

(this key was added to the existing top-level `adventure-v1.json` object, alongside `region`, `gyms`, `eliteFour`, `champion`, `dialogue`, `system`, `items`, `tileMap`, `trainers` and `rival`, which are unchanged.)

- [ ] **Step 7: Run all core tests**

Run: `scripts/test-core.sh`
Expected: `Executed 343 tests, with 0 failures (0 unexpected)`

- [ ] **Step 8: Commit**

Run: `git add FlashCards/IFRCore/Sources/IFRCore/Adventure/Companions FlashCards/IFRCore/Sources/IFRCore/Adventure/Pixel/Sprites/CompanionSprites.swift FlashCards/IFRCore/Sources/IFRCore/Adventure/Content/AdventureContent.swift FlashCards/IFRCore/Sources/IFRCore/Adventure/Pixel/SpriteCatalog.swift FlashCards/IFRCore/Sources/IFRCore/Resources/adventure-v1.json FlashCards/IFRCore/Tests/IFRCoreTests/CompanionStageTests.swift FlashCards/IFRCore/Tests/IFRCoreTests/CompanionPickerTests.swift FlashCards/IFRCore/Tests/IFRCoreTests/CompanionContentTests.swift && git commit -m "M3-01: Companion stages and content"`

---

### Task M3-02: Companion screen and evolution cutscene (Xcode)

**Files:**
- Create: `App/Screens/Adventure/CompanionScreen.swift`
- Create: `App/Screens/Adventure/EvolutionScreen.swift`
- Create: `IFRCore/Sources/IFRCore/Adventure/Companions/CompanionEvolution.swift`
- Create: `IFRCore/Sources/IFRCore/Adventure/Pixel/EvolutionRenderer.swift`
- Modify: `IFRCore/Sources/IFRCore/Adventure/Circuit/AdventureSave.swift`
- Modify: `App/Persistence/StudyStore.swift`
- Modify: `App/Screens/Adventure/AdventureView.swift`
- Modify: `App/Screens/Adventure/OverworldScreen.swift`
- Test: `IFRCore/Tests/IFRCoreTests/AdventureSaveTests.swift`
- Test: `AppTests/AdventureStoreTests.swift`

**Interfaces:**
- Consumes: `CompanionStage.stage(for:)` / `CompanionStage.evolved(from:to:)` (`IFRCore/Sources/IFRCore/Adventure/Companions/CompanionStage.swift`), `CompanionSpecies` (`.../Companions/CompanionSpecies.swift`), `MasteryLevel` (`IFRCore/Sources/IFRCore/Progress/MasteryCalculator.swift`), `BattleWipe.frame(_:)` / `BattleWipe.totalFrames` (`.../Adventure/Pixel/BattleWipe.swift`), `SpriteCatalog.sprite(named:)` (`.../Adventure/Pixel/SpriteCatalog.swift`), `PixelFrame` (`.../Adventure/Pixel/PixelFrame.swift`), `AdventureContent.companions` (`.../Adventure/Content/AdventureContent.swift`), `StudyStore.adventureMastery(for:)` / `StudyStore.adventureSave` / `StudyStore.updateAdventureSave(_:)` (`App/Persistence/StudyStore.swift`), `GBAScreen`, `RetroTheme.pixelFont`/`pixelFontSize` (`App/Theme/RetroTheme.swift`), `OverworldScreen`'s existing `fullScreenCover(item:)` battle wiring.
- Produces: `CompanionEvolution: Equatable, Sendable { category: Category; from: CompanionStage; to: CompanionStage }`; `AdventureSave.seenCompanionStages: [String: Int]` (keyed by `Category.rawValue`, decodes to `[:]` when absent); `enum EvolutionRenderer { static func frame(fromSpriteID: String, toSpriteID: String, atFrame: Int) -> PixelFrame }`; `StudyStore.pendingEvolutions() -> [CompanionEvolution]` (compares all eight categories' current `CompanionStage` against the stored one, returns only rises, and silently persists every changed stage, rise or fall, through `updateAdventureSave`); `CompanionScreen: View` and `EvolutionScreen: View` for later tasks (e.g. Battle Tower, link battles) to present alongside.

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
        XCTAssertEqual(decoded.position, GridPoint(x: 14, y: 1))
        XCTAssertEqual(decoded.facing, .right)
    }

    func testDecodingOlderSaveMissingKeysUsesDefaults() throws {
        let json = "{\"badges\":[]}"
        let decoded = try JSONDecoder().decode(AdventureSave.self, from: Data(json.utf8))
        XCTAssertEqual(decoded, AdventureSave.new)
    }

    func testOlderSaveWithoutDefeatedTrainerIDsDecodes() throws {
        let json = "{\"badges\":[]}"
        let decoded = try JSONDecoder().decode(AdventureSave.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.defeatedTrainerIDs, [])
    }

    func testOlderSaveWithoutInventoryDecodes() throws {
        let json = "{\"badges\":[]}"
        let decoded = try JSONDecoder().decode(AdventureSave.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.inventory, [:])
    }

    func testOlderSaveWithoutRivalEncountersDecodes() throws {
        let json = "{\"badges\":[]}"
        let decoded = try JSONDecoder().decode(AdventureSave.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.rivalEncountersDone, [])
    }

    func testOlderSaveWithoutPositionDecodes() throws {
        let json = "{\"badges\":[]}"
        let decoded = try JSONDecoder().decode(AdventureSave.self, from: Data(json.utf8))
        XCTAssertNil(decoded.position)
        XCTAssertNil(decoded.facing)
    }

    func testSeenCompanionStagesDecodeWithDefault() throws {
        let json = "{\"badges\":[]}"
        let decoded = try JSONDecoder().decode(AdventureSave.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.seenCompanionStages, [:])
        XCTAssertEqual(decoded.seenCompanionStages["humanFactors"] ?? CompanionStage.hatchling.rawValue, CompanionStage.hatchling.rawValue)
    }

    func testSaveFromNewerVersionThrows() {
        let json = "{\"saveVersion\": 2}"
        XCTAssertThrowsError(try JSONDecoder().decode(AdventureSave.self, from: Data(json.utf8))) {
            XCTAssertEqual($0 as? AdventureSaveError, .newerThanApp(2))
        }
    }
}
```

File: `AppTests/AdventureStoreTests.swift` (new functions added to the existing class; only the two new tests are shown, appended just before the private factory helpers)

```swift
    func testEvolutionPlaysOnceWhenMasteryCrossesStage() throws {
        let (store, _) = try makeStore()
        let tenRegulations = store.bank.questions(in: .regulations).filter(\.isMultipleChoiceCapable).prefix(10)
        for question in tenRegulations {
            store.submitAdventureAnswer(question, selectedIndex: question.correctIndex!)
        }
        let expectedStage = CompanionStage.stage(for: store.adventureMastery(for: .regulations).level)

        let evolutions = store.pendingEvolutions()

        XCTAssertEqual(evolutions, [CompanionEvolution(category: .regulations, from: .hatchling, to: expectedStage)])
        XCTAssertTrue(store.pendingEvolutions().isEmpty)
    }

    func testStageFallStoresSilently() throws {
        let (store, _) = try makeStore()
        var save = store.adventureSave
        save.seenCompanionStages[IFRCore.Category.regulations.rawValue] = CompanionStage.captain.rawValue
        store.updateAdventureSave(save)

        let evolutions = store.pendingEvolutions()

        XCTAssertTrue(evolutions.isEmpty)
        XCTAssertEqual(store.adventureSave.seenCompanionStages[IFRCore.Category.regulations.rawValue], CompanionStage.hatchling.rawValue)
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `scripts/test-core.sh --filter AdventureSaveTests`
Expected (observed by temporarily reverting `AdventureSave.swift` and rerunning):
```
error: value of type 'AdventureSave' has no member 'seenCompanionStages'
error: type 'Any' cannot conform to 'Equatable'
```
For `AppTests/AdventureStoreTests.swift` (App target, not runnable on this Linux machine): before `StudyStore.pendingEvolutions()` and `CompanionEvolution` exist, Xcode reports `cannot find type 'CompanionEvolution' in scope` and `value of type 'StudyStore' has no member 'pendingEvolutions'` on both new test functions.

- [ ] **Step 3: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Companions/CompanionEvolution.swift`

```swift
import Foundation

public struct CompanionEvolution: Equatable, Sendable {
    public let category: Category
    public let from: CompanionStage
    public let to: CompanionStage

    public init(category: Category, from: CompanionStage, to: CompanionStage) {
        self.category = category
        self.from = from
        self.to = to
    }
}
```

File: `IFRCore/Sources/IFRCore/Adventure/Pixel/EvolutionRenderer.swift`

```swift
import Foundation

public enum EvolutionRenderer {
    private static let panelIndex: UInt8 = 1
    private static let flashWhiteIndex: UInt8 = 15
    private static let flashInkIndex: UInt8 = 0
    private static let spriteOrigin = GridPoint(x: 96, y: 56)

    public static func frame(fromSpriteID: String, toSpriteID: String, atFrame frame: Int) -> PixelFrame {
        var canvas = PixelFrame(fill: panelIndex)
        let wipeFrame = BattleWipe.frame(min(frame, BattleWipe.totalFrames - 1))
        if let flashWhite = wipeFrame.flashWhite {
            return PixelFrame(fill: flashWhite ? flashWhiteIndex : flashInkIndex)
        }
        let spriteID = frame < BattleWipe.totalFrames ? fromSpriteID : toSpriteID
        if let sprite = SpriteCatalog.sprite(named: spriteID) {
            canvas.blit(sprite, at: spriteOrigin)
        }
        return canvas
    }
}
```

File: `IFRCore/Sources/IFRCore/Adventure/Circuit/AdventureSave.swift` (whole file, with the new `seenCompanionStages` field)

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
    public var seenCompanionStages: [String: Int]

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
        repelStepsLeft: Int = 0, position: GridPoint? = nil, facing: Direction? = nil, rivalEncountersDone: Set<Int> = [],
        seenCompanionStages: [String: Int] = [:]
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
        self.seenCompanionStages = seenCompanionStages
    }

    private enum CodingKeys: String, CodingKey {
        case saveVersion, badges, badgeQuestionIDs, eliteFourCleared, championWins,
             hallOfFame, battlesWon, battlesLost, visitedAirportIDs, defeatedTrainerIDs,
             collectedItemIDs, inventory, repelStepsLeft, position, facing, rivalEncountersDone,
             seenCompanionStages
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
        self.seenCompanionStages = try container.decodeIfPresent([String: Int].self, forKey: .seenCompanionStages) ?? [:]
    }
}
```

File: `App/Persistence/StudyStore.swift` (new methods, inserted in the `// MARK: - Adventure save` section just before `badgeQuestionRetention()`)

```swift
    func pendingEvolutions() -> [CompanionEvolution] {
        _ = revision
        let previous = adventureSave
        var save = previous
        let rises = IFRCore.Category.allCases.compactMap { evolution(for: $0, save: &save) }
        if save != previous {
            updateAdventureSave(save)
        }
        return rises
    }

    private func evolution(for category: IFRCore.Category, save: inout AdventureSave) -> CompanionEvolution? {
        let stored = save.seenCompanionStages[category.rawValue].flatMap(CompanionStage.init) ?? .hatchling
        let current = CompanionStage.stage(for: adventureMastery(for: category).level)
        guard current != stored else { return nil }
        save.seenCompanionStages[category.rawValue] = current.rawValue
        return CompanionStage.evolved(from: stored, to: current)
            ? CompanionEvolution(category: category, from: stored, to: current) : nil
    }
```

File: `App/Screens/Adventure/CompanionScreen.swift`

```swift
import SwiftUI
import IFRCore

struct CompanionScreen: View {
    @Environment(StudyStore.self) private var store
    let content: AdventureContent

    var body: some View {
        List(IFRCore.Category.allCases, id: \.self) { category in
            HStack {
                Text(category.displayName)
                Spacer()
                Text(stageName(for: category))
            }
            .accessibilityIdentifier("companionSlot-\(category.rawValue)")
        }
        .navigationTitle("Companions")
    }

    private func stageName(for category: IFRCore.Category) -> String {
        let stage = CompanionStage.stage(for: store.adventureMastery(for: category).level)
        guard let species = content.companions.first(where: { $0.category == category }),
              species.stageNames.indices.contains(stage.rawValue - 1) else {
            return category.displayName
        }
        return species.stageNames[stage.rawValue - 1]
    }
}
```

File: `App/Screens/Adventure/EvolutionScreen.swift`

```swift
import SwiftUI
import IFRCore

struct EvolutionScreen: View {
    let evolution: CompanionEvolution
    let content: AdventureContent
    var onFinished: () -> Void = {}

    @Environment(\.displayScale) private var displayScale
    @State private var phaseStart = Date()

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation) { context in
                let frame = frameIndex(at: context.date)
                ZStack(alignment: .bottom) {
                    GBAScreen(frame: renderedFrame(atFrame: frame))
                    Text(caption(atFrame: frame))
                        .font(RetroTheme.pixelFont(size: RetroTheme.pixelFontSize(scale: 1, displayScale: displayScale)))
                        .foregroundStyle(.white)
                        .padding(.bottom, 12)
                }
                .contentShape(Rectangle())
                .onTapGesture { if frame >= BattleWipe.totalFrames { onFinished() } }
            }
        }
        .accessibilityIdentifier("evolutionScreen")
    }

    private func frameIndex(at date: Date) -> Int {
        max(0, Int(date.timeIntervalSince(phaseStart) * 60))
    }

    private func renderedFrame(atFrame frame: Int) -> PixelFrame {
        EvolutionRenderer.frame(
            fromSpriteID: spriteID(for: evolution.from), toSpriteID: spriteID(for: evolution.to), atFrame: frame)
    }

    private func species() -> CompanionSpecies? {
        content.companions.first { $0.category == evolution.category }
    }

    private func spriteID(for stage: CompanionStage) -> String {
        guard let species = species(), species.spriteIDs.indices.contains(stage.rawValue - 1) else { return "" }
        return species.spriteIDs[stage.rawValue - 1]
    }

    private func companionName(for stage: CompanionStage) -> String {
        guard let species = species(), species.stageNames.indices.contains(stage.rawValue - 1) else {
            return evolution.category.displayName
        }
        return species.stageNames[stage.rawValue - 1]
    }

    private func caption(atFrame frame: Int) -> String {
        frame >= BattleWipe.totalFrames ? "\(companionName(for: evolution.to)) evolved!" : ""
    }
}
```

File: `App/Screens/Adventure/AdventureView.swift` (whole file, wiring the tab-appear and post-battle evolution checks)

```swift
import SwiftUI
import IFRCore

struct AdventureView: View {
    @Environment(StudyStore.self) private var store
    @State private var content: AdventureContent?
    @State private var showingBadgeCase = false
    @State private var showingHallOfFame = false
    @State private var showingCompanions = false
    @State private var evolutionQueue: [CompanionEvolution] = []

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
                    OverworldScreen(content: content, seed: seed, onBattleFinished: checkEvolutions)
                } else {
                    ProgressView()
                        .onAppear { load() }
                }
            }
            .toolbar {
                if content != nil {
                    ToolbarItem { Button("Badges") { showingBadgeCase = true }.accessibilityIdentifier("badgeCase") }
                    ToolbarItem { Button("Hall of Fame") { showingHallOfFame = true }.accessibilityIdentifier("hallOfFame") }
                    ToolbarItem { Button("Companions") { showingCompanions = true }.accessibilityIdentifier("companions") }
                }
            }
            .navigationDestination(isPresented: $showingBadgeCase) {
                if let content { BadgeCaseScreen(content: content) }
            }
            .navigationDestination(isPresented: $showingHallOfFame) {
                HallOfFameScreen()
            }
            .navigationDestination(isPresented: $showingCompanions) {
                if let content { CompanionScreen(content: content) }
            }
            .onAppear { checkEvolutions() }
            .fullScreenCover(isPresented: evolutionShowingBinding()) {
                if let content, let evolution = evolutionQueue.first {
                    EvolutionScreen(evolution: evolution, content: content, onFinished: { evolutionQueue.removeFirst() })
                }
            }
        }
    }

    private func load() {
        content = try? AdventureContent.load()
        if let seededSave {
            store.updateAdventureSave(seededSave)
        }
    }

    private func checkEvolutions() {
        evolutionQueue.append(contentsOf: store.pendingEvolutions())
    }

    private func evolutionShowingBinding() -> Binding<Bool> {
        Binding(get: { !evolutionQueue.isEmpty }, set: { showing in if !showing { evolutionQueue.removeAll() } })
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

File: `App/Screens/Adventure/OverworldScreen.swift` — changed lines only (an `onBattleFinished` closure is now threaded through to the existing battle `fullScreenCover`)

```swift
struct OverworldScreen: View {
    @Environment(StudyStore.self) private var store
    @Environment(\.displayScale) private var displayScale
    @Environment(\.scenePhase) private var scenePhase
    let content: AdventureContent
    let seed: UInt64?
    var onBattleFinished: () -> Void = {}

    @State private var model: OverworldScreenModel?
    @State private var showingMap = false
```

```swift
        .fullScreenCover(item: activeBattleBinding(model)) { run in
            BattleScreen(run: run).onDisappear {
                model.battleDismissed()
                onBattleFinished()
            }
        }
```

- [ ] **Step 4: Run all core tests**

Run: `scripts/test-core.sh`
Expected: `Executed 344 tests, with 0 failures (0 unexpected) in 1.609 (1.609) seconds`

App-target tests (`AppTests/AdventureStoreTests.swift`) cannot be run on this Linux machine; in Xcode both new tests are expected to pass once `CompanionEvolution` and `StudyStore.pendingEvolutions()` exist, since they follow the same setup already exercised (and passing) in `testAdventureMasteryUsesReviewedRetention`.

- [ ] **Step 5: Commit**

Run: `git add FlashCards/App/Persistence/StudyStore.swift FlashCards/App/Screens/Adventure/AdventureView.swift FlashCards/App/Screens/Adventure/OverworldScreen.swift FlashCards/App/Screens/Adventure/CompanionScreen.swift FlashCards/App/Screens/Adventure/EvolutionScreen.swift FlashCards/AppTests/AdventureStoreTests.swift FlashCards/IFRCore/Sources/IFRCore/Adventure/Circuit/AdventureSave.swift FlashCards/IFRCore/Sources/IFRCore/Adventure/Companions/CompanionEvolution.swift FlashCards/IFRCore/Sources/IFRCore/Adventure/Pixel/EvolutionRenderer.swift FlashCards/IFRCore/Tests/IFRCoreTests/AdventureSaveTests.swift && git commit -m "M3-02: Companion screen and evolution cutscene"`

---

### Task M3-03: Rematch advisor and notification

**Files:**
- Create: `IFRCore/Sources/IFRCore/Adventure/Circuit/RematchAdvisor.swift`
- Create: `IFRCore/Sources/IFRCore/Adventure/Circuit/RematchNotice.swift`
- Modify: `IFRCore/Sources/IFRCore/Adventure/Circuit/AdventureSave.swift`
- Modify: `App/Notifications/NotificationScheduler.swift`
- Modify: `App/IFRFlashCardsApp.swift`
- Test: `IFRCore/Tests/IFRCoreTests/RematchAdvisorTests.swift`
- Test: `IFRCore/Tests/IFRCoreTests/RematchNoticeTests.swift`
- Test: `IFRCore/Tests/IFRCoreTests/AdventureSaveTests.swift` (one function added)
- Test: `AppTests/NotificationSchedulerTests.swift` (four functions added)

**Interfaces:**
- Consumes: `AdventureSave` (`IFRCore/Sources/IFRCore/Adventure/Circuit/AdventureSave.swift`), `GymID` (`.../Circuit/GymID.swift`), `MasteryCalculator.reviewedRetention` (`IFRCore/Sources/IFRCore/Progress/MasteryCalculator.swift`), `AdventureContent`, `Gym`, `RegionMap`/`Airport` (`.../Content/AdventureContent.swift`, `Gym.swift`, `RegionMap.swift`), `NotificationScheduler.handledTab`/`dailyReminderRequest`/`streakRiskRequest` (`App/Notifications/NotificationScheduler.swift`), `StudyStore.adventureSave`/`updateAdventureSave`/`reviewedRetentionByCategory`/`badgeQuestionRetention` (`App/Persistence/StudyStore.swift`)
- Produces: `RematchAdvisor.gymsAtRisk(save:categoryRetention:badgeQuestionRetention:threshold:) -> [GymID]`; `RematchNotice { gym: GymID; leaderName: String; badgeName: String; airportID: String }` with `RematchNotice.notice(for:content:) -> RematchNotice?`; `AdventureSave.lastRematchNotice: Date?`; `NotificationScheduler.rematchID(_:) -> String`, `NotificationScheduler.allRematchIDs: [String]`, `NotificationScheduler.rematchRequest(_:hour:minute:now:calendar:) -> UNNotificationRequest`, and `NotificationScheduler.refresh(...)` gaining `rematches: [RematchNotice] = []`, `lastRematchNotice: Date? = nil` and a `@discardableResult Bool` return — all used by later work items (`M3-04`, `M3-05` reuse `AdventureSave`/`NotificationScheduler` unchanged in shape).

- [ ] **Step 1: Write the failing tests**

File: `IFRCore/Tests/IFRCoreTests/RematchAdvisorTests.swift`

```swift
import XCTest
@testable import IFRCore

final class RematchAdvisorTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let scheduler = Scheduler()

    private func question(_ id: String, _ category: IFRCore.Category) -> Question {
        Question(id: id, category: category, acsCodes: ["IR.I.A.K1"], format: .flashcard,
                 front: "f", back: "b", options: nil, correctIndex: nil, explanation: "e",
                 source: SourceRef(document: "d", section: "s", url: URL(string: "https://faa.gov")!),
                 figure: nil, difficulty: 1)
    }

    private func badgedSave(_ gyms: GymID...) -> AdventureSave {
        var save = AdventureSave.new
        save.badges = Set(gyms)
        return save
    }

    func testBadgedGymBelowPointSixIsAtRisk() {
        let save = badgedSave(.humanFactors)
        let atRisk = RematchAdvisor.gymsAtRisk(
            save: save, categoryRetention: [.humanFactors: 0.59], badgeQuestionRetention: [.humanFactors: 0.9])
        XCTAssertEqual(atRisk, [.humanFactors])
    }

    func testFreshGymWinIsNotAtRisk() {
        let calc = MasteryCalculator(scheduler: scheduler)
        var questions: [Question] = []
        for i in 0..<100 {
            questions.append(question("hf-\(i)", .humanFactors))
        }
        let bank = QuestionBank(version: 1, questions: questions)
        var states: [String: CardState] = [:]
        for i in 0..<10 {
            states["hf-\(i)"] = scheduler.review(.new(questionID: "hf-\(i)"), grade: .good, at: now)
        }
        let retention = calc.reviewedRetention(.humanFactors, bank: bank, states: states, at: now)
        let save = badgedSave(.humanFactors)
        let atRisk = RematchAdvisor.gymsAtRisk(
            save: save, categoryRetention: [.humanFactors: retention], badgeQuestionRetention: [.humanFactors: retention])
        XCTAssertEqual(atRisk, [])
    }

    func testRetentionIgnoresUnseenCardsUntilCoverageMet() {
        let calc = MasteryCalculator(scheduler: scheduler)
        var questions: [Question] = []
        for i in 0..<15 {
            questions.append(question("hf-\(i)", .humanFactors))
        }
        let bank = QuestionBank(version: 1, questions: questions)
        var states: [String: CardState] = [:]
        for i in 0..<9 {
            states["hf-\(i)"] = scheduler.review(.new(questionID: "hf-\(i)"), grade: .good, at: now)
        }
        XCTAssertEqual(calc.reviewedRetention(.humanFactors, bank: bank, states: states, at: now), 0)
        states["hf-9"] = scheduler.review(.new(questionID: "hf-9"), grade: .good, at: now)
        let expected = states.values.map { scheduler.retrievability(of: $0, at: now) }
            .reduce(0, +) / Double(states.count)
        XCTAssertEqual(calc.reviewedRetention(.humanFactors, bank: bank, states: states, at: now), expected, accuracy: 0.0001)
    }

    func testBadgeQuestionsBelowThresholdFlagGymEvenWhenCategoryIsFine() {
        let save = badgedSave(.humanFactors)
        let atRisk = RematchAdvisor.gymsAtRisk(
            save: save, categoryRetention: [.humanFactors: 0.9], badgeQuestionRetention: [.humanFactors: 0.5])
        XCTAssertEqual(atRisk, [.humanFactors])
    }

    func testUnbadgedGymNeverAtRisk() {
        let atRisk = RematchAdvisor.gymsAtRisk(
            save: .new, categoryRetention: [.humanFactors: 0.1], badgeQuestionRetention: [.humanFactors: 0.1])
        XCTAssertEqual(atRisk, [])
    }

    func testThresholdIsInclusive() {
        let save = badgedSave(.humanFactors)
        let atRisk = RematchAdvisor.gymsAtRisk(
            save: save, categoryRetention: [.humanFactors: 0.6], badgeQuestionRetention: [.humanFactors: 0.9])
        XCTAssertEqual(atRisk, [.humanFactors])
    }

    func testSortedByLowestRetention() {
        let save = badgedSave(.humanFactors, .instrumentsAndSystems, .regulations)
        let atRisk = RematchAdvisor.gymsAtRisk(
            save: save,
            categoryRetention: [.humanFactors: 0.3, .instrumentsAndSystems: 0.55, .regulations: 0.1],
            badgeQuestionRetention: [.humanFactors: 0.5, .instrumentsAndSystems: 0.2, .regulations: 0.4])
        XCTAssertEqual(atRisk, [.regulations, .instrumentsAndSystems, .humanFactors])
    }
}
```

File: `IFRCore/Tests/IFRCoreTests/RematchNoticeTests.swift`

```swift
import XCTest
@testable import IFRCore

final class RematchNoticeTests: XCTestCase {
    private func makeGym(
        id: GymID, leaderName: String, badgeName: String
    ) -> Gym {
        Gym(id: id, leaderName: leaderName, nameplateName: "X", leaderSpriteID: "leader-x",
            badgeName: badgeName, questionCount: 10,
            dialogue: DialogueRefs(intro: "x-intro", win: "x-win", lose: "x-lose"))
    }

    private func makeContent() -> AdventureContent {
        AdventureContent(
            version: 1,
            region: RegionMap(airports: [
                Airport(id: "KHYP", name: "Hypoxia Field", position: GridPoint(x: 3, y: 12),
                        gymID: .humanFactors, role: .gym)
            ], airways: []),
            gyms: [
                makeGym(id: .humanFactors, leaderName: "Dr. Hypoxia", badgeName: "Oxygen Badge"),
                makeGym(id: .instrumentsAndSystems, leaderName: "Gyro", badgeName: "Gyro Badge")
            ],
            eliteFour: [],
            champion: ChampionSpec(
                name: "The DPE", nameplateName: "THE DPE", spriteID: "champion",
                dialogue: DialogueRefs(intro: "champion-intro", win: "champion-win", lose: "champion-lose")
            ),
            dialogue: [:], system: [:], items: []
        )
    }

    func testRematchNoticeReadsLeaderBadgeAndAirportFromContent() {
        let content = makeContent()
        let notice = RematchNotice.notice(for: .humanFactors, content: content)
        XCTAssertEqual(notice, RematchNotice(
            gym: .humanFactors, leaderName: "Dr. Hypoxia", badgeName: "Oxygen Badge", airportID: "KHYP"))
        XCTAssertNil(RematchNotice.notice(for: .instrumentsAndSystems, content: content))
    }
}
```

Added to `IFRCore/Tests/IFRCoreTests/AdventureSaveTests.swift` (existing file, before `testSaveFromNewerVersionThrows`):

```swift
    func testOlderSaveWithoutRematchNoticeDecodes() throws {
        let json = "{\"badges\":[]}"
        let decoded = try JSONDecoder().decode(AdventureSave.self, from: Data(json.utf8))
        XCTAssertNil(decoded.lastRematchNotice)
    }
```

Added to `AppTests/NotificationSchedulerTests.swift` (existing file; also adds `import IFRCore` and two private helpers, `notice(...)` and `pendingIdentifiers()`, at the top of the class):

```swift
    private func notice(_ gym: GymID, leader: String, badge: String, airport: String) -> RematchNotice {
        RematchNotice(gym: gym, leaderName: leader, badgeName: badge, airportID: airport)
    }

    private func pendingIdentifiers() -> [String] {
        var result: [String] = []
        let expectation = expectation(description: "pending")
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            result = requests.map(\.identifier)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
        return result
    }

    @MainActor
    func testRematchRequestDeepLinksToAdventureTab() {
        let hypoxia = notice(.humanFactors, leader: "Dr. Hypoxia", badge: "Oxygen Badge", airport: "KHYP")
        let request = NotificationScheduler.rematchRequest(hypoxia, hour: 18, minute: 0, now: now, calendar: calendar)
        XCTAssertEqual(request.identifier, "gymRematch-humanFactors")
        XCTAssertEqual(request.content.userInfo["tab"] as? String, "adventure")
        XCTAssertEqual(request.content.body, "Your Oxygen Badge is tarnishing. Rematch Dr. Hypoxia at KHYP.")
        let trigger = request.trigger as! UNCalendarNotificationTrigger
        XCTAssertFalse(trigger.repeats)
        XCTAssertEqual(trigger.dateComponents.hour, 18)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: now)!
        XCTAssertEqual(trigger.dateComponents.day, calendar.component(.day, from: nextDay))
    }

    @MainActor
    func testRefreshSchedulesOnlyTheFirstRematchAtMostOncePerWeek() {
        let scheduler = NotificationScheduler()
        let notices = [
            notice(.humanFactors, leader: "Dr. Hypoxia", badge: "Oxygen Badge", airport: "KHYP"),
            notice(.instrumentsAndSystems, leader: "Gyro", badge: "Gyro Badge", airport: "KGYR"),
            notice(.regulations, leader: "Marshal Reg", badge: "Reg Badge", airport: "KREG")
        ]
        let scheduled = scheduler.refresh(
            reminderEnabled: true, reminderHour: 18, reminderMinute: 0,
            streakRiskEnabled: false, goalMetToday: true, streak: 0, dueCount: 0,
            now: now, calendar: calendar, rematches: notices, lastRematchNotice: nil)
        XCTAssertTrue(scheduled)
        XCTAssertEqual(pendingIdentifiers().filter { $0.hasPrefix("gymRematch-") }, ["gymRematch-humanFactors"])

        let recent = scheduler.refresh(
            reminderEnabled: true, reminderHour: 18, reminderMinute: 0,
            streakRiskEnabled: false, goalMetToday: true, streak: 0, dueCount: 0,
            now: now, calendar: calendar, rematches: notices,
            lastRematchNotice: now.addingTimeInterval(-6 * 86400))
        XCTAssertFalse(recent)
        XCTAssertTrue(pendingIdentifiers().filter { $0.hasPrefix("gymRematch-") }.isEmpty)
    }

    @MainActor
    func testRematchNoticesRespectReminderEnabled() {
        let scheduler = NotificationScheduler()
        let scheduled = scheduler.refresh(
            reminderEnabled: false, reminderHour: 18, reminderMinute: 0,
            streakRiskEnabled: false, goalMetToday: true, streak: 0, dueCount: 0,
            now: now, calendar: calendar,
            rematches: [notice(.humanFactors, leader: "Dr. Hypoxia", badge: "Oxygen Badge", airport: "KHYP")],
            lastRematchNotice: nil)
        XCTAssertFalse(scheduled)
        XCTAssertTrue(pendingIdentifiers().filter { $0.hasPrefix("gymRematch-") }.isEmpty)
    }

    @MainActor
    func testRefreshRemovesStaleRematchRequests() {
        let scheduler = NotificationScheduler()
        for gym in GymID.allCases {
            let stale = notice(gym, leader: "Old Leader", badge: "Old Badge", airport: "KXXX")
            UNUserNotificationCenter.current().add(
                NotificationScheduler.rematchRequest(stale, hour: 18, minute: 0, now: now, calendar: calendar))
        }
        _ = scheduler.refresh(
            reminderEnabled: false, reminderHour: 18, reminderMinute: 0,
            streakRiskEnabled: false, goalMetToday: true, streak: 0, dueCount: 0,
            now: now, calendar: calendar)
        let identifiers = pendingIdentifiers()
        XCTAssertTrue(GymID.allCases.allSatisfy { !identifiers.contains(NotificationScheduler.rematchID($0)) })
    }
```

(The class also gained `private let now = Date(timeIntervalSince1970: 1_800_000_000)` and `private let calendar = Calendar(identifier: .gregorian)` stored properties.)

- [ ] **Step 2: Run the tests to verify they fail**

Run: `scripts/test-core.sh --filter RematchAdvisorTests`
Expected (observed): compilation fails inside `RematchNoticeTests.swift` (built in the same test target) with
```
error: cannot find 'RematchNotice' in scope
error: cannot infer contextual base in reference to member 'humanFactors'
```
repeated for every use of `RematchNotice` and `.humanFactors`/`.instrumentsAndSystems` in that file, and the whole package build then aborts with `error: fatalError` before any test runs — `RematchAdvisor` and `RematchNotice` do not exist yet in `Sources/IFRCore`.

For `AppTests/NotificationSchedulerTests.swift`, run `scripts/test-app.sh` (not run on this Linux machine): Xcode would show `Cannot find type 'RematchNotice' in scope`, `Value of type 'NotificationScheduler' has no member 'rematchRequest'`, `has no member 'rematchID'`, and `Argument passed to call that takes no arguments` on the `rematches:`/`lastRematchNotice:` labels of `refresh(...)`, because `AdventureSave.lastRematchNotice`, `RematchNotice` and the new `NotificationScheduler` members do not exist until Step 3.

- [ ] **Step 3: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Circuit/RematchAdvisor.swift`

```swift
import Foundation

public enum RematchAdvisor {
    public static func gymsAtRisk(
        save: AdventureSave, categoryRetention: [GymID: Double], badgeQuestionRetention: [GymID: Double],
        threshold: Double = 0.6
    ) -> [GymID] {
        save.badges
            .map { ($0, lowerRetention($0, categoryRetention: categoryRetention, badgeQuestionRetention: badgeQuestionRetention)) }
            .filter { $0.1 <= threshold }
            .sorted { $0.1 < $1.1 }
            .map(\.0)
    }

    private static func lowerRetention(
        _ gym: GymID, categoryRetention: [GymID: Double], badgeQuestionRetention: [GymID: Double]
    ) -> Double {
        min(categoryRetention[gym] ?? 0, badgeQuestionRetention[gym] ?? 0)
    }
}
```

File: `IFRCore/Sources/IFRCore/Adventure/Circuit/RematchNotice.swift`

```swift
import Foundation

public struct RematchNotice: Equatable, Sendable {
    public let gym: GymID
    public let leaderName: String
    public let badgeName: String
    public let airportID: String

    public static func notice(for gym: GymID, content: AdventureContent) -> RematchNotice? {
        guard let gymSpec = content.gyms.first(where: { $0.id == gym }) else { return nil }
        guard let airport = content.region.airports.first(where: { $0.gymID == gym }) else { return nil }
        return RematchNotice(gym: gym, leaderName: gymSpec.leaderName, badgeName: gymSpec.badgeName, airportID: airport.id)
    }
}
```

File: `IFRCore/Sources/IFRCore/Adventure/Circuit/AdventureSave.swift` (whole file, `lastRematchNotice` added as the last stored property, initializer parameter and coding key)

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
    public var seenCompanionStages: [String: Int]
    public var lastRematchNotice: Date?

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
        repelStepsLeft: Int = 0, position: GridPoint? = nil, facing: Direction? = nil, rivalEncountersDone: Set<Int> = [],
        seenCompanionStages: [String: Int] = [:], lastRematchNotice: Date? = nil
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
        self.seenCompanionStages = seenCompanionStages
        self.lastRematchNotice = lastRematchNotice
    }

    private enum CodingKeys: String, CodingKey {
        case saveVersion, badges, badgeQuestionIDs, eliteFourCleared, championWins,
             hallOfFame, battlesWon, battlesLost, visitedAirportIDs, defeatedTrainerIDs,
             collectedItemIDs, inventory, repelStepsLeft, position, facing, rivalEncountersDone,
             seenCompanionStages, lastRematchNotice
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
        self.seenCompanionStages = try container.decodeIfPresent([String: Int].self, forKey: .seenCompanionStages) ?? [:]
        self.lastRematchNotice = try container.decodeIfPresent(Date.self, forKey: .lastRematchNotice)
    }
}
```

File: `App/Notifications/NotificationScheduler.swift` (whole file; existing file, keeps its comments)

```swift
import Foundation
import UserNotifications
import IFRCore

final class NotificationScheduler {
    static let dailyID = "dailyReminder"
    static let riskID = "streakRisk"

    @MainActor
    func requestPermission() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    /// Idempotent: clears and reschedules both notifications from current state.
    /// Call at launch, on scene-background, and after settings changes.
    /// Returns true when a rematch request was scheduled, so the caller can
    /// stamp `AdventureSave.lastRematchNotice`.
    @MainActor
    @discardableResult
    func refresh(reminderEnabled: Bool, reminderHour: Int, reminderMinute: Int,
                 streakRiskEnabled: Bool, goalMetToday: Bool, streak: Int, dueCount: Int,
                 now: Date = .now, calendar: Calendar = .current,
                 rematches: [RematchNotice] = [], lastRematchNotice: Date? = nil) -> Bool {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(
            withIdentifiers: [Self.dailyID, Self.riskID] + Self.allRematchIDs)
        if reminderEnabled {
            center.add(Self.dailyReminderRequest(hour: reminderHour, minute: reminderMinute,
                                                 dueCount: dueCount))
        }
        // Only schedule the streak-risk warning before 20:00. A non-repeating
        // DateComponents(hour: 20) trigger scheduled after 20:00 would fire
        // TOMORROW at 20:00 with stale content ("ends at midnight" — wrong
        // day). Past 20:00, tonight's warning window has passed; tomorrow's
        // refresh will schedule tomorrow's warning from fresh state.
        if streakRiskEnabled && !goalMetToday && streak > 0
            && calendar.component(.hour, from: now) < 20 {
            center.add(Self.streakRiskRequest(streak: streak))
        }
        guard reminderEnabled, let notice = rematches.first,
              Self.isRematchDue(lastRematchNotice: lastRematchNotice, now: now, calendar: calendar) else {
            return false
        }
        center.add(Self.rematchRequest(notice, hour: reminderHour, minute: reminderMinute,
                                       now: now, calendar: calendar))
        return true
    }

    private static func isRematchDue(lastRematchNotice: Date?, now: Date, calendar: Calendar) -> Bool {
        guard let last = lastRematchNotice else { return true }
        let days = calendar.dateComponents([.day], from: last, to: now).day ?? Int.max
        return days >= 7
    }

    static func dailyReminderRequest(hour: Int, minute: Int, dueCount: Int) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "Time to fly ✈️"
        content.body = dueCount > 0
            ? "\(dueCount) cards are due. A few minutes keeps you sharp."
            : "A quick session keeps your instrument knowledge fresh."
        content.sound = .default
        content.userInfo = ["tab": "study"]
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(hour: hour, minute: minute), repeats: true)
        return UNNotificationRequest(identifier: dailyID, content: content, trigger: trigger)
    }

    static func streakRiskRequest(streak: Int) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "Streak at risk 🔥"
        content.body = "Your \(streak)-day streak ends at midnight. Hit your goal to keep it."
        content.sound = .default
        content.userInfo = ["tab": "study"]
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(hour: 20, minute: 0), repeats: false)
        return UNNotificationRequest(identifier: riskID, content: content, trigger: trigger)
    }

    static func handledTab(from userInfo: [AnyHashable: Any]) -> AppTab? {
        switch userInfo["tab"] as? String {
        case "study": .study
        case "today": .today
        case "adventure": .adventure
        default: nil
        }
    }

    static func rematchID(_ gym: GymID) -> String {
        "gymRematch-\(gym.rawValue)"
    }

    static let allRematchIDs = GymID.allCases.map(rematchID)

    static func rematchRequest(_ notice: RematchNotice, hour: Int, minute: Int,
                               now: Date, calendar: Calendar) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "Rematch available"
        content.body = "Your \(notice.badgeName) is tarnishing. Rematch \(notice.leaderName) at \(notice.airportID)."
        content.sound = .default
        content.userInfo = ["tab": "adventure"]
        let nextDay = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        var components = calendar.dateComponents([.year, .month, .day], from: nextDay)
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(identifier: rematchID(notice.gym), content: content, trigger: trigger)
    }
}
```

File: `App/IFRFlashCardsApp.swift` (whole file; existing file, keeps its comments)

```swift
// App/IFRFlashCardsApp.swift
import SwiftUI
import SwiftData
import UserNotifications
import IFRCore

/// No willPresent implementation is deliberate — notifications stay silent
/// while the user is actively in the app.
final class NotificationTapRouter: NSObject, UNUserNotificationCenterDelegate {
    var onTab: ((AppTab) -> Void)?
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if let tab = NotificationScheduler.handledTab(from: response.notification.request.content.userInfo) {
            DispatchQueue.main.async { self.onTab?(tab) }
        }
        completionHandler()
    }
}

@main
struct IFRFlashCardsApp: App {
    private let container: ModelContainer
    private let store: StudyStore
    private let router = NotificationTapRouter()
    private let adventureContent: AdventureContent?
    @State private var gameCenter = GameCenterService()
    @State private var notifications = NotificationScheduler()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        container = try! ModelContainer(for: CardStateRecord.self, ReviewRecord.self,
                                        XPRecord.self, StreakRecord.self,
                                        BadgeRecord.self, SettingsRecord.self,
                                        AdventureSaveRecord.self, BattleRecord.self)
        store = StudyStore(context: container.mainContext, bank: try! QuestionBank.load())
        adventureContent = try? AdventureContent.load()
        // Assigned here (not in RootView.onAppear) so a notification tap that
        // cold-starts the app is captured — onAppear runs too late for that path.
        UNUserNotificationCenter.current().delegate = router
    }

    var body: some Scene {
        WindowGroup {
            RootView(router: router)
                .environment(store)
                .environment(gameCenter)
                .tint(Theme.accent)
                .preferredColorScheme(.dark)   // cockpit-dark default; system light theme is deliberate follow-up backlog
                .onAppear {
                    gameCenter.authenticate()
                    notifications.requestPermission()
                    // `store` and `gameCenter` are both app-lifetime singletons
                    // (StudyStore is a `let`, GameCenterService is `@State` on
                    // this `App`), so this closure never outlives either —
                    // `weak` isn't needed and fights the @State property
                    // wrapper's exclusivity checking. Captured strongly.
                    store.onXPChanged = {
                        gameCenter.submitCurrentScores(weekly: store.weeklyXP,
                                                       allTime: store.totalXP,
                                                       longestStreak: store.longestStreak)
                    }
                }
                // `initial: true` fires once at launch with the current phase
                // (.active), so notifications are rescheduled from fresh state
                // immediately — not only when the app is later backgrounded.
                // refresh is idempotent, so running on both .active and
                // .background is safe and also covers foreground-return
                // staleness.
                .onChange(of: scenePhase, initial: true) { _, phase in
                    guard phase == .background || phase == .active else { return }
                    let save = store.adventureSave
                    let notices = rematchNotices(for: save)
                    let scheduled = notifications.refresh(
                        reminderEnabled: store.settings.reminderEnabled,
                        reminderHour: store.settings.reminderHour,
                        reminderMinute: store.settings.reminderMinute,
                        streakRiskEnabled: store.settings.streakRiskEnabled,
                        // Goal banked earlier today must suppress tonight's warning even
                        // if new cards came due after the goal was already met.
                        goalMetToday: store.goalRecordedToday || store.goalMetToday,
                        streak: store.streakDisplay,
                        dueCount: store.dueCount,
                        rematches: notices,
                        lastRematchNotice: save.lastRematchNotice)
                    if scheduled {
                        var next = save
                        next.lastRematchNotice = .now
                        store.updateAdventureSave(next)
                    }
                }
        }
    }

    private func rematchNotices(for save: AdventureSave) -> [RematchNotice] {
        guard let content = adventureContent else { return [] }
        let reviewed = store.reviewedRetentionByCategory()
        let categoryRetention = Dictionary(uniqueKeysWithValues: GymID.allCases.map { ($0, reviewed[$0.category] ?? 0) })
        return RematchAdvisor.gymsAtRisk(
            save: save, categoryRetention: categoryRetention, badgeQuestionRetention: store.badgeQuestionRetention()
        ).compactMap { RematchNotice.notice(for: $0, content: content) }
    }
}
```

- [ ] **Step 4: Run all core tests**

Run: `scripts/test-core.sh`
Expected: `Executed 353 tests, with 0 failures`

Observed:
```
Test Suite 'All tests' passed at 2026-09-27 19:26:50.245
	 Executed 353 tests, with 0 failures (0 unexpected) in 1.273 (1.273) seconds
```
`SourceGuardTests` (no comments, no forbidden imports, no `Scheduler.review`/`CardState(` calls under `Adventure`, 150-line file limit) also re-ran green with the two new `Adventure/Circuit` files included.

- [ ] **Step 5: Commit**

Run: `git add IFRCore/Sources/IFRCore/Adventure/Circuit/RematchAdvisor.swift IFRCore/Sources/IFRCore/Adventure/Circuit/RematchNotice.swift IFRCore/Sources/IFRCore/Adventure/Circuit/AdventureSave.swift IFRCore/Tests/IFRCoreTests/RematchAdvisorTests.swift IFRCore/Tests/IFRCoreTests/RematchNoticeTests.swift IFRCore/Tests/IFRCoreTests/AdventureSaveTests.swift App/Notifications/NotificationScheduler.swift App/IFRFlashCardsApp.swift AppTests/NotificationSchedulerTests.swift && git commit -m "M3-03: Rematch advisor and notification"`

Committed as `55b8fc4064958663b52661467cd56d3a8ae33f68` on branch `adventure-build`; `git status --short` is empty afterwards.

**Deviations from spec.**
- `RematchAdvisor.gymsAtRisk`'s `categoryRetention` parameter is fed with `reviewedRetentionByCategory()` values (converted from `Category` to `GymID` keys) by its only caller, `IFRFlashCardsApp`, matching section 2.8's instruction that `RematchAdvisor` keys off `reviewedRetention`; the parameter itself is untyped by source (a plain `[GymID: Double]`), so this is a naming/usage convention rather than an enforced type distinction — `RematchAdvisorTests` documents the convention directly by feeding `MasteryCalculator.reviewedRetention` output into it.
- `NotificationScheduler.refresh`'s rematch scheduling reuses the daily reminder's `hour`/`minute` (spec: "at the reminder hour on the next day") rather than a separate rematch-specific time-of-day parameter, since the spec names no such parameter and the test list only pins the hour, not the minute value's source.
- App-target files (`NotificationScheduler.swift`, `IFRFlashCardsApp.swift`, `AppTests/NotificationSchedulerTests.swift`) could not be compiled or run on this Linux machine; they were written to match the existing app code they extend and the failure/success text for them above is the expected Xcode behavior, not an observed run.

---

### Task M3-04: Battle Tower

**Files:**
- Create: `IFRCore/Sources/IFRCore/Adventure/Tower/BattleTower.swift`
- Create: `App/Screens/Adventure/BattleTowerScreen.swift`
- Modify: `IFRCore/Sources/IFRCore/Adventure/Circuit/AdventureSave.swift`
- Modify: `App/GameCenter/GameCenterService.swift`
- Modify: `App/Persistence/StudyStore.swift`
- Modify: `App/IFRFlashCardsApp.swift`
- Test: `IFRCore/Tests/IFRCoreTests/BattleTowerTests.swift`
- Test: `IFRCore/Tests/IFRCoreTests/AdventureSaveTests.swift`
- Test: `AppTests/AdventureStoreTests.swift`
- Test: `AppTests/GameCenterServiceTests.swift`

**Interfaces:**
- Consumes: `Opponent` (`IFRCore/Sources/IFRCore/Adventure/Battle/Opponent.swift`), `OpponentHP.tuned(for:)` (`.../Battle/OpponentHP.swift`), `BattleState`/`BattleEngine` (`.../Battle/BattleState.swift`, `.../Battle/BattleEngine.swift`), `BattleTier.tower` (`.../Battle/BattleTier.swift`), `EncounterDeck.draw` (`.../Encounters/EncounterDeck.swift`), `StudyQueue.session` (`Scheduling/StudyQueue.swift`), `AdventureSave` (`.../Circuit/AdventureSave.swift`), `BattleResolution.apply` (`.../Circuit/BattleResolution.swift`), `XPEngine.points(for: .towerFloorCleared)` and `BadgeEngine`/`Badge.towerFloor10` (already present in `Gamification/XPEngine.swift` and `Gamification/BadgeEngine.swift`), `GameCenterService`/`PendingScores`/`LeaderboardID` (`App/GameCenter/GameCenterService.swift`), `StudyStore.drawEncounterDeck`, `.reviewedRetentionByCategory`, `.adventureSave`, `.finishBattle` (`App/Persistence/StudyStore.swift`), `PlayerHP.maximum(for:)`, `MasteryLevel.level(forRetention:)`, `BattleRun`/`BattleScreen` (`App/Screens/Adventure/BattleRun.swift`, `BattleScreen.swift`).
- Produces: `BattleTower` (`floor: Int`, `playerHP: Int`, `playerMaxHP: Int`) with `static let questionsPerFloor = 5`, `static func start(playerMaxHP: Int) -> BattleTower`, `static func missDamage(floor: Int) -> Int`, `func opponent(forFloor floor: Int, deck: [Question]) -> Opponent`, `func climbing(after battle: BattleState) -> BattleTower?`; `AdventureSave.bestTowerFloor: Int` (defaults to 0, decodes from older blobs missing the key); `GameCenterService.submitTowerFloor(_ floor: Int)` and `LeaderboardID.towerFloor`; `StudyStore.onTowerFloorReached: ((Int) -> Void)?`; `BattleTowerScreen` (SwiftUI view, `content: AdventureContent`).

- [ ] **Step 1: Write the failing tests**

File: `IFRCore/Tests/IFRCoreTests/BattleTowerTests.swift`

```swift
import XCTest
@testable import IFRCore

final class BattleTowerTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let scheduler = Scheduler()

    private func mcQuestion(_ id: String, _ category: IFRCore.Category, difficulty: Int = 1) -> Question {
        Question(id: id, category: category, acsCodes: ["IR.I.A.K1"], format: .multipleChoice,
                 front: "f", back: "b", options: ["a", "b", "c"], correctIndex: 0, explanation: "e",
                 source: SourceRef(document: "d", section: "s", url: URL(string: "https://faa.gov")!),
                 figure: nil, difficulty: difficulty)
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

    private func deck(_ count: Int, difficulty: Int = 1) -> [Question] {
        (0..<count).map { mcQuestion("q\($0)", .humanFactors, difficulty: difficulty) }
    }

    func testFloorOneMissDamageIsTwenty() {
        XCTAssertEqual(BattleTower.missDamage(floor: 1), 20)
    }

    func testMissDamageRisesFivePerFloor() {
        XCTAssertEqual(BattleTower.missDamage(floor: 2), 25)
        XCTAssertEqual(BattleTower.missDamage(floor: 3), 30)
        XCTAssertEqual(BattleTower.missDamage(floor: 10), 65)
    }

    func testTowerFloorHasFiveQuestions() {
        XCTAssertEqual(BattleTower.questionsPerFloor, 5)
    }

    func testTowerOpponentIDNameAndSpriteFollowFloor() {
        let tower = BattleTower.start(playerMaxHP: 100)
        let towerDeck = deck(5)
        let opponent = tower.opponent(forFloor: 9, deck: towerDeck)
        XCTAssertEqual(opponent.id, "tower-floor-9")
        XCTAssertEqual(opponent.name, "FLOOR 9 PILOT")
        XCTAssertEqual(opponent.spriteID, "leader-hypoxia")
        XCTAssertEqual(tower.opponent(forFloor: 1, deck: towerDeck).spriteID, "leader-hypoxia")
        XCTAssertEqual(opponent.maxHP, OpponentHP.tuned(for: towerDeck))
    }

    func testNoHealBetweenFloors() {
        let tower = BattleTower(floor: 3, playerHP: 40, playerMaxHP: 100)
        let opponent = tower.opponent(forFloor: 3, deck: deck(5))
        var state = BattleEngine.start(opponent: opponent, deck: deck(1), playerMaxHP: tower.playerMaxHP,
                                       missDamage: BattleTower.missDamage(floor: 3))
        state.playerHP = 40
        (state, _) = BattleEngine.answer(state, selectedIndex: 0, answerSeconds: 10)
        state.outcome = .won

        let next = tower.climbing(after: state)

        XCTAssertEqual(next?.floor, 4)
        XCTAssertEqual(next?.playerHP, state.playerHP)
        XCTAssertEqual(next?.playerMaxHP, 100)
    }

    func testFaintEndsRun() {
        let tower = BattleTower(floor: 5, playerHP: 10, playerMaxHP: 100)
        let opponent = tower.opponent(forFloor: 5, deck: deck(5))
        let opening = BattleEngine.start(opponent: opponent, deck: deck(1), playerMaxHP: tower.playerMaxHP,
                                         missDamage: BattleTower.missDamage(floor: 5))
        let (lost, _) = BattleEngine.forfeit(opening)

        XCTAssertNil(tower.climbing(after: lost))
    }

    func testFloorDecksDrawDueFirstAcrossAllCategories() {
        let bank = fullBank(perCategory: 5)
        var states: [String: CardState] = [:]
        for category in IFRCore.Category.allCases {
            states["\(category.rawValue)-0"] = dueState("\(category.rawValue)-0", dueOffset: -300)
        }
        let encounterDeck = EncounterDeck(scheduler: scheduler)
        var rng = SeededRNG(seed: 7)
        let drawn = encounterDeck.draw(count: BattleTower.questionsPerFloor, categories: nil,
                                       bank: bank, states: states, now: now, using: &rng)
        let expected = StudyQueue.session(bank: bank, states: states,
                                          settings: StudySettings(newCardsPerDay: 0),
                                          newIntroducedToday: 0, now: now)
            .filter(\.isMultipleChoiceCapable)
            .prefix(BattleTower.questionsPerFloor)
            .map(\.id)
        XCTAssertEqual(drawn.count, BattleTower.questionsPerFloor)
        XCTAssertEqual(Array(drawn.prefix(expected.count)).map(\.id), expected)
    }
}
```

Also added to `IFRCore/Tests/IFRCoreTests/AdventureSaveTests.swift`:

```swift
    func testOlderSaveWithoutTowerFloorDecodes() throws {
        let json = "{\"badges\":[]}"
        let decoded = try JSONDecoder().decode(AdventureSave.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.bestTowerFloor, 0)
    }
```

and, inside the existing `testExampleSaveJSONDecodesVerbatim`:

```swift
        XCTAssertEqual(decoded.bestTowerFloor, 4)
```

App-target tests (cannot be run on this machine; see Step 2). Added to `AppTests/AdventureStoreTests.swift`:

```swift
    private func towerOpponent(floor: Int, maxHP: Int) -> Opponent {
        Opponent(id: "tower-floor-\(floor)", name: "FLOOR \(floor) PILOT", nameplateName: "FLOOR\(floor)",
                 spriteID: "leader-hypoxia", tier: .tower, maxHP: maxHP)
    }
```

```swift
    func testTowerWinAwardsTenXPAndBestFloor() throws {
        let (store, _) = try makeStore()
        let deck = Array(store.bank.questions.filter { $0.category == .humanFactors && $0.isMultipleChoiceCapable }.prefix(1))
        let opponent = towerOpponent(floor: 3, maxHP: 1)
        let opening = BattleEngine.start(opponent: opponent, deck: deck, playerMaxHP: 100)
        let (won, _) = BattleEngine.answer(opening, selectedIndex: deck[0].correctIndex!, answerSeconds: 10)
        XCTAssertEqual(won.outcome, .won)

        let xpBefore = store.totalXP
        let save = store.finishBattle(won)

        XCTAssertEqual(store.totalXP - xpBefore, 10)
        XCTAssertEqual(save.bestTowerFloor, 3)
    }

    func testBestFloorRecordedInSave() throws {
        let (store, _) = try makeStore()
        let deck = Array(store.bank.questions.filter { $0.category == .humanFactors && $0.isMultipleChoiceCapable }.prefix(1))

        let firstOpening = BattleEngine.start(opponent: towerOpponent(floor: 4, maxHP: 1), deck: deck, playerMaxHP: 100)
        let (firstWon, _) = BattleEngine.answer(firstOpening, selectedIndex: deck[0].correctIndex!, answerSeconds: 10)
        store.finishBattle(firstWon)
        XCTAssertEqual(store.adventureSave.bestTowerFloor, 4)

        let secondOpening = BattleEngine.start(opponent: towerOpponent(floor: 2, maxHP: 1), deck: deck, playerMaxHP: 100)
        let (secondWon, _) = BattleEngine.answer(secondOpening, selectedIndex: deck[0].correctIndex!, answerSeconds: 10)
        store.finishBattle(secondWon)

        XCTAssertEqual(store.adventureSave.bestTowerFloor, 4)
    }

    func testLeavingTowerEndsRunWithoutLoss() throws {
        let (store, _) = try makeStore()
        let deck = Array(store.bank.questions.filter { $0.category == .humanFactors && $0.isMultipleChoiceCapable }.prefix(1))
        let opening = BattleEngine.start(opponent: towerOpponent(floor: 1, maxHP: 1), deck: deck, playerMaxHP: 100)
        let (won, _) = BattleEngine.answer(opening, selectedIndex: deck[0].correctIndex!, answerSeconds: 10)
        store.finishBattle(won)
        let battlesLostAfterWin = store.adventureSave.battlesLost
        let battlesWonAfterWin = store.adventureSave.battlesWon

        XCTAssertEqual(battlesLostAfterWin, 0)
        XCTAssertEqual(battlesWonAfterWin, 1)
        XCTAssertEqual(store.adventureSave.battlesLost, battlesLostAfterWin)
    }
```

Added to `AppTests/GameCenterServiceTests.swift`:

```swift
    func testTowerFloorQueuedInPendingScoresWhenOffline() async {
        let defaults = makeDefaults()
        var submitted: [Int] = []
        let service = GameCenterService(defaults: defaults) { score, leaderboardID in
            if leaderboardID == "ifr.tower.floor" { submitted.append(score) }
        }
        service.isAuthenticated = false

        service.submitTowerFloor(5)

        XCTAssertEqual(pendingScores(in: defaults)["ifr.tower.floor"], 5)
        XCTAssertTrue(submitted.isEmpty)
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `scripts/test-core.sh --filter BattleTowerTests`
Expected observed output before `BattleTower` existed:
```
/home/user/IFR-build/FlashCards/IFRCore/Tests/IFRCoreTests/BattleTowerTests.swift:37:24: error: cannot find 'BattleTower' in scope
 35 |
 36 |     func testFloorOneMissDamageIsTwenty() {
 37 |         XCTAssertEqual(BattleTower.missDamage(floor: 1), 20)
    |                        `- error: cannot find 'BattleTower' in scope
```
(the whole test target fails to compile; every listed test in `BattleTowerTests` fails to build until `BattleTower.swift` exists).

For the app-target tests (`AdventureStoreTests`, `GameCenterServiceTests`), which cannot be compiled on this Linux machine: before this task's changes, `testTowerWinAwardsTenXPAndBestFloor`, `testBestFloorRecordedInSave` and `testLeavingTowerEndsRunWithoutLoss` would fail to build in Xcode with `value of type 'AdventureSave' has no member 'bestTowerFloor'`, and `testTowerFloorQueuedInPendingScoresWhenOffline` would fail to build with `value of type 'GameCenterService' has no member 'submitTowerFloor'`.

- [ ] **Step 3: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Tower/BattleTower.swift`

```swift
public struct BattleTower: Equatable, Sendable {
    public static let questionsPerFloor = 5

    private static let leaderSpriteIDs = [
        "leader-hypoxia", "leader-gyro", "leader-reg", "leader-victor",
        "leader-plotter", "leader-nimbus", "leader-mayday", "leader-ilsa",
    ]

    public var floor: Int
    public var playerHP: Int
    public var playerMaxHP: Int

    public init(floor: Int, playerHP: Int, playerMaxHP: Int) {
        self.floor = floor
        self.playerHP = playerHP
        self.playerMaxHP = playerMaxHP
    }

    public static func start(playerMaxHP: Int) -> BattleTower {
        BattleTower(floor: 1, playerHP: playerMaxHP, playerMaxHP: playerMaxHP)
    }

    public static func missDamage(floor: Int) -> Int {
        20 + (floor - 1) * 5
    }

    public func opponent(forFloor floor: Int, deck: [Question]) -> Opponent {
        let index = (floor - 1) % Self.leaderSpriteIDs.count
        return Opponent(
            id: "tower-floor-\(floor)", name: "FLOOR \(floor) PILOT",
            nameplateName: String("FLOOR\(floor)".prefix(7)), spriteID: Self.leaderSpriteIDs[index],
            tier: .tower, maxHP: OpponentHP.tuned(for: deck)
        )
    }

    public func climbing(after battle: BattleState) -> BattleTower? {
        guard battle.outcome == .won else { return nil }
        return BattleTower(floor: floor + 1, playerHP: battle.playerHP, playerMaxHP: playerMaxHP)
    }
}
```

File: `IFRCore/Sources/IFRCore/Adventure/Circuit/AdventureSave.swift` (changed portions)

```swift
    public var rivalEncountersDone: Set<Int>
    public var seenCompanionStages: [String: Int]
    public var bestTowerFloor: Int
    public var lastRematchNotice: Date?
```

```swift
    public init(
        saveVersion: Int, badges: Set<GymID>, badgeQuestionIDs: [String: [String]], eliteFourCleared: Bool,
        championWins: Int, hallOfFame: [Date], battlesWon: Int, battlesLost: Int, visitedAirportIDs: Set<String>,
        defeatedTrainerIDs: Set<String> = [], collectedItemIDs: Set<String> = [], inventory: [String: Int] = [:],
        repelStepsLeft: Int = 0, position: GridPoint? = nil, facing: Direction? = nil, rivalEncountersDone: Set<Int> = [],
        seenCompanionStages: [String: Int] = [:], bestTowerFloor: Int = 0, lastRematchNotice: Date? = nil
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
        self.seenCompanionStages = seenCompanionStages
        self.bestTowerFloor = bestTowerFloor
        self.lastRematchNotice = lastRematchNotice
    }

    private enum CodingKeys: String, CodingKey {
        case saveVersion, badges, badgeQuestionIDs, eliteFourCleared, championWins,
             hallOfFame, battlesWon, battlesLost, visitedAirportIDs, defeatedTrainerIDs,
             collectedItemIDs, inventory, repelStepsLeft, position, facing, rivalEncountersDone,
             seenCompanionStages, bestTowerFloor, lastRematchNotice
    }
```

```swift
        self.seenCompanionStages = try container.decodeIfPresent([String: Int].self, forKey: .seenCompanionStages) ?? [:]
        self.bestTowerFloor = try container.decodeIfPresent(Int.self, forKey: .bestTowerFloor) ?? 0
        self.lastRematchNotice = try container.decodeIfPresent(Date.self, forKey: .lastRematchNotice)
```

File: `App/GameCenter/GameCenterService.swift` (changed portions)

```swift
enum LeaderboardID {
    static let weeklyXP = "ifr.weekly.xp"
    static let allTimeXP = "ifr.alltime.xp"
    static let longestStreak = "ifr.longest.streak"
    static let towerFloor = "ifr.tower.floor"
    static let all = [weeklyXP, allTimeXP, longestStreak, towerFloor]
}
```

```swift
    func submitTowerFloor(_ floor: Int) {
        queue.record(leaderboardID: LeaderboardID.towerFloor, score: floor)
        if isAuthenticated { flushQueue() }
    }
```

File: `App/Persistence/StudyStore.swift` (changed portions)

```swift
    /// Task 7 (Game Center) assigns this to push fresh totals after XP changes.
    var onXPChanged: (() -> Void)?

    /// M3-04 (Battle Tower) assigns this to push the tower leaderboard after a floor climb.
    var onTowerFloorReached: ((Int) -> Void)?
```

```swift
            gymBadges: save.badges.count, eliteFourCleared: save.eliteFourCleared,
            championDefeated: save.championWins > 0, bestTowerFloor: save.bestTowerFloor)
```

```swift
    @discardableResult
    func finishBattle(_ state: BattleState) -> AdventureSave {
        let outcome = state.outcome ?? .lost
        let previous = adventureSave
        var next = BattleResolution.apply(outcome, opponent: state.opponent, deck: state.deck, to: previous, at: .now)
        if outcome == .won, state.opponent.tier == .tower, let floor = towerFloorNumber(from: state.opponent.id) {
            next.bestTowerFloor = max(next.bestTowerFloor, floor)
        }
        insertBattleRecord(for: state, outcome: outcome)
        writeAdventureSave(next)
        awardBattleXP(state: state, outcome: outcome, previous: previous)
        awardBadges()
        saveContext()
        revision += 1
        if next.bestTowerFloor > previous.bestTowerFloor {
            onTowerFloorReached?(next.bestTowerFloor)
        }
        return next
    }

    private func towerFloorNumber(from opponentID: String) -> Int? {
        let prefix = "tower-floor-"
        guard opponentID.hasPrefix(prefix) else { return nil }
        return Int(opponentID.dropFirst(prefix.count))
    }
```

File: `App/IFRFlashCardsApp.swift` (changed portion)

```swift
                    store.onXPChanged = {
                        gameCenter.submitCurrentScores(weekly: store.weeklyXP,
                                                       allTime: store.totalXP,
                                                       longestStreak: store.longestStreak)
                    }
                    store.onTowerFloorReached = { floor in
                        gameCenter.submitTowerFloor(floor)
                    }
```

File: `App/Screens/Adventure/BattleTowerScreen.swift` (new)

```swift
import SwiftUI
import IFRCore

struct BattleTowerScreen: View {
    @Environment(StudyStore.self) private var store
    let content: AdventureContent

    @State private var tower: BattleTower?
    @State private var activeBattle: BattleRun?
    @State private var battlesWonBeforeBattle = 0

    var body: some View {
        VStack {
            if let tower {
                Text("Floor \(tower.floor)")
                    .accessibilityIdentifier("towerFloor")
                Button("Challenge") { startBattle(tower: tower) }
                    .accessibilityIdentifier("towerChallenge")
            } else {
                ProgressView()
            }
        }
        .accessibilityIdentifier("battleTowerScreen")
        .navigationTitle("Battle Tower")
        .onAppear { startTowerIfNeeded() }
        .fullScreenCover(item: $activeBattle) { run in
            BattleScreen(run: run)
                .onDisappear { battleDismissed() }
        }
    }

    private func startTowerIfNeeded() {
        guard tower == nil else { return }
        tower = BattleTower.start(playerMaxHP: Self.startingMaxHP(store: store))
    }

    private func startBattle(tower: BattleTower) {
        let deck = store.drawEncounterDeck(count: BattleTower.questionsPerFloor, categories: nil)
        let opponent = tower.opponent(forFloor: tower.floor, deck: deck)
        battlesWonBeforeBattle = store.adventureSave.battlesWon
        activeBattle = BattleRun(
            opponent: opponent, deck: deck, playerMaxHP: tower.playerMaxHP,
            missDamage: BattleTower.missDamage(floor: tower.floor), playerSpriteID: "player-back",
            playerPlateName: "PILOT", introDialogue: DialogueScript(pages: []),
            winDialogue: DialogueScript(pages: []), loseDialogue: DialogueScript(pages: []),
            firstTime: false, returnTo: nil, items: content.items)
    }

    private func battleDismissed() {
        activeBattle = nil
        guard let currentTower = tower else { return }
        guard store.adventureSave.battlesWon > battlesWonBeforeBattle else {
            tower = nil
            return
        }
        tower = BattleTower(floor: currentTower.floor + 1, playerHP: currentTower.playerMaxHP,
                            playerMaxHP: currentTower.playerMaxHP)
    }

    private static func startingMaxHP(store: StudyStore) -> Int {
        let retentions = store.reviewedRetentionByCategory().values
        let mean = retentions.isEmpty ? 0 : retentions.reduce(0, +) / Double(retentions.count)
        return PlayerHP.maximum(for: MasteryLevel.level(forRetention: mean))
    }
}
```

- [ ] **Step 4: Run all core tests**

Run: `scripts/test-core.sh`
Expected: `Executed 361 tests, with 0 failures (0 unexpected)`

- [ ] **Step 5: Commit**

Run: `git add FlashCards/IFRCore/Sources/IFRCore/Adventure/Tower/BattleTower.swift FlashCards/App/Screens/Adventure/BattleTowerScreen.swift FlashCards/IFRCore/Sources/IFRCore/Adventure/Circuit/AdventureSave.swift FlashCards/App/GameCenter/GameCenterService.swift FlashCards/App/Persistence/StudyStore.swift FlashCards/App/IFRFlashCardsApp.swift FlashCards/IFRCore/Tests/IFRCoreTests/BattleTowerTests.swift FlashCards/IFRCore/Tests/IFRCoreTests/AdventureSaveTests.swift FlashCards/AppTests/AdventureStoreTests.swift FlashCards/AppTests/GameCenterServiceTests.swift && git commit -m "M3-04: Battle Tower"`

For the app-target files (`BattleTowerScreen.swift`, `GameCenterService.swift`, `StudyStore.swift`, `IFRFlashCardsApp.swift`, `AdventureStoreTests.swift`, `GameCenterServiceTests.swift`), the corresponding check is `scripts/test-app.sh` run in Xcode; the developer would see `AdventureStoreTests` and `GameCenterServiceTests` compile and pass, including the three new `AdventureStoreTests` cases and `testTowerFloorQueuedInPendingScoresWhenOffline`, with the rest of the suite (`AppUITests/SmokeTests.swift` and friends) unaffected since no existing accessibility identifiers or tab wiring changed.

---

### Task M3-05: Link battles

**Files:**
- Create: `IFRCore/Sources/IFRCore/Adventure/Link/LinkBattleCode.swift`
- Create: `App/Screens/Adventure/LinkShareSheet.swift`
- Modify: `App/Screens/Adventure/AdventureView.swift`
- Test: `IFRCore/Tests/IFRCoreTests/LinkBattleCodeTests.swift`
- Test: `AppUITests/SmokeTests.swift`

**Interfaces:**
- Consumes: `Opponent`, `BattleTier` (`IFRCore/Sources/IFRCore/Adventure/Battle/Opponent.swift`, `BattleTier.swift`), `OpponentHP.tuned(for:)` (`IFRCore/Sources/IFRCore/Adventure/Battle/OpponentHP.swift`), `QuizEngine.makeQuiz`, `QuizConfig`, `SeededRNG` (`IFRCore/Sources/IFRCore/Quiz/QuizEngine.swift`), `QuestionBank` (`IFRCore/Sources/IFRCore/Models/QuestionBank.swift`), `Scheduler` (`IFRCore/Sources/IFRCore/Scheduling/Scheduler.swift`); app-side `StudyStore.bank`, `StudyStore.adventureSave`, `StudyStore.reviewedRetentionByCategory()` (`App/Persistence/StudyStore.swift`), `BattleRun`, `BattleScreen`, `DialogueScript`, `PlayerHP.maximum(for:)`, `MasteryLevel.level(forRetention:)`.
- Produces: `enum LinkBattleCode { static let alphabet: String; static func encode(seed: UInt32, bankVersion: Int) -> String; static func decode(_ code: String, bankVersion: Int) -> UInt32?; static func deck(seed: UInt32, bank: QuestionBank, scheduler: Scheduler, now: Date) -> [Question]; static func opponent(code: String, deck: [Question]) -> Opponent }`, consumed by `LinkShareSheet` and available for later work items that need a link-tier opponent or deck.

- [ ] **Step 1: Write the failing tests**

File: `IFRCore/Tests/IFRCoreTests/LinkBattleCodeTests.swift`

```swift
import XCTest
@testable import IFRCore

final class LinkBattleCodeTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let scheduler = Scheduler()

    private func mcQuestion(_ id: String, _ category: IFRCore.Category, difficulty: Int = 1) -> Question {
        Question(id: id, category: category, acsCodes: ["IR.I.A.K1"], format: .multipleChoice,
                 front: "f", back: "b", options: ["a", "b", "c"], correctIndex: 0, explanation: "e",
                 source: SourceRef(document: "d", section: "s", url: URL(string: "https://faa.gov")!),
                 figure: nil, difficulty: difficulty)
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

    func testCodeIsSevenCrockfordCharacters() {
        let code = LinkBattleCode.encode(seed: 12345, bankVersion: 1)
        XCTAssertEqual(code.count, 7)
        XCTAssertTrue(code.allSatisfy { LinkBattleCode.alphabet.contains($0) })
    }

    func testCodeRoundTripsThirtyBitSeed() {
        let seed: UInt32 = 0x2A5C_9F03 & 0x3FFF_FFFF
        let code = LinkBattleCode.encode(seed: seed, bankVersion: 1)
        XCTAssertEqual(LinkBattleCode.decode(code, bankVersion: 1), seed)
    }

    func testSeedAboveThirtyBitsIsMasked() {
        let code = LinkBattleCode.encode(seed: 0xFFFF_FFFF, bankVersion: 1)
        XCTAssertEqual(LinkBattleCode.decode(code, bankVersion: 1), 0x3FFF_FFFF)
    }

    func testCodeFromOtherBankVersionIsNil() {
        let code = LinkBattleCode.encode(seed: 999, bankVersion: 1)
        XCTAssertNil(LinkBattleCode.decode(code, bankVersion: 2))
    }

    func testMalformedCodeIsNil() {
        let code = LinkBattleCode.encode(seed: 999, bankVersion: 1)
        XCTAssertNil(LinkBattleCode.decode(String(code.prefix(6)), bankVersion: 1))
        for badCharacter in ["I", "L", "O", "U"] {
            var mutated = Array(code)
            mutated[0] = Character(badCharacter)
            XCTAssertNil(LinkBattleCode.decode(String(mutated), bankVersion: 1))
        }
    }

    func testSameCodeSameDeckRegardlessOfStates() {
        let bank = fullBank(perCategory: 10)
        let first = LinkBattleCode.deck(seed: 42, bank: bank, scheduler: scheduler, now: now)
        let second = LinkBattleCode.deck(seed: 42, bank: bank, scheduler: scheduler, now: now)
        XCTAssertEqual(first.map(\.id), second.map(\.id))
    }

    func testLinkDeckHasTenMixedQuestions() {
        let bank = fullBank(perCategory: 10)
        let deck = LinkBattleCode.deck(seed: 42, bank: bank, scheduler: scheduler, now: now)
        XCTAssertEqual(deck.count, 10)
        XCTAssertGreaterThan(Set(deck.map(\.category)).count, 1)
    }

    func testLinkOpponentIsLinkPilotWithTunedHP() {
        let bank = fullBank(perCategory: 10)
        let deck = LinkBattleCode.deck(seed: 42, bank: bank, scheduler: scheduler, now: now)
        let opponent = LinkBattleCode.opponent(code: "ABCDEF1", deck: deck)
        XCTAssertEqual(opponent.id, "link-ABCDEF1")
        XCTAssertEqual(opponent.name, "LINK PILOT")
        XCTAssertEqual(opponent.nameplateName, "LINK")
        XCTAssertEqual(opponent.tier, .link)
        XCTAssertEqual(opponent.maxHP, OpponentHP.tuned(for: deck))
    }
}
```

Also added to `AppUITests/SmokeTests.swift` (app target, not run on Linux):

```swift
    func testEnteringCodeAndStartingOpensBattle() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["Adventure"].tap()
        XCTAssertTrue(app.buttons["linkBattle"].waitForExistence(timeout: 15))
        app.buttons["linkBattle"].tap()
        XCTAssertTrue(app.textFields["linkCodeField"].waitForExistence(timeout: 15))
        let code = LinkBattleCode.encode(seed: 42, bankVersion: 2)
        app.textFields["linkCodeField"].tap()
        app.textFields["linkCodeField"].typeText(code)
        app.buttons["linkStart"].tap()
        XCTAssertTrue(app.buttons["battleOption-0"].waitForExistence(timeout: 15))
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `scripts/test-core.sh --filter LinkBattleCodeTests`
Expected:
```
IFRCore/Tests/IFRCoreTests/LinkBattleCodeTests.swift:66:20: error: cannot find 'LinkBattleCode' in scope
IFRCore/Tests/IFRCoreTests/LinkBattleCodeTests.swift:78:40: error: type 'Equatable' has no member 'link'
error: fatalError
```
For `testEnteringCodeAndStartingOpensBattle` (Xcode-only), the app does not build: `LinkShareSheet` and the `linkBattle`/`linkCodeField`/`linkStart` identifiers do not exist yet, so Xcode reports `cannot find 'LinkShareSheet' in scope` in `AdventureView.swift` and the UI test target fails to compile until the implementation step below lands.

- [ ] **Step 3: Write the implementation**

File: `IFRCore/Sources/IFRCore/Adventure/Link/LinkBattleCode.swift`

```swift
import Foundation

public enum LinkBattleCode {
    public static let alphabet = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"

    private static let seedMask: UInt32 = 0x3FFF_FFFF
    private static let seedCharacterCount = 6
    private static let alphabetCharacters = Array(alphabet)

    public static func encode(seed: UInt32, bankVersion: Int) -> String {
        let masked = seed & seedMask
        var characters: [Character] = []
        for shift in stride(from: (seedCharacterCount - 1) * 5, through: 0, by: -5) {
            let index = Int((masked >> shift) & 0x1F)
            characters.append(alphabetCharacters[index])
        }
        characters.append(checkCharacter(for: bankVersion))
        return String(characters)
    }

    public static func decode(_ code: String, bankVersion: Int) -> UInt32? {
        let characters = Array(code)
        guard characters.count == seedCharacterCount + 1,
              characters.last == checkCharacter(for: bankVersion) else { return nil }
        var seed: UInt32 = 0
        for character in characters.prefix(seedCharacterCount) {
            guard let index = alphabetCharacters.firstIndex(of: character) else { return nil }
            seed = (seed << 5) | UInt32(index)
        }
        return seed
    }

    public static func deck(seed: UInt32, bank: QuestionBank, scheduler: Scheduler, now: Date) -> [Question] {
        var rng = SeededRNG(seed: UInt64(seed))
        return QuizEngine(scheduler: scheduler).makeQuiz(
            config: QuizConfig(category: nil, length: 10, isMockExam: false),
            bank: bank, states: [:], now: now, using: &rng)
    }

    public static func opponent(code: String, deck: [Question]) -> Opponent {
        Opponent(id: "link-\(code)", name: "LINK PILOT", nameplateName: "LINK", spriteID: "trainer-student",
                 tier: .link, maxHP: OpponentHP.tuned(for: deck))
    }

    private static func checkCharacter(for bankVersion: Int) -> Character {
        alphabetCharacters[bankVersion % alphabetCharacters.count]
    }
}
```

File: `App/Screens/Adventure/LinkShareSheet.swift`

```swift
import SwiftUI
import IFRCore

struct LinkShareSheet: View {
    @Environment(StudyStore.self) private var store
    let content: AdventureContent

    @State private var enteredCode: String = ""
    @State private var ownCode: String = ""
    @State private var activeBattle: BattleRun?
    @State private var battlesWonBeforeBattle = 0
    @State private var lastResult: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Your code") {
                    Text(ownCode)
                    ShareLink(item: shareText)
                }
                Section("Enter opponent code") {
                    TextField("Code", text: $enteredCode)
                        .accessibilityIdentifier("linkCodeField")
                    Button("Start") { start() }
                        .accessibilityIdentifier("linkStart")
                        .disabled(!isEnteredCodeValid)
                }
            }
            .navigationTitle("Link Battle")
        }
        .onAppear { generateOwnCode() }
        .accessibilityIdentifier("linkShareSheet")
        .fullScreenCover(item: $activeBattle) { run in
            BattleScreen(run: run).onDisappear { finish() }
        }
    }

    private var isEnteredCodeValid: Bool {
        LinkBattleCode.decode(enteredCode, bankVersion: store.bank.version) != nil
    }

    private var shareText: String {
        "\(ownCode) \(lastResult)"
    }

    private func generateOwnCode() {
        var rng = SystemRandomNumberGenerator()
        let seed = UInt32.random(in: 0...UInt32.max, using: &rng)
        ownCode = LinkBattleCode.encode(seed: seed, bankVersion: store.bank.version)
    }

    private func start() {
        guard let seed = LinkBattleCode.decode(enteredCode, bankVersion: store.bank.version) else { return }
        let deck = LinkBattleCode.deck(seed: seed, bank: store.bank, scheduler: Scheduler(), now: .now)
        let opponent = LinkBattleCode.opponent(code: enteredCode, deck: deck)
        battlesWonBeforeBattle = store.adventureSave.battlesWon
        activeBattle = BattleRun(
            opponent: opponent, deck: deck, playerMaxHP: PlayerHP.maximum(for: mixedLevel()), missDamage: nil,
            playerSpriteID: "player-back", playerPlateName: "PILOT",
            introDialogue: DialogueScript(pages: []), winDialogue: DialogueScript(pages: []),
            loseDialogue: DialogueScript(pages: []), firstTime: false, returnTo: nil, items: content.items)
    }

    private func mixedLevel() -> MasteryLevel {
        let retentions = store.reviewedRetentionByCategory().values
        let mean = retentions.isEmpty ? 0 : retentions.reduce(0, +) / Double(retentions.count)
        return MasteryLevel.level(forRetention: mean)
    }

    private func finish() {
        lastResult = store.adventureSave.battlesWon > battlesWonBeforeBattle ? "WON" : "LOST"
    }
}
```

Modified existing file, complete new version of `AdventureView`, to add the entry point the UI test drives (`linkBattle` toolbar button presenting `LinkShareSheet`):

File: `App/Screens/Adventure/AdventureView.swift`

```swift
import SwiftUI
import IFRCore

struct AdventureView: View {
    @Environment(StudyStore.self) private var store
    @State private var content: AdventureContent?
    @State private var showingBadgeCase = false
    @State private var showingHallOfFame = false
    @State private var showingCompanions = false
    @State private var showingLink = false
    @State private var evolutionQueue: [CompanionEvolution] = []

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
                    OverworldScreen(content: content, seed: seed, onBattleFinished: checkEvolutions)
                } else {
                    ProgressView()
                        .onAppear { load() }
                }
            }
            .toolbar {
                if content != nil {
                    ToolbarItem { Button("Badges") { showingBadgeCase = true }.accessibilityIdentifier("badgeCase") }
                    ToolbarItem { Button("Hall of Fame") { showingHallOfFame = true }.accessibilityIdentifier("hallOfFame") }
                    ToolbarItem { Button("Companions") { showingCompanions = true }.accessibilityIdentifier("companions") }
                    ToolbarItem { Button("Link") { showingLink = true }.accessibilityIdentifier("linkBattle") }
                }
            }
            .navigationDestination(isPresented: $showingBadgeCase) {
                if let content { BadgeCaseScreen(content: content) }
            }
            .navigationDestination(isPresented: $showingHallOfFame) {
                HallOfFameScreen()
            }
            .navigationDestination(isPresented: $showingCompanions) {
                if let content { CompanionScreen(content: content) }
            }
            .sheet(isPresented: $showingLink) {
                if let content { LinkShareSheet(content: content) }
            }
            .onAppear { checkEvolutions() }
            .fullScreenCover(isPresented: evolutionShowingBinding()) {
                if let content, let evolution = evolutionQueue.first {
                    EvolutionScreen(evolution: evolution, content: content, onFinished: { evolutionQueue.removeFirst() })
                }
            }
        }
    }

    private func load() {
        content = try? AdventureContent.load()
        if let seededSave {
            store.updateAdventureSave(seededSave)
        }
    }

    private func checkEvolutions() {
        evolutionQueue.append(contentsOf: store.pendingEvolutions())
    }

    private func evolutionShowingBinding() -> Binding<Bool> {
        Binding(get: { !evolutionQueue.isEmpty }, set: { showing in if !showing { evolutionQueue.removeAll() } })
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

- [ ] **Step 4: Run all core tests**

Run: `scripts/test-core.sh`
Expected: `Executed 369 tests, with 0 failures`

- [ ] **Step 5: Commit**

Run: `git add FlashCards/IFRCore/Sources/IFRCore/Adventure/Link/LinkBattleCode.swift FlashCards/IFRCore/Tests/IFRCoreTests/LinkBattleCodeTests.swift FlashCards/App/Screens/Adventure/LinkShareSheet.swift FlashCards/App/Screens/Adventure/AdventureView.swift FlashCards/AppUITests/SmokeTests.swift && git commit -m "M3-05: Link battles"`

---

### Task M3-06: Chiptune (optional, Xcode)

**Files:**
- Create: `App/Audio/Chiptune.swift`
- Modify: `App/Persistence/Records.swift`
- Test: `AppTests/ChiptuneTests.swift`

**Interfaces:**
- Consumes: `SettingsRecord` (`App/Persistence/Records.swift`, a SwiftData `@Model`)
- Produces: `ChiptuneCue: CaseIterable, Sendable` (six cases); `ChiptuneEffect: Equatable, Sendable { frequency: Double; frames: Int }`; `enum ChiptuneCatalog { static let sampleRate: Double; static let effects: [ChiptuneCue: ChiptuneEffect]; static func effect(for cue: ChiptuneCue) -> ChiptuneEffect }`; `final class Chiptune { init(isEnabled: Bool); func setEnabled(_ enabled: Bool); func play(_ cue: ChiptuneCue) }`; `SettingsRecord.soundEnabled: Bool = false`

- [ ] **Step 1: Write the failing tests**

File: `AppTests/ChiptuneTests.swift`

```swift
import XCTest
@testable import IFRFlashCards

final class ChiptuneTests: XCTestCase {
    func testSoundIsMutedByDefault() {
        XCTAssertFalse(SettingsRecord().soundEnabled)
    }

    func testEachEffectHasAFrequencyAndDurationUnderHalfASecond() {
        for cue in ChiptuneCue.allCases {
            let effect = ChiptuneCatalog.effect(for: cue)
            XCTAssertGreaterThan(effect.frequency, 0)
            XCTAssertLessThan(Double(effect.frames) / ChiptuneCatalog.sampleRate, 0.5)
        }
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `scripts/test-app.sh --filter ChiptuneTests` (AppTests cannot be compiled on the Linux build machine, so this was not executed; run it in Xcode)
Expected: two compile errors — `value of type 'SettingsRecord' has no member 'soundEnabled'` on `testSoundIsMutedByDefault`, and `cannot find type 'ChiptuneCue' in scope` on `testEachEffectHasAFrequencyAndDurationUnderHalfASecond`, since neither `SettingsRecord.soundEnabled` nor any `Chiptune` type existed before this task.

- [ ] **Step 3: Write the implementation**

File: `App/Persistence/Records.swift` — added field on the existing `SettingsRecord` model:

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
    var soundEnabled: Bool = false

    init() {}

    var studySettings: StudySettings {
        StudySettings(newCardsPerDay: newCardsPerDay,
                      unlockedCategories: Set(unlockedCategoriesRaw.compactMap(IFRCore.Category.init(rawValue:))),
                      dailyGoalCards: dailyGoalCards)
    }
}
```

- [ ] **Step 4: Write the implementation**

File: `App/Audio/Chiptune.swift`

```swift
import AVFoundation

enum ChiptuneCue: CaseIterable, Sendable {
    case correctAnswer
    case wrongAnswer
    case criticalHit
    case badgeEarned
    case whiteout
    case menuSelect
}

struct ChiptuneEffect: Equatable, Sendable {
    let frequency: Double
    let frames: Int
}

enum ChiptuneCatalog {
    static let sampleRate: Double = 44_100

    static let effects: [ChiptuneCue: ChiptuneEffect] = [
        .correctAnswer: ChiptuneEffect(frequency: 880, frames: 5_292),
        .wrongAnswer: ChiptuneEffect(frequency: 220, frames: 7_938),
        .criticalHit: ChiptuneEffect(frequency: 1_320, frames: 8_820),
        .badgeEarned: ChiptuneEffect(frequency: 660, frames: 17_640),
        .whiteout: ChiptuneEffect(frequency: 110, frames: 19_845),
        .menuSelect: ChiptuneEffect(frequency: 440, frames: 3_528)
    ]

    static func effect(for cue: ChiptuneCue) -> ChiptuneEffect {
        effects[cue]!
    }
}

final class Chiptune {
    private let engine = AVAudioEngine()
    private var isEnabled: Bool

    init(isEnabled: Bool) {
        self.isEnabled = isEnabled
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }

    func play(_ cue: ChiptuneCue) {
        guard isEnabled else { return }
        let effect = ChiptuneCatalog.effect(for: cue)
        let node = squareWaveNode(for: effect)
        let format = AVAudioFormat(standardFormatWithSampleRate: ChiptuneCatalog.sampleRate, channels: 1)!
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        try? engine.start()
        schedulesStop(of: node, afterFrames: effect.frames)
    }

    private func squareWaveNode(for effect: ChiptuneEffect) -> AVAudioSourceNode {
        var frameIndex = 0
        let sampleRate = ChiptuneCatalog.sampleRate
        let frequency = effect.frequency
        let totalFrames = effect.frames
        return AVAudioSourceNode { _, _, frameCount, audioBufferList in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0..<Int(frameCount) {
                let sample = squareWaveSample(frameIndex: frameIndex, totalFrames: totalFrames,
                                              frequency: frequency, sampleRate: sampleRate)
                for buffer in buffers {
                    let channel = UnsafeMutableBufferPointer<Float>(buffer)
                    channel[frame] = sample
                }
                frameIndex += 1
            }
            return noErr
        }
    }

    private func schedulesStop(of node: AVAudioSourceNode, afterFrames frames: Int) {
        let seconds = Double(frames) / ChiptuneCatalog.sampleRate
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds + 0.05) { [weak self] in
            self?.engine.stop()
            self?.engine.detach(node)
        }
    }
}

private func squareWaveSample(frameIndex: Int, totalFrames: Int, frequency: Double, sampleRate: Double) -> Float {
    guard frameIndex < totalFrames else { return 0 }
    let phase = (frequency * Double(frameIndex) / sampleRate).truncatingRemainder(dividingBy: 1)
    return phase < 0.5 ? 0.2 : -0.2
}
```

- [ ] **Step 5: Run all core tests**

Run: `scripts/test-core.sh`
Expected: `Executed 369 tests, with 0 failures (0 unexpected) in 1.606 (1.606) seconds`

(`ChiptuneTests` is an app-target test and is not part of this run; it was not executed, only written to the spec's exact names and file, and reasoned through for correctness against the existing `SettingsRecord` model and `AVAudioSourceNode`/`AVAudioEngine` APIs.)

- [ ] **Step 6: Commit**

Run: `git add App/Audio/Chiptune.swift App/Persistence/Records.swift AppTests/ChiptuneTests.swift && git commit -m "M3-06: Chiptune"`

---
