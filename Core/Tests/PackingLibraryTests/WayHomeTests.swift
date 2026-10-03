import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// Pack to go home (his idea 13, 2 Oct 2026): what went, plus what was bought on site,
/// less what was used up — with ticks of its own.
final class WayHomeTests: XCTestCase {
    override func setUp() { PackingEnv.freeze(at: "2026-10-01T12:00:00.000Z") }
    override func tearDown() { PackingEnv.reset() }

    /// A trip of four lines: two packed on the way out, one ticked and then set aside, one never ticked.
    private func library() -> (Library, String) {
        var lib = Library()
        lib.saveTemplate(newList(name: "Base", role: "base"))
        let base = lib.templates.first { $0.role == "base" }!.id
        for name in ["Swimsuit", "Sun cream", "Umbrella", "Kite"] {
            let t = lib.addThing(name: name)!
            _ = lib.setOnTemplate(itemId: t.id, templateId: base, on: true)
        }
        let trip = lib.createTrip(newEvent(name: "Away", startDate: "2026-11-01", endDate: "2026-12-31")).id
        func line(_ name: String) -> String { lib.trips[0].entries.first { $0.name == name }!.id }
        _ = lib.setChecked(true, tripId: trip, entryId: line("Swimsuit"))
        _ = lib.setChecked(true, tripId: trip, entryId: line("Sun cream"))
        // Ticked, then set aside after all: it did not go.
        _ = lib.setChecked(true, tripId: trip, entryId: line("Umbrella"))
        _ = lib.setAside(true, tripId: trip, entryId: line("Umbrella"))
        return (lib, trip)
    }

    private func id(_ lib: Library, _ name: String) -> String { lib.trips[0].entries.first { $0.name == name }!.id }

    func testTheWayHomeIsWhatWentAndWhatWasBought() {
        var (lib, trip) = library()
        XCTAssertEqual(lib.homeLines(tripId: trip).map(\.name), ["Swimsuit", "Sun cream"],
                       "not what went: set aside and never-packed lines do not come home")
        _ = lib.addBoughtOnSite(tripId: trip, name: "Sandals")
        XCTAssertEqual(lib.homeLines(tripId: trip).map(\.name), ["Swimsuit", "Sun cream", "Sandals"], "what was bought on site is not on it")
        XCTAssertTrue(lib.homeProgress(tripId: trip) == (0, 3))
    }

    func testTheWayHomeHasTicksOfItsOwnAndUsedUpGoesOff() {
        var (lib, trip) = library()
        XCTAssertTrue(lib.setPackedHome(true, tripId: trip, entryId: id(lib, "Swimsuit")))
        XCTAssertTrue(lib.homeProgress(tripId: trip) == (1, 2))
        XCTAssertEqual(lib.trips[0].entries.first { $0.name == "Swimsuit" }?.checked, true, "the way-out tick was touched")
        // The sun cream is used up: off the way home, nothing to pack.
        XCTAssertTrue(lib.setUsedUp(true, tripId: trip, entryId: id(lib, "Sun cream")))
        XCTAssertTrue(lib.homeProgress(tripId: trip) == (1, 1), "used up still counts for the way home")
        // Packed, then used up after all: the home tick goes with it.
        _ = lib.setUsedUp(false, tripId: trip, entryId: id(lib, "Sun cream"))
        _ = lib.setPackedHome(true, tripId: trip, entryId: id(lib, "Sun cream"))
        _ = lib.setUsedUp(true, tripId: trip, entryId: id(lib, "Sun cream"))
        XCTAssertFalse(Library.isPackedHome(lib.trips[0].entries.first { $0.name == "Sun cream" }!), "used up yet packed home")
        // Kept in the stored records.
        let back = Library(records: lib.records())
        XCTAssertTrue(back.homeProgress(tripId: trip) == (1, 1), "the stored records lost the way home")
        XCTAssertFalse(lib.setPackedHome(true, tripId: trip, entryId: "no such line"))
    }
}
