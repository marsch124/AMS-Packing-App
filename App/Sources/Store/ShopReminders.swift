import Foundation
import EventKit
import PackingCore
import PackingLibrary

/// To buy → Apple Reminders — his pre-trip idea 9 (2 Oct 2026). The open buy lines go
/// to a Reminders list of their own, to take to the shop; a reminder ticked there ticks
/// its line here the next time the buy list is opened.
///
/// A reminder is remembered by its EXTERNAL identifier — the one that is the same on
/// his iPhone and his Mac — so a line sent from one device is read back on either.
///
/// Under the UI tests nothing is asked of the system (its permission question is a
/// window no test can answer): a pretend Reminders in memory stands in.
@MainActor
final class ShopReminders {
    static let shared = ShopReminders()
    static let listName = "To buy \u{00B7} Packing"
    private let store = EKEventStore()
    private var pretend: [String: Bool] = [:]

    /// May the app read his reminders without asking?
    var mayRead: Bool {
        if AMSPackingApp.testing { return true }
        return EKEventStore.authorizationStatus(for: .reminder) == .fullAccess
    }

    /// Ask once. True when the app may write to Reminders.
    func askAccess() async -> Bool {
        if AMSPackingApp.testing { return true }
        if mayRead { return true }
        return (try? await store.requestFullAccessToReminders()) ?? false
    }

    /// The list the buy lines go to — made the first time.
    private func list() throws -> EKCalendar {
        if let found = store.calendars(for: .reminder).first(where: { $0.title == Self.listName }) { return found }
        let made = EKCalendar(for: .reminder, eventStore: store)
        made.title = Self.listName
        guard let source = store.defaultCalendarForNewReminders()?.source ?? store.sources.first(where: { $0.sourceType == .local })
        else { throw CocoaError(.featureUnsupported) }
        made.source = source
        try store.saveCalendar(made, commit: true)
        return made
    }

    /// Put these lines into Reminders. Returns which reminder each became.
    func send(_ lines: [ActionItem]) async throws -> [(actionId: String, reminderId: String)] {
        if AMSPackingApp.testing {
            return lines.map { a in
                let id = "pretend-\(a.id)"
                pretend[id] = false
                return (a.id, id)
            }
        }
        let into = try list()
        var made: [(String, EKReminder)] = []
        for a in lines {
            let r = EKReminder(eventStore: store)
            r.title = a.text
            r.calendar = into
            try store.save(r, commit: false)
            made.append((a.id, r))
        }
        try store.commit()
        return made.map { ($0.0, $0.1.calendarItemExternalIdentifier ?? $0.1.calendarItemIdentifier) }
    }

    /// Which of these reminders have been ticked.
    func ticked(_ ids: [String]) async -> Set<String> {
        if AMSPackingApp.testing { return Set(ids.filter { pretend[$0] == true }) }
        var out = Set<String>()
        for id in ids {
            let items = store.calendarItems(withExternalIdentifier: id)
            if items.contains(where: { ($0 as? EKReminder)?.isCompleted == true }) { out.insert(id) }
        }
        return out
    }
}
