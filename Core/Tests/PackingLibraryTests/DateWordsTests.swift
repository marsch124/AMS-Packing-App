import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// A thing's Valid until says how far away it is (their field test,
/// Oct 2026: "It didn't say 10 days. You have to calculate that yourself.").
final class DateWordsTests: XCTestCase {
    private let today = "2026-10-03"
    private func says(_ ymd: String) -> String { distanceWords(from: today, to: ymd) }

    func testTodayTomorrowAndDays() {
        XCTAssertEqual(says("2026-10-03"), "today")
        XCTAssertEqual(says("2026-10-04"), "tomorrow", "one day")
        XCTAssertEqual(says("2026-10-05"), "in 2 days")
        XCTAssertEqual(says("2026-10-13"), "in 10 days", "his sun cream, ten days on")
        XCTAssertEqual(says("2026-10-16"), "in 13 days", "13 days is still days")
    }

    func testWeeksFromTwoWeeksOn() {
        XCTAssertEqual(says("2026-10-17"), "in 2 weeks", "14 days")
        XCTAssertEqual(says("2026-10-23"), "in 2 weeks", "20 days: whole weeks, never rounded up")
        XCTAssertEqual(says("2026-10-24"), "in 3 weeks")
        XCTAssertEqual(says("2026-11-02"), "in 4 weeks", "30 days, a day short of a month")
        XCTAssertEqual(says("2026-11-03"), "in 1 month", "a month on, to the day")
        XCTAssertEqual(says("2026-11-06"), "in 1 month", "34 days")
        XCTAssertEqual(says("2026-11-07"), "in 5 weeks", "35 days")
        XCTAssertEqual(says("2026-11-28"), "in 8 weeks", "8 weeks")
        XCTAssertEqual(says("2026-12-02"), "in 8 weeks", "a day short of two months")
    }

    func testMonthsThenYears() {
        XCTAssertEqual(says("2026-12-03"), "in 2 months")
        XCTAssertEqual(says("2027-04-02"), "in 5 months", "a day short of six months is not six — the passport's rule")
        XCTAssertEqual(says("2027-04-03"), "in 6 months")
        XCTAssertEqual(says("2027-09-03"), "in 11 months")
        XCTAssertEqual(says("2027-10-02"), "in 11 months", "a day short of a year")
        XCTAssertEqual(says("2027-10-03"), "in 1 year")
        XCTAssertEqual(says("2028-10-02"), "in 1 year", "a day short of two years")
        XCTAssertEqual(says("2031-10-03"), "in 5 years")
        XCTAssertEqual(says("2036-10-03"), "in 10 years")
    }

    func testThePastIsOutOfDate() {
        XCTAssertEqual(says("2026-10-02"), "yesterday (out of date)")
        XCTAssertEqual(says("2026-09-30"), "3 days ago (out of date)")
        XCTAssertEqual(says("2026-09-12"), "3 weeks ago (out of date)")
        XCTAssertEqual(says("2026-09-03"), "1 month ago (out of date)")
        XCTAssertEqual(says("2026-04-03"), "6 months ago (out of date)")
        XCTAssertEqual(says("2024-10-03"), "2 years ago (out of date)")
    }

    func testNotADateSaysNothing() {
        XCTAssertEqual(says(""), "")
        XCTAssertEqual(says("2026-10"), "")
        XCTAssertEqual(distanceWords(from: "", to: "2026-10-03"), "")
    }

    /// A month on from a day the next month lacks is that month's last day.
    func testAMonthOnKeepsInsideTheMonth() {
        XCTAssertEqual(addMonths("2026-10-03", 1), "2026-11-03")
        XCTAssertEqual(addMonths("2027-01-31", 1), "2027-02-28")
        XCTAssertEqual(addMonths("2028-01-31", 1), "2028-02-29", "a leap year")
        XCTAssertEqual(addMonths("2028-02-29", 12), "2029-02-28")
        XCTAssertEqual(addMonths("2026-08-31", 6), "2027-02-28")
        XCTAssertEqual(addMonths("2026-12-15", 1), "2027-01-15", "into the next year")
        XCTAssertEqual(addMonths("2026-10-03", 120), "2036-10-03")
        XCTAssertEqual(addMonths("not a date", 1), "")
    }

    /// The quick choices (+1 month, +6 months, +1 year, +5 years, +10 years) read
    /// back as themselves, from every day of two years — month ends and 29 February too.
    func testEveryQuickChoiceReadsBackAsItself() {
        let choices: [(Int, String)] = [(1, "in 1 month"), (6, "in 6 months"), (12, "in 1 year"),
                                        (60, "in 5 years"), (120, "in 10 years")]
        var day = "2027-01-01"
        while day < "2029-01-01" {
            for (months, words) in choices {
                XCTAssertEqual(distanceWords(from: day, to: addMonths(day, months)), words, "+\(months) months from \(day)")
            }
            day = addDays(day, 1)
        }
    }
}
