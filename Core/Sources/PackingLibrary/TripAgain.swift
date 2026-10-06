import Foundation
import PackingCore

// "Start a new trip from this one — same list, fresh ticks": the web app's trip
// menu. A preset only remembers the answers on Create; this copies the LIST as it
// finally ended up, after a week of corrections. What belonged to the old trip
// rather than to the kind of trip it was stays behind: its dates, weather, place
// on the map, ticks, set-asides, what happened on site, and its review.

extension Library {
    /// The name offered for the copy, as the web app offers it.
    public static func againName(_ name: String) -> String {
        "\(name.isEmpty ? "Trip" : name) (again)"
    }

    /// A new trip with this one's settings and lines, nothing ticked, no dates.
    /// Nil when the trip is not there or the name is empty.
    @discardableResult
    public mutating func startAgain(from id: String, name: String) -> TripEvent? {
        guard let old = trips.first(where: { $0.id == id }) else { return nil }
        let n = jsTrim(name)
        guard !n.isEmpty else { return nil }
        var copy = newEvent(name: n, mode: old.mode, activities: old.activities, transport: old.transport,
                            season: old.season, contexts: old.contexts,
                            activityContexts: old.activityContexts, weatherOn: old.weatherOn,
                            catering: old.catering, laundry: old.laundry, destination: old.destination)
        copy.extra[LAUNDRY_NIGHTS_KEY] = old.extra[LAUNDRY_NIGHTS_KEY]
        // A clean list (the spec pass, 5 Oct 2026): what was decided ON the old trip
        // stays with it — "not this time" was for that time; bought on site, the way
        // home's ticks, used up and its notes happened there. Before, a copied
        // bought-on-site mark made the new trip stand at On site the moment it was made.
        // What the line IS stays: its name, bag, When, quantity, a line typed by hand
        // (still kept by a rebuild), a line changed on the trip.
        copy.entries = old.entries.map { line in
            var fresh = line
            fresh.id = PackingEnv.makeId()
            fresh.checked = false
            fresh.skipped = false
            fresh.used = nil
            for key in ["packedAt", BOUGHT_ON_SITE_KEY, HOME_KEY, USED_UP_KEY, HOME_NOTE_KEY] { fresh.extra[key] = nil }
            return fresh
        }
        trips.append(copy)
        return copy
    }
}
