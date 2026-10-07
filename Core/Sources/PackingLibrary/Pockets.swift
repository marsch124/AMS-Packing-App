import Foundation
import PackingCore

// Bag pockets and "Where is my charger?" — stop B of his idea plan (7 Oct 2026, idea 5:
// "every bag gets its pockets"). A bag's page lists its pockets (main, front pocket, lid,
// shoe compartment); a thing can have a usual pocket; ticking a line on a trip offers the
// bag's pockets in one short row; and on site he asks "Where is my charger?" — Siri, or
// Search — and hears "Backpack, front pocket".
//
// All of it lives in extra keys, so the web app's model (PackingCore) is untouched and an
// absent key changes nothing: a bag with no pockets, a thing with no usual pocket and a
// line with no pocket are exactly what they were before 0.69. The keys travel with the
// records they sit on — synced, backed up and restored like the rest.

/// A bag's extra key: its pockets, in his order (their names).
public let POCKETS_KEY = "pockets"
/// A thing's extra key: the pocket of its usual bag it usually goes in.
public let USUAL_POCKET_KEY = "usualPocket"
/// A trip line's extra key: the pocket it went into on the way out.
public let POCKET_KEY = "pocket"
/// A trip line's extra key: the pocket it went into for the way home (Pack to go home
/// keeps its own, as it keeps its own ticks — the way out stays as it was).
public let HOME_POCKET_KEY = "homePocket"

extension Library {
    // MARK: - A bag's pockets

    /// A bag's pockets, in his order. None = the bag as it always was.
    public static func pockets(of bag: Item) -> [String] {
        (bag.extra[POCKETS_KEY]?.arrayValue ?? []).compactMap { $0.stringValue }.map(jsTrim).filter { !$0.isEmpty }
    }

    /// The bag of his by this name — its own record, which holds the pockets.
    func bagRecord(named name: String) -> Item? {
        let key = normName(name)
        guard !key.isEmpty, let bag = bags().first(where: { normName($0.name) == key }) else { return nil }
        return items.first { $0.id == bag.id } ?? bag
    }

    /// The pockets of the bag with this name ([] for a name that is not one of his bags).
    public func pockets(bag name: String) -> [String] {
        bagRecord(named: name).map(Library.pockets(of:)) ?? []
    }

    public func pockets(bagId: String) -> [String] {
        items.first { $0.id == bagId }.map(Library.pockets(of:)) ?? []
    }

    /// Every bag's pockets at once, by the bag's name as `normName` sees it — for a
    /// screen that asks for many lines (asking `pockets(bag:)` per line resolves the bag
    /// list each time). Only bags that have pockets.
    public func pocketsByBag() -> [String: [String]] {
        var out: [String: [String]] = [:]
        let byId = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for bag in bags() {
            let mine = Library.pockets(of: byId[bag.id] ?? bag)
            let key = normName(bag.name)
            if !mine.isEmpty, out[key] == nil { out[key] = mine }
        }
        return out
    }

    private mutating func storePockets(bagId: String, _ list: [String]) -> Bool {
        guard let n = items.firstIndex(where: { $0.id == bagId }) else { return false }
        items[n].extra[POCKETS_KEY] = list.isEmpty ? nil : .array(list.map(JSONValue.string))
        return true
    }

    /// A new pocket at the end of the bag's list. Refused: no name, not one of his bags,
    /// or a pocket of that name already (as `normName` sees it).
    @discardableResult
    public mutating func addPocket(bagId: String, name: String) -> Bool {
        let clean = jsTrim(name)
        guard !clean.isEmpty, bags().contains(where: { $0.id == bagId }) else { return false }
        var list = pockets(bagId: bagId)
        guard !list.contains(where: { normName($0) == normName(clean) }) else { return false }
        list.append(clean)
        return storePockets(bagId: bagId, list)
    }

    /// A pocket's new name — carried to every thing that usually goes in it and every
    /// trip line packed in it (his rule for bags, 2026-09-26: a rename reaches all trips),
    /// or nothing would be in the renamed pocket any more. Refused: no name, or another
    /// pocket of the bag already called that. Changing only the capitals is a rename.
    @discardableResult
    public mutating func renamePocket(bagId: String, from old: String, to new: String) -> Bool {
        let clean = jsTrim(new)
        var list = pockets(bagId: bagId)
        guard !clean.isEmpty, let at = list.firstIndex(where: { normName($0) == normName(old) }),
              !list.indices.contains(where: { $0 != at && normName(list[$0]) == normName(clean) }),
              let bag = items.first(where: { $0.id == bagId }) else { return false }
        let was = list[at]
        guard was != clean else { return true }
        list[at] = clean
        _ = storePockets(bagId: bagId, list)
        carryPocket(bag: bag.name, from: was, to: clean)
        return true
    }

    /// Move a pocket within the bag's list (Up on the bag's page).
    @discardableResult
    public mutating func movePocket(bagId: String, from: Int, to: Int) -> Bool {
        var list = pockets(bagId: bagId)
        guard list.indices.contains(from), list.indices.contains(to), from != to else { return false }
        let p = list.remove(at: from)
        list.insert(p, at: to)
        return storePockets(bagId: bagId, list)
    }

    /// Take a pocket away. A thing that usually went in it, and a line packed in it, are
    /// then simply in the bag — never in a pocket that is not there.
    @discardableResult
    public mutating func removePocket(bagId: String, name: String) -> Bool {
        var list = pockets(bagId: bagId)
        guard let at = list.firstIndex(where: { normName($0) == normName(name) }),
              let bag = items.first(where: { $0.id == bagId }) else { return false }
        let was = list.remove(at: at)
        _ = storePockets(bagId: bagId, list)
        carryPocket(bag: bag.name, from: was, to: "")
        return true
    }

    /// Every pocket named `old` in the bag called `bag` becomes `new` ("" = none): the
    /// things' usual pockets and every trip line's two pockets (way out, way home).
    mutating func carryPocket(bag: String, from old: String, to new: String) {
        let b = normName(bag), o = normName(old)
        guard !b.isEmpty, !o.isEmpty else { return }
        func swap(_ extra: inout [String: JSONValue], _ key: String) {
            guard let v = extra[key]?.stringValue, normName(v) == o else { return }
            extra[key] = new.isEmpty ? nil : .string(new)
        }
        for n in items.indices where normName(items[n].container) == b { swap(&items[n].extra, USUAL_POCKET_KEY) }
        for t in trips.indices {
            for e in trips[t].entries.indices where normName(trips[t].entries[e].container) == b {
                swap(&trips[t].entries[e].extra, POCKET_KEY)
                swap(&trips[t].entries[e].extra, HOME_POCKET_KEY)
            }
        }
    }

    /// A bag is deleted and its things move elsewhere: the pockets they were in were
    /// that bag's, so they go — before the move, while the lines still name the bag.
    mutating func forgetPockets(ofBag name: String) {
        let b = normName(name)
        guard !b.isEmpty else { return }
        for n in items.indices where normName(items[n].container) == b { items[n].extra[USUAL_POCKET_KEY] = nil }
        for t in trips.indices {
            for e in trips[t].entries.indices where normName(trips[t].entries[e].container) == b {
                trips[t].entries[e].extra[POCKET_KEY] = nil
                trips[t].entries[e].extra[HOME_POCKET_KEY] = nil
            }
        }
    }

    // MARK: - A thing's usual pocket

    /// The pocket a thing usually goes in, as stored ("" = none).
    public static func usualPocket(_ thing: Item) -> String {
        jsTrim(thing.extra[USUAL_POCKET_KEY]?.stringValue ?? "")
    }

    /// Set (or, with "", clear) a thing's usual pocket on the thing itself — the thing's
    /// page saves it this way, with the rest of the page.
    public static func setUsualPocket(_ thing: inout Item, _ pocket: String) {
        let clean = jsTrim(pocket)
        thing.extra[USUAL_POCKET_KEY] = clean.isEmpty ? nil : .string(clean)
    }

    /// The pocket a thing usually goes in — only while its usual bag HAS that pocket
    /// (a pocket taken away, or a new usual bag, leaves the thing simply in its bag).
    public func usualPocket(thingId: String) -> String {
        guard let thing = items.first(where: { $0.id == thingId }) else { return "" }
        let p = Library.usualPocket(thing)
        guard !p.isEmpty else { return "" }
        return pockets(bag: thing.container).first { normName($0) == normName(p) } ?? ""
    }

    /// Set a thing's usual pocket: one of its usual bag's pockets, or "" for none.
    @discardableResult
    public mutating func setUsualPocket(thingId: String, pocket: String) -> Bool {
        guard let n = items.firstIndex(where: { $0.id == thingId }) else { return false }
        let clean = jsTrim(pocket)
        if !clean.isEmpty {
            guard let hit = pockets(bag: items[n].container).first(where: { normName($0) == normName(clean) }) else { return false }
            Library.setUsualPocket(&items[n], hit)
        } else {
            Library.setUsualPocket(&items[n], "")
        }
        return true
    }

    // MARK: - A trip line's pocket

    public static func pocket(_ line: Item) -> String { jsTrim(line.extra[POCKET_KEY]?.stringValue ?? "") }
    public static func homePocket(_ line: Item) -> String { jsTrim(line.extra[HOME_POCKET_KEY]?.stringValue ?? "") }

    /// The pocket a line goes into when he says nothing: its thing's usual pocket, when
    /// the line is packed in the thing's usual bag and that bag has the pocket. "" else.
    public func suggestedPocket(for line: Item) -> String {
        guard let src = line.sourceItemId, !src.isEmpty,
              let thing = items.first(where: { $0.id == src }),
              normName(thing.container) == normName(line.container) else { return "" }
        return usualPocket(thingId: src)
    }

    /// Which pocket a line went into on the way out ("" = just in the bag).
    @discardableResult
    public mutating func setPocket(_ pocket: String, tripId: String, entryId: String) -> Bool {
        notePocket(POCKET_KEY, pocket, tripId: tripId, entryId: entryId)
    }

    /// Which pocket a line went into for the way home ("" = just in the bag).
    @discardableResult
    public mutating func setHomePocket(_ pocket: String, tripId: String, entryId: String) -> Bool {
        notePocket(HOME_POCKET_KEY, pocket, tripId: tripId, entryId: entryId)
    }

    private mutating func notePocket(_ key: String, _ pocket: String, tripId: String, entryId: String) -> Bool {
        guard let t = trips.firstIndex(where: { $0.id == tripId }),
              let e = trips[t].entries.firstIndex(where: { $0.id == entryId }) else { return false }
        let clean = jsTrim(pocket)
        // The line only, never the trip's head: like a tick, one small record, so two
        // devices choosing pockets on different lines both win.
        trips[t].entries[e].extra[key] = clean.isEmpty ? nil : .string(clean)
        return true
    }

    /// Ticked on the way out with no pocket said yet: the usual one, so most lines need
    /// no tap at all ("A thing can have a usual pocket, so most need no tap at all").
    mutating func prechoosePocket(trip t: Int, entry e: Int) {
        guard Library.pocket(trips[t].entries[e]).isEmpty else { return }
        let usual = suggestedPocket(for: trips[t].entries[e])
        if !usual.isEmpty { trips[t].entries[e].extra[POCKET_KEY] = .string(usual) }
    }

    /// Packed for home with no home pocket said yet: the pocket it went out in, when the
    /// bag still has it — else its usual one.
    mutating func prechooseHomePocket(trip t: Int, entry e: Int) {
        let line = trips[t].entries[e]
        guard Library.homePocket(line).isEmpty else { return }
        let here = pockets(bag: line.container)
        let out = Library.pocket(line)
        let pick = here.first { normName($0) == normName(out) } ?? suggestedPocket(for: line)
        if !pick.isEmpty { trips[t].entries[e].extra[HOME_POCKET_KEY] = .string(pick) }
    }

    /// "Backpack · Front pocket", "Backpack", "Front pocket", or "" — a bag and a pocket
    /// as a line shows them.
    public static func bagAndPocket(_ bag: String, _ pocket: String) -> String {
        [jsTrim(bag), jsTrim(pocket)].filter { !$0.isEmpty }.joined(separator: " \u{00B7} ")
    }
}

// MARK: - Where is my …?

/// The answer to "Where is my charger?" — for the trip under way, else the thing's usual
/// bag and pocket.
public struct WhereAnswer: Equatable, Sendable {
    public enum Kind: String, Equatable, Sendable {
        /// Ticked on the trip under way: in this bag (and pocket).
        case packed
        /// Packed for the way home: in this bag (and pocket).
        case packedHome
        /// On the trip under way but not ticked: where it GOES.
        case notPacked
        /// No trip under way (or not on it): where it usually goes.
        case usual
    }
    public var kind: Kind
    /// The thing's (or line's) name, as he wrote it.
    public var name: String
    public var bag: String
    public var pocket: String
    /// The trip under way ("" for the usual answer).
    public var tripName: String

    /// What the screen shows: "Backpack · Front pocket" ("Not in a bag" for none).
    public var shown: String {
        bag.isEmpty && pocket.isEmpty ? "Not in a bag" : Library.bagAndPocket(bag, pocket)
    }

    /// What Siri says: "Backpack, front pocket." — the pocket's first capital softened
    /// ("Front pocket" → "front pocket"; "USB pocket" stays as it is).
    public var said: String {
        let place: String
        if bag.isEmpty && pocket.isEmpty { place = "not in a bag" }
        else if pocket.isEmpty { place = bag }
        else if bag.isEmpty { place = WhereAnswer.soft(pocket) }
        else { place = "\(bag), \(WhereAnswer.soft(pocket))" }
        switch kind {
        case .packed, .packedHome: return bag.isEmpty && pocket.isEmpty ? "Packed, but not in a bag." : "\(place)."
        case .notPacked: return bag.isEmpty && pocket.isEmpty ? "Not packed yet." : "Not packed yet. It goes in \(place)."
        case .usual: return bag.isEmpty && pocket.isEmpty ? "It has no usual bag." : "Usually in \(place)."
        }
    }

    static func soft(_ s: String) -> String {
        let c = Array(s)
        guard c.count >= 2, c[0].isUppercase, c[1].isLowercase else { return s }
        return c[0].lowercased() + String(c.dropFirst())
    }
}

extension Library {
    /// The trip under way today: begun, and its last day not yet past (the last day
    /// counts — he asks on the way home too). Two at once: the one that began last.
    public func tripUnderWay(today: String) -> TripEvent? {
        trips.filter { t in
            let start = jsTrim(t.startDate), end = jsTrim(t.endDate).isEmpty ? start : jsTrim(t.endDate)
            return isYMD(start) && start <= today && today <= end
        }
        .max { $0.startDate < $1.startDate }
    }

    /// Where is the thing called this? On the trip under way: its line there — packed for
    /// home, ticked, or still to go. Otherwise (no trip under way, or not on it): the
    /// thing's usual bag and pocket. Names match whole first ("charger" is not "Phone
    /// charger" when a "Charger" exists), then by part. Nil: nothing by that name.
    public func whereIs(_ words: String, today: String) -> WhereAnswer? {
        let needle = normName(words)
        guard !needle.isEmpty else { return nil }
        let trip = tripUnderWay(today: today)
        let lines = trip?.entries ?? []
        func best<T>(_ all: [T], _ name: (T) -> String) -> T? {
            all.first { normName(name($0)) == needle }
                ?? all.filter { normName(name($0)).contains(needle) }.min { name($0).count < name($1).count }
        }
        // A line on the trip under way, or a thing — whichever names it more closely.
        let line = best(lines.filter { !isSetAside($0) }, { $0.name })
        let thing = best(items, { $0.name })
        if let line, let trip,
           normName(line.name) == needle || thing == nil || normName(thing!.name) != needle {
            return answer(line: line, trip: trip)
        }
        guard let thing else { return nil }
        return whereIs(thingId: thing.id, today: today)
    }

    /// Where is this thing? Its line on the trip under way, else its usual bag and pocket.
    public func whereIs(thingId: String, today: String) -> WhereAnswer? {
        guard let thing = items.first(where: { $0.id == thingId }) else { return nil }
        if let trip = tripUnderWay(today: today),
           let line = trip.entries.first(where: { $0.sourceItemId == thingId && !isSetAside($0) }) {
            return answer(line: line, trip: trip)
        }
        return WhereAnswer(kind: .usual, name: thing.name, bag: jsTrim(thing.container),
                           pocket: usualPocket(thingId: thingId), tripName: "")
    }

    private func answer(line: Item, trip: TripEvent) -> WhereAnswer {
        if Library.isPackedHome(line) {
            return WhereAnswer(kind: .packedHome, name: line.name, bag: jsTrim(line.container),
                               pocket: Library.homePocket(line), tripName: trip.name)
        }
        if line.checked {
            return WhereAnswer(kind: .packed, name: line.name, bag: jsTrim(line.container),
                               pocket: Library.pocket(line), tripName: trip.name)
        }
        return WhereAnswer(kind: .notPacked, name: line.name, bag: jsTrim(line.container),
                           pocket: suggestedPocket(for: line), tripName: trip.name)
    }
}
