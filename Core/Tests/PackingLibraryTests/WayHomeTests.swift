import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// Pack to go home (his idea 13, 2 Oct 2026): what went, plus what was bought there,
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
        _ = lib.addBoughtThere(tripId: trip, name: "Sandals")
        XCTAssertEqual(lib.homeLines(tripId: trip).map(\.name), ["Swimsuit", "Sun cream", "Sandals"], "what was bought there is not on it")
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

    // Their field test (Martin and Anna, 3 Oct 2026): the heading counts what was used
    // up, everything can be ticked at once, a line takes a note, and it opens its thing.

    func testTheWayHomeCountsWhatWasUsedUp() {
        var (lib, trip) = library()
        XCTAssertEqual(lib.homeUsedUp(tripId: trip), 0)
        _ = lib.setUsedUp(true, tripId: trip, entryId: id(lib, "Sun cream"))
        XCTAssertEqual(lib.homeUsedUp(tripId: trip), 1, "the used-up line is not counted")
        XCTAssertTrue(lib.homeProgress(tripId: trip) == (0, 1))
        // A line that never went is not on the way home, so it is not counted either.
        _ = lib.setUsedUp(true, tripId: trip, entryId: id(lib, "Kite"))
        XCTAssertEqual(lib.homeUsedUp(tripId: trip), 1, "a line that never went counts as used up")
        _ = lib.setUsedUp(false, tripId: trip, entryId: id(lib, "Sun cream"))
        XCTAssertEqual(lib.homeUsedUp(tripId: trip), 0, "Undo left it counted")
    }

    func testEverythingIsTickedForTheWayHomeAndClearedAgain() {
        var (lib, trip) = library()
        _ = lib.addBoughtThere(tripId: trip, name: "Sandals")
        _ = lib.setUsedUp(true, tripId: trip, entryId: id(lib, "Sun cream"))
        XCTAssertEqual(lib.setAllPackedHome(true, tripId: trip), 2)
        XCTAssertTrue(lib.homeProgress(tripId: trip) == (2, 2), "not everything still to come home was ticked")
        XCTAssertFalse(Library.isPackedHome(lib.trips[0].entries.first { $0.name == "Sun cream" }!),
                       "a used-up line was ticked for the way home")
        XCTAssertFalse(Library.isPackedHome(lib.trips[0].entries.first { $0.name == "Kite" }!),
                       "a line that never went was ticked for the way home")
        XCTAssertEqual(lib.trips[0].entries.filter(\.checked).count, 4, "the way-out ticks were touched")
        XCTAssertEqual(lib.setAllPackedHome(true, tripId: trip), 0, "ticked twice")
        // Cleared: every home tick goes — also one on a line no longer on the way home.
        _ = lib.setChecked(false, tripId: trip, entryId: id(lib, "Swimsuit"))
        XCTAssertEqual(lib.setAllPackedHome(false, tripId: trip), 2)
        XCTAssertTrue(lib.homeProgress(tripId: trip) == (0, 1), "the ticks were not cleared")
        XCTAssertFalse(lib.trips[0].entries.contains(where: Library.isPackedHome), "a home tick was left behind")
        XCTAssertEqual(lib.setAllPackedHome(true, tripId: "no such trip"), 0)
    }

    func testALineKeepsANoteForTheWayHomeAndTheThingIsUntouched() {
        var (lib, trip) = library()
        let thingBefore = lib.items.first { $0.name == "Swimsuit" }!
        XCTAssertTrue(lib.setHomeNote("  Zip broken  ", tripId: trip, entryId: id(lib, "Swimsuit")))
        XCTAssertEqual(Library.homeNote(lib.trips[0].entries.first { $0.name == "Swimsuit" }!), "Zip broken")
        XCTAssertEqual(lib.items.first { $0.name == "Swimsuit" }!, thingBefore, "the note changed the thing itself")
        // Kept in the stored records.
        let back = Library(records: lib.records())
        XCTAssertEqual(Library.homeNote(back.trips[0].entries.first { $0.name == "Swimsuit" }!), "Zip broken",
                       "the stored records lost the note")
        // An empty note takes it away.
        XCTAssertTrue(lib.setHomeNote(" ", tripId: trip, entryId: id(lib, "Swimsuit")))
        XCTAssertNil(lib.trips[0].entries.first { $0.name == "Swimsuit" }!.extra[HOME_NOTE_KEY], "an empty note was kept")
        XCTAssertFalse(lib.setHomeNote("Wash it", tripId: trip, entryId: "no such line"))
    }

    func testOpenFindsTheThingBehindALine() {
        var (lib, trip) = library()
        let sandals = lib.addBoughtThere(tripId: trip, name: "Sandals")!
        let swimsuit = lib.trips[0].entries.first { $0.name == "Swimsuit" }!
        XCTAssertEqual(lib.thingBehind(swimsuit), lib.items.first { $0.name == "Swimsuit" }!.id)
        XCTAssertNil(lib.thingBehind(sandals), "something bought there has no thing to open")
        _ = lib.deleteThing(id: lib.items.first { $0.name == "Swimsuit" }!.id)
        XCTAssertNil(lib.thingBehind(swimsuit), "a deleted thing is offered to open")
    }
}
