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
    /// site says so instead; and on a dated trip still ahead, a bought line says it too.
    func testSomethingBoughtOnSiteBeginsATripWithoutDates() {
        var lib = Library()
        let undated = trip("", "")
        let ahead = trip("2026-10-03", "2026-10-05")
        lib.trips = [undated, ahead]
        XCTAssertEqual(lib.loopStep(tripId: undated.id, today: "2026-09-27"), .pack)
        _ = lib.addBoughtOnSite(tripId: undated.id, name: "Sun hat")
        XCTAssertEqual(lib.loopStep(tripId: undated.id, today: "2026-09-27"), .onSite, "bought on site and still Pack")
        XCTAssertEqual(lib.loopStep(tripId: ahead.id, today: "2026-09-27"), .pack, "a dated trip ahead, nothing bought")
        // Bought on site says he is there, whatever the dates say — as the On site door
        // has always gone (the spec pass, 5 Oct 2026: the two disagreed).
        _ = lib.addBoughtOnSite(tripId: ahead.id, name: "Sun hat")
        XCTAssertEqual(lib.loopStep(tripId: ahead.id, today: "2026-09-27"), .onSite, "bought on site and still Pack")
        XCTAssertTrue(lib.onSiteBegun(tripId: ahead.id, today: "2026-09-27"))
        // Reviewed beats everything.
        lib.trips[0].reviewedAt = "2026-09-28T08:00:00.000Z"
        XCTAssertEqual(lib.loopStep(tripId: undated.id, today: "2026-09-27"), .refine)
    }

    /// His report (13 Oct 2026): at 07:30 on the first day, with "I leave at 08:00", the trip
    /// already said On site. On the first day the time he leaves decides — the loop and the On
    /// site door alike; with no time, the day does, as before; something bought on site is On
    /// site at any time. Given only the day, the end of it: what every caller saw before 0.75.
    func testOnItsFirstDayATripIsOnSiteOnlyFromTheTimeHeLeaves() {
        var lib = Library()
        var leaving = trip("2026-10-14", "2026-10-16")
        XCTAssertTrue(Library.setLeaveTime(&leaving, "08:00", home: false))
        var early = trip("2026-10-14", "")
        XCTAssertTrue(Library.setLeaveTime(&early, "00:10", home: false))
        let noTime = trip("2026-10-14", "2026-10-16")
        lib.trips = [leaving, early, noTime]
        func step(_ t: TripEvent, _ day: String, _ time: String) -> Library.LoopStep {
            lib.loopStep(tripId: t.id, today: day, time: time)
        }
        func door(_ t: TripEvent, _ day: String, _ time: String) -> Bool {
            lib.onSiteBegun(tripId: t.id, today: day, time: time)
        }

        XCTAssertEqual(step(leaving, "2026-10-14", "07:30"), .pack, "07:30 on the first day, leaving at 08:00")
        XCTAssertFalse(door(leaving, "2026-10-14", "07:30"), "the On site door at 07:30, leaving at 08:00")
        XCTAssertEqual(step(leaving, "2026-10-14", "7:59"), .pack, "a minute before he leaves")
        XCTAssertEqual(step(leaving, "2026-10-14", "08:00"), .onSite, "the minute he leaves is not On site")
        XCTAssertTrue(door(leaving, "2026-10-14", "08:00"), "no On site door the minute he leaves")
        XCTAssertEqual(step(leaving, "2026-10-14", "23:10"), .onSite)
        XCTAssertEqual(step(leaving, "2026-10-13", "09:00"), .pack, "the day before, after the time")
        XCTAssertFalse(door(leaving, "2026-10-13", "09:00"))
        XCTAssertEqual(step(leaving, "2026-10-15", "06:00"), .onSite, "the second day goes by the day")
        XCTAssertTrue(door(leaving, "2026-10-20", "06:00"), "after the trip the door went")
        XCTAssertEqual(step(leaving, "2026-10-17", "06:00"), .review)
        XCTAssertEqual(step(early, "2026-10-14", "00:05"), .pack, "just after midnight, leaving at 00:10")
        XCTAssertEqual(step(early, "2026-10-14", "00:10"), .onSite)
        // No time to leave: from the start of the day, as before.
        XCTAssertEqual(step(noTime, "2026-10-14", "00:00"), .onSite, "no time set and still Pack on the first day")
        XCTAssertTrue(door(noTime, "2026-10-14", "00:00"))
        // Only the day, or a time that is not one: the end of the day.
        XCTAssertEqual(lib.loopStep(tripId: leaving.id, today: "2026-10-14"), .onSite, "the day alone no longer says what it did")
        XCTAssertTrue(lib.onSiteBegun(tripId: leaving.id, today: "2026-10-14"))
        XCTAssertEqual(step(leaving, "2026-10-14", "soon"), .onSite, "an unreadable time")
        // Bought on site says he is there, whatever the time.
        _ = lib.addBoughtOnSite(tripId: leaving.id, name: "Sun hat")
        XCTAssertEqual(step(leaving, "2026-10-14", "07:30"), .onSite, "bought on site and still Pack before the time")
        XCTAssertTrue(door(leaving, "2026-10-14", "07:30"), "bought on site and no door before the time")
        XCTAssertFalse(Library.hasSetOff(trip("", ""), today: "2026-10-14", time: "12:00"), "an undated trip set off")
    }

    /// The moments a trip turns by the clock alone — the trip screen wakes at the next one,
    /// so a trip left open at 07:59 is On site at 08:00. Each really is a turn: the minute
    /// before it the step is another.
    func testATripTurnsByTheClockAtTheMomentsItSays() {
        var lib = Library()
        var leaving = trip("2026-10-30", "2026-11-01")
        XCTAssertEqual(Library.clockTurns(leaving), ["2026-10-30 00:00", "2026-11-02 00:00"], "no time: the day sets it off")
        _ = Library.setLeaveTime(&leaving, "08:00", home: false)
        XCTAssertEqual(Library.clockTurns(leaving), ["2026-10-30 08:00", "2026-11-02 00:00"], "the time he leaves is not the turn")
        XCTAssertEqual(Library.clockTurns(trip("2026-10-30", "")), ["2026-10-30 00:00", "2026-10-31 00:00"], "a one-day trip")
        XCTAssertEqual(Library.clockTurns(trip("", "")), [], "an undated trip turns by the clock")
        var reviewed = leaving
        reviewed.reviewedAt = "2026-11-03T08:00:00.000Z"
        XCTAssertEqual(Library.clockTurns(reviewed), [], "a reviewed trip turns by the clock")
        lib.trips = [leaving]
        func step(_ at: String) -> Library.LoopStep {
            lib.loopStep(tripId: leaving.id, today: String(at.prefix(10)), time: String(at.suffix(5)))
        }
        XCTAssertEqual([step("2026-10-30 07:59"), step("2026-10-30 08:00")], [.pack, .onSite])
        XCTAssertEqual([step("2026-11-01 23:59"), step("2026-11-02 00:00")], [.onSite, .review])
    }

    /// The colours say it: Pack, On site and Review are one trip, Plan and Refine the lists.
    func testTheLoopIsInOrderAndSaysWhatEachStepIsAbout() {
        XCTAssertEqual(Library.LoopStep.allCases.map(\.name), ["Plan", "Pack", "On site", "Review", "Refine"])
        XCTAssertEqual(Library.LoopStep.allCases.map(\.rawValue), [0, 1, 2, 3, 4])
        XCTAssertEqual(Library.LoopStep.allCases.map(\.aboutOneTrip), [false, true, true, true, false])
    }
}
