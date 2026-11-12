import Foundation
import PackingCore

// The Inventory tab (0.117 — his words of 11 Nov 2026: "I cannot find an entry point for the new
// items perspective… Can we make an inventory page?"; his pick: a tab of its own). Rooms with their
// counts, and the warranties that end soon.

extension Library {
    /// His rooms that hold things, in the order of his list (rooms not on it after, A–Z), each with how
    /// many things it holds; things with no room last, as "".
    public func inventoryRooms() -> [(room: String, count: Int)] {
        var counts: [String: Int] = [:], spelled: [String: String] = [:]
        for it in ownThings() where !Library.isGone(it) {
            let k = normName(it.storage)
            counts[k, default: 0] += 1
            if spelled[k] == nil { spelled[k] = jsTrim(it.storage) }
        }
        var out: [(room: String, count: Int)] = []
        var done = Set<String>()
        for p in storagePlaces() {
            let k = normName(p)
            if !k.isEmpty, let n = counts[k], done.insert(k).inserted { out.append((p, n)) }
        }
        let others = counts.keys.filter { !$0.isEmpty && !done.contains($0) }
            .map { (room: spelled[$0] ?? $0, count: counts[$0] ?? 0) }
            .sorted { jsLocaleCompare($0.room, $1.room) < 0 }
        out += others
        if let n = counts[""] { out.append(("", n)) }
        return out
    }

    /// Things whose warranty ends between today and `days` from now, soonest first.
    public func warrantiesEndingSoon(today: String, days: Int = 60) -> [Item] {
        guard isYMD(today) else { return [] }
        let last = addDays(today, days)
        return ownThings().filter { !Library.isGone($0) && isYMD($0.warranty) && $0.warranty >= today && $0.warranty <= last }
            .sorted { $0.warranty < $1.warranty }
    }
}
