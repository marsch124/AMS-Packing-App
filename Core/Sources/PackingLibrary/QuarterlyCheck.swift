import Foundation
import PackingCore

// 0.124 — the quarterly check (his pick of 12 Nov 2026, "make it quarterly"): on 1 Jan, 1 Apr, 1 Jul
// and 1 Oct the app asks, room by room, "Still have it?" for each thing not looked at this quarter.
// "Still here" stamps `extra["checked"]` with the day; "Gone…" marks it gone. A thing added this
// quarter counts as looked at (`addThing` stamps it).

public let CHECKED_KEY = "checked"

extension Library {
    /// The first day of today's quarter ("2026-10-01").
    public static func quarterStart(_ today: String) -> String {
        let b = today.split(separator: "-").compactMap { Int($0) }
        guard b.count == 3 else { return "" }
        let m = ((b[1] - 1) / 3) * 3 + 1
        return String(format: "%04d-%02d-01", b[0], m)
    }

    public static func checked(_ it: Item) -> String { it.extra[CHECKED_KEY]?.stringValue ?? "" }

    /// The things to look at this quarter, room by room (rooms in the Inventory tab's order).
    public func toCheck(today: String) -> [(room: String, things: [Item])] {
        let start = Library.quarterStart(today)
        guard isYMD(start) else { return [] }
        let due = ownThings().filter { it in
            !it.retired && !Library.isGone(it) && Library.checked(it) < start
        }
        var out: [(room: String, things: [Item])] = []
        var left = due
        for r in inventoryRooms() {
            let k = normName(r.room)
            let mine = left.filter { normName($0.storage) == k }
            guard !mine.isEmpty else { continue }
            left.removeAll { normName($0.storage) == k }
            out.append((r.room, mine.sorted { jsLocaleCompare($0.name, $1.name) < 0 }))
        }
        if !left.isEmpty { out.append(("No room", left.sorted { jsLocaleCompare($0.name, $1.name) < 0 })) }
        return out
    }

    public mutating func stillHave(_ ids: [String], today: String) {
        for id in ids { _ = updateThing(id: id) { $0.extra[CHECKED_KEY] = .string(today) } }
    }

    /// The reminder on the first day of the next quarter (today, when today is one) — when there is
    /// anything to look at by then.
    func quarterlyCheckReminder(today: String) -> InventoryReminder? {
        guard isYMD(today) else { return nil }
        let start = Library.quarterStart(today)
        let day = start == today ? today : addMonths(start, 3)
        let n = toCheck(today: day).reduce(0) { $0 + $1.things.count }
        guard n > 0 else { return nil }
        return InventoryReminder(id: "inv-check-\(day)", kind: .check, itemId: "", day: day,
                                 title: "Quarterly check",
                                 body: "Still have them? \(n) thing\(n == 1 ? "" : "s") to look at, room by room.")
    }
}
