import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// On site (their field test, 3 Oct 2026, mission 9.1): Bought on site · Left on site ·
/// Maintenance notes · Pack to go home — and a note made there lands on the thing too.
final class OnSiteTests: XCTestCase {
    override func setUp() { PackingEnv.freeze(at: "2026-10-03T12:00:00.000Z") }
    override func tearDown() { PackingEnv.reset() }

    /// A trip of three lines, two of them packed on the way out.
    private func library(start: String = "2026-10-02", end: String = "2026-10-06") -> (Library, String) {
        var lib = Library()
        lib.saveTemplate(newList(name: "Base", role: "base"))
        let base = lib.templates.first { $0.role == "base" }!.id
        for name in ["Tent", "Sun cream", "Kite"] {
            let t = lib.addThing(name: name)!
            _ = lib.setOnTemplate(itemId: t.id, templateId: base, on: true)
        }
        let trip = lib.createTrip(newEvent(name: "Away", startDate: start, endDate: end)).id
        _ = lib.setChecked(true, tripId: trip, entryId: id(lib, "Tent"))
        _ = lib.setChecked(true, tripId: trip, entryId: id(lib, "Sun cream"))
        return (lib, trip)
    }

    private func id(_ lib: Library, _ name: String) -> String { lib.trips[0].entries.first { $0.name == name }!.id }
    private func thing(_ lib: Library, _ name: String) -> Item { lib.items.first { $0.name == name }! }

    /// Its door shows once the first day has come — or, on a trip without dates, once
    /// something was bought on site. The door and the loop strip agree (the spec pass,
    /// 5 Oct 2026: a dated trip ahead with a bought line showed the door at Pack).
    func testOnSiteBeginsOnTheFirstDayOrWithSomethingBought() {
        var (lib, trip) = library(start: "2026-10-10", end: "2026-10-12")
        XCTAssertFalse(lib.onSiteBegun(tripId: trip, today: "2026-10-03"), "a trip a week ahead has begun")
        XCTAssertTrue(lib.onSiteBegun(tripId: trip, today: "2026-10-10"), "its first day has not begun it")
        XCTAssertTrue(lib.onSiteBegun(tripId: trip, today: "2026-10-20"), "after the trip the door went")
        _ = lib.addBoughtOnSite(tripId: trip, name: "Sandals")
        XCTAssertFalse(lib.onSiteBegun(tripId: trip, today: "2026-10-03"), "a dated trip ahead goes by its dates, not by a bought line")
        XCTAssertEqual(lib.loopStep(tripId: trip, today: "2026-10-03"), .pack, "the loop says Pack — the door must agree")
        // Without dates, something bought on site is the sign it has begun — for both.
        lib.trips[0].startDate = ""; lib.trips[0].endDate = ""
        XCTAssertTrue(lib.onSiteBegun(tripId: trip, today: "2026-10-03"), "something bought on site, and no door")
        XCTAssertEqual(lib.loopStep(tripId: trip, today: "2026-10-03"), .onSite)
        XCTAssertFalse(lib.onSiteBegun(tripId: "no such trip", today: "2026-10-03"))
    }

    /// The door's one line: only what there is, the way home always.
    func testTheDoorSaysWhatOnSiteHolds() {
        var (lib, trip) = library()
        XCTAssertEqual(lib.onSiteSummary(tripId: trip), "home 0/2")
        _ = lib.addBoughtOnSite(tripId: trip, name: "Sandals")
        _ = lib.addBoughtOnSite(tripId: trip, name: "Sun hat")
        _ = lib.setUsedUp(true, tripId: trip, entryId: id(lib, "Sun cream"))
        _ = lib.noteOnSite("Zip broken", tripId: trip, entryId: id(lib, "Tent"), today: "2026-10-03")
        _ = lib.setPackedHome(true, tripId: trip, entryId: id(lib, "Tent"))
        XCTAssertEqual(lib.onSiteSummary(tripId: trip), "2 bought \u{00B7} 1 left \u{00B7} 1 note \u{00B7} home 1/3")
        XCTAssertEqual(lib.leftOnSite(tripId: trip).map(\.name), ["Sun cream"])
        XCTAssertEqual(lib.onSiteNotes(tripId: trip).map(\.name), ["Tent"])
        _ = lib.noteOnSite("Wash before next trip", tripId: trip, entryId: id(lib, "Sandals"), today: "2026-10-03")
        XCTAssertTrue(lib.onSiteSummary(tripId: trip).contains("2 notes"), lib.onSiteSummary(tripId: trip))
        // Undo: no longer left on site.
        _ = lib.setUsedUp(false, tripId: trip, entryId: id(lib, "Sun cream"))
        XCTAssertEqual(lib.leftOnSite(tripId: trip).map(\.name), [])
        XCTAssertFalse(lib.onSiteSummary(tripId: trip).contains("left"), lib.onSiteSummary(tripId: trip))
    }

    /// A note made on site stays on the trip's line AND lands on the thing, dated, once.
    func testANoteMadeOnSiteLandsOnTheThingToo() {
        var (lib, trip) = library()
        let tent = id(lib, "Tent")
        XCTAssertTrue(lib.noteOnSite("  Zip broken ", tripId: trip, entryId: tent, today: "2026-10-03"))
        XCTAssertEqual(Library.homeNote(lib.trips[0].entries.first { $0.id == tent }!), "Zip broken", "the trip's line lost the note")
        XCTAssertEqual(thing(lib, "Tent").note, "On site 3 Oct 2026: Zip broken", "the note did not land on the thing")
        // The same words again — saved twice, or on another day — are not written twice.
        _ = lib.noteOnSite("Zip broken", tripId: trip, entryId: tent, today: "2026-10-03")
        _ = lib.noteOnSite("zip broken", tripId: trip, entryId: tent, today: "2026-10-04")
        XCTAssertEqual(thing(lib, "Tent").note, "On site 3 Oct 2026: Zip broken", "the same note landed twice")
        // A new note is one more line, under what was there.
        _ = lib.noteOnSite("Wash before next trip", tripId: trip, entryId: tent, today: "2026-10-05")
        XCTAssertEqual(thing(lib, "Tent").note, "On site 3 Oct 2026: Zip broken\nOn site 5 Oct 2026: Wash before next trip")
        XCTAssertEqual(Library.homeNote(lib.trips[0].entries.first { $0.id == tent }!), "Wash before next trip")
        // The other things are untouched.
        XCTAssertEqual(thing(lib, "Sun cream").note, "")
        // Kept in the stored records.
        let back = Library(records: lib.records())
        XCTAssertEqual(back.items.first { $0.name == "Tent" }?.note, thing(lib, "Tent").note, "the stored records lost the thing's note")
    }

    /// His own words on the thing stay, and are not repeated.
    func testANoteJoinsWhatTheThingAlreadySays() {
        var (lib, trip) = library()
        let t = thing(lib, "Sun cream").id
        _ = lib.updateThing(id: t) { $0.note = "Factor 50" }
        _ = lib.noteOnSite("Nearly empty", tripId: trip, entryId: id(lib, "Sun cream"), today: "2026-10-03")
        XCTAssertEqual(thing(lib, "Sun cream").note, "Factor 50\nOn site 3 Oct 2026: Nearly empty")
        _ = lib.noteOnSite("Factor 50", tripId: trip, entryId: id(lib, "Sun cream"), today: "2026-10-03")
        XCTAssertEqual(thing(lib, "Sun cream").note, "Factor 50\nOn site 3 Oct 2026: Nearly empty", "his own words were written again")
    }

    /// Something bought on site has no thing behind it: the note stays on the trip's line only.
    /// An empty note clears the line's note; what reached the thing stays.
    func testANoteWithNoThingBehindStaysOnTheTrip() {
        var (lib, trip) = library()
        let sandals = lib.addBoughtOnSite(tripId: trip, name: "Sandals")!.id
        let before = lib.items
        XCTAssertTrue(lib.noteOnSite("Strap loose", tripId: trip, entryId: sandals, today: "2026-10-03"))
        XCTAssertEqual(Library.homeNote(lib.trips[0].entries.first { $0.id == sandals }!), "Strap loose")
        XCTAssertEqual(lib.items, before, "a thing changed for a line with no thing behind it")
        // Cleared on the trip: the thing keeps what it was given.
        let tent = id(lib, "Tent")
        _ = lib.noteOnSite("Zip broken", tripId: trip, entryId: tent, today: "2026-10-03")
        _ = lib.noteOnSite("", tripId: trip, entryId: tent, today: "2026-10-03")
        XCTAssertEqual(Library.homeNote(lib.trips[0].entries.first { $0.id == tent }!), "", "the empty note did not clear the line")
        XCTAssertEqual(thing(lib, "Tent").note, "On site 3 Oct 2026: Zip broken")
        XCTAssertFalse(lib.noteOnSite("Zip broken", tripId: trip, entryId: "no such line", today: "2026-10-03"))
    }

    func testTheNoteLineSaysTheDay() {
        XCTAssertEqual(Library.onSiteNoteLine("Zip broken", today: "2026-10-03"), "On site 3 Oct 2026: Zip broken")
        XCTAssertEqual(Library.onSiteNoteLine("Zip broken", today: "2027-01-31"), "On site 31 Jan 2027: Zip broken")
        XCTAssertEqual(Library.onSiteNoteLine("Zip broken", today: ""), "On site: Zip broken")
    }
}
