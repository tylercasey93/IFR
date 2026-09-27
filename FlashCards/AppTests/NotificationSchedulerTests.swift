import XCTest
import IFRCore
@testable import IFRFlashCards

final class NotificationSchedulerTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let calendar = Calendar(identifier: .gregorian)

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

    func testDeepLinkParsing() {
        XCTAssertEqual(NotificationScheduler.handledTab(from: ["tab": "study"]), .study)
        XCTAssertNil(NotificationScheduler.handledTab(from: [:]))
    }

    func testHandledTabMapsAdventure() {
        XCTAssertEqual(NotificationScheduler.handledTab(from: ["tab": "adventure"]), .adventure)
    }

    func testRequestBuildersProduceExpectedTriggers() {
        let daily = NotificationScheduler.dailyReminderRequest(hour: 18, minute: 30, dueCount: 14)
        let trigger = daily.trigger as! UNCalendarNotificationTrigger
        XCTAssertEqual(trigger.dateComponents.hour, 18)
        XCTAssertEqual(trigger.dateComponents.minute, 30)
        XCTAssertTrue(trigger.repeats)
        XCTAssertTrue(daily.content.body.contains("14"))
        XCTAssertEqual(daily.content.userInfo["tab"] as? String, "study")

        let risk = NotificationScheduler.streakRiskRequest(streak: 12)
        let riskTrigger = risk.trigger as! UNCalendarNotificationTrigger
        XCTAssertEqual(riskTrigger.dateComponents.hour, 20)
        XCTAssertTrue(risk.content.body.contains("12"))
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
}
