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
