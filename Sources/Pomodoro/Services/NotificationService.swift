import Foundation
import PomodoroCore
@preconcurrency import UserNotifications

@MainActor
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
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
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }

    func schedule(at date: Date, phase: Phase) async {
        cancel()
        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional else {
            return
        }
        let interval = date.timeIntervalSinceNow
        guard interval > 1 else { return }

        let content = UNMutableNotificationContent()
        switch phase {
        case .focus:
            content.title = "Focus complete"
            content.body = "Ready for a break, whenever you are."
        case .shortBreak, .longBreak:
            content.title = "Break complete"
            content.body = "Start another focus when you’re ready."
        }
        content.sound = nil

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await center.add(request)
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
