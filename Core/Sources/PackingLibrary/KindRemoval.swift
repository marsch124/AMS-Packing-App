import Foundation
import PackingCore

// A kind of thing removed while things still have it (0.107). His words, 30 Oct 2026: "I need the ability to
// delete a Kind of thing, even if there are items that are connected to this very Kind of thing choice. Example: I
// don't understand why I defined Reminders. I want them gone, because I dont know how to use them."
//
// Until 0.107 a kind in use could not be removed at all — the refusal of every list of his ("… is still used by 3
// things, so it stays."). Now the two places a kind is removed — Your choices and a thing's Kind of thing drop-down
// (his second screenshot) — ask where its things go (`KindUse.says`, "Move them to" — his Other when he has one,
// `fallbackKind`), and `removeKind` moves every thing and every trip line of that kind (any spelling) to the kind
// chosen and takes it off his list. Your choices does it on the page's copy of the library (Done hands it over in one
// change, one ⌘Z step "Change Your Choices"); a thing's page holds it in its `ChoiceEdits` (`moves`) and makes it on
// Save, after the thing, in the Save's one step. Cancel throws it away on both. Only Kind of thing does this; a place,
// an owner, a packer, a condition or a step still in use is still refused (`ChoiceUse.refusal`).
//
// Two kinds are the app's own. Documents & money is read by Before you go, so it stays. Reminders may go: a reminder
// is known by its `itemType`, never by its kind — and once it is gone the app does not bring it back: a reminder made
// after is given `reminderKind()` (his Other, else the app's own catch-all, else the first of his kinds).

/// How many of his things, and how many reminders (a template's, or a thing on no template that is one), have a
/// kind — the card's count. Trip lines are not counted: they follow their things.
public struct KindUse: Equatable, Sendable {
    public var things = 0
    public var reminders = 0
    public init(things: Int = 0, reminders: Int = 0) { self.things = things; self.reminders = reminders }

    public var inUse: Bool { things + reminders > 0 }

    /// "10 things have this kind." · "1 reminder has this kind." · "3 things and 2 reminders have this kind."
    public var says: String {
        func n(_ count: Int, _ word: String) -> String { "\(count) \(word)\(count == 1 ? "" : "s")" }
        var parts: [String] = []
        if things > 0 { parts.append(n(things, "thing")) }
        if reminders > 0 { parts.append(n(reminders, "reminder")) }
        let one = things + reminders == 1
        return parts.joined(separator: " and ") + (one ? " has this kind." : " have this kind.")
    }

    /// The drop-down's heading on the card: one thing is "it".
    public var moveTo: String { things + reminders == 1 ? "Move it to" : "Move them to" }
}

extension Library {
    /// What has kind `key` (any spelling of it, as `usesOf` counts): his things and his reminders apart.
    /// `except`: a thing not counted — a thing's page counts its own by what the page says.
    public func kindUse(_ key: String, except: String? = nil) -> KindUse {
        let k = normName(key)
        guard !k.isEmpty else { return KindUse() }
        var use = KindUse()
        for it in items where normName(it.category) == k && it.id != except {
            if Library.isReminder(it) { use.reminders += 1 } else { use.things += 1 }
        }
        return use
    }

    /// Where the things of a kind being removed go unless he chooses another — and the kind a reminder is given once
    /// Reminders is gone: his Other, else the app's own catch-all (Comfort & misc, what a thing with no kind reads as),
    /// else the first of his kinds — never `without` (the kind going), always one on his list as he spells it.
    public func fallbackKind(without gone: String = "") -> String {
        let away = Library.choiceKey(gone)
        let list = categories().filter { gone.isEmpty || Library.choiceKey($0) != away }
        return Library.fallbackKindIndex(list).map { list[$0] } ?? CATEGORY_DEFAULT
    }

    /// Which of these kinds (as a page shows them, the one going left out) the things go to unless he
    /// chooses: Other, else the app's catch-all, else the first — nil for none.
    public static func fallbackKindIndex(_ labels: [String]) -> Int? {
        if let other = labels.firstIndex(where: { normName($0) == "other" }) { return other }
        if let catchAll = labels.firstIndex(where: { normName($0) == normName(CATEGORY_DEFAULT) }) { return catchAll }
        return labels.isEmpty ? nil : 0
    }

    /// The kind a reminder the app makes now is given (a template's reminder, a trip's own To do): Reminders while he
    /// has it — as his list spells it — otherwise `fallbackKind()`. Never a kind he removed.
    public func reminderKind() -> String {
        categories().first { normName($0) == normName(REMINDERS_CATEGORY) } ?? fallbackKind()
    }

    /// Why kind `key` cannot be removed even with its things moved — nil when it can. Documents & money is read by
    /// Before you go; the last of his kinds would leave nothing (an empty list is the app's twelve again).
    public func kindRemoveProblem(_ key: String) -> String? {
        if normName(key) == normName(DOCUMENTS_CATEGORY) { return "\(DOCUMENTS_CATEGORY) is read by Before you go, so it stays." }
        let away = Library.choiceKey(key)
        if !categories().contains(where: { Library.choiceKey($0) != away }) {
            return "\(jsTrim(key)) is your only kind of thing, so it stays."
        }
        return nil
    }

    /// Takes kind `key` off his list; every thing and every trip line of that kind (any spelling) takes `moveTo` —
    /// one of his other kinds, as his list spells it; anything else (blank, unknown, the kind itself) is
    /// `fallbackKind(without: key)`. Trip lines of every trip, done ones included, as a rename carries them: the kind
    /// is gone everywhere. A reminder stays a reminder (its `itemType`). nil = done; otherwise why it stays
    /// (`kindRemoveProblem`), and nothing changed.
    @discardableResult
    public mutating func removeKind(_ key: String, moveTo: String) -> String? {
        if let problem = kindRemoveProblem(key) { return problem }
        let away = Library.choiceKey(key), gone = normName(key)
        let to = categories().first { Library.choiceKey($0) == Library.choiceKey(moveTo) && Library.choiceKey($0) != away }
            ?? fallbackKind(without: key)
        for i in items.indices where normName(items[i].category) == gone { items[i].category = to }
        for t in trips.indices {
            var moved = false
            for e in trips[t].entries.indices where normName(trips[t].entries[e].category) == gone {
                trips[t].entries[e].category = to
                moved = true
            }
            if moved { trips[t].updatedAt = nowISO() }
        }
        setCategories(categories().filter { Library.choiceKey($0) != away })
        return nil
    }
}
