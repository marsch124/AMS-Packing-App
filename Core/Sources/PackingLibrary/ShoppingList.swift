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
