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

    // MARK: - Things, rows and templates field by field (0.94, the open point of 0.93's report)
    //
    // 0.93 merged a trip field by field, but a thing, a row (membership) and a template were still
    // handed over WHOLE: a field the other device changed on a record the page also changed went
    // back to what it was when the page opened.

    private func thing(_ lib: Library, _ name: String) -> Item? { lib.items.first { $0.name == name } }

    private func torchRow(_ lib: Library) -> Membership? {
        let torch = thing(lib, "Torch")!.id
        return lib.memberships.first { $0.itemId == torch }
    }

    /// The page wrote a note on the Torch; the other device put the Torch in another bag. Both stay.
    func testAThingsNoteFromThePageAndItsBagFromTheOtherDeviceBothStay() {
        let opened = library()
        let torch = thing(opened, "Torch")!.id
        var page = opened
        XCTAssertTrue(page.setThingNote(id: torch, "Spare batteries in the lid"))
        var live = opened
        XCTAssertTrue(live.updateThing(id: torch) { $0.container = "Day pack" })

        let saved = live.applyingPage(from: opened, to: page)
        XCTAssertEqual(thing(saved, "Torch")?.note, "Spare batteries in the lid", "the page's note was not handed over")
        XCTAssertEqual(thing(saved, "Torch")?.container, "Day pack", "Save put back the bag the other device chose")
    }

    /// The page moved the Torch's row into a section; the other device made it two. Both stay.
    func testARowsSectionFromThePageAndItsCountFromTheOtherDeviceBothStay() {
        let opened = library()
        let hiking = template(opened, "Hiking")!.id
        let row = torchRow(opened)!.id
        var page = opened
        let lights = page.addSection(templateId: hiking, name: "Lights")!
        XCTAssertTrue(page.updateMembership(memId: row) { $0.section = lights.id })
        var live = opened
        XCTAssertTrue(live.updateMembership(memId: row) { $0.qty = "2" })

        let saved = live.applyingPage(from: opened, to: page)
        XCTAssertEqual(saved.memberships.first { $0.id == row }?.section, lights.id, "the page's section was not handed over")
        XCTAssertEqual(saved.memberships.first { $0.id == row }?.qty, "2", "Save put back the count from when the page opened")
        XCTAssertEqual(template(saved, "Hiking")?.sections.map(\.name), ["Lights"])
    }

    /// The page renamed Hiking; the other device gave it a colour. Both stay, and its time is the later one.
    func testATemplatesNameFromThePageAndItsColourFromTheOtherDeviceBothStay() {
        let opened = library()
        let hiking = template(opened, "Hiking")!.id
        PackingEnv.freeze(at: "2026-10-19T12:03:00.000Z")
        var live = opened
        XCTAssertTrue(live.setTemplateColour(id: hiking, hex: "#2f7d4a"))
        PackingEnv.freeze(at: "2026-10-19T12:05:00.000Z")
        var page = opened
        XCTAssertTrue(page.renameTemplate(id: hiking, to: "Hill walk"))

        let saved = live.applyingPage(from: opened, to: page)
        let t = saved.templates.first { $0.id == hiking }
        XCTAssertEqual(t?.name, "Hill walk", "the page's name was not handed over")
        XCTAssertEqual(t?.color, "#2f7d4a", "Save put back the colour from when the page opened")
        XCTAssertEqual(t?.updatedAt, "2026-10-19T12:05:00.000Z")
    }

    /// Your choices renamed the place the Torch is kept in (carried onto the Torch); the other device
    /// deleted the Torch meanwhile. It stays deleted — the follow does not bring it back.
    func testAThingDeletedOnTheOtherDeviceStaysDeleted() {
        var opened = library()
        let torch = thing(opened, "Torch")!.id
        XCTAssertTrue(opened.updateThing(id: torch) { $0.storage = "Garage" })
        var page = opened
        XCTAssertNil(page.renameChoice("places", key: "Garage", to: "Shed"))
        XCTAssertEqual(thing(page, "Torch")?.storage, "Shed")
        var live = opened
        XCTAssertTrue(live.deleteThing(id: torch))

        let saved = live.applyingPage(from: opened, to: page)
        XCTAssertNil(saved.items.first { $0.id == torch }, "Save brought back a thing deleted on the other device")
        XCTAssertTrue(saved.storagePlaces().contains("Shed"), "the page's rename was not handed over")
    }

    // MARK: - The smaller tables field by field, and lists as lists (0.95, residual of the outside review)
    //
    // 0.94 merged things, rows and templates field by field; to-dos, kits, "When" steps, settings rows
    // and photos still went back WHOLE, and a list held in one field (a template's sections, a kit's
    // contents, his kinds of thing) went back as the page had it: what the other device added to it
    // meanwhile was lost.

    private func todo(_ lib: Library, _ text: String) -> ActionItem? { lib.actions.first { $0.text == text } }

    /// The page reworded a to-do; the other device ticked it done. Both stay.
    func testAToDosWordsFromThePageAndItsTickFromTheOtherDeviceBothStay() {
        var opened = library()
        opened.actions.append(newAction(text: "Book the ferry"))
        let id = todo(opened, "Book the ferry")!.id
        var page = opened
        page.actions[0].text = "Book the ferry and the cabin"
        var live = opened
        live.actions[0].done = true
        live.actions[0].doneAt = "2026-10-19T12:01:00.000Z"

        let saved = live.applyingPage(from: opened, to: page)
        XCTAssertEqual(saved.actions.first { $0.id == id }?.text, "Book the ferry and the cabin", "the page's words were not handed over")
        XCTAssertEqual(saved.actions.first { $0.id == id }?.done, true, "Save unticked the to-do ticked on the other device")
        XCTAssertEqual(saved.actions.count, 1)
    }

    /// A to-do deleted on the other device stays deleted, though the page changed it.
    func testAToDoDeletedOnTheOtherDeviceStaysDeleted() {
        var opened = library()
        opened.actions.append(newAction(text: "Charge the lamp"))
        var page = opened
        page.actions[0].priority = "high"
        var live = opened
        live.actions.removeAll()

        let saved = live.applyingPage(from: opened, to: page)
        XCTAssertTrue(saved.actions.isEmpty, "Save brought back a to-do deleted on the other device: \(saved.actions.map(\.text))")
    }

    /// A kit: the page renamed it and put the Torch in; the other device put the Map in. All stay.
    func testAKitsNameAndWhatEachDevicePutInItAllStay() {
        var opened = library()
        let torch = thing(opened, "Torch")!.id, map = thing(opened, "Map")!.id, kettle = thing(opened, "Kettle")!.id
        opened.kits.append(newKit(name: "Brew kit", itemIds: [kettle]))
        let kit = opened.kits[0].id
        var page = opened
        page.kits[0].name = "Camp kitchen"
        page.kits[0].itemIds.append(torch)
        var live = opened
        live.kits[0].itemIds.append(map)

        let saved = live.applyingPage(from: opened, to: page)
        let k = saved.kits.first { $0.id == kit }
        XCTAssertEqual(k?.name, "Camp kitchen", "the page's name was not handed over")
        XCTAssertEqual(k?.itemIds, [kettle, map, torch], "a thing put in on one of the devices was lost")
    }

    /// The "When" steps were the factory seven on both devices. The page renamed one, the other
    /// device gave another more days ahead: both changes stay (each device stored all seven).
    func testTwoWhenStepsChangedOneOnEachDeviceBothStay() {
        let opened = library()
        XCTAssertTrue(opened.phases.isEmpty, "the factory steps are stored as none")
        var page = opened
        page.setTimeline(DEFAULT_PHASES.map { p in var q = p; if q.id == "week" { q.label = "A week ahead" }; return q })
        var live = opened
        live.setTimeline(DEFAULT_PHASES.map { p in var q = p; if q.id == "door" { q.leadDays = 1 }; return q })

        let saved = live.applyingPage(from: opened, to: page)
        XCTAssertEqual(saved.phases.first { $0.id == "week" }?.label, "A week ahead", "the page's step was not handed over")
        XCTAssertEqual(saved.phases.first { $0.id == "door" }?.leadDays, 1, "Save put back the step the other device changed")
        XCTAssertEqual(saved.phases.map(\.id), DEFAULT_PHASES.map(\.id))
    }

    /// The page put a step back to the factory's words (all seven are the factory's again, so none
    /// is stored); the other device added a step. The seven stay, with the new one.
    func testWhenStepsSetBackToTheFactoryOnThePageKeepTheStepAddedOnTheOtherDevice() {
        var opened = library()
        opened.setTimeline(DEFAULT_PHASES.map { p in var q = p; if q.id == "prep" { q.label = "Planning" }; return q })
        var page = opened
        page.setTimeline(DEFAULT_PHASES)
        XCTAssertTrue(page.phases.isEmpty)
        var live = opened
        live.setTimeline(opened.phases + [Phase(id: "visa", label: "Visa", emoji: "🛂", color: "#888888", leadDays: 60, order: 7)])

        let saved = live.applyingPage(from: opened, to: page)
        XCTAssertEqual(saved.phases.map(\.id), DEFAULT_PHASES.map(\.id) + ["visa"], "the steps were lost: \(saved.phases.map(\.id))")
        XCTAssertEqual(saved.phases.first { $0.id == "prep" }?.label, "Preparations", "the page's words were not handed over")
    }

    /// A settings row: the page renamed a condition, the other device changed its colour. Both stay.
    func testASettingsRowsWordsFromThePageAndItsColourFromTheOtherDeviceBothStay() {
        var opened = library()
        opened.setConditions(DEFAULT_ITEM_CONDITIONS + [ItemCondition(id: "patched", label: "Patched", tone: "warn")])
        var page = opened
        page.setConditions(DEFAULT_ITEM_CONDITIONS + [ItemCondition(id: "patched", label: "Patched up", tone: "warn")])
        var live = opened
        live.setConditions(DEFAULT_ITEM_CONDITIONS + [ItemCondition(id: "patched", label: "Patched", tone: "danger")])

        let saved = live.applyingPage(from: opened, to: page)
        let row = conditionsFromRows(saved.shared).first { $0.id == "patched" }
        XCTAssertEqual(row?.label, "Patched up", "the page's words were not handed over")
        XCTAssertEqual(row?.tone, "danger", "Save put back the colour from when the page opened")
    }

    /// The page set the places back to the factory list; the other device added one. The factory
    /// list stays, with the new place — not the new place alone.
    func testPlacesSetBackToTheFactoryOnThePageKeepThePlaceAddedOnTheOtherDevice() {
        let opened = library()
        var page = opened
        page.setNames("places", DEFAULT_STORAGE_LOCATIONS)
        XCTAssertFalse(page.shared.contains { $0.kind == "places" })
        var live = opened
        _ = live.addChoice("places", "Boathouse")

        let saved = live.applyingPage(from: opened, to: page)
        let places = saved.storagePlaces()
        XCTAssertTrue(places.contains("Boathouse"), "the other device's place was lost: \(places)")
        for p in DEFAULT_STORAGE_LOCATIONS where !["Garage", "Loft"].contains(p) {
            XCTAssertTrue(places.contains(p), "the factory place \(p) went: \(places)")
        }
    }

    /// His kinds of thing (one list): the page added one, the other device another. Both stay.
    func testAKindOfThingAddedOnEachDeviceBothStay() {
        let opened = library()
        var page = opened
        page.setCategories(opened.categories() + ["Rope work"])
        var live = opened
        live.setCategories(opened.categories() + ["Fishing"])

        let saved = live.applyingPage(from: opened, to: page)
        XCTAssertEqual(saved.categories().suffix(2), ["Fishing", "Rope work"], "a kind added on one of the devices was lost")
    }

    /// For the lost-luggage desk (from Your choices): the page changed the e-mail, the other device
    /// the phone. Both stay.
    func testTheDeskDetailsEachDeviceChangedBothStay() {
        var opened = library()
        opened.setDeskDetails(DeskDetails(name: "Sam Example", phone: "+46 70 000 00 01", email: "sam@example.com"))
        var page = opened
        page.setDeskDetails(DeskDetails(name: "Sam Example", phone: "+46 70 000 00 01", email: "sam.new@example.com"))
        var live = opened
        live.setDeskDetails(DeskDetails(name: "Sam Example", phone: "+46 70 000 00 02", email: "sam@example.com"))

        let saved = live.applyingPage(from: opened, to: page)
        XCTAssertEqual(saved.deskDetails().email, "sam.new@example.com", "the page's e-mail was not handed over")
        XCTAssertEqual(saved.deskDetails().phone, "+46 70 000 00 02", "Save put back the phone from when the page opened")
    }

    // A photo (0.95): never dropped, never twice.

    private let jpegA = Data([0xFF, 0xD8, 0xFF, 0x01]), jpegB = Data([0xFF, 0xD8, 0xFF, 0x02])

    /// The page took a photo off the Torch (nothing showed it on the page any more, so it went);
    /// meanwhile the other device showed it on the Kettle. The photo stays.
    func testAPhotoTheOtherDeviceStillShowsIsNotDeleted() {
        var opened = library()
        let torch = thing(opened, "Torch")!.id, kettle = thing(opened, "Kettle")!.id
        let photo = opened.addThingPhoto(id: torch, jpeg: jpegA)!.id
        var page = opened
        XCTAssertTrue(page.removeThingPhoto(id: torch, photoId: photo))
        XCTAssertFalse(page.photos.contains { $0.id == photo })
        var live = opened
        XCTAssertTrue(live.updateThing(id: kettle) { $0.photos.append(photo) })

        let saved = live.applyingPage(from: opened, to: page)
        XCTAssertTrue(saved.photos.contains { $0.id == photo }, "Save deleted a photo the Kettle still shows")
        XCTAssertEqual(saved.photos.filter { $0.id == photo }.count, 1)
        XCTAssertEqual(thing(saved, "Torch")?.photos, [], "the page's change to the Torch was not handed over")
    }

    /// A photo whose bytes the other device has, and whose page copy differs only in when it was
    /// taken: the bytes here stay.
    func testAPhotoChangedOnlyInItsDateOnThePageKeepsTheBytesHere() {
        var opened = library()
        let torch = thing(opened, "Torch")!.id
        let photo = opened.addThingPhoto(id: torch, jpeg: jpegA)!.id
        var page = opened
        page.photos[0].createdAt = "2026-10-19T12:30:00.000Z"
        var live = opened
        live.photos[0].data = "data:image/jpeg;base64," + jpegB.base64EncodedString()

        let saved = live.applyingPage(from: opened, to: page)
        XCTAssertEqual(saved.photos.first { $0.id == photo }?.data, live.photos[0].data, "Save put back the bytes from when the page opened")
        XCTAssertEqual(saved.photos.count, 1)
    }

    /// A photo taken on each device of the same thing: the thing keeps both.
    func testAPhotoTakenOnEachDeviceOfOneThingBothStay() {
        let opened = library()
        let torch = thing(opened, "Torch")!.id
        var page = opened
        let mine = page.addThingPhoto(id: torch, jpeg: jpegA)!.id
        var live = opened
        let theirs = live.addThingPhoto(id: torch, jpeg: jpegB)!.id

        let saved = live.applyingPage(from: opened, to: page)
        XCTAssertEqual(Set(thing(saved, "Torch")?.photos ?? []), [mine, theirs], "a photo of the Torch was lost")
        XCTAssertEqual(Set(saved.photos.map(\.id)), [mine, theirs])
    }

    // A template's sections, merged as a list (0.95). The rule: what either device added stays; what
    // the page removed goes; one removed on the other device stays removed. The order is the one here,
    // with each section the page added put just before the one after it on the page (last, when none
    // is) — unless the page itself moved sections (Arrange): then the page's order, with each section
    // added on the other device just before the one after it there.

    private func sections(_ lib: Library) -> [String] { template(lib, "Hiking")?.sections.map(\.name) ?? [] }

    /// Each device added a section; the page also renamed one and removed one. All of it stays.
    func testASectionAddedOnEachDeviceBothStay() {
        var opened = library()
        let hiking = template(opened, "Hiking")!.id
        for s in ["Lights", "Maps", "Food"] { _ = opened.addSection(templateId: hiking, name: s) }
        let maps = template(opened, "Hiking")!.sections[1].id, food = template(opened, "Hiking")!.sections[2].id
        var page = opened
        _ = page.addSection(templateId: hiking, name: "Rain gear")
        XCTAssertTrue(page.renameSection(templateId: hiking, sectionId: maps, to: "Navigation"))
        XCTAssertTrue(page.removeSection(templateId: hiking, sectionId: food))
        var live = opened
        _ = live.addSection(templateId: hiking, name: "First aid")

        let saved = live.applyingPage(from: opened, to: page)
        XCTAssertEqual(sections(saved), ["Lights", "Navigation", "First aid", "Rain gear"],
                       "the sections are not both devices' work")
    }

    /// The page moved a section (Arrange); the other device added one after Maps. The page's order,
    /// with the new one just after Maps.
    func testSectionsMovedOnThePageKeepTheOrderOfThePageAndTheSectionAddedElsewhere() {
        var opened = library()
        let hiking = template(opened, "Hiking")!.id
        for s in ["Lights", "Maps", "Food"] { _ = opened.addSection(templateId: hiking, name: s) }
        let lights = template(opened, "Hiking")!.sections[0].id
        var page = opened
        XCTAssertTrue(page.moveSection(templateId: hiking, sectionId: lights, before: nil))
        XCTAssertEqual(sections(page), ["Maps", "Food", "Lights"])
        var live = opened
        let ropes = live.addSection(templateId: hiking, name: "Ropes")!.id
        XCTAssertTrue(live.moveSection(templateId: hiking, sectionId: ropes, before: template(live, "Hiking")!.sections[2].id))
        XCTAssertEqual(sections(live), ["Lights", "Maps", "Ropes", "Food"])

        let saved = live.applyingPage(from: opened, to: page)
        XCTAssertEqual(sections(saved), ["Maps", "Ropes", "Food", "Lights"])
    }

    /// A section removed on the other device stays removed, though the page renamed it.
    func testASectionRemovedOnTheOtherDeviceStaysRemoved() {
        var opened = library()
        let hiking = template(opened, "Hiking")!.id
        for s in ["Lights", "Maps"] { _ = opened.addSection(templateId: hiking, name: s) }
        let maps = template(opened, "Hiking")!.sections[1].id
        var page = opened
        XCTAssertTrue(page.renameSection(templateId: hiking, sectionId: maps, to: "Navigation"))
        var live = opened
        XCTAssertTrue(live.removeSection(templateId: hiking, sectionId: maps))

        let saved = live.applyingPage(from: opened, to: page)
        XCTAssertEqual(sections(saved), ["Lights"], "Save brought back a section removed on the other device")
    }

    /// A kit on a thing's page (opened from a template's page): the page put the Map in the Torch,
    /// the other device the Kettle. The Torch holds both.
    func testWhatEachDevicePutInAThingsKitBothStay() {
        let opened = library()
        let torch = thing(opened, "Torch")!.id, map = thing(opened, "Map")!.id, kettle = thing(opened, "Kettle")!.id
        var page = opened
        XCTAssertTrue(page.setKit(kitId: torch, contents: [map]))
        var live = opened
        XCTAssertTrue(live.setKit(kitId: torch, contents: [kettle]))

        let saved = live.applyingPage(from: opened, to: page)
        XCTAssertEqual(Set(Library.listedContents(thing(saved, "Torch")!)), [map, kettle], "a thing put in on one of the devices was lost")
    }

    // MARK: - Pages that save their own copy (0.95, the audit of the outside review's residual)

    /// Trip settings: the screen changed the season; the other device renamed the trip and ticked a
    /// line meanwhile. Save keeps the name and the tick.
    func testTripSettingsWriteOnlyWhatTheScreenChanged() {
        let (opened, tripId) = libraryWithTrip()
        let atLoad = opened.trips.first { $0.id == tripId }!
        var screen = atLoad
        screen.season = "Winter"
        screen.name = atLoad.name                                  // the screen writes every field it shows
        var live = opened
        let t = live.trips.firstIndex { $0.id == tripId }!
        live.trips[t].name = "Weekend in the hills"
        XCTAssertTrue(live.setChecked(true, tripId: tripId, entryId: atLoad.entries[0].id))

        let now = live.trips[t].takingSettings(from: atLoad, to: screen)
        XCTAssertEqual(now.season, "Winter", "the screen's season was not saved")
        XCTAssertEqual(now.name, "Weekend in the hills", "Save put back the trip's name from when the screen opened")
        XCTAssertEqual(now.entries.first { $0.id == atLoad.entries[0].id }?.checked, true, "Save unticked a line")
    }

    /// For the lost-luggage desk (from Settings): the e-mail typed here, the phone changed on the
    /// other device while the screen was open. Both stay.
    func testTheDeskScreenWritesOnlyTheFieldsTypedOnIt() {
        var live = library()
        let opened = DeskDetails(name: "Sam Example", phone: "+46 70 000 00 01", email: "sam@example.com")
        live.setDeskDetails(opened)
        live.setDeskDetails(DeskDetails(name: "Sam Example", phone: "+46 70 000 00 02", email: "sam@example.com"))
        var typed = opened
        typed.email = "sam.new@example.com"

        XCTAssertTrue(live.setDeskDetails(typed, opened: opened))
        XCTAssertEqual(live.deskDetails().email, "sam.new@example.com")
        XCTAssertEqual(live.deskDetails().phone, "+46 70 000 00 02", "Save put back the phone from when the screen opened")
    }

    /// A grab list's Edit: the editor added Fins and marked Towel "1 in 10"; the other device added
    /// a Nose clip and marked Goggles meanwhile. All of it stays.
    func testAGrabListsEditKeepsWhatTheOtherDeviceAddedMeanwhile() {
        var live = library()
        let swim = GRAB_FACTORY[0]
        let opened = live.grabList(id: swim.id)!.lines
        let openedMarks = live.sometimes(listId: swim.id)
        var other = opened
        other.append(.thing("Nose clip"))
        XCTAssertTrue(live.saveGrabEdit(id: swim.id, lines: other, sometimes: ["Goggles"]))
        var edited = opened
        edited.append(.thing("Fins"))

        XCTAssertTrue(live.saveGrabEdit(id: swim.id, opened: opened, openedSometimes: openedMarks, lines: edited, sometimes: ["Towel"]))
        let items = live.grabList(id: swim.id)!.items
        XCTAssertEqual(Array(items.suffix(2)), ["Nose clip", "Fins"], "a thing added on one of the devices was lost: \(items)")
        XCTAssertEqual(Set(live.sometimes(listId: swim.id)), ["Goggles", "Towel"], "a mark was lost")
    }

    /// A kit's own page (Inside, on a thing's page): the page put the Map in the Torch; the other
    /// device the Kettle meanwhile. What the page saves keeps both.
    func testAKitsPageSavesWhatItChangedOntoTheKitAsItIsNow() {
        var live = library()
        let torch = thing(live, "Torch")!.id, map = thing(live, "Map")!.id, kettle = thing(live, "Kettle")!.id
        XCTAssertTrue(live.setKit(kitId: torch, contents: [kettle]))
        let saved = live.kitFromPage(kitId: torch, opened: [], openedOut: [], contents: [map], out: [])
        XCTAssertEqual(saved.contents, [kettle, map], "a thing put in on the other device was lost")
        XCTAssertEqual(saved.out, [])
    }

    /// A bag's page, Cancel: the page renamed a pocket; the other device meanwhile put a line in the
    /// bag's Lid and added a pocket. Cancel undoes the rename and keeps the other device's work.
    func testABagPagesCancelPutsBackOnlyWhatThePageChanged() {
        var lib = Library()
        let bag = lib.addBag(name: "Day pack")!.id
        for p in ["Main", "Lid"] { XCTAssertTrue(lib.addPocket(bagId: bag, name: p)) }
        lib.saveTemplate(newList(name: "Base", role: "base"))
        let base = lib.templates.first { $0.role == "base" }!.id
        let flask = lib.addThing(name: "Flask")!.id
        _ = lib.updateThing(id: flask) { $0.container = "Day pack" }
        _ = lib.setOnTemplate(itemId: flask, templateId: base, on: true)
        let trip = lib.createTrip(newEvent(name: "Away", startDate: "2026-10-19", endDate: "2026-10-21")).id
        let line = lib.trips[0].entries.first { $0.name == "Flask" }!.id
        let kept = lib.keepPockets(bagId: bag)!
        // The page renames Main.
        var trail = PocketsTrail()
        let before = lib.keepPockets(bagId: bag)
        XCTAssertTrue(lib.renamePocket(bagId: bag, from: "Main", to: "Big pocket"))
        trail.add(before: before, after: lib.keepPockets(bagId: bag))
        // The other device, meanwhile.
        XCTAssertTrue(lib.setPocket("Lid", tripId: trip, entryId: line))
        XCTAssertTrue(lib.addPocket(bagId: bag, name: "Side"))

        XCTAssertTrue(lib.putBackPockets(kept, trail: trail))
        XCTAssertEqual(lib.pockets(bagId: bag), ["Main", "Lid", "Side"], "Cancel took away the other device's pocket")
        XCTAssertEqual(Library.pocket(lib.trips[0].entries.first { $0.id == line }!), "Lid", "Cancel took the line out of the pocket the other device put it in")
    }
}
