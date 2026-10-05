import Foundation
import UserNotifications
import PackingCore
import PackingLibrary

/// Packing reminders on this device — his pre-trip idea 7 (2 Oct 2026). At nine in
/// the morning of the day a packing step falls due: the trip's name, and what is left
/// in each step due that day. Per device and off until he turns it on in Settings —
/// his iPhone and his Mac both reminding him would be the same news twice.
///
/// Under the UI tests nothing is asked of the system: the permission question is the
/// system's own window, and no test can answer it.
@MainActor
final class PackingReminders: NSObject, UNUserNotificationCenterDelegate {
    static let shared = PackingReminders()
    static let onKey = "ams.reminders"
    static let hour = 9
    private static let prefix = "packing-"

    /// Where a tapped reminder goes: the trip it is about.
    var open: ((String) -> Void)?

    static var isOn: Bool { UserDefaults.standard.bool(forKey: onKey) }

    /// UI tests only (`-pretendRemindersBlocked`): switched on here earlier, then
    /// switched off for the app in the device's Settings.
    private static var pretendBlocked: Bool { ProcessInfo.processInfo.arguments.contains("-pretendRemindersBlocked") }

    func start() {
        guard !AMSPackingApp.testing else {
            if Self.pretendBlocked { UserDefaults.standard.set(true, forKey: Self.onKey) }
            return
        }
        UNUserNotificationCenter.current().delegate = self
    }

    /// May reminders be shown on this device NOW? Asks the system, never him: no
    /// question appears. False once they are switched off for the app in the
    /// device's Settings — while the switch here may still say on.
    func allowed() async -> Bool {
        if AMSPackingApp.testing { return !Self.pretendBlocked }
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        return status == .authorized || status == .provisional
    }

    /// Ask once. True when reminders may be shown.
    func askToShow() async -> Bool {
        if AMSPackingApp.testing { return !Self.pretendBlocked }
        let center = UNUserNotificationCenter.current()
        switch await center.notificationSettings().authorizationStatus {
        // (Not .ephemeral: that is the iPhone's App Clips only, and the Mac has no such
        // thing — naming it broke the Mac build, 0.49 on GitHub.)
        case .authorized, .provisional: return true
        case .denied: return false
        default: return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        }
    }

    /// The reminders still to come: today's only while it is not yet nine.
    static func upcoming(_ library: Library, now: Date = Date()) -> [Library.PackingReminder] {
        library.reminderPlan(today: Today.local).filter { r in
            guard let when = moment(r.date) else { return false }
            return when > now
        }
    }

    /// Nine in the morning of a day, on this device's clock.
    static func moment(_ ymd: String) -> Date? {
        guard var parts = day(ymd) else { return nil }
        parts.hour = hour; parts.minute = 0
        return Calendar.current.date(from: parts)
    }

    private static func day(_ ymd: String) -> DateComponents? {
        let p = ymd.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return nil }
        var c = DateComponents()
        c.year = p[0]; c.month = p[1]; c.day = p[2]
        return c
    }

    /// Put the waiting reminders right for this library: every one of ours out,
    /// the plan back in. Called whenever the library settles after a change.
    func reschedule(_ library: Library) async {
        guard !AMSPackingApp.testing else { return }
        let center = UNUserNotificationCenter.current()
        let ours = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(Self.prefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)
        guard Self.isOn else { return }
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional else { return }
        for r in Self.upcoming(library) {
            guard var parts = Self.day(r.date) else { continue }
            parts.hour = Self.hour; parts.minute = 0
            let content = UNMutableNotificationContent()
            content.title = r.tripName
            content.body = r.says
            content.sound = .default
            content.userInfo = ["tripId": r.tripId]
            let request = UNNotificationRequest(identifier: "\(Self.prefix)\(r.tripId)-\(r.date)", content: content,
                                                trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false))
            try? await center.add(request)
        }
    }

    // Shown while the app is open too; a tap opens the trip.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        guard let id = response.notification.request.content.userInfo["tripId"] as? String else { return }
        await MainActor.run { PackingReminders.shared.open?(id) }
    }
}
