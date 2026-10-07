import Foundation
import UserNotifications
import PackingCore
import PackingLibrary

/// The door check on this device (0.69 — his choice of idea 4, "c, a time"): 15 minutes
/// before the time he leaves, one notification names what is still unticked; on the
/// last day, what is not in a bag yet. WHAT is said and WHEN is the model's
/// (`Library.doorChecks`); this puts it in the device's list, and puts it right again
/// whenever the library changes — a tick, a new time, a trip deleted or reviewed.
///
/// On the iPhone only: he leaves with his iPhone, and the Mac at home saying the same
/// would be the same news twice (his word on the packing reminders, 2 Oct 2026). It
/// uses the permission "Remind me to pack" asks for (`PackingReminders`), and asks for
/// it itself when he sets a time — never more than the system's one question.
///
/// Under the UI tests nothing reaches the system (no test can see a notification): what
/// WOULD be scheduled is kept in `planned`, which a debug-only list on the trip shows.
@MainActor
final class DoorChecks: ObservableObject {
    static let shared = DoorChecks()
    static let prefix = "door-"

    /// UI tests only: what would be in the device's list now.
    @Published private(set) var planned: [DoorCheck] = []

    /// Where a tapped door check goes: its trip — on just the unticked lines, or (`home`)
    /// at Pack to go home on just what is not in a bag yet.
    var open: ((String, DoorCheck.Kind) -> Void)?

    /// This device's clock in the model's words: "2026-10-07 08:30".
    static func now(_ date: Date = Date()) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: date)
    }

    func reschedule(_ library: Library) async {
        let plan = library.doorChecks(now: Self.now())
        if AMSPackingApp.testing {
            if plan != planned { planned = plan }
            return
        }
        #if os(iOS)
        let center = UNUserNotificationCenter.current()
        let ours = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(Self.prefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional else { return }
        for check in plan {
            let p = check.day.split(separator: "-").compactMap { Int($0) }
            let t = check.time.split(separator: ":").compactMap { Int($0) }
            guard p.count == 3, t.count == 2 else { continue }
            var when = DateComponents()
            when.year = p[0]; when.month = p[1]; when.day = p[2]; when.hour = t[0]; when.minute = t[1]
            let content = UNMutableNotificationContent()
            content.title = check.title
            content.body = check.body
            content.sound = .default
            content.userInfo = ["tripId": check.tripId, "door": check.kind.rawValue]
            let request = UNNotificationRequest(identifier: check.id, content: content,
                                                trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: false))
            try? await center.add(request)
        }
        #endif
    }
}
