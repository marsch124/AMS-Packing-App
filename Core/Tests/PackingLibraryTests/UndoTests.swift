import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// ⌘Z undo everywhere (0.105) — his "2. ⌘Z - yes please", 28 Oct 2026. Each kind of step undone and
/// redone; an undo writes back only what is still as the step left it, so a change from the other device
/// meanwhile stays; a delete comes back with the same ids; 50 steps; forgotten on a restore.
final class UndoTests: XCTestCase {
    override func setUp() { PackingEnv.freeze(at: "2026-10-28T09:00:00.000Z") }
    override func tearDown() { PackingEnv.reset() }

    /// One device as the app runs it (`LibraryModel`): every change stored as a step; the other device's
    /// changes arrive as records — not steps of this device.
    private struct Device {
        var lib: Library
        var book = UndoBook()
        var lastNote: String?

        mutating func change(_ name: String? = nil, joining: Bool = false, _ body: (inout Library) -> Void) {
            let old = lib.records()
            var next = lib
            body(&next)
            book.record(name: name, from: old, to: next.records(), library: next, joining: joining)
            lib = next
        }

        /// The app's own bookkeeping on this device (a forecast kept, a line sent to Reminders): no step.
        mutating func bookkeeping(_ body: (inout Library) -> Void) {
            let old = lib.records()
            var next = lib
            body(&next)
            book.carry(old: old, changes: recordChanges(from: old, to: next.records()))
            lib = next
        }

        /// The other device's change, arriving through iCloud: no step here.
        mutating func arrives(_ body: (inout Library) -> Void) {
            var next = lib
            body(&next)
            lib = Library(records: next.records())
        }

        @discardableResult
        mutating func undo() -> Reverted? {
            guard let r = book.undoing(lib) else { return nil }
            lib = r.library
            book.undone(r)
            lastNote = UndoBook.note(r, otherDevice: "your iPhone")
            return r
        }

        @discardableResult
        mutating func redo() -> Reverted? {
            guard let r = book.redoing(lib) else { return nil }
            lib = r.library
            book.redone(r)
            lastNote = UndoBook.note(r, redo: true, otherDevice: "your iPhone")
            return r
        }
    }

    /// A template Hiking (Passport, Map, Torch), a thing on no template (Kettle), and a trip "Weekend in
    /// the hills" with the three as its lines.
    private func device() -> Device {
        var lib = Library()
        lib.saveTemplate({ var l = newList(name: "Hiking")
            l.items = ["Passport", "Map", "Torch"].map { newItem(name: $0) }
            return l }())
        _ = lib.addThing(name: "Kettle")
        var trip = newEvent(name: "Weekend in the hills", startDate: "2026-11-06", endDate: "2026-11-08")
        trip.entries = ["Passport", "Map", "Torch"].map { newItem(name: $0) }
        lib.trips = [trip]
        return Device(lib: Library(records: lib.records()))
    }

    private func line(_ d: Device, _ name: String) -> Item { d.lib.trips[0].entries.first { $0.name == name }! }
    private func thing(_ d: Device, _ name: String) -> Item? { d.lib.items.first { $0.name == name } }
    /// The library as stored, without the moment each record was written — what both devices compare.
    private func stored(_ lib: Library) -> [String] {
        lib.records().map { "\($0.table.rawValue)|\($0.key)|\($0.parent)|\($0.json.text())" }.sorted()
    }

    // MARK: - Each kind of step, undone and redone

    func testATickIsUndoneAndRedone() {
        var d = device()
        let start = stored(d.lib)
        let trip = d.lib.trips[0].id, passport = line(d, "Passport").id
        d.change { _ = $0.setChecked(true, tripId: trip, entryId: passport) }
        XCTAssertEqual(d.book.undoName, "Tick Passport")
        d.undo()
        XCTAssertFalse(line(d, "Passport").checked, "Undo left the line ticked")
        XCTAssertNil(line(d, "Passport").extra[TICKED_AT_KEY], "Undo left the tick's moment behind")
        XCTAssertEqual(stored(d.lib), start, "Undo did not put the library back as it was")
        XCTAssertEqual(d.book.redoName, "Tick Passport")
        XCTAssertNil(d.lastNote, "a plain undo said something")
        d.redo()
        XCTAssertTrue(line(d, "Passport").checked, "Redo did not tick it again")
        XCTAssertEqual(d.book.undoName, "Tick Passport")
        XCTAssertFalse(d.book.canRedo)
    }

    func testUntickSetAsideAndBringBackAreNamedAndUndone() {
        var d = device()
        let trip = d.lib.trips[0].id, map = line(d, "Map").id
        d.change { _ = $0.setChecked(true, tripId: trip, entryId: map) }
        d.change { _ = $0.setChecked(false, tripId: trip, entryId: map) }
        XCTAssertEqual(d.book.undoName, "Untick Map")
        d.change { _ = $0.setAside(true, tripId: trip, entryId: map) }
        XCTAssertEqual(d.book.undoName, "Set Aside Map")
        d.change { _ = $0.setAside(false, tripId: trip, entryId: map) }
        XCTAssertEqual(d.book.undoName, "Bring Back Map")
        d.undo()
        XCTAssertTrue(line(d, "Map").skipped, "Undo of Bring back did not set it aside again")
        d.undo()
        XCTAssertFalse(line(d, "Map").skipped, "Undo of Set aside did not bring it back")
        d.undo()
        XCTAssertTrue(line(d, "Map").checked, "Undo of an untick did not tick it again")
    }

    /// A heading's round tick is one step (and the screen names it after the heading); Clear every tick too.
    func testAHeadingsTickIsOneStep() {
        var d = device()
        let trip = d.lib.trips[0].id, ids = d.lib.trips[0].entries.map(\.id)
        d.change("Tick Hiking") { _ = $0.setChecked(true, tripId: trip, entryIds: ids) }
        XCTAssertEqual(d.book.undos.count, 1)
        XCTAssertEqual(d.book.undoName, "Tick Hiking")
        d.undo()
        XCTAssertEqual(d.lib.trips[0].entries.filter(\.checked).count, 0, "one Undo did not take every tick of the press back")
        var e = device()
        let other = e.lib.trips[0].id, lines = e.lib.trips[0].entries.map(\.id)
        e.change { _ = $0.setChecked(true, tripId: other, entryIds: lines) }
        XCTAssertEqual(e.book.undoName, "Tick 3 Things", "a press of many lines without a name of its own")
    }

    func testThingsAddedToATripGoAndThingsRemovedComeBack() {
        var d = device()
        let start = stored(d.lib)
        let trip = d.lib.trips[0].id
        d.change { _ = $0.addCustomLine(tripId: trip, name: "Compass") }
        XCTAssertEqual(d.book.undoName, "Add Compass")
        d.undo()
        XCTAssertFalse(d.lib.trips[0].entries.contains { $0.name == "Compass" }, "Undo left the added line")
        XCTAssertEqual(stored(d.lib), start)
        let torch = line(d, "Torch").id
        d.change { $0.trips[0].entries.removeAll { $0.id == torch } }
        XCTAssertEqual(d.book.undoName, "Remove Torch")
        d.undo()
        XCTAssertEqual(d.lib.trips[0].entries.map(\.name), ["Passport", "Map", "Torch"], "the line did not come back in its place")
        XCTAssertEqual(line(d, "Torch").id, torch, "the line came back as another line")
    }

    /// A thing's Done writes in two changes (a rename, then the rest): one step, both taken back at once.
    func testAThingsSaveIsOneStep() {
        var d = device()
        let id = thing(d, "Map")!.id
        d.change { _ = $0.renameThing(id: id, to: "Map case") }
        d.change(joining: true) { _ = $0.updateThing(id: id) { $0.note = "Fold along the creases" } }
        XCTAssertEqual(d.book.undos.count, 1, "one Done made two steps")
        XCTAssertEqual(d.book.undoName, "Edit Map case")
        d.undo()
        XCTAssertEqual(thing(d, "Map")?.id, id, "the name did not go back")
        XCTAssertEqual(thing(d, "Map")?.note, "", "the note did not go back")
        d.redo()
        XCTAssertEqual(thing(d, "Map case")?.note, "Fold along the creases")
    }

    func testATemplatesSaveIsUndone() {
        var d = device()
        let hiking = d.lib.templates[0].id
        d.change { _ = $0.renameTemplate(id: hiking, to: "Hill walk") }
        XCTAssertEqual(d.book.undoName, "Edit Hill walk")
        d.undo()
        XCTAssertEqual(d.lib.templates[0].name, "Hiking")
    }

    // MARK: - Deletes come back whole, with the same ids

    func testADeletedTripComesBackWholeWithTheSameIds() {
        var d = device()
        let trip = d.lib.trips[0].id
        let mapLine = line(d, "Map").id
        d.change { _ = $0.setChecked(true, tripId: trip, entryId: mapLine) }
        let before = stored(d.lib)
        let keys = Set(d.lib.records().filter { $0.table == .trips || $0.table == .entries }.map(\.key))
        d.change { _ = $0.deleteTrip(id: trip) }
        XCTAssertEqual(d.book.undoName, "Delete Weekend in the hills")
        let gone = d.lib
        d.undo()
        XCTAssertEqual(stored(d.lib), before, "the trip did not come back as it was, ticks and all")
        // What the other device is sent: the same records again, under their own keys — nothing new.
        let sent = recordChanges(from: gone.records(), to: d.lib.records())
        XCTAssertEqual(Set(sent.puts.map(\.key)), keys, "the undo wrote other records than the trip's own")
        XCTAssertTrue(sent.deletes.isEmpty)
        d.redo()
        XCTAssertTrue(d.lib.trips.isEmpty, "Redo did not delete it again")
    }

    func testADeletedThingAndTemplateComeBackWithTheirRows() {
        var d = device()
        let before = stored(d.lib)
        let map = thing(d, "Map")!.id
        d.change { _ = $0.deleteThing(id: map) }
        XCTAssertEqual(d.book.undoName, "Delete Map")
        d.undo()
        XCTAssertEqual(stored(d.lib), before, "the thing did not come back with its place on Hiking")
        let hiking = d.lib.templates[0].id
        d.change { _ = $0.deleteTemplate(id: hiking) }
        XCTAssertEqual(d.book.undoName, "Delete Hiking")
        d.undo()
        XCTAssertEqual(stored(d.lib), before, "the template did not come back with its rows")
    }

    // MARK: - The other device meanwhile

    /// His rule: an undo must not overwrite what the other device changed since.
    func testAnUndoKeepsTheOtherDevicesTickBesideIt() {
        var d = device()
        let trip = d.lib.trips[0].id, passport = line(d, "Passport").id, map = line(d, "Map").id
        d.change { _ = $0.setChecked(true, tripId: trip, entryId: passport) }
        d.arrives { _ = $0.setChecked(true, tripId: trip, entryId: map) }
        d.arrives { _ = $0.addCustomLine(tripId: trip, name: "Sun cream") }
        d.undo()
        XCTAssertFalse(line(d, "Passport").checked)
        XCTAssertTrue(line(d, "Map").checked, "Undo took the other device's tick away")
        XCTAssertTrue(d.lib.trips[0].entries.contains { $0.name == "Sun cream" }, "Undo took the other device's line away")
        XCTAssertNil(d.lastNote, "nothing of the step had changed, yet a note")
    }

    func testPartlyUndoneWhenTheOtherDeviceChangedAField() {
        var d = device()
        let id = thing(d, "Map")!.id
        d.change { lib in
            _ = lib.renameThing(id: id, to: "Map case")
            _ = lib.updateThing(id: id) { $0.note = "Fold along the creases" }
        }
        d.arrives { _ = $0.updateThing(id: id) { $0.note = "In the lid pocket" } }
        let r = d.undo()
        XCTAssertEqual(thing(d, "Map")?.id, id, "the name the other device left alone did not go back")
        XCTAssertEqual(thing(d, "Map")?.note, "In the lid pocket", "Undo overwrote the other device's note")
        XCTAssertEqual(r?.kept, ["Map"])
        XCTAssertEqual(d.lastNote, "Partly undone \u{2014} Map was changed on your iPhone")
        // Redo puts back what the undo took back — the name — and leaves the other device's note.
        d.redo()
        XCTAssertEqual(thing(d, "Map case")?.note, "In the lid pocket")
    }

    func testNotUndoneWhenAllOfItWasChangedSince() {
        var d = device()
        let id = thing(d, "Kettle")!.id
        d.change { _ = $0.updateThing(id: id) { $0.note = "Descale first" } }
        d.arrives { _ = $0.updateThing(id: id) { $0.note = "Bring the lid" } }
        let r = d.undo()
        XCTAssertEqual(r?.nothing, true)
        XCTAssertEqual(thing(d, "Kettle")?.note, "Bring the lid")
        XCTAssertEqual(d.lastNote, "Not undone \u{2014} Kettle was changed on your iPhone")
        XCTAssertFalse(d.book.canUndo, "the step stayed after it was tried")
        XCTAssertFalse(d.book.canRedo, "nothing was undone, yet Redo is offered")
    }

    /// A list (a template's sections) loses what the step added and keeps what the other device added to
    /// it meanwhile — never the step's list whole (0.95's list rule).
    func testAnUndoOfAnAddedSectionKeepsTheOtherDevicesSection() {
        var d = device()
        let hiking = d.lib.templates[0].id
        d.change { _ = $0.addSection(templateId: hiking, name: "Lights") }
        d.arrives { _ = $0.addSection(templateId: hiking, name: "Maps") }
        d.undo()
        XCTAssertEqual(d.lib.templates[0].sections.map(\.name), ["Maps"], "Undo took the other device's section too, or left its own")
        XCTAssertNil(d.lastNote)
    }

    /// A trip deleted on the other device after a tick here: Undo of the tick does not bring it back.
    func testARecordDeletedElsewhereStaysDeleted() {
        var d = device()
        let trip = d.lib.trips[0].id, torch = line(d, "Torch").id
        d.change { _ = $0.setChecked(true, tripId: trip, entryId: torch) }
        d.arrives { _ = $0.deleteTrip(id: trip) }
        d.undo()
        XCTAssertTrue(d.lib.trips.isEmpty, "Undo brought back a trip the other device deleted")
        XCTAssertTrue(d.lib.records().allSatisfy { $0.table != .entries }, "a line of the deleted trip came back")
    }

    /// A trip the other device changed after a delete here … cannot be: the delete reached it. But a trip
    /// it made again under the same id (its save crossed the delete) is left as it is.
    func testADeleteUndoneKeepsWhatWasMadeAgainMeanwhile() {
        var d = device()
        let trip = d.lib.trips[0]
        d.change { _ = $0.deleteTrip(id: trip.id) }
        var again = trip
        again.name = "Weekend by the sea"
        d.arrives { $0.trips.append(again) }
        d.undo()
        XCTAssertEqual(d.lib.trips.map(\.name), ["Weekend by the sea"], "Undo wrote over the other device's trip")
    }

    /// A trip made here, then its place looked up and kept by the app itself: Undo takes the trip away
    /// and says nothing — the app's own write is not the other device's change.
    func testTheAppsOwnBookkeepingIsNotTakenForTheOtherDevice() {
        var d = device()
        d.change { _ = $0.createTrip(newEvent(name: "Coast week", startDate: "2026-11-20", endDate: "2026-11-22")) }
        XCTAssertEqual(d.book.undoName, "Add Coast week")
        let id = d.lib.trips.first { $0.name == "Coast week" }!.id
        d.bookkeeping { _ = $0.setPlace(tripId: id, lat: 57.7, lon: 11.97, label: "Gothenburg") }
        d.undo()
        XCTAssertFalse(d.lib.trips.contains { $0.id == id }, "Undo kept the trip because the app wrote its place")
        XCTAssertNil(d.lastNote, "the app's own write was called the other device's: \(d.lastNote ?? "")")
    }

    // MARK: - The history

    func testFiftyStepsBack() {
        var d = device()
        let trip = d.lib.trips[0].id
        for n in 0..<60 { d.change { _ = $0.addCustomLine(tripId: trip, name: "Line \(n)") } }
        XCTAssertEqual(UndoBook.depth, 50)
        XCTAssertEqual(d.book.undos.count, 50, "the history is not 50 steps deep")
        var undone = 0
        while d.undo() != nil { undone += 1 }
        XCTAssertEqual(undone, 50)
        let left = d.lib.trips[0].entries.map(\.name).filter { $0.hasPrefix("Line ") }
        XCTAssertEqual(left, (0..<10).map { "Line \($0)" }, "50 steps back is not where the history ends")
    }

    func testANewChangeForgetsTheRedo() {
        var d = device()
        let trip = d.lib.trips[0].id, map = line(d, "Map").id, torch = line(d, "Torch").id
        d.change { _ = $0.setChecked(true, tripId: trip, entryId: map) }
        d.undo()
        XCTAssertTrue(d.book.canRedo)
        d.change { _ = $0.setChecked(true, tripId: trip, entryId: torch) }
        XCTAssertFalse(d.book.canRedo, "a new change kept the Redo of an older one")
    }

    /// A restore (or the first import, or a restart of the sync) replaces the library: nothing of before
    /// can be undone.
    func testARestoreForgetsTheHistory() throws {
        var d = device()
        let trip = d.lib.trips[0].id, map = line(d, "Map").id, torch = line(d, "Torch").id
        d.change { _ = $0.setChecked(true, tripId: trip, entryId: map) }
        d.undo()
        d.change { _ = $0.setChecked(true, tripId: trip, entryId: torch) }
        let file = Library().backupData()
        d.lib = Importer.restoring(try Importer.read(file).library, over: d.lib)
        d.book.forget()
        XCTAssertFalse(d.book.canUndo)
        XCTAssertFalse(d.book.canRedo)
        XCTAssertNil(d.undo(), "an undo after a restore did something")
    }

    /// A banner's Undo of a step that is not the last one (a heading's tick, then a tick of one line in
    /// it): that step alone goes back; what the later step changed is this device's own, kept without a
    /// word; the later step stays to be undone.
    func testABannersUndoOfAnOlderStepKeepsTheLaterOne() {
        var d = device()
        let trip = d.lib.trips[0].id, ids = d.lib.trips[0].entries.map(\.id)
        d.change("Tick Hiking") { _ = $0.setChecked(true, tripId: trip, entryIds: ids) }
        let heading = d.book.undos.last!.id
        d.change { _ = $0.setAside(true, tripId: trip, entryId: ids[2]) }
        let r = d.book.undoingOne(heading, in: d.lib)!
        d.lib = r.library
        d.book.undoneOne(heading)
        XCTAssertEqual(d.lib.trips[0].entries.map(\.checked), [false, false, false])
        XCTAssertTrue(d.lib.trips[0].entries[2].skipped, "the later step's change was taken back")
        XCTAssertTrue(r.kept.isEmpty, "this device's own later change was called the other device's")
        XCTAssertEqual(d.book.undos.map(\.name), ["Set Aside Torch"])
        XCTAssertFalse(d.book.holds(heading))
    }
}
