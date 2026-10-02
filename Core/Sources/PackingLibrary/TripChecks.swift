import Foundation
import PackingCore

// "Check before you go" — his pre-trip ideas 4 and 5 (2 Oct 2026, before his
// first real trip):
//  • On a plane trip, what is packed in a CABIN bag that the airport stops: a thing
//    not allowed on board (its "Restricted"), and liquids (100 ml at most, in the
//    clear bag).
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
    public enum Why: String, Sendable { case notAllowed, liquid }
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

    /// On a plane trip: what in a cabin bag will be stopped — not allowed on board
    /// first, then the liquids. A line set aside is not packed, so not asked about.
    public func cabinCheck(tripId: String) -> [CabinFlag] {
        guard let trip = trips.first(where: { $0.id == tripId }), trip.transport == "Plane" else { return [] }
        var notAllowed: [CabinFlag] = [], liquids: [CabinFlag] = []
        for line in trip.entries where line.itemType != "reminder" && !isSetAside(line) && isCabin(container: line.container) {
            let thing = thingNow(line)
            if thing.restricted { notAllowed.append(CabinFlag(line: line, thingId: thingToOpen(line), why: .notAllowed)) }
            else if thing.liquid { liquids.append(CabinFlag(line: line, thingId: thingToOpen(line), why: .liquid)) }
        }
        return notAllowed + liquids
    }

    /// What runs out before he is home, and a document within six months of it —
    /// soonest first. The core's `expiringOnTrip` does the judging (parity-checked),
    /// asked about the documents with the end moved six months on. A trip without
    /// dates has nothing to judge against.
    public func dateCheck(tripId: String, todayISO: String? = nil) -> [DateFlag] {
        guard let trip = trips.first(where: { $0.id == tripId }), isYMD(trip.endDate) else { return [] }
        let end = trip.endDate
        // The lines, carrying their thing's date, kind and retirement as they are now.
        let lines: [Item] = trip.entries.filter { !isSetAside($0) }.map { line in
            var l = line
            let t = thingNow(line)
            l.expiry = t.expiry; l.category = t.category; l.retired = t.retired
            return l
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
