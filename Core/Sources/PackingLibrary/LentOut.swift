import Foundation
import PackingCore

// 0.124 — "Lent to…" (his pick of 12 Nov 2026): who has the thing, since when, and a reminder to ask
// for it back three weeks after, and every three weeks while it is still out. Kept in the thing's
// `extra["lent"]` {to, on}; "Back home" clears it.

public let LENT_KEY = "lent"
/// Days after lending that the first "ask for it back" reminder comes, and between the next ones.
public let LENT_REMIND_DAYS = 21

public struct LentMark: Equatable, Sendable {
    public var to: String
    public var on: String
    public init(to: String, on: String) { self.to = to; self.on = on }
}

extension Library {
    public static func lent(_ it: Item) -> LentMark? {
        guard case .object(let o)? = it.extra[LENT_KEY] else { return nil }
        let to = jsStringOr(o["to"])
        guard !jsTrim(to).isEmpty else { return nil }
        return LentMark(to: to, on: jsStringOr(o["on"]))
    }

    /// Lend it (a blank name lends nothing) — or, with nil, it is back home.
    public static func setLent(_ it: inout Item, _ mark: LentMark?) {
        if let mark, !jsTrim(mark.to).isEmpty {
            it.extra[LENT_KEY] = .object(["to": .string(jsTrim(mark.to)), "on": .string(mark.on)])
        } else {
            it.extra[LENT_KEY] = nil
        }
    }

    /// "Lent to Anna · 1 Nov 2026".
    public static func lentLine(_ it: Item) -> String {
        guard let l = lent(it) else { return "" }
        return "Lent to \(l.to)" + (isYMD(l.on) ? " \u{00B7} " + dayWords(l.on) : "")
    }

    /// His things that are lent out, the longest out first.
    public func lentThings() -> [Item] {
        ownThings().filter { Library.lent($0) != nil && !Library.isGone($0) }.sorted {
            (Library.lent($0)?.on ?? "", $0.name) < (Library.lent($1)?.on ?? "", $1.name)
        }
    }

    /// People he has lent to before, A–Z, for the name field's suggestions.
    public func lentToNames() -> [String] {
        var seen = Set<String>(), out: [String] = []
        for it in items { if let l = Library.lent(it), seen.insert(normName(l.to)).inserted { out.append(l.to) } }
        return out.sorted { jsLocaleCompare($0, $1) < 0 }
    }

    /// For each thing out: the next 21-day step from the day it went that is today or later.
    func lentReminders(today: String) -> [InventoryReminder] {
        lentThings().compactMap { it in
            guard let l = Library.lent(it), isYMD(l.on) else { return nil }
            var day = addDays(l.on, LENT_REMIND_DAYS)
            var guardN = 0
            while isYMD(day), day < today, guardN < 200 { day = addDays(day, LENT_REMIND_DAYS); guardN += 1 }
            guard isYMD(day) else { return nil }
            return InventoryReminder(id: "inv-lent-\(it.id)-\(day)", kind: .lent, itemId: it.id, day: day,
                                     title: "Ask for it back",
                                     body: "\(it.name) \u{2014} lent to \(l.to) on \(Library.dayWords(l.on))")
        }
    }
}
