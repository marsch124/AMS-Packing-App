import XCTest
@testable import PackingCore
@testable import PackingLibrary

final class WorldMapTests: XCTestCase {
    override func setUp() { PackingEnv.freeze() }
    override func tearDown() { PackingEnv.reset() }

    private func trip(_ name: String, _ start: String, place: String = "", geo: GeoFix? = nil) -> TripEvent {
        var t = newEvent(name: name, startDate: start, endDate: start)
        t.destination = place
        t.geo = geo
        return t
    }

    /// Repeat visits share a pin; a trip with a place but no spot waits to be found;
    /// the summary counts places and trips; the line runs oldest first.
    func testTripsBecomePinsAndALine() {
        var lib = Library()
        let kalmar = GeoFix(lat: 56.66, lon: 16.36, place: "Kalmar, SE")
        lib.trips = [trip("Ironman", "2026-08-12", place: "Kalmar", geo: kalmar),
                     trip("Kalmar again", "2025-08-10", place: "Kalmar", geo: kalmar),
                     trip("GBG", "2026-09-21", place: "Göteborg", geo: GeoFix(lat: 57.71, lon: 11.97, place: "Göteborg, SE")),
                     trip("Somewhere", "2026-07-01", place: "Visby"),
                     trip("No place", "2026-06-01")]
        let pins = lib.mapPlaces()
        XCTAssertEqual(pins.count, 2, "two places: Kalmar twice is one pin")
        XCTAssertEqual(pins.first { $0.place == "Kalmar, SE" }?.events.count, 2)
        XCTAssertEqual(Library.mapSummary(pins), "2 places · 3 trips")
        XCTAssertEqual(Library.mapSummary([]), "0 places · 0 trips")
        XCTAssertEqual(mostVisited(pins)?.place, "Kalmar, SE")
        XCTAssertEqual(lib.mapPath().map(\.name), ["Kalmar again", "Ironman", "GBG"], "the line is not oldest first")
        XCTAssertEqual(lib.placesToFind().map(\.name), ["Somewhere"], "only a trip with a place and no spot waits")

        // Found: it joins the map with the service's label, and no longer waits.
        let visby = lib.trips[3].id
        XCTAssertTrue(lib.setPlace(tripId: visby, lat: 57.64, lon: 18.29, label: " Visby, SE "))
        XCTAssertEqual(lib.trips[3].geo?.place, "Visby, SE")
        XCTAssertEqual(lib.mapPlaces().count, 3)
        XCTAssertTrue(lib.placesToFind().isEmpty)
        XCTAssertFalse(lib.setPlace(tripId: visby, lat: 120, lon: 18, label: "Nowhere"), "an impossible spot was kept")
        XCTAssertFalse(lib.setPlace(tripId: "nope", lat: 1, lon: 1, label: "X"))
    }

    /// A forecast keeps the map's label on the trip, as the web app does.
    func testAForecastGivesTheMapItsLabel() {
        var lib = Library()
        let t = trip("Run", "2026-10-03")
        lib.trips = [t]
        let snap = WeatherSnapshot(place: "Kalmar, SE", lat: 56.66, lon: 16.36, fetchedAt: nowISO(), daily: [])
        XCTAssertTrue(lib.setWeather(tripId: t.id, place: "Kalmar", lat: 56.66, lon: 16.36, snapshot: snap))
        XCTAssertEqual(lib.trips[0].geo?.place, "Kalmar, SE")
    }
}
