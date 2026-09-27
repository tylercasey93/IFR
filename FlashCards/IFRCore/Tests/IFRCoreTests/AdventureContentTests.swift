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
