// Counting — what is left to pack, what the post-trip review teaches the templates,
// how many of a thing a trip needs, and what each bag weighs.
// Ported from js/model.js ("Progress / stats", "Weight, bag loads, flags & quantity scaling").

import Foundation

// MARK: - Progress / stats

/// Something SET ASIDE for this trip: still on the list, still visible, but not
/// being packed this time. It is a decision, not an omission — so it leaves every
/// count of "what is left", or a trip could never reach 100% and the ring would
/// be lying. The flag lives on the trip's entry, never on the template: the next
/// trip starts with everything back.
public func isSetAside(_ e: Item?) -> Bool { e?.skipped ?? false }

/// The entries actually being packed.
public func packable(_ entries: [Item]) -> [Item] { entries.filter { !isSetAside($0) } }

/// `{ done, total, aside, pct }` — what `progress` returns. (Not called `Progress`:
/// Foundation already has a class of that name.)
public struct PackingProgress: Equatable, Hashable, Sendable {
    public var done: Int
    public var total: Int
    public var aside: Int
    public var pct: Int
    public init(done: Int = 0, total: Int = 0, aside: Int = 0, pct: Int = 0) {
        self.done = done; self.total = total; self.aside = aside; self.pct = pct
    }
    public var json: JSONValue {
        ["done": .number(Double(done)), "total": .number(Double(total)), "aside": .number(Double(aside)), "pct": .number(Double(pct))]
    }
}

public func progress(_ entries: [Item]) -> PackingProgress {
    let list = packable(entries)
    let total = list.count
    let done = list.filter { $0.checked }.count
    let aside = entries.count - total
    return PackingProgress(done: done, total: total, aside: aside,
                           pct: total > 0 ? jsRoundInt(Double(done) / Double(total) * 100) : 0)
}

// MARK: - Post-trip review learning

/// Post-trip review learning. Each reviewed entry carries a boolean `used`; fold that
/// into the source building-block item's stats so lists can get tighter over time.
/// Returns the lists that changed (so the caller can persist just those).
///
/// JS mutates the lists it is handed; here `lists` is `inout` for the same effect,
/// and the returned lists are the changed ones AS THEY ARE AFTERWARDS, in the order
/// they first changed. (Two lists sharing an id: the LAST one is the one written to,
/// as with the JS Map.)
///
/// 🚨 v162: only what actually went in the bag counts as packed.
///
/// Before this, EVERY line on the trip scored +1 packed the moment you saved a
/// review — including the things you looked at and deliberately left behind. So
/// gear you quietly skip on every single trip was recorded as "packed, and used"
/// every single trip, and the learning was being fed the opposite of the truth.
/// A tick in Packing Mode (or on the list) is the app's record of "this is in the
/// bag", so that is what we count.
///
/// The fallback matters as much as the rule. If you packed WITHOUT ticking — no
/// tick anywhere on the trip — there is no evidence to read, and refusing to
/// learn anything would be worse than trusting the list. In that case the list
/// itself is the evidence and every line counts, exactly as it did before v162.
@discardableResult
public func applyReview(_ event: TripEvent?, _ lists: inout [PackList], _ whenISO: String? = nil) -> [PackList] {
    let now = (whenISO ?? "").isEmpty ? nowISO() : (whenISO ?? "")
    var byId: [String: Int] = [:]
    for (i, l) in lists.enumerated() { byId[l.id] = i }
    var changed: [String] = []                                   // list ids, in the order they first changed
    let entries = event?.entries ?? []
    let anyTicked = entries.contains { $0.checked }

    for e in entries {
        guard let used = e.used,
              let lid = e.sourceListId, !lid.isEmpty,
              let sid = e.sourceItemId, !sid.isEmpty else { continue }
        guard let li = byId[lid] else { continue }
        guard let ii = lists[li].items.firstIndex(where: { $0.id == sid }) else { continue }
        var stats = normalizeStats(lists[li].items[ii].stats)
        if anyTicked && !e.checked {
            // On the list, never packed. A fact worth keeping — it is the clearest
            // sign an item has outstayed its welcome on that template.
            stats.skipped += 1
        } else {
            stats.packed += 1
            if used { stats.used += 1 } else { stats.unused += 1 }
        }
        stats.lastReviewed = now
        lists[li].items[ii].stats = stats
        if !changed.contains(lid) { changed.append(lid) }
    }
    return changed.compactMap { lid in byId[lid].map { lists[$0] } }
}

/// `{ listId, listName, item, stats, reason, times }` — one row of `pruneSuggestions`.
public struct PruneSuggestion: Equatable, Sendable {
    public var listId: String
    public var listName: String
    public var item: Item
    /// The item's stats, normalised.
    public var stats: ItemStats
    /// 'never-used' | 'never-packed'
    public var reason: String
    public var times: Int
    public init(listId: String, listName: String, item: Item, stats: ItemStats, reason: String, times: Int) {
        self.listId = listId; self.listName = listName; self.item = item
        self.stats = stats; self.reason = reason; self.times = times
    }
    public var json: JSONValue {
        ["listId": .string(listId), "listName": .string(listName), "item": item.json, "stats": stats.json,
         "reason": .string(reason), "times": .number(Double(times))]
    }
}

/// Things a template is probably carrying for nothing. Two different signals, kept
/// apart because they mean different things and read differently on screen:
///
///   'never-used'   — you packed it this many times and never once used it.
///   'never-packed' — it sat on the list this many times and never went in the bag.
///
/// 🚨 `minTrips` defaults to 2 and v162 stopped the Refine screen overriding it
/// to 1. One trip is not evidence, and the class of gear you most often fail to
/// use is precisely the class you carry BECAUSE you hope not to need it — the
/// first-aid kit, the tow rope, the spare warm layer. Offering a one-tap Drop on
/// the strength of a single quiet trip is the same trap this app removed twice
/// before (v133's "Reset to the standard seven", v141's "Standard items").
public func pruneSuggestions(_ lists: [PackList], minTrips: Int = 2) -> [PruneSuggestion] {
    var out: [PruneSuggestion] = []
    for l in lists {
        for it in l.items {
            let s = normalizeStats(it.stats)
            if it.keep { continue }                              // you have already said "keep it"
            var reason = ""
            var times = 0
            if s.packed >= minTrips && s.used == 0 { reason = "never-used"; times = s.packed }
            else if s.skipped >= minTrips && s.packed == 0 { reason = "never-packed"; times = s.skipped }
            if reason.isEmpty { continue }
            out.append(PruneSuggestion(listId: l.id, listName: l.name, item: it, stats: s, reason: reason, times: times))
        }
    }
    return out.stableSorted(compare: { a, b in jsSign(Double(b.times - a.times)) })
}

// MARK: - Weight, bag loads, flags & quantity scaling (#3)

/// How many of this item are actually needed for the trip. Per-night items scale
/// with the trip length; otherwise honour an explicit numeric qty, defaulting to 1.
/// (`qty` is free text: "2" is 2, "2.5" is 2.5, "1 pair" is not a number and counts as 1.)
public func effectiveQty(_ entry: Item?, _ nights: Int = 0) -> Double {
    guard let entry = entry else { return 1 }
    if entry.perNight && nights > 0 { return Double(nights) }
    let n = jsParseNumber(entry.qty)
    return n.isFinite && n > 0 ? n : 1
}

/// When laundry is available you wash and re-wear, so per-night items (socks,
/// underwear, tees) don't need one per night. This caps the "nights" used for
/// quantity scaling to a sensible cycle's worth. Short trips are unaffected
/// (min never raises the count); only display quantities change, not the real
/// trip length. Feed the result to effectiveQty / bagLoads / packingFlags.
public let LAUNDRY_CAP_NIGHTS = 4
public func qtyNights(_ event: TripEvent?) -> Int {
    guard let event = event else { return 0 }
    let n = event.nights
    return (event.laundry && n > LAUNDRY_CAP_NIGHTS) ? LAUNDRY_CAP_NIGHTS : n
}

/// A per-container-name weight-limit map (kg): the built-in airline defaults,
/// overlaid with any real container record's own `maxKg` (a bag the user has
/// specced). Later wins, so a user's own limit overrides the generic default.
public func containerLimits(_ lists: [PackList] = []) -> [String: Double] {
    var out = CONTAINER_LIMITS_KG
    for l in lists where l.role == CONTAINER_ROLE {
        for it in l.items {
            let name = jsTrim(it.name)
            if !name.isEmpty && it.maxKg > 0 { out[name] = it.maxKg }
        }
    }
    return out
}

/// `{ container, grams, items, kg, limitKg, over }` — one bag from `bagLoads`.
public struct BagLoad: Equatable, Hashable, Sendable {
    public var container: String
    public var grams: Double
    public var items: Int
    /// `grams` in kg, rounded to 0.1.
    public var kg: Double
    /// 0 = no limit tracked.
    public var limitKg: Double
    public var over: Bool
    public init(container: String, grams: Double = 0, items: Int = 0, kg: Double = 0, limitKg: Double = 0, over: Bool = false) {
        self.container = container; self.grams = grams; self.items = items
        self.kg = kg; self.limitKg = limitKg; self.over = over
    }
    public var json: JSONValue {
        ["container": .string(container), "grams": .number(grams), "items": .number(Double(items)),
         "kg": .number(kg), "limitKg": .number(limitKg), "over": .bool(over)]
    }
}

/// Per-container weight totals (kg) with over-limit warnings. `limits` maps a
/// container name to its max kg; defaults to the built-in airline ceilings, but the
/// app passes containerLimits(lists) so each real bag's own limit is honoured.
/// What is set aside is not weighed; reminders weigh nothing. Bags come back in
/// CONTAINERS order, the user's own bags after them in first-appearance order.
public func bagLoads(_ entries: [Item], _ nights: Int = 0, _ limits: [String: Double]? = CONTAINER_LIMITS_KG) -> [BagLoad] {
    var bags: [BagLoad] = []                                     // first-appearance order, as the JS Map
    for e in packable(entries) {
        if e.itemType == "reminder" { continue }
        let c = e.container.isEmpty ? "Other" : e.container
        let i: Int
        if let found = bags.firstIndex(where: { $0.container == c }) { i = found }
        else { bags.append(BagLoad(container: c)); i = bags.count - 1 }
        bags[i].items += 1
        bags[i].grams += (e.weight.isNaN ? 0 : e.weight) * effectiveQty(e, nights)
    }
    var order: [String: Int] = [:]
    for (i, c) in CONTAINERS.enumerated() { order[c] = i }
    return bags
        .stableSorted(compare: { a, b in jsSign(Double((order[a.container] ?? 999) - (order[b.container] ?? 999))) })
        .map { b in
            var out = b
            let limit = limits?[b.container] ?? 0
            out.limitKg = limit.isNaN ? 0 : limit
            out.kg = jsRound(b.grams / 100) / 10
            out.over = out.limitKg > 0 && b.grams / 1000 > out.limitKg
            return out
        }
}

/// `{ liquids, restricted, total, weighed, totalKg }`
public struct PackingFlags: Equatable, Hashable, Sendable {
    public var liquids: Int
    public var restricted: Int
    public var total: Int
    public var weighed: Int
    public var totalKg: Double
    public init(liquids: Int = 0, restricted: Int = 0, total: Int = 0, weighed: Int = 0, totalKg: Double = 0) {
        self.liquids = liquids; self.restricted = restricted; self.total = total
        self.weighed = weighed; self.totalKg = totalKg
    }
    public var json: JSONValue {
        ["liquids": .number(Double(liquids)), "restricted": .number(Double(restricted)), "total": .number(Double(total)),
         "weighed": .number(Double(weighed)), "totalKg": .number(totalKg)]
    }
}

/// Trip-wide flag counts + total known weight.
/// NOTE: unlike `bagLoads` this walks EVERY entry, set aside or not — as the JS does.
public func packingFlags(_ entries: [Item], _ nights: Int = 0) -> PackingFlags {
    var f = PackingFlags()
    var grams = 0.0
    for e in entries {
        if e.itemType == "reminder" { continue }
        f.total += 1
        if e.liquid { f.liquids += 1 }
        if e.restricted { f.restricted += 1 }
        if e.weight > 0 { f.weighed += 1; grams += e.weight * effectiveQty(e, nights) }
    }
    f.totalKg = jsRound(grams / 100) / 10
    return f
}
