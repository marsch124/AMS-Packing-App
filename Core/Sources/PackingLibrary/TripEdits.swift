import Foundation
import PackingCore

// Changing a trip after it is made — the web app's trip menu, which the native app
// lacked (the gap list, 2026-09-26). First: getting rid of one.

extension Library {
    /// Delete a trip: it and its lines go. Nothing else is touched — the things,
    /// the lists and the to-dos stay. A trip that is not there: false.
    @discardableResult
    public mutating func deleteTrip(id: String) -> Bool {
        guard trips.contains(where: { $0.id == id }) else { return false }
        trips.removeAll { $0.id == id }
        return true
    }
}

// Where a thing is kept, set from the trip itself — his ask (2026-09-26), packing
// by From where: "No place set … I want to define a place for these items with one
// click or two", not by leaving the trip to find the thing.

extension Library {
    /// The thing a trip line came from, if it came from a list.
    public func thingId(of line: Item) -> String? {
        guard let lid = line.sourceListId, !lid.isEmpty,
              let sid = line.sourceItemId, !sid.isEmpty,
              let row = resolvedTemplate(id: lid)?.items.first(where: { $0.id == sid }) else { return nil }
        return row.itemId
    }

    /// Set where a line's thing is kept. The THING gets the place (so every later
    /// trip knows it) and so does every line of that thing on this trip — the same
    /// thing can sit on a trip twice, from two lists. A line typed on the trip has
    /// no thing behind it and changes alone. A place he has not used before joins
    /// his list of places.
    @discardableResult
    public mutating func setPlace(_ place: String, tripId: String, entryId: String) -> Bool {
        let clean = jsTrim(place)
        guard !clean.isEmpty,
              let t = trips.firstIndex(where: { $0.id == tripId }),
              let e = trips[t].entries.firstIndex(where: { $0.id == entryId }) else { return false }
        if let thing = thingId(of: trips[t].entries[e]) {
            _ = updateThing(id: thing) { $0.storage = clean }
            for n in trips[t].entries.indices where thingId(of: trips[t].entries[n]) == thing {
                trips[t].entries[n].storage = clean
            }
        } else {
            trips[t].entries[e].storage = clean
        }
        trips[t].updatedAt = nowISO()
        let known = storagePlaces()
        if !known.contains(where: { normName($0) == normName(clean) }) {
            _ = setNames("places", known + [clean])
        }
        return true
    }
}
