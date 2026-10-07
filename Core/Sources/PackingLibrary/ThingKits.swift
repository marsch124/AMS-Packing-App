import Foundation
import PackingCore

// Kits — things that hold things (spec 07, part 9; his yes of 7 Oct 2026: some things are
// "already existing as a permanently packed item consisting of items" — a pouch of cables
// and chargers, a pouch of small tools).
//
// NOT the web app's kits (PackingCore/Kits.swift, `Library.kits`: a named bundle that
// pours its members onto a list as separate lines; this app has never shown those). Here
// a kit is a THING — a pouch, a wash bag — that stays packed with other things inside it.
// On a trip it is ONE line.
//
// The rules: one level deep (a kit can go in a bag, never inside another kit); a thing is
// in one kit at most; a bag is never a kit nor inside one (a bag holds its things by
// name, `container`). A kit is simply a thing that holds at least one thing.
//
// WHERE IT IS KEPT. On the KIT, in its extra keys — so the web app's model reads a kit as
// a plain thing (the parity check is untouched), and the kit is stored, synced, backed up
// and restored with the thing, as every extra key is:
//   kitContents  [ids]  what is inside, in his order
//   kitOut       [ids]  of those, what is taken out for now
//   kitCheck     true   check the contents before each trip (absent = no)
// and on a trip's kit LINE:
//   kitTicked    [ids]  the contents ticked on this trip, while the line is not
//
// Chapter 07 planned `insideKitId` on each content as well. It is not stored: ONE record
// holds a kit's whole state, so the two sides can never disagree. A content's kit is read
// from the kits (`kitIndex`). Two devices putting one thing in two different kits at the
// same moment leave it listed by both: it is then inside the kit whose id sorts first,
// and the other kit drops it at its next save.

/// On a kit: the ids of the things inside it, in his order.
public let KIT_CONTENTS_KEY = "kitContents"
/// On a kit: the ids of its contents taken out for now.
public let KIT_OUT_KEY = "kitOut"
/// On a kit: check what is inside before each trip.
public let KIT_CHECK_KEY = "kitCheck"
/// On a trip's kit line: the contents ticked on this trip.
public let KIT_TICKED_KEY = "kitTicked"

/// One thing inside a kit.
public struct KitContent: Equatable, Sendable {
    /// The thing as it is now.
    public var thing: Item
    /// Taken out of the kit for now ("1 missing: Lighter").
    public var takenOut: Bool
    public init(thing: Item, takenOut: Bool) { self.thing = thing; self.takenOut = takenOut }
}

/// Who holds what, read once from the kits.
public struct KitIndex: Equatable, Sendable {
    /// A content's kit, by the content's id.
    public var holder: [String: String] = [:]
    /// A kit's contents, in his order, by the kit's id. Only kits that hold something.
    public var contents: [String: [KitContent]] = [:]
    public init() {}

    public func isKit(_ id: String) -> Bool { !(contents[id] ?? []).isEmpty }
    public func kitOf(_ id: String) -> String? { holder[id] }
}

/// A kit's line on a trip, as the trip shows it.
public struct KitOnLine: Equatable, Sendable {
    /// The kit as it is now.
    public var kit: Item
    public var contents: [KitContent]
    /// "Check before each trip".
    public var check: Bool
    /// The contents ticked on this trip — every one inside when the line is ticked.
    public var ticked: Set<String>

    public init(kit: Item, contents: [KitContent], check: Bool, ticked: Set<String>) {
        self.kit = kit; self.contents = contents; self.check = check; self.ticked = ticked
    }

    /// What is inside now (not taken out).
    public var inside: [KitContent] { contents.filter { !$0.takenOut } }
    /// What is taken out.
    public var missing: [KitContent] { contents.filter(\.takenOut) }
    /// With "Check before each trip": the ones inside not ticked yet. 0 otherwise.
    public var toTick: Int { check ? inside.filter { !ticked.contains($0.thing.id) }.count : 0 }
    /// "3 inside".
    public var insideWords: String { "\(inside.count) inside" }
    /// "1 missing: Lighter", "2 missing: Lighter, Spare cord", or "".
    public var missingWords: String {
        let gone = missing.map(\.thing.name)
        return gone.isEmpty ? "" : "\(gone.count) missing: " + gone.joined(separator: ", ")
    }
    /// "Tick what is inside first: 2 to go." while a checked kit is not all ticked.
    public var toTickWords: String {
        toTick == 0 ? "" : "Tick what is inside first: \(toTick) to go."
    }
}

extension Library {
    // MARK: - Reading

    /// The ids a thing lists under a key, as stored: each once, blanks dropped.
    static func kitIds(_ v: JSONValue?) -> [String] {
        var seen = Set<String>()
        return (v?.arrayValue ?? []).compactMap(\.stringValue).filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    /// The ids a thing lists as inside it — as stored, nothing checked.
    public static func listedContents(_ thing: Item) -> [String] { kitIds(thing.extra[KIT_CONTENTS_KEY]) }

    /// "Check before each trip", on a kit.
    public static func kitCheck(_ kit: Item) -> Bool { kit.extra[KIT_CHECK_KEY]?.boolValue == true }

    /// Who holds what. A thing lists contents → it may be a kit. A listed id counts when
    /// it is a thing that exists, is not the kit itself, not a bag, not a to-do, and does
    /// not list contents of its own (a kit is never inside a kit). Kits are read in id
    /// order and a thing goes in the first that lists it (one kit at most).
    public func kitIndex() -> KitIndex {
        var index = KitIndex()
        let listing = items.filter { !Library.listedContents($0).isEmpty }
        guard !listing.isEmpty else { return index }
        var byId: [String: Item] = [:]
        for i in items where byId[i.id] == nil { byId[i.id] = i }
        let bagIds = Set(bags().map(\.id))
        let lists = Set(listing.map(\.id))
        for kit in listing.sorted(by: { $0.id < $1.id }) where !bagIds.contains(kit.id) && index.holder[kit.id] == nil {
            let out = Set(Library.kitIds(kit.extra[KIT_OUT_KEY]))
            var mine: [KitContent] = []
            for id in Library.listedContents(kit) {
                guard id != kit.id, let thing = byId[id], !bagIds.contains(id), !lists.contains(id),
                      thing.itemType != "reminder", index.holder[id] == nil else { continue }
                index.holder[id] = kit.id
                mine.append(KitContent(thing: thing, takenOut: out.contains(id)))
            }
            if !mine.isEmpty { index.contents[kit.id] = mine }
        }
        return index
    }

    /// Is this thing a kit (does it hold at least one thing)?
    public func isKit(_ id: String) -> Bool { kitIndex().isKit(id) }

    /// What is inside a kit, in his order. [] for a thing that is not a kit.
    public func kitContents(kitId: String) -> [KitContent] { kitIndex().contents[kitId] ?? [] }

    /// The kit a thing is inside, if any.
    public func kitHolding(thingId: String) -> Item? {
        guard let k = kitIndex().holder[thingId] else { return nil }
        return items.first { $0.id == k }
    }

    /// Is this thing taken out of its kit for now?
    public func isTakenOut(thingId: String) -> Bool {
        guard let kit = kitHolding(thingId: thingId) else { return false }
        return Library.kitIds(kit.extra[KIT_OUT_KEY]).contains(thingId)
    }

    /// What a thing weighs as it is packed, in grams: a kit with what is inside it now
    /// (its own weight, plus each content's weight × its how-many, the ones taken out
    /// not counted); any other thing, its own weight.
    public func packedWeight(_ thing: Item, index: KitIndex? = nil) -> Double {
        let own = thing.weight.isFinite ? max(0, thing.weight) : 0
        guard !Library.listedContents(thing).isEmpty else { return own }
        let idx = index ?? kitIndex()
        return own + Library.contentsWeight(idx.contents[thing.id] ?? [])
    }

    /// A trip's lines with each kit weighing what is inside it now (its line's own weight
    /// plus `contentsWeight`) — what the Bags card and a bag's trips add up.
    public func linesWithKitWeights(_ entries: [Item]) -> [Item] {
        let idx = kitIndex()
        guard !idx.contents.isEmpty else { return entries }
        return entries.map { line in
            guard let sid = line.sourceItemId, let inside = idx.contents[sid] else { return line }
            var l = line
            l.weight = (line.weight.isFinite ? max(0, line.weight) : 0) + Library.contentsWeight(inside)
            return l
        }
    }

    static func contentsWeight(_ contents: [KitContent]) -> Double {
        contents.filter { !$0.takenOut }.reduce(0) { sum, c in
            let w = c.thing.weight.isFinite ? max(0, c.thing.weight) : 0
            return sum + w * effectiveQty(c.thing, 0)
        }
    }

    /// The templates a thing inside a kit ALSO sits on by itself — pointed out on its
    /// page ("Also on Common base on its own"): a trip packs its kit instead (see
    /// `templatesForTrips`). His bag list is never one of them.
    public func kitAlsoOn(thingId: String) -> [String] {
        guard kitHolding(thingId: thingId) != nil else { return [] }
        return listsOf(itemId: thingId).filter { $0 != "Bags" }
    }

    /// Why a thing cannot go in this kit, in his words — "" when it can.
    public func kitRefusal(thingId: String, kitId: String, index: KitIndex? = nil) -> String {
        guard let thing = items.first(where: { $0.id == thingId }),
              let kit = items.first(where: { $0.id == kitId }) else { return "That thing is gone." }
        let idx = index ?? kitIndex()
        let bagIds = Set(bags().map(\.id))
        if thingId == kitId { return "A thing cannot go inside itself." }
        if bagIds.contains(kitId) { return "A bag holds its things by itself." }
        if bagIds.contains(thingId) { return "A bag cannot go inside a kit." }
        if thing.itemType == "reminder" { return "A to-do cannot go inside a kit." }
        if let holder = idx.holder[kitId], let outer = items.first(where: { $0.id == holder }) {
            return "\(kit.name) is inside \(outer.name): a kit cannot go inside another kit."
        }
        if idx.isKit(thingId) { return "\(thing.name) holds things itself: a kit cannot go inside another kit." }
        return ""
    }

    /// The things that can go in this kit — every thing but itself, his bags, to-dos and
    /// kits, A–Z. A thing in another kit is offered too: it moves (one kit at most).
    public func kitCandidates(kitId: String) -> [Item] {
        let idx = kitIndex()
        let mine = Set((idx.contents[kitId] ?? []).map(\.thing.id))
        return items
            .filter { !mine.contains($0.id) && kitRefusal(thingId: $0.id, kitId: kitId, index: idx).isEmpty }
            .stableSorted(compare: { a, b in jsLocaleCompare(a.name, b.name, sensitivity: .base) })
    }

    // MARK: - Changing a kit

    /// What a kit's page saves: what is inside, in his order, which of them are taken
    /// out, and "Check before each trip". A thing that cannot go in (`kitRefusal`) is left
    /// out; one that was in another kit leaves it. Nothing inside = a plain thing again.
    /// Returns whether anything was written.
    @discardableResult
    public mutating func setKit(kitId: String, contents ids: [String], takenOut: Set<String> = [], check: Bool = false) -> Bool {
        guard let k = items.firstIndex(where: { $0.id == kitId }) else { return false }
        let idx = kitIndex()
        var seen = Set<String>()
        let keep = ids.filter { seen.insert($0).inserted && kitRefusal(thingId: $0, kitId: kitId, index: idx).isEmpty }
        var changed = false
        // Out of any other kit first: a thing is in one kit at most.
        for n in items.indices where n != k && !Library.listedContents(items[n]).isEmpty {
            let had = Library.listedContents(items[n])
            let left = had.filter { !keep.contains($0) }
            guard left != had else { continue }
            Library.writeKit(&items[n], contents: left,
                             out: Set(Library.kitIds(items[n].extra[KIT_OUT_KEY])), check: Library.kitCheck(items[n]))
            changed = true
        }
        let before = items[k].extra
        Library.writeKit(&items[k], contents: keep, out: takenOut, check: check)
        return changed || items[k].extra != before
    }

    /// Put one thing in a kit (at the end), moving it out of any other.
    @discardableResult
    public mutating func addToKit(kitId: String, thingId: String) -> Bool {
        guard let kit = items.first(where: { $0.id == kitId }),
              kitRefusal(thingId: thingId, kitId: kitId).isEmpty else { return false }
        let now = kitContents(kitId: kitId).map(\.thing.id)
        guard !now.contains(thingId) else { return false }
        return setKit(kitId: kitId, contents: now + [thingId],
                      takenOut: Set(Library.kitIds(kit.extra[KIT_OUT_KEY])), check: Library.kitCheck(kit))
    }

    /// Take a thing out of its kit for good (it becomes a thing of its own again).
    @discardableResult
    public mutating func removeFromKit(thingId: String) -> Bool {
        guard let kit = kitHolding(thingId: thingId) else { return false }
        let now = kitContents(kitId: kit.id).map(\.thing.id).filter { $0 != thingId }
        return setKit(kitId: kit.id, contents: now, takenOut: Set(Library.kitIds(kit.extra[KIT_OUT_KEY])),
                      check: Library.kitCheck(kit))
    }

    /// Taken out of its kit for now, or put back. False for a thing in no kit.
    @discardableResult
    public mutating func setTakenOut(thingId: String, _ out: Bool) -> Bool {
        guard let kit = kitHolding(thingId: thingId), let k = items.firstIndex(where: { $0.id == kit.id }) else { return false }
        var gone = Set(Library.kitIds(kit.extra[KIT_OUT_KEY]))
        if out { gone.insert(thingId) } else { gone.remove(thingId) }
        let before = items[k].extra
        Library.writeKit(&items[k], contents: Library.listedContents(kit), out: gone, check: Library.kitCheck(kit))
        return items[k].extra != before
    }

    /// "Check before each trip", on or off.
    @discardableResult
    public mutating func setKitCheck(kitId: String, _ on: Bool) -> Bool {
        guard let k = items.firstIndex(where: { $0.id == kitId }) else { return false }
        let kit = items[k]
        let before = kit.extra
        Library.writeKit(&items[k], contents: Library.listedContents(kit),
                         out: Set(Library.kitIds(kit.extra[KIT_OUT_KEY])), check: on)
        return items[k].extra != before
    }

    /// The three keys, written only when they say something: no contents → none of them.
    static func writeKit(_ kit: inout Item, contents: [String], out: Set<String>, check: Bool) {
        if contents.isEmpty {
            kit.extra[KIT_CONTENTS_KEY] = nil
            kit.extra[KIT_OUT_KEY] = nil
            kit.extra[KIT_CHECK_KEY] = nil
            return
        }
        kit.extra[KIT_CONTENTS_KEY] = JSONValue(contents)
        let gone = contents.filter { out.contains($0) }
        kit.extra[KIT_OUT_KEY] = gone.isEmpty ? JSONValue?.none : JSONValue(gone)
        kit.extra[KIT_CHECK_KEY] = check ? JSONValue.bool(true) : JSONValue?.none
    }

    // MARK: - Building a trip

    /// The templates as a trip is built from them: a thing inside a kit is never a line
    /// of its own. On a template that holds its kit too, it is left out; on one that does
    /// not, its kit takes its place — once per template, with the thing's section and its
    /// "only on some trips" answers there, and the kit's own bag and When.
    public func templatesForTrips() -> [PackList] {
        let lists = resolvedTemplates()
        let idx = kitIndex()
        guard !idx.holder.isEmpty else { return lists }
        var byId: [String: Item] = [:]
        for i in items where byId[i.id] == nil { byId[i.id] = i }
        var memById: [String: Membership] = [:]
        for m in memberships { memById[m.id] = m }
        return lists.map { list in
            var l = list
            let here = Set(list.items.compactMap(\.itemId))
            var placed = Set<String>()
            var rows: [Item] = []
            for row in list.items {
                guard let iid = row.itemId, let kitId = idx.holder[iid] else { rows.append(row); continue }
                if here.contains(kitId) || placed.contains(kitId) { continue }
                guard let kit = byId[kitId] else { continue }
                placed.insert(kitId)
                var m = row.memId.flatMap { memById[$0] } ?? newMembership(itemId: iid, templateId: list.id)
                m.itemId = kitId
                m.container = ""; m.phase = ""; m.qty = ""; m.note = ""; m.itemType = ""
                var r = resolveMembership(kit, m, templateDefaults(list))
                r.itemId = kitId
                r.memId = ""
                rows.append(r)
            }
            l.items = rows
            return l
        }
    }

    /// A trip's lines as a new trip (or a rebuild) makes them: the web app's
    /// `buildTotalEntries` over `templatesForTrips`, and each kit once.
    public func builtLines(_ trip: TripEvent) -> [Item] {
        let lines = buildTotalEntries(trip, templatesForTrips())
        let kits = Set(kitIndex().contents.keys)
        guard !kits.isEmpty else { return lines }
        var seen = Set<String>()
        return lines.filter { line in
            guard let sid = line.sourceItemId, kits.contains(sid) else { return true }
            return seen.insert(sid).inserted
        }
    }

    // MARK: - On a trip

    /// A trip line's kit, as the line shows it — nil for a line that is not a kit (a
    /// thing typed on the trip, a line someone sent, a thing that holds nothing).
    public func kitOnLine(_ line: Item, index: KitIndex? = nil) -> KitOnLine? {
        guard let sid = line.sourceItemId, !sid.isEmpty else { return nil }
        // Most lines are no kit: answered without reading every kit.
        if index == nil, !items.contains(where: { $0.id == sid && !Library.listedContents($0).isEmpty }) { return nil }
        let idx = index ?? kitIndex()
        guard let contents = idx.contents[sid], !contents.isEmpty,
              let kit = items.first(where: { $0.id == sid }) else { return nil }
        let inside = contents.filter { !$0.takenOut }.map(\.thing.id)
        let ticked: Set<String> = line.checked ? Set(inside) : Set(Library.kitIds(line.extra[KIT_TICKED_KEY]))
        return KitOnLine(kit: kit, contents: contents, check: Library.kitCheck(kit), ticked: ticked)
    }

    /// Every kit line of a trip, by line id.
    public func kitLines(tripId: String) -> [String: KitOnLine] {
        guard let trip = trips.first(where: { $0.id == tripId }) else { return [:] }
        let idx = kitIndex()
        guard !idx.contents.isEmpty else { return [:] }
        var out: [String: KitOnLine] = [:]
        for line in trip.entries where out[line.id] == nil {
            if let k = kitOnLine(line, index: idx) { out[line.id] = k }
        }
        return out
    }

    /// A tick on a kit line, by the kit's rule — asked by `setChecked` before it ticks.
    /// With "Check before each trip" the kit is packed only when everything inside it is
    /// ticked: a tick before that is refused (false). An untick starts its contents over.
    mutating func kitAllowsTick(_ checked: Bool, trip t: Int, entry e: Int) -> Bool {
        let line = trips[t].entries[e]
        guard let kit = kitOnLine(line) else { return true }
        if checked { return kit.toTick == 0 }
        trips[t].entries[e].extra[KIT_TICKED_KEY] = nil
        return true
    }

    /// Tick one thing inside a checked kit on a trip, or untick it. The last one ticked
    /// packs the kit; unticking one unpacks it (the others stay ticked).
    @discardableResult
    public mutating func setKitContentTicked(_ on: Bool, tripId: String, entryId: String, contentId: String) -> Bool {
        guard let t = trips.firstIndex(where: { $0.id == tripId }),
              let e = trips[t].entries.firstIndex(where: { $0.id == entryId }),
              !isSetAside(trips[t].entries[e]),
              let kit = kitOnLine(trips[t].entries[e]),
              kit.inside.contains(where: { $0.thing.id == contentId }) else { return false }
        var ticked = kit.ticked
        if on { ticked.insert(contentId) } else { ticked.remove(contentId) }
        let inside = kit.inside.map(\.thing.id)
        let all = inside.allSatisfy { ticked.contains($0) }
        let keep = inside.filter { ticked.contains($0) }
        trips[t].entries[e].checked = all
        trips[t].entries[e].extra[KIT_TICKED_KEY] = all || keep.isEmpty ? JSONValue?.none : JSONValue(keep)
        return true
    }

    /// What is inside a kit line, as lines of their own for Check before you go — never
    /// shown on the trip: "Lighter, in the Camp pouch", in the kit's bag, carrying the
    /// thing's flags, date and kind as they are now (the knife in a pouch in the cabin bag
    /// is stopped at the airport all the same). Things taken out are not in it.
    func insideLines(_ line: Item, index: KitIndex) -> [Item] {
        guard let kit = kitOnLine(line, index: index) else { return [] }
        return kit.inside.map { c in
            var l = line
            l.id = "\(line.id)|\(c.thing.id)"
            l.name = "\(c.thing.name), in the \(kit.kit.name)"
            l.sourceItemId = c.thing.id
            l.restricted = c.thing.restricted
            l.liquid = c.thing.liquid
            l.expiry = c.thing.expiry
            l.category = c.thing.category
            l.retired = c.thing.retired
            return l
        }
    }

    /// Care rows say where a thing inside a kit is: "Hiking · inside the Camp pouch".
    func namingKits(_ rows: [MaintenanceRow]) -> [MaintenanceRow] {
        let idx = kitIndex()
        guard !idx.holder.isEmpty else { return rows }
        return rows.map { row in
            guard let k = idx.holder[row.item.itemId ?? row.item.id], let kit = items.first(where: { $0.id == k }) else { return row }
            var r = row
            let inside = "inside the \(kit.name)"
            r.listName = r.listName.isEmpty ? "Inside the \(kit.name)" : "\(r.listName) · \(inside)"
            return r
        }
    }

    // MARK: - Care

    /// What is worth saying about the things inside a kit, in his words, soonest first:
    /// a Valid until that has passed, or comes before `before` (a trip's last day) — or,
    /// without a day to go by, within 60 days — and care that is overdue or due soon.
    /// Things taken out are not in the kit, so not said.
    public func kitWarnings(kitId: String, today: String, before: String = "") -> [String] {
        kitContents(kitId: kitId).filter { !$0.takenOut }
            .flatMap { Library.contentWarnings($0.thing, today: today, before: before) }
            .stableSorted(by: { a, b in jsStringLess(a.date, b.date) }).map(\.words)
    }

    /// What `kitWarnings` says about ONE thing, with the day each is about (to sort by).
    public static func contentWarnings(_ t: Item, today: String, before: String = "") -> [(date: String, words: String)] {
        var out: [(date: String, words: String)] = []
        if isYMD(t.expiry), let days = daysBetween(today, t.expiry) {
            let soon = isYMD(before) ? !jsStringLess(before, t.expiry) : days <= MAINTENANCE_UPCOMING_DAYS
            if days < 0 {
                out.append((t.expiry, "\(t.name) is out of date"))
            } else if soon {
                out.append((t.expiry, "\(t.name) runs out \(distanceWords(from: today, to: t.expiry))"))
            }
        }
        if let s = maintenanceStatus(t, today), s.scheduled, s.state == "overdue" || s.state == "soon" {
            out.append((s.nextDue, s.state == "overdue" ? "\(t.name) is overdue for care" : "\(t.name) needs care soon"))
        }
        return out
    }
}
