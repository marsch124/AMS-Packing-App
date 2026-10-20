import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// Cancel everywhere (0.92): a page that changes the library at once works on a copy while it is
/// open, and its Save hands over only what the page changed (`Library.applyingPage`). His words,
/// 19 Oct 2026: "I open an item and change some property. How do I cancel that?"
final class PageChangesTests: XCTestCase {
    override func setUp() { PackingEnv.freeze(at: "2026-10-19T12:00:00.000Z") }
    override func tearDown() {
        PackingEnv.reset(); _ = setPhases(DEFAULT_PHASES); _ = setItemConditions(DEFAULT_ITEM_CONDITIONS)
    }

    /// A template "Hiking" with a Torch and a Map, and a thing on no template, a Kettle.
    private func library() -> Library {
        var lib = Library()
        lib.setNames("places", ["Garage", "Loft"])
        lib.saveTemplate(newList(name: "Hiking"))
        let hiking = lib.templates.first { $0.name == "Hiking" }!.id
        for name in ["Torch", "Map"] { _ = lib.addToTemplate(templateId: hiking, name: name) }
        _ = lib.addThing(name: "Kettle")
        return lib
    }

    private func template(_ lib: Library, _ name: String) -> PackList? {
        lib.templates.first { $0.name == name }
    }

    func testNothingChangedOnThePageChangesNothing() {
        let live = library()
        XCTAssertEqual(live.applyingPage(from: live, to: live), live)
    }

    /// Renamed, a thing added and one taken off, a place added — all on the copy. Meanwhile the
    /// other device added a thing and a place of its own: Save keeps both sides.
    func testSaveHandsOverWhatThePageChangedAndKeepsWhatChangedElsewhere() {
        let opened = library()
        let hiking = template(opened, "Hiking")!.id
        var page = opened
        XCTAssertTrue(page.renameTemplate(id: hiking, to: "Hill walk"))
        _ = page.addToTemplate(templateId: hiking, name: "Compass")
        let map = page.memberships.first { m in page.items.first { $0.id == m.itemId }?.name == "Map" }!.id
        XCTAssertNotNil(page.removeFromTemplate(templateId: hiking, memId: map))
        _ = page.addChoice("places", "Shed")

        var live = opened
        _ = live.addThing(name: "Tent")                         // the other device, meanwhile
        _ = live.addChoice("places", "Cellar")

        let saved = live.applyingPage(from: opened, to: page)
        XCTAssertEqual(template(saved, "Hill walk")?.id, hiking, "the rename was not handed over")
        XCTAssertNil(template(saved, "Hiking"))
        let rows = saved.resolvedTemplate(id: hiking)!.items.map(\.name).sorted()
        XCTAssertEqual(rows, ["Compass", "Torch"], "the template's rows are not the page's")
        XCTAssertTrue(saved.items.contains { $0.name == "Tent" }, "Save undid the other device's thing")
        XCTAssertTrue(saved.items.contains { $0.name == "Kettle" })
        let places = saved.storagePlaces()
        XCTAssertTrue(places.contains("Shed"), "the page's place was not handed over: \(places)")
        XCTAssertTrue(places.contains("Cellar"), "Save undid the other device's place: \(places)")
    }

    /// Cancel is the copy thrown away: the real library never saw the page's changes.
    func testCancelLeavesTheLibraryAsItWas() {
        let opened = library()
        let hiking = template(opened, "Hiking")!.id
        var page = opened
        XCTAssertTrue(page.renameTemplate(id: hiking, to: "Hill walk"))
        XCTAssertNotEqual(page, opened)
        // Cancel hands nothing over: the library is the one the page opened on.
        XCTAssertEqual(opened.applyingPage(from: page, to: page), opened)
        XCTAssertEqual(template(opened, "Hiking")?.id, hiking)
    }

    /// A record the page deleted goes, and only that one.
    func testADeleteOnThePageDeletesOnlyThat() {
        let opened = library()
        var page = opened
        let kettle = page.items.first { $0.name == "Kettle" }!.id
        XCTAssertTrue(page.deleteThing(id: kettle))
        var live = opened
        _ = live.addThing(name: "Tent")
        let saved = live.applyingPage(from: opened, to: page)
        XCTAssertFalse(saved.items.contains { $0.id == kettle }, "the page's delete was lost")
        XCTAssertEqual(saved.items.count, opened.items.count, "one gone, one come: \(saved.items.map(\.name))")
    }
    // MARK: - A trip the page touched (0.93, the outside review of 0.92 — his "fix 1, 2 and 6")
    //
    // A page never edits a trip itself, but what it does reaches the trips ahead: a thing renamed
    // or a row saved rewrites its open lines (`followThing`), a place renamed in Your choices is
    // carried into every line. Save handed such a trip over WHOLE — the page's copy from when it
    // opened, with all its lines — so a tick or a line added on the other device meanwhile was
    // undone or deleted.

    /// The library above with a trip ahead, "Weekend", built from Hiking: a Torch line and a Map line.
    private func libraryWithTrip() -> (Library, String) {
        var lib = library()
        let hiking = template(lib, "Hiking")!.id
        for i in lib.items.indices where lib.items[i].name == "Torch" { lib.items[i].storage = "Garage" }
        var trip = newEvent(name: "Weekend", startDate: "2026-10-25", endDate: "2026-10-27")
        trip.activities = [hiking]
        let made = lib.createTrip(trip)
        return (lib, made.id)
    }

    private func line(_ lib: Library, _ tripId: String, _ name: String) -> Item? {
        lib.trips.first { $0.id == tripId }?.entries.first { $0.name == name }
    }

    /// The reviewer's repro: the page renamed Torch; meanwhile the other device ticked Map, added
    /// Passport and renamed the trip. Save keeps all three, and the rename still reaches the trip.
    func testSaveKeepsATickALineAndATripNameFromTheOtherDevice() {
        let (opened, tripId) = libraryWithTrip()
        XCTAssertNotNil(line(opened, tripId, "Torch"))
        let map = line(opened, tripId, "Map")!.id
        PackingEnv.freeze(at: "2026-10-19T12:05:00.000Z")         // the page works a few minutes later
        var page = opened
        let torch = page.items.first { $0.name == "Torch" }!.id
        XCTAssertTrue(page.renameThing(id: torch, to: "Head torch"))
        XCTAssertNotNil(line(page, tripId, "Head torch"), "the rename did not reach the trip on the page")

        var live = opened                                          // the other device, meanwhile
        XCTAssertTrue(live.setChecked(true, tripId: tripId, entryId: map))
        XCTAssertNotNil(live.addCustomLine(tripId: tripId, name: "Passport"))
        let t = live.trips.firstIndex { $0.id == tripId }!
        live.trips[t].name = "Weekend in the hills"

        let saved = live.applyingPage(from: opened, to: page)
        XCTAssertEqual(line(saved, tripId, "Map")?.checked, true, "Save unticked the Map ticked on the other device")
        XCTAssertNotNil(line(saved, tripId, "Passport"), "Save deleted the line added on the other device")
        XCTAssertEqual(saved.trips.first { $0.id == tripId }?.name, "Weekend in the hills",
                       "Save undid the trip's new name — a line's follow counted as a change to the trip")
        XCTAssertNotNil(line(saved, tripId, "Head torch"), "the page's rename did not reach the trip")
        XCTAssertNil(line(saved, tripId, "Torch"))
        XCTAssertEqual(saved.trips.first { $0.id == tripId }?.entries.count, 3, "lines were added or lost")
    }

    /// Field by field on one line: Your choices renamed the place Garage (carried into the Torch
    /// line); the other device ticked that very line. Save keeps the tick AND takes the new name.
    func testAPlaceRenamedOnThePageAndATickOnTheSameLineBothStay() {
        let (opened, tripId) = libraryWithTrip()
        let torchLine = line(opened, tripId, "Torch")!
        XCTAssertEqual(torchLine.storage, "Garage")
        var page = opened
        XCTAssertNil(page.renameChoice("places", key: "Garage", to: "Shed"))
        XCTAssertEqual(line(page, tripId, "Torch")?.storage, "Shed")

        var live = opened
        XCTAssertTrue(live.setChecked(true, tripId: tripId, entryId: torchLine.id))

        let saved = live.applyingPage(from: opened, to: page)
        XCTAssertEqual(line(saved, tripId, "Torch")?.checked, true, "Save unticked the line ticked on the other device")
        XCTAssertEqual(line(saved, tripId, "Torch")?.storage, "Shed", "the page's rename did not reach the line")
    }

    /// A trip, or a line, deleted on the other device stays deleted — the page's follow of a thing
    /// does not bring it back.
    func testATripOrALineDeletedOnTheOtherDeviceStaysDeleted() {
        let (opened, tripId) = libraryWithTrip()
        var page = opened
        let torch = page.items.first { $0.name == "Torch" }!.id
        XCTAssertTrue(page.renameThing(id: torch, to: "Head torch"))

        var gone = opened
        XCTAssertTrue(gone.deleteTrip(id: tripId))
        XCTAssertFalse(gone.applyingPage(from: opened, to: page).trips.contains { $0.id == tripId },
                       "Save brought back a trip deleted on the other device")

        var lineGone = opened
        let t = lineGone.trips.firstIndex { $0.id == tripId }!
        lineGone.trips[t].entries.removeAll { $0.name == "Torch" }
        let saved = lineGone.applyingPage(from: opened, to: page)
        XCTAssertNil(line(saved, tripId, "Head torch"), "Save brought back a line deleted on the other device")
        XCTAssertNotNil(line(saved, tripId, "Map"))
    }
}
