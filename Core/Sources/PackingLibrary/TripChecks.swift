import Foundation
import PackingCore

// "Check before you go" — his pre-trip ideas 4 and 5 (2 Oct 2026, before his
// first real trip):
//  • On a plane trip, what is packed in a CABIN bag that the airport stops: a thing
//    not allowed on board (its "Restricted"), and liquids (100 ml at most, in the
//    clear bag). And (0.76, his yes of 13 Oct 2026) a thing with a BATTERY in a CHECKED
//    bag: airlines want lithium batteries and power banks in the cabin.
//  • What runs out before he is home (a thing's "Valid until"), and a document — a
//    passport, an ID card — that runs out within six months of coming home, since
//    many countries want that much left on it.
//
// Both judge the THING as it is now (its flags, its date, its kind), not the trip
// line's copy: a fix in the thing's page clears the warning at once, ticked line or
// not. And the LINE's bag, because that is where it is packed on this trip.

/// A bag's own word that it goes in the cabin. Kept in the bag's extra keys, so the
/// web app's model is untouched.
public let CABIN_KEY = "cabin"
/// How long a document should still be good after the trip ends.
public let DOCUMENT_MONTHS_LEFT = 6
/// The kind of thing whose date is judged six months on.
public let DOCUMENTS_CATEGORY = "Documents & money"

public struct CabinFlag: Equatable, Sendable {
    /// In a cabin bag: not allowed on board, a liquid. In a checked bag: a battery (0.76).
    public enum Why: String, Sendable { case notAllowed, battery, liquid }
    /// The trip's line.
    public var line: Item
    /// The thing to open to put it right (nil: a thing typed on this trip only).
    public var thingId: String?
    public var why: Why
}

public struct DateFlag: Equatable, Sendable {
    public var line: Item
    public var thingId: String?
    public var expiry: String
    /// A passport, an ID card…: judged six months past the trip.
    public var document: Bool
    /// Already out of date today.
    public var alreadyOut: Bool
    /// Runs out before the trip ends (a document: rather than in the six months after).
    public var beforeHome: Bool
}

extension Library {
    static let cabinWords = ["carry-on", "carry on", "carryon", "hand luggage", "cabin"]

    /// Does this bag go in the cabin? His word on the bag's page; until he gives it,
    /// its name says so ("Carry-on / hand luggage", "Cabin bag").
    public static func isCabinBag(_ bag: Item) -> Bool {
        if let on = bag.extra[CABIN_KEY]?.boolValue { return on }
        return cabinByName(bag.name)
    }

    static func cabinByName(_ name: String) -> Bool {
        let n = normName(name)
        return cabinWords.contains { n.contains($0) }
    }

    /// Is a trip line's bag a cabin bag? His bag's own word — or, for a bag he never
    /// made (the web app's "Carry-on / hand luggage"), its name.
    public func isCabin(container: String) -> Bool {
        if let bag = bags().first(where: { normName($0.name) == normName(container) }) {
            return Library.isCabinBag(items.first { $0.id == bag.id } ?? bag)
        }
        return Library.cabinByName(container)
    }

    /// Say whether a bag goes in the cabin. Only a bag takes it.
    @discardableResult
    public mutating func setBagCabin(id: String, _ on: Bool) -> Bool {
        guard bags().contains(where: { $0.id == id }) else { return false }
        return updateThing(id: id) { $0.extra[CABIN_KEY] = .bool(on) }
    }

    /// Say whether the bag a trip packs into goes in the cabin — from the trip itself
    /// (field test 7.3, 3 Oct 2026: their cabin bag was a name on the lines, not one of
    /// their bags, so there was nowhere to say so). A name that is not a bag yet
    /// becomes one, and then appears in Care → Bags too.
    @discardableResult
    public mutating func setCabin(container: String, _ on: Bool) -> Bool {
        let name = jsTrim(container)
        guard !name.isEmpty, name != "Other" else { return false }
        let bag = bags().first { normName($0.name) == normName(name) } ?? addBag(name: name)
        guard let bag else { return false }
        return setBagCabin(id: bag.id, on)
    }

    /// The thing behind a trip line as it is NOW — or the line itself, for a thing
    /// typed on the trip only.
    func thingNow(_ line: Item) -> Item {
        if let src = line.sourceItemId, let it = items.first(where: { $0.id == src }) { return it }
        return line
    }

    private func thingToOpen(_ line: Item) -> String? {
        guard let src = line.sourceItemId, items.contains(where: { $0.id == src }) else { return nil }
        return src
    }

    /// Is a trip line in a bag at all? "Not in a bag" ("" or "Other") is no bag: on the
    /// cabin's side or the hold's, there is nothing to judge yet.
    static func inABag(_ line: Item) -> Bool {
        let bag = jsTrim(line.container)
        return !bag.isEmpty && bag != "Other"
    }

    /// On a plane trip: what the airport will stop. In a CABIN bag, a thing not allowed on
    /// board and the liquids; in a CHECKED bag — any bag that is not a cabin bag, by the
    /// same rule (`isCabin`) — a thing with a battery (0.76, `BATTERY_KEY`), which must
    /// travel in the cabin. Not allowed first, then the batteries, then the liquids, each
    /// in the trip's order. A line set aside is not packed, so not asked about; a reminder
    /// is never; a line in no bag yet is not judged. What is inside a kit goes where the
    /// kit goes ("Power bank, in the Camp pouch").
    public func cabinCheck(tripId: String) -> [CabinFlag] {
        guard let trip = trips.first(where: { $0.id == tripId }), trip.transport == "Plane" else { return [] }
        var notAllowed: [CabinFlag] = [], batteries: [CabinFlag] = [], liquids: [CabinFlag] = []
        let kits = kitIndex()
        for line in trip.entries where line.itemType != "reminder" && !isSetAside(line) && Library.inABag(line) {
            let thing = thingNow(line)
            // What is inside a kit goes where the kit goes (ThingKits).
            let inside = insideLines(line, index: kits)
            guard isCabin(container: line.container) else {
                // The hold: only a battery is stopped there.
                if Library.hasBattery(thing) { batteries.append(CabinFlag(line: line, thingId: thingToOpen(line), why: .battery)) }
                for c in inside where Library.hasBattery(c) {
                    batteries.append(CabinFlag(line: c, thingId: c.sourceItemId, why: .battery))
                }
                continue
            }
            if thing.restricted { notAllowed.append(CabinFlag(line: line, thingId: thingToOpen(line), why: .notAllowed)) }
            else if thing.liquid { liquids.append(CabinFlag(line: line, thingId: thingToOpen(line), why: .liquid)) }
            for c in inside {
                if c.restricted { notAllowed.append(CabinFlag(line: c, thingId: c.sourceItemId, why: .notAllowed)) }
                else if c.liquid { liquids.append(CabinFlag(line: c, thingId: c.sourceItemId, why: .liquid)) }
            }
        }
        return notAllowed + batteries + liquids
    }

    /// What runs out before he is home, and a document within six months of it —
    /// soonest first. The core's `expiringOnTrip` does the judging (parity-checked),
    /// asked about the documents with the end moved six months on. A trip without
    /// dates has nothing to judge against.
    public func dateCheck(tripId: String, todayISO: String? = nil) -> [DateFlag] {
        guard let trip = trips.first(where: { $0.id == tripId }), isYMD(trip.endDate) else { return [] }
        let end = trip.endDate
        // The lines, carrying their thing's date, kind and retirement as they are now.
        // …and what is inside a kit, by its own date (ThingKits).
        let kits = kitIndex()
        let lines: [Item] = trip.entries.filter { !isSetAside($0) }.flatMap { line -> [Item] in
            var l = line
            let t = thingNow(line)
            l.expiry = t.expiry; l.category = t.category; l.retired = t.retired
            return [l] + insideLines(line, index: kits)
        }
        let byId = Dictionary(trip.entries.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        func flags(_ found: [ExpiringEntry], document: Bool) -> [DateFlag] {
            found.map { e in
                let line = byId[e.entry.id] ?? e.entry
                return DateFlag(line: line, thingId: thingToOpen(line), expiry: e.expiry, document: document,
                                alreadyOut: e.alreadyOut, beforeHome: !jsStringLess(end, e.expiry))
            }
        }
        let docs = lines.filter { $0.category == DOCUMENTS_CATEGORY }
        let gear = lines.filter { $0.category != DOCUMENTS_CATEGORY }
        let all = flags(expiringOnTrip(docs, Library.ymd(end, plusMonths: DOCUMENT_MONTHS_LEFT), todayISO), document: true)
                + flags(expiringOnTrip(gear, end, todayISO), document: false)
        return all.stableSorted(by: { a, b in jsStringLess(a.expiry, b.expiry) })
    }

    /// "2026-11-30" six months on is "2027-05-30"; a day the month lacks becomes its
    /// last ("2026-08-31" → "2027-02-28").
    static func ymd(_ s: String, plusMonths m: Int) -> String {
        let p = s.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return s }
        let total = p[0] * 12 + (p[1] - 1) + m
        let y = total / 12, mo = total % 12 + 1
        var c = DateComponents(); c.year = y; c.month = mo; c.day = 1
        let cal = Calendar(identifier: .gregorian)
        let days = cal.date(from: c).flatMap { cal.range(of: .day, in: .month, for: $0)?.count } ?? 28
        return String(format: "%04d-%02d-%02d", y, mo, min(p[2], days))
    }
}
