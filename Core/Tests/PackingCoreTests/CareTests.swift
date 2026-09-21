import XCTest
@testable import PackingCore

// Ported from tests/model.test.mjs — "Care & maintenance", the careSections tests
// and the v165 "one row per item" tests. (The normalizeMaintenance and coerceItem
// care tests belong to the foundation and live in ItemsTests.swift.)
final class CareTests: XCTestCase {
    override func tearDown() { PackingEnv.reset(); super.tearDown() }

    // JS: 'addDays / daysBetween: UTC date arithmetic'
    func testAddDaysDaysBetweenUTCDateArithmetic() {
        XCTAssertEqual(addDays("2026-01-01", 365), "2027-01-01")
        XCTAssertEqual(addDays("2026-01-31", 1), "2026-02-01")
        XCTAssertEqual(daysBetween("2026-07-01", "2026-07-21"), 20)
        XCTAssertEqual(daysBetween("2026-07-21", "2026-07-01"), -20)
        XCTAssertNil(daysBetween("nope", "2026-07-01"))
    }

    // JS: 'hasCare: only true when the record holds something'
    func testHasCareOnlyTrueWhenTheRecordHoldsSomething() {
        XCTAssertEqual(hasCare(newItem(name: "Socks")), false)
        XCTAssertEqual(hasCare(newItem(name: "Bike", maintenance: Maintenance(link: "https://x"))), true)
        XCTAssertEqual(hasCare(newItem(name: "Tent", maintenance: Maintenance(intervalDays: 365))), true)
    }

    // JS: 'maintenanceStatus: overdue / soon / ok by next-due date'
    func testMaintenanceStatusOverdueSoonOkByNextDueDate() {
        let today = "2026-07-30T00:00:00Z"
        func mk(_ lastDone: String, _ intervalDays: Int) -> Item {
            newItem(name: "x", maintenance: Maintenance(intervalDays: intervalDays, lastDone: lastDone))
        }
        // Due exactly N days from today, whatever the threshold currently is.
        func dueIn(_ days: Int) -> Item { mk(addDays("2026-07-30", days - 30), 30) }
        XCTAssertEqual(maintenanceStatus(mk("2026-01-01", 90), today)?.state, "overdue") // due 2026-04-01
        XCTAssertEqual(maintenanceStatus(dueIn(3), today)?.state, "soon")
        XCTAssertEqual(maintenanceStatus(mk("2026-07-01", 365), today)?.state, "ok")     // due next year
        XCTAssertNil(maintenanceStatus(newItem(name: "x"), today))                        // no record
        // The "due soon" window is a boundary, so pin both sides of it.
        XCTAssertEqual(maintenanceStatus(dueIn(MAINTENANCE_SOON_DAYS), today)?.state, "soon")
        XCTAssertEqual(maintenanceStatus(dueIn(MAINTENANCE_SOON_DAYS + 1), today)?.state, "ok")
    }

    // JS: 'maintenanceStatus: reference-only (no interval) and never-done'
    func testMaintenanceStatusReferenceOnlyAndNeverDone() {
        let today = "2026-07-30T00:00:00Z"
        let ref = maintenanceStatus(newItem(name: "x", maintenance: Maintenance(notes: "hand wash")), today)
        XCTAssertEqual(ref?.state, "reference")
        XCTAssertEqual(ref?.scheduled, false)
        let never = maintenanceStatus(newItem(name: "x", maintenance: Maintenance(intervalDays: 30)), today)
        XCTAssertEqual(never?.neverDone, true)
        XCTAssertEqual(never?.nextDue, "2026-07-30") // due today when never logged
    }

    // JS: 'maintenanceList: orders overdue → soon → ok → reference'
    func testMaintenanceListOrdersOverdueSoonOkReference() {
        let today = "2026-07-30T00:00:00Z"
        let list = newList(name: "Gear", items: [
            newItem(name: "OK", maintenance: Maintenance(intervalDays: 365, lastDone: "2026-07-01")),
            newItem(name: "Reference", maintenance: Maintenance(notes: "wipe down")),
            newItem(name: "Overdue", maintenance: Maintenance(intervalDays: 90, lastDone: "2026-01-01")),
            newItem(name: "Soon", maintenance: Maintenance(intervalDays: 30, lastDone: "2026-07-20")),
            newItem(name: "Plain socks"), // no care → excluded
        ])
        let names = maintenanceList([list], today).map { $0.item.name }
        XCTAssertEqual(names, ["Overdue", "Soon", "OK", "Reference"])
    }

    // JS: 'maintenanceSummary: counts due (overdue + soon)'
    func testMaintenanceSummaryCountsDue() {
        let today = "2026-07-30T00:00:00Z"
        let list = newList(items: [
            newItem(maintenance: Maintenance(intervalDays: 90, lastDone: "2026-01-01")), // overdue
            newItem(maintenance: Maintenance(intervalDays: 30, lastDone: addDays("2026-07-30", -27))), // soon (3 days)
            newItem(maintenance: Maintenance(notes: "x")),                                // reference
        ])
        let s = maintenanceSummary([list], today)
        XCTAssertEqual(s.overdue, 1)
        XCTAssertEqual(s.soon, 1)
        XCTAssertEqual(s.due, 2)
        XCTAssertEqual(s.reference, 1)
        XCTAssertEqual(s.total, 3)
    }

    // JS: 'maintenanceByDate: buckets scheduled items on their next-due date'
    func testMaintenanceByDateBucketsScheduledItemsOnTheirNextDueDate() {
        let today = "2026-07-30T00:00:00Z"
        let list = newList(items: [
            newItem(name: "A", maintenance: Maintenance(intervalDays: 30, lastDone: "2026-07-20")), // due 2026-08-19
            newItem(name: "Ref", maintenance: Maintenance(notes: "x")),                              // no date → excluded
        ])
        let map = maintenanceByDate([list], today)
        XCTAssertEqual(map.first { $0.date == "2026-08-19" }?.rows.count, 1)
        XCTAssertEqual(map.map { $0.date }.count, 1)
    }

    // JS: 'logMaintenance: records a service, resets the schedule, appends history'
    func testLogMaintenanceRecordsAServiceResetsTheScheduleAppendsHistory() {
        var it = newItem(name: "Bike", maintenance: Maintenance(intervalDays: 90, lastDone: "2026-01-01"))
        logMaintenance(&it, "2026-07-30", "chain + drivetrain")
        XCTAssertEqual(it.maintenance?.lastDone, "2026-07-30")
        XCTAssertEqual(it.maintenance?.log.count, 1)
        XCTAssertEqual(it.maintenance?.log[0].note, "chain + drivetrain")
        // status now computes from the new lastDone (ok, due ~3 months out)
        XCTAssertEqual(maintenanceStatus(it, "2026-07-31T00:00:00Z")?.state, "ok")
        // works on an item with no prior record
        var fresh = newItem(name: "Jacket")
        logMaintenance(&fresh, "2026-07-30")
        XCTAssertEqual(fresh.maintenance?.lastDone, "2026-07-30")
    }

    // JS: 'careSections: overdue and due-soon stay open, far-off and reference fold'
    func testCareSectionsOverdueAndDueSoonStayOpenFarOffAndReferenceFold() throws {
        func row(_ state: String, _ days: Int?) -> MaintenanceRow { MaintenanceRow(status: MaintenanceStatus(state: state, days: days)) }
        let rows = [row("overdue", -5), row("soon", 3), row("ok", 20), row("ok", 400), row("reference", nil)]
        let secs = careSections(rows, 60)
        func by(_ key: String) throws -> CareSection { try XCTUnwrap(secs.first { $0.key == key }) }
        XCTAssertEqual(secs.map { $0.key }, ["overdue", "soon", "upcoming", "later", "reference"])
        XCTAssertEqual(try by("upcoming").rows.count, 1)         // the 20-day one
        XCTAssertEqual(try by("later").rows.count, 1)            // the 400-day one
        XCTAssertEqual(try by("overdue").fold, false)
        XCTAssertEqual(try by("soon").fold, false)
        XCTAssertEqual(try by("upcoming").fold, false)
        XCTAssertEqual(try by("later").fold, true)
        XCTAssertEqual(try by("reference").fold, true)
        // Every row lands in exactly one section, so nothing is hidden by the split.
        XCTAssertEqual(secs.reduce(0) { $0 + $1.rows.count }, rows.count)
    }

    // JS: 'careSections: the fold boundary, and a missing day count sinks to Later'
    func testCareSectionsTheFoldBoundaryAndAMissingDayCountSinksToLater() {
        func row(_ days: Int?) -> MaintenanceRow { MaintenanceRow(status: MaintenanceStatus(state: "ok", days: days)) }
        func at(_ days: Int?) -> [CareSection] { careSections([row(days)], MAINTENANCE_UPCOMING_DAYS) }
        XCTAssertEqual(at(MAINTENANCE_UPCOMING_DAYS).first { $0.key == "upcoming" }?.rows.count, 1)
        XCTAssertEqual(at(MAINTENANCE_UPCOMING_DAYS + 1).first { $0.key == "later" }?.rows.count, 1)
        XCTAssertEqual(at(nil).first { $0.key == "later" }?.rows.count, 1)
        XCTAssertEqual(careSections(nil).map { $0.rows.count }, [0, 0, 0, 0, 0])
    }

    // JS: 'careSections: rows keep the order they arrived in (the urgency sort still rules)'
    func testCareSectionsRowsKeepTheOrderTheyArrivedIn() {
        // (The JS row is `{ name, status }`; here the name sits on the row's item.)
        func row(_ name: String, _ days: Int) -> MaintenanceRow {
            MaintenanceRow(item: Item(name: name), status: MaintenanceStatus(state: "ok", days: days))
        }
        let secs = careSections([row("a", 5), row("b", 1), row("c", 9)], 60)
        XCTAssertEqual(secs.first { $0.key == "upcoming" }?.rows.map { $0.item.name }, ["a", "b", "c"])
    }

    // --- v165: the Care list shows an item once, however many templates hold it ---

    // JS: 'maintenanceList: one row per item across templates, naming all of them'
    func testMaintenanceListOneRowPerItemAcrossTemplatesNamingAllOfThem() {
        let jacket = newItem(name: "Shell jacket", maintenance: Maintenance(notes: "Re-proof", link: "", intervalDays: 180, lastDone: "2025-12-01", log: []))
        let golf = newList(name: "Golf", items: [jacket])
        let hike = newList(name: "Hiking", items: [jacket])
        let travel = newList(name: "Travel", items: [jacket])
        let rows = maintenanceList([golf, hike, travel], "2026-09-11")
        XCTAssertEqual(rows.count, 1, "was three rows — and Home said \"3 overdue\" for one jacket")
        XCTAssertEqual(rows.first?.listName, "Golf, Hiking, Travel")
        XCTAssertEqual(rows.first?.listNames, ["Golf", "Hiking", "Travel"])
        XCTAssertEqual(rows.first?.status.state, "overdue")
    }

    // JS: 'maintenanceList: different items are still separate rows'
    func testMaintenanceListDifferentItemsAreStillSeparateRows() {
        let a = newItem(name: "Boots", maintenance: Maintenance(notes: "Wax", link: "", intervalDays: 90, lastDone: "2026-09-01", log: []))
        let b = newItem(name: "Tent", maintenance: Maintenance(notes: "Seal seams", link: "", intervalDays: 365, lastDone: "2026-01-01", log: []))
        let rows = maintenanceList([newList(name: "Camp", items: [a, b])], "2026-09-11")
        XCTAssertEqual(rows.count, 2)
    }

    // --- not in the JS suite (every expected value below was read off the JS model in Node) ---

    func testTheConstantsAreTheJSOnes() {
        XCTAssertEqual(MAINTENANCE_INTERVALS.map { $0.days }, [0, 30, 90, 182, 365, 730])
        XCTAssertEqual(MAINTENANCE_INTERVALS.first?.label, "No schedule (reference only)")
        XCTAssertEqual(MAINTENANCE_SOON_DAYS, 14)
        XCTAssertEqual(MAINTENANCE_UPCOMING_DAYS, 60)
    }

    func testDatesAreReadTheWayDateParseReadsThem() {
        XCTAssertEqual(addDays("2024-02-28", 2), "2024-03-01")          // leap year
        XCTAssertEqual(addDays("1970-01-01", -1), "1969-12-31")
        XCTAssertEqual(addDays("2026-02-30", 0), "2026-03-02")          // a day the month lacks ROLLS OVER (V8)
        XCTAssertEqual(addDays("2026", 0), "2026-01-01")                // the shorter ISO forms count too
        XCTAssertEqual(addDays("2026-07", 1), "2026-07-02")
        XCTAssertEqual(addDays("+002026-07-30", -30), "2026-06-30")
        XCTAssertEqual(daysBetween("2026", "2026-02-30"), 60)
        for junk in ["", "nope", "2026-7-3", "2026-13-01", "2026-00-10", "2026-02-00", "2026-12-32", "20260730",
                     "2026-07-30T12:00:00Z", " 2026-07-30", "2026-07-30 ", "-000000-01-01", "12345-01-01", "٢٠٢٦-٠٧-٣٠"] {
            XCTAssertEqual(addDays(junk, 1), "", junk)
            XCTAssertNil(daysBetween(junk, "2026-07-01"), junk)
            XCTAssertNil(daysBetween("2026-07-01", junk), junk)
        }
        // Outside 0000–9999 JS writes a signed six-digit year, and the cut at ten characters lands inside it.
        XCTAssertEqual(addDays("9999-12-31", 1), "+010000-01")
        XCTAssertEqual(addDays("0000-01-01", -1), "-000001-12")
        XCTAssertEqual(addDays("2026-01-01", Int.max), "")              // (JS throws a RangeError)
    }

    func testADateThatCannotBeReadLandsInSoonWithNoDayCount() {
        // Only reachable with a record nobody normalised — coerceItem would blank that lastDone.
        let it = Item(name: "x", maintenance: Maintenance(intervalDays: 30, lastDone: "2026-13-01"))
        XCTAssertEqual(maintenanceStatus(it, "2026-07-30"),
                       MaintenanceStatus(scheduled: true, state: "soon", nextDue: "", days: nil,
                                         lastDone: "2026-13-01", neverDone: false, intervalDays: 30))
    }

    func testMaintenanceStatusUsesTheInjectedClockWhenNoDayIsGiven() {
        PackingEnv.freeze(at: "2026-07-30T22:30:00.000Z")
        let s = maintenanceStatus(newItem(name: "x", maintenance: Maintenance(intervalDays: 30, lastDone: "2026-07-20")))
        XCTAssertEqual(s?.nextDue, "2026-08-19")
        XCTAssertEqual(s?.days, 20)
        XCTAssertEqual(s?.json, ["scheduled": true, "state": "ok", "nextDue": "2026-08-19", "days": 20,
                                 "lastDone": "2026-07-20", "neverDone": false, "intervalDays": 30])
    }

    func testTheFirstNAMEDTemplateNamesTheRowButTheFirstTemplateKeepsTheListId() {
        let j = newItem(id: "j", name: "Jacket", maintenance: Maintenance(notes: "x"))
        let rows = maintenanceList([newList(id: "a", name: "", items: [j]), newList(id: "b", name: "Golf", items: [j]),
                                    newList(id: "c", name: "Golf", items: [j])], "2026-07-30")
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.listId, "a")
        XCTAssertEqual(rows.first?.listName, "Golf")
        XCTAssertEqual(rows.first?.listNames, ["Golf"])          // the same name is not said twice
        // Items with NO id are never merged — there is nothing to tell them apart by.
        let blank = Item(id: "", name: "Rope", maintenance: Maintenance(notes: "inspect"))
        XCTAssertEqual(maintenanceList([newList(name: "A", items: [blank]), newList(name: "B", items: [blank])], "2026-07-30").count, 2)
    }

    func testRowsOfOneStateGoSoonestDueFirstThenByName() {
        let list = newList(name: "Gear", items: [
            newItem(name: "Zip", maintenance: Maintenance(intervalDays: 30, lastDone: "2026-01-01")),
            newItem(name: "bike", maintenance: Maintenance(intervalDays: 30, lastDone: "2026-02-01")),
            newItem(name: "Axe", maintenance: Maintenance(intervalDays: 30, lastDone: "2026-02-01")),
            newItem(name: "ref b", maintenance: Maintenance(notes: "x")),
            newItem(name: "Ref a", maintenance: Maintenance(notes: "x")),
        ])
        XCTAssertEqual(maintenanceList([list], "2026-07-30").map { $0.item.name }, ["Zip", "Axe", "bike", "Ref a", "ref b"])
        let byDate = maintenanceByDate([list], "2026-07-30")
        XCTAssertEqual(byDate.map { $0.date }, ["2026-01-31", "2026-03-03"])   // insertion order = urgency order
        XCTAssertEqual(byDate.last?.rows.map { $0.item.name }, ["Axe", "bike"])
    }

    func testLogMaintenanceAnOlderServiceMovesLastDoneBackAndANonDateMeansToday() {
        var it = newItem(name: "Bike", maintenance: Maintenance(intervalDays: 90, lastDone: "2026-07-01",
                                                               log: [MaintenanceLogEntry(date: "2026-07-01", note: "a")]))
        logMaintenance(&it, "2026-03-01")
        XCTAssertEqual(it.maintenance?.json, ["notes": "", "link": "", "intervalDays": 90, "lastDone": "2026-03-01",
                                              "log": [["date": "2026-03-01", "note": ""], ["date": "2026-07-01", "note": "a"]]])
        let back = logMaintenance(&it, "junk", "n", "2026-08-09T10:00:00Z")
        XCTAssertEqual(back, it)
        XCTAssertEqual(it.maintenance?.lastDone, "2026-08-09")
        XCTAssertEqual(it.maintenance?.log.map { $0.date }, ["2026-03-01", "2026-07-01", "2026-08-09"])
        XCTAssertEqual(it.maintenance?.log.last?.note, "n")
    }
}

// JS tests NOT ported as written: none dropped. Two notes on HOW they were ported:
//  • the 'careSections…' tests feed bare `{ status: { state, days } }` rows; here they are
//    `MaintenanceRow(status:)` with a default item — same data, typed — and
//    `careSections(null)` is `careSections(nil)`. A row that is itself null, or has no
//    status (JS steps over it), cannot be written in the typed form.
//  • 'maintenanceByDate…' reads a JS Map (`map.get(date)`, `[...map.keys()]`); here it is
//    the Map's entries in insertion order (`first { $0.date == … }`, `map { $0.date }`).
