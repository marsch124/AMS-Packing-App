import Foundation
import PackingCore

// The forecast on a trip: where to keep it, what it says, and what it asks you to
// take. The rules are all in PackingCore (`deriveWeather`, `weatherSuggestions`) —
// this is only the library's way in and out.

extension Library {
    public func trip(_ id: String) -> TripEvent? { trips.last { $0.id == id } }

    /// What the forecast on this trip says: the place, the days, the range and the
    /// conditions it adds up to. nil when the trip has no forecast.
    public func weather(tripId: String) -> DerivedWeather? {
        guard let t = trip(tripId) else { return nil }
        return deriveWeather(t)
    }

    /// The gear this trip's weather calls for that is NOT on the trip yet: your own
    /// tagged things from its lists first, then the plain ones everybody needs.
    public func weatherMissing(tripId: String) -> [WeatherGearSpec] {
        guard let t = trip(tripId) else { return [] }
        return weatherSuggestions(t, resolvedTemplates()).items
    }

    /// Keep a forecast on the trip. The place is kept too, so the next look needs
    /// no searching, and so a backup carries what was asked for.
    @discardableResult
    public mutating func setWeather(tripId: String, place: String, lat: Double?, lon: Double?,
                                    snapshot: WeatherSnapshot) -> Bool {
        guard let n = trips.firstIndex(where: { $0.id == tripId }) else { return false }
        trips[n].destination = jsTrim(place).isEmpty ? trips[n].destination : jsTrim(place)
        trips[n].weather = snapshot
        if let lat, let lon { trips[n].geo = GeoFix(lat: lat, lon: lon) }
        trips[n].updatedAt = nowISO()
        return true
    }

    /// Take one of the suggestions along: it becomes a line on this trip, carrying
    /// the bag and the "when" the suggestion asks for.
    @discardableResult
    public mutating func addWeatherGear(tripId: String, _ gear: WeatherGearSpec) -> Item? {
        addCustomLine(tripId: tripId, name: gear.name,
                      container: gear.container ?? "", phase: gear.phase ?? "")
    }

    /// Is this forecast worth looking up again? Older than six hours, or for a
    /// different place than the trip now says.
    public func forecastIsStale(tripId: String, hours: Double = 6, now: Date = Date()) -> Bool {
        guard let t = trip(tripId) else { return false }
        guard let w = t.weather, !w.daily.isEmpty else { return true }
        let place = jsTrim(t.destination)
        if !place.isEmpty, !w.place.isEmpty,
           !w.place.lowercased().hasPrefix(place.lowercased().prefix(3)) { return true }
        guard let taken = isoMoment(w.fetchedAt) else { return true }
        return now.timeIntervalSince(taken) > hours * 3600
    }
}

/// An ISO moment as a date, or nil. (`nowISO()` writes these.)
func isoMoment(_ text: String) -> Date? {
    if text.isEmpty { return nil }
    let strict = ISO8601DateFormatter()
    strict.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = strict.date(from: text) { return d }
    let plain = ISO8601DateFormatter()
    plain.formatOptions = [.withInternetDateTime]
    return plain.date(from: text)
}
