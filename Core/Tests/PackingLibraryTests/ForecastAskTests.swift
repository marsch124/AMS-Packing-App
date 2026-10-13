import XCTest
import PackingCore
@testable import PackingLibrary

/// Which days the forecast is asked for, and what the service's "no" means (0.73).
/// His report, 12 Oct 2026: a trip about two weeks ahead said "check the connection"
/// while the internet worked — the app asked for a day past the forecast, and read the
/// service's refusal as no connection. Today is 12 Oct 2026 in every test here; the
/// service's last forecast day is then 27 Oct (today + 15, checked with the real service
/// that day: 27 Oct answered, 28 Oct was refused).
final class ForecastAskTests: XCTestCase {
    private let today = "2026-10-12"

    private func ask(_ start: String, nights: Int, today: String? = nil, utc: String? = nil) -> ForecastDays? {
        ForecastAsk.days(startDate: start, nights: nights, today: today ?? self.today, utcToday: utc ?? self.today)
    }

    // MARK: - The days asked for

    func testTheForecastReachesFifteenDaysAhead() {
        XCTAssertEqual(ForecastAsk.reachDays, 15, "the service forecasts today and 15 more days")
        XCTAssertEqual(ForecastAsk.lastDay(today: today, utcToday: today), "2026-10-27")
    }

    func testATripStartingOnTheLastForecastDayIsAskedForThatDayOnly() {
        XCTAssertEqual(ask("2026-10-27", nights: 3), ForecastDays(start: "2026-10-27", end: "2026-10-27"))
        XCTAssertTrue(ForecastAsk.inReach(startDate: "2026-10-27", nights: 3, today: today, utcToday: today),
                      "a trip starting on the last forecast day has a forecast to look up")
    }

    func testATripStartingADayPastTheReachIsNotAskedForItsDays() {
        XCTAssertNil(ask("2026-10-28", nights: 3), "28 Oct is past the forecast — the service refuses it")
        XCTAssertFalse(ForecastAsk.inReach(startDate: "2026-10-28", nights: 3, today: today, utcToday: today),
                       "nothing to look up by itself for a trip that starts past the forecast")
        XCTAssertNil(ask("2026-11-20", nights: 7), "a trip a month ahead gets the service's own days")
    }

    func testATripRunningPastTheReachIsCutAtTheLastForecastDay() {
        // His trip: two weeks ahead, a week long — the days that exist, not one more.
        XCTAssertEqual(ask("2026-10-26", nights: 7), ForecastDays(start: "2026-10-26", end: "2026-10-27"))
        XCTAssertEqual(ask(today, nights: 30), ForecastDays(start: today, end: "2026-10-27"))
        // Inside the reach it is the trip's own days, start + nights.
        XCTAssertEqual(ask("2026-10-20", nights: 3), ForecastDays(start: "2026-10-20", end: "2026-10-23"))
        XCTAssertEqual(ask("2026-10-24", nights: 3), ForecastDays(start: "2026-10-24", end: "2026-10-27"),
                       "a trip ending on the last forecast day is not cut")
        XCTAssertEqual(ask(today, nights: 0), ForecastDays(start: today, end: today), "a day trip today")
    }

    func testAfterMidnightTheReachCountsFromTheServicesDate() {
        // 00:30 in Sweden on 13 Oct is still 12 Oct in UTC — and the service's "today" is
        // the UTC date wherever the place is. Its last day is still 27 Oct.
        let late = ("2026-10-13", "2026-10-12")
        XCTAssertEqual(ForecastAsk.lastDay(today: late.0, utcToday: late.1), "2026-10-27")
        XCTAssertEqual(ask("2026-10-26", nights: 7, today: late.0, utc: late.1),
                       ForecastDays(start: "2026-10-26", end: "2026-10-27"))
        XCTAssertNil(ask("2026-10-28", nights: 1, today: late.0, utc: late.1))
        XCTAssertFalse(ForecastAsk.inReach(startDate: "2026-10-28", nights: 1, today: late.0, utcToday: late.1))
        // West of UTC in the evening the phone's date is the earlier one: counted from it.
        XCTAssertEqual(ForecastAsk.lastDay(today: "2026-10-11", utcToday: today), "2026-10-26")
    }

    func testATripUnderWayIsInReachUntilItsLastDay() {
        // Started two days ago: its own days are not asked for (the service's days are),
        // but a forecast exists, so it is looked up — until the trip is over.
        XCTAssertNil(ask("2026-10-10", nights: 2))
        XCTAssertTrue(ForecastAsk.inReach(startDate: "2026-10-10", nights: 2, today: today, utcToday: today))
        XCTAssertFalse(ForecastAsk.inReach(startDate: "2026-10-10", nights: 1, today: today, utcToday: today),
                       "the trip ended yesterday")
        XCTAssertFalse(ForecastAsk.inReach(startDate: "", nights: 2, today: today, utcToday: today), "no date, no look")
        XCTAssertNil(ask("", nights: 2))
    }

    // MARK: - A trip past the reach (0.75)

    /// Until 0.75 a trip a month ahead was asked for the service's own days — this week —
    /// and the card showed this week's weather as the trip's. Now it is not asked: the
    /// forecast comes 15 days before the trip, and the card says from when.
    func testATripPastTheReachIsNotAskedAndSaysWhenItsForecastComes() {
        func from(_ start: String, today: String? = nil, utc: String? = nil) -> String? {
            ForecastAsk.comesFrom(startDate: start, today: today ?? self.today, utcToday: utc ?? self.today)
        }
        XCTAssertEqual(from("2026-11-11"), "2026-10-27", "a trip a month ahead: its forecast comes 15 days before it")
        XCTAssertEqual(from("2026-10-28"), "2026-10-13", "a day past the reach: tomorrow")
        XCTAssertNil(from("2026-10-27"), "a trip starting on the last forecast day is asked for now")
        XCTAssertNil(from(today), "a trip starting today is asked for now")
        XCTAssertNil(from("2026-10-10"), "a trip under way is asked for now (the service's days, from today)")
        XCTAssertNil(from("2026-09-01"), "a trip long over says nothing about a forecast to come")
        XCTAssertNil(from(""), "an undated trip is asked for the service's own days: today's weather on")
        XCTAssertNil(from("soon"), "no date, no answer")
        // After midnight in Sweden the service still counts from the UTC date: 28 Oct is
        // still past its last day (27 Oct), so it is not asked for.
        XCTAssertEqual(from("2026-10-28", today: "2026-10-13", utc: "2026-10-12"), "2026-10-13")
        // The two questions never disagree: a trip is either asked for (its days, or the
        // service's) or waits for its forecast — never both, never neither.
        for start in ["2026-10-10", today, "2026-10-26", "2026-10-27", "2026-10-28", "2026-11-11", ""] {
            let waits = from(start) != nil
            XCTAssertEqual(waits, start > "2026-10-27", "\(start): waits = \(waits)")
            if waits { XCTAssertNil(ask(start, nights: 3), "\(start) waits for its forecast and is asked for days too") }
        }
    }

    // MARK: - What the service's answer means

    /// The service's own words on 12 Oct 2026, asked for one day too many.
    private let refusedDays = Data(#"{"error":true,"reason":"Parameter 'end_date' is out of allowed range from 2026-07-11 to 2026-10-27"}"#.utf8)

    func testTheServiceRefusingTheDaysSaysThereIsNoForecastYet() {
        let trouble = ForecastAsk.trouble(status: 400, body: refusedDays)
        XCTAssertEqual(trouble, .nothingYet, "the service answered: not 'check the connection'")
        XCTAssertEqual(trouble?.localizedDescription, "No forecast for those dates yet.")
        let start = Data(#"{"error":true,"reason":"Parameter 'start_date' is out of allowed range from 2026-07-11 to 2026-10-27"}"#.utf8)
        XCTAssertEqual(ForecastAsk.trouble(status: 400, body: start), .nothingYet)
    }

    func testAnyOtherNoFromTheServiceIsNotTheConnection() {
        let latitude = Data(#"{"error":true,"reason":"Latitude must be in range of -90 to 90°. Given: 95.0."}"#.utf8)
        let busy = Data(#"{"error":true,"reason":"Too many requests"}"#.utf8)
        let broken = Data("<html><body>502 Bad Gateway</body></html>".utf8)
        for (status, body) in [(400, latitude), (429, busy), (502, broken), (500, Data())] {
            let trouble = ForecastAsk.trouble(status: status, body: body)
            XCTAssertEqual(trouble, .serviceTrouble, "HTTP \(status) is an answer, not a lost connection")
            XCTAssertEqual(trouble?.localizedDescription,
                           "The weather service could not answer just now — try again later.")
        }
        XCTAssertNil(ForecastAsk.trouble(status: 200, body: Data(#"{"daily":{"time":[]}}"#.utf8)),
                     "a forecast is not trouble")
        // No answer at all is the one case that says "check the connection".
        XCTAssertEqual(ForecastTrouble.offline.localizedDescription,
                       "Could not reach the weather service — check the connection.")
        XCTAssertEqual(ForecastTrouble.noSuchPlace("Nowhere").localizedDescription, "No place found for “Nowhere”.")
    }
}
