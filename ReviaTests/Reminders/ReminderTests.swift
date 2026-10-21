import XCTest
import UserNotifications
@testable import Revia

@MainActor
private final class MockReminderCenter: ReminderScheduling {
    var status = UNAuthorizationStatus.notDetermined
    var allow = true
    var permissionRequests = 0
    var pending: [String: UNNotificationRequest] = [:]
    var failScheduling = false
    func authorization() async -> UNAuthorizationStatus { status }
    func requestPermission() async throws -> Bool {
        permissionRequests += 1
        status = allow ? .authorized : .denied
        return allow
    }
    func schedule(hour: Int, minute: Int, title: String, body: String) async throws {
        if failScheduling { throw NSError(domain: "test", code: 1) }
        let request = LocalReminderCenter.request(hour: hour, minute: minute, title: title, body: body)
        pending[request.identifier] = request
    }
    func remove() { pending.removeValue(forKey: LocalReminderCenter.identifier) }
}

final class ReminderTests: XCTestCase {
    @MainActor
    func testDefaultTimeDoesNotRequestPermissionOrEnableNotifications() async {
        let suite = "ReminderTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let center = MockReminderCenter()
        let reminder = ReminderController(center: center, defaults: defaults)
        await reminder.refresh()
        XCTAssertFalse(reminder.enabled)
        XCTAssertEqual(reminder.hour, 19)
        XCTAssertEqual(reminder.minute, 0)
        XCTAssertEqual(center.permissionRequests, 0)
        XCTAssertTrue(center.pending.isEmpty)
    }
    @MainActor
    func testDailyReminderUsesOneRepeatingRequestAndCanBeChangedOrCancelled() async throws {
        let suite = "ReminderTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let center = MockReminderCenter()
        let reminder = ReminderController(center: center, defaults: defaults)
        await reminder.setEnabled(true)
        XCTAssertTrue(reminder.enabled)
        XCTAssertEqual(center.permissionRequests, 1)
        var trigger = try XCTUnwrap(center.pending.values.first?.trigger as? UNCalendarNotificationTrigger)
        XCTAssertTrue(trigger.repeats)
        XCTAssertEqual(trigger.dateComponents.hour, 19)
        XCTAssertEqual(trigger.dateComponents.minute, 0)
        XCTAssertNil(trigger.dateComponents.year)
        XCTAssertNil(trigger.dateComponents.day)
        XCTAssertNil(trigger.dateComponents.timeZone)
        let newTime = Calendar.current.date(bySettingHour: 20, minute: 35, second: 0, of: Date())!
        await reminder.setTime(newTime)
        await reminder.refresh()
        XCTAssertEqual(center.pending.count, 1)
        trigger = try XCTUnwrap(center.pending.values.first?.trigger as? UNCalendarNotificationTrigger)
        XCTAssertEqual(trigger.dateComponents.hour, 20)
        XCTAssertEqual(trigger.dateComponents.minute, 35)
        let restored = ReminderController(center: center, defaults: defaults)
        XCTAssertTrue(restored.enabled)
        XCTAssertEqual(restored.hour, 20)
        XCTAssertEqual(restored.minute, 35)
        await restored.setEnabled(false)
        XCTAssertTrue(center.pending.isEmpty)
        XCTAssertFalse(defaults.bool(forKey: "reminder.enabled"))
    }
    @MainActor
    func testDeniedPermissionSchedulesNothingAndDoesNotPromptRepeatedly() async {
        let suite = "ReminderTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let center = MockReminderCenter(); center.allow = false
        let reminder = ReminderController(center: center, defaults: defaults)
        await reminder.setEnabled(true)
        await reminder.setEnabled(true)
        XCTAssertFalse(reminder.enabled)
        XCTAssertTrue(reminder.denied)
        XCTAssertNotNil(reminder.message)
        XCTAssertEqual(center.permissionRequests, 1)
        XCTAssertTrue(center.pending.isEmpty)
    }
    @MainActor
    func testRevokedPermissionRemovesExistingReminder() async {
        let suite = "ReminderTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let center = MockReminderCenter()
        let reminder = ReminderController(center: center, defaults: defaults)
        await reminder.setEnabled(true)
        center.status = .denied
        await reminder.refresh()
        XCTAssertFalse(reminder.enabled)
        XCTAssertTrue(reminder.denied)
        XCTAssertTrue(center.pending.isEmpty)
    }
    @MainActor
    func testSchedulingFailureDoesNotSaveTimeOrEnableSwitch() async {
        let suite = "ReminderTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let center = MockReminderCenter(); center.failScheduling = true
        let reminder = ReminderController(center: center, defaults: defaults)
        await reminder.setEnabled(true)
        XCTAssertFalse(reminder.enabled)
        XCTAssertNotNil(reminder.message)
        center.failScheduling = false
        await reminder.setEnabled(true)
        center.failScheduling = true
        await reminder.setTime(Calendar.current.date(bySettingHour: 21, minute: 40, second: 0, of: Date())!)
        XCTAssertEqual(reminder.hour, 19)
        XCTAssertEqual(reminder.minute, 0)
        XCTAssertEqual(center.pending.count, 1)
    }
}
