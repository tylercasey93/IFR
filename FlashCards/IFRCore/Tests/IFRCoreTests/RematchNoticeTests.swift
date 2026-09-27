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
