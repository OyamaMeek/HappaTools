import Foundation
import OSLog
import UserNotifications

final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()
    private let logger = Logger(subsystem: "com.happatools.FinderGitHelper", category: "Notifications")

    override init() {
        super.init()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { [logger] _, error in
            if let error = error { logger.error("Notification authorization: \(error.localizedDescription)") }
        }
    }

    func send(title: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = String(message.prefix(99))
        content.sound = .default
        center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)) { [logger] error in
            if let error = error { logger.error("Notification delivery: \(error.localizedDescription)") }
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
