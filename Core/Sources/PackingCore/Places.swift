// Places — the world map: where each trip went, one pin per place.
// Ported from js/model.js ("PLACES VISITED (world map)").
//
// Every event may name a `destination`. Once that place is looked up (by the
// weather forecast, or on demand for the map) its coordinates are cached — on
// the weather snapshot and/or the lightweight `geo` fix. These helpers pull the
// coordinates back out and roll repeat visits to the same place into ONE pin.

import Foundation

// MARK: - Coordinates

/// The best-known coordinates for an event, or nil. A fetched forecast is the
/// most authoritative source (it carries a tidy "City, CC" label); the cached
/// `geo` fix is the fallback for events that never had a forecast.
///
/// JS answers `{ lat, lon, place }` — exactly the shape of a `GeoFix`, so that is
/// what comes back. NOTE the forecast's coordinates are NOT range-checked (only the
/// geo fix goes through `coerceGeo`), as in the JS.
public func eventCoords(_ event: TripEvent?) -> GeoFix? {
    guard let event = event else { return nil }
    if let w = event.weather, let lat = w.lat, let lon = w.lon, lat.isFinite, lon.isFinite {
        return GeoFix(lat: lat, lon: lon, place: !w.place.isEmpty ? w.place : event.destination)
    }
    if let g = coerceGeo(event.geo) {
        return GeoFix(lat: g.lat, lon: g.lon, place: !g.place.isEmpty ? g.place : event.destination)
    }
    return nil
}

/// Events that name a destination but have no coordinates yet — the map's
/// "Find these places" button geocodes exactly these.
public func eventsNeedingCoords(_ events: [TripEvent]) -> [TripEvent] {
    events.filter { !jsTrim($0.destination).isEmpty && eventCoords($0) == nil }
}

// MARK: - Pins

/// The pin key that merges repeat visits: a normalised place label when we have
/// one (so "Stockholm, SE" visited thrice is one pin), else coordinates rounded
/// to ~0.1° (~11 km) so two forecasts of the same spot still coincide.
func placeKey(_ coords: GeoFix) -> String {
    let label = normName(coords.place)
    if !label.isEmpty { return "n:\(label)" }
    return "c:\(jsToFixed1(coords.lat)),\(jsToFixed1(coords.lon))"
}

/// One pin of `placesVisited`.
public struct PlacePin: Equatable, Sendable {
    public var key: String
    /// Label and coordinates come from the pin's FIRST event in `sortEventsForList` order.
    public var place: String
    public var lat: Double
    public var lon: Double
    public var events: [TripEvent]
    public init(key: String = "", place: String = "", lat: Double = 0, lon: Double = 0, events: [TripEvent] = []) {
        self.key = key; self.place = place; self.lat = lat; self.lon = lon; self.events = events
    }
    public var json: JSONValue {
        ["key": .string(key), "place": .string(place), "lat": .number(lat), "lon": .number(lon),
         "events": .array(events.map { $0.json })]
    }
}

/// Roll a list of events into one pin per place: { key, place, lat, lon, events }.
/// `events` within a pin are newest-first; the pin's coordinates/label come from
/// its most recent visit. Pins are returned most-recently-visited first.
///
/// (More exactly: everything follows `sortEventsForList` with TODAY's date — upcoming
/// trips soonest first, then undated ones, then past trips newest first. "Today" comes
/// from `PackingEnv.now`. JS builds a Map; this is its values in insertion order.)
public func placesVisited(_ events: [TripEvent]) -> [PlacePin] {
    var pins: [PlacePin] = []
    var at: [String: Int] = [:]
    for e in sortEventsForList(events) {
        guard let coords = eventCoords(e) else { continue }
        let key = placeKey(coords)
        if let i = at[key] {
            pins[i].events.append(e)
        } else {
            at[key] = pins.count
            pins.append(PlacePin(key: key, place: coords.place, lat: coords.lat, lon: coords.lon, events: [e]))
        }
    }
    return pins
}

/// One stop of `tripPath`.
public struct TripStop: Equatable, Hashable, Sendable {
    public var lat: Double
    public var lon: Double
    public var name: String
    public var date: String
    public var place: String
    public init(lat: Double = 0, lon: Double = 0, name: String = "", date: String = "", place: String = "") {
        self.lat = lat; self.lon = lon; self.name = name; self.date = date; self.place = place
    }
    public var json: JSONValue {
        ["lat": .number(lat), "lon": .number(lon), "name": .string(name), "date": .string(date), "place": .string(place)]
    }
}

/// The trips that have BOTH coordinates and a start date, ordered oldest→newest,
/// as a simple list of stops for the map's "journey" line. A place visited twice
/// appears twice (the line can return to it); undated trips are pinned but left
/// off the line, since we can't place them in time.
public func tripPath(_ events: [TripEvent]) -> [TripStop] {
    events
        .compactMap { e -> (e: TripEvent, c: GeoFix)? in
            guard let c = eventCoords(e), !e.startDate.isEmpty else { return nil }
            return (e, c)
        }
        // Start dates are compared as STRINGS (`<`), not as dates.
        .stableSorted(compare: { a, b in
            jsStringLess(a.e.startDate, b.e.startDate) ? -1 : (jsStringLess(b.e.startDate, a.e.startDate) ? 1 : 0)
        })
        .map { TripStop(lat: $0.c.lat, lon: $0.c.lon, name: $0.e.name, date: $0.e.startDate, place: $0.c.place) }
}

/// The place with the most visits, for the little "most visited" summary. Only
/// meaningful once somewhere has been visited more than once; ties resolve to the
/// most-recently-visited (placesVisited is already newest-first), so nil means
/// "nowhere stands out yet".
public func mostVisited(_ places: [PlacePin]) -> PlacePin? {
    var best: PlacePin?
    for p in places where best == nil || p.events.count > (best?.events.count ?? 0) { best = p }
    guard let b = best, b.events.count >= 2 else { return nil }
    return b
}
