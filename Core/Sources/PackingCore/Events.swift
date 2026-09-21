// Events — a TRIP (the JS calls it an event), its cached forecast and its place fix.
// Ported from js/model.js (`coerceEvent`, `coerceGeo`, `coerceWeather`, `newEvent`).
// Only the SHAPES live here: the weather logic, trip building, dates and places are
// later sections with files of their own.
//
// Called `TripEvent` because `Event` is taken in too many Apple frameworks.

import Foundation

// MARK: - Place fix

/// A tiny, standalone place fix — { lat, lon, place } — cached on an event so the
/// world map can pin it offline. Set when a destination is looked up (via the same
/// geocoder the weather uses); kept even if no forecast is ever fetched.
public struct GeoFix: JSONModel, Hashable, Sendable {
    public var lat: Double
    public var lon: Double
    public var place: String
    public init(lat: Double = 0, lon: Double = 0, place: String = "") { self.lat = lat; self.lon = lon; self.place = place }
    /// The fix, or 0/0 when `coerceGeo` would give null — decode `GeoFix?` through
    /// `coerceGeo(json:)` (as `TripEvent` does) to keep the difference.
    public init(json: JSONValue) { self = coerceGeo(json: json) ?? GeoFix() }
    public var json: JSONValue { ["lat": .number(lat), "lon": .number(lon), "place": .string(place)] }
}

/// The value rules of `coerceGeo`: nil unless both coordinates are real and in range.
public func coerceGeo(_ g: GeoFix?) -> GeoFix? {
    guard let g = g, g.lat.isFinite, g.lon.isFinite else { return nil }
    if g.lat < -90 || g.lat > 90 || g.lon < -180 || g.lon > 180 { return nil }
    return g
}
/// `coerceGeo(g)` for raw JSON. Coordinates go through `Number()`, so "51.5" counts.
public func coerceGeo(json g: JSONValue?) -> GeoFix? {
    guard let o = g?.objectValue else { return nil }
    let lat = jsNumber(o["lat"]), lon = jsNumber(o["lon"])
    guard lat.isFinite, lon.isFinite else { return nil }
    return coerceGeo(GeoFix(lat: lat, lon: lon, place: jsStringOr(o["place"])))
}

// MARK: - Cached forecast

/// One day of the cached Open-Meteo forecast.
/// `tmax` / `tmin` are nil where the JS holds NaN (`Number(undefined)`): NaN cannot be
/// compared or written as JSON. (JS writes it as null and reads null back as 0 — and
/// so does this.)
public struct WeatherDay: JSONModel, Hashable, Sendable {
    public var date: String
    /// WMO weather code.
    public var code: Double
    public var tmax: Double?
    public var tmin: Double?
    public var precipProb: Double
    public var wind: Double

    public init(date: String = "", code: Double = 0, tmax: Double? = nil, tmin: Double? = nil,
                precipProb: Double = 0, wind: Double = 0) {
        self.date = date; self.code = code; self.tmax = tmax; self.tmin = tmin
        self.precipProb = precipProb; self.wind = wind
    }
    public init(json: JSONValue) {
        func orZero(_ v: JSONValue?) -> Double { let n = jsNumber(v); return (n.isNaN || n == 0) ? 0 : n }   // Number(x) || 0
        func orNil(_ v: JSONValue?) -> Double? { let n = jsNumber(v); return n.isNaN ? nil : n }
        self.date = jsStringOrEmpty(json["date"])
        self.code = orZero(json["code"])
        self.tmax = orNil(json["tmax"])
        self.tmin = orNil(json["tmin"])
        self.precipProb = orZero(json["precipProb"])
        self.wind = orZero(json["wind"])
    }
    public var json: JSONValue {
        ["date": .string(date), "code": .number(code), "tmax": JSONValue(tmax), "tmin": JSONValue(tmin),
         "precipProb": .number(precipProb), "wind": .number(wind)]
    }
}

/// The cached forecast on an event (fetched when online, kept so it still shows
/// offline). `lat` / `lon` are nil where the JS holds NaN.
public struct WeatherSnapshot: JSONModel, Hashable, Sendable {
    public var place: String
    public var lat: Double?
    public var lon: Double?
    public var fetchedAt: String
    public var daily: [WeatherDay]

    public init(place: String = "", lat: Double? = nil, lon: Double? = nil, fetchedAt: String = "",
                daily: [WeatherDay] = []) {
        self.place = place; self.lat = lat; self.lon = lon; self.fetchedAt = fetchedAt; self.daily = daily
    }
    /// The snapshot, or an empty one when `coerceWeather` would give null — decode
    /// `WeatherSnapshot?` through `coerceWeather(json:)` (as `TripEvent` does).
    public init(json: JSONValue) { self = coerceWeather(json: json) ?? WeatherSnapshot() }
    public var json: JSONValue {
        ["place": .string(place), "lat": JSONValue(lat), "lon": JSONValue(lon),
         "fetchedAt": .string(fetchedAt), "daily": .array(daily.map { $0.json })]
    }
}

/// The value rules of `coerceWeather`: days without a date are dropped, and a
/// snapshot with no days left is nil. (Not exported by the JS module; public here
/// because the app stores a fetched forecast through it.)
public func coerceWeather(_ w: WeatherSnapshot?) -> WeatherSnapshot? {
    guard var w = w else { return nil }
    w.daily = w.daily.filter { !$0.date.isEmpty }
    if w.daily.isEmpty { return nil }
    if let v = w.lat, !v.isFinite { w.lat = nil }
    if let v = w.lon, !v.isFinite { w.lon = nil }
    return w
}
/// `coerceWeather(w)` for raw JSON: null unless it is an object whose `daily` is an array.
public func coerceWeather(json w: JSONValue?) -> WeatherSnapshot? {
    guard let o = w?.objectValue, let daily = o["daily"]?.arrayValue else { return nil }
    let lat = jsNumber(o["lat"]), lon = jsNumber(o["lon"])
    return coerceWeather(WeatherSnapshot(
        place: jsStringOr(o["place"]),
        lat: lat.isFinite ? lat : nil,
        lon: lon.isFinite ? lon : nil,
        fetchedAt: jsStringOr(o["fetchedAt"]),
        daily: daily.filter { jsTruthy($0["date"]) }.map { WeatherDay(json: $0) }
    ))
}

// MARK: - TripEvent

public struct TripEvent: JSONModel, Hashable, Sendable {
    public var id: String
    public var name: String
    /// 'trip' (common base + transport + activities) | 'quick' (ticked activities only)
    public var mode: String
    /// Packing-list ids chosen for this trip.
    public var activities: [String]
    public var transport: String
    public var season: String
    public var contexts: [String]
    /// Weather conditions "forced on" for this trip (rain/cold/…) — pulls in that
    /// tagged gear as a precaution, regardless of forecast.
    public var weatherOn: [String]
    public var catering: String
    public var startDate: String
    /// Return date; trip length in nights derives from start → end.
    public var endDate: String
    /// Trip length in nights (drives per-night quantity scaling).
    public var nights: Int
    /// Laundry available → cap per-night quantities to a cycle's worth.
    public var laundry: Bool
    /// Optional place name for the weather forecast.
    public var destination: String
    /// Cached Open-Meteo snapshot (set when fetched online), or nil.
    public var weather: WeatherSnapshot?
    /// Cached place coordinates for the world map, or nil.
    public var geo: GeoFix?
    /// Materialised, editable Total-List lines.
    public var entries: [Item]
    /// 'active' | 'done' (reviewed)
    public var status: String
    public var reviewedAt: String
    public var generatedAt: String
    public var createdAt: String
    public var updatedAt: String
    /// Any key this package does not know — kept so nothing is lost on a round trip.
    public var extra: [String: JSONValue]

    /// The defaults are `newEvent`'s. NOTE this does not coerce — `newEvent(…)` does.
    public init(
        id: String = PackingEnv.makeId(),
        name: String = "",
        mode: String = "trip",
        activities: [String] = [],
        transport: String = "Car",
        season: String = "Summer",
        contexts: [String] = [],
        weatherOn: [String] = [],
        catering: String = "mixed",
        startDate: String = "",
        endDate: String = "",
        nights: Int = 0,
        laundry: Bool = false,
        destination: String = "",
        weather: WeatherSnapshot? = nil,
        geo: GeoFix? = nil,
        entries: [Item] = [],
        status: String = "active",
        reviewedAt: String = "",
        generatedAt: String = "",
        createdAt: String = nowISO(),
        updatedAt: String = nowISO(),
        extra: [String: JSONValue] = [:]
    ) {
        self.id = id; self.name = name; self.mode = mode; self.activities = activities
        self.transport = transport; self.season = season; self.contexts = contexts; self.weatherOn = weatherOn
        self.catering = catering; self.startDate = startDate; self.endDate = endDate; self.nights = nights
        self.laundry = laundry; self.destination = destination; self.weather = weather; self.geo = geo
        self.entries = entries; self.status = status; self.reviewedAt = reviewedAt
        self.generatedAt = generatedAt; self.createdAt = createdAt; self.updatedAt = updatedAt
        self.extra = extra
    }

    static let knownKeys: Set<String> = [
        "id", "name", "mode", "activities", "transport", "season", "contexts", "weatherOn", "catering",
        "startDate", "endDate", "nights", "laundry", "destination", "weather", "geo", "entries",
        "status", "reviewedAt", "generatedAt", "createdAt", "updatedAt",
    ]

    /// `coerceEvent(json)`. NOTE a field the JSON does not carry gets `coerceEvent`'s
    /// answer ('' for the transport), NOT `newEvent`'s default — use `newEvent(json:)`.
    public init(json: JSONValue) {
        let o = json.objectValue ?? [:]
        var n = 0
        if let d = o["nights"]?.finiteNumber, d >= 0 { n = jsFloorInt(d) }
        self.init(
            id: jsLooseText(o["id"]),
            name: jsLooseText(o["name"]),
            mode: jsStringOr(o["mode"]),
            activities: asStringArray(o["activities"]),
            transport: jsStringOr(o["transport"]),
            season: jsStringOr(o["season"]),
            contexts: asStringArray(o["contexts"]),
            weatherOn: asStringArray(o["weatherOn"]),
            catering: jsStringOr(o["catering"]),
            startDate: jsStringOr(o["startDate"]),
            endDate: jsStringOr(o["endDate"]),
            nights: n,
            laundry: jsTruthy(o["laundry"]),
            destination: jsStringOr(o["destination"]),
            weather: coerceWeather(json: o["weather"]),
            geo: coerceGeo(json: o["geo"]),
            entries: coerceItems(json: o["entries"]),
            status: jsStringOr(o["status"]),
            reviewedAt: jsStringOr(o["reviewedAt"]),
            generatedAt: jsStringOr(o["generatedAt"]),
            createdAt: jsStringOr(o["createdAt"]),
            updatedAt: jsStringOr(o["updatedAt"]),
            extra: extraKeys(o, known: TripEvent.knownKeys)
        )
        self = coerceEvent(self)
    }

    public var json: JSONValue {
        var o = extra
        o["id"] = .string(id); o["name"] = .string(name); o["mode"] = .string(mode)
        o["activities"] = JSONValue(activities); o["transport"] = .string(transport); o["season"] = .string(season)
        o["contexts"] = JSONValue(contexts); o["weatherOn"] = JSONValue(weatherOn); o["catering"] = .string(catering)
        o["startDate"] = .string(startDate); o["endDate"] = .string(endDate)
        o["nights"] = .number(Double(nights)); o["laundry"] = .bool(laundry)
        o["destination"] = .string(destination)
        o["weather"] = weather?.json ?? .null
        o["geo"] = geo?.json ?? .null
        o["entries"] = .array(entries.map { $0.json })
        o["status"] = .string(status); o["reviewedAt"] = .string(reviewedAt); o["generatedAt"] = .string(generatedAt)
        o["createdAt"] = .string(createdAt); o["updatedAt"] = .string(updatedAt)
        return .object(o)
    }
}

/// The value rules of `coerceEvent`, for an event built in memory.
public func coerceEvent(_ event: TripEvent) -> TripEvent {
    var e = event
    e.mode = e.mode == "quick" ? "quick" : "trip"   // 'quick' skips the common base + transport kit
    e.entries = e.entries.map { coerceItem($0) }
    e.status = e.status == "done" ? "done" : "active"
    e.nights = max(0, e.nights)
    e.weather = coerceWeather(e.weather)
    // Conditions "forced on" for this trip: pack that tagged gear regardless of forecast/season.
    e.weatherOn = e.weatherOn.filter { WEATHER_CONDITION_IDS.contains($0) }
    e.geo = coerceGeo(e.geo)
    return e
}
/// `coerceEvent(e)` for raw JSON. nil when it is not an object.
public func coerceEvent(json e: JSONValue?) -> TripEvent? {
    guard let e = e, e.objectValue != nil else { return nil }
    return TripEvent(json: e)
}

/// `newEvent({ … })` — the same parameters as `TripEvent.init`, then `coerceEvent`.
public func newEvent(
    id: String = PackingEnv.makeId(),
    name: String = "",
    mode: String = "trip",
    activities: [String] = [],
    transport: String = "Car",
    season: String = "Summer",
    contexts: [String] = [],
    weatherOn: [String] = [],
    catering: String = "mixed",
    startDate: String = "",
    endDate: String = "",
    nights: Int = 0,
    laundry: Bool = false,
    destination: String = "",
    weather: WeatherSnapshot? = nil,
    geo: GeoFix? = nil,
    entries: [Item] = [],
    status: String = "active",
    reviewedAt: String = "",
    generatedAt: String = "",
    createdAt: String = nowISO(),
    updatedAt: String = nowISO(),
    extra: [String: JSONValue] = [:]
) -> TripEvent {
    coerceEvent(TripEvent(id: id, name: name, mode: mode, activities: activities, transport: transport,
                          season: season, contexts: contexts, weatherOn: weatherOn, catering: catering,
                          startDate: startDate, endDate: endDate, nights: nights, laundry: laundry,
                          destination: destination, weather: weather, geo: geo, entries: entries,
                          status: status, reviewedAt: reviewedAt, generatedAt: generatedAt,
                          createdAt: createdAt, updatedAt: updatedAt, extra: extra))
}
/// `newEvent(event)` — coerce an event already built with `TripEvent(…)`.
public func newEvent(_ event: TripEvent) -> TripEvent { coerceEvent(event) }
/// `newEvent(partial)` for a raw JSON partial, laid over the defaults as the JS spreads it.
public func newEvent(json partial: JSONValue) -> TripEvent {
    var o = TripEvent().json.objectValue ?? [:]
    for (k, v) in partial.objectValue ?? [:] { o[k] = v }
    return TripEvent(json: .object(o))
}
