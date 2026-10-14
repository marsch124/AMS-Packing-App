import XCTest
import PackingCore
@testable import PackingLibrary

/// Before you start (spec 07 part 19, his yes of 14 Oct 2026): what to buy and get ready ahead,
/// in one place, on a trip not yet being packed. Invented data only — this repository is public.
final class BeforeYouStartTests: XCTestCase {

    override func setUp() { PackingEnv.freeze(at: "2026-10-14T09:00:00.000Z") }
    override func tearDown() { PackingEnv.reset() }

    /// The batteries' library (spec 07 part 15: a Toothbrush, a Passport and a Phone charger on the
    /// base; a Camp pouch — holding a Power bank, a GPS watch taken out and a Lighter —, a Headlamp
    /// and a Map on Hiking; with a battery: Headlamp, Power bank, GPS watch, Toothbrush) — plus Sun
    /// cream on the base, a "Book the hut" thing in Preparations on Hiking, and Hiking's reminders a
    /// month ahead, a week ahead, the day before and on the morning.
    static func library() -> Library {
        var lib = BatteriesTests.library()
        let base = lib.templates.first { $0.role == "base" }!.id
        let hiking = lib.templates.first { $0.name == "Hiking" }!.id
        if let t = lib.addThing(name: "Sun cream") { _ = lib.setOnTemplate(itemId: t.id, templateId: base, on: true) }
        if let t = lib.addThing(name: "Hut booking") {
            _ = lib.setOnTemplate(itemId: t.id, templateId: hiking, on: true)
            _ = lib.updateThing(id: t.id) { $0.phase = "prep" }
        }
        XCTAssertNotNil(lib.addReminder(templateId: hiking, name: "Check the forecast", when: "week"))
        XCTAssertNotNil(lib.addReminder(templateId: hiking, name: "Leave a route note", when: "daybefore"))
        XCTAssertNotNil(lib.addReminder(templateId: hiking, name: "Ask for leave", when: "prep"))
        XCTAssertNotNil(lib.addReminder(templateId: hiking, name: "Water the plants", when: "morning"))
        return lib
    }

    func id(_ lib: Library, _ name: String) -> String { BatteriesTests.id(lib, name) }

    func trip(_ lib: inout Library, _ name: String = "Weekend in the hills", start: String = "2026-10-30",
              end: String = "2026-11-01") -> String {
        var t = newEvent(name: name, startDate: start, endDate: end)
        t.activities = lib.templates.filter { $0.name == "Hiking" }.map(\.id)
        return lib.createTrip(t).id
    }

    func entry(_ lib: Library, _ tripId: String, _ name: String) -> String {
        lib.trips.first { $0.id == tripId }!.entries.first { $0.name == name }!.id
    }

    /// "Map: needs replacing", "Sun cream: date · used up on X" — the To buy rows, in order.
    func said(_ rows: [BeforeYouStart.Buy]) -> [String] {
        rows.map { row in
            "\(row.name): " + row.why.map { w -> String in
                switch w {
                case .onToBuy: return "on To buy"
                case .needsReplacing: return "needs replacing"
                case .date(let f): return f.alreadyOut ? "out of date" : (f.beforeHome ? "runs out" : "document")
                case .usedUp(let t): return "used up on \(t)"
                }
            }.joined(separator: " · ")
        }
    }

    // MARK: - When

    /// At Plan and at Pack until the first THING is ticked: a reminder, a Preparations line, a
    /// line set aside and a charge tick are not packing; a thing ticked, or something ticked inside
    /// a kit, is. Set off, over, reviewed or bought on site: never.
    func testItShowsUntilTheFirstThingIsPacked() {
        var lib = BeforeYouStartTests.library()
        let trip = trip(&lib)
        let today = "2026-10-14"
        XCTAssertTrue(lib.beforeStartTime(tripId: trip, today: today), "a trip being planned has no Before you start")
        XCTAssertFalse(lib.beforeYouStart(tripId: trip, today: today).isEmpty)

        // Things to DO ticked, a thing set aside, a thing charged: still not packing.
        XCTAssertTrue(lib.setChecked(true, tripId: trip, entryId: entry(lib, trip, "Ask for leave")))
        XCTAssertTrue(lib.setChecked(true, tripId: trip, entryId: entry(lib, trip, "Hut booking")))
        XCTAssertTrue(lib.setAside(true, tripId: trip, entryId: entry(lib, trip, "Map")))
        XCTAssertTrue(lib.setCharged(true, tripId: trip, lineId: entry(lib, trip, "Headlamp")))
        XCTAssertFalse(Library.hasStartedPacking(lib.trips[0]), "a reminder, a Preparations line, ⊘ or a charge counted as packing")
        XCTAssertTrue(lib.beforeStartTime(tripId: trip, today: today))

        // The first thing packed: it goes. Unticked: it comes back.
        XCTAssertTrue(lib.setChecked(true, tripId: trip, entryId: entry(lib, trip, "Headlamp")))
        XCTAssertTrue(Library.hasStartedPacking(lib.trips[0]))
        XCTAssertFalse(lib.beforeStartTime(tripId: trip, today: today), "still shown once packing began")
        XCTAssertTrue(lib.beforeYouStart(tripId: trip, today: today).isEmpty, "Before you start has parts once packing began")
        XCTAssertTrue(lib.setChecked(false, tripId: trip, entryId: entry(lib, trip, "Headlamp")))
        XCTAssertTrue(lib.beforeStartTime(tripId: trip, today: today))

        // Something ticked inside a kit is packing too.
        XCTAssertTrue(lib.setKitContentTicked(true, tripId: trip, entryId: entry(lib, trip, "Camp pouch"),
                                              contentId: id(lib, "Lighter")))
        XCTAssertFalse(lib.beforeStartTime(tripId: trip, today: today), "a kit being filled is not packing")
        XCTAssertTrue(lib.setKitContentTicked(false, tripId: trip, entryId: entry(lib, trip, "Camp pouch"),
                                              contentId: id(lib, "Lighter")))
        XCTAssertTrue(lib.beforeStartTime(tripId: trip, today: today))

        // On its first day: before the time he leaves yes, from it no; later, over, reviewed: no.
        lib.trips[0].extra[LEAVE_AT_KEY] = .string("08:00")
        XCTAssertTrue(lib.beforeStartTime(tripId: trip, today: "2026-10-30", time: "07:30"))
        XCTAssertFalse(lib.beforeStartTime(tripId: trip, today: "2026-10-30", time: "08:00"), "set off, still shown")
        XCTAssertFalse(lib.beforeStartTime(tripId: trip, today: "2026-10-31"))
        XCTAssertFalse(lib.beforeStartTime(tripId: trip, today: "2026-11-02"))
        lib.trips[0].status = "done"
        XCTAssertFalse(lib.beforeStartTime(tripId: trip, today: today), "a reviewed trip")
        lib.trips[0].status = ""
        XCTAssertNotNil(lib.addBoughtOnSite(tripId: trip, name: "Postcards"))
        XCTAssertFalse(lib.beforeStartTime(tripId: trip, today: today), "bought on site: he is there")
        XCTAssertFalse(lib.beforeStartTime(tripId: "no-such-trip", today: today))
        XCTAssertTrue(lib.beforeYouStart(tripId: "no-such-trip", today: today).isEmpty)
    }

    // MARK: - To buy

    /// The trip's things on To buy (by the thing, or a line typed with its name), needing
    /// replacing (inside a kit too), running out before he is home, a document short of six
    /// months — in the trip's order, a thing once. Not: a consumable alone, a thing set aside,
    /// To buy lines about other things, a line already bought.
    func testToBuyGathersWhatIsOnToBuyWornOutAndRunningOut() {
        var lib = BeforeYouStartTests.library()
        let trip = trip(&lib)
        // Nothing to buy at first: every reason is off.
        XCTAssertEqual(lib.toBuyBeforeStart(tripId: trip, today: "2026-10-14").map(\.name), [])

        _ = lib.updateThing(id: id(lib, "Map")) { $0.condition = "retire" }
        _ = lib.updateThing(id: id(lib, "Lighter")) { $0.condition = "retire" }
        _ = lib.updateThing(id: id(lib, "Sun cream")) { $0.expiry = "2026-10-31"; $0.consumable = true }
        _ = lib.updateThing(id: id(lib, "Passport")) { $0.expiry = "2027-03-01"; $0.category = DOCUMENTS_CATEGORY }
        _ = lib.updateThing(id: id(lib, "Toothbrush")) { $0.consumable = true }            // a consumable alone
        XCTAssertNotNil(lib.addAction(text: "Headlamp", kind: "shopping", itemId: id(lib, "Headlamp"), itemName: "Headlamp"))
        XCTAssertNotNil(lib.addAction(text: "phone charger ", kind: "shopping"))          // typed, the same name
        // The GPS watch is taken out of the Camp pouch: not on this trip.
        XCTAssertNotNil(lib.addAction(text: "GPS watch", kind: "shopping", itemId: id(lib, "GPS watch"), itemName: "GPS watch"))
        XCTAssertNotNil(lib.addAction(text: "Coffee filters", kind: "shopping"))          // no thing, no line of that name
        let bought = lib.addAction(text: "Map", kind: "shopping", itemId: id(lib, "Map"), itemName: "Map")!
        XCTAssertTrue(lib.setActionDone(true, id: bought.id))                              // bought: not "on To buy"

        let rows = lib.toBuyBeforeStart(tripId: trip, today: "2026-10-14")
        XCTAssertEqual(said(rows), ["Passport: document", "Phone charger: on To buy", "Sun cream: runs out",
                                    "Lighter, in the Camp pouch: needs replacing", "Headlamp: on To buy",
                                    "Map: needs replacing"])
        XCTAssertEqual(rows.map(\.thingId), [id(lib, "Passport"), id(lib, "Phone charger"), id(lib, "Sun cream"),
                                             id(lib, "Lighter"), id(lib, "Headlamp"), id(lib, "Map")],
                       "a row does not open its own thing")
        XCTAssertEqual(rows.map(\.red), [false, false, true, true, false, true])
        XCTAssertEqual(rows.map(\.orange), [true, false, false, false, false, false])

        // Set aside: not going, nothing to buy for it. The ones inside a kit go with their kit.
        XCTAssertTrue(lib.setAside(true, tripId: trip, entryId: entry(lib, trip, "Camp pouch")))
        XCTAssertTrue(lib.setAside(true, tripId: trip, entryId: entry(lib, trip, "Map")))
        XCTAssertEqual(lib.toBuyBeforeStart(tripId: trip, today: "2026-10-14").map(\.name),
                       ["Passport", "Phone charger", "Sun cream", "Headlamp"])
        // A thing put right goes at once: the date moved on, the line ticked bought on To buy.
        _ = lib.updateThing(id: id(lib, "Sun cream")) { $0.expiry = "2027-10-31" }
        let headlampLine = lib.actions.first { $0.itemId == id(lib, "Headlamp") }!
        XCTAssertTrue(lib.setActionDone(true, id: headlampLine.id))
        XCTAssertEqual(lib.toBuyBeforeStart(tripId: trip, today: "2026-10-14").map(\.name), ["Passport", "Phone charger"])
        // A line typed on the trip only, with the name of a To buy line: its own row, nothing to open.
        XCTAssertNotNil(lib.addCustomLine(tripId: trip, name: "Coffee filters"))
        let typed = lib.toBuyBeforeStart(tripId: trip, today: "2026-10-14").last!
        XCTAssertEqual(typed.name, "Coffee filters")
        XCTAssertNil(typed.thingId)
        XCTAssertEqual(lib.toBuyBeforeStart(tripId: "no-such-trip", today: "2026-10-14").count, 0)
    }

    /// Used up on the last trip it went on, and not bought since: to buy. A To buy line for it
    /// ticked bought after that trip began, or a later trip on which it went and was not used up,
    /// clears it; a trip after this one, or one on which it was set aside, says nothing.
    func testUsedUpLastTimeIsToBuyUntilBoughtOrGoneAgain() {
        var lib = BeforeYouStartTests.library()
        let summer = trip(&lib, "Summer hike", start: "2026-08-01", end: "2026-08-03")
        let autumn = trip(&lib, start: "2026-10-30", end: "2026-11-01")
        // On the summer hike the sun cream went and was used up; the map went and came home.
        for name in ["Sun cream", "Map"] {
            XCTAssertTrue(lib.setChecked(true, tripId: summer, entryId: entry(lib, summer, name)))
        }
        XCTAssertTrue(lib.setUsedUp(true, tripId: summer, entryId: entry(lib, summer, "Sun cream")))
        lib.trips[lib.trips.firstIndex { $0.id == summer }!].status = "done"
        XCTAssertEqual(said(lib.toBuyBeforeStart(tripId: autumn, today: "2026-10-14")), ["Sun cream: used up on Summer hike"])
        XCTAssertEqual(lib.toBuyBeforeStart(tripId: autumn, today: "2026-10-14").first?.orange, true)

        // On To buy and bought (today, after the summer hike began): no longer to buy.
        let line = lib.addAction(text: "Sun cream", kind: "shopping", itemId: id(lib, "Sun cream"), itemName: "Sun cream")!
        XCTAssertEqual(said(lib.toBuyBeforeStart(tripId: autumn, today: "2026-10-14")),
                       ["Sun cream: on To buy · used up on Summer hike"])
        XCTAssertTrue(lib.setActionDone(true, id: line.id))
        XCTAssertEqual(lib.toBuyBeforeStart(tripId: autumn, today: "2026-10-14").map(\.name), [], "bought since, still used up")

        // Bought BEFORE that trip began counts for nothing.
        let n = lib.actions.firstIndex { $0.id == line.id }!
        lib.actions[n].doneAt = "2026-07-20T10:00:00.000Z"
        XCTAssertEqual(lib.toBuyBeforeStart(tripId: autumn, today: "2026-10-14").map(\.name), ["Sun cream"],
                       "a line bought before the trip it was used up on cleared it")

        // A later trip on which it went and came home: he had it again.
        let september = trip(&lib, "September hike", start: "2026-09-10", end: "2026-09-12")
        XCTAssertTrue(lib.setChecked(true, tripId: september, entryId: entry(lib, september, "Sun cream")))
        XCTAssertEqual(lib.toBuyBeforeStart(tripId: autumn, today: "2026-10-14").map(\.name), [], "gone again since, still used up")
        // …but set aside on it, it did not go: the summer hike is its last trip again.
        XCTAssertTrue(lib.setAside(true, tripId: september, entryId: entry(lib, september, "Sun cream")))
        XCTAssertEqual(lib.toBuyBeforeStart(tripId: autumn, today: "2026-10-14").map(\.name), ["Sun cream"])

        // A trip AFTER this one says nothing about it: the summer hike's own Before you start is clean.
        XCTAssertEqual(lib.toBuyBeforeStart(tripId: summer, today: "2026-07-01").map(\.name), [])
        // A trip without dates looks back from today.
        lib.trips[lib.trips.firstIndex { $0.id == autumn }!].startDate = ""
        lib.trips[lib.trips.firstIndex { $0.id == autumn }!].endDate = ""
        XCTAssertEqual(lib.toBuyBeforeStart(tripId: autumn, today: "2026-10-14").map(\.name), ["Sun cream"])
        XCTAssertEqual(lib.toBuyBeforeStart(tripId: autumn, today: "2026-07-31").map(\.name), [],
                       "an undated trip looked at a trip still to come")
    }

    // MARK: - To prepare

    /// The trip's reminders and Preparations lines that fall due BEFORE the day he leaves, by the
    /// day they fall due, each with its day; the morning's reminder is not one; the To dos written
    /// on the trip last, due at once. Ticked or set aside, a line leaves. A reminder opens its
    /// template, a Preparations line its thing, a To do nothing.
    func testToPrepareListsWhatFallsDueBeforeTheDayHeLeaves() {
        var lib = BeforeYouStartTests.library()
        let trip = trip(&lib)
        let hiking = lib.templates.first { $0.name == "Hiking" }!.id
        XCTAssertNotNil(lib.addTripTodo(tripId: trip, name: "Name tag for the Day pack", today: "2026-10-14"))

        var rows = lib.toPrepare(tripId: trip, today: "2026-10-14")
        XCTAssertEqual(rows.map(\.line.name), ["Hut booking", "Ask for leave", "Check the forecast", "Leave a route note",
                                               "Name tag for the Day pack"],
                       "not by the day it falls due, or the morning's reminder is in")
        XCTAssertEqual(rows.map(\.due), ["2026-09-30", "2026-09-30", "2026-10-23", "2026-10-29", ""])
        XCTAssertEqual(rows.map(\.tripTodo), [false, false, false, false, true])
        XCTAssertEqual(rows.map(\.templateId), [nil, hiking, hiking, hiking, nil])
        XCTAssertEqual(rows.map(\.thingId), [id(lib, "Hut booking"), nil, nil, nil, nil])

        // Ticked or set aside: it leaves.
        XCTAssertTrue(lib.setChecked(true, tripId: trip, entryId: rows[2].line.id))
        XCTAssertTrue(lib.setAside(true, tripId: trip, entryId: rows[0].line.id))
        rows = lib.toPrepare(tripId: trip, today: "2026-10-14")
        XCTAssertEqual(rows.map(\.line.name), ["Ask for leave", "Leave a route note", "Name tag for the Day pack"])

        // Without dates: the same lines, no day.
        lib.trips[0].startDate = ""
        lib.trips[0].endDate = ""
        rows = lib.toPrepare(tripId: trip, today: "2026-10-14")
        XCTAssertEqual(rows.map(\.line.name), ["Ask for leave", "Leave a route note", "Name tag for the Day pack"])
        XCTAssertEqual(rows.map(\.due), ["", "", ""])
        XCTAssertEqual(lib.toPrepare(tripId: "no-such-trip", today: "2026-10-14").count, 0)
    }

    // MARK: - The whole, and Home

    /// The three parts together: To charge holds the things not charged yet; the door's words and
    /// Home's line count them; the next trip carries Home's line only in its time.
    func testThePartsTheWordsAndHomesLine() {
        var lib = BeforeYouStartTests.library()
        let trip = trip(&lib)
        _ = lib.updateThing(id: id(lib, "Map")) { $0.condition = "retire" }
        var start = lib.beforeYouStart(tripId: trip, today: "2026-10-14")
        XCTAssertEqual(start.buy.map(\.name), ["Map"])
        XCTAssertEqual(start.prepare.count, 4)
        XCTAssertEqual(start.charge.map(\.name), ["Toothbrush", "Power bank", "Headlamp"],
                       "To charge is not every thing with a battery on the trip")
        XCTAssertEqual(start.words, "1 to buy \u{00B7} 4 to prepare \u{00B7} 3 to charge")
        XCTAssertEqual(start.homeWords, "Before you start: 1 to buy, 4 to prepare")
        XCTAssertEqual(lib.nextTrip(today: "2026-10-14")?.beforeStart, "Before you start: 1 to buy, 4 to prepare")

        // Charged: it leaves To charge. Nothing to buy: the words leave it out.
        let toothbrush = start.charge[0]
        XCTAssertTrue(lib.setCharged(true, tripId: trip, lineId: toothbrush.lineId, contentId: toothbrush.contentId))
        _ = lib.updateThing(id: id(lib, "Map")) { $0.condition = "good" }
        start = lib.beforeYouStart(tripId: trip, today: "2026-10-14")
        XCTAssertEqual(start.charge.map(\.name), ["Power bank", "Headlamp"])
        XCTAssertEqual(start.words, "4 to prepare \u{00B7} 2 to charge")
        XCTAssertEqual(start.homeWords, "Before you start: 4 to prepare")

        // Only To charge left: no line on Home, the door still there.
        for row in lib.toPrepare(tripId: trip, today: "2026-10-14") {
            XCTAssertTrue(lib.setChecked(true, tripId: trip, entryId: row.line.id))
        }
        start = lib.beforeYouStart(tripId: trip, today: "2026-10-14")
        XCTAssertEqual(start.words, "2 to charge")
        XCTAssertEqual(start.homeWords, "")
        XCTAssertFalse(start.isEmpty)
        XCTAssertEqual(lib.nextTrip(today: "2026-10-14")?.beforeStart, "")

        // Packing begun: nothing on the door, nothing on Home.
        _ = lib.updateThing(id: id(lib, "Map")) { $0.condition = "retire" }
        XCTAssertTrue(lib.setChecked(true, tripId: trip, entryId: entry(lib, trip, "Headlamp")))
        XCTAssertTrue(lib.beforeYouStart(tripId: trip, today: "2026-10-14").isEmpty)
        XCTAssertEqual(lib.nextTrip(today: "2026-10-14")?.beforeStart, "")
        XCTAssertEqual(BeforeYouStart().words, "")
        XCTAssertEqual(BeforeYouStart().homeWords, "")
    }
}
