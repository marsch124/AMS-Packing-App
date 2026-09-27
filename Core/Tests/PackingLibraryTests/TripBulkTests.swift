import XCTest
@testable import PackingCore
@testable import PackingLibrary

final class TripBulkTests: XCTestCase {
    override func setUp() { PackingEnv.reset(); _ = setPhases(DEFAULT_PHASES) }
    override func tearDown() { PackingEnv.reset(); _ = setPhases(DEFAULT_PHASES) }

    /// "Mark everything packed" and "Clear every tick": every line but those set
    /// aside, which are not being packed; the count says how many moved.
    func testEverythingIsTickedAndClearedButWhatIsSetAside() {
        var lib = Library()
        var trip = newEvent(name: "Trip")
        var a = newItem(name: "A"); a.checked = true
        let b = newItem(name: "B"), c = newItem(name: "C")
        var d = newItem(name: "D"); d.skipped = true
        trip.entries = [a, b, c, d]
        lib.trips = [trip]

        XCTAssertEqual(lib.setAllChecked(true, tripId: trip.id), 2, "only the two unticked lines move")
        XCTAssertEqual(lib.trips[0].entries.map(\.checked), [true, true, true, false], "a set-aside line is not ticked")
        XCTAssertEqual(progress(lib.trips[0].entries).done, 3)
        XCTAssertEqual(lib.setAllChecked(true, tripId: trip.id), 0, "nothing left to tick")

        XCTAssertEqual(lib.setAllChecked(false, tripId: trip.id), 3)
        XCTAssertFalse(lib.trips[0].entries.contains { $0.checked }, "a tick survived Clear")
        XCTAssertTrue(lib.trips[0].entries[3].skipped, "Clear touched the set-aside line")
        XCTAssertEqual(lib.setAllChecked(true, tripId: "nope"), 0)
    }

    private func rainy() -> (Library, String) {
        var lib = Library()
        var hike = newList(name: "Hiking", group: "GA")
        var coat = newItem(name: "Rain shell"); coat.weather = ["rain"]; coat.weight = 420; coat.category = "Clothing"
        hike.items = [coat, newItem(name: "Walking poles")]
        lib.saveTemplate(hike)
        var trip = newEvent(name: "Two nights out", startDate: "2026-10-03", endDate: "2026-10-05")
        trip.nights = 2
        trip.activities = lib.templates.filter { $0.name == "Hiking" }.map { $0.id }
        trip.entries = buildTotalEntries(trip, lib.resolvedTemplates())
        lib.trips = [trip]
        let days = (0...2).map { n in
            WeatherDay(date: "2026-10-0\(3 + n)", code: 61, tmax: 8, tmin: 2, precipProb: 90, wind: 24)
        }
        _ = lib.setWeather(tripId: trip.id, place: "Testville", lat: 58.59, lon: 16.18,
                           snapshot: WeatherSnapshot(place: "Testville, SE", lat: 58.59, lon: 16.18,
                                                     fetchedAt: nowISO(), daily: days))
        return (lib, trip.id)
    }

    /// The weather card's "Add all": everything it asks for arrives once, and then
    /// nothing is asked for.
    func testAddAllTakesEveryWeatherSuggestionOnce() {
        var (lib, id) = rainy()
        let asked = lib.weatherMissing(tripId: id)
        XCTAssertGreaterThanOrEqual(asked.count, 2, "the rainy trip should ask for several things")
        let before = lib.trip(id)?.entries.count ?? 0
        XCTAssertEqual(lib.addAllWeatherGear(tripId: id), asked.count)
        XCTAssertEqual(lib.trip(id)?.entries.count, before + asked.count)
        XCTAssertTrue(lib.weatherMissing(tripId: id).isEmpty, "still asking after Add all")
        XCTAssertEqual(lib.addAllWeatherGear(tripId: id), 0, "a second Add all added again")
    }

    /// His own weather gear keeps where it came from (the web app's entryFromWeatherSpec),
    /// so the review credits that thing — and its weight counts in the bags.
    func testHisOwnWeatherGearKeepsItsSource() {
        var (lib, id) = rainy()
        guard let shell = lib.weatherMissing(tripId: id).first(where: { $0.name == "Rain shell" }) else {
            return XCTFail("his rain shell is not suggested")
        }
        let line = lib.addWeatherGear(tripId: id, shell)
        XCTAssertEqual(line?.sourceItemId, shell.sourceItemId)
        XCTAssertNotNil(line?.sourceItemId, "the line forgot the thing it came from")
        XCTAssertEqual(line?.weight, 420)
        XCTAssertEqual(line?.category, "Clothing")
        XCTAssertEqual(lib.trip(id)?.entries.last?.sourceItemId, shell.sourceItemId, "not stored on the trip")
        XCTAssertTrue(lib.trip(id)?.entries.last?.custom ?? false, "a weather line must survive a rebuild")
    }
}
