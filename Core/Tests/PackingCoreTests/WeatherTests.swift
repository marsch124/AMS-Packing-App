import XCTest
@testable import PackingCore

// Ported from tests/model.test.mjs — "Weather (Open-Meteo interpretation)" and the
// weather-condition gear tests. ('coerceEvent: normalises destination + weather…' and
// 'coerceItem: keeps only known weather conditions' belong to the foundation and live
// in EventsTests.swift / ItemsTests.swift; 'buildTotalEntries: weather-tagged items
// stay OUT of the base list' belongs to the trip slice.)
final class WeatherTests: XCTestCase {
    override func tearDown() { PackingEnv.reset(); super.tearDown() }

    // JS: const wEvent = (daily, extra = {}) => newEvent({ season: 'Summer', weather: { place: 'Chamonix, FR', … }, ...extra })
    private func wEvent(_ daily: [WeatherDay]) -> TripEvent {
        newEvent(season: "Summer", weather: WeatherSnapshot(place: "Chamonix, FR", lat: 45.9, lon: 6.9,
                                                            fetchedAt: "2026-08-01T00:00:00Z", daily: daily))
    }

    // JS: 'weatherCode: maps WMO codes to icon key + wet flag'
    func testWeatherCodeMapsWMOCodesToIconKeyAndWetFlag() {
        XCTAssertEqual(weatherCode(0).icon, "sun")
        XCTAssertEqual(weatherCode(0).wet, false)
        XCTAssertEqual(weatherCode(3).icon, "cloud")
        XCTAssertEqual(weatherCode(63).icon, "rain")
        XCTAssertEqual(weatherCode(63).wet, true)
        XCTAssertEqual(weatherCode(73).icon, "snow")
        XCTAssertEqual(weatherCode(95).icon, "storm")
    }

    // JS: 'deriveWeather: builds per-day rows and a temperature range'
    func testDeriveWeatherBuildsPerDayRowsAndATemperatureRange() throws {
        let d = try XCTUnwrap(deriveWeather(wEvent([
            WeatherDay(date: "2026-08-03", code: 0, tmax: 19, tmin: 9, precipProb: 5, wind: 8),
            WeatherDay(date: "2026-08-04", code: 61, tmax: 11, tmin: 7, precipProb: 80, wind: 20),
        ])))
        XCTAssertEqual(d.days.count, 2)
        XCTAssertEqual(d.days[0].icon, "sun")
        XCTAssertEqual(d.days[1].rainy, true)
        XCTAssertEqual(d.tempMax, 19)
        XCTAssertEqual(d.tempMin, 7)
        XCTAssertEqual(d.rangeLabel, "7–19°C")
        XCTAssertTrue(!d.days[0].dow.isEmpty && !d.days[1].dow.isEmpty, "weekday labels present")
    }

    // JS: 'deriveWeather: derives rain + cold conditions from the forecast'
    func testDeriveWeatherDerivesRainAndColdConditionsFromTheForecast() throws {
        let d = try XCTUnwrap(deriveWeather(wEvent([
            WeatherDay(date: "2026-08-03", code: 80, tmax: 12, tmin: 3, precipProb: 70, wind: 15),
        ])))
        XCTAssertTrue(d.conditions.contains("rain"))
        XCTAssertTrue(d.conditions.contains("cold"), "tmin 3°C <= coldMinC")
    }

    // JS: 'deriveWeather: flags a summer trip that is cooler than expected'
    func testDeriveWeatherFlagsASummerTripThatIsCoolerThanExpected() throws {
        let d = try XCTUnwrap(deriveWeather(wEvent([
            WeatherDay(date: "2026-08-03", code: 3, tmax: 12, tmin: 9, precipProb: 10, wind: 10),
        ])))
        XCTAssertTrue(d.coolerThanSeason, "max 12°C < coolMaxSummerC while season is Summer")
        XCTAssertTrue(d.conditions.contains("cold"))
    }

    // JS: 'deriveWeather: hot + windy conditions'
    func testDeriveWeatherHotAndWindyConditions() throws {
        let d = try XCTUnwrap(deriveWeather(wEvent([
            WeatherDay(date: "2026-08-03", code: 0, tmax: 31, tmin: 20, precipProb: 0, wind: 42),
        ])))
        XCTAssertTrue(d.conditions.contains("hot"))
        XCTAssertTrue(d.conditions.contains("wind"))
        XCTAssertTrue(!d.conditions.contains("rain"))
    }

    // JS: 'deriveWeather: returns null when there is no forecast'
    func testDeriveWeatherReturnsNullWhenThereIsNoForecast() {
        XCTAssertNil(deriveWeather(newEvent()))
    }

    // JS: 'weatherSuggestions: suggests condition-matched items, skipping ones already packed'
    func testWeatherSuggestionsSuggestsConditionMatchedItemsSkippingOnesAlreadyPacked() {
        var ev = wEvent([WeatherDay(date: "2026-08-03", code: 61, tmax: 11, tmin: 4, precipProb: 80, wind: 12)])
        ev.entries = [newItem(name: "Rain jacket")]   // already have this one
        let s = weatherSuggestions(ev)
        let names = s.items.map { $0.name }
        XCTAssertTrue(names.contains("Waterproof / pack cover"), "rain add-on offered")
        XCTAssertTrue(names.contains("Long tights"), "cold add-on offered")
        XCTAssertTrue(!names.contains("Rain jacket"), "already-packed item is not re-suggested")
        XCTAssertTrue(s.items.allSatisfy { !($0.reason ?? "").isEmpty }, "each suggestion carries the driving condition")
        XCTAssertTrue(s.summary.count > 0)
    }

    // JS: 'weatherSuggestions: no forecast -> nothing suggested'
    func testWeatherSuggestionsNoForecastNothingSuggested() {
        XCTAssertEqual(weatherSuggestions(newEvent()), WeatherSuggestions(conditions: [], items: [], summary: ""))
    }

    // JS: 'weatherSuggestions: pulls your own tagged gear from the chosen lists'
    func testWeatherSuggestionsPullsYourOwnTaggedGearFromTheChosenLists() throws {
        let list = newList(name: "Hiking", items: [
            newItem(name: "Rain suit", category: "Adventure clothing", container: "Hiking backpack", weather: ["rain"]),
            newItem(name: "Sun umbrella", weather: ["hot"]),  // not forecast -> not suggested
        ])
        var ev = wEvent([WeatherDay(date: "2026-08-03", code: 61, tmax: 16, tmin: 8, precipProb: 80, wind: 12)])
        ev.activities = [list.id]
        let s = weatherSuggestions(ev, [list])
        let own = try XCTUnwrap(s.items.first { $0.name == "Rain suit" }, "your own rain suit is suggested")
        XCTAssertEqual(own.own, true)
        XCTAssertEqual(own.sourceItemId, list.items[0].id, "keeps the source link for trip-review stats")
        XCTAssertEqual(own.container, "Hiking backpack", "carries its container")
        XCTAssertTrue(!s.items.contains { $0.name == "Sun umbrella" }, "hot-only item not suggested when it is not hot")
    }

    // JS: 'weatherSuggestions: your own item is preferred and de-duped against the curated add-on'
    func testWeatherSuggestionsYourOwnItemIsPreferredAndDeDupedAgainstTheCuratedAddOn() {
        let list = newList(name: "Run", items: [newItem(name: "Rain jacket", weather: ["rain"])])
        var ev = wEvent([WeatherDay(date: "2026-08-03", code: 61, tmax: 16, tmin: 9, precipProb: 80, wind: 12)])
        ev.activities = [list.id]
        let s = weatherSuggestions(ev, [list])
        let jackets = s.items.filter { $0.name == "Rain jacket" }
        XCTAssertEqual(jackets.count, 1, "not duplicated by the curated map")
        XCTAssertEqual(jackets.first?.own, true, "the users own item wins")
    }

    // JS: 'pendingWeatherItems: counts conditional gear waiting on a forecast, ignoring packed ones'
    func testPendingWeatherItemsCountsConditionalGearWaitingOnAForecast() {
        let list = newList(name: "Hiking", items: [
            newItem(name: "Rain suit", weather: ["rain"]),
            newItem(name: "Rain cover", weather: ["rain"]),
            newItem(name: "Down jacket", seasons: ["Winter"], weather: ["cold"]),
            newItem(name: "Boots"),  // not weather-tagged
        ])
        var summer = newEvent(activities: [list.id], season: "Summer")
        // Down jacket is Winter-only, so it doesn't count for a Summer trip.
        XCTAssertEqual(pendingWeatherItems(summer, [list]), 2)
        // Already having one packed drops the count.
        summer.entries = [newItem(name: "Rain suit")]
        XCTAssertEqual(pendingWeatherItems(summer, [list]), 1)
    }

    // JS: 'weatherGear: returns all applicable weather items regardless of forecast, with source links'
    func testWeatherGearReturnsAllApplicableWeatherItemsRegardlessOfForecast() {
        let list = newList(name: "Hiking", items: [
            newItem(name: "Rain suit", container: "Hiking backpack", weather: ["rain"]),
            newItem(name: "Down jacket", seasons: ["Winter"], weather: ["cold"]),  // not this season
            newItem(name: "Boots"),  // not tagged
        ])
        var ev = newEvent(activities: [list.id], season: "Summer")
        let gear = weatherGear(ev, [list])   // no forecast at all
        XCTAssertEqual(gear.map { $0.name }, ["Rain suit"])
        XCTAssertEqual(gear.first?.container, "Hiking backpack")
        XCTAssertEqual(gear.first?.sourceItemId, list.items[0].id)
        XCTAssertEqual(gear.first?.conditions, ["rain"])
        // once packed, it drops out
        ev.entries = [newItem(name: "Rain suit")]
        XCTAssertEqual(weatherGear(ev, [list]).count, 0)
    }

    // --- not in the JS suite (every expected value below was read off the JS model in Node) ---

    func testTheConstantsAreTheJSOnes() {
        XCTAssertEqual(WEATHER_THRESHOLDS, WeatherThresholds(coldMinC: 5, coolMaxSummerC: 14, hotMaxC: 27, windKmh: 35, wetProb: 50))
        XCTAssertEqual(Set(WEATHER_SUGGESTIONS.keys), Set(WEATHER_CONDITION_IDS))
        XCTAssertEqual(WEATHER_SUGGESTIONS["hot"]?.map { $0.name }, ["Sun hat / cap", "Sunscreen", "Extra water bottle"])
        XCTAssertEqual(WEATHER_SUGGESTIONS["hot"]?[1].json, ["name": "Sunscreen", "category": "Toiletries", "liquid": true])
    }

    func testWeatherCodeEveryBandAndTheGaps() {
        let expect: [(Double, String, String, Bool)] = [
            (1, "sun-cloud", "Partly cloudy", false), (2, "sun-cloud", "Partly cloudy", false),
            (45, "fog", "Fog", false), (48, "fog", "Fog", false), (51, "rain", "Drizzle", true), (57, "rain", "Drizzle", true),
            (61, "rain", "Rain", true), (67, "rain", "Rain", true), (71, "snow", "Snow", true), (77, "snow", "Snow", true),
            (80, "rain", "Showers", true), (82, "rain", "Showers", true), (85, "snow", "Snow showers", true),
            (86, "snow", "Snow showers", true), (99, "storm", "Thunderstorm", true), (1000, "storm", "Thunderstorm", true),
            (4, "cloud", "—", false), (58, "cloud", "—", false), (90, "cloud", "—", false), (-1, "cloud", "—", false),
        ]
        for (code, icon, label, wet) in expect {
            XCTAssertEqual(weatherCode(code), WeatherCodeInfo(icon: icon, label: label, wet: wet), "\(code)")
        }
        XCTAssertEqual(weatherCode(nil).label, "—")             // Number(undefined) is NaN
        XCTAssertEqual(weatherCode(.nan).label, "—")
        XCTAssertEqual(weatherCode(json: "63").label, "Rain")   // it goes through Number()
        XCTAssertEqual(weatherCode(json: nil).label, "—")
        XCTAssertEqual(weatherCode(json: .null).icon, "sun")    // Number(null) is 0
    }

    func testTheWeekdayIsTheCalendarDatesOwnOnEveryDeviceInEveryTimeZone() {
        XCTAssertEqual(dowLabel("2026-08-03"), "Mon")
        XCTAssertEqual(dowLabel("2026-08-09"), "Sun")
        XCTAssertEqual(dowLabel("2024-02-29"), "Thu")
        XCTAssertEqual(dowLabel("1969-12-31"), "Wed")           // before 1970
        XCTAssertEqual(dowLabel("2018-11-04"), "Sun")           // a day São Paulo had no midnight — still that day
        XCTAssertEqual(dowLabel("2026-02-30"), "Mon")           // rolls over to 2 March, as V8 does
        XCTAssertEqual(dowLabel("nope"), "")
        XCTAssertEqual(dowLabel(""), "")
    }

    func testDeriveWeatherRoundsHalvesUpAndUsesTheRawRainChanceButTheRoundedWind() throws {
        let ev = newEvent(season: "Summer", weather: WeatherSnapshot(place: "Åre, SE", lat: 63.4, lon: 13.08, fetchedAt: "2026-08-01T00:00:00Z", daily: [
            WeatherDay(date: "2026-08-03", code: 61, tmax: 12.5, tmin: -0.4, precipProb: 49.6, wind: 34.5),
            WeatherDay(date: "2026-08-04", code: 73, tmax: 11.4, tmin: 2.5, precipProb: 10, wind: 5),
            WeatherDay(date: "2026-08-05", code: 3, tmax: 13, tmin: 6, precipProb: 50, wind: 0),
            WeatherDay(date: "nope", code: 0, tmax: 13, tmin: 6, precipProb: 0, wind: 0),
        ]))
        let d = try XCTUnwrap(deriveWeather(ev))
        XCTAssertEqual(d.json, try JSONValue.parse("""
        {"place":"Åre, SE","fetchedAt":"2026-08-01T00:00:00Z","days":[{"date":"2026-08-03","dow":"Mon","icon":"rain","label":"Rain","tmax":13,"tmin":0,"precipProb":50,"wind":35,"rainy":true,"snowy":false},{"date":"2026-08-04","dow":"Tue","icon":"snow","label":"Snow","tmax":11,"tmin":3,"precipProb":10,"wind":5,"rainy":true,"snowy":true},{"date":"2026-08-05","dow":"Wed","icon":"cloud","label":"Cloudy","tmax":13,"tmin":6,"precipProb":50,"wind":0,"rainy":true,"snowy":false},{"date":"nope","dow":"","icon":"sun","label":"Clear","tmax":13,"tmin":6,"precipProb":0,"wind":0,"rainy":false,"snowy":false}],"tempMin":0,"tempMax":13,"rangeLabel":"0–13°C","conditions":["rain","snow","cold","wind"],"coolerThanSeason":true}
        """))
        XCTAssertEqual(weatherSuggestions(ev).json, try JSONValue.parse("""
        {"conditions":["rain","snow","cold","wind"],"items":[{"name":"Rain jacket","category":"Adventure clothing","reason":"rain"},{"name":"Waterproof / pack cover","category":"Adventure clothing","reason":"rain"},{"name":"Warm gloves","category":"Adventure clothing","reason":"snow"},{"name":"Traction spikes","category":"Footwear","reason":"snow"},{"name":"Warm mid-layer","category":"Adventure clothing","reason":"cold"},{"name":"Beanie + gloves","category":"Adventure clothing","reason":"cold"},{"name":"Long tights","category":"Adventure clothing","reason":"cold"},{"name":"Windbreaker","category":"Adventure clothing","reason":"wind"}],"summary":"Rain likely · snow · cooler than Summer · windy"}
        """))
    }

    func testADayWithNoTemperaturePoisonsTheRangeAndTripsNoCondition() throws {
        let ev = newEvent(season: "Winter", weather: WeatherSnapshot(daily: [WeatherDay(date: "2026-08-03", code: 0)]))
        let d = try XCTUnwrap(deriveWeather(ev))
        XCTAssertEqual(d.json, try JSONValue.parse("""
        {"place":"","fetchedAt":"","days":[{"date":"2026-08-03","dow":"Mon","icon":"sun","label":"Clear","tmax":null,"tmin":null,"precipProb":0,"wind":0,"rainy":false,"snowy":false}],"tempMin":null,"tempMax":null,"rangeLabel":"NaN–NaN°C","conditions":[],"coolerThanSeason":false}
        """))
        XCTAssertEqual(weatherSuggestions(ev), WeatherSuggestions())
        XCTAssertNil(deriveWeather(nil))
    }

    func testTheSummaryNamesUpToTwoRainyDays() {
        func summary(_ days: [WeatherDay], season: String = "Winter") -> String {
            weatherSuggestions(newEvent(season: season, weather: WeatherSnapshot(daily: days))).summary
        }
        XCTAssertEqual(summary([WeatherDay(date: "2026-08-03", code: 61, tmax: 20, tmin: 10),
                                WeatherDay(date: "2026-08-04", code: 61, tmax: 20, tmin: 10)]), "Rain Mon–Tue")
        XCTAssertEqual(summary([WeatherDay(date: "2026-08-03", code: 0, tmax: 30, tmin: 2, wind: 40)]), "cold spells · hot · windy")
        XCTAssertEqual(summary([WeatherDay(date: "2026-08-03", code: 0, tmax: 20, tmin: 10)]), "")
    }

    func testYourOwnGearCarriesEverythingAndTheJSONHasTheJSKeys() throws {
        let list = newList(id: "L", name: "Hiking", group: "WET", items: [
            newItem(id: "i1", name: "Rain  Suit", swedish: "Regnställ", category: "Adventure clothing", container: "Duffel bag",
                    phase: "day", contexts: ["Race"], weather: ["cold", "rain"], weight: 450, liquid: false),
            newItem(id: "i2", name: "rain suit", weather: ["rain"]),      // the same name, spelt differently → once
            newItem(id: "i3", name: "", weather: ["rain"]),               // nameless → never
            newItem(id: "i4", name: "Pool shoes", contexts: ["Indoor"], weather: ["rain"]),   // a WET list minds the context
        ])
        var ev = newEvent(activities: ["nope", "L"], season: "Summer", contexts: ["Race"],
                          weather: WeatherSnapshot(daily: [WeatherDay(date: "2026-08-03", code: 61, tmax: 20, tmin: 10)]))
        let gear = weatherGear(ev, [list])
        XCTAssertEqual(gear.count, 1)
        XCTAssertEqual(gear.first?.json, ["name": "Rain  Suit", "swedish": "Regnställ", "category": "Adventure clothing",
                                          "container": "Duffel bag", "phase": "day", "itemType": "item", "liquid": false,
                                          "weight": 450, "sourceListId": "L", "sourceItemId": "i1",
                                          "conditions": ["cold", "rain"], "own": true])
        let s = weatherSuggestions(ev, [list])
        XCTAssertEqual(s.items.first?.reason, "rain")            // the first TAG the forecast calls for, not the first tag
        XCTAssertNil(s.items.first?.conditions)
        XCTAssertEqual(s.items.map { $0.name }, ["Rain  Suit", "Rain jacket", "Waterproof / pack cover"])
        // An event that pins no context keeps every item of a WET list.
        ev.contexts = []
        XCTAssertEqual(weatherGear(ev, [list]).map { $0.name }, ["Rain  Suit", "Pool shoes"])
    }
}

// JS tests NOT ported as written: none. (`assert.ok(s.items.every((i) => i.reason))` reads
// `reason` as an Optional here — nil is the JS `undefined` a `weatherGear` row has.)
