import XCTest
@testable import PackingCore
@testable import PackingLibrary

final class LoopTests: XCTestCase {
    override func setUp() { PackingEnv.freeze() }
    override func tearDown() { PackingEnv.reset() }

    private func trip(_ start: String, _ end: String, lines: Int = 1) -> TripEvent {
        var t = newEvent(name: "Trip", startDate: start, endDate: end)
        t.entries = (0..<lines).map { newItem(name: "Thing \($0)") }
        return t
    }

    /// His loop (2026-09-27), with On site after Pack (their field test, 3 Oct 2026):
    /// a trip is packed until it begins, On site while it is under way, then waits for
    /// its review; once reviewed, what it taught waits in Refine.
    func testATripMovesRoundTheLoop() {
        var lib = Library()
        let coming = trip("2026-10-03", "2026-10-05")
        let today = trip("2026-09-26", "2026-09-27")
        let begins = trip("2026-09-27", "2026-09-29")
        let over = trip("2026-09-20", "2026-09-21")
        let oneDay = trip("2026-09-25", "")
        let oneDayToday = trip("2026-09-27", "")
        var reviewed = trip("2026-09-10", "2026-09-12"); reviewed.reviewedAt = "2026-09-13T08:00:00.000Z"
        var done = trip("2026-09-01", "2026-09-02"); done.status = "done"
        let empty = trip("2026-10-10", "2026-10-11", lines: 0)
        let emptyUnderWay = trip("2026-09-26", "2026-09-28", lines: 0)
        let undated = trip("", "")
        lib.trips = [coming, today, begins, over, oneDay, oneDayToday, reviewed, done, empty, emptyUnderWay, undated]
        let at = { (t: TripEvent) -> Library.LoopStep in lib.loopStep(tripId: t.id, today: "2026-09-27") }

        XCTAssertEqual(at(coming), .pack, "a trip still ahead is being packed")
        XCTAssertEqual(at(begins), .onSite, "its first day: On site")
        XCTAssertEqual(at(today), .onSite, "its last day is still On site")
        XCTAssertEqual(at(oneDayToday), .onSite, "a one-day trip is On site on its day")
        XCTAssertEqual(at(over), .review, "over and not reviewed: Review")
        XCTAssertEqual(at(oneDay), .review, "a one-day trip is over the day after")
        XCTAssertEqual(at(reviewed), .refine, "reviewed: Refine")
        XCTAssertEqual(at(done), .refine, "the web app's done is reviewed too")
        XCTAssertEqual(at(empty), .plan, "no lines yet: still Plan")
        XCTAssertEqual(at(emptyUnderWay), .plan, "under way with no lines: still Plan")
        XCTAssertEqual(at(undated), .pack, "no dates and nothing bought: never begun, never over")
        XCTAssertEqual(lib.loopStep(tripId: "nope", today: "2026-09-27"), .plan)
    }

    /// A trip without dates has no first day to say it has begun — something bought on
    /// site says so instead. A dated trip goes by its dates alone.
    func testSomethingBoughtOnSiteBeginsATripWithoutDates() {
        var lib = Library()
        let undated = trip("", "")
        let ahead = trip("2026-10-03", "2026-10-05")
        lib.trips = [undated, ahead]
        XCTAssertEqual(lib.loopStep(tripId: undated.id, today: "2026-09-27"), .pack)
        _ = lib.addBoughtOnSite(tripId: undated.id, name: "Sun hat")
        XCTAssertEqual(lib.loopStep(tripId: undated.id, today: "2026-09-27"), .onSite, "bought on site and still Pack")
        _ = lib.addBoughtOnSite(tripId: ahead.id, name: "Sun hat")
        XCTAssertEqual(lib.loopStep(tripId: ahead.id, today: "2026-09-27"), .pack, "a dated trip ahead goes by its dates")
        // Reviewed beats everything.
        lib.trips[0].reviewedAt = "2026-09-28T08:00:00.000Z"
        XCTAssertEqual(lib.loopStep(tripId: undated.id, today: "2026-09-27"), .refine)
    }

    /// The colours say it: Pack, On site and Review are one trip, Plan and Refine the lists.
    func testTheLoopIsInOrderAndSaysWhatEachStepIsAbout() {
        XCTAssertEqual(Library.LoopStep.allCases.map(\.name), ["Plan", "Pack", "On site", "Review", "Refine"])
        XCTAssertEqual(Library.LoopStep.allCases.map(\.rawValue), [0, 1, 2, 3, 4])
        XCTAssertEqual(Library.LoopStep.allCases.map(\.aboutOneTrip), [false, true, true, true, false])
    }
}
