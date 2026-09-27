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

    /// His loop (2026-09-27): a trip is packed until it is over, then waits for its
    /// review; once reviewed, what it taught waits in Refine.
    func testATripMovesRoundTheLoop() {
        var lib = Library()
        let coming = trip("2026-10-03", "2026-10-05")
        let today = trip("2026-09-26", "2026-09-27")
        let over = trip("2026-09-20", "2026-09-21")
        let oneDay = trip("2026-09-25", "")
        var reviewed = trip("2026-09-10", "2026-09-12"); reviewed.reviewedAt = "2026-09-13T08:00:00.000Z"
        var done = trip("2026-09-01", "2026-09-02"); done.status = "done"
        let empty = trip("2026-10-10", "2026-10-11", lines: 0)
        let undated = trip("", "")
        lib.trips = [coming, today, over, oneDay, reviewed, done, empty, undated]
        let at = { (t: TripEvent) -> Library.LoopStep in lib.loopStep(tripId: t.id, today: "2026-09-27") }

        XCTAssertEqual(at(coming), .pack, "a trip still ahead is being packed")
        XCTAssertEqual(at(today), .pack, "its last day is still the trip")
        XCTAssertEqual(at(over), .review, "over and not reviewed: Review")
        XCTAssertEqual(at(oneDay), .review, "a one-day trip is over the day after")
        XCTAssertEqual(at(reviewed), .refine, "reviewed: Refine")
        XCTAssertEqual(at(done), .refine, "the web app's done is reviewed too")
        XCTAssertEqual(at(empty), .plan, "no lines yet: still Plan")
        XCTAssertEqual(at(undated), .pack, "no dates: never over")
        XCTAssertEqual(lib.loopStep(tripId: "nope", today: "2026-09-27"), .plan)
    }

    /// The colours say it: Pack and Review are one trip, Plan and Refine the lists.
    func testTheLoopIsInOrderAndSaysWhatEachStepIsAbout() {
        XCTAssertEqual(Library.LoopStep.allCases.map(\.name), ["Plan", "Pack", "Review", "Refine"])
        XCTAssertEqual(Library.LoopStep.allCases.map(\.aboutOneTrip), [false, true, true, false])
    }
}
