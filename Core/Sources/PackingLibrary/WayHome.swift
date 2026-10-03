import Foundation
import PackingCore

// Pack to go home — his pre-trip idea 13 (2 Oct 2026). The way out is the list; the
// way home is what actually went, plus what was bought on site, less what was used up
// or left behind. Its own ticks (the way-out ticks stay as they were, for the
// review), kept in the lines' extra keys so the web app's model is untouched.

/// A line's extra key: packed for the way home.
public let HOME_KEY = "packedHome"
/// A line's extra key: used up or left on site — nothing to pack home.
public let USED_UP_KEY = "usedUp"

extension Library {
    /// What goes home: the lines that went (ticked on the way out, not set aside),
    /// and everything bought on site, in the list's order.
    public func homeLines(tripId: String) -> [Item] {
        guard let trip = trips.first(where: { $0.id == tripId }) else { return [] }
        return trip.entries.filter { ($0.checked && !isSetAside($0)) || Library.isBoughtOnSite($0) }
    }

    public static func isPackedHome(_ line: Item) -> Bool { line.extra[HOME_KEY]?.boolValue == true }
    public static func isUsedUp(_ line: Item) -> Bool { line.extra[USED_UP_KEY]?.boolValue == true }

    /// The way home in numbers: packed of what is still to come home.
    public func homeProgress(tripId: String) -> (done: Int, total: Int) {
        let mine = homeLines(tripId: tripId).filter { !Library.isUsedUp($0) }
        return (mine.filter(Library.isPackedHome).count, mine.count)
    }

    @discardableResult
    public mutating func setPackedHome(_ on: Bool, tripId: String, entryId: String) -> Bool {
        mark(tripId: tripId, entryId: entryId) { line in
            line.extra[HOME_KEY] = on ? .bool(true) : nil
        }
    }

    /// Used up or left on site: off the way home (and not packed). Again: back on.
    @discardableResult
    public mutating func setUsedUp(_ on: Bool, tripId: String, entryId: String) -> Bool {
        mark(tripId: tripId, entryId: entryId) { line in
            line.extra[USED_UP_KEY] = on ? .bool(true) : nil
            if on { line.extra[HOME_KEY] = nil }
        }
    }

    private mutating func mark(tripId: String, entryId: String, _ change: (inout Item) -> Void) -> Bool {
        guard let t = trips.firstIndex(where: { $0.id == tripId }),
              let k = trips[t].entries.firstIndex(where: { $0.id == entryId }) else { return false }
        change(&trips[t].entries[k])
        trips[t].updatedAt = nowISO()
        return true
    }
}
