import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// Unpack (his idea 1, 12 Nov 2026): back home, tick each thing back into its room.
final class UnpackTests: XCTestCase {
    override func setUp() { PackingEnv.freeze(at: "2026-11-12T12:00:00.000Z") }
    override func tearDown() { PackingEnv.reset() }

    /// A trip of four lines: two ticked, one ticked then set aside, one never ticked.
    private func library(start: String = "2026-11-01", end: String = "2026-11-10") -> (Library, String) {
        var lib = Library()
        lib.saveTemplate(newList(name: "Base", role: "base"))
        let base = lib.templates.first { $0.role == "base" }!.id
        for name in ["Swimsuit", "Sun cream", "Umbrella", "Kite"] {
            let t = lib.addThing(name: name)!
            _ = lib.setOnTemplate(itemId: t.id, templateId: base, on: true)
        }
        let trip = lib.createTrip(newEvent(name: "Away", startDate: start, endDate: end, destination: "Torremolinos")).id
        _ = lib.setChecked(true, tripId: trip, entryId: id(lib, "Swimsuit"))
        _ = lib.setChecked(true, tripId: trip, entryId: id(lib, "Sun cream"))
        _ = lib.setChecked(true, tripId: trip, entryId: id(lib, "Umbrella"))
        _ = lib.setAside(true, tripId: trip, entryId: id(lib, "Umbrella"))
        return (lib, trip)
    }

    private func id(_ lib: Library, _ name: String) -> String { lib.trips[0].entries.first { $0.name == name }!.id }
    private func thing(_ lib: Library, _ name: String) -> String { lib.items.first { $0.name == name }!.id }

    func testUnpackIsWhatWentAndWhatWasBoughtLessUsedUp() {
        var (lib, trip) = library()
        XCTAssertEqual(lib.unpackLines(tripId: trip).map(\.name), ["Swimsuit", "Sun cream"])
        _ = lib.addBoughtOnSite(tripId: trip, name: "Sandals")
        XCTAssertEqual(lib.unpackLines(tripId: trip).map(\.name), ["Swimsuit", "Sun cream", "Sandals"])
        _ = lib.setUsedUp(true, tripId: trip, entryId: id(lib, "Sun cream"))
        XCTAssertEqual(lib.unpackLines(tripId: trip).map(\.name), ["Swimsuit", "Sandals"])
    }

    func testUnpackIsGroupedByRoomWithNoRoomLastAndShowsTheSpot() {
        var (lib, trip) = library()
        _ = lib.updateThing(id: thing(lib, "Swimsuit")) { $0.storage = "Kitchen" }
        _ = lib.updateThing(id: thing(lib, "Swimsuit")) { $0.extra[SPOT_KEY] = .string("top shelf") }
        let groups = lib.unpackGroups(tripId: trip)
        XCTAssertEqual(groups.map(\.room), ["Kitchen", UNPACK_NO_ROOM])
        XCTAssertEqual(groups[0].lines.map(\.name), ["Swimsuit"])
        XCTAssertEqual(groups[1].lines.map(\.name), ["Sun cream"])
        XCTAssertEqual(lib.unpackSpot(groups[0].lines[0]), "top shelf")
        XCTAssertEqual(lib.unpackSpot(groups[1].lines[0]), "")
    }

    func testARoomIsTickedAtOnceAndProgressCounts() {
        var (lib, trip) = library()
        _ = lib.updateThing(id: thing(lib, "Swimsuit")) { $0.storage = "Kitchen" }
        _ = lib.updateThing(id: thing(lib, "Sun cream")) { $0.storage = "Kitchen" }
        XCTAssertTrue(lib.unpackProgress(tripId: trip) == (0, 2))
        XCTAssertEqual(lib.setRoomUnpacked(room: "Kitchen", tripId: trip), 2)
        XCTAssertTrue(lib.unpackProgress(tripId: trip) == (2, 2))
        XCTAssertEqual(lib.setRoomUnpacked(room: "Kitchen", tripId: trip), 0, "already back")
    }

    func testGivingARoomToSomethingBoughtOnSiteMakesAThing() {
        var (lib, trip) = library()
        _ = lib.addBoughtOnSite(tripId: trip, name: "Sandals")
        let line = lib.trips[0].entries.first { $0.name == "Sandals" }!.id
        let made = lib.giveRoom("Hall", tripId: trip, entryId: line)
        XCTAssertNotNil(made)
        XCTAssertEqual(lib.items.first { $0.id == made }?.storage, "Hall")
        let l = lib.trips[0].entries.first { $0.id == line }!
        XCTAssertEqual(lib.thingBehind(l), made)
        XCTAssertEqual(lib.unpackRoom(l), "Hall")
    }

    func testHomeRemindsOnlyWhileThingsAreLeftAndForAMonth() {
        var (lib, trip) = library()
        XCTAssertNil(lib.unpackNudge(today: "2026-11-10"), "not before the last day is over")
        let n = lib.unpackNudge(today: "2026-11-11")
        XCTAssertEqual(n?.left, 2)
        XCTAssertEqual(n?.name, "Torremolinos")
        XCTAssertEqual(n?.tripId, trip)
        XCTAssertNil(lib.unpackNudge(today: "2026-12-11"), "more than 30 days after")
        XCTAssertNotNil(lib.unpackNudge(today: "2026-12-10"))
        lib.setUnpackDone(true, tripId: trip)
        XCTAssertNil(lib.unpackNudge(today: "2026-11-11"), "closed with Done")
        lib.setUnpackDone(false, tripId: trip)
        _ = lib.setRoomUnpacked(room: UNPACK_NO_ROOM, tripId: trip)
        XCTAssertNil(lib.unpackNudge(today: "2026-11-11"), "everything is back")
    }

    func testABagShowsWhatIsInItOnTheTripUnderWayElseTheNextOne() {
        var (lib, _) = library(start: "2026-11-01", end: "2026-12-31")
        XCTAssertNil(lib.bagNow(name: "Duffel", today: "2026-11-05"), "nothing in it")
        lib.trips[0].entries[lib.trips[0].entries.firstIndex { $0.name == "Swimsuit" }!].container = "Duffel"
        lib.trips[0].entries[lib.trips[0].entries.firstIndex { $0.name == "Kite" }!].container = "Duffel"   // not ticked
        lib.trips[0].entries[lib.trips[0].entries.firstIndex { $0.name == "Umbrella" }!].container = "Duffel" // set aside
        let now = lib.bagNow(name: "duffel", today: "2026-11-05")
        XCTAssertEqual(now?.lines.map(\.name), ["Swimsuit"])
        XCTAssertEqual(now?.tripName, "Away")
        // Before the trip sets off it is the next trip.
        XCTAssertEqual(lib.bagNow(name: "Duffel", today: "2026-10-20")?.lines.map(\.name), ["Swimsuit"])
        XCTAssertNil(lib.bagNow(name: "Duffel", today: "2027-01-05"), "the trip is over")
    }
}
