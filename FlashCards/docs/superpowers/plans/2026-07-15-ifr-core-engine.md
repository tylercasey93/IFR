# IFR Core Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `IFRCore`, a pure-Swift package containing every piece of app logic that doesn't touch a screen: question bank models + validation, FSRS scheduling, the study queue, XP, streaks, mastery/readiness, quiz/mock-exam assembly, and badges — all unit-tested via `swift test` with no simulator.

**Architecture:** A local Swift Package consumed later by the iOS app (separate plan). Everything is value types + pure functions; time, calendars, and randomness are always injected parameters so every behavior is deterministic and testable. The only dependency is the official FSRS package.

**Tech Stack:** Swift 5.9, Swift Package Manager, XCTest, [open-spaced-repetition/swift-fsrs](https://github.com/open-spaced-repetition/swift-fsrs) v5.x (product name `FSRS`, MIT).

## Global Constraints

- Package lives at `IFRCore/` inside the repo root `/Users/tylercasey/Documents/Projects/FlashCards`.
- Platforms: `.iOS(.v17), .macOS(.v14)` — macOS included so `swift test` runs on the host with no simulator.
- Only third-party dependency: `https://github.com/open-spaced-repetition/swift-fsrs`, `from: "5.0.0"`.
- All public types `Sendable`; no singletons; no `Date()`/`Calendar.current`/`SystemRandomNumberGenerator` inside logic — callers inject them.
- Grades everywhere are `again/hard/good/easy`. Desired retention is 0.9.
- The 8 categories and their `examWeight` values (12, 12, 8, 7, 7, 8, 4, 2 — sum 60) are fixed; `examWeight` doubles as the mock-exam per-category question count.
- Run all tests from `IFRCore/` with `swift test`. Commit after every green task.
- **swift-fsrs API note:** the adapter in Task 3 is the ONLY file allowed to import `FSRS`. Its documented API is `FSRS(parameters:)` / `try fsrs.next(card:now:grade:).card`; if property names differ at the pinned version, adapt inside `Scheduler.swift` only — the tests define the required behavior, not the package's spelling.

---

### Task 1: Package scaffold + Question model

**Files:**
- Create: `IFRCore/Package.swift`
- Create: `IFRCore/Sources/IFRCore/Models/Question.swift`
- Test: `IFRCore/Tests/IFRCoreTests/QuestionDecodingTests.swift`

**Interfaces:**
- Consumes: nothing (first task).
- Produces: `Category` (enum, `displayName: String`, `examWeight: Int`), `QuestionFormat`, `SourceRef`, `Question` — exactly as coded below. Every later task uses these.

- [ ] **Step 1: Create the package manifest**

```swift
// IFRCore/Package.swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "IFRCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "IFRCore", targets: ["IFRCore"])],
    dependencies: [
        .package(url: "https://github.com/open-spaced-repetition/swift-fsrs", from: "5.0.0"),
    ],
    targets: [
        .target(
            name: "IFRCore",
            dependencies: [.product(name: "FSRS", package: "swift-fsrs")],
            resources: [.copy("Resources/bank-v1.json")]
        ),
        .testTarget(name: "IFRCoreTests", dependencies: ["IFRCore"]),
    ]
)
```

Also create an empty placeholder so the resource target compiles before Task 2: `IFRCore/Sources/IFRCore/Resources/bank-v1.json` containing `{"version": 1, "questions": []}`.

- [ ] **Step 2: Write the failing test**

```swift
// IFRCore/Tests/IFRCoreTests/QuestionDecodingTests.swift
import XCTest
@testable import IFRCore

final class QuestionDecodingTests: XCTestCase {
    func testDecodesFullQuestion() throws {
        let json = """
        {
          "id": "reg-001",
          "category": "regulations",
          "acsCodes": ["IR.I.A.K1"],
          "format": "multipleChoice",
          "front": "To act as PIC under IFR, what instrument experience must be logged in the preceding 6 calendar months?",
          "back": "Six instrument approaches, holding procedures and tasks, and intercepting and tracking courses using navigation systems.",
          "options": [
            "Six instrument approaches, holding procedures and tasks, and intercepting/tracking courses",
            "Six hours of instrument time including three approaches",
            "Three approaches and three hours of simulated instrument time"
          ],
          "correctIndex": 0,
          "explanation": "14 CFR 61.57(c) requires the '66 HIT' items within the preceding 6 calendar months.",
          "source": {
            "document": "14 CFR 61.57(c)",
            "section": "Instrument experience",
            "url": "https://www.ecfr.gov/current/title-14/section-61.57"
          },
          "figure": null,
          "difficulty": 1
        }
        """.data(using: .utf8)!
        let q = try JSONDecoder().decode(Question.self, from: json)
        XCTAssertEqual(q.id, "reg-001")
        XCTAssertEqual(q.category, .regulations)
        XCTAssertEqual(q.format, .multipleChoice)
        XCTAssertEqual(q.correctIndex, 0)
        XCTAssertEqual(q.options?.count, 3)
        XCTAssertNil(q.figure)
    }

    func testCategoryExamWeightsSumTo60() {
        XCTAssertEqual(Category.allCases.map(\.examWeight).reduce(0, +), 60)
    }
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd IFRCore && swift test`
Expected: compile FAILURE — `cannot find type 'Question' in scope`.

- [ ] **Step 4: Write the model**

```swift
// IFRCore/Sources/IFRCore/Models/Question.swift
import Foundation

public enum Category: String, Codable, CaseIterable, Sendable, Hashable {
    case regulations, weather, chartsAndPlanning, navigation
    case instrumentsAndSystems, approaches, emergencies, humanFactors

    public var displayName: String {
        switch self {
        case .regulations: "Regulations & Procedures"
        case .weather: "Weather & Weather Services"
        case .chartsAndPlanning: "En Route Charts & Flight Planning"
        case .navigation: "Navigation & Avionics"
        case .instrumentsAndSystems: "Flight Instruments & Systems"
        case .approaches: "Instrument Approaches"
        case .emergencies: "Emergencies, Lost Comms & ATC"
        case .humanFactors: "Human Factors & Aeromedical"
        }
    }

    /// Relative prominence on the real exam. Drives new-card priority and
    /// quiz weighting, and doubles as the mock-exam per-category count (sums to 60).
    public var examWeight: Int {
        switch self {
        case .regulations: 12
        case .weather: 12
        case .chartsAndPlanning: 8
        case .navigation: 7
        case .instrumentsAndSystems: 7
        case .approaches: 8
        case .emergencies: 4
        case .humanFactors: 2
        }
    }
}

public enum QuestionFormat: String, Codable, Sendable {
    case flashcard, multipleChoice, both
}

public struct SourceRef: Codable, Equatable, Sendable {
    public let document: String
    public let section: String
    public let url: URL

    public init(document: String, section: String, url: URL) {
        self.document = document
        self.section = section
        self.url = url
    }
}

public struct Question: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let category: Category
    public let acsCodes: [String]
    public let format: QuestionFormat
    public let front: String
    public let back: String
    public let options: [String]?
    public let correctIndex: Int?
    public let explanation: String
    public let source: SourceRef
    public let figure: String?
    public let difficulty: Int

    public var isMultipleChoiceCapable: Bool { format != .flashcard }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd IFRCore && swift test`
Expected: `Test Suite 'All tests' passed` (2 tests).

- [ ] **Step 6: Commit**

```bash
git add IFRCore && git commit -m "feat: IFRCore package scaffold with Question model"
```

---

### Task 2: Seed question bank + validation

**Files:**
- Create: `IFRCore/Sources/IFRCore/Models/QuestionBank.swift`
- Modify: `IFRCore/Sources/IFRCore/Resources/bank-v1.json` (replace placeholder)
- Test: `IFRCore/Tests/IFRCoreTests/BankValidationTests.swift`

**Interfaces:**
- Consumes: `Question`, `Category`, `QuestionFormat` from Task 1.
- Produces: `QuestionBank` (`version: Int`, `questions: [Question]`, `static func load() throws -> QuestionBank`, `func validate() throws`, `func questions(in: Category) -> [Question]`), `BankValidationError`.

- [ ] **Step 1: Write the failing tests**

```swift
// IFRCore/Tests/IFRCoreTests/BankValidationTests.swift
import XCTest
@testable import IFRCore

final class BankValidationTests: XCTestCase {
    private func makeQuestion(
        id: String = "q1", category: Category = .weather, format: QuestionFormat = .flashcard,
        options: [String]? = nil, correctIndex: Int? = nil, difficulty: Int = 1
    ) -> Question {
        Question(id: id, category: category, acsCodes: ["IR.I.B.K1"], format: format,
                 front: "front", back: "back", options: options, correctIndex: correctIndex,
                 explanation: "why",
                 source: SourceRef(document: "AIM", section: "s", url: URL(string: "https://faa.gov")!),
                 figure: nil, difficulty: difficulty)
    }

    func testBundledBankLoadsAndValidates() throws {
        let bank = try QuestionBank.load()
        XCTAssertGreaterThanOrEqual(bank.questions.count, 16)
        XCTAssertEqual(Set(bank.questions.map(\.category)).count, 8, "seed bank covers all categories")
    }

    func testDuplicateIDFails() {
        let bank = QuestionBank(version: 1, questions: [makeQuestion(), makeQuestion()])
        XCTAssertThrowsError(try bank.validate()) {
            XCTAssertEqual($0 as? BankValidationError, .duplicateID("q1"))
        }
    }

    func testMCWithoutOptionsFails() {
        let bank = QuestionBank(version: 1, questions: [makeQuestion(format: .multipleChoice)])
        XCTAssertThrowsError(try bank.validate()) {
            XCTAssertEqual($0 as? BankValidationError, .missingOptions(id: "q1"))
        }
    }

    func testBadCorrectIndexFails() {
        let bank = QuestionBank(version: 1, questions:
            [makeQuestion(format: .multipleChoice, options: ["a", "b", "c"], correctIndex: 3)])
        XCTAssertThrowsError(try bank.validate()) {
            XCTAssertEqual($0 as? BankValidationError, .badCorrectIndex(id: "q1"))
        }
    }

    func testBadDifficultyFails() {
        let bank = QuestionBank(version: 1, questions: [makeQuestion(difficulty: 4)])
        XCTAssertThrowsError(try bank.validate()) {
            XCTAssertEqual($0 as? BankValidationError, .badDifficulty(id: "q1"))
        }
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd IFRCore && swift test --filter BankValidationTests`
Expected: compile FAILURE — `cannot find type 'QuestionBank'`.

- [ ] **Step 3: Implement QuestionBank**

```swift
// IFRCore/Sources/IFRCore/Models/QuestionBank.swift
import Foundation

public enum BankValidationError: Error, Equatable {
    case duplicateID(String)
    case missingOptions(id: String)
    case badCorrectIndex(id: String)
    case badDifficulty(id: String)
    case emptyField(id: String, field: String)
}

public struct QuestionBank: Codable, Sendable {
    public let version: Int
    public let questions: [Question]

    public init(version: Int, questions: [Question]) {
        self.version = version
        self.questions = questions
    }

    public static func load() throws -> QuestionBank {
        let url = Bundle.module.url(forResource: "bank-v1", withExtension: "json")!
        let bank = try JSONDecoder().decode(QuestionBank.self, from: Data(contentsOf: url))
        try bank.validate()
        return bank
    }

    public func questions(in category: Category) -> [Question] {
        questions.filter { $0.category == category }
    }

    public func validate() throws {
        var seen = Set<String>()
        for q in questions {
            guard seen.insert(q.id).inserted else { throw BankValidationError.duplicateID(q.id) }
            if q.front.isEmpty { throw BankValidationError.emptyField(id: q.id, field: "front") }
            if q.back.isEmpty { throw BankValidationError.emptyField(id: q.id, field: "back") }
            if q.explanation.isEmpty { throw BankValidationError.emptyField(id: q.id, field: "explanation") }
            if q.acsCodes.isEmpty { throw BankValidationError.emptyField(id: q.id, field: "acsCodes") }
            guard (1...3).contains(q.difficulty) else { throw BankValidationError.badDifficulty(id: q.id) }
            if q.isMultipleChoiceCapable {
                guard let options = q.options, options.count >= 3 else {
                    throw BankValidationError.missingOptions(id: q.id)
                }
                guard let idx = q.correctIndex, options.indices.contains(idx) else {
                    throw BankValidationError.badCorrectIndex(id: q.id)
                }
            }
        }
    }
}
```

- [ ] **Step 4: Write the seed bank (16 real questions, 2 per category)**

Replace `IFRCore/Sources/IFRCore/Resources/bank-v1.json` with:

```json
{
  "version": 1,
  "questions": [
    {
      "id": "reg-001",
      "category": "regulations",
      "acsCodes": ["IR.I.A.K1"],
      "format": "multipleChoice",
      "front": "To act as pilot in command under IFR, what instrument experience must you have logged within the preceding 6 calendar months?",
      "back": "Six instrument approaches, holding procedures and tasks, and intercepting and tracking courses through the use of navigational electronic systems.",
      "options": [
        "Six instrument approaches, holding procedures and tasks, and intercepting and tracking courses using navigation systems",
        "Six hours of instrument flight time, including at least three instrument approaches",
        "Three instrument approaches and three hours of simulated instrument time with a safety pilot"
      ],
      "correctIndex": 0,
      "explanation": "14 CFR 61.57(c) — the '66 HIT' rule: within 6 calendar months, 6 approaches, Holding, Intercepting and Tracking. There is no hourly requirement.",
      "source": {
        "document": "14 CFR 61.57(c)",
        "section": "Instrument experience",
        "url": "https://www.ecfr.gov/current/title-14/section-61.57"
      },
      "figure": null,
      "difficulty": 1
    },
    {
      "id": "wx-001",
      "category": "weather",
      "acsCodes": ["IR.I.B.K2"],
      "format": "flashcard",
      "front": "What two conditions must be present for structural icing to occur in flight?",
      "back": "Visible moisture (clouds or precipitation) and an aircraft surface temperature at or below freezing (0°C).",
      "options": null,
      "correctIndex": null,
      "explanation": "Both conditions are required: supercooled visible moisture strikes a below-freezing airframe and freezes on contact.",
      "source": {
        "document": "Aviation Weather Handbook (FAA-H-8083-28A)",
        "section": "Icing",
        "url": "https://www.faa.gov/regulations_policies/handbooks_manuals/aviation/faa-h-8083-28"
      },
      "figure": null,
      "difficulty": 1
    },
    {
      "id": "cht-001",
      "category": "chartsAndPlanning",
      "acsCodes": ["IR.I.C.K2"],
      "format": "multipleChoice",
      "front": "What does the Minimum En Route Altitude (MEA) on an IFR en route chart guarantee?",
      "back": "Acceptable navigational signal coverage and obstacle clearance requirements for the route segment.",
      "options": [
        "Acceptable navigation signal coverage and required obstacle clearance for the segment",
        "Obstacle clearance only; navigation reception is guaranteed by the MOCA",
        "Radar coverage and two-way communications with ATC for the segment"
      ],
      "correctIndex": 0,
      "explanation": "The MEA assures both obstacle clearance and nav signal coverage. The MOCA assures obstacle clearance but VOR reception only within 22 NM.",
      "source": {
        "document": "AIM",
        "section": "5-6, Pilot/Controller Glossary — Minimum En Route IFR Altitude",
        "url": "https://www.faa.gov/air_traffic/publications/atpubs/aim_html/"
      },
      "figure": null,
      "difficulty": 1
    },
    {
      "id": "nav-001",
      "category": "navigation",
      "acsCodes": ["IR.I.C.K3"],
      "format": "flashcard",
      "front": "What are the maximum permissible bearing errors for a VOR check using (a) a VOT, (b) a ground checkpoint, and (c) an airborne checkpoint?",
      "back": "(a) VOT: ±4°, (b) ground checkpoint: ±4°, (c) airborne checkpoint: ±6°. Dual-VOR cross-check: 4° between indicated bearings.",
      "options": null,
      "correctIndex": null,
      "explanation": "14 CFR 91.171 requires a VOR check within the preceding 30 days for IFR flight using VOR navigation, with these tolerances.",
      "source": {
        "document": "14 CFR 91.171",
        "section": "VOR equipment check for IFR operations",
        "url": "https://www.ecfr.gov/current/title-14/section-91.171"
      },
      "figure": null,
      "difficulty": 2
    },
    {
      "id": "ins-001",
      "category": "instrumentsAndSystems",
      "acsCodes": ["IR.IV.A.K1"],
      "format": "multipleChoice",
      "front": "In a typical light training aircraft, which flight instruments are driven by the vacuum system?",
      "back": "The attitude indicator and the heading indicator.",
      "options": [
        "Attitude indicator and heading indicator",
        "Attitude indicator and turn coordinator",
        "Airspeed indicator, altimeter, and vertical speed indicator"
      ],
      "correctIndex": 0,
      "explanation": "The vacuum system typically spins the gyros in the attitude and heading indicators. The turn coordinator is usually electric; airspeed/altimeter/VSI are pitot-static.",
      "source": {
        "document": "Instrument Flying Handbook (FAA-H-8083-15B)",
        "section": "Ch. 5 — Flight Instruments",
        "url": "https://www.faa.gov/regulations_policies/handbooks_manuals/aviation/instrument_flying_handbook"
      },
      "figure": null,
      "difficulty": 1
    },
    {
      "id": "app-001",
      "category": "approaches",
      "acsCodes": ["IR.VI.A.K5"],
      "format": "multipleChoice",
      "front": "What conditions must be met before you may descend below the DA or MDA on an instrument approach?",
      "back": "The aircraft is in a position to make a normal descent to landing, flight visibility is at or above the published minimum, and a required runway environment reference is distinctly visible.",
      "options": [
        "Normal descent-to-landing position, required flight visibility, and a listed runway environment reference in sight",
        "The runway environment in sight and ATC clearance to land",
        "Required flight visibility and the ceiling reported at or above published minimums"
      ],
      "correctIndex": 0,
      "explanation": "14 CFR 91.175(c) lists all three conditions; reported ceiling is not one of them — flight visibility controls.",
      "source": {
        "document": "14 CFR 91.175(c)",
        "section": "Operation below DA/DH or MDA",
        "url": "https://www.ecfr.gov/current/title-14/section-91.175"
      },
      "figure": null,
      "difficulty": 2
    },
    {
      "id": "emg-001",
      "category": "emergencies",
      "acsCodes": ["IR.VII.A.K1"],
      "format": "flashcard",
      "front": "You lose two-way radio communication in IMC. What route are you expected to fly?",
      "back": "In this order (AVEF): the route Assigned; if being radar Vectored, direct to the fix/route/airway in the vector clearance; in the absence of an assigned route, the route ATC said to Expect; otherwise the route Filed.",
      "options": null,
      "correctIndex": null,
      "explanation": "14 CFR 91.185(c)(1) — remember AVEF. Altitude is the highest of Minimum en route, Expected, or Assigned (MEA) for each segment.",
      "source": {
        "document": "14 CFR 91.185(c)",
        "section": "IFR operations: two-way radio communications failure",
        "url": "https://www.ecfr.gov/current/title-14/section-91.185"
      },
      "figure": null,
      "difficulty": 2
    },
    {
      "id": "hf-001",
      "category": "humanFactors",
      "acsCodes": ["IR.I.A.K3"],
      "format": "flashcard",
      "front": "During a constant-rate turn, you tilt your head down to look at a chart and suddenly feel the aircraft tumbling. Which illusion is this?",
      "back": "The Coriolis illusion.",
      "options": null,
      "correctIndex": null,
      "explanation": "Moving the head in a prolonged constant-rate turn stimulates multiple semicircular canals at once, creating an overwhelming tumbling sensation. Keep head movements minimal in IMC.",
      "source": {
        "document": "Instrument Flying Handbook (FAA-H-8083-15B)",
        "section": "Ch. 3 — Human Factors: vestibular illusions",
        "url": "https://www.faa.gov/regulations_policies/handbooks_manuals/aviation/instrument_flying_handbook"
      },
      "figure": null,
      "difficulty": 1
    },
    {
      "id": "reg-002",
      "category": "regulations",
      "acsCodes": ["IR.I.C.K1"],
      "format": "flashcard",
      "front": "Under 14 CFR 91.169, when is filing an alternate airport NOT required (the '1-2-3 rule')?",
      "back": "When the destination has an instrument approach and, from 1 hour before to 1 hour after the ETA, the forecast ceiling is at least 2,000 ft and visibility is at least 3 SM.",
      "options": null,
      "correctIndex": null,
      "explanation": "Remember 1-2-3: ±1 hour of ETA, 2,000-foot ceiling, 3 statute miles visibility. Fail any one and you must file an alternate.",
      "source": {
        "document": "14 CFR 91.169",
        "section": "IFR flight plan: information required",
        "url": "https://www.ecfr.gov/current/title-14/section-91.169"
      },
      "figure": null,
      "difficulty": 2
    },
    {
      "id": "wx-002",
      "category": "weather",
      "acsCodes": ["IR.I.B.K2"],
      "format": "multipleChoice",
      "front": "Which conditions are most favorable for the formation of radiation fog?",
      "back": "Clear skies, light or calm wind, and moist air over low, flat terrain at night.",
      "options": [
        "Clear skies, calm winds, and moist air over low-lying terrain at night",
        "Warm moist air moving over a colder surface with moderate winds",
        "Overcast skies and gusty winds behind a cold front"
      ],
      "correctIndex": 0,
      "explanation": "Radiation fog forms when the ground cools rapidly on clear, calm nights and chills moist air to its dew point. Warm air over a cold surface produces advection fog instead.",
      "source": {
        "document": "Aviation Weather Handbook (FAA-H-8083-28A)",
        "section": "Fog",
        "url": "https://www.faa.gov/regulations_policies/handbooks_manuals/aviation/faa-h-8083-28"
      },
      "figure": null,
      "difficulty": 1
    },
    {
      "id": "cht-002",
      "category": "chartsAndPlanning",
      "acsCodes": ["IR.I.C.K2"],
      "format": "flashcard",
      "front": "What does the MOCA (Minimum Obstruction Clearance Altitude) guarantee, and what is its navigation limitation?",
      "back": "Required obstacle clearance for the entire route segment, but acceptable VOR navigation signal coverage only within 22 NM of the VOR.",
      "options": null,
      "correctIndex": null,
      "explanation": "Compare with the MEA, which guarantees both obstacle clearance and nav signal coverage for the whole segment.",
      "source": {
        "document": "AIM",
        "section": "Pilot/Controller Glossary — Minimum Obstruction Clearance Altitude",
        "url": "https://www.faa.gov/air_traffic/publications/atpubs/aim_html/"
      },
      "figure": null,
      "difficulty": 2
    },
    {
      "id": "nav-002",
      "category": "navigation",
      "acsCodes": ["IR.I.C.K3"],
      "format": "multipleChoice",
      "front": "To use VOR navigation under IFR, the VOR equipment check must have been performed within the preceding:",
      "back": "30 days.",
      "options": [
        "30 days",
        "10 days",
        "24 calendar months"
      ],
      "correctIndex": 0,
      "explanation": "14 CFR 91.171: the VOR check must be within the preceding 30 days (and logged). 24 calendar months applies to the altimeter/pitot-static and transponder checks, not the VOR.",
      "source": {
        "document": "14 CFR 91.171",
        "section": "VOR equipment check for IFR operations",
        "url": "https://www.ecfr.gov/current/title-14/section-91.171"
      },
      "figure": null,
      "difficulty": 1
    },
    {
      "id": "ins-002",
      "category": "instrumentsAndSystems",
      "acsCodes": ["IR.IV.A.K2"],
      "format": "flashcard",
      "front": "The pitot tube's ram inlet and drain hole both become blocked by ice, but the static ports stay clear. How does the airspeed indicator behave?",
      "back": "It acts like an altimeter — indicated airspeed increases in a climb and decreases in a descent, regardless of actual airspeed.",
      "options": null,
      "correctIndex": null,
      "explanation": "Trapped pressure in the pitot line stays constant while static pressure changes with altitude, so the ASI responds to altitude changes instead of airspeed.",
      "source": {
        "document": "Instrument Flying Handbook (FAA-H-8083-15B)",
        "section": "Ch. 5 — Flight Instruments: pitot-static system failures",
        "url": "https://www.faa.gov/regulations_policies/handbooks_manuals/aviation/instrument_flying_handbook"
      },
      "figure": null,
      "difficulty": 2
    },
    {
      "id": "app-002",
      "category": "approaches",
      "acsCodes": ["IR.VI.A.K1"],
      "format": "flashcard",
      "front": "What is the difference between a DA and an MDA?",
      "back": "DA (decision altitude) applies to approaches with vertical guidance: you decide to continue or go missed while still descending through it. MDA (minimum descent altitude) applies to nonprecision approaches: it is a floor you may not descend below without the visual references required by 91.175.",
      "options": null,
      "correctIndex": null,
      "explanation": "At DA the momentary dip below during the missed is expected; the MDA must not be penetrated at all without visual references.",
      "source": {
        "document": "Instrument Procedures Handbook (FAA-H-8083-16B)",
        "section": "Approaches — minimums",
        "url": "https://www.faa.gov/regulations_policies/handbooks_manuals/aviation/instrument_procedures_handbook"
      },
      "figure": null,
      "difficulty": 1
    },
    {
      "id": "emg-002",
      "category": "emergencies",
      "acsCodes": ["IR.VII.A.K2"],
      "format": "multipleChoice",
      "front": "What transponder code should you squawk after a two-way radio communications failure?",
      "back": "7600.",
      "options": [
        "7600",
        "7500",
        "7700"
      ],
      "correctIndex": 0,
      "explanation": "7500 = hijacking, 7600 = lost communications, 7700 = emergency. Remember: 75 taken alive, 76 radio fix, 77 going to heaven.",
      "source": {
        "document": "AIM",
        "section": "6-4-2 — Transponder operation during two-way communications failure",
        "url": "https://www.faa.gov/air_traffic/publications/atpubs/aim_html/"
      },
      "figure": null,
      "difficulty": 1
    },
    {
      "id": "hf-002",
      "category": "humanFactors",
      "acsCodes": ["IR.I.A.K3"],
      "format": "multipleChoice",
      "front": "During a rapid acceleration on takeoff into IMC, the somatogravic illusion creates the sensation of:",
      "back": "An excessive nose-up pitch attitude.",
      "options": [
        "Pitching up excessively, tempting a nose-down correction",
        "Pitching down, tempting a pull-up into a stall",
        "Banking left when the wings are level"
      ],
      "correctIndex": 0,
      "explanation": "Acceleration feels like tilting backward, so the pilot may push the nose over into the ground. Trust the attitude indicator during acceleration.",
      "source": {
        "document": "Instrument Flying Handbook (FAA-H-8083-15B)",
        "section": "Ch. 3 — Human Factors: vestibular illusions",
        "url": "https://www.faa.gov/regulations_policies/handbooks_manuals/aviation/instrument_flying_handbook"
      },
      "figure": null,
      "difficulty": 2
    }
  ]
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd IFRCore && swift test`
Expected: all tests pass, including `testBundledBankLoadsAndValidates`.

- [ ] **Step 6: Commit**

```bash
git add IFRCore && git commit -m "feat: question bank loading, validation, and 8-question seed bank"
```

---

### Task 3: FSRS scheduler adapter

**Files:**
- Create: `IFRCore/Sources/IFRCore/Scheduling/CardState.swift`
- Create: `IFRCore/Sources/IFRCore/Scheduling/Scheduler.swift`
- Test: `IFRCore/Tests/IFRCoreTests/SchedulerTests.swift`

**Interfaces:**
- Consumes: nothing from earlier tasks (standalone).
- Produces:
  - `Grade` enum: `.again, .hard, .good, .easy` (raw Int 1–4).
  - `CardState`: `questionID: String`, `stability: Double`, `difficulty: Double`, `due: Date`, `lastReview: Date?`, `reps: Int`, `lapses: Int`; `static func new(questionID: String) -> CardState` (due = .distantPast, reps 0).
  - `Scheduler`: `init(desiredRetention: Double = 0.9)`; `func review(_ state: CardState, grade: Grade, at date: Date) -> CardState`; `func retrievability(of state: CardState, at date: Date) -> Double`.

- [ ] **Step 1: Write the failing tests**

```swift
// IFRCore/Tests/IFRCoreTests/SchedulerTests.swift
import XCTest
@testable import IFRCore

final class SchedulerTests: XCTestCase {
    let scheduler = Scheduler()
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    func testNewCardGoodSchedulesInFuture() {
        let s = scheduler.review(.new(questionID: "q"), grade: .good, at: t0)
        XCTAssertGreaterThan(s.due, t0)
        XCTAssertEqual(s.reps, 1)
        XCTAssertEqual(s.lastReview, t0)
    }

    func testAgainIsSoonerThanGoodIsSoonerThanEasy() {
        let again = scheduler.review(.new(questionID: "q"), grade: .again, at: t0)
        let good = scheduler.review(.new(questionID: "q"), grade: .good, at: t0)
        let easy = scheduler.review(.new(questionID: "q"), grade: .easy, at: t0)
        XCTAssertLessThan(again.due, good.due)
        XCTAssertLessThan(good.due, easy.due)
    }

    func testAgainIncrementsLapsesOnReviewCard() {
        var s = scheduler.review(.new(questionID: "q"), grade: .good, at: t0)
        s = scheduler.review(s, grade: .again, at: s.due)
        XCTAssertEqual(s.lapses, 1)
    }

    func testIntervalGrowsAcrossSuccessfulReviews() {
        var s = scheduler.review(.new(questionID: "q"), grade: .good, at: t0)
        let firstInterval = s.due.timeIntervalSince(t0)
        let secondReviewDate = s.due
        s = scheduler.review(s, grade: .good, at: secondReviewDate)
        let secondInterval = s.due.timeIntervalSince(secondReviewDate)
        XCTAssertGreaterThan(secondInterval, firstInterval)
    }

    func testRetrievabilityIsZeroForUnseenAndDecays() {
        XCTAssertEqual(scheduler.retrievability(of: .new(questionID: "q"), at: t0), 0)
        let s = scheduler.review(.new(questionID: "q"), grade: .good, at: t0)
        let soon = scheduler.retrievability(of: s, at: t0.addingTimeInterval(3600))
        let later = scheduler.retrievability(of: s, at: t0.addingTimeInterval(30 * 86_400))
        XCTAssertGreaterThan(soon, later)
        XCTAssertGreaterThan(soon, 0.9)
    }

    func testCardStateCodableRoundTrip() throws {
        // Compare fields, not whole-struct equality: JSON's decimal encoding of
        // Date can lose sub-millisecond precision.
        let s = scheduler.review(.new(questionID: "q"), grade: .hard, at: t0)
        let decoded = try JSONDecoder().decode(CardState.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(decoded.questionID, s.questionID)
        XCTAssertEqual(decoded.reps, s.reps)
        XCTAssertEqual(decoded.lapses, s.lapses)
        XCTAssertEqual(decoded.stability, s.stability, accuracy: 1e-9)
        XCTAssertEqual(decoded.difficulty, s.difficulty, accuracy: 1e-9)
        XCTAssertEqual(decoded.due.timeIntervalSince1970, s.due.timeIntervalSince1970, accuracy: 0.001)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd IFRCore && swift test --filter SchedulerTests`
Expected: compile FAILURE — `cannot find type 'Scheduler'`.

- [ ] **Step 3: Implement CardState and Scheduler**

```swift
// IFRCore/Sources/IFRCore/Scheduling/CardState.swift
import Foundation

public enum Grade: Int, Codable, CaseIterable, Sendable {
    case again = 1, hard, good, easy
}

public struct CardState: Codable, Equatable, Sendable {
    public let questionID: String
    public var stability: Double
    public var difficulty: Double
    public var due: Date
    public var lastReview: Date?
    public var reps: Int
    public var lapses: Int

    public static func new(questionID: String) -> CardState {
        CardState(questionID: questionID, stability: 0, difficulty: 0,
                  due: .distantPast, lastReview: nil, reps: 0, lapses: 0)
    }
}
```

```swift
// IFRCore/Sources/IFRCore/Scheduling/Scheduler.swift
// The ONLY file in IFRCore that may import FSRS.
import Foundation
import FSRS

public struct Scheduler: Sendable {
    private let desiredRetention: Double

    public init(desiredRetention: Double = 0.9) {
        self.desiredRetention = desiredRetention
    }

    public func review(_ state: CardState, grade: Grade, at date: Date) -> CardState {
        let fsrs = FSRS(parameters: .init())
        var card = Card()
        if state.reps > 0 {
            card.stability = state.stability
            card.difficulty = state.difficulty
            card.due = state.due
            card.lastReview = state.lastReview
            card.reps = state.reps
            card.lapses = state.lapses
            card.state = .review
        }
        let rating: Rating = switch grade {
        case .again: .again
        case .hard: .hard
        case .good: .good
        case .easy: .easy
        }
        // next() is documented as throwing only on malformed parameters, which
        // ours never are; a throw here is a programmer error.
        let next = try! fsrs.next(card: card, now: date, grade: rating).card
        return CardState(questionID: state.questionID,
                         stability: next.stability,
                         difficulty: next.difficulty,
                         due: next.due,
                         lastReview: date,
                         reps: state.reps + 1,
                         lapses: state.lapses + (grade == .again && state.reps > 0 ? 1 : 0))
    }

    /// Predicted probability of recall at `date`. Unseen cards score 0.
    public func retrievability(of state: CardState, at date: Date) -> Double {
        guard state.reps > 0, let last = state.lastReview, state.stability > 0 else { return 0 }
        let elapsedDays = max(0, date.timeIntervalSince(last) / 86_400)
        let factor = 19.0 / 81.0
        return pow(1 + factor * elapsedDays / state.stability, -0.5)
    }
}
```

**Note:** if the pinned swift-fsrs version spells `Card`/`Rating`/`next` differently (e.g. `grade:` label or a `Card` initializer with arguments), adapt this file until the tests pass — change nothing outside `Scheduler.swift`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd IFRCore && swift test --filter SchedulerTests`
Expected: 6 tests pass.

- [ ] **Step 5: Commit**

```bash
git add IFRCore && git commit -m "feat: FSRS scheduler adapter with CardState"
```

---

### Task 4: Study queue (due cards + new-card trickle)

**Files:**
- Create: `IFRCore/Sources/IFRCore/Scheduling/StudyQueue.swift`
- Test: `IFRCore/Tests/IFRCoreTests/StudyQueueTests.swift`

**Interfaces:**
- Consumes: `QuestionBank`, `Question`, `Category`, `CardState` from Tasks 1–3.
- Produces:
  - `StudySettings`: `newCardsPerDay: Int` (default 20), `unlockedCategories: Set<Category>` (default all), `dailyGoalCards: Int` (default 10).
  - `StudyQueue.session(bank:states:settings:newIntroducedToday:now:) -> [Question]`.

- [ ] **Step 1: Write the failing tests**

```swift
// IFRCore/Tests/IFRCoreTests/StudyQueueTests.swift
import XCTest
@testable import IFRCore

final class StudyQueueTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func question(_ id: String, _ category: Category) -> Question {
        Question(id: id, category: category, acsCodes: ["IR.I.A.K1"], format: .flashcard,
                 front: "f", back: "b", options: nil, correctIndex: nil, explanation: "e",
                 source: SourceRef(document: "d", section: "s", url: URL(string: "https://faa.gov")!),
                 figure: nil, difficulty: 1)
    }

    private func dueState(_ id: String, dueOffset: TimeInterval) -> CardState {
        var s = CardState.new(questionID: id)
        s.reps = 1
        s.due = now.addingTimeInterval(dueOffset)
        return s
    }

    func testDueCardsComeBeforeNewCards() {
        let bank = QuestionBank(version: 1, questions: [question("a", .weather), question("b", .weather)])
        let states = ["a": dueState("a", dueOffset: -60)]
        let session = StudyQueue.session(bank: bank, states: states,
                                         settings: StudySettings(), newIntroducedToday: 0, now: now)
        XCTAssertEqual(session.map(\.id), ["a", "b"])
    }

    func testFutureDueCardsExcluded() {
        let bank = QuestionBank(version: 1, questions: [question("a", .weather)])
        let states = ["a": dueState("a", dueOffset: 86_400)]
        let session = StudyQueue.session(bank: bank, states: states,
                                         settings: StudySettings(), newIntroducedToday: 0, now: now)
        XCTAssertTrue(session.isEmpty)
    }

    func testNewCardCapRespectsAlreadyIntroduced() {
        let bank = QuestionBank(version: 1, questions: (0..<30).map { question("q\($0)", .weather) })
        var settings = StudySettings()
        settings.newCardsPerDay = 20
        let session = StudyQueue.session(bank: bank, states: [:], settings: settings,
                                         newIntroducedToday: 15, now: now)
        XCTAssertEqual(session.count, 5)
    }

    func testLockedCategoriesYieldNoNewCards() {
        let bank = QuestionBank(version: 1, questions: [question("a", .weather), question("b", .approaches)])
        var settings = StudySettings()
        settings.unlockedCategories = [.approaches]
        let session = StudyQueue.session(bank: bank, states: [:], settings: settings,
                                         newIntroducedToday: 0, now: now)
        XCTAssertEqual(session.map(\.id), ["b"])
    }

    func testDueCardsInterleaveAcrossCategories() {
        let bank = QuestionBank(version: 1, questions: [
            question("w1", .weather), question("w2", .weather),
            question("r1", .regulations), question("r2", .regulations),
        ])
        let states = [
            "w1": dueState("w1", dueOffset: -400), "w2": dueState("w2", dueOffset: -300),
            "r1": dueState("r1", dueOffset: -200), "r2": dueState("r2", dueOffset: -100),
        ]
        let session = StudyQueue.session(bank: bank, states: states,
                                         settings: StudySettings(), newIntroducedToday: 0, now: now)
        let categories = session.map(\.category)
        XCTAssertNotEqual(categories[0], categories[1], "adjacent due cards alternate category")
        XCTAssertNotEqual(categories[2], categories[3])
    }

    func testNewCardsPrioritizedByExamWeight() {
        let bank = QuestionBank(version: 1, questions: [question("h", .humanFactors), question("r", .regulations)])
        var settings = StudySettings()
        settings.newCardsPerDay = 1
        let session = StudyQueue.session(bank: bank, states: [:], settings: settings,
                                         newIntroducedToday: 0, now: now)
        XCTAssertEqual(session.map(\.id), ["r"], "regulations (weight 12) beats human factors (weight 2)")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd IFRCore && swift test --filter StudyQueueTests`
Expected: compile FAILURE — `cannot find 'StudyQueue'`.

- [ ] **Step 3: Implement StudyQueue**

```swift
// IFRCore/Sources/IFRCore/Scheduling/StudyQueue.swift
import Foundation

public struct StudySettings: Codable, Equatable, Sendable {
    public var newCardsPerDay: Int
    public var unlockedCategories: Set<Category>
    public var dailyGoalCards: Int

    public init(newCardsPerDay: Int = 20,
                unlockedCategories: Set<Category> = Set(Category.allCases),
                dailyGoalCards: Int = 10) {
        self.newCardsPerDay = newCardsPerDay
        self.unlockedCategories = unlockedCategories
        self.dailyGoalCards = dailyGoalCards
    }
}

public enum StudyQueue {
    /// Builds today's session: due cards (round-robin interleaved across
    /// categories, oldest-due first within each), then new cards up to the
    /// remaining daily allowance, highest examWeight category first.
    public static func session(
        bank: QuestionBank,
        states: [String: CardState],
        settings: StudySettings,
        newIntroducedToday: Int,
        now: Date
    ) -> [Question] {
        let byID = Dictionary(uniqueKeysWithValues: bank.questions.map { ($0.id, $0) })

        let dueStates = states.values
            .filter { $0.reps > 0 && $0.due <= now && byID[$0.questionID] != nil }
            .sorted { $0.due < $1.due }
        var buckets: [Category: [Question]] = [:]
        for state in dueStates {
            let q = byID[state.questionID]!
            buckets[q.category, default: []].append(q)
        }
        var due: [Question] = []
        var order = buckets.keys.sorted { $0.rawValue < $1.rawValue }
        while !order.isEmpty {
            for category in order {
                if let next = buckets[category]?.first {
                    due.append(next)
                    buckets[category]?.removeFirst()
                }
            }
            order = order.filter { !(buckets[$0] ?? []).isEmpty }
        }

        let allowance = max(0, settings.newCardsPerDay - newIntroducedToday)
        let fresh = bank.questions
            .filter { states[$0.id] == nil && settings.unlockedCategories.contains($0.category) }
            .sorted {
                if $0.category.examWeight != $1.category.examWeight {
                    return $0.category.examWeight > $1.category.examWeight
                }
                return $0.id < $1.id
            }
            .prefix(allowance)

        return due + Array(fresh)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd IFRCore && swift test --filter StudyQueueTests`
Expected: 6 tests pass.

- [ ] **Step 5: Commit**

```bash
git add IFRCore && git commit -m "feat: study queue with interleaved due cards and new-card trickle"
```

---

### Task 5: XP engine

**Files:**
- Create: `IFRCore/Sources/IFRCore/Gamification/XPEngine.swift`
- Test: `IFRCore/Tests/IFRCoreTests/XPEngineTests.swift`

**Interfaces:**
- Consumes: `Grade` from Task 3.
- Produces: `XPEvent` enum and `XPEngine.points(for:) -> Int`. The app plan's `StudyStore` calls this for every answer.

- [ ] **Step 1: Write the failing tests**

```swift
// IFRCore/Tests/IFRCoreTests/XPEngineTests.swift
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
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd IFRCore && swift test --filter XPEngineTests`
Expected: compile FAILURE.

- [ ] **Step 3: Implement XPEngine**

```swift
// IFRCore/Sources/IFRCore/Gamification/XPEngine.swift
public enum XPEvent: Equatable, Sendable {
    case flashcardReview(grade: Grade, difficulty: Int)
    case reviewMC(correct: Bool, difficulty: Int)
    case quizAnswer(correct: Bool, difficulty: Int)
    case mockExamCompleted(passed: Bool)
    case dailyGoalMet
}

public enum XPEngine: Sendable {
    /// +5 bonus applies only to correct answers on difficulty-3 questions.
    public static func points(for event: XPEvent) -> Int {
        switch event {
        case .flashcardReview(let grade, let difficulty):
            grade == .again ? 2 : 10 + bonus(correct: true, difficulty: difficulty)
        case .reviewMC(let correct, let difficulty):
            correct ? 12 + bonus(correct: true, difficulty: difficulty) : 3
        case .quizAnswer(let correct, let difficulty):
            correct ? 15 + bonus(correct: true, difficulty: difficulty) : 3
        case .mockExamCompleted(let passed):
            passed ? 100 : 40
        case .dailyGoalMet:
            50
        }
    }

    private static func bonus(correct: Bool, difficulty: Int) -> Int {
        correct && difficulty == 3 ? 5 : 0
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd IFRCore && swift test --filter XPEngineTests`
Expected: 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add IFRCore && git commit -m "feat: XP engine with fixed point values"
```

---

### Task 6: Streak engine

**Files:**
- Create: `IFRCore/Sources/IFRCore/Gamification/StreakEngine.swift`
- Test: `IFRCore/Tests/IFRCoreTests/StreakEngineTests.swift`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `StreakState` (`current`, `longest`, `freezes`, `lastGoalDate: Date?`, `daysTowardFreeze`) and `StreakEngine` (`init(calendar: Calendar)`, `recordGoalMet(on:state:) -> StreakState`, `displayStreak(asOf:state:) -> Int`).

**Rules being implemented (copy into the file's doc comment):** a goal-met day extends the streak if it's the next calendar day; repeat calls same day are no-ops; missing N days consumes min(N, freezes) freezes — if freezes cover every missed day the streak survives, otherwise it resets to 1 on the new goal day; every 7 consecutive goal days earns 1 freeze, banked to a max of 2; `longest` never decreases; `displayStreak` shows 0 if the streak is already broken beyond freeze coverage as of "now".

- [ ] **Step 1: Write the failing tests**

```swift
// IFRCore/Tests/IFRCoreTests/StreakEngineTests.swift
import XCTest
@testable import IFRCore

final class StreakEngineTests: XCTestCase {
    var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }()
    lazy var engine = StreakEngine(calendar: calendar)

    private func day(_ n: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: n, hour: hour))!
    }

    func testFirstGoalStartsStreakAtOne() {
        let s = engine.recordGoalMet(on: day(1), state: StreakState())
        XCTAssertEqual(s.current, 1)
        XCTAssertEqual(s.longest, 1)
    }

    func testConsecutiveDaysExtend() {
        var s = engine.recordGoalMet(on: day(1), state: StreakState())
        s = engine.recordGoalMet(on: day(2), state: s)
        XCTAssertEqual(s.current, 2)
    }

    func testSameDayTwiceIsNoOp() {
        var s = engine.recordGoalMet(on: day(1, hour: 8), state: StreakState())
        s = engine.recordGoalMet(on: day(1, hour: 22), state: s)
        XCTAssertEqual(s.current, 1)
    }

    func testMissedDayWithoutFreezeResets() {
        var s = engine.recordGoalMet(on: day(1), state: StreakState())
        s = engine.recordGoalMet(on: day(3), state: s)
        XCTAssertEqual(s.current, 1)
        XCTAssertEqual(s.longest, 1)
    }

    func testFreezeCoversOneMissedDay() {
        var s = StreakState()
        s.freezes = 1
        s = engine.recordGoalMet(on: day(1), state: s)
        s = engine.recordGoalMet(on: day(3), state: s)
        XCTAssertEqual(s.current, 2)
        XCTAssertEqual(s.freezes, 0)
    }

    func testTwoMissedDaysWithOneFreezeResets() {
        var s = StreakState()
        s.freezes = 1
        s = engine.recordGoalMet(on: day(1), state: s)
        s = engine.recordGoalMet(on: day(4), state: s)
        XCTAssertEqual(s.current, 1)
        XCTAssertEqual(s.freezes, 0, "freeze is still consumed by the attempt")
    }

    func testSevenDayStreakEarnsFreezeCappedAtTwo() {
        var s = StreakState()
        for d in 1...21 { s = engine.recordGoalMet(on: day(d), state: s) }
        XCTAssertEqual(s.current, 21)
        XCTAssertEqual(s.freezes, 2, "earned 3, capped at 2")
    }

    func testLongestSurvivesReset() {
        var s = StreakState()
        for d in 1...5 { s = engine.recordGoalMet(on: day(d), state: s) }
        s = engine.recordGoalMet(on: day(10), state: s)
        XCTAssertEqual(s.longest, 5)
        XCTAssertEqual(s.current, 1)
    }

    func testMidnightBoundaryInTimezone() {
        var s = engine.recordGoalMet(on: day(1, hour: 23), state: StreakState())
        s = engine.recordGoalMet(on: day(2, hour: 0), state: s)
        XCTAssertEqual(s.current, 2, "23:59 and 00:01 local are different days")
    }

    func testDisplayStreakZeroWhenBrokenBeyondFreezes() {
        var s = engine.recordGoalMet(on: day(1), state: StreakState())
        XCTAssertEqual(engine.displayStreak(asOf: day(2), state: s), 1, "still recoverable today")
        XCTAssertEqual(engine.displayStreak(asOf: day(4), state: s), 0, "2 days missed, 0 freezes")
        s.freezes = 2
        XCTAssertEqual(engine.displayStreak(asOf: day(4), state: s), 1, "freezes keep it alive")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd IFRCore && swift test --filter StreakEngineTests`
Expected: compile FAILURE.

- [ ] **Step 3: Implement StreakEngine**

```swift
// IFRCore/Sources/IFRCore/Gamification/StreakEngine.swift
import Foundation

public struct StreakState: Codable, Equatable, Sendable {
    public var current: Int
    public var longest: Int
    public var freezes: Int
    public var lastGoalDate: Date?
    public var daysTowardFreeze: Int

    public init(current: Int = 0, longest: Int = 0, freezes: Int = 0,
                lastGoalDate: Date? = nil, daysTowardFreeze: Int = 0) {
        self.current = current
        self.longest = longest
        self.freezes = freezes
        self.lastGoalDate = lastGoalDate
        self.daysTowardFreeze = daysTowardFreeze
    }
}

public struct StreakEngine: Sendable {
    private let calendar: Calendar

    public init(calendar: Calendar) {
        self.calendar = calendar
    }

    public func recordGoalMet(on date: Date, state: StreakState) -> StreakState {
        var s = state
        let today = calendar.startOfDay(for: date)

        guard let last = s.lastGoalDate.map({ calendar.startOfDay(for: $0) }) else {
            s.current = 1
            s.daysTowardFreeze = 1
            s.longest = max(s.longest, 1)
            s.lastGoalDate = today
            return earnFreezeIfDue(s)
        }

        let gap = calendar.dateComponents([.day], from: last, to: today).day ?? 0
        if gap == 0 { return s }

        let missed = gap - 1
        let spent = min(missed, s.freezes)
        s.freezes -= spent
        if spent == missed {
            s.current += 1
            s.daysTowardFreeze += 1
        } else {
            s.current = 1
            s.daysTowardFreeze = 1
        }
        s.longest = max(s.longest, s.current)
        s.lastGoalDate = today
        return earnFreezeIfDue(s)
    }

    /// Streak to show in UI: the stored streak if it's still alive (today's
    /// goal can still extend it, counting available freezes), else 0.
    public func displayStreak(asOf date: Date, state: StreakState) -> Int {
        guard let last = state.lastGoalDate.map({ calendar.startOfDay(for: $0) }) else { return 0 }
        let today = calendar.startOfDay(for: date)
        let gap = calendar.dateComponents([.day], from: last, to: today).day ?? 0
        let missedIfMetToday = max(0, gap - 1)
        return missedIfMetToday <= state.freezes ? state.current : 0
    }

    private func earnFreezeIfDue(_ state: StreakState) -> StreakState {
        var s = state
        if s.daysTowardFreeze >= 7 {
            s.freezes = min(2, s.freezes + 1)
            s.daysTowardFreeze = 0
        }
        return s
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd IFRCore && swift test --filter StreakEngineTests`
Expected: 10 tests pass.

- [ ] **Step 5: Commit**

```bash
git add IFRCore && git commit -m "feat: streak engine with freezes and timezone-aware day boundaries"
```

---

### Task 7: Mastery & readiness calculator

**Files:**
- Create: `IFRCore/Sources/IFRCore/Progress/MasteryCalculator.swift`
- Test: `IFRCore/Tests/IFRCoreTests/MasteryTests.swift`

**Interfaces:**
- Consumes: `Scheduler.retrievability(of:at:)` (Task 3), `QuestionBank` (Task 2), `Category` (Task 1).
- Produces: `MasteryLevel` (5 cases, `static func level(forRetention:)`, thresholds 0.2/0.4/0.6/0.8) and `MasteryCalculator` (`categoryRetention(_:bank:states:at:)`, `readiness(bank:states:at:)`). Unseen cards count as retention 0 — mastery reflects the whole category, not just started cards.

- [ ] **Step 1: Write the failing tests**

```swift
// IFRCore/Tests/IFRCoreTests/MasteryTests.swift
import XCTest
@testable import IFRCore

final class MasteryTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let scheduler = Scheduler()
    lazy var calc = MasteryCalculator(scheduler: scheduler)

    private func question(_ id: String, _ category: Category) -> Question {
        Question(id: id, category: category, acsCodes: ["IR.I.A.K1"], format: .flashcard,
                 front: "f", back: "b", options: nil, correctIndex: nil, explanation: "e",
                 source: SourceRef(document: "d", section: "s", url: URL(string: "https://faa.gov")!),
                 figure: nil, difficulty: 1)
    }

    func testLevelThresholds() {
        XCTAssertEqual(MasteryLevel.level(forRetention: 0.0), .novice)
        XCTAssertEqual(MasteryLevel.level(forRetention: 0.19), .novice)
        XCTAssertEqual(MasteryLevel.level(forRetention: 0.2), .apprentice)
        XCTAssertEqual(MasteryLevel.level(forRetention: 0.45), .competent)
        XCTAssertEqual(MasteryLevel.level(forRetention: 0.65), .proficient)
        XCTAssertEqual(MasteryLevel.level(forRetention: 0.95), .instrumentMaster)
    }

    func testUnseenCategoryIsZero() {
        let bank = QuestionBank(version: 1, questions: [question("a", .weather)])
        XCTAssertEqual(calc.categoryRetention(.weather, bank: bank, states: [:], at: now), 0)
    }

    func testFreshlyReviewedCardScoresNearOne() {
        let bank = QuestionBank(version: 1, questions: [question("a", .weather)])
        let states = ["a": scheduler.review(.new(questionID: "a"), grade: .good, at: now)]
        let r = calc.categoryRetention(.weather, bank: bank, states: states, at: now.addingTimeInterval(60))
        XCTAssertGreaterThan(r, 0.95)
    }

    func testHalfSeenCategoryAveragesUnseenAsZero() {
        let bank = QuestionBank(version: 1, questions: [question("a", .weather), question("b", .weather)])
        let states = ["a": scheduler.review(.new(questionID: "a"), grade: .good, at: now)]
        let r = calc.categoryRetention(.weather, bank: bank, states: states, at: now.addingTimeInterval(60))
        XCTAssertEqual(r, 0.5, accuracy: 0.05)
    }

    func testReadinessAveragesAcrossWholeBank() {
        let bank = QuestionBank(version: 1, questions: [question("a", .weather), question("b", .regulations)])
        let states = [
            "a": scheduler.review(.new(questionID: "a"), grade: .good, at: now),
            "b": scheduler.review(.new(questionID: "b"), grade: .good, at: now),
        ]
        let r = calc.readiness(bank: bank, states: states, at: now.addingTimeInterval(60))
        XCTAssertGreaterThan(r, 0.95)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd IFRCore && swift test --filter MasteryTests`
Expected: compile FAILURE.

- [ ] **Step 3: Implement MasteryCalculator**

```swift
// IFRCore/Sources/IFRCore/Progress/MasteryCalculator.swift
import Foundation

public enum MasteryLevel: Int, CaseIterable, Sendable {
    case novice = 1, apprentice, competent, proficient, instrumentMaster

    public var displayName: String {
        switch self {
        case .novice: "Novice"
        case .apprentice: "Apprentice"
        case .competent: "Competent"
        case .proficient: "Proficient"
        case .instrumentMaster: "Instrument Master"
        }
    }

    public static func level(forRetention r: Double) -> MasteryLevel {
        switch r {
        case ..<0.2: .novice
        case ..<0.4: .apprentice
        case ..<0.6: .competent
        case ..<0.8: .proficient
        default: .instrumentMaster
        }
    }
}

public struct MasteryCalculator: Sendable {
    private let scheduler: Scheduler

    public init(scheduler: Scheduler) {
        self.scheduler = scheduler
    }

    /// Mean predicted recall over ALL cards in the category; unseen cards
    /// contribute 0, so mastery reflects true coverage of the material.
    public func categoryRetention(_ category: Category, bank: QuestionBank,
                                  states: [String: CardState], at date: Date) -> Double {
        mean(retention(of: bank.questions(in: category), states: states, at: date))
    }

    /// Predicted mean recall across the whole bank at `date` (e.g. exam day).
    public func readiness(bank: QuestionBank, states: [String: CardState], at date: Date) -> Double {
        mean(retention(of: bank.questions, states: states, at: date))
    }

    private func retention(of questions: [Question], states: [String: CardState], at date: Date) -> [Double] {
        questions.map { q in
            states[q.id].map { scheduler.retrievability(of: $0, at: date) } ?? 0
        }
    }

    private func mean(_ values: [Double]) -> Double {
        values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd IFRCore && swift test --filter MasteryTests`
Expected: 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add IFRCore && git commit -m "feat: mastery levels and exam readiness from predicted retention"
```

---

### Task 8: Quiz engine (weighted selection + mock exam + scoring)

**Files:**
- Create: `IFRCore/Sources/IFRCore/Quiz/QuizEngine.swift`
- Test: `IFRCore/Tests/IFRCoreTests/QuizEngineTests.swift`

**Interfaces:**
- Consumes: `Scheduler` (Task 3), `QuestionBank`/`Question`/`Category` (Tasks 1–2).
- Produces:
  - `QuizConfig`: `category: Category?` (nil = all), `length: Int`, `isMockExam: Bool`; `static let mockExam = QuizConfig(category: nil, length: 60, isMockExam: true)`.
  - `QuizScore`: `correct: Int`, `total: Int`, `percent: Int`, `passed: Bool` (≥ 70).
  - `QuizEngine`: `makeQuiz(config:bank:states:now:using:) -> [Question]` (RNG injected `inout`), `static func score(results: [Bool]) -> QuizScore`.
  - `SeededRNG`: deterministic `RandomNumberGenerator` (also used by app for reproducibility in tests).

- [ ] **Step 1: Write the failing tests**

```swift
// IFRCore/Tests/IFRCoreTests/QuizEngineTests.swift
import XCTest
@testable import IFRCore

final class QuizEngineTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let scheduler = Scheduler()
    lazy var engine = QuizEngine(scheduler: scheduler)

    private func mcQuestion(_ id: String, _ category: Category) -> Question {
        Question(id: id, category: category, acsCodes: ["IR.I.A.K1"], format: .multipleChoice,
                 front: "f", back: "b", options: ["a", "b", "c"], correctIndex: 0, explanation: "e",
                 source: SourceRef(document: "d", section: "s", url: URL(string: "https://faa.gov")!),
                 figure: nil, difficulty: 1)
    }

    private func fullBank(perCategory: Int) -> QuestionBank {
        var questions: [Question] = []
        for category in Category.allCases {
            for i in 0..<perCategory {
                questions.append(mcQuestion("\(category.rawValue)-\(i)", category))
            }
        }
        return QuestionBank(version: 1, questions: questions)
    }

    func testQuizRespectsCategoryAndLength() {
        var rng = SeededRNG(seed: 7)
        let quiz = engine.makeQuiz(config: QuizConfig(category: .weather, length: 10, isMockExam: false),
                                   bank: fullBank(perCategory: 15), states: [:], now: now, using: &rng)
        XCTAssertEqual(quiz.count, 10)
        XCTAssertTrue(quiz.allSatisfy { $0.category == .weather })
        XCTAssertEqual(Set(quiz.map(\.id)).count, 10, "no repeats")
    }

    func testFlashcardOnlyQuestionsExcluded() {
        var flashcard = mcQuestion("fc", .weather)
        flashcard = Question(id: "fc", category: .weather, acsCodes: ["IR.I.B.K1"], format: .flashcard,
                             front: "f", back: "b", options: nil, correctIndex: nil, explanation: "e",
                             source: flashcard.source, figure: nil, difficulty: 1)
        let bank = QuestionBank(version: 1, questions: [flashcard, mcQuestion("mc", .weather)])
        var rng = SeededRNG(seed: 7)
        let quiz = engine.makeQuiz(config: QuizConfig(category: .weather, length: 5, isMockExam: false),
                                   bank: bank, states: [:], now: now, using: &rng)
        XCTAssertEqual(quiz.map(\.id), ["mc"])
    }

    func testMockExamMatchesBlueprint() {
        var rng = SeededRNG(seed: 7)
        let quiz = engine.makeQuiz(config: .mockExam, bank: fullBank(perCategory: 15),
                                   states: [:], now: now, using: &rng)
        XCTAssertEqual(quiz.count, 60)
        for category in Category.allCases {
            XCTAssertEqual(quiz.filter { $0.category == category }.count, category.examWeight,
                           "\(category) count matches examWeight")
        }
    }

    func testWeakAreaWeighting() {
        // 2 weather questions: one just reviewed (strong), one unseen (weak).
        // Over many 1-question quizzes, the weak one must be picked more often.
        let bank = QuestionBank(version: 1, questions: [mcQuestion("strong", .weather), mcQuestion("weak", .weather)])
        let states = ["strong": scheduler.review(.new(questionID: "strong"), grade: .good, at: now)]
        var weakPicks = 0
        var rng = SeededRNG(seed: 42)
        for _ in 0..<200 {
            let quiz = engine.makeQuiz(config: QuizConfig(category: .weather, length: 1, isMockExam: false),
                                       bank: bank, states: states, now: now, using: &rng)
            if quiz.first?.id == "weak" { weakPicks += 1 }
        }
        XCTAssertGreaterThan(weakPicks, 120, "weak card (weight ~1.25) beats strong card (~0.25)")
    }

    func testScoring() {
        let pass = QuizEngine.score(results: Array(repeating: true, count: 42) + Array(repeating: false, count: 18))
        XCTAssertEqual(pass.percent, 70)
        XCTAssertTrue(pass.passed)
        let fail = QuizEngine.score(results: Array(repeating: true, count: 41) + Array(repeating: false, count: 19))
        XCTAssertEqual(fail.percent, 68)
        XCTAssertFalse(fail.passed)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd IFRCore && swift test --filter QuizEngineTests`
Expected: compile FAILURE.

- [ ] **Step 3: Implement QuizEngine**

```swift
// IFRCore/Sources/IFRCore/Quiz/QuizEngine.swift
import Foundation

public struct QuizConfig: Equatable, Sendable {
    public var category: Category?
    public var length: Int
    public var isMockExam: Bool

    public init(category: Category?, length: Int, isMockExam: Bool) {
        self.category = category
        self.length = length
        self.isMockExam = isMockExam
    }

    public static let mockExam = QuizConfig(category: nil, length: 60, isMockExam: true)
}

public struct QuizScore: Equatable, Sendable {
    public let correct: Int
    public let total: Int
    public var percent: Int { total == 0 ? 0 : Int((Double(correct) / Double(total) * 100).rounded()) }
    public var passed: Bool { percent >= 70 }
}

/// Deterministic RNG for tests and reproducible shuffles (SplitMix64).
public struct SeededRNG: RandomNumberGenerator, Sendable {
    private var state: UInt64
    public init(seed: UInt64) { state = seed }
    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

public struct QuizEngine: Sendable {
    private let scheduler: Scheduler

    public init(scheduler: Scheduler) {
        self.scheduler = scheduler
    }

    public func makeQuiz(
        config: QuizConfig,
        bank: QuestionBank,
        states: [String: CardState],
        now: Date,
        using rng: inout some RandomNumberGenerator
    ) -> [Question] {
        if config.isMockExam {
            var quiz: [Question] = []
            for category in Category.allCases {
                let pool = bank.questions(in: category).filter(\.isMultipleChoiceCapable)
                quiz += weightedSample(pool, count: category.examWeight, states: states, now: now, using: &rng)
            }
            return quiz.shuffled(using: &rng)
        }
        let pool = bank.questions
            .filter(\.isMultipleChoiceCapable)
            .filter { config.category == nil || $0.category == config.category }
        return weightedSample(pool, count: config.length, states: states, now: now, using: &rng)
    }

    public static func score(results: [Bool]) -> QuizScore {
        QuizScore(correct: results.filter { $0 }.count, total: results.count)
    }

    /// Roulette-wheel sampling without replacement. Weight = 1.25 − predicted
    /// retention, so weak/unseen cards (retention 0 → weight 1.25) are ~5×
    /// likelier than fresh ones (retention ~1 → weight 0.25).
    private func weightedSample(
        _ pool: [Question], count: Int, states: [String: CardState], now: Date,
        using rng: inout some RandomNumberGenerator
    ) -> [Question] {
        var remaining = pool.map { q -> (Question, Double) in
            let r = states[q.id].map { scheduler.retrievability(of: $0, at: now) } ?? 0
            return (q, 1.25 - r)
        }
        var picked: [Question] = []
        while picked.count < count, !remaining.isEmpty {
            let totalWeight = remaining.reduce(0) { $0 + $1.1 }
            var roll = Double.random(in: 0..<totalWeight, using: &rng)
            var index = remaining.count - 1
            for (i, entry) in remaining.enumerated() {
                if roll < entry.1 { index = i; break }
                roll -= entry.1
            }
            picked.append(remaining.remove(at: index).0)
        }
        return picked
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd IFRCore && swift test --filter QuizEngineTests`
Expected: 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add IFRCore && git commit -m "feat: quiz engine with weak-area weighting and mock exam blueprint"
```

---

### Task 9: Badge engine

**Files:**
- Create: `IFRCore/Sources/IFRCore/Gamification/BadgeEngine.swift`
- Test: `IFRCore/Tests/IFRCoreTests/BadgeEngineTests.swift`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `Badge` enum (16 cases with `displayName`/`detail`), `BadgeSnapshot` struct, `BadgeEngine.newlyEarned(snapshot:already:) -> Set<Badge>`. The app calls this after every session/quiz with a current snapshot and the set of already-earned badges.

- [ ] **Step 1: Write the failing tests**

```swift
// IFRCore/Tests/IFRCoreTests/BadgeEngineTests.swift
import XCTest
@testable import IFRCore

final class BadgeEngineTests: XCTestCase {
    private func snapshot(
        totalReviews: Int = 0, streak: Int = 0, lastQuizPerfect: Bool = false,
        mockExamPassed: Bool = false, masteredCategories: Int = 0, hourOfDay: Int = 12,
        totalXP: Int = 0, quizzesCompleted: Int = 0, daysAwayBeforeToday: Int = 0
    ) -> BadgeSnapshot {
        BadgeSnapshot(totalReviews: totalReviews, streak: streak, lastQuizPerfect: lastQuizPerfect,
                      mockExamPassed: mockExamPassed, masteredCategories: masteredCategories,
                      hourOfDay: hourOfDay, totalXP: totalXP, quizzesCompleted: quizzesCompleted,
                      daysAwayBeforeToday: daysAwayBeforeToday)
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
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd IFRCore && swift test --filter BadgeEngineTests`
Expected: compile FAILURE.

- [ ] **Step 3: Implement BadgeEngine**

```swift
// IFRCore/Sources/IFRCore/Gamification/BadgeEngine.swift
import Foundation

public enum Badge: String, Codable, CaseIterable, Sendable {
    case firstSession, streak7, streak30, streak100
    case reviews100, reviews500, reviews1000
    case perfectQuiz, quizzes10, quizzes50, mockExamPassed
    case categoryMastered, allCategoriesMastered
    case xp10k, earlyBird, nightOwl, comeback

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

    public init(totalReviews: Int, streak: Int, lastQuizPerfect: Bool, mockExamPassed: Bool,
                masteredCategories: Int, hourOfDay: Int, totalXP: Int, quizzesCompleted: Int,
                daysAwayBeforeToday: Int) {
        self.totalReviews = totalReviews
        self.streak = streak
        self.lastQuizPerfect = lastQuizPerfect
        self.mockExamPassed = mockExamPassed
        self.masteredCategories = masteredCategories
        self.hourOfDay = hourOfDay
        self.totalXP = totalXP
        self.quizzesCompleted = quizzesCompleted
        self.daysAwayBeforeToday = daysAwayBeforeToday
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
        return earned
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd IFRCore && swift test --filter BadgeEngineTests`
Expected: 6 tests pass.

- [ ] **Step 5: Run the full suite and commit**

Run: `cd IFRCore && swift test`
Expected: all tests across all 9 suites pass.

```bash
git add IFRCore && git commit -m "feat: badge engine — IFRCore complete"
```

---

## Done criteria for this plan

- `cd IFRCore && swift test` passes with ~40 tests across 9 suites.
- No file outside `Scheduler.swift` imports `FSRS`.
- The bundled seed bank loads, validates, and covers all 8 categories.
- Next: the iOS app plan (`2026-07-15-ifr-app.md`) consumes this package; the full 800-question bank is produced later by the content workflow and drops into `bank-v1.json`'s format as `bank-v2.json` with only a resource-name change.
