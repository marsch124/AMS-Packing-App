import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// The countdown on Home and the packing reminders (his ideas 6 and 7, 2 Oct 2026):
/// the next trip still to leave, and each packing step on the day it falls due.
final class CountdownTests: XCTestCase {
    override func setUp() { PackingEnv.freeze(at: "2026-10-01T12:00:00.000Z") }
    override func tearDown() { PackingEnv.reset() }

    /// One base template, a thing on each step of the timeline.
    private func library() -> Library {
        var lib = Library()
        lib.saveTemplate(newList(name: "Base", role: "base"))
        let base = lib.templates.first { $0.role == "base" }!.id
        for (name, phase) in [("Insurance", "prep"), ("Boots", "week"), ("Jacket", "week"), ("Charger", "daybefore"),
                              ("Phone", "morning"), ("Keys", "door"), ("Recovery drink", "after")] {
            let t = lib.addThing(name: name)!
            _ = lib.updateThing(id: t.id) { $0.phase = phase }
            _ = lib.setOnTemplate(itemId: t.id, templateId: base, on: true)
        }
        return lib
    }

    private func trip(_ lib: inout Library, _ name: String, _ start: String = "", _ end: String = "") -> String {
        lib.createTrip(newEvent(name: name, startDate: start, endDate: end)).id
    }

    func testTheNextTripIsTheSoonestStillToLeave() {
        var lib = library()
        _ = trip(&lib, "Been", "2026-09-01", "2026-09-05")
        let later = trip(&lib, "Later", "2026-12-01", "2026-12-10")
        let soon = trip(&lib, "Soon", "2026-10-21", "2026-10-28")
        _ = trip(&lib, "Some day")
        let next = lib.nextTrip(today: "2026-10-01")
        XCTAssertEqual(next?.name, "Soon", "not the soonest trip still to leave")
        XCTAssertEqual(next?.days, 20)
        XCTAssertEqual(next?.left, 7, "every line still to pack")
        XCTAssertEqual(next?.step?.phaseId, "prep", "the first step with something left, even one due already")
        XCTAssertEqual(next?.step?.date, "2026-09-21", "Preparations falls due 30 days ahead")
        let n = lib.trips.firstIndex { $0.id == soon }!
        lib.trips[n].reviewedAt = "2026-10-01T10:00:00.000Z"
        XCTAssertEqual(lib.nextTrip(today: "2026-10-01")?.id, later, "a reviewed trip is still counted down")
        XCTAssertEqual(lib.nextTrip(today: "2026-12-01")?.days, 0, "the day it starts is day 0")
        XCTAssertNil(lib.nextTrip(today: "2026-12-02"), "a trip under way is counted down")
    }

    func testAStepFallsDueItsLeadDaysAheadAndGoesWhenPacked() {
        var lib = library()
        let id = trip(&lib, "Soon", "2026-10-21", "2026-10-28")
        let steps = lib.packingSteps(tripId: id)
        XCTAssertEqual(steps.map(\.phaseId), ["prep", "week", "daybefore", "morning", "door"], "after the trip is a reminder")
        XCTAssertEqual(steps.map(\.date), ["2026-09-21", "2026-10-14", "2026-10-20", "2026-10-21", "2026-10-21"])
        XCTAssertEqual(steps.first { $0.phaseId == "week" }?.says, "≥1 week ahead: 2 to pack")
        XCTAssertEqual(steps.first { $0.phaseId == "prep" }?.says, "Preparations: 1 to do", "Preparations are things to do")
        for line in lib.trips.first(where: { $0.id == id })!.entries where line.phase == "week" {
            _ = lib.setChecked(true, tripId: id, entryId: line.id)
        }
        let charger = lib.trips.first { $0.id == id }!.entries.first { $0.name == "Charger" }!
        _ = lib.setAside(true, tripId: id, entryId: charger.id)
        XCTAssertEqual(lib.packingSteps(tripId: id).map(\.phaseId), ["prep", "morning", "door"],
                       "a step all ticked or set aside still reminds")
    }

    func testOneReminderPerTripPerDayFromTodayOn() {
        var lib = library()
        let soon = trip(&lib, "Soon", "2026-10-21", "2026-10-28")
        let later = trip(&lib, "Later", "2026-12-01", "2026-12-10")
        let plan = lib.reminderPlan(today: "2026-10-01")
        // Soon: Preparations fell due on 21 Sep (gone by); a week ahead on 14 Oct; the
        // day before on 20 Oct; the morning and the front door together on 21 Oct.
        XCTAssertEqual(plan.filter { $0.tripId == soon }.map(\.date), ["2026-10-14", "2026-10-20", "2026-10-21"])
        XCTAssertEqual(plan.first { $0.tripId == soon && $0.date == "2026-10-21" }?.says,
                       "Morning list: 1 to pack · At the front door: 1 to pack", "one reminder for the day, both steps in it")
        XCTAssertEqual(plan.filter { $0.tripId == later }.map(\.date), ["2026-11-01", "2026-11-24", "2026-11-30", "2026-12-01"])
        XCTAssertEqual(plan.map(\.date), plan.map(\.date).sorted(), "not soonest first")
        XCTAssertEqual(plan.first?.tripName, "Soon")
        XCTAssertEqual(lib.reminderPlan(today: "2026-10-01", limit: 2).count, 2, "more than the limit")
        let n = lib.trips.firstIndex { $0.id == soon }!
        lib.trips[n].reviewedAt = "2026-10-01T10:00:00.000Z"
        XCTAssertTrue(lib.reminderPlan(today: "2026-10-01").allSatisfy { $0.tripId == later }, "a reviewed trip still reminds")
    }

    /// A trip marked done but never reviewed — only data from elsewhere can be so
    /// (a saved review here sets both) — is behind him: no countdown, no reminders.
    func testATripMarkedDoneIsNoCountdownEvenUnreviewed() {
        var lib = library()
        let soon = trip(&lib, "Soon", "2026-10-21", "2026-10-28")
        let n = lib.trips.firstIndex { $0.id == soon }!
        lib.trips[n].status = "done"
        XCTAssertTrue(lib.trips[n].reviewedAt.isEmpty)
        XCTAssertNil(lib.nextTrip(today: "2026-10-01"), "a trip marked done is counted down")
        XCTAssertTrue(lib.reminderPlan(today: "2026-10-01").isEmpty, "a trip marked done still reminds")
    }

    func testDaysAreCountedOnTheCalendar() {
        XCTAssertEqual(Library.ymd("2026-10-21", plusDays: -7), "2026-10-14")
        XCTAssertEqual(Library.ymd("2026-03-01", plusDays: -1), "2026-02-28")
        XCTAssertEqual(Library.ymd("2028-03-01", plusDays: -1), "2028-02-29")
        XCTAssertEqual(Library.ymd("2027-01-15", plusDays: -30), "2026-12-16")
    }
}
