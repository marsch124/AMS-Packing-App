import Foundation
import PackingCore

// The buy-list. It is the actions store with `kind == "shopping"`, exactly as the
// web app keeps it, so the same lines come through a backup either way.

extension Library {
    /// What is on the buy-list, open lines before bought ones.
    public func buyList() -> [ActionItem] { sortedActions(kind: "shopping") }

    /// What the library itself thinks is worth buying: consumables, things marked
    /// "needs replacing", and anything past or near its replace-by date. Anything
    /// already on the open buy-list is left out, so a line is never offered twice.
    public func buySuggestions(today: String? = nil) -> [ShoppingSuggestion] {
        shoppingSuggestions(items, actions, today)
    }

    /// Put a suggestion on the list, keeping the thing it came from so the
    /// suggestion stops being offered and the line can say what it is for.
    @discardableResult
    public mutating func addToBuyList(_ suggestion: ShoppingSuggestion) -> ActionItem? {
        addAction(text: suggestion.item.name, kind: "shopping",
                  itemId: suggestion.item.id, itemName: suggestion.item.name)
    }

    /// A line he types himself — no thing behind it.
    @discardableResult
    public mutating func addToBuyList(text: String) -> ActionItem? {
        addAction(text: text, kind: "shopping")
    }
}

// MARK: - Removing a line, and putting it back

extension Library {
    /// Remove a to-do or a buy line. Returns the line as it was — so a screen can
    /// offer Undo — and the reminder it had become, for the app to take out of
    /// Reminders too. nil for an unknown id.
    ///
    /// His rule is that things, bags, templates and trips ask before they go; a line
    /// of a list goes at once with ✕ but can be brought back with Undo (the spec
    /// pass, 5 Oct 2026) — asking each time would make a quick list slow.
    @discardableResult
    public mutating func removeLine(id: String) -> (line: ActionItem, reminderId: String?)? {
        guard let line = actions.first(where: { $0.id == id }) else { return nil }
        let rid = reminderOf(actionId: id)
        deleteAction(id: id)
        return (line, rid)
    }

    /// Undo: the line back exactly as it was, under its own id. Its reminder was
    /// taken out of Reminders with it, so it comes back as not sent yet.
    @discardableResult
    public mutating func putBackLine(_ line: ActionItem) -> Bool {
        guard !actions.contains(where: { $0.id == line.id }) else { return false }
        var back = line
        back.extra[REMINDER_ID_KEY] = nil
        actions.append(back)
        return true
    }
}
