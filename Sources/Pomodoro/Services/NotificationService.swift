import Foundation
import PomodoroCore
@preconcurrency import UserNotifications

/// The notification effects the timer needs. `NotificationService` is the
/// production implementation; `NotificationReconciler` and tests depend only on
/// this seam.
@MainActor
protocol NotificationScheduling: AnyObject {
    func requestAuthorization() async -> Bool

    func authorizationStatus() async -> UNAuthorizationStatus

    /// Schedules the interval-end notification.
    ///
    /// `shouldInstall` is evaluated after the notification-settings read and
    /// immediately before the request is added, so a request superseded during
    /// an earlier suspension point never installs a notification. Returns
    /// whether a request was added.
    @discardableResult
    func schedule(
        at date: Date,
        phase: Phase,
        ifCurrent shouldInstall: @escaping @MainActor () -> Bool
    ) async -> Bool

    func cancel()
}

extension NotificationScheduling {
    /// Schedules without a freshness check. Callers that can be invalidated by
    /// a newer request must use the `ifCurrent` variant.
    func schedule(at date: Date, phase: Phase) async {
        _ = await schedule(at: date, phase: phase, ifCurrent: { true })
    }
}

@MainActor
final class NotificationService: NSObject, UNUserNotificationCenterDelegate, NotificationScheduling {
    private let center = UNUserNotificationCenter.current()
    private let identifier = "pomodoro.interval-end"

    override init() {
        super.init()
        center.delegate = self
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert])
        } catch {
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }

    func schedule(at date: Date, phase: Phase) async {
        _ = await schedule(at: date, phase: phase, ifCurrent: { true })
    }

    @discardableResult
    func schedule(
        at date: Date,
        phase: Phase,
        ifCurrent shouldInstall: @escaping @MainActor () -> Bool
    ) async -> Bool {
        cancel()
        let settings = await center.notificationSettings()
        guard shouldInstall() else { return false }
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            return false
        }
        let interval = date.timeIntervalSinceNow
        guard interval > 1 else { return false }

        let content = UNMutableNotificationContent()
        switch phase {
        case .focus:
            content.title = L10n.string("notifications.focus.title")
            content.body = L10n.string("notifications.focus.body")
        case .shortBreak, .longBreak:
            content.title = L10n.string("notifications.break.title")
            content.body = L10n.string("notifications.break.body")
        }
        content.sound = nil

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        do {
            try await center.add(request)
            return true
        } catch {
            return false
        }
    }

    func cancel() {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([])
    }
}
