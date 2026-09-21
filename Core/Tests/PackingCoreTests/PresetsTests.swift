import XCTest
@testable import PackingCore

// Ported from tests/model.test.mjs — "Trip presets (saved event recipes)".
final class PresetsTests: XCTestCase {
    override func tearDown() { PackingEnv.reset(); super.tearDown() }

    // JS: 'presetConfigFromEvent: captures the recipe, not the trip specifics'
    func testPresetConfigFromEventCapturesTheRecipeNotTheTripSpecifics() {
        let ev = newEvent(
            name: "Kalmar 2026", mode: "trip", activities: ["a", "b"], transport: "Plane", season: "Summer",
            contexts: ["Outdoor"], weatherOn: ["rain"], catering: "self",
            startDate: "2026-08-20", endDate: "2026-08-24", nights: 4, laundry: true, destination: "Kalmar")
        let c = presetConfigFromEvent(ev)
        XCTAssertEqual(c, PresetConfig(mode: "trip", activities: ["a", "b"], transport: "Plane", season: "Summer",
                                       contexts: ["Outdoor"], catering: "self", weatherOn: ["rain"], laundry: true))
        // Trip specifics are NOT part of the preset.
        let keys = Set((c.json.objectValue ?? [:]).keys)
        XCTAssertFalse(keys.contains("startDate"))
        XCTAssertFalse(keys.contains("destination"))
        XCTAssertFalse(keys.contains("name"))
        XCTAssertEqual(keys, ["mode", "activities", "transport", "season", "contexts", "catering", "weatherOn", "laundry"])
    }

    // JS: 'applyPresetConfig: fills conditions but leaves name/dates/entries alone'
    func testApplyPresetConfigFillsConditionsButLeavesNameDatesEntriesAlone() {
        var ev = newEvent(name: "My trip", startDate: "2026-09-01", destination: "Rome")
        ev.entries = [newItem(name: "Passport")]
        ev = applyPresetConfig(ev, json: ["mode": "quick", "activities": ["x"], "transport": "RV", "season": "Winter",
                                          "contexts": ["Indoor"], "catering": "eatout", "weatherOn": ["cold"], "laundry": true])
        XCTAssertEqual(ev.mode, "quick")
        XCTAssertEqual(ev.activities, ["x"])
        XCTAssertEqual(ev.transport, "RV")
        XCTAssertEqual(ev.season, "Winter")
        XCTAssertEqual(ev.laundry, true)
        // Untouched:
        XCTAssertEqual(ev.name, "My trip")
        XCTAssertEqual(ev.startDate, "2026-09-01")
        XCTAssertEqual(ev.destination, "Rome")
        XCTAssertEqual(ev.entries.count, 1)
    }

    // JS: 'preset round-trip: config from an event re-applies to an identical config'
    func testPresetRoundTrip() {
        let src = newEvent(mode: "trip", activities: ["golf"], transport: "Car", season: "Summer", contexts: ["Race"],
                           weatherOn: [], catering: "mixed", laundry: false)
        let config = presetConfigFromEvent(src)
        let target = applyPresetConfig(newEvent(name: "New", startDate: "2026-01-01"), config)
        XCTAssertEqual(presetConfigFromEvent(target), config)
    }

    // MARK: --- not in the JS suite ---

    func testPresetConfigDefaultsAndTheRawForm() {
        let blank = PresetConfig(mode: "trip", activities: [], transport: "Car", season: "Summer", contexts: [],
                                 catering: "mixed", weatherOn: [], laundry: false)
        XCTAssertEqual(presetConfigFromEvent(), blank)                 // JS: presetConfigFromEvent() with `ev = {}`
        XCTAssertEqual(presetConfigFromEvent(json: [:]), blank)
        XCTAssertEqual(presetConfigFromEvent(json: nil), blank)
        XCTAssertEqual(PresetConfig(), blank)
        // An event whose fields were blanked falls back the same way.
        XCTAssertEqual(presetConfigFromEvent(TripEvent(mode: "odd", transport: "", season: "", catering: "")), blank)
        let raw: JSONValue = ["mode": "quick", "activities": "golf", "transport": 0, "season": "Winter", "laundry": 1, "name": "x"]
        let c = presetConfigFromEvent(json: raw)
        XCTAssertEqual(c, PresetConfig(mode: "quick", activities: [], transport: "Car", season: "Winter", laundry: true))
        XCTAssertEqual(PresetConfig(json: c.json), c)
    }

    func testApplyPresetConfigAPartialConfigLeavesTheRestButAlwaysSetsLaundry() {
        let ev = newEvent(name: "Trip", mode: "quick", activities: ["a"], transport: "Plane", season: "Winter",
                          contexts: ["Indoor"], weatherOn: ["rain"], catering: "self", laundry: true)
        let out = applyPresetConfig(ev, json: ["season": "Summer", "activities": "not-a-list", "transport": ""])
        XCTAssertEqual(out.season, "Summer")
        XCTAssertEqual([out.mode, out.transport, out.catering], ["quick", "Plane", "self"])
        XCTAssertEqual(out.activities, ["a"])
        XCTAssertEqual(out.weatherOn, ["rain"])
        XCTAssertEqual(out.laundry, false, "a config without `laundry` switches it off — as in the JS")
        // Not an object: nothing changes, laundry included.
        XCTAssertEqual(applyPresetConfig(ev, json: nil), ev)
        XCTAssertEqual(applyPresetConfig(ev, json: "quick"), ev)
        // Any mode but 'quick' is 'trip'.
        XCTAssertEqual(applyPresetConfig(ev, json: ["mode": "whatever", "laundry": true]).mode, "trip")
    }
}
