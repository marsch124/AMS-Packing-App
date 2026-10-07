import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// The door check (0.69, his choice "c, a time"): "I leave at" on a trip's first day and,
/// for the way home, on its last; 15 minutes before, what is still unticked — or not in a
/// bag yet.
final class DoorCheckTests: XCTestCase {
    override func setUp() { PackingEnv.freeze(at: "2026-10-01T12:00:00.000Z") }
    override func tearDown() { PackingEnv.reset() }

    private func library(_ names: [String] = ["Passport", "Charger", "Goggles"]) -> (Library, String) {
        var lib = Library()
        lib.saveTemplate(newList(name: "Base", role: "base"))
        let base = lib.templates.first { $0.role == "base" }!.id
        for name in names {
            let t = lib.addThing(name: name)!
            _ = lib.setOnTemplate(itemId: t.id, templateId: base, on: true)
        }
        let trip = lib.createTrip(newEvent(name: "Sun week", startDate: "2026-10-14", endDate: "2026-10-20", destination: "Seaside")).id
        return (lib, trip)
    }

    private func line(_ lib: Library, _ name: String) -> String { lib.trips[0].entries.first { $0.name == name }!.id }

    func testATimeIsKeptAsHoursAndMinutes() {
        XCTAssertEqual(Library.cleanTime("7:30"), "07:30")
        XCTAssertEqual(Library.cleanTime("0730"), "07:30")
        XCTAssertNil(Library.cleanTime("25:00"))
        XCTAssertNil(Library.cleanTime("soon"))
        var (lib, trip) = library()
        XCTAssertTrue(lib.setLeaveTime("7:30", home: false, tripId: trip))
        XCTAssertFalse(lib.setLeaveTime("later", home: true, tripId: trip), "a time that is not one was kept")
        XCTAssertEqual(Library.leaveTime(lib.trips[0], home: false), "07:30")
        XCTAssertEqual(Library.leaveTime(lib.trips[0], home: true), "")
        // Kept in the stored records (synced) and in a backup.
        XCTAssertEqual(Library.leaveTime(Library(records: lib.records()).trips[0], home: false), "07:30")
        let restored = try! Importer.read(lib.backupData(exportedAt: "2026-10-01T12:00:00.000Z")).library
        XCTAssertEqual(Library.leaveTime(restored.trips[0], home: false), "07:30", "a backup lost the time he leaves")
        XCTAssertTrue(lib.setLeaveTime("", home: false, tripId: trip))
        XCTAssertNil(lib.trips[0].extra[LEAVE_AT_KEY], "a time taken away left a key")
    }

    func testFifteenMinutesBeforeHeLeavesTheUntickedAreNamed() {
        var (lib, trip) = library()
        _ = lib.setLeaveTime("07:30", home: false, tripId: trip)
        _ = lib.setChecked(true, tripId: trip, entryId: line(lib, "Charger"))
        let checks = lib.doorChecks(now: "2026-10-07 09:00")
        XCTAssertEqual(checks.count, 1)
        XCTAssertEqual(checks.first?.id, "door-out-\(trip)")
        XCTAssertEqual(checks.first?.day, "2026-10-14")
        XCTAssertEqual(checks.first?.time, "07:15")
        XCTAssertEqual(checks.first?.title, "Leaving for Seaside?")
        XCTAssertEqual(checks.first?.body, "Still unticked: Passport, Goggles")
        // Its moment past: none.
        XCTAssertTrue(lib.doorChecks(now: "2026-10-14 07:15").isEmpty)
        // A line set aside is not coming: not named. Everything ticked: no check at all.
        _ = lib.setAside(true, tripId: trip, entryId: line(lib, "Goggles"))
        XCTAssertEqual(lib.doorChecks(now: "2026-10-07 09:00").first?.body, "Still unticked: Passport")
        _ = lib.setChecked(true, tripId: trip, entryId: line(lib, "Passport"))
        XCTAssertTrue(lib.doorChecks(now: "2026-10-07 09:00").isEmpty, "a check with nothing to say")
    }

    func testFiveNamesThenHowManyMore() {
        var (lib, trip) = library(["A1", "A2", "A3", "A4", "A5", "A6", "A7", "A8"])
        _ = lib.setLeaveTime("10:00", home: false, tripId: trip)
        XCTAssertEqual(lib.doorChecks(now: "2026-10-07 09:00").first?.body, "Still unticked: A1, A2, A3, A4, A5 and 3 more")
    }

    func testJustAfterMidnightTheCheckComesTheDayBefore() {
        XCTAssertTrue(Library.before(day: "2026-10-14", time: "00:10", minutes: 15)! == ("2026-10-13", "23:55"))
    }

    func testTheWayHomeNamesWhatIsNotInABagYet() {
        var (lib, trip) = library()
        _ = lib.setLeaveTime("16:00", home: true, tripId: trip)
        for n in ["Passport", "Charger", "Goggles"] { _ = lib.setChecked(true, tripId: trip, entryId: line(lib, n)) }
        _ = lib.setPackedHome(true, tripId: trip, entryId: line(lib, "Passport"))
        _ = lib.setUsedUp(true, tripId: trip, entryId: line(lib, "Goggles"))
        let checks = lib.doorChecks(now: "2026-10-18 12:00")
        XCTAssertEqual(checks.map(\.kind), [.home], "the way out was checked although everything is ticked")
        XCTAssertEqual(checks.first?.day, "2026-10-20")
        XCTAssertEqual(checks.first?.time, "15:45")
        XCTAssertEqual(checks.first?.title, "Going home from Seaside?")
        XCTAssertEqual(checks.first?.body, "Not in a bag yet: Charger")
        // A reviewed trip, or a deleted one, has none.
        lib.trips[0].reviewedAt = "2026-10-18T10:00:00.000Z"
        XCTAssertTrue(lib.doorChecks(now: "2026-10-18 12:00").isEmpty)
        lib.trips[0].reviewedAt = ""
        _ = lib.deleteTrip(id: trip)
        XCTAssertTrue(lib.doorChecks(now: "2026-10-18 12:00").isEmpty)
    }

    func testNoTimeNoCheck() {
        let (lib, _) = library()
        XCTAssertTrue(lib.doorChecks(now: "2026-10-07 09:00").isEmpty, "a check without a time he leaves")
    }
}
