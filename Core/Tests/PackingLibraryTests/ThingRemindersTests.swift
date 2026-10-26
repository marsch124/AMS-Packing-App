import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// Reminders on things (0.101, spec 07 part 21 — his yes to the picture, 26 Oct 2026): A, short
/// reminders on a thing, each with a When, on the trips where the thing is; B, the things that go
/// with it, brought onto the trip as their own lines. Invented names only.
final class ThingRemindersTests: XCTestCase {
    override func setUp() { PackingEnv.freeze(at: "2026-10-01T12:00:00.000Z") }
    override func tearDown() { PackingEnv.reset() }

    /// "Photo trip" holds the Camera; "Travel" the Laptop, the Toothbrush and the Charger. The
    /// USB-C cable, the Spare battery and the Tripod are on no template. The Camera has two
    /// reminders and three things that go with it.
    static func library() -> Library {
        var lib = Library()
        var photo = newList(name: "Photo trip", group: "GA")
        photo.items = [newItem(name: "Camera", container: "Carry-on / hand luggage", phase: "week")]
        lib.saveTemplate(photo)
        var travel = newList(name: "Travel", group: "WET")
        let desk = TemplateSection(name: "Office desk")
        travel.sections = [desk]
        var laptop = newItem(name: "Laptop", container: "Backpack"); laptop.section = desk.id
        travel.items = [laptop, newItem(name: "Toothbrush", container: "Wash bag"), newItem(name: "Charger", container: "Backpack")]
        lib.saveTemplate(travel)
        for name in ["USB-C cable", "Spare battery", "Tripod"] { _ = lib.addThing(name: name) }
        _ = lib.updateThing(id: id(lib, "Spare battery")) { $0.container = "Wash bag"; $0.phase = "daybefore" }
        _ = lib.updateThing(id: id(lib, "USB-C cable")) { $0.container = "Backpack" }
        _ = lib.updateThing(id: id(lib, "Camera")) { cam in
            Library.setThingReminders(&cam, [ThingReminder(id: "r-sd", text: "Empty the SD card", when: "week"),
                                             ThingReminder(id: "r-bat", text: "Charge the spare battery", when: "daybefore")])
        }
        goes(&lib, "Camera", ["USB-C cable", "Charger", "Spare battery"])
        return lib
    }

    static func id(_ lib: Library, _ name: String) -> String { lib.items.first { $0.name == name }!.id }

    /// `thing` goes with these (by name).
    static func goes(_ lib: inout Library, _ thing: String, _ with: [String]) {
        let ids = with.map { id(lib, $0) }
        _ = lib.updateThing(id: id(lib, thing)) { Library.setGoesWith(&$0, ids) }
    }
    private func id(_ lib: Library, _ name: String) -> String { ThingRemindersTests.id(lib, name) }
    private func template(_ lib: Library, _ name: String) -> String { lib.templates.first { $0.name == name }!.id }

    /// A trip from the templates named, starting `start`.
    @discardableResult
    private func trip(_ lib: inout Library, _ names: [String], start: String = "2026-10-10") -> TripEvent {
        var draft = newEvent(name: "Torremolinos", startDate: start, endDate: "2026-10-14")
        draft.activities = names.map { template(lib, $0) }
        return lib.createTrip(draft)
    }

    private func line(_ lib: Library, _ tripId: String, _ name: String) -> Item? {
        lib.trips.first { $0.id == tripId }?.entries.first { $0.name == name }
    }

    private func with(_ lib: Library, _ tripId: String, _ name: String) -> [String] {
        line(lib, tripId, name).map { lib.withNames($0) } ?? []
    }

    // MARK: - On the thing

    func testAThingsRemindersAndWhatGoesWithItAreKeptInItsOwnRecord() throws {
        let lib = ThingRemindersTests.library()
        let cam = lib.items.first { $0.name == "Camera" }!
        XCTAssertEqual(Library.thingReminders(cam).map(\.text), ["Empty the SD card", "Charge the spare battery"])
        XCTAssertEqual(Library.thingReminders(cam).map(\.when), ["week", "daybefore"])
        XCTAssertEqual(lib.companions(of: cam.id).map(\.name), ["USB-C cable", "Charger", "Spare battery"], "his order")
        // Nothing new for the web app: the keys ride through its own reading of a thing.
        XCTAssertEqual(coerceItem(cam).extra[THING_REMINDERS_KEY], cam.extra[THING_REMINDERS_KEY])
        XCTAssertEqual(coerceItem(cam).extra[GOES_WITH_KEY], cam.extra[GOES_WITH_KEY])
        XCTAssertEqual(Item(json: cam.json), cam)
        // Read leniently: an entry without words, a second of one id, the thing itself, are dropped.
        var odd = cam
        odd.extra[THING_REMINDERS_KEY] = .array([ThingReminder(id: "a", text: "Wipe the lens", when: "week").json,
                                                 .object(["id": .string("b"), "text": .string("  ")]),
                                                 ThingReminder(id: "a", text: "Again", when: "week").json])
        odd.extra[GOES_WITH_KEY] = JSONValue([cam.id, "x", "x", ""])
        XCTAssertEqual(Library.thingReminders(odd).map(\.text), ["Wipe the lens"])
        XCTAssertEqual(Library.goesWith(odd), ["x"])
        // Written empty, the keys go.
        Library.setThingReminders(&odd, []); Library.setGoesWith(&odd, [])
        XCTAssertNil(odd.extra[THING_REMINDERS_KEY]); XCTAssertNil(odd.extra[GOES_WITH_KEY])
    }

    func testAReminderNeedsWordsOnceAndStartsAtTheLastOnesWhen() throws {
        let list = [ThingReminder(id: "1", text: "Empty the SD card", when: "week")]
        XCTAssertEqual(Library.thingReminderProblem("  ", others: list), "Type the reminder first.")
        XCTAssertEqual(Library.thingReminderProblem("empty the sd CARD", others: list), "This thing has that reminder already.")
        XCTAssertNil(Library.thingReminderProblem("Empty the SD card", others: list, except: "1"), "its own words, renamed in place")
        XCTAssertNil(Library.thingReminderProblem("Wipe the lens", others: list))
        XCTAssertEqual(Library.whenForNewThingReminder(list), "week", "the last one's When")
        XCTAssertEqual(Library.whenForNewThingReminder([]), "daybefore", "else the day before")
        // The things that can go with it: his things, not itself, not a bag, not one chosen already.
        var lib = ThingRemindersTests.library()
        lib.addBag(name: "Backpack")
        let offered = lib.goesWithCandidates(thingId: id(lib, "Camera"), chosen: [id(lib, "Tripod")]).map(\.name)
        XCTAssertFalse(offered.contains("Camera")); XCTAssertFalse(offered.contains("Tripod")); XCTAssertFalse(offered.contains("Backpack"))
        XCTAssertTrue(offered.contains("USB-C cable"))
        XCTAssertEqual(offered, offered.sorted { $0.lowercased() < $1.lowercased() }, "A–Z")
    }

    // MARK: - Store, backup, the page's Save

    func testRemindersCompanionsAndTheirTicksSurviveTheStoreAndABackup() throws {
        var lib = ThingRemindersTests.library()
        let t = trip(&lib, ["Photo trip"])
        let camLine = try XCTUnwrap(line(lib, t.id, "Camera"))
        XCTAssertTrue(lib.setThingReminderDone(true, tripId: t.id, lineId: camLine.id, reminderId: "r-bat"))
        // The store and iCloud: records and back.
        let stored = Library(records: lib.records())
        XCTAssertEqual(stored.items.first { $0.name == "Camera" }, lib.items.first { $0.name == "Camera" })
        XCTAssertEqual(stored.trips, lib.trips, "the tick and the \u{201C}with\u{201D} marks on the lines")
        XCTAssertEqual(stored.thingReminders(tripId: t.id), lib.thingReminders(tripId: t.id))
        // A backup file, read back as Settings reads it — as this app writes it, and the older kind.
        for data in [lib.backupData(exportedAt: "2026-10-07T09:00:00.000Z"),
                     BackupTests.olderFile(lib, exportedAt: "2026-10-07T09:00:00.000Z")] {
            let (back, report) = try BackupTests.read(data)
            XCTAssertTrue(report.isFaithful, report.mismatches.joined(separator: "; "))
            let cam = back.items.first { $0.name == "Camera" }!
            XCTAssertEqual(Library.thingReminders(cam).map(\.text), ["Empty the SD card", "Charge the spare battery"])
            XCTAssertEqual(back.companions(of: cam.id).map(\.name), ["USB-C cable", "Charger", "Spare battery"])
            XCTAssertEqual(back.thingReminders(tripId: t.id)[camLine.id]?.map(\.done), [false, true], "the tick came back")
            XCTAssertEqual(with(back, t.id, "Spare battery"), ["Camera"])
        }
    }

    func testThePagesSaveKeepsWhatTheOtherDeviceAddedMeanwhile() throws {
        var lib = ThingRemindersTests.library()
        let cam = id(lib, "Camera")
        let opened = Library.thingReminders(lib.items.first { $0.id == cam }!)
        let openedWith = Library.goesWith(lib.items.first { $0.id == cam }!)
        // The Mac adds a reminder and the Tripod while the iPhone's page is open.
        let tripod = id(lib, "Tripod")
        _ = lib.updateThing(id: cam) { c in
            Library.setThingReminders(&c, Library.thingReminders(c) + [ThingReminder(id: "r-mac", text: "Pack the lens hood", when: "week")])
            Library.setGoesWith(&c, Library.goesWith(c) + [tripod])
        }
        // The iPhone's page: one reminder reworded, one removed, one added; the charger taken off.
        var page = opened
        page[0].text = "Empty both SD cards"
        page.remove(at: 1)
        page.append(ThingReminder(id: "r-phone", text: "Lens cloth in the bag", when: "morning"))
        let pageWith = openedWith.filter { $0 != id(lib, "Charger") }
        XCTAssertTrue(lib.saveThingRemembers(id: cam, openedReminders: opened, reminders: page, openedWith: openedWith, with: pageWith))
        let now = lib.items.first { $0.id == cam }!
        XCTAssertEqual(Library.thingReminders(now).map(\.text), ["Empty both SD cards", "Pack the lens hood", "Lens cloth in the bag"],
                       "a reminder added on each device both stay")
        XCTAssertEqual(lib.companions(of: cam).map(\.name), ["USB-C cable", "Spare battery", "Tripod"], "a companion added on each device both stay")
        // Nothing changed on the page: nothing written.
        XCTAssertFalse(lib.saveThingRemembers(id: cam, openedReminders: page, reminders: page, openedWith: pageWith, with: pageWith))

        // A template's page (0.95's merge) that touched the Camera keeps the other device's lists too.
        let from = lib
        var to = lib
        _ = to.updateThing(id: cam) { c in
            Library.setThingReminders(&c, Library.thingReminders(c).filter { $0.id != "r-mac" })
            c.note = "Grey case"
        }
        var live = lib
        let laptop = id(lib, "Laptop")
        _ = live.updateThing(id: cam) { c in
            Library.setGoesWith(&c, Library.goesWith(c) + [laptop])
            Library.setThingReminders(&c, Library.thingReminders(c) + [ThingReminder(id: "r-x", text: "Format the card", when: "week")])
        }
        let merged = live.applyingPage(from: from, to: to).items.first { $0.id == cam }!
        XCTAssertEqual(Library.thingReminders(merged).map(\.text), ["Empty both SD cards", "Lens cloth in the bag", "Format the card"])
        XCTAssertEqual(Library.goesWith(merged).count, 4, "the Laptop added on the other device stays")
        XCTAssertEqual(merged.note, "Grey case")

        // A line's ticks as a list too (a page's follow onto the trip ahead).
        var tl = ThingRemindersTests.library()
        let t = trip(&tl, ["Photo trip"])
        let camLine = try XCTUnwrap(line(tl, t.id, "Camera")).id
        let before = tl
        var after = tl
        after.setThingReminderDone(true, tripId: t.id, lineId: camLine, reminderId: "r-sd")
        var here = tl
        here.setThingReminderDone(true, tripId: t.id, lineId: camLine, reminderId: "r-bat")
        let ticks = here.applyingPage(from: before, to: after).thingReminders(tripId: t.id)[camLine]?.map(\.done)
        XCTAssertEqual(ticks, [true, true], "a tick on each device both stay")
    }

    // MARK: - A · reminders on a trip

    func testAThingsRemindersAreOnlyOnTripsWhereTheThingIs() throws {
        var lib = ThingRemindersTests.library()
        let photo = trip(&lib, ["Photo trip"])
        let travel = trip(&lib, ["Travel"])
        let camLine = try XCTUnwrap(line(lib, photo.id, "Camera"))
        let on = lib.thingReminders(tripId: photo.id)
        XCTAssertEqual(on.keys.sorted(), [camLine.id], "the camera's line carries them")
        XCTAssertEqual(on[camLine.id]?.map(\.name), ["Camera: Empty the SD card", "Camera: Charge the spare battery"])
        XCTAssertTrue(lib.thingReminders(tripId: travel.id).isEmpty, "no camera, no camera reminders")
        // Set aside ("not this time"): none.
        var aside = lib
        aside.setAside(true, tripId: photo.id, entryId: camLine.id)
        XCTAssertTrue(aside.thingReminders(tripId: photo.id).isEmpty)
        // A reviewed trip: none.
        var done = lib
        done.trips[0].status = "done"
        XCTAssertTrue(done.thingReminders(tripId: photo.id).isEmpty)
        // Typed on the trip by its name: the camera is on it.
        var typed = lib
        let custom = try XCTUnwrap(typed.addCustomLine(tripId: travel.id, name: "camera"))
        XCTAssertEqual(typed.thingReminders(tripId: travel.id)[custom.id]?.count, 2)
        // Inside a kit on the trip: under the kit's line, in the camera's own name.
        var kit = ThingRemindersTests.library()
        let bag = try XCTUnwrap(kit.addThing(name: "Camera bag"))
        kit.setOnTemplate(itemId: bag.id, templateId: template(kit, "Travel"), on: true)
        kit.setKit(kitId: bag.id, contents: [id(kit, "Camera")])
        let kt = trip(&kit, ["Travel"])
        let bagLine = try XCTUnwrap(line(kit, kt.id, "Camera bag"))
        XCTAssertNil(line(kit, kt.id, "Camera"), "a thing in a kit is no line of its own")
        XCTAssertEqual(kit.thingReminders(tripId: kt.id)[bagLine.id]?.map(\.name).first, "Camera: Empty the SD card")
    }

    func testAThingReminderIsDueAtItsWhenAndTickedOnceForTheTrip() throws {
        var lib = ThingRemindersTests.library()
        let t = trip(&lib, ["Photo trip"], start: "2026-10-10")
        let camLine = try XCTUnwrap(line(lib, t.id, "Camera")).id
        XCTAssertEqual(lib.dueThingReminders(tripId: t.id, today: "2026-10-02").count, 0, "eight days ahead: none yet")
        XCTAssertEqual(lib.dueThingReminders(tripId: t.id, today: "2026-10-03").map(\.name), ["Camera: Empty the SD card"], "a week ahead")
        XCTAssertEqual(lib.dueThingReminders(tripId: t.id, today: "2026-10-09").map(\.name),
                       ["Camera: Empty the SD card", "Camera: Charge the spare battery"], "the day before, in the timeline's order")
        // In Before you go's To do and Home's countdown, with the template reminders.
        let card = lib.beforeYouGo(tripId: t.id, today: "2026-10-09")
        XCTAssertEqual(card.thingDue.count, 2)
        XCTAssertTrue(card.hasToDo)
        XCTAssertGreaterThanOrEqual(card.left, 2)
        XCTAssertEqual(lib.nextTrip(today: "2026-10-09")?.due.suffix(2), ["Camera: Empty the SD card", "Camera: Charge the spare battery"])
        // ONE tick for the trip: under the line or in Before you go — the same stored state.
        XCTAssertTrue(lib.setThingReminderDone(true, tripId: t.id, lineId: camLine, reminderId: "r-sd"))
        XCTAssertEqual(lib.dueThingReminders(tripId: t.id, today: "2026-10-09").map(\.name), ["Camera: Charge the spare battery"])
        XCTAssertEqual(lib.thingReminders(tripId: t.id)[camLine]?.map(\.done), [true, false])
        XCTAssertEqual(lib.trips[0].entries.first { $0.id == camLine }?.extra[REMINDERS_DONE_KEY], JSONValue(["r-sd"]))
        lib.setThingReminderDone(false, tripId: t.id, lineId: camLine, reminderId: "r-sd")
        XCTAssertNil(lib.trips[0].entries.first { $0.id == camLine }?.extra[REMINDERS_DONE_KEY], "unticked: no key")
        // Undated: never due, still on the line.
        var undated = ThingRemindersTests.library()
        let u = trip(&undated, ["Photo trip"], start: "")
        XCTAssertTrue(undated.dueThingReminders(tripId: u.id, today: "2026-10-09").isEmpty)
        XCTAssertEqual(undated.thingReminders(tripId: u.id).values.first?.count, 2)
        // Start again: a clean list. A shared trip: his ticks and marks stay his.
        lib.setThingReminderDone(true, tripId: t.id, lineId: camLine, reminderId: "r-sd")
        let again = try XCTUnwrap(lib.startAgain(from: t.id, name: "Again"))
        XCTAssertTrue(again.entries.allSatisfy { $0.extra[REMINDERS_DONE_KEY] == nil })
        let shared = Library.justTheList(lib.trips[0])
        XCTAssertTrue(shared.entries.allSatisfy { $0.extra[REMINDERS_DONE_KEY] == nil && $0.extra[WITH_THINGS_KEY] == nil })
    }

    // MARK: - B · what goes with it

    func testWhatGoesWithAThingComesAlongAsItsOwnLines() throws {
        var lib = ThingRemindersTests.library()
        let t = trip(&lib, ["Photo trip"])
        XCTAssertEqual(lib.trips[0].entries.map(\.name), ["Camera", "USB-C cable", "Charger", "Spare battery"])
        let battery = try XCTUnwrap(line(lib, t.id, "Spare battery"))
        XCTAssertEqual(battery.container, "Wash bag", "its own bag")
        XCTAssertEqual(battery.phase, "daybefore", "its own When")
        XCTAssertEqual(battery.sourceItemId, id(lib, "Spare battery"))
        XCTAssertFalse(battery.custom)
        XCTAssertEqual(line(lib, t.id, "Charger")?.container, "Backpack")
        XCTAssertEqual(line(lib, t.id, "Charger")?.section, "", "the charger has no section on Travel")
        // Its own section: the one its first template gives it.
        var desk = ThingRemindersTests.library()
        ThingRemindersTests.goes(&desk, "Camera", ["Laptop"])
        let d = trip(&desk, ["Photo trip"])
        XCTAssertEqual(line(desk, d.id, "Laptop")?.section, "Office desk")
        XCTAssertEqual(line(desk, d.id, "Laptop")?.container, "Backpack")
        XCTAssertEqual(with(lib, t.id, "USB-C cable"), ["Camera"])
        // On a template of the trip already: once, and no mark — the template has it.
        var both = ThingRemindersTests.library()
        let b = trip(&both, ["Photo trip", "Travel"])
        XCTAssertEqual(both.trips[0].entries.filter { $0.name == "Charger" }.count, 1)
        XCTAssertEqual(with(both, b.id, "Charger"), [], "the template brought it")
        XCTAssertEqual(line(both, b.id, "Laptop")?.section, "Office desk")
        // Brought by two things: one line, naming both. One level: what goes with a companion is not followed.
        var two = ThingRemindersTests.library()
        ThingRemindersTests.goes(&two, "Tripod", ["Camera"])
        ThingRemindersTests.goes(&two, "Spare battery", ["Tripod"])
        ThingRemindersTests.goes(&two, "Toothbrush", ["USB-C cable"])
        let tt = trip(&two, ["Photo trip", "Travel"])
        XCTAssertNil(line(two, tt.id, "Tripod"), "no chain: the spare battery came along, its own companions do not")
        XCTAssertEqual(with(two, tt.id, "USB-C cable"), ["Camera", "Toothbrush"])
        XCTAssertEqual(two.trips[0].entries.filter { $0.name == "USB-C cable" }.count, 1)
        // A thing inside a kit comes as its kit; what goes with a kit's content comes along.
        var kit = ThingRemindersTests.library()
        let pouch = try XCTUnwrap(kit.addThing(name: "Cable pouch"))
        kit.setKit(kitId: pouch.id, contents: [id(kit, "USB-C cable")])
        let bag = try XCTUnwrap(kit.addThing(name: "Camera bag"))
        kit.setOnTemplate(itemId: bag.id, templateId: template(kit, "Travel"), on: true)
        kit.setKit(kitId: bag.id, contents: [id(kit, "Camera")])
        let kt = trip(&kit, ["Travel"])
        XCTAssertNil(line(kit, kt.id, "USB-C cable"), "inside a kit: never a line of its own")
        XCTAssertEqual(with(kit, kt.id, "Cable pouch"), ["Camera"], "its kit came, with the camera in the camera bag")
        XCTAssertEqual(with(kit, kt.id, "Spare battery"), ["Camera"])
    }

    func testTakingAThingOffTakesWhatCameWithItUnlessSomethingElseNeedsIt() throws {
        var lib = ThingRemindersTests.library()
        // The Tripod also goes with the Toothbrush (on Travel), and the spare battery is typed by him.
        ThingRemindersTests.goes(&lib, "Toothbrush", ["USB-C cable"])
        let t = trip(&lib, ["Photo trip", "Travel"])
        let typed = try XCTUnwrap(lib.addCustomLine(tripId: t.id, name: "Spare battery"))
        XCTAssertEqual(lib.bringCompanions(tripId: t.id), 0, "everything is there")
        // The battery came along, the camera ticked it: kept when the camera goes, mark gone.
        _ = lib.setChecked(true, tripId: t.id, entryId: try XCTUnwrap(line(lib, t.id, "Spare battery")).id)
        // Photo trip off the trip: the camera goes.
        let travelId = template(lib, "Travel")
        let rebuilt = lib.changeTrip(id: t.id) { $0.activities = [travelId] }
        XCTAssertNotNil(rebuilt)
        let names = lib.trips[0].entries.map(\.name)
        XCTAssertFalse(names.contains("Camera"))
        XCTAssertTrue(names.contains("USB-C cable"), "the toothbrush still needs it")
        XCTAssertEqual(with(lib, t.id, "USB-C cable"), ["Toothbrush"], "only what still brings it is named")
        XCTAssertTrue(names.contains("Charger"), "Travel has it")
        XCTAssertEqual(lib.trips[0].entries.filter { $0.name == "Spare battery" }.count, 2, "his own line, and the one packed")
        XCTAssertTrue(lib.trips[0].entries.contains { $0.id == typed.id }, "the line he typed stays")
        XCTAssertTrue(lib.trips[0].entries.filter { $0.name == "Spare battery" && !$0.custom }.allSatisfy { $0.checked && lib.withNames($0).isEmpty },
                      "the packed one stays, nothing brings it now")
        // Nothing else needs it: it goes with the camera.
        var alone = ThingRemindersTests.library()
        let a = trip(&alone, ["Photo trip", "Travel"])
        XCTAssertTrue(alone.trips[0].entries.contains { $0.name == "USB-C cable" })
        let aloneTravel = template(alone, "Travel"), alonePhoto = template(alone, "Photo trip")
        alone.changeTrip(id: a.id) { $0.activities = [aloneTravel] }
        XCTAssertFalse(alone.trips[0].entries.contains { $0.name == "USB-C cable" || $0.name == "Spare battery" },
                       "what came with the camera went with it: \(alone.trips[0].entries.map(\.name))")
        // And back: the camera's template ticked again brings them again.
        alone.changeTrip(id: a.id) { $0.activities = [aloneTravel, alonePhoto] }
        XCTAssertEqual(with(alone, a.id, "USB-C cable"), ["Camera"])
        // Added by hand ("Add a thing"): its companions come too.
        var hand = ThingRemindersTests.library()
        let h = trip(&hand, ["Travel"])
        _ = hand.addCustomLine(tripId: h.id, name: "Camera")
        XCTAssertEqual(hand.bringCompanions(tripId: h.id), 2, "the cable and the battery; the charger is there")
        XCTAssertEqual(with(hand, h.id, "Spare battery"), ["Camera"])
        // ⊘ "not this time" on the camera: what came only with it is set aside too; ↻ brings it back.
        var skip = ThingRemindersTests.library()
        ThingRemindersTests.goes(&skip, "Toothbrush", ["USB-C cable"])
        let s = trip(&skip, ["Photo trip", "Travel"])
        let cam = try XCTUnwrap(line(skip, s.id, "Camera")).id
        skip.setAside(true, tripId: s.id, entryId: cam)
        XCTAssertTrue(try XCTUnwrap(line(skip, s.id, "Spare battery")).skipped, "only the camera needed it")
        XCTAssertFalse(try XCTUnwrap(line(skip, s.id, "USB-C cable")).skipped, "the toothbrush still needs it")
        XCTAssertFalse(try XCTUnwrap(line(skip, s.id, "Charger")).skipped, "Travel has it")
        skip.setAside(false, tripId: s.id, entryId: cam)
        XCTAssertFalse(try XCTUnwrap(line(skip, s.id, "Spare battery")).skipped)
    }
}
