import Foundation
import PackingCore

// Changing a trip after it is made — the web app's trip menu, which the native app
// lacked (the gap list, 2026-09-26). First: getting rid of one.

extension Library {
    /// Delete a trip: it and its lines go, and so do its photos — the packed bags'
    /// and its lines' — unless something else still shows one (his ask, 4 Oct 2026:
    /// the practice trip was gone, its bag photo stayed behind). The things, the
    /// lists and the to-dos stay. A trip that is not there: false.
    @discardableResult
    public mutating func deleteTrip(id: String) -> Bool {
        guard let trip = trips.first(where: { $0.id == id }) else { return false }
        let mine = Set(trip.entries.flatMap { photoRefs($0) }
                       + (trip.extra[BAG_PHOTOS_KEY]?.objectValue ?? [:]).values.flatMap { Library.bagPhotoIds($0) })
        trips.removeAll { $0.id == id }
        let gone = Set(mine.filter { !photoInUse($0) })
        photos.removeAll { gone.contains($0.id) }
        return true
    }

    /// Photos nothing shows any more — no thing, no trip line, no packed bag — and
    /// at least a day old. Never younger: a photo can arrive from the other device a
    /// little before the trip that shows it.
    public func unusedPhotos(now: Date = PackingEnv.now()) -> [PhotoRecord] {
        let dayAgo = now.addingTimeInterval(-86_400)
        let used = photoIdsInUse()                      // one walk, not one per photo
        return photos.filter { photo in
            guard !used.contains(photo.id) else { return false }
            // A date that cannot be read is no proof of age: kept, never offered.
            guard let made = isoMoment(photo.createdAt) else { return false }
            return made < dayAgo
        }
    }

    /// Take away the photos nothing shows any more. How many went.
    @discardableResult
    public mutating func removeUnusedPhotos(now: Date = PackingEnv.now()) -> Int {
        let gone = Set(unusedPhotos(now: now).map(\.id))
        photos.removeAll { gone.contains($0.id) }
        return gone.count
    }
}

/// The sections folded away on trips, as the trip screen remembers them on this
/// device (his ask, 2026-09-26: "the list is extremely long"): one
/// "<trip id>|<sorting>|<heading>" per line, per trip and per sorting.
///
/// The spec pass (5 Oct 2026): a deleted trip's folds were kept for ever. Now a
/// trip's folds go with it, and every fold made sweeps out those of trips this
/// device no longer has (deleted on the other one, too).
public enum TripFolds {
    public static func key(trip: String, view: String, heading: String) -> String { "\(trip)|\(view)|\(heading)" }

    public static func isFolded(_ raw: String, _ key: String) -> Bool {
        raw.split(separator: "\n").contains { String($0) == key }
    }

    /// Fold or open one section; the folds of trips not in `trips` are dropped.
    public static func toggled(_ raw: String, _ key: String, trips: Set<String>) -> String {
        var keys = raw.split(separator: "\n").map(String.init).filter { trips.contains(tripOf($0)) }
        if let i = keys.firstIndex(of: key) { keys.remove(at: i) } else { keys.append(key) }
        return keys.joined(separator: "\n")
    }

    /// Every fold of one trip taken away — the trip is gone.
    public static func without(trip: String, in raw: String) -> String {
        raw.split(separator: "\n").map(String.init).filter { tripOf($0) != trip }.joined(separator: "\n")
    }

    private static func tripOf(_ key: String) -> String { String(key.prefix { $0 != "|" }) }
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

// A trip's settings, changed after it is made — the gap list's first High item
// (2026-09-27): its name, dates, lists, Quick, transport, season, food, context.
// The list is then rebuilt the web app's way (`regenerated`): ticked, edited and
// hand-added lines stay; new matches arrive; lines no longer asked for go.

extension Library {
    public struct TripRebuilt: Equatable, Sendable {
        public var added: Int
        public var removed: Int
    }

    /// Change a trip and rebuild its list. nil when there is no such trip, or the
    /// change leaves it without a name or without a list to pack from.
    @discardableResult
    public mutating func changeTrip(id: String, _ apply: (inout TripEvent) -> Void) -> TripRebuilt? {
        guard let t = trips.firstIndex(where: { $0.id == id }) else { return nil }
        var trip = trips[t]
        let before = Set(trip.entries.map(\.id))
        apply(&trip)
        trip.name = jsTrim(trip.name)
        guard !trip.name.isEmpty, !trip.activities.isEmpty || trip.mode != "quick" else { return nil }
        trip.nights = nightsBetween(trip.startDate, trip.endDate) ?? 0
        trip.entries = regenerated(trip)
        trip.updatedAt = nowISO()
        trips[t] = trip
        let after = Set(trip.entries.map(\.id))
        return TripRebuilt(added: after.subtracting(before).count, removed: before.subtracting(after).count)
    }
}
