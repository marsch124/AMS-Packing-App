import XCTest
@testable import PackingCore
@testable import PackingLibrary

final class TripEditsTests: XCTestCase {
    override func setUp() { PackingEnv.freeze() }
    override func tearDown() { PackingEnv.reset() }

    /// His two test trips had no way out (the gap list, 2026-09-26). A deleted trip
    /// takes its lines with it — out of the records too, so no device keeps them —
    /// and leaves every thing, list and other trip as it was.
    func testADeletedTripTakesOnlyItself() {
        var lib = Library()
        lib.saveTemplate({ var l = newList(name: "Hike"); l.items = [newItem(name: "Boots"), newItem(name: "Map")]; return l }())
        var keep = newEvent(name: "Keep me", startDate: "2026-10-01", endDate: "2026-10-02")
        keep.entries = [newItem(name: "Boots")]
        var gone = newEvent(name: "Test trip", startDate: "2026-09-26", endDate: "2026-09-27")
        gone.entries = [newItem(name: "Map"), newItem(name: "Towel")]
        lib.trips = [keep, gone]
        let things = lib.items.count, lists = lib.templates.count, rows = lib.memberships.count
        let lines = lib.records().filter { $0.table == .entries }.count

        XCTAssertTrue(lib.deleteTrip(id: gone.id))
        XCTAssertEqual(lib.trips.map(\.name), ["Keep me"], "only the chosen trip goes")
        XCTAssertEqual(lib.records().filter { $0.table == .entries }.count, lines - 2, "its lines leave the records")
        XCTAssertEqual(lib.items.count, things, "no thing is touched")
        XCTAssertEqual(lib.templates.count, lists, "no list is touched")
        XCTAssertEqual(lib.memberships.count, rows)
        XCTAssertFalse(lib.deleteTrip(id: gone.id), "a trip that is not there: false")
    }
}
