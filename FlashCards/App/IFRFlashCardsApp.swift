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
    @State private var gameCenter = GameCenterService()
    @State private var notifications = NotificationScheduler()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        container = try! ModelContainer(for: CardStateRecord.self, ReviewRecord.self,
                                        XPRecord.self, StreakRecord.self,
                                        BadgeRecord.self, SettingsRecord.self)
        store = StudyStore(context: container.mainContext, bank: try! QuestionBank.load())
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
                    notifications.refresh(
                        reminderEnabled: store.settings.reminderEnabled,
                        reminderHour: store.settings.reminderHour,
                        reminderMinute: store.settings.reminderMinute,
                        streakRiskEnabled: store.settings.streakRiskEnabled,
                        // Goal banked earlier today must suppress tonight's warning even
                        // if new cards came due after the goal was already met.
                        goalMetToday: store.goalRecordedToday || store.goalMetToday,
                        streak: store.streakDisplay,
                        dueCount: store.dueCount)
                }
        }
    }
}
