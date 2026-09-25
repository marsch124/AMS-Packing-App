import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// The maintenance calendar's arithmetic: which day things land on, which way up
/// the month sits, and what colour a day takes.
final class CareCalendarTests: XCTestCase {
    private func library() -> Library {
        var lib = Library()
        var l = newList(name: "Kit", group: "GA")
        func thing(_ name: String, every days: Int, last: String) -> Item {
            var it = newItem(name: name)
            it.maintenance = Maintenance(notes: "", intervalDays: days, lastDone: last)
            return it
        }
        l.items = [thing("Boots", every: 30, last: "2026-08-20"),      // due 2026-09-19 → overdue on the 25th
                   thing("Wetsuit", every: 30, last: "2026-08-28"),    // due 2026-09-27 → soon
                   thing("Bike", every: 90, last: "2026-07-01"),       // due 2026-09-29 → soon/ok
                   newItem(name: "Towel")]                             // no care at all
        // Care NOTES but no schedule — on the Care list as "reference only". It has
        // no due date, so the calendar has no day to put it on. (A plant removing
        // the calendar's own schedule check cannot fail this: the model gives such
        // a thing no date to land on. The case is here so it is exercised.)
        var notes = newItem(name: "Rain jacket")
        notes.maintenance = Maintenance(notes: "Wash cold, no softener")
        l.items.append(notes)
        lib.saveTemplate(l)
        return lib
    }

    func testTheMonthStartsOnTheRightWeekday() {
        // September 2026 begins on a Tuesday: one empty cell before it, Monday first.
        let month = Library().careMonth("2026-09", today: "2026-09-25")
        XCTAssertEqual(month.lead, 1)
        XCTAssertEqual(month.days.count, 30)
        // February 2028 is a leap month.
        XCTAssertEqual(Library().careMonth("2028-02", today: "2028-02-01").days.count, 29)
    }

    func testAServiceSitsOnTheDayItFallsDueAndTakesItsColour() {
        let month = library().careMonth("2026-09", today: "2026-09-25")
        let day = { (d: Int) in month.days[d - 1] }
        XCTAssertEqual(day(19).count, 1)
        XCTAssertEqual(day(19).state, "overdue", "boots were due on the 19th")
        XCTAssertEqual(day(27).count, 1)
        XCTAssertEqual(day(27).state, "soon")
        XCTAssertEqual(day(1).count, 0)
        XCTAssertEqual(day(1).state, "")
        XCTAssertEqual(month.overdue, 1)
    }

    func testAThingWithNoScheduleIsNotOnTheCalendar() {
        let month = library().careMonth("2026-09", today: "2026-09-25")
        XCTAssertEqual(month.days.map(\.count).reduce(0, +), 3, "three scheduled things; the towel is not one")
    }

    func testMonthsTurnOverTheYear() {
        XCTAssertEqual(Library.shiftMonth("2026-12", by: 1), "2027-01")
        XCTAssertEqual(Library.shiftMonth("2026-01", by: -1), "2025-12")
        XCTAssertEqual(Library.shiftMonth("2026-09", by: 0), "2026-09")
    }
}
