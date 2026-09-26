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

final class SetPlaceTests: XCTestCase {
    override func setUp() { PackingEnv.freeze() }
    override func tearDown() { PackingEnv.reset() }

    /// His ask (2026-09-26): a place set from the trip's "No place set" goes onto
    /// the THING and onto every line of it on this trip (a thing on two lists sits
    /// on the trip twice); a typed line changes alone; a new place joins his list.
    func testAPlaceSetOnTheTripReachesTheThingAndItsTwin() {
        var lib = Library()
        // Different bags on the two lists — as his Underwear (Checked luggage / RV box).
        lib.saveTemplate({ var l = newList(name: "Run"); l.items = [newItem(name: "Socks", container: "Duffel bag"), newItem(name: "Cap")]; return l }())
        lib.saveTemplate({ var l = newList(name: "Swim"); l.items = [newItem(name: "Socks", container: "Swim bag")]; return l }())
        var draft = newEvent(name: "Weekend", startDate: "2026-10-03", endDate: "2026-10-04")
        draft.activities = lib.templates.map(\.id)
        draft.mode = "quick"
        let trip = lib.createTrip(draft)
        let custom = lib.addCustomLine(tripId: trip.id, name: "Tripod")!
        let socks = lib.trips[0].entries.filter { $0.name == "Socks" }
        XCTAssertEqual(socks.count, 2, "the same thing, on the trip from two lists")

        XCTAssertTrue(lib.setPlace(" Hall shelf ", tripId: trip.id, entryId: socks[0].id))
        let lines = lib.trips[0].entries
        XCTAssertEqual(lines.filter { $0.name == "Socks" }.map(\.storage), ["Hall shelf", "Hall shelf"], "both lines of the thing")
        XCTAssertEqual(lib.items.first { $0.name == "Socks" }?.storage, "Hall shelf", "the thing itself, for every later trip")
        XCTAssertEqual(lines.first { $0.name == "Cap" }?.storage, "", "another thing is not touched")
        XCTAssertTrue(lib.storagePlaces().contains("Hall shelf"), "a new place joins his list")

        XCTAssertTrue(lib.setPlace("Garage", tripId: trip.id, entryId: custom.id))
        XCTAssertEqual(lib.trips[0].entries.first { $0.id == custom.id }?.storage, "Garage", "a typed line gets its place")
        XCTAssertFalse(lib.setPlace("  ", tripId: trip.id, entryId: custom.id), "an empty place is refused")
    }
}
