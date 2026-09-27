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
