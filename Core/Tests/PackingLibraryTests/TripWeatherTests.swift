import XCTest
import PackingCore
@testable import PackingLibrary

/// The forecast on a trip: what it says, what it asks you to take, and when it is
/// worth looking up again.
final class TripWeatherTests: XCTestCase {
    override func setUp() { PackingEnv.reset(); _ = setPhases(DEFAULT_PHASES) }
    override func tearDown() { PackingEnv.reset(); _ = setPhases(DEFAULT_PHASES) }

    private func wet(from start: String, nights: Int) -> WeatherSnapshot {
        let days = (0...nights).map { n -> WeatherDay in
            let d = Calendar(identifier: .gregorian).date(byAdding: .day, value: n,
                                                          to: ISO8601DateFormatter().date(from: "\(start)T00:00:00Z")!)!
            return WeatherDay(date: String(ISO8601DateFormatter().string(from: d).prefix(10)),
                              code: 61, tmax: 8, tmin: 2, precipProb: 90, wind: 24)
        }
        return WeatherSnapshot(place: "Testville, SE", lat: 58.59, lon: 16.18, fetchedAt: nowISO(), daily: days)
    }

    /// A library with one trip built from a list whose rain gear is tagged.
    private func library() -> (Library, String) {
        var lib = Library()
        var hike = newList(name: "Hiking", group: "GA")
        var coat = newItem(name: "Rain shell")
        coat.weather = ["rain"]
        var poles = newItem(name: "Walking poles")
        hike.items = [coat, poles]
        lib.saveTemplate(hike)
        var trip = newEvent(name: "Two nights out", startDate: "2026-10-03", endDate: "2026-10-05")
        trip.nights = 2
        trip.activities = lib.templates.filter { $0.name == "Hiking" }.map { $0.id }
        trip.entries = buildTotalEntries(trip, lib.resolvedTemplates())
        lib.trips = [trip]
        return (lib, trip.id)
    }

    func testAForecastIsKeptOnTheTripAndReadBack() {
        var (lib, id) = library()
        XCTAssertNil(lib.weather(tripId: id), "a trip starts with no forecast")
        XCTAssertTrue(lib.setWeather(tripId: id, place: "Testville", lat: 58.59, lon: 16.18,
                                     snapshot: wet(from: "2026-10-03", nights: 2)))
        guard let said = lib.weather(tripId: id) else { return XCTFail("the forecast did not come back") }
        XCTAssertEqual(said.place, "Testville, SE")
        XCTAssertEqual(said.days.count, 3)
        XCTAssertTrue(said.conditions.contains("rain"), "three wet days and no rain in the conditions")
        XCTAssertTrue(said.conditions.contains("cold"), "2–8°C is not warm")
        XCTAssertEqual(lib.trip(id)?.destination, "Testville", "the place was not kept")
    }

    func testTheGearItAsksForIsWhatIsMissing() {
        var (lib, id) = library()
        _ = lib.setWeather(tripId: id, place: "Testville", lat: 58.59, lon: 16.18,
                           snapshot: wet(from: "2026-10-03", nights: 2))
        let asked = lib.weatherMissing(tripId: id)
        XCTAssertFalse(asked.isEmpty, "wet and cold, and nothing suggested")
        XCTAssertTrue(asked.contains { $0.name == "Rain shell" }, "his own tagged gear should lead")

        // Take it along: it becomes a line, and stops being suggested.
        guard let shell = asked.first(where: { $0.name == "Rain shell" }) else { return }
        XCTAssertNotNil(lib.addWeatherGear(tripId: id, shell))
        XCTAssertTrue(lib.trip(id)?.entries.contains { $0.name == "Rain shell" } ?? false,
                      "it did not reach the trip")
        XCTAssertFalse(lib.weatherMissing(tripId: id).contains { $0.name == "Rain shell" },
                       "it is still being asked for although it is packed")
    }

    func testWhenItIsWorthLookingAgain() {
        var (lib, id) = library()
        XCTAssertTrue(lib.forecastIsStale(tripId: id), "no forecast at all is stale")

        var fresh = wet(from: "2026-10-03", nights: 2)
        fresh.fetchedAt = nowISO()
        _ = lib.setWeather(tripId: id, place: "Testville", lat: 58.59, lon: 16.18, snapshot: fresh)
        XCTAssertFalse(lib.forecastIsStale(tripId: id), "a forecast taken just now is not stale")

        // Six hours on, it is.
        let later = Date().addingTimeInterval(7 * 3600)
        XCTAssertTrue(lib.forecastIsStale(tripId: id, now: later))

        // And a different place makes it stale whatever the clock says.
        var moved = lib
        _ = moved.setWeather(tripId: id, place: "Elsewhere", lat: 1, lon: 1, snapshot: fresh)
        XCTAssertTrue(moved.forecastIsStale(tripId: id), "the place changed and the forecast did not")
    }

    func testAForecastTravelsInABackup() {
        var (lib, id) = library()
        _ = lib.setWeather(tripId: id, place: "Testville", lat: 58.59, lon: 16.18,
                           snapshot: wet(from: "2026-10-03", nights: 2))
        guard let json = try? JSONValue.parse(lib.backupData()) else { return XCTFail("the backup did not parse") }
        let (back, report) = Importer.library(from: BackupFile(json: json))
        XCTAssertTrue(report.isFaithful)
        XCTAssertEqual(back.weather(tripId: id)?.days.count, 3, "the forecast did not survive the backup")
        XCTAssertEqual(back.trip(id)?.destination, "Testville")
    }
}
