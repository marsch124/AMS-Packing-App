import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// His decision on test I.7 (1 Oct 2026): a change to a thing reaches the trips
/// still ahead — only on lines not ticked, not typed by hand, not changed on the
/// trip — and never a trip that is over or reviewed.
final class ThingFollowsTests: XCTestCase {
    override func setUp() { PackingEnv.freeze(at: "2026-10-01T09:00:00.000Z") }   // "today" for ahead / over
    override func tearDown() { PackingEnv.reset() }

    private func library() -> (Library, String) {
        var lib = Library()
        var hiking = newList(name: "Hiking", group: "GA")
        var lamp = newItem(name: "Headlamp"); lamp.container = "Day pack"; lamp.weight = 60
        hiking.items = [lamp, newItem(name: "Map")]
        lib.saveTemplate(hiking)
        let id = lib.items.first { $0.name == "Headlamp" }?.id ?? ""
        func trip(_ name: String, _ from: String, _ to: String) -> TripEvent {
            var t = newEvent(name: name, startDate: from, endDate: to)
            t.activities = [lib.templates[0].id]
            return lib.createTrip(t)
        }
        _ = trip("ahead", "2026-10-10", "2026-10-12")
        _ = trip("ticked", "2026-10-10", "2026-10-12")
        _ = trip("over", "2026-09-01", "2026-09-03")
        _ = trip("reviewed", "2026-10-10", "2026-10-12")
        _ = trip("someday", "", "")
        // On "ticked" the Headlamp is packed; "reviewed" is done.
        let t1 = lib.trips.firstIndex { $0.name == "ticked" }!
        let lampLine = lib.trips[t1].entries.firstIndex { $0.sourceItemId == id }!
        lib.trips[t1].entries[lampLine].checked = true
        let t3 = lib.trips.firstIndex { $0.name == "reviewed" }!
        lib.trips[t3].status = "done"
        return (lib, id)
    }
    private func lampLine(_ lib: Library, _ trip: String, _ id: String) -> Item? {
        lib.trips.first { $0.name == trip }?.entries.first { $0.sourceItemId == id }
    }

    func testAChangeToAThingReachesOnlyWhatIsStillUndecided() {
        var (lib, id) = library()
        let before = lampLine(lib, "ahead", id)
        XCTAssertEqual(before?.container, "Day pack")
        XCTAssertTrue(lib.updateThing(id: id) { $0.container = "Duffel bag"; $0.weight = 777; $0.storage = "Garage" })

        let ahead = lampLine(lib, "ahead", id)
        XCTAssertEqual(ahead?.container, "Duffel bag", "an unpacked line on a trip ahead did not follow")
        XCTAssertEqual(ahead?.weight, 777)
        XCTAssertEqual(ahead?.storage, "Garage")
        XCTAssertEqual(ahead?.id, before?.id, "the line lost its id")
        XCTAssertEqual(lampLine(lib, "someday", id)?.container, "Duffel bag", "a trip with no dates is still ahead")

        XCTAssertEqual(lampLine(lib, "ticked", id)?.container, "Day pack", "a TICKED line changed")
        XCTAssertEqual(lampLine(lib, "over", id)?.container, "Day pack", "a trip that is OVER changed")
        XCTAssertEqual(lampLine(lib, "reviewed", id)?.container, "Day pack", "a REVIEWED trip changed")
        XCTAssertEqual(lib.trips.first { $0.name == "ahead" }?.entries.count, 2, "lines were added or lost")
    }

    func testARenameAndAnEditedOrSetAsideLineAreHandledRightly() {
        var (lib, id) = library()
        let t = lib.trips.firstIndex { $0.name == "ahead" }!
        let n = lib.trips[t].entries.firstIndex { $0.sourceItemId == id }!
        lib.trips[t].entries[n].skipped = true                     // set aside: still follows, stays aside
        XCTAssertTrue(lib.renameThing(id: id, to: "Head torch"))
        XCTAssertEqual(lampLine(lib, "ahead", id)?.name, "Head torch", "a rename did not reach the trip ahead")
        XCTAssertEqual(lampLine(lib, "ahead", id)?.skipped, true, "set aside was lost")

        lib.trips[t].entries[n].edited = true                      // changed on the trip itself (the web app marks it)
        _ = lib.updateThing(id: id) { $0.container = "Duffel bag" }
        XCTAssertEqual(lampLine(lib, "ahead", id)?.container, "Day pack", "a line changed on the trip was overwritten")
    }

    func testABagChosenForOneTemplateStillWins() {
        var (lib, id) = library()
        // The template says: on Hiking the Headlamp goes in the Hip belt.
        var hiking = lib.resolvedTemplate(id: lib.templates[0].id)!
        let r = hiking.items.firstIndex { $0.name == "Headlamp" }!
        hiking.items[r].ovContainer = "Hip belt"
        lib.saveTemplate(hiking)
        _ = lib.updateThing(id: id) { $0.container = "Duffel bag"; $0.weight = 90 }
        let line = lampLine(lib, "ahead", id)
        XCTAssertEqual(line?.container, "Hip belt", "the template's own bag lost to the thing's")
        XCTAssertEqual(line?.weight, 90, "the weight did not follow")
    }

    /// "Still ahead" goes by the day where he is (the spec pass, 5 Oct 2026): just
    /// after midnight in Sweden the UTC date is still yesterday, and a trip that ended
    /// yesterday took a change to its thing.
    func testStillAheadGoesByTheDayWhereHeIs() {
        let zone = TimeZone(secondsFromGMT: 2 * 3600)!                                    // two hours ahead of UTC
        let justAfterMidnight = ISO8601DateFormatter().date(from: "2026-10-05T22:30:00Z")!   // 00:30 on the 6th there
        XCTAssertEqual(Library.localToday(justAfterMidnight, zone: zone), "2026-10-06")
        XCTAssertEqual(Library.localToday(justAfterMidnight, zone: TimeZone(identifier: "UTC")!), "2026-10-05")

        let saved = Library.dayZone
        defer { Library.dayZone = saved }
        Library.dayZone = { zone }
        PackingEnv.now = { justAfterMidnight }
        var lib = Library()
        var hiking = newList(name: "Hiking", group: "GA")
        hiking.items = [newItem(name: "Headlamp")]
        lib.saveTemplate(hiking)
        var t = newEvent(name: "Ended yesterday", startDate: "2026-10-03", endDate: "2026-10-05")
        t.activities = [lib.templates[0].id]
        _ = lib.createTrip(t)
        let lamp = lib.items.first { $0.name == "Headlamp" }!.id
        _ = lib.updateThing(id: lamp) { $0.container = "Duffel bag" }
        XCTAssertNotEqual(lib.trips[0].entries.first { $0.sourceItemId == lamp }?.container, "Duffel bag",
                          "a trip that ended yesterday (where he is) still took the change")
        // The same moment, a trip ending TODAY there is still ahead and follows.
        lib.trips[0].endDate = "2026-10-06"
        _ = lib.updateThing(id: lamp) { $0.container = "Day pack" }
        XCTAssertEqual(lib.trips[0].entries.first { $0.sourceItemId == lamp }?.container, "Day pack",
                       "a trip ending today (where he is) did not take the change")
    }

    /// A line's own marks stay when its thing changes (the spec pass, 5 Oct 2026): a
    /// way-home tick, used up and a maintenance note on a line that was ticked and then
    /// unticked were wiped by the next change to the thing.
    func testALineKeepsItsOwnMarksWhenItsThingChanges() {
        var (lib, id) = library()
        let t = lib.trips.firstIndex { $0.name == "ahead" }!
        let n = lib.trips[t].entries.firstIndex { $0.sourceItemId == id }!
        lib.trips[t].entries[n].extra[HOME_KEY] = .bool(true)
        lib.trips[t].entries[n].extra[USED_UP_KEY] = .bool(true)
        lib.trips[t].entries[n].extra[HOME_NOTE_KEY] = .string("Strap loose")
        XCTAssertTrue(lib.updateThing(id: id) { $0.weight = 75 })
        let line = lampLine(lib, "ahead", id)!
        XCTAssertEqual(line.weight, 75, "the change did not reach the trip still ahead")
        XCTAssertTrue(Library.isPackedHome(line), "the way-home tick was wiped")
        XCTAssertTrue(Library.isUsedUp(line), "used up was wiped")
        XCTAssertEqual(Library.homeNote(line), "Strap loose", "the maintenance note was wiped")
    }
}
