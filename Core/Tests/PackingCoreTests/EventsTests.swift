import XCTest
@testable import PackingCore

// Ported from tests/model.test.mjs — coerceEvent / newEvent, coerceGeo and the
// coercion half of the weather snapshot. (deriveWeather, eventCoords and the rest of
// the weather and places logic belong to a later section.)
final class EventsTests: XCTestCase {
    override func tearDown() { PackingEnv.reset(); super.tearDown() }

    // JS: 'coerceEvent: normalises destination + weather, drops a malformed snapshot'
    func testCoerceEventNormalisesDestinationAndWeather() throws {
        let ok = try XCTUnwrap(coerceEvent(json: ["destination": "Nice", "weather": ["place": "Nice, FR", "daily": [["date": "2026-08-03", "code": "0", "tmax": "20", "tmin": "12", "precipProb": "5", "wind": "9"]]]]))
        XCTAssertEqual(ok.destination, "Nice")
        XCTAssertEqual(ok.weather?.daily[0].code, 0)
        XCTAssertEqual(ok.weather?.daily[0].tmax, 20)
        let bad = try XCTUnwrap(coerceEvent(json: ["weather": ["nope": true]]))
        XCTAssertNil(bad.weather)
        XCTAssertEqual(bad.destination, "")
    }

    // JS: 'coerceGeo: keeps valid coordinates, rejects junk'
    func testCoerceGeoKeepsValidCoordinatesRejectsJunk() {
        XCTAssertEqual(coerceGeo(json: ["lat": 59.33, "lon": 18.06, "place": "Stockholm, SE"]),
                       GeoFix(lat: 59.33, lon: 18.06, place: "Stockholm, SE"))
        XCTAssertEqual(coerceGeo(json: ["lat": "51.5", "lon": "-0.12"]), GeoFix(lat: 51.5, lon: -0.12, place: ""))
        XCTAssertNil(coerceGeo(json: nil))
        XCTAssertNil(coerceGeo(json: ["lat": 10]))               // missing lon
        XCTAssertNil(coerceGeo(json: ["lat": 999, "lon": 0]))    // out of range
        XCTAssertNil(coerceGeo(json: ["lat": "x", "lon": "y"]))  // not numbers
        // (the typed form)
        XCTAssertNil(coerceGeo(GeoFix(lat: 999, lon: 0)))
        XCTAssertNil(coerceGeo(GeoFix(lat: .nan, lon: 0)))
        XCTAssertNil(coerceGeo(nil as GeoFix?))
    }

    // JS: 'coerceEvent + newEvent carry the laundry flag'
    func testCoerceEventAndNewEventCarryTheLaundryFlag() {
        XCTAssertEqual(newEvent().laundry, false)
        XCTAssertEqual(coerceEvent(json: ["laundry": true])?.laundry, true)
        XCTAssertEqual(coerceEvent(json: [:])?.laundry, false)
    }

    // --- not in the JS suite ---

    func testNewEventHasTheJSDefaultsAndCoerceEventAloneDoesNot() throws {
        PackingEnv.freeze(at: "2026-08-20T12:00:00.000Z")
        let e = newEvent(name: "Åre")
        XCTAssertEqual([e.mode, e.transport, e.season, e.catering, e.status], ["trip", "Car", "Summer", "mixed", "active"])
        XCTAssertEqual(e.createdAt, "2026-08-20T12:00:00.000Z")
        XCTAssertEqual(e.id, "id-1")
        XCTAssertEqual(newEvent(json: ["name": "Åre", "mode": "quick", "nights": 3.9, "weatherOn": ["cold", "fog"]]).nights, 3)
        XCTAssertEqual(newEvent(json: ["weatherOn": ["cold", "fog"]]).weatherOn, ["cold"])
        // coerceEvent on its own never invents a transport or a season.
        let bare = try XCTUnwrap(coerceEvent(json: ["name": "Bare", "mode": "whatever", "status": "paused", "nights": -2]))
        XCTAssertEqual([bare.mode, bare.transport, bare.season, bare.catering, bare.status], ["trip", "", "", "", "active"])
        XCTAssertEqual(bare.nights, 0)
        XCTAssertNil(coerceEvent(json: "nope"))
    }

    func testWeatherNumbersFollowNumberAndNaNIsNil() throws {
        let w = try XCTUnwrap(coerceWeather(json: [
            "place": 7, "lat": "45.9", "fetchedAt": "2026-08-01T00:00:00Z",
            "daily": [["date": "2026-08-03", "tmax": 21.4, "tmin": nil], ["code": 3], nil, ["date": 20260804, "wind": "x"]],
        ]))
        XCTAssertEqual(w.place, "")
        XCTAssertEqual(w.lat, 45.9)
        XCTAssertNil(w.lon)                          // Number(undefined) is NaN → nil
        XCTAssertEqual(w.daily.count, 2)             // a day without a date is dropped
        XCTAssertEqual(w.daily[0].tmax, 21.4)
        XCTAssertEqual(w.daily[0].tmin, 0)           // Number(null) is 0 — JS does the same
        XCTAssertEqual(w.daily[1].date, "20260804")  // String(d.date)
        XCTAssertNil(w.daily[1].tmax)
        XCTAssertEqual(w.daily[1].wind, 0)           // Number('x') || 0
        XCTAssertNil(coerceWeather(json: ["daily": []]))
        XCTAssertNil(coerceWeather(json: ["daily": "x"]))
        XCTAssertNil(coerceWeather(WeatherSnapshot(place: "Nowhere")))
    }

    func testAnEventRoundTripsThroughJSONWithItsEntries() throws {
        let e = newEvent(
            id: "e1", name: "Chamonix", activities: ["l1", "l2"], weatherOn: ["cold"], startDate: "2026-08-03",
            endDate: "2026-08-10", nights: 7, laundry: true, destination: "Chamonix",
            weather: WeatherSnapshot(place: "Chamonix, FR", lat: 45.9, lon: 6.9, fetchedAt: "2026-08-01T00:00:00Z",
                                     daily: [WeatherDay(date: "2026-08-03", code: 61, tmax: 18, tmin: 7, precipProb: 80, wind: 12)]),
            geo: GeoFix(lat: 45.9, lon: 6.9, place: "Chamonix, FR"),
            entries: [newItem(id: "en1", name: "Rope", sourceListId: "l1", sourceItemId: "i1", checked: true)],
            status: "done", reviewedAt: "2026-08-12T09:00:00.000Z", createdAt: "2026-07-01T00:00:00.000Z",
            updatedAt: "2026-07-02T00:00:00.000Z")
        let back = try JSONDecoder().decode(TripEvent.self, from: JSONEncoder().encode(e))
        XCTAssertEqual(back, e)
        XCTAssertEqual(back.entries[0].checked, true)
        XCTAssertEqual(e.json["weather"]?["daily"]?[0]?["code"], 61)
    }
}
