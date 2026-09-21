// Weather — what a cached forecast MEANS for packing (opt-in, Open-Meteo).
// Ported from js/model.js ("Weather (opt-in, Open-Meteo)").
//
// The event optionally stores a `destination` and a cached `weather` snapshot
// (fetched when online, kept on-device so it still shows offline). All the
// interpretation below is pure: it maps a forecast to icon keys, derived
// conditions, and packing suggestions. The app maps icon keys to its own drawings.
// (The snapshot's SHAPE — `WeatherSnapshot`, `WeatherDay`, `coerceWeather` — is in
// Events.swift.)

import Foundation

// MARK: - WMO codes

/// What `weatherCode` answers: a symbolic icon key, a short label, and whether it means "wet".
public struct WeatherCodeInfo: Equatable, Hashable, Sendable {
    public var icon: String
    public var label: String
    public var wet: Bool
    public init(icon: String, label: String, wet: Bool) { self.icon = icon; self.label = label; self.wet = wet }
    public var json: JSONValue { ["icon": .string(icon), "label": .string(label), "wet": .bool(wet)] }
}

/// WMO weather-code -> symbolic icon key + short label + whether it means "wet".
/// nil / NaN (JS `Number(undefined)`) falls through to the grey cloud with a dash.
public func weatherCode(_ code: Double?) -> WeatherCodeInfo {
    let c = code ?? .nan
    if c == 0 { return WeatherCodeInfo(icon: "sun", label: "Clear", wet: false) }
    if c == 1 || c == 2 { return WeatherCodeInfo(icon: "sun-cloud", label: "Partly cloudy", wet: false) }
    if c == 3 { return WeatherCodeInfo(icon: "cloud", label: "Cloudy", wet: false) }
    if c == 45 || c == 48 { return WeatherCodeInfo(icon: "fog", label: "Fog", wet: false) }
    if c >= 51 && c <= 57 { return WeatherCodeInfo(icon: "rain", label: "Drizzle", wet: true) }
    if c >= 61 && c <= 67 { return WeatherCodeInfo(icon: "rain", label: "Rain", wet: true) }
    if c >= 71 && c <= 77 { return WeatherCodeInfo(icon: "snow", label: "Snow", wet: true) }
    if c >= 80 && c <= 82 { return WeatherCodeInfo(icon: "rain", label: "Showers", wet: true) }
    if c >= 85 && c <= 86 { return WeatherCodeInfo(icon: "snow", label: "Snow showers", wet: true) }
    if c >= 95 { return WeatherCodeInfo(icon: "storm", label: "Thunderstorm", wet: true) }
    return WeatherCodeInfo(icon: "cloud", label: "—", wet: false)
}
/// `weatherCode(code)` for a raw value — it goes through `Number()`, so "63" counts.
public func weatherCode(json code: JSONValue?) -> WeatherCodeInfo { weatherCode(jsNumber(code)) }

// MARK: - Thresholds

public struct WeatherThresholds: Equatable, Hashable, Sendable {
    public var coldMinC: Double
    public var coolMaxSummerC: Double
    public var hotMaxC: Double
    public var windKmh: Double
    public var wetProb: Double
    public init(coldMinC: Double, coolMaxSummerC: Double, hotMaxC: Double, windKmh: Double, wetProb: Double) {
        self.coldMinC = coldMinC; self.coolMaxSummerC = coolMaxSummerC; self.hotMaxC = hotMaxC
        self.windKmh = windKmh; self.wetProb = wetProb
    }
}
/// Thresholds that turn a forecast into packing-relevant conditions (metric).
public let WEATHER_THRESHOLDS = WeatherThresholds(coldMinC: 5, coolMaxSummerC: 14, hotMaxC: 27, windKmh: 35, wetProb: 50)

// MARK: - Weekday label

private let DOW = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

/// `DOW[new Date(`${dateISO}T00:00:00`).getDay()]` — '' when it is not a date.
///
/// The JS reads the date at LOCAL midnight and asks for the LOCAL weekday, so the two
/// cancel out: the answer is simply the weekday of that calendar date, the same on
/// every device, in every time zone. The labels are fixed English words — the
/// device's language plays no part either. Hence plain arithmetic here, no Calendar.
func dowLabel(_ dateISO: String) -> String {
    guard let n = JSDay.number(dateISO) else { return "" }
    return DOW[JSDay.weekday(n)]
}

// MARK: - deriveWeather

/// One day of `deriveWeather`: display data for the forecast strip.
/// `tmax` / `tmin` are nil where the JS holds NaN (a day the forecast gave no
/// temperature for).
public struct DerivedWeatherDay: Equatable, Hashable, Sendable {
    public var date: String
    /// 'Mon', 'Tue'… ('' if the date cannot be read).
    public var dow: String
    public var icon: String
    public var label: String
    public var tmax: Double?
    public var tmin: Double?
    public var precipProb: Double
    public var wind: Double
    public var rainy: Bool
    public var snowy: Bool
    public init(date: String = "", dow: String = "", icon: String = "", label: String = "", tmax: Double? = nil,
                tmin: Double? = nil, precipProb: Double = 0, wind: Double = 0, rainy: Bool = false, snowy: Bool = false) {
        self.date = date; self.dow = dow; self.icon = icon; self.label = label; self.tmax = tmax; self.tmin = tmin
        self.precipProb = precipProb; self.wind = wind; self.rainy = rainy; self.snowy = snowy
    }
    public var json: JSONValue {
        ["date": .string(date), "dow": .string(dow), "icon": .string(icon), "label": .string(label),
         "tmax": JSONValue(tmax), "tmin": JSONValue(tmin), "precipProb": .number(precipProb),
         "wind": .number(wind), "rainy": .bool(rainy), "snowy": .bool(snowy)]
    }
}

/// What `deriveWeather` answers. `tempMin` / `tempMax` are nil where the JS holds NaN
/// (any day without a temperature poisons `Math.min` / `Math.max`).
public struct DerivedWeather: Equatable, Hashable, Sendable {
    public var place: String
    public var fetchedAt: String
    public var days: [DerivedWeatherDay]
    public var tempMin: Double?
    public var tempMax: Double?
    /// "7–19°C" (an en dash). "NaN–NaN°C" when a temperature is missing, as in JS.
    public var rangeLabel: String
    /// A subset of rain · snow · cold · hot · wind, in that order.
    public var conditions: [String]
    public var coolerThanSeason: Bool
    public init(place: String = "", fetchedAt: String = "", days: [DerivedWeatherDay] = [], tempMin: Double? = nil,
                tempMax: Double? = nil, rangeLabel: String = "", conditions: [String] = [], coolerThanSeason: Bool = false) {
        self.place = place; self.fetchedAt = fetchedAt; self.days = days; self.tempMin = tempMin
        self.tempMax = tempMax; self.rangeLabel = rangeLabel; self.conditions = conditions
        self.coolerThanSeason = coolerThanSeason
    }
    public var json: JSONValue {
        ["place": .string(place), "fetchedAt": .string(fetchedAt), "days": .array(days.map { $0.json }),
         "tempMin": JSONValue(tempMin), "tempMax": JSONValue(tempMax), "rangeLabel": .string(rangeLabel),
         "conditions": JSONValue(conditions), "coolerThanSeason": .bool(coolerThanSeason)]
    }
}

/// `Math.min(...xs)` / `Math.max(...xs)`: NaN (nil) as soon as one value is NaN.
private func jsMin(_ xs: [Double?]) -> Double? {
    var out = Double.infinity
    for x in xs { guard let v = x, !v.isNaN else { return nil }; out = Swift.min(out, v) }
    return out
}
private func jsMax(_ xs: [Double?]) -> Double? {
    var out = -Double.infinity
    for x in xs { guard let v = x, !v.isNaN else { return nil }; out = Swift.max(out, v) }
    return out
}
/// `Math.round(x)` where NaN is nil.
private func roundOrNil(_ x: Double?) -> Double? {
    guard let v = x, !v.isNaN else { return nil }
    return jsRound(v)
}
/// `x || 0`
private func orZero(_ x: Double) -> Double { x.isNaN ? 0 : x }

/// Turn the cached forecast into per-day display data + derived conditions.
/// nil when the event has no forecast.
public func deriveWeather(_ event: TripEvent?) -> DerivedWeather? {
    guard let event = event, let w = event.weather, !w.daily.isEmpty else { return nil }
    let T = WEATHER_THRESHOLDS
    let days: [DerivedWeatherDay] = w.daily.map { d in
        let info = weatherCode(d.code)
        let rainy = info.wet || d.precipProb >= T.wetProb   // the UNROUNDED chance of rain
        return DerivedWeatherDay(
            date: d.date, dow: dowLabel(d.date), icon: info.icon, label: info.label,
            tmax: roundOrNil(d.tmax), tmin: roundOrNil(d.tmin),
            precipProb: jsRound(orZero(d.precipProb)), wind: jsRound(orZero(d.wind)),
            rainy: rainy, snowy: info.icon == "snow")
    }
    let tempMax = jsMax(days.map { $0.tmax })
    let tempMin = jsMin(days.map { $0.tmin })
    let lowestMax = jsMin(days.map { $0.tmax })
    let summer = event.season == "Summer"
    // (A comparison with NaN is false in JS — a missing temperature trips nothing.)
    let cooler = summer && (lowestMax.map { $0 < T.coolMaxSummerC } ?? false)
    var conditions: [String] = []
    if days.contains(where: { $0.rainy && !$0.snowy }) { conditions.append("rain") }
    if days.contains(where: { $0.snowy }) { conditions.append("snow") }
    if (tempMin.map { $0 <= T.coldMinC } ?? false) || cooler { conditions.append("cold") }
    if tempMax.map({ $0 >= T.hotMaxC }) ?? false { conditions.append("hot") }
    if days.contains(where: { $0.wind >= T.windKmh }) { conditions.append("wind") }   // the ROUNDED wind
    func label(_ t: Double?) -> String { jsNumberToString(t ?? .nan) }
    return DerivedWeather(
        place: w.place, fetchedAt: w.fetchedAt, days: days, tempMin: tempMin, tempMax: tempMax,
        rangeLabel: "\(label(tempMin))–\(label(tempMax))°C", conditions: conditions, coolerThanSeason: cooler)
}

// MARK: - Suggestions

/// A piece of gear the weather calls for — one row of `weatherGear`,
/// `weatherSuggestions(…).items` or `WEATHER_SUGGESTIONS`. One shape for all three,
/// as the web app's `entryFromWeatherSpec` reads all three alike.
///
/// Your OWN tagged item (`own == true`) carries everything below. A curated generic
/// add-on carries only `name`, `category`, (`liquid`) and `reason` — in JS the rest is
/// `undefined`, so here `container`, `phase`, `itemType` and the source links are nil
/// and whoever turns it into an entry falls back to `newItem`'s defaults.
public struct WeatherGearSpec: Equatable, Hashable, Sendable {
    public var name: String
    public var swedish: String
    public var category: String
    public var container: String?
    public var phase: String?
    public var itemType: String?
    public var liquid: Bool
    public var weight: Double
    /// Kept so the post-trip review can credit the item it came from.
    public var sourceListId: String?
    public var sourceItemId: String?
    /// `weatherSuggestions` only: the forecast condition that calls for it. nil elsewhere.
    public var reason: String?
    /// `weatherGear` only: every condition the item is tagged for. nil elsewhere.
    public var conditions: [String]?
    /// One of your own items (true) or a curated generic add-on (false).
    public var own: Bool

    public init(name: String, swedish: String = "", category: String = "", container: String? = nil,
                phase: String? = nil, itemType: String? = nil, liquid: Bool = false, weight: Double = 0,
                sourceListId: String? = nil, sourceItemId: String? = nil, reason: String? = nil,
                conditions: [String]? = nil, own: Bool = false) {
        self.name = name; self.swedish = swedish; self.category = category; self.container = container
        self.phase = phase; self.itemType = itemType; self.liquid = liquid; self.weight = weight
        self.sourceListId = sourceListId; self.sourceItemId = sourceItemId; self.reason = reason
        self.conditions = conditions; self.own = own
    }

    /// The keys the JS object has — a curated add-on has far fewer than one of your own.
    public var json: JSONValue {
        var o: [String: JSONValue] = ["name": .string(name), "category": .string(category)]
        if own {
            o["swedish"] = .string(swedish)
            o["container"] = JSONValue(container); o["phase"] = JSONValue(phase); o["itemType"] = JSONValue(itemType)
            o["liquid"] = .bool(liquid); o["weight"] = .number(weight)
            o["sourceListId"] = JSONValue(sourceListId); o["sourceItemId"] = JSONValue(sourceItemId)
            o["own"] = true
        } else if liquid {
            o["liquid"] = true
        }
        if let r = reason { o["reason"] = .string(r) }
        if let c = conditions { o["conditions"] = JSONValue(c) }
        return .object(o)
    }
}

/// Curated, generic add-ons per condition — the kind of gear that isn't
/// activity-specific. Suggested only when the forecast calls for it and the item
/// isn't already on the list. (Keyed by WEATHER_CONDITIONS id.)
public let WEATHER_SUGGESTIONS: [String: [WeatherGearSpec]] = [
    "rain": [
        WeatherGearSpec(name: "Rain jacket", category: "Adventure clothing"),
        WeatherGearSpec(name: "Waterproof / pack cover", category: "Adventure clothing"),
    ],
    "cold": [
        WeatherGearSpec(name: "Warm mid-layer", category: "Adventure clothing"),
        WeatherGearSpec(name: "Beanie + gloves", category: "Adventure clothing"),
        WeatherGearSpec(name: "Long tights", category: "Adventure clothing"),
    ],
    "hot": [
        WeatherGearSpec(name: "Sun hat / cap", category: "Adventure clothing"),
        WeatherGearSpec(name: "Sunscreen", category: "Toiletries", liquid: true),
        WeatherGearSpec(name: "Extra water bottle", category: "Comfort & misc"),
    ],
    "wind": [WeatherGearSpec(name: "Windbreaker", category: "Adventure clothing")],
    "snow": [
        WeatherGearSpec(name: "Warm gloves", category: "Adventure clothing"),
        WeatherGearSpec(name: "Traction spikes", category: "Footwear"),
    ],
]

/// The one-line headline over the suggestions: "Rain Mon–Tue · cold spells · windy".
func weatherSummary(_ d: DerivedWeather) -> String {
    var bits: [String] = []
    // NOTE a snowy day counts as "rainy" here too (both are "wet"), as in the JS.
    let rainy = d.days.filter { $0.rainy }.map { $0.dow }.filter { !$0.isEmpty }
    if !rainy.isEmpty { bits.append(rainy.count <= 2 ? "Rain \(rainy.joined(separator: "–"))" : "Rain likely") }
    if d.conditions.contains("snow") { bits.append("snow") }
    if d.coolerThanSeason { bits.append("cooler than Summer") }
    else if d.conditions.contains("cold") { bits.append("cold spells") }
    if d.conditions.contains("hot") { bits.append("hot") }
    if d.conditions.contains("wind") { bits.append("windy") }
    return bits.joined(separator: " · ")
}

/// One of your own weather-tagged items, as a spec.
private func ownSpec(_ it: Item, _ list: PackList, reason: String? = nil, conditions: [String]? = nil) -> WeatherGearSpec {
    WeatherGearSpec(
        name: it.name, swedish: it.swedish, category: it.category, container: it.container,
        phase: it.phase, itemType: it.itemType, liquid: it.liquid, weight: orZero(it.weight),
        sourceListId: list.id, sourceItemId: it.id, reason: reason, conditions: conditions, own: true)
}

/// All weather-conditional gear this trip's lists hold that isn't packed yet —
/// applicable to the trip (season/transport) but independent of any forecast.
/// Powers both the "waiting" hint and the "pack anyway" control, so the user can
/// add e.g. a rain shell as a backup layer even when it isn't forecast to rain.
public func weatherGear(_ event: TripEvent, _ lists: [PackList] = []) -> [WeatherGearSpec] {
    let have = Set(event.entries.map { normName($0.name) })
    var seen = Set<String>()
    var out: [WeatherGearSpec] = []
    for listId in event.activities {
        // `new Map(lists.map(l => [l.id, l]))`: of two lists with one id, the LAST wins.
        guard let list = lists.last(where: { $0.id == listId }) else { continue }
        for it in list.items {
            let tags = it.weather
            if tags.isEmpty || it.name.isEmpty || !itemMatchesEvent(it, event, list) { continue }
            let key = normName(it.name)
            if have.contains(key) || seen.contains(key) { continue }
            seen.insert(key)
            out.append(ownSpec(it, list, conditions: tags))
        }
    }
    return out
}
public func pendingWeatherItems(_ event: TripEvent, _ lists: [PackList] = []) -> Int {
    weatherGear(event, lists).count
}

/// What `weatherSuggestions` answers.
public struct WeatherSuggestions: Equatable, Hashable, Sendable {
    public var conditions: [String]
    public var items: [WeatherGearSpec]
    public var summary: String
    public init(conditions: [String] = [], items: [WeatherGearSpec] = [], summary: String = "") {
        self.conditions = conditions; self.items = items; self.summary = summary
    }
    public var json: JSONValue {
        ["conditions": JSONValue(conditions), "items": .array(items.map { $0.json }), "summary": .string(summary)]
    }
}

/// Suggested additions for this trip's forecast, minus anything already packed.
/// Prefers the user's OWN weather-tagged items from the chosen activity lists,
/// then fills any remaining conditions with the curated generic add-ons.
public func weatherSuggestions(_ event: TripEvent, _ lists: [PackList] = []) -> WeatherSuggestions {
    guard let d = deriveWeather(event) else { return WeatherSuggestions() }
    let active = Set(d.conditions)
    let have = Set(event.entries.map { normName($0.name) })
    var seen = Set<String>()
    var items: [WeatherGearSpec] = []

    // 1) Your own tagged gear from the lists this trip draws on.
    for listId in event.activities {
        guard let list = lists.last(where: { $0.id == listId }) else { continue }
        for it in list.items {
            guard let reason = it.weather.first(where: { active.contains($0) }) else { continue }
            if reason.isEmpty || it.name.isEmpty || !itemMatchesEvent(it, event, list) { continue }
            let key = normName(it.name)
            if have.contains(key) || seen.contains(key) { continue }
            seen.insert(key)
            items.append(ownSpec(it, list, reason: reason))
        }
    }

    // 2) Curated generic add-ons cover any condition your lists didn't.
    for cond in d.conditions {
        for spec in WEATHER_SUGGESTIONS[cond] ?? [] {
            let key = normName(spec.name)
            if have.contains(key) || seen.contains(key) { continue }
            seen.insert(key)
            var s = spec
            s.reason = cond
            items.append(s)
        }
    }
    return WeatherSuggestions(conditions: d.conditions, items: items, summary: weatherSummary(d))
}
