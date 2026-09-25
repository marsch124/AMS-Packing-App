import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// His travelling year: which months he goes away in, and what those trips came to.
final class TravelYearTests: XCTestCase {
    private func library() -> Library {
        var lib = Library()
        func trip(_ name: String, _ from: String, _ to: String, ticked: Int = 0) -> TripEvent {
            var t = newEvent(name: name, startDate: from, endDate: to)
            t.entries = (0..<3).map { n in
                var it = newItem(name: "thing \(n)")
                it.checked = n < ticked
                return it
            }
            return t
        }
        lib.trips = [trip("a", "2026-09-10", "2026-09-13", ticked: 2),
                     trip("b", "2026-09-20", "2026-09-21", ticked: 1),
                     trip("c", "2026-03-01", "2026-03-08"),
                     // Older than a year: outside the twelve months.
                     trip("old", "2024-09-01", "2024-09-03", ticked: 3)]
        return lib
    }

    func testTheYearCountsTripsNightsAndWhatWasPacked() {
        let year = library().travelYear(today: "2026-09-25")
        XCTAssertEqual(year.months.count, 12)
        XCTAssertEqual(year.months.last, "2026-09-01", "the last column is the month we are in")
        XCTAssertEqual(year.trips, 3, "the trip from two years ago is not in this year")
        XCTAssertEqual(year.byMonth.last, 2, "two trips started this month")
        XCTAssertEqual(year.nights, 3 + 1 + 7)
        XCTAssertEqual(year.packed, 3, "two ticks on one trip, one on another")
        XCTAssertEqual(year.most, 2)
    }

    func testATripWithNoDatesIsNotCounted() {
        var lib = Library()
        lib.trips = [newEvent(name: "someday", startDate: "", endDate: "")]
        let year = lib.travelYear(today: "2026-09-25")
        XCTAssertEqual(year.trips, 0)
        XCTAssertEqual(year.nights, 0)
    }

    func testATripThatStartsAndEndsTheSameDayIsNoNights() {
        var lib = Library()
        lib.trips = [newEvent(name: "day out", startDate: "2026-09-02", endDate: "2026-09-02")]
        XCTAssertEqual(lib.travelYear(today: "2026-09-25").nights, 0)
    }
}
