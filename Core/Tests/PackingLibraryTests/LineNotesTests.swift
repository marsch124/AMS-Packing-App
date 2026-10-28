import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// A trip line's Show note (0.104, his ask of 28 Oct 2026: "a way to see the notes for an item" while
/// packing, without ticking it): everything written about the line's thing, each under its label.
final class LineNotesTests: XCTestCase {
    override func setUp() { PackingEnv.freeze(at: "2026-10-01T12:00:00.000Z") }
    override func tearDown() { PackingEnv.reset() }

    /// Three things on the Base template; the Map's row there keeps a note BEFORE the trip is built,
    /// so the Map's line carries the same words.
    private func library() -> (Library, String) {
        var lib = Library()
        lib.saveTemplate(newList(name: "Base", role: "base"))
        let base = lib.templates.first { $0.role == "base" }!.id
        for name in ["Headlamp", "Map", "Kite"] {
            let t = lib.addThing(name: name)!
            _ = lib.setOnTemplate(itemId: t.id, templateId: base, on: true)
        }
        let map = thing(lib, "Map")
        let m = lib.memberships.firstIndex { $0.templateId == base && $0.itemId == map }!
        lib.memberships[m].note = "The waterproof one"
        let trip = lib.createTrip(newEvent(name: "Away", startDate: "2026-11-01", endDate: "2026-11-05")).id
        return (lib, trip)
    }

    private func thing(_ lib: Library, _ name: String) -> String { lib.items.first { $0.name == name }!.id }
    private func line(_ lib: Library, _ name: String) -> String { lib.trips[0].entries.first { $0.name == name }!.id }

    func testEverythingWrittenAboutTheThingIsGatheredInOrder() {
        var (lib, trip) = library()
        let n = lib.items.firstIndex { $0.name == "Headlamp" }!
        lib.items[n].note = "  Spare batteries in the lid "
        lib.items[n].swedish = "Pannlampa"
        let base = lib.templates.first { $0.role == "base" }!.id
        let m = lib.memberships.firstIndex { $0.templateId == base && $0.itemId == lib.items[n].id }!
        lib.memberships[m].note = "The red light for the tent"
        _ = lib.setHomeNote("strap torn", tripId: trip, entryId: line(lib, "Headlamp"))
        let notes = lib.lineNotes(tripId: trip, entryId: line(lib, "Headlamp"))
        XCTAssertEqual(notes.map(\.kind), [.swedish, .thing, .template, .home])
        XCTAssertEqual(notes.map(\.label), ["In Swedish", "Note", "Note on the Base template", "Note for the way home"])
        XCTAssertEqual(notes.map(\.text), ["Pannlampa", "Spare batteries in the lid", "The red light for the tent", "strap torn"])
        XCTAssertEqual(Library.lineNotesTip(notes),
                       "In Swedish: Pannlampa\nNote: Spare batteries in the lid\nNote on the Base template: The red light for the tent\nNote for the way home: strap torn")
    }

    /// The Map's line carries its row's note: said once, as the template's.
    func testTheLinesOwnNoteIsNotSaidTwice() {
        let (lib, trip) = library()
        XCTAssertEqual(lib.trips[0].entries.first { $0.name == "Map" }?.note, "The waterproof one", "the line does not carry its row's note")
        XCTAssertEqual(lib.lineNotes(tripId: trip, entryId: line(lib, "Map")),
                       [LineNote(kind: .template, label: "Note on the Base template", text: "The waterproof one")])
    }

    /// A note the line carries that nothing else says any more (a line sent by someone, or the row's
    /// note changed after it was packed) is the line's own; nothing written at all = nothing.
    func testALineKeepsWhatOnlyItSays() {
        var (lib, trip) = library()
        let base = lib.templates.first { $0.role == "base" }!.id
        let m = lib.memberships.firstIndex { $0.templateId == base && $0.itemId == thing(lib, "Map") }!
        lib.memberships[m].note = ""
        XCTAssertEqual(lib.lineNotes(tripId: trip, entryId: line(lib, "Map")),
                       [LineNote(kind: .line, label: "Note on this trip", text: "The waterproof one")])
        XCTAssertEqual(lib.lineNotes(tripId: trip, entryId: line(lib, "Kite")), [], "a line with nothing written about it")
    }

    /// A line typed on the trip has no thing behind it: only its own words — even with a thing of that
    /// name (what Open thing opens is the thing the line was built from, as the way home's Open).
    func testALineTypedOnTheTripHasOnlyItsOwnWords() {
        var (lib, trip) = library()
        let n = lib.items.firstIndex { $0.name == "Kite" }!
        lib.items[n].note = "Two lines"
        let typed = lib.addCustomLine(tripId: trip, name: "Tripod")!
        XCTAssertEqual(lib.lineNotes(tripId: trip, entryId: typed.id), [])
        XCTAssertNil(lib.thingBehind(typed))
        _ = lib.setHomeNote("one leg loose", tripId: trip, entryId: typed.id)
        XCTAssertEqual(lib.lineNotes(tripId: trip, entryId: typed.id).map(\.text), ["one leg loose"])
    }

    /// A Swedish name that is the name itself says nothing new; the line's own Swedish name is read
    /// when the thing has none.
    func testASwedishNameIsSaidOnlyWhenItIsAnotherWord() {
        var (lib, trip) = library()
        let n = lib.items.firstIndex { $0.name == "Kite" }!
        lib.items[n].swedish = "kite "
        XCTAssertEqual(lib.lineNotes(tripId: trip, entryId: line(lib, "Kite")), [])
        lib.items[n].swedish = ""
        let k = lib.trips[0].entries.firstIndex { $0.name == "Kite" }!
        lib.trips[0].entries[k].swedish = "Drake"
        XCTAssertEqual(lib.lineNotes(tripId: trip, entryId: line(lib, "Kite")).map(\.text), ["Drake"])
    }

    /// The whole trip asked at once answers exactly as each line asked alone — and leaves out the lines
    /// with nothing.
    func testTheTripAtOnceAnswersAsEachLine() {
        var (lib, trip) = library()
        let n = lib.items.firstIndex { $0.name == "Headlamp" }!
        lib.items[n].note = "Spare batteries"
        let all = lib.lineNotes(tripId: trip)
        for entry in lib.trips[0].entries {
            let one = lib.lineNotes(tripId: trip, entryId: entry.id)
            XCTAssertEqual(all[entry.id] ?? [], one, entry.name)
        }
        XCTAssertNil(all[line(lib, "Kite")], "a line with nothing is in the answer")
        XCTAssertEqual(all.count, 2)
        XCTAssertEqual(lib.lineNotes(tripId: "no-such-trip"), [:])
    }
}
