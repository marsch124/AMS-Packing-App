import Foundation
import UserNotifications
import PackingCore
import PackingLibrary

/// Take a break's "Back to packing", the messages when a trip moves on, and "Charge tonight"
/// the evening before a trip, on this device (spec 07 part 16, his yeses of 13 and 15 Oct
/// 2026). WHAT is said and WHEN is the model's (`Library.tripMessages`); this puts it in the device's list, and puts it right again
/// whenever the library changes — a tick, a new break, new dates or a new time he leaves, a
/// trip deleted or reviewed — exactly as the door check does (`DoorChecks`).
///
/// On the iPhone only: he packs and travels with his iPhone; the Mac at home saying the same
/// would be the same news twice (his word on the packing reminders, 2 Oct 2026). A break taken
/// on the Mac is kept on the trip, so it is the iPhone that reminds him. It uses the
/// permission the app already asks for (`PackingReminders.askToShow` — the system's one
/// question): asked when he takes a break, when he switches the messages on, or when he
/// first opens a trip at Pack with them on.
///
/// Under the UI tests nothing reaches the system (no test can see a notification): what
/// WOULD be scheduled is kept in `planned`, which a debug-only list on the trip shows
/// (`-showTripMessages`).
@MainActor
final class TripMessages: ObservableObject {
    static let shared = TripMessages()
    /// Every notification of ours starts with one of these: the break's, the moves-on, and
    /// Charge tonight's (0.87).
    static let prefixes = ["break-", "moves-", "charge-"]
    /// Settings → "Messages when a trip moves on", this device's own switch: on until he
    /// turns it off.
    static let onKey = "ams.movesOn"
    static var movesOn: Bool { UserDefaults.standard.object(forKey: onKey) as? Bool ?? true }

    /// UI tests only: what would be in the device's list now.
    @Published private(set) var planned: [TripMessage] = []

    /// Where a tapped message goes: its trip — for "Welcome home", its review; for "Charge
    /// tonight", its To charge.
    var open: ((String, TripMessage.Kind) -> Void)?

    func reschedule(_ library: Library) async {
        let plan = library.tripMessages(now: Today.stamp(Today.now), movesOn: Self.movesOn)
        if AMSPackingApp.testing {
            if plan != planned { planned = plan }
            return
        }
        #if os(iOS)
        let center = UNUserNotificationCenter.current()
        let ours = await center.pendingNotificationRequests().map(\.identifier)
            .filter { id in Self.prefixes.contains { id.hasPrefix($0) } }
        center.removePendingNotificationRequests(withIdentifiers: ours)
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional else { return }
        for message in plan {
            let p = message.day.split(separator: "-").compactMap { Int($0) }
            let t = message.time.split(separator: ":").compactMap { Int($0) }
            guard p.count == 3, t.count == 2 else { continue }
            var when = DateComponents()
            when.year = p[0]; when.month = p[1]; when.day = p[2]; when.hour = t[0]; when.minute = t[1]
            let content = UNMutableNotificationContent()
            content.title = message.title
            content.body = message.body
            content.sound = .default
            content.userInfo = ["tripId": message.tripId, "trip": message.kind.rawValue]
            let request = UNNotificationRequest(identifier: message.id, content: content,
                                                trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: false))
            try? await center.add(request)
        }
        #endif
    }

    /// The system's one question, when a trip at Pack is opened with the messages on and the
    /// iPhone was never asked — the moment a message is first planned. Never on the Mac; never
    /// again once answered (the system asks only once).
    func askOnce(_ library: Library) async {
        #if os(iOS)
        guard Self.movesOn, await PackingReminders.shared.permission() == .notAskedYet else { return }
        _ = await PackingReminders.shared.askToShow()
        await reschedule(library)
        #endif
    }
}
