import Foundation
import UserNotifications

/// Manages macOS notifications for session lifecycle events.
///
/// Uses `UNUserNotificationCenter` to:
/// - Schedule a notification 5 minutes before a timed session expires
/// - Cancel pending notifications when a session is stopped or extended
///
/// Notification permissions are requested lazily on first schedule attempt.
final class NotificationManager {

    static let shared = NotificationManager()

    // MARK: - Constants

    /// Identifier for the "session expiring soon" notification.
    private let expiryNotificationID = "com.steins.stim.session-expiry"

    /// How many seconds before session end to fire the notification.
    private let warningLeadTime: TimeInterval = 5 * 60  // 5 minutes

    // MARK: - Init

    /// Whether notifications are available (requires a valid bundle identifier).
    private let isAvailable: Bool

    private init() {
        // UNUserNotificationCenter crashes if there's no bundle identifier
        // (e.g. when running via `swift run` without a proper app bundle).
        isAvailable = Bundle.main.bundleIdentifier != nil
    }

    // MARK: - Public API

    /// Request notification authorization if not already granted.
    func requestAuthorization() {
        guard isAvailable else { return }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("[Stim] Notification auth error: \(error.localizedDescription)")
            }
        }
    }

    /// Schedule a notification 5 minutes before the session expires.
    ///
    /// - Parameter endDate: When the session will expire. If the end date is less
    ///   than 5 minutes from now, the notification fires immediately.
    ///   Does nothing if notifications are disabled via `@AppStorage`.
    func scheduleExpiryNotification(for endDate: Date) {
        // Check if expiry notifications are enabled
        let enabled = UserDefaults.standard.object(forKey: "expiryNotificationEnabled") as? Bool ?? true
        guard enabled, isAvailable else { return }

        // Cancel any existing expiry notification first
        cancelExpiryNotification()

        let timeUntilExpiry = endDate.timeIntervalSinceNow
        guard timeUntilExpiry > 0 else { return }

        // Fire 5 minutes before, or immediately if less than 5 min remaining
        let fireInterval = max(timeUntilExpiry - warningLeadTime, 1)

        let content = UNMutableNotificationContent()
        content.title = "Stim"
        content.body = "Your keep-awake session expires in 5 minutes."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: fireInterval,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: expiryNotificationID,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[Stim] Failed to schedule notification: \(error.localizedDescription)")
            }
        }
    }

    /// Cancel any pending session-expiry notification.
    func cancelExpiryNotification() {
        guard isAvailable else { return }
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [expiryNotificationID])
    }

    /// Cancel all pending Stim notifications.
    func cancelAll() {
        guard isAvailable else { return }
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
