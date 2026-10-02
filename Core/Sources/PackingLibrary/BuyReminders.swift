import Foundation
import PackingCore

// To buy → Apple Reminders — his pre-trip idea 9 (2 Oct 2026): the buy list goes
// with him to the shop in the app he already shops with. A line sent once is not
// sent again (the reminder it became is kept in the line's extra keys, so the web
// app's model is untouched); and a reminder ticked in the shop ticks its line here.

/// The line's extra key: the identifier of the reminder it became.
public let REMINDER_ID_KEY = "reminderId"

extension Library {
    /// Open buy lines not yet in Reminders.
    public func buyLinesToSend() -> [ActionItem] {
        buyList().filter { !$0.done && reminderId(of: $0) == nil }
    }

    /// The buy lines that went to Reminders, with the reminder each became.
    public func sentBuyLines() -> [(line: ActionItem, reminderId: String)] {
        buyList().compactMap { a in reminderId(of: a).map { (a, $0) } }
    }

    private func reminderId(of a: ActionItem) -> String? {
        guard let s = a.extra[REMINDER_ID_KEY]?.stringValue, !s.isEmpty else { return nil }
        return s
    }

    /// Remember the reminder a buy line became.
    @discardableResult
    public mutating func markSent(actionId: String, reminderId: String) -> Bool {
        guard let n = actions.firstIndex(where: { $0.id == actionId && $0.kind == "shopping" }), !reminderId.isEmpty else { return false }
        actions[n].extra[REMINDER_ID_KEY] = .string(reminderId)
        actions[n].updatedAt = nowISO()
        return true
    }

    /// Reminders ticked in the shop: their buy lines are ticked here too. Never the
    /// other way round — a line is never un-ticked by a reminder. Returns how many.
    @discardableResult
    public mutating func takeBought(reminderIds: Set<String>) -> Int {
        var n = 0
        for (line, rid) in sentBuyLines() where !line.done && reminderIds.contains(rid) {
            if setActionDone(true, id: line.id) { n += 1 }
        }
        return n
    }
}
