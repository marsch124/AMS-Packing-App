import Foundation
import PackingCore

// 0.126 — Unpack (his idea 1 of 12 Nov 2026): back home, tick each thing back into the room it lives in.
// The trip's packed lines, grouped by the thing's room at home (its `storage`, the inventory's Room) and
// shown with its spot; "All back" per room; "Still in the bag · N". Something bought on site has no room
// yet: "Give it a room" makes it one of his things, kept in that room. Used up is left out: it is gone.
// The ticks are the trip line's own (`unpacked`), as the way home's are — the way home packs at the
// hotel, this unpacks at HOME. Home shows a quiet line ("3 things still in the bag from Torremolinos")
// while something is left, for a month after the trip, until all is back or he says Done.

/// A line's extra key: true once it is back in its room at home.
public let UNPACKED_KEY = "unpacked"
/// A trip's extra key: true when he closed Unpack with "Done" while things were left — Home stops asking.
public let UNPACK_DONE_KEY = "unpackDone"
/// How long after its last day Home still reminds of a trip's bag.
public let UNPACK_NUDGE_DAYS = 30
/// The heading of lines with no room at home yet.
public let UNPACK_NO_ROOM = "No room yet"

extension Library {
    public struct UnpackGroup: Equatable, Sendable {
        /// The room's name, or `UNPACK_NO_ROOM`.
        public var room: String
        public var lines: [Item]
    }

    public struct UnpackNudge: Equatable, Sendable {
        public var tripId: String
        public var name: String
        public var left: Int
        public var says: String { "\(left) \(left == 1 ? "thing" : "things") still in the bag from \(name)" }
    }

    public static func isUnpacked(_ line: Item) -> Bool { line.extra[UNPACKED_KEY]?.boolValue == true }

    /// What comes out of the bags: what went (ticked, not set aside, not a reminder) and what was bought
    /// on site — less what was used up or left there.
    public func unpackLines(tripId: String) -> [Item] {
        guard let trip = trips.first(where: { $0.id == tripId }) else { return [] }
        return trip.entries.filter { line in
            (line.checked && !isSetAside(line) && !Library.isReminder(line) || Library.isBoughtOnSite(line))
                && !Library.isUsedUp(line)
        }
    }

    /// The room a line's thing lives in at home ("" = none yet).
    public func unpackRoom(_ line: Item) -> String {
        guard let id = thingBehind(line), let it = items.first(where: { $0.id == id }) else { return "" }
        return jsTrim(it.storage)
    }

    /// The spot in that room ("top shelf"), "" when none.
    public func unpackSpot(_ line: Item) -> String {
        guard let id = thingBehind(line), let it = items.first(where: { $0.id == id }) else { return "" }
        return Library.spot(it)
    }

    /// The lines by room: his rooms in his order, then any other A–Z, "No room yet" last.
    public func unpackGroups(tripId: String) -> [UnpackGroup] {
        var byKey: [String: UnpackGroup] = [:]
        var order: [String] = []
        for line in unpackLines(tripId: tripId) {
            let room = unpackRoom(line)
            let key = normName(room)
            if byKey[key] == nil { byKey[key] = UnpackGroup(room: room.isEmpty ? UNPACK_NO_ROOM : room, lines: []); order.append(key) }
            byKey[key]!.lines.append(line)
        }
        let mine = storagePlaces().map(normName)
        let sorted = order.sorted { a, b in
            if a.isEmpty != b.isEmpty { return b.isEmpty }
            let ia = mine.firstIndex(of: a) ?? Int.max, ib = mine.firstIndex(of: b) ?? Int.max
            if ia != ib { return ia < ib }
            return jsLocaleCompare(byKey[a]!.room, byKey[b]!.room) < 0
        }
        return sorted.map { byKey[$0]! }
    }

    /// Unpacking in numbers: back of all.
    public func unpackProgress(tripId: String) -> (done: Int, total: Int) {
        let all = unpackLines(tripId: tripId)
        return (all.filter(Library.isUnpacked).count, all.count)
    }

    /// Unpack is offered on the trip's page once the trip has set off, while it has something to unpack.
    public func unpackOffered(tripId: String, today: String, time: String = END_OF_DAY) -> Bool {
        guard let trip = trips.first(where: { $0.id == tripId }) else { return false }
        return Library.hasSetOff(trip, today: today, time: time) && !unpackLines(tripId: tripId).isEmpty
    }

    @discardableResult
    public mutating func setUnpacked(_ on: Bool, tripId: String, entryId: String) -> Bool {
        guard let t = trips.firstIndex(where: { $0.id == tripId }),
              let k = trips[t].entries.firstIndex(where: { $0.id == entryId }) else { return false }
        trips[t].entries[k].extra[UNPACKED_KEY] = on ? .bool(true) : nil
        trips[t].updatedAt = nowISO()
        return true
    }

    /// "All back" for one room's heading: every line in it ticked. Returns how many changed.
    @discardableResult
    public mutating func setRoomUnpacked(room: String, tripId: String) -> Int {
        guard let group = unpackGroups(tripId: tripId).first(where: { $0.room == room }) else { return 0 }
        let ids = group.lines.filter { !Library.isUnpacked($0) }.map(\.id)
        for id in ids { setUnpacked(true, tripId: tripId, entryId: id) }
        return ids.count
    }

    /// "Done" with things left: Home stops reminding. Unticking or ticking later is still possible.
    public mutating func setUnpackDone(_ on: Bool, tripId: String) {
        guard let t = trips.firstIndex(where: { $0.id == tripId }) else { return }
        trips[t].extra[UNPACK_DONE_KEY] = on ? .bool(true) : nil
        trips[t].updatedAt = nowISO()
    }

    /// Something bought on site, given a room: it becomes one of his things (or the one he already has by
    /// that name), kept in that room, and the line now stands for it. Returns the thing's id.
    @discardableResult
    public mutating func giveRoom(_ room: String, tripId: String, entryId: String) -> String? {
        let clean = jsTrim(room)
        guard !clean.isEmpty, let t = trips.firstIndex(where: { $0.id == tripId }),
              let k = trips[t].entries.firstIndex(where: { $0.id == entryId }) else { return nil }
        let line = trips[t].entries[k]
        var id = thingBehind(line)
        if id == nil {
            id = items.first(where: { normName($0.name) == normName(line.name) })?.id ?? addThing(name: line.name)?.id
        }
        guard let thing = id else { return nil }
        _ = updateThing(id: thing) { $0.storage = clean }
        keepRoom(clean)
        trips[t].entries[k].sourceItemId = thing
        trips[t].updatedAt = nowISO()
        return thing
    }

    /// Home's quiet line: the trip back home most recently (its last day before today, at most
    /// `UNPACK_NUDGE_DAYS` ago) with things still in the bag and not closed with Done. Nil when none.
    public func unpackNudge(today: String) -> UnpackNudge? {
        guard isYMD(today), let floor = ymdAdd(today, -UNPACK_NUDGE_DAYS) else { return nil }
        let back = trips.filter { t in
            let last = Library.lastDay(t)
            return isYMD(last) && jsStringLess(last, today) && !jsStringLess(last, floor)
                && t.extra[UNPACK_DONE_KEY]?.boolValue != true
        }
        .sorted { Library.lastDay($0) > Library.lastDay($1) }
        for t in back {
            let p = unpackProgress(tripId: t.id)
            // A trip where nothing was ever unpacked AND nothing went is no reminder.
            if p.total > p.done {
                let name = jsTrim(t.destination).isEmpty ? t.name : jsTrim(t.destination)
                return UnpackNudge(tripId: t.id, name: name, left: p.total - p.done)
            }
        }
        return nil
    }

    /// Adds days to "YYYY-MM-DD" (negative = back).
    func ymdAdd(_ ymd: String, _ days: Int) -> String? {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC"); f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: ymd), let moved = f.calendar.date(byAdding: .day, value: days, to: d) else { return nil }
        return f.string(from: moved)
    }
}

// 0.126 — the bag label (his idea 6 of 12 Nov 2026): a bag's thing label, scanned, opens the bag's page,
// which shows what is in it NOW — the ticked lines packed in it on the trip under way or the next one —
// else what is usually in it.

extension Library {
    public struct BagNow: Equatable, Sendable {
        public var tripId: String
        public var tripName: String
        public var lines: [Item]
    }

    /// Is this thing one of his bags?
    public func isBag(_ id: String) -> Bool { bags().contains { $0.id == id } }

    /// What is in a bag right now: the trip under way (set off, last day not passed) first, else the
    /// next one not reviewed — its ticked lines (not set aside) packed in this bag. Nil when no such trip
    /// has anything in it.
    public func bagNow(name: String, today: String) -> BagNow? {
        let key = normName(name)
        guard !key.isEmpty else { return nil }
        let open = trips.filter { !Library.isReviewed($0) && isYMD(jsTrim($0.startDate)) && !jsStringLess(Library.lastDay($0), today) }
        let underWay = open.filter { Library.hasSetOff($0, today: today) }.sorted { $0.startDate > $1.startDate }
        let ahead = open.filter { !Library.hasSetOff($0, today: today) }.sorted { $0.startDate < $1.startDate }
        for t in underWay + ahead {
            let lines = t.entries.filter { $0.checked && !isSetAside($0) && normName($0.container) == key }
            if !lines.isEmpty { return BagNow(tripId: t.id, tripName: t.name, lines: lines) }
        }
        return nil
    }
}
