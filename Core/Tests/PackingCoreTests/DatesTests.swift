import XCTest
@testable import PackingCore

// Ported from tests/model.test.mjs — daysUntil, countdownLabel, nightsBetween,
// endFromNights and the calendar behind the trip date picker.
final class DatesTests: XCTestCase {
    override func tearDown() { PackingEnv.reset(); super.tearDown() }

    // JS: 'daysUntil / countdownLabel'
    func testDaysUntilAndCountdownLabel() {
        XCTAssertEqual(daysUntil("2026-08-10", "2026-08-03"), 7)
        XCTAssertEqual(daysUntil("2026-08-03", "2026-08-03"), 0)
        XCTAssertEqual(daysUntil("2026-08-01", "2026-08-03"), -2)
        XCTAssertNil(daysUntil("", "2026-08-03"))
        XCTAssertEqual(countdownLabel(7), "in 7 days")
        XCTAssertEqual(countdownLabel(0), "Today")
        XCTAssertEqual(countdownLabel(1), "Tomorrow")
        XCTAssertEqual(countdownLabel(-2), "2 days ago")
    }

    // JS: 'nightsBetween / endFromNights'
    func testNightsBetweenAndEndFromNights() {
        XCTAssertEqual(nightsBetween("2026-08-02", "2026-08-09"), 7)
        XCTAssertEqual(nightsBetween("2026-08-02", "2026-08-02"), 0)    // day trip
        XCTAssertNil(nightsBetween("2026-08-09", "2026-08-02"))         // end before start
        XCTAssertNil(nightsBetween("", "2026-08-09"))
        XCTAssertNil(nightsBetween("2026-08-02", ""))
        // Round-trips with endFromNights
        XCTAssertEqual(endFromNights("2026-08-02", 7), "2026-08-09")
        XCTAssertEqual(endFromNights("2026-08-02", 0), "2026-08-02")
        XCTAssertEqual(endFromNights("", 7), "")
        XCTAssertEqual(nightsBetween("2026-08-02", endFromNights("2026-08-02", 5)), 5)
    }

    // ---------- v125: the trip date picker's calendar ----------

    // JS: 'monthKey: a real date gives its month, anything else gives nothing'
    func testMonthKeyARealDateGivesItsMonthAnythingElseGivesNothing() {
        XCTAssertEqual(monthKey("2026-09-12"), "2026-09")
        XCTAssertEqual(monthKey("2026-09-12T10:00:00Z"), "2026-09")
        XCTAssertEqual(monthKey(""), "")
        XCTAssertEqual(monthKey("not a date"), "")
        XCTAssertEqual(monthKey("2026-13-01"), "")   // month 13 is not a month
    }

    // JS: 'shiftMonth: steps months and rolls the year over both ways'
    func testShiftMonthStepsMonthsAndRollsTheYearOverBothWays() {
        XCTAssertEqual(shiftMonth("2026-09", 1), "2026-10")
        XCTAssertEqual(shiftMonth("2026-12", 1), "2027-01")
        XCTAssertEqual(shiftMonth("2026-01", -1), "2025-12")
        XCTAssertEqual(shiftMonth("2026-06", 0), "2026-06")
        XCTAssertEqual(shiftMonth("2026-01", -13), "2024-12")
        XCTAssertEqual(shiftMonth("nonsense", 1), "")
    }

    // JS: 'monthGrid: always 42 cells, starting on the chosen weekday, in UTC'
    func testMonthGridAlways42CellsStartingOnTheChosenWeekdayInUTC() {
        // 1 Sept 2026 is a Tuesday, so a Monday-first grid leads with 31 August.
        let g = monthGrid("2026-09", 1)
        XCTAssertEqual(g.days.count, 42)
        XCTAssertEqual(g.days[0].iso, "2026-08-31")
        XCTAssertEqual(g.days[0].inMonth, false)
        XCTAssertEqual(g.days[1].iso, "2026-09-01")
        XCTAssertEqual(g.days[1].inMonth, true)
        XCTAssertEqual(g.days.filter { $0.inMonth }.count, 30)
        // Sunday-first shifts the whole grid one day earlier.
        XCTAssertEqual(monthGrid("2026-09", 0).days[0].iso, "2026-08-30")
        // Every cell is exactly one day after the last — no gaps, no repeats, and no
        // daylight-saving hiccup, which is the whole reason this is UTC arithmetic.
        // (JS subtracts two Date.parse results and expects 86400000; one whole day is the same claim.)
        for i in 1..<g.days.count {
            XCTAssertEqual(daysUntil(g.days[i].iso, g.days[i - 1].iso), 1, "\(g.days[i - 1].iso) -> \(g.days[i].iso)")
        }
        XCTAssertEqual(monthGrid("rubbish").days, [])
    }

    // JS: 'monthGrid: a month starting exactly on the week start needs no lead-in'
    func testMonthGridAMonthStartingExactlyOnTheWeekStartNeedsNoLeadIn() {
        // 1 June 2026 is a Monday.
        XCTAssertEqual(monthGrid("2026-06", 1).days[0].iso, "2026-06-01")
        // February in a leap year still fills 42 cells.
        XCTAssertEqual(monthGrid("2028-02", 1).days.filter { $0.inMonth }.count, 29)
    }

    // JS: 'rangeCellState: paints the two ends, the days between, and nothing else'
    func testRangeCellStatePaintsTheTwoEndsTheDaysBetweenAndNothingElse() {
        XCTAssertEqual(rangeCellState("2026-09-12", "2026-09-12", "2026-09-19"), "start")
        XCTAssertEqual(rangeCellState("2026-09-19", "2026-09-12", "2026-09-19"), "end")
        XCTAssertEqual(rangeCellState("2026-09-15", "2026-09-12", "2026-09-19"), "between")
        XCTAssertEqual(rangeCellState("2026-09-20", "2026-09-12", "2026-09-19"), "")
        XCTAssertEqual(rangeCellState("2026-09-11", "2026-09-12", "2026-09-19"), "")
        // A start with no end yet, and a same-day trip, are both a single round cell —
        // 'start' would draw a flat right edge leading into a range that isn't there.
        XCTAssertEqual(rangeCellState("2026-09-12", "2026-09-12", ""), "only")
        XCTAssertEqual(rangeCellState("2026-09-12", "2026-09-12", "2026-09-12"), "only")
        XCTAssertEqual(rangeCellState("2026-09-13", "2026-09-12", ""), "")
        XCTAssertEqual(rangeCellState("2026-09-12", "", ""), "")
    }

    // JS: 'orderRange: two taps become a trip, whichever order they came in'
    func testOrderRangeTwoTapsBecomeATripWhicheverOrderTheyCameIn() {
        XCTAssertEqual(orderRange("2026-09-12", "2026-09-19"), ["2026-09-12", "2026-09-19"])
        // Tapping an earlier day second is a correction, not an error.
        XCTAssertEqual(orderRange("2026-09-19", "2026-09-12"), ["2026-09-12", "2026-09-19"])
        XCTAssertEqual(orderRange("2026-09-12", "2026-09-12"), ["2026-09-12", "2026-09-12"])
        XCTAssertEqual(orderRange("2026-09-12", ""), ["2026-09-12", ""])
        XCTAssertEqual(orderRange("", "2026-09-12"), ["2026-09-12", ""])
        XCTAssertEqual(orderRange("", ""), ["", ""])
    }

    // JS: 'the picker and nightsBetween agree on what a range means'
    func testThePickerAndNightsBetweenAgreeOnWhatARangeMeans() {
        let r = orderRange("2026-09-19", "2026-09-12")
        XCTAssertEqual(nightsBetween(r[0], r[1]), 7)
        let same = orderRange("2026-09-12", "2026-09-12")
        XCTAssertEqual(nightsBetween(same[0], same[1]), 0)
    }

    // MARK: - Not in the JS suite — every expected value below was READ OFF the web
    // app's own model.js running in Node, so the odd ones are pinned as they really are.

    func testDaysUntilReadsDatesTheWayDateParseDoes() {
        // 🪤 JS does not check the day against the month: 30 February is 2 March.
        XCTAssertEqual(daysUntil("2026-02-30", "2026-02-28"), 2)
        // The shorter ISO forms are dates too (the 1st).
        XCTAssertEqual(daysUntil("2026-08", "2026-07-31"), 1)
        XCTAssertEqual(daysUntil("2026", "2025-12-31"), 1)
        // Anything else is not a date.
        XCTAssertNil(daysUntil("2026-8-3", "2026-08-01"))
        XCTAssertNil(daysUntil("2026-08-10", "rubbish"))
        XCTAssertNil(daysUntil("2026-00-10", "2026-08-01"))
        XCTAssertNil(daysUntil("2026-08-32", "2026-08-01"))
        XCTAssertNil(daysUntil(nil, "2026-08-01"))
        // Only the first ten characters count — the time and its offset are cut off, not converted.
        XCTAssertEqual(daysUntil("2026-08-10T23:30:00+02:00", "2026-08-03T22:00:00Z"), 7)
    }

    func testDaysUntilWithoutATodayUsesTheUTCDateOfTheClock() {
        // 00:30 on 4 August in Sweden (UTC+2) is still 3 August in UTC — and UTC is what counts.
        PackingEnv.freeze(at: "2026-08-03T22:30:00.000Z")
        XCTAssertEqual(daysUntil("2026-08-10"), 7)
        XCTAssertEqual(daysUntil("2026-08-10", ""), 7)
    }

    func testNightsAcrossMonthLeapAndYearEnds() {
        XCTAssertEqual(nightsBetween("2026-02-28", "2026-03-01"), 1)
        XCTAssertEqual(nightsBetween("2028-02-28", "2028-03-01"), 2)   // leap year
        XCTAssertEqual(nightsBetween("2026-12-30", "2027-01-02"), 3)
        XCTAssertEqual(endFromNights("2026-12-30", 3), "2027-01-02")
        XCTAssertEqual(endFromNights("2026-08-02", 2.9), "2026-08-04")   // Math.floor
        XCTAssertEqual(endFromNights("2026-08-02", -3), "2026-08-02")
        XCTAssertEqual(endFromNights("2026-08-02", Double.nan), "2026-08-02")
        XCTAssertEqual(endFromNights("rubbish", 3), "")
        XCTAssertEqual(endFromNights("2026-02-30", 0), "2026-03-02")
        XCTAssertEqual(endFromNights("9999-12-31", 1), "+010000-01")     // toISOString's six-digit year, cut at 10
    }

    func testMonthKeyAndShiftMonthOddInputs() {
        XCTAssertEqual(monthKey("2026-02-30"), "2026-02")   // a date to JS, so a month
        XCTAssertEqual(monthKey("2026-00-10"), "")
        XCTAssertEqual(monthKey("2026-9-12"), "")
        XCTAssertEqual(monthKey(nil), "")
        XCTAssertEqual(shiftMonth("2026-09"), "2026-09")
        XCTAssertEqual(shiftMonth("2026-13", 0), "2027-01")   // the month is not range-checked
        XCTAssertEqual(shiftMonth("2026-00", 0), "2025-12")
        XCTAssertEqual(shiftMonth("2026-09-12", 1), "")
        XCTAssertEqual(shiftMonth("0000-01", -1), "00-1-12")  // String(-1).padStart(4, '0')
        XCTAssertEqual(shiftMonth("9999-12", 1), "10000-01")
    }

    func testMonthGridOddKeys() {
        // Date.UTC reads a year 0–99 as 1900 + year.
        let old = monthGrid("0050-03")
        XCTAssertEqual([old.key, String(old.year), String(old.month)], ["0050-03", "50", "2"])
        XCTAssertEqual(old.days.first, MonthGridDay(iso: "1950-02-27", inMonth: false))
        XCTAssertEqual(old.days.last, MonthGridDay(iso: "1950-04-09", inMonth: false))
        XCTAssertEqual(old.days.filter { $0.inMonth }.count, 31)
        // A month outside 01–12 rolls into the next / previous year, and no cell is "in" it.
        let thirteen = monthGrid("2026-13")
        XCTAssertEqual(thirteen.month, 12)
        XCTAssertEqual(thirteen.days.first?.iso, "2026-12-28")
        XCTAssertEqual(thirteen.days.filter { $0.inMonth }.count, 0)
        let zero = monthGrid("2026-00")
        XCTAssertEqual(zero.month, -1)
        XCTAssertEqual(zero.days.first?.iso, "2025-12-01")
        XCTAssertEqual(zero.days.filter { $0.inMonth }.count, 0)
        // Any weekStart but 0 is Monday.
        XCTAssertEqual(monthGrid("2026-02", 7).days.first?.iso, "2026-01-26")
        XCTAssertEqual(monthGrid("2026-02", 7).days.last?.iso, "2026-03-08")
        XCTAssertEqual(monthGrid("2026-11", 0).days.first, MonthGridDay(iso: "2026-11-01", inMonth: true))
        XCTAssertEqual(monthGrid("2026-11", 0).days.last?.iso, "2026-12-12")
    }

    func testRangeHelpersCutLongDatesAndTakeNil() {
        XCTAssertEqual(rangeCellState("2026-09-15T10:00", "2026-09-12T08:00", "2026-09-19"), "between")
        XCTAssertEqual(orderRange("2026-09-19T10:00", nil), ["2026-09-19", ""])
        XCTAssertEqual(countdownLabel(-1), "Yesterday")
        XCTAssertEqual(countdownLabel(nil), "")
        XCTAssertEqual(countdownLabel(2), "in 2 days")
    }

    func testTheDeviceTimeZoneCannotMoveADay() {
        // Nothing in Dates.swift reads a Calendar or a TimeZone; this makes sure it stays that way.
        let saved = NSTimeZone.default
        defer { NSTimeZone.default = saved }
        for zone in ["Pacific/Kiritimati", "Pacific/Pago_Pago", "Europe/Stockholm"] {
            NSTimeZone.default = TimeZone(identifier: zone) ?? saved
            XCTAssertEqual(monthGrid("2026-03", 1).days[0].iso, "2026-02-23", zone)
            XCTAssertEqual(monthGrid("2026-10", 1).days.filter { $0.inMonth }.count, 31, zone)   // across the DST change
            XCTAssertEqual(nightsBetween("2026-03-28", "2026-03-30"), 2, zone)
            XCTAssertEqual(endFromNights("2026-10-24", 2), "2026-10-26", zone)
            XCTAssertEqual(daysUntil("2026-03-30", "2026-03-28T23:59:59.999Z"), 2, zone)
        }
    }
}
