import XCTest
@testable import PackingCore

// Ported from tests/model.test.mjs — sortEventsForList, tripNudge, tripEndDate,
// tripsAwaitingReview and packSteps.
final class TripEventsTests: XCTestCase {
    override func tearDown() {
        PackingEnv.reset()
        setPhases(DEFAULT_PHASES)
        super.tearDown()
    }

    // JS: 'packSteps: one step per non-empty phase, with packed/remaining counts'
    func testPackStepsOneStepPerNonEmptyPhaseWithPackedRemainingCounts() throws {
        let entries = [
            newItem(name: "A", phase: "week", checked: true),
            newItem(name: "B", phase: "week", checked: false),
            newItem(name: "C", phase: "morning", checked: false),
        ]
        let steps = packSteps(entries)
        XCTAssertEqual(steps.map { $0.phase.id }, ["week", "morning"])   // timeline order, empties skipped
        let week = try XCTUnwrap(steps.first { $0.phase.id == "week" })
        XCTAssertEqual(week.total, 2)
        XCTAssertEqual(week.done, 1)
        XCTAssertEqual(week.remaining, 1)
        let morning = try XCTUnwrap(steps.first { $0.phase.id == "morning" })
        XCTAssertEqual(morning.remaining, 1)
    }

    // JS: 'packSteps: set-aside entries are not part of the walk'
    func testPackStepsSetAsideEntriesAreNotPartOfTheWalk() throws {
        let entries = [
            newItem(name: "A", phase: "week", checked: true),
            newItem(name: "B", phase: "week"),
            newItem(name: "C", phase: "week", skipped: true),
        ]
        let step = try XCTUnwrap(packSteps(entries).first { $0.phase.id == "week" })
        XCTAssertEqual(step.total, 2)
        XCTAssertEqual(step.done, 1)
        XCTAssertEqual(step.remaining, 1)
        XCTAssertFalse(step.entries.contains { $0.name == "C" })
    }

    // JS: 'packSteps: a phase with nothing left to pack drops out of the walk'
    func testPackStepsAPhaseWithNothingLeftToPackDropsOutOfTheWalk() {
        let entries = [
            newItem(name: "A", phase: "week"),
            newItem(name: "B", phase: "day", skipped: true),
        ]
        let ids = packSteps(entries).map { $0.phase.id }
        XCTAssertTrue(ids.contains("week"))
        XCTAssertFalse(ids.contains("day"), "a phase holding only set-aside things is not a step")
    }

    // JS: 'tripNudge: focuses the earliest due phase with unpacked items'
    func testTripNudgeFocusesTheEarliestDuePhaseWithUnpackedItems() throws {
        var ev = newEvent(startDate: "2026-08-10")
        ev.entries = [
            newItem(name: "Boots", phase: "week", checked: false),
            newItem(name: "Passport", phase: "morning", checked: false),
        ]
        // 7 days out: only the "≥1 week ahead" phase is due (lead 7 >= 7); morning (lead 0) not yet.
        let n = try XCTUnwrap(tripNudge(ev, "2026-08-03"))
        XCTAssertEqual(n.daysToGo, 7)
        XCTAssertEqual(n.focusPhaseId, "week")
        XCTAssertEqual(n.dueCount, 1)
        // departure day: both phases due; earliest timeline (week) is the focus, count = 2.
        let n2 = try XCTUnwrap(tripNudge(ev, "2026-08-10"))
        XCTAssertEqual(n2.focusPhaseId, "week")
        XCTAssertEqual(n2.dueCount, 2)
    }

    // JS: 'tripNudge: null without a date; zero due when all packed'
    func testTripNudgeNullWithoutADateZeroDueWhenAllPacked() {
        XCTAssertNil(tripNudge(newEvent(), "2026-08-03"))
        var ev = newEvent(startDate: "2026-08-04")
        ev.entries = [newItem(name: "X", phase: "week", checked: true)]
        XCTAssertEqual(tripNudge(ev, "2026-08-03")?.dueCount, 0)
    }

    // JS: 'sortEventsForList orders nearest-upcoming first, then undated, then past'
    func testSortEventsForListOrdersNearestUpcomingFirstThenUndatedThenPast() {
        let today = "2026-07-29T00:00:00Z"
        func ev(_ id: String, _ startDate: String, _ createdAt: String = "2026-01-01T00:00:00Z") -> TripEvent {
            TripEvent(id: id, startDate: startDate, createdAt: createdAt)
        }
        let soon = ev("soon", "2026-08-02")        // +4 days
        let later = ev("later", "2026-12-25")      // far future
        let past = ev("past", "2026-07-10")        // -19 days
        let older = ev("older", "2026-01-05")      // more past
        let draftA = ev("draftA", "", "2026-06-01T00:00:00Z")
        let draftB = ev("draftB", "", "2026-07-20T00:00:00Z")   // newer draft
        let out = sortEventsForList([older, draftA, later, past, soon, draftB], today).map { $0.id }
        XCTAssertEqual(out, ["soon", "later", "draftB", "draftA", "past", "older"])
    }

    // --- v161: the trip review finally gets asked for -------------------------
    // These pin the two halves of the Home fix: a finished trip must NOT be able to
    // claim the "pack now" slot, and it MUST be able to claim the review slot.

    private func reviewable(id: String = PackingEnv.makeId(), name: String = "Norway",
                            startDate: String = "2026-08-30", endDate: String = "2026-09-05",
                            entries: [Item]? = nil, status: String = "active", reviewedAt: String = "") -> TripEvent {
        newEvent(id: id, name: name, startDate: startDate, endDate: endDate,
                 entries: entries ?? [newItem(name: "Boots")], status: status, reviewedAt: reviewedAt)
    }

    // JS: 'tripEndDate: the return date, or the start when there is no return'
    func testTripEndDateTheReturnDateOrTheStartWhenThereIsNoReturn() {
        XCTAssertEqual(tripEndDate(TripEvent(startDate: "2026-09-01", endDate: "2026-09-08")), "2026-09-08")
        XCTAssertEqual(tripEndDate(TripEvent(startDate: "2026-09-01", endDate: "")), "2026-09-01")
        XCTAssertEqual(tripEndDate(TripEvent(startDate: "", endDate: "")), "")
        XCTAssertEqual(tripEndDate(nil), "")
    }

    // JS: 'tripsAwaitingReview: a finished, unreviewed trip is offered'
    func testTripsAwaitingReviewAFinishedUnreviewedTripIsOffered() {
        let rows = tripsAwaitingReview([reviewable()], "2026-09-10")
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.endedDaysAgo, 5)
        XCTAssertEqual(rows.first?.event.name, "Norway")
    }

    // JS: 'tripsAwaitingReview: not while it is still running, and not on the day it ends'
    func testTripsAwaitingReviewNotWhileItIsStillRunningAndNotOnTheDayItEnds() {
        XCTAssertEqual(tripsAwaitingReview([reviewable()], "2026-09-02").count, 0, "mid-trip")
        XCTAssertEqual(tripsAwaitingReview([reviewable()], "2026-09-05").count, 0, "still driving home")
        XCTAssertEqual(tripsAwaitingReview([reviewable()], "2026-09-06").count, 1, "the morning after")
    }

    // JS: 'tripsAwaitingReview: the offer expires, rather than nagging about last year'
    func testTripsAwaitingReviewTheOfferExpires() {
        func day(_ n: String) -> Int { tripsAwaitingReview([reviewable()], n).count }
        XCTAssertEqual(day("2026-10-05"), 1, "exactly 30 days is still inside the window")
        XCTAssertEqual(day("2026-10-06"), 0, "a day later it has expired")
        XCTAssertEqual(REVIEW_WINDOW_DAYS, 30)
    }

    // JS: 'tripsAwaitingReview: skips trips already reviewed, undated, or with no gear'
    func testTripsAwaitingReviewSkipsTripsAlreadyReviewedUndatedOrWithNoGear() {
        XCTAssertEqual(tripsAwaitingReview([reviewable(reviewedAt: "2026-09-06T10:00:00Z")], "2026-09-10").count, 0)
        XCTAssertEqual(tripsAwaitingReview([reviewable(status: "done")], "2026-09-10").count, 0)
        XCTAssertEqual(tripsAwaitingReview([reviewable(startDate: "", endDate: "")], "2026-09-10").count, 0)
        XCTAssertEqual(tripsAwaitingReview([reviewable(entries: [])], "2026-09-10").count, 0)
        let remindersOnly = reviewable(entries: [newItem(name: "Lock the door", itemType: "reminder")])
        XCTAssertEqual(tripsAwaitingReview([remindersOnly], "2026-09-10").count, 0, "a reminder is not gear to review")
    }

    // JS: 'tripsAwaitingReview: most recently finished first'
    func testTripsAwaitingReviewMostRecentlyFinishedFirst() {
        let rows = tripsAwaitingReview([
            reviewable(id: "a", name: "Older", startDate: "2026-08-20", endDate: "2026-08-25"),
            reviewable(id: "b", name: "Newer", startDate: "2026-09-01", endDate: "2026-09-08"),
        ], "2026-09-10")
        XCTAssertEqual(rows.map { $0.event.name }, ["Newer", "Older"])
    }

    // JS: 'tripNudge: a finished trip reports a NEGATIVE days-to-go'
    func testTripNudgeAFinishedTripReportsANegativeDaysToGo() throws {
        // The premise of the Home fix. Home sorts its pack nudges ascending, so before
        // v161 this negative number sorted a trip that was already over ahead of every
        // upcoming one and kept the only slot. Home now filters on daysToGo >= 0.
        let ev = newEvent(startDate: "2026-08-01", entries: [newItem(name: "Boots", phase: "week")])
        let n = try XCTUnwrap(tripNudge(ev, "2026-09-10"))
        XCTAssertTrue(n.daysToGo < 0, "a past trip is negative")
        XCTAssertTrue(n.dueCount > 0, "and it still reports unpacked items — which is why it used to win")
        XCTAssertEqual(countdownLabel(n.daysToGo), "40 days ago")
    }

    // MARK: - Not in the JS suite — behaviour checked against the JS, pinned here

    func testTripNudgeWithNothingDueHasNoFocus() throws {
        let ev = newEvent(startDate: "2026-08-20", entries: [newItem(name: "Passport", phase: "morning")])
        let n = try XCTUnwrap(tripNudge(ev, "2026-08-03"))
        XCTAssertEqual(n, TripNudge(daysToGo: 17, label: "in 17 days", focusPhaseId: nil, focusLabel: "", dueCount: 0))
        // An "after the trip" phase (lead -1) is never due before departure; a phase this
        // device does not know has lead 0, so it is due on the day.
        let odd = newEvent(startDate: "2026-08-03", entries: [newItem(name: "Towel", phase: "after"), newItem(name: "Mystery", phase: "from-the-mac")])
        let n2 = try XCTUnwrap(tripNudge(odd, "2026-08-03"))
        XCTAssertEqual(n2.focusPhaseId, "from-the-mac")
        XCTAssertEqual(n2.focusLabel, "from-the-mac")
        XCTAssertEqual(n2.dueCount, 1)
    }

    func testSortEventsForListAnUnreadableStartDateCountsAsUndated() {
        let a = TripEvent(id: "bad", startDate: "soon-ish", createdAt: "2026-07-01T00:00:00Z")
        let b = TripEvent(id: "past", startDate: "2026-07-01", createdAt: "2026-01-01T00:00:00Z")
        let c = TripEvent(id: "today", startDate: "2026-07-29", createdAt: "2026-01-01T00:00:00Z")
        XCTAssertEqual(sortEventsForList([b, a, c], "2026-07-29").map { $0.id }, ["today", "bad", "past"])
    }
}
