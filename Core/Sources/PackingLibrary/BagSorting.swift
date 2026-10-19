import Foundation
import PackingCore

// Sorting Your bags (0.90) — his ask of 19 Oct 2026: "Add the ability to sort bags in the Care page /
// Bags. Alphabetical, Own order, Last used, Last added, last edited etc." Care → Bags gets a Sort
// drop-down; the choice is remembered on the device (spec 05, Care → Bags).
//
// WHERE EACH ORDER IS READ — none of it is a new list of his; each comes from what the library
// already knows, and where it did not know (last edited) one key on the bag's own thing says it:
//
// - Own order: his bag list's own order (`bags()`) — the order he arranges with the grip in a
//   thing's "Usually packed in" list (`moveBag(named:by:)`); a new bag joins at the end, a
//   duplicate right after its original.
// - A–Z: the names, as the app sorts names everywhere (`jsLocaleCompare`, base: case and accents
//   do not count).
// - Last used: the newest trip the bag went on — a trip with a line packed in it, or one Packing
//   Stations' "+ Add a bag" put on the trip — by the trip's first day (or the day it was made, an
//   undated trip). A trip still ahead counts: the bag is on it. Never on a trip: last.
// - Last added: when the bag joined Your bags. A record's id begins with the moment it was made
//   (`PackingEnv.defaultMakeId`, the web app's own `Date.now().toString(36)`), so the id of the bag's
//   row on Your bags says when it became a bag — no new field. Bags moved in together (from the web
//   app, at one moment) tie, and keep their own order among themselves.
// - Last edited: `BAG_EDITED_KEY` on the bag's thing — the moment anything about the bag itself last
//   changed (`stampEditedBags`, called by the app on every change it makes). A bag not changed since
//   0.90 counts as edited when it was added.
//
// Ties, and a bag with no answer, keep his own order — the sort is stable and starts from it.

/// On a bag's thing: when anything about the bag itself last changed — an ISO time (`nowISO()`).
/// Absent until the bag is first changed after 0.90; the web model never reads it.
public let BAG_EDITED_KEY = "bagEditedAt"

/// The orders Your bags can show — the Sort drop-down's rows, in this order.
public enum BagSort: String, CaseIterable, Sendable, Identifiable {
    case own, name, used, added, edited

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .own: return "Own order"
        case .name: return "A\u{2013}Z"
        case .used: return "Last used"
        case .added: return "Last added"
        case .edited: return "Last edited"
        }
    }
}

extension Library {
    /// His bags in the chosen order (see the top of this file for where each is read).
    public func sortedBags(_ sort: BagSort) -> [Item] {
        let own = bags()
        switch sort {
        case .own:
            return own
        case .name:
            return own.stableSorted(compare: { a, b in jsLocaleCompare(a.name, b.name, sensitivity: .base) })
        case .used:
            let last = bagLastTrips()
            return Library.newestFirst(own) { last[normName($0.name)] }
        case .added:
            return Library.newestFirst(own) { Library.bagAddedAt($0) }
        case .edited:
            let stamped = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            return Library.newestFirst(own) { bag in
                stamped[bag.id].flatMap(Library.bagEditedAt) ?? Library.bagAddedAt(bag)
            }
        }
    }

    /// Newest first by a key that sorts as text (ISO times and days do); no key = last. Stable: ties
    /// keep the order they came in (his own).
    static func newestFirst(_ bags: [Item], _ key: (Item) -> String?) -> [Item] {
        let keyed = bags.map { ($0, key($0)) }
        return keyed.stableSorted(compare: { a, b in
            switch (a.1, b.1) {
            case let (x?, y?): return x > y ? -1 : (x < y ? 1 : 0)
            case (_?, nil): return -1
            case (nil, _?): return 1
            default: return 0
            }
        }).map(\.0)
    }

    // MARK: - Last used

    /// Each bag's newest trip day, by the bag's name as `normName` sees it: a trip with a line
    /// packed in it (a reminder is in no bag; a skipped line is not packed), or one "+ Add a bag"
    /// put on the trip. The day is the trip's first, or the day it was made.
    public func bagLastTrips() -> [String: String] {
        var out: [String: String] = [:]
        for t in trips {
            let day = t.startDate.isEmpty ? String(t.createdAt.prefix(10)) : t.startDate
            guard !day.isEmpty else { continue }
            var names = Set(bagLoads(t.entries, 0, nil).filter { $0.items > 0 }.map { normName($0.container) })
            for added in Library.addedBags(t) { names.insert(normName(added)) }
            for name in names where !name.isEmpty && (out[name] ?? "") < day { out[name] = day }
        }
        return out
    }

    // MARK: - Last added

    /// When the bag joined Your bags, as an ISO time: the moment its row's id was made. nil for an
    /// id that does not begin with a time (or one outside 2015–2100: not a time after all).
    public static func bagAddedAt(_ bag: Item) -> String? {
        guard let row = bag.memId else { return nil }
        return idTime(row)
    }

    /// The moment an id was made — its first part, milliseconds in base 36 — as an ISO time.
    public static func idTime(_ id: String) -> String? {
        guard let head = id.split(separator: "-", maxSplits: 1).first, head.count >= 8,
              let ms = Int64(head, radix: 36),
              ms > 1_420_070_400_000, ms < 4_102_444_800_000 else { return nil }
        return jsISOString(Date(timeIntervalSince1970: Double(ms) / 1000))
    }

    // MARK: - Last edited

    /// When anything about the bag itself last changed (its thing's `BAG_EDITED_KEY`), if it has.
    public static func bagEditedAt(_ thing: Item) -> String? {
        guard let s = thing.extra[BAG_EDITED_KEY]?.stringValue, !jsTrim(s).isEmpty else { return nil }
        return s
    }

    /// Stamp every bag whose own thing changed since `before` — its name, numbers, notes, details,
    /// pockets, switches, photos: anything but its review counts (`stats`, which a trip's review
    /// writes, not he) and the stamp itself. A bag that is new since `before` is not stamped: it
    /// counts as edited when it was added. The app calls this on every change it makes
    /// (`LibraryModel.change`), so every screen that changes a bag is covered — the bag's page,
    /// Your bags' numbers, Its details, the table, a trip's switches. Returns how many it stamped.
    @discardableResult
    public mutating func stampEditedBags(since before: Library, at when: String = nowISO()) -> Int {
        guard let list = bagList else { return 0 }
        let ids = Set(memberships.filter { $0.templateId == list.id }.map(\.itemId))
        guard !ids.isEmpty else { return 0 }
        var was: [String: Item] = [:]
        for it in before.items where ids.contains(it.id) { was[it.id] = it }
        guard !was.isEmpty else { return 0 }
        var stamped = 0
        for n in items.indices where ids.contains(items[n].id) {
            guard let old = was[items[n].id], Library.editedPart(old) != Library.editedPart(items[n]) else { continue }
            items[n].extra[BAG_EDITED_KEY] = .string(when)
            stamped += 1
        }
        return stamped
    }

    /// What counts as an edit of a bag: the thing without its review counts and the stamp.
    static func editedPart(_ thing: Item) -> Item {
        var t = thing
        t.stats = ItemStats()
        t.extra[BAG_EDITED_KEY] = nil
        return t
    }
}
