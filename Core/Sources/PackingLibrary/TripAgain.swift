import Foundation
import PackingCore

// "Start a new trip from this one — same list, fresh ticks": the web app's trip
// menu. A preset only remembers the answers on Create; this copies the LIST as it
// finally ended up, after a week of corrections. What belonged to the old trip
// rather than to the kind of trip it was stays behind: its dates, weather, place
// on the map, ticks and review.

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
                            season: old.season, contexts: old.contexts, weatherOn: old.weatherOn,
                            catering: old.catering, laundry: old.laundry, destination: old.destination)
        copy.extra[LAUNDRY_NIGHTS_KEY] = old.extra[LAUNDRY_NIGHTS_KEY]
        copy.entries = old.entries.map { line in
            var fresh = line
            fresh.id = PackingEnv.makeId()
            fresh.checked = false
            fresh.used = nil
            fresh.extra["packedAt"] = nil
            return fresh
        }
        trips.append(copy)
        return copy
    }
}
