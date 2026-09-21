// Presets — a saved trip "recipe" (which activities + which conditions), reusable to
// spin up a similar trip in one tap. Dates, destination and the packed entries are
// trip-specific and deliberately NOT part of a preset.
// Ported from js/model.js (`presetConfigFromEvent`, `applyPresetConfig`).
// (The preset ROW — { id, name, createdAt, config } — and its sync belong to the
// settings section; only the config lives here.)

import Foundation

/// `{ mode, activities, transport, season, contexts, catering, weatherOn, laundry }`.
public struct PresetConfig: JSONModel, Hashable, Sendable {
    public var mode: String
    public var activities: [String]
    public var transport: String
    public var season: String
    public var contexts: [String]
    public var catering: String
    public var weatherOn: [String]
    public var laundry: Bool

    /// The defaults are what `presetConfigFromEvent({})` answers.
    public init(mode: String = "trip", activities: [String] = [], transport: String = "Car",
                season: String = "Summer", contexts: [String] = [], catering: String = "mixed",
                weatherOn: [String] = [], laundry: Bool = false) {
        self.mode = mode; self.activities = activities; self.transport = transport; self.season = season
        self.contexts = contexts; self.catering = catering; self.weatherOn = weatherOn; self.laundry = laundry
    }
    /// `presetConfigFromEvent(json)` — the same rules, read off any object at all.
    public init(json: JSONValue) { self = presetConfigFromEvent(json: json) }
    public var json: JSONValue {
        ["mode": .string(mode), "activities": JSONValue(activities), "transport": .string(transport),
         "season": .string(season), "contexts": JSONValue(contexts), "catering": .string(catering),
         "weatherOn": JSONValue(weatherOn), "laundry": .bool(laundry)]
    }
}

public func presetConfigFromEvent(_ ev: TripEvent? = nil) -> PresetConfig {
    guard let ev = ev else { return PresetConfig() }
    return PresetConfig(
        mode: ev.mode == "quick" ? "quick" : "trip",
        activities: ev.activities,
        transport: ev.transport.isEmpty ? "Car" : ev.transport,
        season: ev.season.isEmpty ? "Summer" : ev.season,
        contexts: ev.contexts,
        catering: ev.catering.isEmpty ? "mixed" : ev.catering,
        weatherOn: ev.weatherOn,
        laundry: ev.laundry
    )
}
/// `presetConfigFromEvent(ev)` for a raw object. `ev.transport || 'Car'`: a falsy value
/// gets the default; a truthy one that is not text reads as '' (what a typed event
/// would hold for it).
public func presetConfigFromEvent(json ev: JSONValue?) -> PresetConfig {
    func text(_ v: JSONValue?, _ fallback: String) -> String { jsTruthy(v) ? jsStringOr(v) : fallback }
    return PresetConfig(
        mode: ev?["mode"]?.stringValue == "quick" ? "quick" : "trip",
        activities: asStringArray(ev?["activities"]),
        transport: text(ev?["transport"], "Car"),
        season: text(ev?["season"], "Summer"),
        contexts: asStringArray(ev?["contexts"]),
        catering: text(ev?["catering"], "mixed"),
        weatherOn: asStringArray(ev?["weatherOn"]),
        laundry: jsTruthy(ev?["laundry"])
    )
}

/// Copy a preset's config onto an event. Leaves the event's own name/dates/
/// destination/entries untouched. (JS mutates and returns the event; here the
/// updated copy is returned. As in the JS, the result is NOT coerced.)
public func applyPresetConfig(_ ev: TripEvent, _ config: PresetConfig) -> TripEvent {
    applyPresetConfig(ev, json: config.json)
}
/// `applyPresetConfig(ev, config)` for a stored (possibly partial) config: a key that
/// is missing or falsy leaves the event's own value — except `laundry`, which is
/// ALWAYS set (a config without it switches laundry off). A config that is not an
/// object changes nothing at all.
public func applyPresetConfig(_ ev: TripEvent, json config: JSONValue?) -> TripEvent {
    guard let config = config, config.objectValue != nil || config.arrayValue != nil else { return ev }
    var e = ev
    if jsTruthy(config["mode"]) { e.mode = config["mode"]?.stringValue == "quick" ? "quick" : "trip" }
    if config["activities"]?.arrayValue != nil { e.activities = asStringArray(config["activities"]) }
    if jsTruthy(config["transport"]) { e.transport = jsStringOr(config["transport"]) }
    if jsTruthy(config["season"]) { e.season = jsStringOr(config["season"]) }
    if config["contexts"]?.arrayValue != nil { e.contexts = asStringArray(config["contexts"]) }
    if jsTruthy(config["catering"]) { e.catering = jsStringOr(config["catering"]) }
    if config["weatherOn"]?.arrayValue != nil { e.weatherOn = asStringArray(config["weatherOn"]) }
    e.laundry = jsTruthy(config["laundry"])
    return e
}
