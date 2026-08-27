import Foundation
import UserNotifications

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
    @MainActor
    func refresh(reminderEnabled: Bool, reminderHour: Int, reminderMinute: Int,
                 streakRiskEnabled: Bool, goalMetToday: Bool, streak: Int, dueCount: Int,
                 now: Date = .now, calendar: Calendar = .current) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.dailyID, Self.riskID])
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
        default: nil
        }
    }
}
