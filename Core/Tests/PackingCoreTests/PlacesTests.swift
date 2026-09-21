import XCTest
@testable import PackingCore

// Ported from tests/model.test.mjs — "Places visited (world map)".
// ('coerceGeo: keeps valid coordinates, rejects junk' belongs to the foundation and
// lives in EventsTests.swift.)
final class PlacesTests: XCTestCase {
    // `placesVisited` sorts by "today". The JS suite runs on the real clock, with every
    // trip below already in the past; pinning the clock keeps it that way for good.
    override func setUp() { super.setUp(); PackingEnv.freeze(at: "2026-09-01T12:00:00.000Z") }
    override func tearDown() { PackingEnv.reset(); super.tearDown() }

    // JS: 'eventCoords: reads weather snapshot, then the geo fix, else null'
    func testEventCoordsReadsWeatherSnapshotThenTheGeoFixElseNull() {
        let bare = newEvent(name: "Nowhere")
        XCTAssertNil(eventCoords(bare))

        var withGeo = newEvent(name: "Geo only", destination: "Oslo")
        withGeo.geo = GeoFix(lat: 59.91, lon: 10.75, place: "Oslo, NO")
        XCTAssertEqual(eventCoords(withGeo), GeoFix(lat: 59.91, lon: 10.75, place: "Oslo, NO"))

        // A fetched forecast wins over the geo fix, and carries its tidy label.
        var withWeather = newEvent(name: "Weathered", destination: "oslo")
        withWeather.geo = GeoFix(lat: 1, lon: 1, place: "stale")
        withWeather.weather = WeatherSnapshot(place: "Oslo, NO", lat: 59.91, lon: 10.75, daily: [])
        XCTAssertEqual(eventCoords(withWeather), GeoFix(lat: 59.91, lon: 10.75, place: "Oslo, NO"))
    }

    // JS: 'eventsNeedingCoords: only trips with a destination and no coordinates'
    func testEventsNeedingCoordsOnlyTripsWithADestinationAndNoCoordinates() {
        var located = newEvent(name: "Has coords", destination: "Rome")
        located.geo = GeoFix(lat: 41.9, lon: 12.5, place: "Rome, IT")
        let needs = newEvent(name: "Needs lookup", destination: "Lisbon")
        let noDest = newEvent(name: "No destination")
        let list = eventsNeedingCoords([located, needs, noDest])
        XCTAssertEqual(list.map { $0.name }, ["Needs lookup"])
    }

    // JS: 'placesVisited: merges repeat visits to the same place into one pin'
    func testPlacesVisitedMergesRepeatVisitsToTheSamePlaceIntoOnePin() throws {
        func mk(_ name: String, _ startDate: String, _ place: String, _ lat: Double, _ lon: Double) -> TripEvent {
            var e = newEvent(name: name, startDate: startDate, destination: place)
            e.geo = GeoFix(lat: lat, lon: lon, place: place)
            return e
        }
        let events = [
            mk("Stockholm spring", "2025-04-10", "Stockholm, SE", 59.33, 18.06),
            mk("Stockholm winter", "2026-01-05", "Stockholm, SE", 59.33, 18.06),
            mk("London trip", "2025-09-01", "London, GB", 51.5, -0.12),
            newEvent(name: "Undestined"),   // no coords -> not on the map
        ]
        let pins = placesVisited(events)
        XCTAssertEqual(pins.count, 2, "two distinct places")
        let sthlm = try XCTUnwrap(pins.first { $0.place == "Stockholm, SE" })
        XCTAssertEqual(sthlm.events.count, 2, "both Stockholm trips under one pin")
        // Newest visit leads within the pin.
        XCTAssertEqual(sthlm.events[0].name, "Stockholm winter")
        let london = try XCTUnwrap(pins.first { $0.place == "London, GB" })
        XCTAssertEqual(london.events.count, 1)
    }

    // JS: 'placesVisited: same spot with no label still merges by coordinates'
    func testPlacesVisitedSameSpotWithNoLabelStillMergesByCoordinates() {
        var a = newEvent(name: "A", destination: "spot")
        a.geo = GeoFix(lat: 12.34, lon: 56.78, place: "")
        var b = newEvent(name: "B", destination: "spot")
        b.geo = GeoFix(lat: 12.341, lon: 56.779, place: "")   // ~same, rounds together
        let pins = placesVisited([a, b])
        XCTAssertEqual(pins.count, 1)
        XCTAssertEqual(pins.first?.events.count, 2)
    }

    // JS: 'tripPath: dated trips with coordinates, oldest first; undated left off'
    func testTripPathDatedTripsWithCoordinatesOldestFirstUndatedLeftOff() {
        func mk(_ name: String, _ startDate: String, _ lat: Double?, _ lon: Double? = nil) -> TripEvent {
            var e = newEvent(name: name, startDate: startDate, destination: name)
            if let lat = lat, let lon = lon { e.geo = GeoFix(lat: lat, lon: lon, place: name) }
            return e
        }
        let events = [
            mk("London", "2025-09-01", 51.5, -0.12),
            mk("Tokyo", "2024-11-02", 35.68, 139.7),
            mk("Undated", "", 10, 10),            // no date -> not on the line
            mk("NoCoords", "2025-01-01", nil),    // no coords -> not on the line
            mk("Oslo", "2026-01-05", 59.9, 10.75),
        ]
        let path = tripPath(events)
        XCTAssertEqual(path.map { $0.name }, ["Tokyo", "London", "Oslo"])
        XCTAssertEqual(path.first?.lat, 35.68)
    }

    // JS: 'mostVisited: the top place, but only when somewhere beats a single visit'
    func testMostVisitedTheTopPlaceButOnlyWhenSomewhereBeatsASingleVisit() {
        func mk(_ name: String, _ startDate: String, _ place: String) -> TripEvent {
            var e = newEvent(name: name, startDate: startDate, destination: place)
            e.geo = GeoFix(lat: 1, lon: 1, place: place)
            return e
        }
        // Everywhere once -> nothing stands out.
        XCTAssertNil(mostVisited(placesVisited([
            mk("a", "2025-01-01", "Alpha, X"), mk("b", "2025-02-01", "Beta, X"),
        ])))
        // Beta visited twice -> it's the winner.
        let top = mostVisited(placesVisited([
            mk("a", "2025-01-01", "Alpha, X"),
            mk("b1", "2025-02-01", "Beta, X"), mk("b2", "2025-03-01", "Beta, X"),
        ]))
        XCTAssertEqual(top?.place, "Beta, X")
        XCTAssertEqual(top?.events.count, 2)
    }

    // --- not in the JS suite (every expected value below was read off the JS model in Node) ---

    func testToFixedTakesTheLargerDigitOnAnExactTie() {
        XCTAssertEqual(jsToFixed1(59.25), "59.3")      // printf says 59.2
        XCTAssertEqual(jsToFixed1(12.25), "12.3")
        XCTAssertEqual(jsToFixed1(59.75), "59.8")
        XCTAssertEqual(jsToFixed1(-0.25), "-0.3")      // away from zero
        XCTAssertEqual(jsToFixed1(-0.0), "0.0")
        XCTAssertEqual(jsToFixed1(-0.04), "-0.0")
        XCTAssertEqual(jsToFixed1(12.35), "12.3")      // 12.35 is really 12.3499999…
        XCTAssertEqual(jsToFixed1(0.05), "0.1")        // and 0.05 is really 0.05000000000000000277
        XCTAssertEqual(jsToFixed1(139.7), "139.7")
        XCTAssertEqual(jsToFixed1(-180), "-180.0")
    }

    func testThePinKeyIsTheNormalisedLabelElseTheRoundedCoordinates() {
        func mk(_ lat: Double, _ lon: Double, _ place: String = "") -> TripEvent {
            var e = newEvent(name: "x")
            e.geo = GeoFix(lat: lat, lon: lon, place: place)
            return e
        }
        let pins = placesVisited([mk(59.25, -0.25), mk(-0.04, 12.35), mk(12.25, 0.05), mk(1, 2, "  Stockholm,   SE ")])
        XCTAssertEqual(pins.map { $0.key }, ["c:59.3,-0.3", "c:-0.0,12.3", "c:12.3,0.1", "n:stockholm, se"])
        XCTAssertEqual(pins.last?.place, "  Stockholm,   SE ")   // the label itself is kept as written
    }

    func testEventCoordsFallsBackToTheDestinationForItsLabelAndDoesNotRangeCheckAForecast() {
        var e = newEvent(name: "x", destination: "Visby")
        e.geo = GeoFix(lat: 57.6, lon: 18.3, place: "")
        XCTAssertEqual(eventCoords(e)?.place, "Visby")
        e.geo = GeoFix(lat: 999, lon: 0, place: "off the map")
        XCTAssertNil(eventCoords(e))                              // the geo fix goes through coerceGeo…
        e.weather = WeatherSnapshot(place: "", lat: 999, lon: 0, daily: [])
        XCTAssertEqual(eventCoords(e), GeoFix(lat: 999, lon: 0, place: "Visby"))   // …a forecast does not
        e.weather = WeatherSnapshot(place: "", lat: nil, lon: 0, daily: [])        // NaN
        XCTAssertNil(eventCoords(e))
        XCTAssertNil(eventCoords(nil))
        var blank = newEvent(name: "blank", destination: "   ")
        blank.geo = nil
        XCTAssertEqual(eventsNeedingCoords([blank]).count, 0)     // a destination of spaces is no destination
    }

    func testPinsFollowSortEventsForListUpcomingFirstThenUndatedThenPast() {
        func mk(_ name: String, _ startDate: String, _ place: String, createdAt: String = "2026-01-01T00:00:00.000Z") -> TripEvent {
            var e = newEvent(name: name, startDate: startDate, destination: place, createdAt: createdAt)
            e.geo = GeoFix(lat: 1, lon: 1, place: place)
            return e
        }
        // "Today" is 2026-09-01 (see setUp).
        let pins = placesVisited([
            mk("past old", "2025-01-01", "A"), mk("far", "2027-01-01", "B"), mk("draft old", "", "C", createdAt: "2026-02-01T00:00:00.000Z"),
            mk("past new", "2026-08-01", "D"), mk("near", "2026-09-01", "E"), mk("draft new", "", "F", createdAt: "2026-03-01T00:00:00.000Z"),
            mk("junk date", "soon", "G", createdAt: "2026-01-15T00:00:00.000Z"), mk("back to A", "2026-10-01", "a"),
        ])
        XCTAssertEqual(pins.map { $0.place }, ["E", "a", "B", "F", "C", "G", "D"])
        XCTAssertEqual(pins.first { $0.key == "n:a" }?.events.map { $0.name }, ["back to A", "past old"])
        XCTAssertEqual(mostVisited(pins)?.place, "a")
        // tripPath compares start dates as TEXT, and keeps whatever text is there.
        XCTAssertEqual(tripPath(pins.flatMap { $0.events }).map { $0.date },
                       ["2025-01-01", "2026-08-01", "2026-09-01", "2026-10-01", "2027-01-01", "soon"])
    }
}

// JS tests NOT ported as written: none.
