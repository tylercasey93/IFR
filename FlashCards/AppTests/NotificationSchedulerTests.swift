import XCTest
@testable import IFRFlashCards

final class NotificationSchedulerTests: XCTestCase {
    func testDeepLinkParsing() {
        XCTAssertEqual(NotificationScheduler.handledTab(from: ["tab": "study"]), .study)
        XCTAssertNil(NotificationScheduler.handledTab(from: [:]))
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
}
