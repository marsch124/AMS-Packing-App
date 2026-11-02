import XCTest
import PackingCore
@testable import PackingLibrary

/// Home's "On your trip" card (0.108) — his words, 2 Nov 2026, on a trip: "I am currently on a
/// trip, but I can't see it on the home page." Invented data only — this repository is public.
///
/// The trip is `BatteriesTests.library()`'s "Weekend in the hills" moved to Sunday 1 – Saturday 7
/// Nov 2026: seven days, the base template and Hiking; the Toothbrush, the Power bank and the
/// Headlamp on its To charge.
final class OnTripHomeTests: XCTestCase {
    override func setUp() { PackingEnv.freeze(at: "2026-11-02T09:00:00.000Z") }
    override func tearDown() { PackingEnv.reset() }

    private func library(start: String = "2026-11-01", end: String = "2026-11-07") -> (Library, String) {
        var lib = BatteriesTests.library()
        var t = newEvent(name: "Weekend in the hills", startDate: start, endDate: end)
        t.activities = lib.templates.filter { $0.name == "Hiking" }.map(\.id)
        let id = lib.createTrip(t).id
        return (lib, id)
    }

    private func index(_ lib: Library, _ id: String) -> Int { lib.trips.firstIndex { $0.id == id }! }

    // MARK: Which moment, by the dates

    func testTheMomentFollowsTheDates() {
        let (lib, id) = library()
        XCTAssertNil(lib.onTripCard(today: "2026-10-31"), "a trip still to leave is the countdown's")
        XCTAssertNotNil(lib.nextTrip(today: "2026-10-31"), "the countdown is as it was for a trip ahead")
        for day in ["2026-11-01", "2026-11-02", "2026-11-05"] {
            XCTAssertEqual(lib.onTripCard(today: day)?.moment, .underWay, "\(day) is not under way")
            XCTAssertEqual(lib.onTripCard(today: day)?.id, id)
        }
        // The day before the last day and the last day itself: going home.
        XCTAssertEqual(lib.onTripCard(today: "2026-11-06")?.moment, .goingHome)
        XCTAssertEqual(lib.onTripCard(today: "2026-11-06")?.title, "Going home tomorrow")
        XCTAssertEqual(lib.onTripCard(today: "2026-11-07")?.moment, .goingHome)
        XCTAssertEqual(lib.onTripCard(today: "2026-11-07")?.title, "Going home today")
        // From the day after: back home — not reviewed, and it has lines.
        XCTAssertEqual(lib.onTripCard(today: "2026-11-08")?.moment, .backHome)
        XCTAssertEqual(lib.onTripCard(today: "2026-11-08")?.title, "Welcome home")
        XCTAssertEqual(lib.onTripCard(today: "2026-11-21")?.moment, .backHome, "two weeks after its last day, still welcomed")
        XCTAssertNil(lib.onTripCard(today: "2026-11-22"), "a trip back more than two weeks is no Welcome home")
        XCTAssertNil(lib.onTripCard(today: "not a day"))
    }

    func testTheFirstDayWaitsForTheTimeHeLeaves() {
        var (lib, id) = library()
        XCTAssertTrue(Library.setLeaveTime(&lib.trips[index(lib, id)], "08:00", home: false))
        XCTAssertNil(lib.onTripCard(today: "2026-11-01", time: "07:59"), "on the trip before he has left")
        XCTAssertEqual(lib.nextTrip(today: "2026-11-01", time: "07:59")?.days, 0, "before he leaves, the countdown says Today")
        XCTAssertEqual(lib.onTripCard(today: "2026-11-01", time: "08:00")?.moment, .underWay, "the minute he leaves counts")
        XCTAssertEqual(lib.onTripCard(today: "2026-11-01")?.moment, .underWay, "no time given: the day has set off")
    }

    func testAReviewedOrUndatedTripIsNeverOnTheCard() {
        var (lib, id) = library()
        lib.trips[index(lib, id)].reviewedAt = "2026-11-08T10:00:00.000Z"
        XCTAssertNil(lib.onTripCard(today: "2026-11-03"), "reviewed under way")
        XCTAssertNil(lib.onTripCard(today: "2026-11-08"), "reviewed: Home goes back to the next countdown")
        lib.trips[index(lib, id)].reviewedAt = ""
        lib.trips[index(lib, id)].status = "done"
        XCTAssertNil(lib.onTripCard(today: "2026-11-08"), "marked done is reviewed too")
        lib.trips[index(lib, id)].status = ""
        XCTAssertEqual(lib.onTripCard(today: "2026-11-08")?.moment, .backHome)
        lib.trips[index(lib, id)].startDate = ""
        lib.trips[index(lib, id)].endDate = ""
        XCTAssertNil(lib.onTripCard(today: "2026-11-03"), "a trip without dates is never under way")
        // An empty trip back home has nothing to review.
        var (empty, eid) = library()
        empty.trips[index(empty, eid)].entries = []
        XCTAssertNil(empty.onTripCard(today: "2026-11-08"))
        XCTAssertEqual(empty.onTripCard(today: "2026-11-03")?.moment, .underWay, "under way it is on Home, lines or none")
    }

    func testADayTripAndATwoDayTripGoHomeFromTheStart() {
        let (day, _) = library(start: "2026-11-03", end: "")
        XCTAssertEqual(day.onTripCard(today: "2026-11-03")?.moment, .goingHome, "a day trip: home today")
        XCTAssertEqual(day.onTripCard(today: "2026-11-03")?.dayLine, "Day 1 of 1")
        XCTAssertEqual(day.onTripCard(today: "2026-11-04")?.moment, .backHome)
        XCTAssertEqual(day.onTripCard(today: "2026-11-04")?.dayLine, "1 day")
        let (two, _) = library(start: "2026-11-03", end: "2026-11-04")
        XCTAssertEqual(two.onTripCard(today: "2026-11-03")?.title, "Going home tomorrow")
        XCTAssertEqual(two.onTripCard(today: "2026-11-03")?.dayLine, "Day 1 of 2")
    }

    func testOfTwoTripsAwayTheOneSetOffLastAndAwayBeatsBackHome() {
        var (lib, first) = library(start: "2026-10-20", end: "2026-10-30")
        var t = newEvent(name: "City break", startDate: "2026-11-01", endDate: "2026-11-05")
        t.activities = lib.templates.filter { $0.name == "Hiking" }.map(\.id)
        let second = lib.createTrip(t).id
        XCTAssertEqual(lib.onTripCard(today: "2026-11-02")?.id, second, "the trip under way, not the one back home")
        XCTAssertEqual(lib.onTripCard(today: "2026-11-06")?.id, second, "both back: the one back most recently")
        XCTAssertEqual(lib.onTripCard(today: "2026-11-06")?.moment, .backHome)
        // Two at once: the one that set off last.
        lib.trips[index(lib, first)].endDate = "2026-11-10"
        XCTAssertEqual(lib.onTripCard(today: "2026-11-02")?.id, second)
        lib.trips[index(lib, second)].reviewedAt = "2026-11-02T08:00:00.000Z"
        XCTAssertEqual(lib.onTripCard(today: "2026-11-02")?.id, first)
    }

    // MARK: What the card says

    func testUnderWayItSaysTheDayAndWhenPackToGoHomeOpens() {
        let (lib, id) = library()
        let card = lib.onTripCard(today: "2026-11-03")!
        XCTAssertEqual(card.name, "Weekend in the hills")
        XCTAssertEqual(card.day, 3)
        XCTAssertEqual(card.days, 7)
        XCTAssertEqual(card.title, "On your trip")
        XCTAssertEqual(card.dayLine, "Day 3 of 7 \u{00B7} home on Saturday", "7 Nov 2026 is a Saturday")
        XCTAssertEqual(card.packHomeOpens, "2026-11-06")
        XCTAssertEqual(card.packHomeLine, "Opens on Friday")
        XCTAssertEqual(card.segments, [true, true, true, false, false, false, false])
        XCTAssertEqual(lib.onTripCard(today: "2026-11-05")?.packHomeLine, "Opens tomorrow")
        XCTAssertEqual(lib.onTripCard(today: "2026-11-05")?.dayLine, "Day 5 of 7 \u{00B7} home on Saturday")
        XCTAssertTrue(card.charge.isEmpty, "Charge tonight is the way home's")
        XCTAssertEqual(card.id, id)
        // A long trip: its last day a date, and one bar instead of a segment a day.
        let (long, _) = library(start: "2026-11-01", end: "2026-11-30")
        XCTAssertEqual(long.onTripCard(today: "2026-11-02")?.dayLine, "Day 2 of 30 \u{00B7} home on 30 Nov")
        XCTAssertEqual(long.onTripCard(today: "2026-11-02")?.packHomeLine, "Opens on 29 Nov")
        XCTAssertNil(long.onTripCard(today: "2026-11-02")?.segments)
    }

    func testToDoTodayIsWhatIsDue() {
        var (lib, id) = library()
        XCTAssertEqual(lib.onTripCard(today: "2026-11-03")?.due, [])
        XCTAssertNotNil(lib.addTripTodo(tripId: id, name: "Book the taxi", today: "2026-11-03"))
        XCTAssertNotNil(lib.addTripTodo(tripId: id, name: "Charge the watch", today: "2026-11-03"))
        XCTAssertEqual(lib.onTripCard(today: "2026-11-03")?.due, ["Book the taxi", "Charge the watch"])
        let taxi = lib.trips[index(lib, id)].entries.first { $0.name == "Book the taxi" }!
        XCTAssertTrue(lib.setChecked(true, tripId: id, entryId: taxi.id))
        XCTAssertEqual(lib.onTripCard(today: "2026-11-03")?.due, ["Charge the watch"], "a ticked one is done")
        XCTAssertEqual(lib.onTripCard(today: "2026-11-08")?.due, [], "back home nothing is to do today")
    }

    func testGoingHomeCountsWhatIsStillToPackAndToCharge() {
        var (lib, id) = library()
        // What went: every line ticked on the way out but the Map.
        for line in lib.trips[index(lib, id)].entries where line.name != "Map" {
            XCTAssertTrue(lib.setChecked(true, tripId: id, entryId: line.id))
        }
        let went = lib.trips[index(lib, id)].entries.filter(\.checked).count
        var card = lib.onTripCard(today: "2026-11-06")!
        XCTAssertEqual(card.homeTotal, went)
        XCTAssertEqual(card.packHomeLine, "\(went) of \(went) still to pack")
        let first = lib.homeLines(tripId: id)[0]
        XCTAssertTrue(lib.setPackedHome(true, tripId: id, entryId: first.id))
        card = lib.onTripCard(today: "2026-11-06")!
        XCTAssertEqual(card.homeLeft, went - 1)
        XCTAssertEqual(card.packHomeLine, "\(went - 1) of \(went) still to pack")
        _ = lib.setAllPackedHome(true, tripId: id)
        XCTAssertEqual(lib.onTripCard(today: "2026-11-06")?.packHomeLine, "All \(went) packed")
        // Charge tonight: the To charge card's things not charged yet, in its order.
        XCTAssertEqual(card.charge, ["Toothbrush", "Power bank", "Headlamp"])
        let bank = lib.toCharge(tripId: id).first { $0.name == "Power bank" }!
        XCTAssertTrue(lib.setCharged(true, tripId: id, lineId: bank.lineId, contentId: bank.contentId))
        XCTAssertEqual(lib.onTripCard(today: "2026-11-06")?.charge, ["Toothbrush", "Headlamp"])
        for row in lib.toCharge(tripId: id) { _ = lib.setCharged(true, tripId: id, lineId: row.lineId, contentId: row.contentId) }
        XCTAssertEqual(lib.onTripCard(today: "2026-11-06")?.charge, [], "all charged: no Charge tonight")
        // Nothing went yet: nothing to bring home.
        let (none, _) = library()
        XCTAssertEqual(none.onTripCard(today: "2026-11-06")?.packHomeLine, "Nothing to bring home yet")
    }

    func testTheLeaveTimeForHomeIsSaidAndTurnsOnTheLastDay() {
        var (lib, id) = library()
        XCTAssertEqual(lib.onTripCard(today: "2026-11-06")?.dayLine, "Day 6 of 7", "no time set: none said")
        XCTAssertTrue(Library.setLeaveTime(&lib.trips[index(lib, id)], "10:00", home: true))
        XCTAssertEqual(lib.onTripCard(today: "2026-11-06", time: "18:00")?.dayLine, "Day 6 of 7 \u{00B7} you leave at 10:00")
        XCTAssertEqual(lib.onTripCard(today: "2026-11-07", time: "09:59")?.dayLine, "Day 7 of 7 \u{00B7} you leave at 10:00")
        XCTAssertEqual(lib.onTripCard(today: "2026-11-07", time: "10:00")?.dayLine, "Day 7 of 7 \u{00B7} you left at 10:00")
        XCTAssertEqual(lib.onTripCard(today: "2026-11-07", time: "10:00")?.moment, .goingHome, "the last day stays going home")
        XCTAssertEqual(lib.onTripCard(today: "2026-11-07", time: "10:00")?.hasLeft, true)
        XCTAssertEqual(lib.onTripCard(today: "2026-11-06", time: "23:00")?.hasLeft, false, "the day before, never left")
        XCTAssertEqual(lib.onTripCard(today: "2026-11-08", time: "00:00")?.moment, .backHome)
        // The way OUT's time is not the way home's.
        XCTAssertTrue(Library.setLeaveTime(&lib.trips[index(lib, id)], "", home: true))
        XCTAssertTrue(Library.setLeaveTime(&lib.trips[index(lib, id)], "07:00", home: false))
        XCTAssertEqual(lib.onTripCard(today: "2026-11-07", time: "12:00")?.dayLine, "Day 7 of 7")
    }

    func testBackHomeSaysHowLongAndHowMuchWent() {
        var (lib, id) = library()
        let things = lib.trips[index(lib, id)].entries.filter { !Library.isReminder($0) }
        for line in things.prefix(4) { XCTAssertTrue(lib.setChecked(true, tripId: id, entryId: line.id)) }
        // A line set aside did not go, ticked or not.
        XCTAssertTrue(lib.setAside(true, tripId: id, entryId: things[0].id))
        let card = lib.onTripCard(today: "2026-11-09")!
        XCTAssertEqual(card.moment, .backHome)
        XCTAssertEqual(card.went, 3)
        XCTAssertEqual(card.dayLine, "7 days \u{00B7} 3 things went along")
        XCTAssertNil(card.segments)
        XCTAssertNil(card.weather, "back home, no weather from away")
        XCTAssertTrue(lib.setChecked(false, tripId: id, entryId: things[1].id))
        XCTAssertTrue(lib.setChecked(false, tripId: id, entryId: things[2].id))
        XCTAssertEqual(lib.onTripCard(today: "2026-11-09")?.dayLine, "7 days \u{00B7} 1 thing went along")
        XCTAssertTrue(lib.setChecked(false, tripId: id, entryId: things[3].id))
        XCTAssertEqual(lib.onTripCard(today: "2026-11-09")?.dayLine, "7 days", "nothing ticked: how long alone")
    }

    func testTodaysWeatherComesFromTheForecastTheTripHolds() {
        var (lib, id) = library()
        XCTAssertNil(lib.onTripCard(today: "2026-11-03")?.weather, "no forecast: no weather")
        let days = [WeatherDay(date: "2026-11-02", code: 61, tmax: 12, tmin: 4),
                    WeatherDay(date: "2026-11-03", code: 2, tmax: 22.6, tmin: 15)]
        XCTAssertTrue(lib.setWeather(tripId: id, place: "", lat: nil, lon: nil,
                                     snapshot: WeatherSnapshot(place: "Testville, SE", daily: days)))
        let card = lib.onTripCard(today: "2026-11-03")!
        XCTAssertEqual(card.weather?.icon, "sun-cloud")
        XCTAssertEqual(card.weather?.label, "Partly cloudy")
        XCTAssertEqual(card.weather?.high, 23)
        XCTAssertEqual(card.weather?.says, "23\u{00B0}")
        XCTAssertEqual(card.place, "Testville", "the forecast's place without its country")
        XCTAssertNil(lib.onTripCard(today: "2026-11-04")?.weather, "a forecast without today says nothing")
        lib.trips[index(lib, id)].destination = "Torremolinos"
        XCTAssertEqual(lib.onTripCard(today: "2026-11-03")?.place, "Torremolinos", "his own word for the place first")
    }

    // MARK: Words and drawings

    func testADayIsSaidAsTheCardSaysIt() {
        XCTAssertEqual(Library.weekdayName("2026-11-01"), "Sunday")
        XCTAssertEqual(Library.weekdayName("2026-11-07"), "Saturday")
        XCTAssertEqual(Library.weekdayName("1970-01-01"), "Thursday")
        XCTAssertEqual(Library.weekdayName("2024-02-29"), "Thursday")
        XCTAssertEqual(Library.weekdayName("nope"), "")
        XCTAssertEqual(Library.onDay("2026-11-02", from: "2026-11-02"), "today")
        XCTAssertEqual(Library.onDay("2026-11-03", from: "2026-11-02"), "tomorrow")
        XCTAssertEqual(Library.onDay("2026-11-08", from: "2026-11-02"), "on Sunday")
        XCTAssertEqual(Library.onDay("2026-11-09", from: "2026-11-02"), "on 9 Nov")
        XCTAssertEqual(Library.onDay("2027-01-01", from: "2026-12-28"), "on Friday", "across the year")
    }

    func testEveryForecastIconHasADrawingInTheAppsHand() {
        let keys = Set([0, 1, 3, 45, 51, 61, 71, 80, 85, 95, 999].map { weatherCode(Double($0)).icon })
        XCTAssertEqual(keys, Set(WeatherMark.all.map(\.key)), "a forecast icon without a drawing, or a drawing for none")
        let allowed = Set("MLHVCSQAZmlhvcsqaz")
        for mark in WeatherMark.all {
            XCTAssertFalse(mark.path.isEmpty, "\(mark.key) has no drawing")
            let letters = mark.path.filter(\.isLetter)
            XCTAssertTrue(letters.allSatisfy(allowed.contains), "\(mark.key) uses a command the app does not draw: \(letters)")
            XCTAssertEqual(WeatherMark.path(mark.key), mark.path)
        }
        XCTAssertEqual(WeatherMark.path("hail"), WeatherMark.path("cloud"), "an unknown sky is a cloud")
    }
}
