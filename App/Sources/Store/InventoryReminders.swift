import Foundation
import UserNotifications
import PackingCore
import PackingLibrary

/// Warranty and care reminders on this device (0.120 — his picks of 12 Nov 2026): 30 days before a
/// warranty ends and on the day a thing's care is due, at 9:00. WHAT and WHEN is the model's
/// (`Library.inventoryReminders`); this puts them in the device's list, and puts them right again
/// whenever the library changes. Per device and off until he turns it on on the Inventory tab, as
/// Remind me to pack — his iPhone and his Mac both saying it would be the same news twice. Uses the
/// same permission (`PackingReminders.askToShow`). Under the UI tests nothing reaches the system.
@MainActor
final class InventoryReminders {
    static let shared = InventoryReminders()
    static let onKey = "ams.inventoryReminders"
    static let prefix = "inv-"

    static var isOn: Bool { UserDefaults.standard.bool(forKey: onKey) }

    /// Where a tapped one goes: the Inventory tab (the thing's id is handed along).
    var open: ((String) -> Void)?

    func reschedule(_ library: Library) async {
        guard !AMSPackingApp.testing else { return }
        let center = UNUserNotificationCenter.current()
        let ours = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(Self.prefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)
        guard Self.isOn else { return }
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional else { return }
        let now = Date()
        for r in library.inventoryReminders(today: Today.local) {
            let p = r.day.split(separator: "-").compactMap { Int($0) }
            guard p.count == 3 else { continue }
            var when = DateComponents()
            when.year = p[0]; when.month = p[1]; when.day = p[2]; when.hour = PackingReminders.hour; when.minute = 0
            // Today's only while it is not yet nine.
            if let at = Calendar.current.date(from: when), at <= now { continue }
            let content = UNMutableNotificationContent()
            content.title = r.title
            content.body = r.body
            content.sound = .default
            content.userInfo = ["inventory": r.itemId]
            let request = UNNotificationRequest(identifier: r.id, content: content,
                                                trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: false))
            try? await center.add(request)
        }
    }
}
