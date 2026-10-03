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
/// A line's extra key: a note made while packing to go home — "zip broken", "wash
/// before next trip" (their field test, 3 Oct 2026: "a button for each item to write
/// maintenance in the comment"). It stays on the trip's line; the thing is untouched.
public let HOME_NOTE_KEY = "homeNote"

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

    /// How many of the way home's lines were used up — for the heading ("1/3 · 1 used
    /// up", their field test, 3 Oct 2026), so a line that went off is still accounted for.
    public func homeUsedUp(tripId: String) -> Int {
        homeLines(tripId: tripId).filter(Library.isUsedUp).count
    }

    public static func homeNote(_ line: Item) -> String { line.extra[HOME_NOTE_KEY]?.stringValue ?? "" }

    /// The thing a way-home line came from, when it is still in the library — what
    /// Open opens. Nil for something bought on site or typed on the trip only.
    public func thingBehind(_ line: Item) -> String? {
        guard let src = line.sourceItemId, !src.isEmpty, items.contains(where: { $0.id == src }) else { return nil }
        return src
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

    /// "A button to check off all items" (their field test, 3 Oct 2026): on = every
    /// line still to come home is packed; off = every home tick goes. A used-up line is
    /// left alone — it is not coming home. Returns how many lines changed.
    @discardableResult
    public mutating func setAllPackedHome(_ on: Bool, tripId: String) -> Int {
        let ids = on
            ? homeLines(tripId: tripId).filter { !Library.isUsedUp($0) && !Library.isPackedHome($0) }.map(\.id)
            // Off clears EVERY home tick on the trip, even on a line that is no longer on
            // the way home (its way-out tick taken back): it must not come back ticked.
            : (trips.first { $0.id == tripId }?.entries ?? []).filter(Library.isPackedHome).map(\.id)
        for id in ids { setPackedHome(on, tripId: tripId, entryId: id) }
        return ids.count
    }

    /// The line's note for the way home; an empty one removes it. The thing itself is
    /// not touched — the note belongs to this trip.
    @discardableResult
    public mutating func setHomeNote(_ text: String, tripId: String, entryId: String) -> Bool {
        let note = jsTrim(text)
        return mark(tripId: tripId, entryId: entryId) { line in
            line.extra[HOME_NOTE_KEY] = note.isEmpty ? nil : .string(note)
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
