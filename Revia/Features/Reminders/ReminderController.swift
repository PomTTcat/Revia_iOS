import Foundation
import Combine
import UserNotifications

@MainActor
protocol ReminderScheduling {
    func authorization() async -> UNAuthorizationStatus
    func requestPermission() async throws -> Bool
    func schedule(hour: Int, minute: Int, title: String, body: String) async throws
    func remove()
}

private final class ReminderDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

@MainActor
final class LocalReminderCenter: ReminderScheduling {
    static let identifier = "revia.daily-review"
    private let center: UNUserNotificationCenter
    private let delegate = ReminderDelegate()
    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        center.delegate = delegate
    }
    func authorization() async -> UNAuthorizationStatus { await center.notificationSettings().authorizationStatus }
    func requestPermission() async throws -> Bool { try await center.requestAuthorization(options: [.alert, .sound]) }
    static func request(hour: Int, minute: Int, title: String, body: String) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title; content.body = body; content.sound = .default
        // Match the local wall clock every day, without pinning a time zone or calendar date.
        let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: hour, minute: minute), repeats: true)
        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }
    func schedule(hour: Int, minute: Int, title: String, body: String) async throws {
        // Reusing one identifier replaces the old schedule instead of accumulating reminders.
        try await center.add(Self.request(hour: hour, minute: minute, title: title, body: body))
    }
    func remove() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])
        center.removeDeliveredNotifications(withIdentifiers: [Self.identifier])
    }
}

@MainActor
final class ReminderController: ObservableObject {
    @Published private(set) var enabled: Bool
    @Published private(set) var hour: Int
    @Published private(set) var minute: Int
    @Published private(set) var busy = false
    @Published private(set) var denied = false
    @Published var message: String?
    private let center: ReminderScheduling
    private let defaults: UserDefaults

    init(center: ReminderScheduling? = nil, defaults: UserDefaults = .standard) {
        self.center = center ?? LocalReminderCenter()
        self.defaults = defaults
        enabled = defaults.bool(forKey: "reminder.enabled")
        let storedHour = defaults.object(forKey: "reminder.hour") as? Int ?? 19
        let storedMinute = defaults.object(forKey: "reminder.minute") as? Int ?? 0
        hour = (0...23).contains(storedHour) ? storedHour : 19
        minute = (0...59).contains(storedMinute) ? storedMinute : 0
    }
    var time: Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }
    private func permitted(_ status: UNAuthorizationStatus) -> Bool { status == .authorized || status == .provisional }
    private func schedule(hour: Int, minute: Int) async throws {
        try await center.schedule(hour: hour, minute: minute, title: L("reminder_title"), body: L("reminder_body"))
    }
    func setEnabled(_ value: Bool) async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        if !value {
            center.remove(); enabled = false; defaults.set(false, forKey: "reminder.enabled")
            return
        }
        do {
            var status = await center.authorization()
            if status == .notDetermined {
                _ = try await center.requestPermission()
                status = await center.authorization()
            }
            denied = status == .denied
            guard permitted(status) else {
                center.remove(); enabled = false; defaults.set(false, forKey: "reminder.enabled")
                message = L("reminder_denied")
                return
            }
            try await schedule(hour: hour, minute: minute)
            enabled = true; defaults.set(true, forKey: "reminder.enabled")
        } catch { message = L("reminder_failed", error.localizedDescription) }
    }
    func setTime(_ date: Date) async {
        guard !busy else { return }
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        guard let hour = parts.hour, let minute = parts.minute else { return }
        busy = true
        defer { busy = false }
        do {
            if enabled { try await schedule(hour: hour, minute: minute) }
            self.hour = hour; self.minute = minute
            defaults.set(hour, forKey: "reminder.hour"); defaults.set(minute, forKey: "reminder.minute")
        } catch { message = L("reminder_failed", error.localizedDescription) }
    }
    /// Reconcile permission changes and refresh localized content on launch/return to foreground.
    func refresh() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        let status = await center.authorization()
        denied = status == .denied
        guard enabled else { center.remove(); return }
        guard permitted(status) else {
            center.remove(); enabled = false; defaults.set(false, forKey: "reminder.enabled")
            return
        }
        do { try await schedule(hour: hour, minute: minute) }
        catch { message = L("reminder_failed", error.localizedDescription) }
    }
}
