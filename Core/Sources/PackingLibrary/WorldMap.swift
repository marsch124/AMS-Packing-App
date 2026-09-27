import Foundation
import PackingCore

// The world map of his trips — the web app's #/map (gap list, 2026-09-27). The
// rules are PackingCore's port of model.js (`placesVisited`, `tripPath`,
// `eventsNeedingCoords`, `mostVisited`); this is the library's way in.

extension Library {
    /// One pin per place, the most recent visit first; repeat visits share a pin.
    public func mapPlaces() -> [PlacePin] { placesVisited(trips) }

    /// The dated trips with a place, oldest first — the line between the pins.
    public func mapPath() -> [TripStop] { tripPath(trips) }

    /// Trips that name a place but have no spot on the map yet.
    public func placesToFind() -> [TripEvent] { eventsNeedingCoords(trips) }

    /// A place looked up for the map, kept on the trip (its geo fix) with the
    /// label the map service gave it. Out-of-range coordinates are refused.
    @discardableResult
    public mutating func setPlace(tripId: String, lat: Double, lon: Double, label: String) -> Bool {
        guard let n = trips.firstIndex(where: { $0.id == tripId }),
              let fix = coerceGeo(GeoFix(lat: lat, lon: lon, place: jsTrim(label))) else { return false }
        trips[n].geo = fix
        trips[n].updatedAt = nowISO()
        return true
    }

    /// "3 places · 4 trips".
    public static func mapSummary(_ pins: [PlacePin]) -> String {
        let trips = pins.reduce(0) { $0 + $1.events.count }
        return "\(pins.count) place\(pins.count == 1 ? "" : "s") · \(trips) trip\(trips == 1 ? "" : "s")"
    }
}
