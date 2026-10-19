import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// Duplicate a thing (0.92 — his yes of 19 Oct 2026: "Duplicate a thing: the same as Duplicate bag, for
/// any thing — handy for near-copies like a second charger or a spare cable"; spec 05, a thing's page
/// 18b). Invented data only — this repository is public.
final class ThingDuplicateTests: XCTestCase {
    override func setUp() { PackingEnv.freeze(at: "2026-10-19T09:00:00.000Z") }
    override func tearDown() { PackingEnv.reset() }

    /// Common base (Passport, Phone charger, Toothbrush) and Hiking — its headings Power (Phone charger,
    /// Power bank) and Lights (Headlamp) — and a Backpack with a Lid pocket. The charger says everything a
    /// thing's page can say; on Hiking its row says its own: two of them, a note, Winter only, and a
    /// web-app kit name. A trip from Hiking by plane in winter, which packs the charger, is still ahead.
    private func library() -> Library {
        var lib = Library()
        var base = newList(name: "Common base", role: "base")
        base.items = [newItem(name: "Passport"), newItem(name: "Phone charger"), newItem(name: "Toothbrush")]
        lib.saveTemplate(base)
        var hiking = newList(name: "Hiking", group: "GA")
        hiking.items = [newItem(name: "Phone charger"), newItem(name: "Power bank"), newItem(name: "Headlamp")]
        lib.saveTemplate(hiking)
        let hikingId = templateId(lib, "Hiking")
        XCTAssertNotNil(lib.addBag(name: "Backpack"))
        XCTAssertTrue(lib.addPocket(bagId: id(lib, "Backpack"), name: "Lid"))
        let power = lib.addSection(templateId: hikingId, name: "Power")!, lights = lib.addSection(templateId: hikingId, name: "Lights")!
        for (name, section) in [("Phone charger", power.id), ("Power bank", power.id), ("Headlamp", lights.id)] {
            XCTAssertTrue(lib.updateMembership(memId: row(lib, name, on: "Hiking").id) { $0.section = section })
        }
        XCTAssertTrue(lib.updateMembership(memId: row(lib, "Phone charger", on: "Hiking").id) {
            $0.qty = "2"; $0.note = "The short cable"; $0.seasons = ["Winter"]; $0.kit = "Old cable kit"
        })
        let charger = id(lib, "Phone charger")
        XCTAssertTrue(lib.setThingLimits(id: charger, TripLimits(transports: ["Plane"])))
        XCTAssertTrue(lib.updateThing(id: charger) {
            $0.category = "Electronics"; $0.ownedBy = "Kim"; $0.storage = "Desk drawer"; $0.container = "Backpack"
            Library.setUsualPocket(&$0, "Lid")
            $0.phase = "prep"; $0.weight = 120; $0.manufacturer = "Exempel"; $0.color = "White"; $0.condition = "good"
            $0.note = "Braided cable"; $0.restricted = true; $0.liquid = false; $0.expiry = "2028-01-31"
            Library.setBattery(&$0, true)
            $0.maintenance = Maintenance(notes: "Check the cable", intervalDays: 180, lastDone: "2026-05-01",
                                         log: [MaintenanceLogEntry(date: "2026-05-01")])
            $0.stats = ItemStats(packed: 4, used: 3, unused: 1); $0.keep = true; $0.serial = "SN-7"
            $0.acquired = "2025-03-01"; $0.price = 199
        })
        XCTAssertNotNil(lib.addThingPhoto(id: charger, jpeg: Data([1, 2, 3])))
        _ = lib.createTrip(newEvent(name: "Hills", activities: [hikingId], transport: "Plane", season: "Winter",
                                    startDate: "2026-11-06", endDate: "2026-11-08"))
        return lib
    }

    private func id(_ lib: Library, _ name: String) -> String { lib.items.first { $0.name == name }!.id }
    private func templateId(_ lib: Library, _ name: String) -> String { lib.templates.first { $0.name == name }!.id }
    private func row(_ lib: Library, _ name: String, on template: String) -> Membership {
        let thing = id(lib, name), list = templateId(lib, template)
        return lib.memberships.first { $0.itemId == thing && $0.templateId == list }!
    }
    /// A template's things as its page reads them by Section: "# Power", "Phone charger", …
    private func page(_ lib: Library, _ template: String) -> [String] {
        var out: [String] = []
        let list = lib.templates.first { $0.name == template }!
        for group in lib.arrangedRows(templateId: list.id) {
            if let s = list.sections.first(where: { $0.id == group.sectionId }) { out.append("# " + s.name) }
            for mem in group.rows {
                let thing = lib.memberships.first { $0.id == mem }!.itemId
                out.append(lib.items.first { $0.id == thing }!.name)
            }
        }
        return out
    }

    func testACopyTakesWhatDescribesTheThingAndItsTemplatesButNotItsPhotosTripsOrCounts() {
        var lib = library()
        let charger = id(lib, "Phone charger")
        let before = lib.items.first { $0.id == charger }!
        guard let copy = lib.duplicateThing(id: charger) else { return XCTFail("the thing was not duplicated") }
        XCTAssertEqual(copy.name, "Phone charger 2")
        XCTAssertNotEqual(copy.id, charger)
        // What describes it came along.
        XCTAssertEqual([copy.category, copy.ownedBy, copy.storage, copy.container, Library.usualPocket(copy), copy.phase],
                       ["Electronics", "Kim", "Desk drawer", "Backpack", "Lid", "prep"],
                       "kind, owner, place, bag, pocket or When was not copied")
        XCTAssertEqual(copy.weight, 120, "the weight was not copied")
        XCTAssertEqual([copy.manufacturer, copy.color, copy.condition, copy.note, copy.expiry],
                       ["Exempel", "White", "good", "Braided cable", "2028-01-31"],
                       "brand, colour, condition, notes or Valid until was not copied")
        XCTAssertTrue(copy.restricted, "On a plane was not copied")
        XCTAssertTrue(Library.hasBattery(copy), "Has a battery was not copied")
        XCTAssertEqual(Library.thingLimits(copy).transports, ["Plane"], "its own Only on some trips was not copied")
        XCTAssertEqual(copy.maintenance?.notes, "Check the cable", "the care was not copied")
        XCTAssertEqual(copy.maintenance?.intervalDays, 180)
        XCTAssertEqual(copy.acquired, "2025-03-01")
        // …and what is the original's alone stayed behind.
        XCTAssertEqual(copy.photos, [], "the photos were copied")
        XCTAssertEqual(lib.thingPhotos(id: copy.id).count, 0)
        XCTAssertEqual(copy.thumb, "")
        XCTAssertEqual(copy.stats, ItemStats(), "the review counts were copied")
        XCTAssertFalse(copy.keep, "Keep it was copied")
        XCTAssertEqual(copy.serial, "", "the serial number was copied")
        XCTAssertEqual(copy.maintenance?.lastDone, "", "the last care was copied")
        XCTAssertEqual(copy.maintenance?.log.count, 0, "the care log was copied")
        // On both its templates, right after the original, with the row's own answers.
        XCTAssertEqual(Set(lib.listsOf(itemId: copy.id)), ["Common base", "Hiking"], "the copy is not on the original's templates")
        XCTAssertEqual(page(lib, "Common base"), ["Passport", "Phone charger", "Phone charger 2", "Toothbrush"])
        XCTAssertEqual(page(lib, "Hiking"), ["# Power", "Phone charger", "Phone charger 2", "Power bank", "# Lights", "Headlamp"],
                       "the copy is not right after the original under its heading")
        let copied = row(lib, "Phone charger 2", on: "Hiking"), original = row(lib, "Phone charger", on: "Hiking")
        XCTAssertNotEqual(copied.id, original.id)
        XCTAssertEqual([copied.qty, copied.note, copied.section], [original.qty, original.note, original.section],
                       "the row's own answers were not copied")
        XCTAssertEqual(copied.seasons, ["Winter"], "the row's own Only on some trips was not copied")
        XCTAssertEqual(copied.kit, "", "the copy joined the original's kit")
        XCTAssertFalse(lib.memberships.contains { $0.itemId == copy.id && $0.templateId == lib.bagList?.id },
                       "a thing's copy became a bag")
        // No trip: the one ahead keeps its lines; a new one from Hiking packs both.
        XCTAssertTrue(lib.trips[0].entries.contains { $0.sourceItemId == charger }, "the trip ahead does not pack the original")
        XCTAssertFalse(lib.trips[0].entries.contains { $0.sourceItemId == copy.id || $0.name == copy.name },
                       "the copy joined a trip already made")
        let next = lib.createTrip(newEvent(name: "Again", activities: [templateId(lib, "Hiking")], transport: "Plane",
                                           season: "Winter", startDate: "2026-12-04", endDate: "2026-12-06"))
        XCTAssertTrue(next.entries.contains { $0.name == "Phone charger" })
        XCTAssertTrue(next.entries.contains { $0.name == "Phone charger 2" }, "a new trip from its template leaves the copy out")
        // The original is as it was.
        XCTAssertEqual(lib.items.first { $0.id == charger }, before, "the original changed")
        XCTAssertEqual(lib.thingPhotos(id: charger).count, 1)
        XCTAssertEqual(original.kit, "Old cable kit")
        // A copy is a thing like any other: kept by the records and a backup, its rows too.
        XCTAssertEqual(Set(Library(records: lib.records()).listsOf(itemId: copy.id)), ["Common base", "Hiking"])
        let restored = try! Importer.read(lib.backupData(exportedAt: "2026-10-19T12:00:00.000Z")).library
        XCTAssertEqual(page(restored, "Hiking"), page(lib, "Hiking"), "a backup lost the copy's place")
    }

    func testACopysNameCountsOnAndAThingTwiceOnATemplateIsCopiedTwice() {
        var lib = library()
        let charger = id(lib, "Phone charger")
        XCTAssertNotNil(lib.addThing(name: "Phone charger 2"))           // a thing already has the name
        XCTAssertEqual(lib.duplicateThing(id: charger)?.name, "Phone charger 3")
        XCTAssertEqual(lib.duplicateThing(id: id(lib, "Phone charger 3"))?.name, "Phone charger 4", "a copy's copy does not count on")
        // Each copy right after the one it was made from: 3 after the charger, 4 after 3.
        // Twice on one template (a second row, under Lights): the copy is twice there too.
        let hiking = templateId(lib, "Hiking")
        let lights = lib.templates.first { $0.id == hiking }!.sections.first { $0.name == "Lights" }!.id
        var twice = newMembership(itemId: id(lib, "Power bank"), templateId: hiking)
        twice.section = lights
        twice.order = 99
        lib.memberships.append(twice)
        let copy = lib.duplicateThing(id: id(lib, "Power bank"))!
        XCTAssertEqual(lib.memberships.filter { $0.itemId == copy.id && $0.templateId == hiking }.count, 2,
                       "a thing twice on a template: its copy is not twice")
        XCTAssertEqual(page(lib, "Hiking"),
                       ["# Power", "Phone charger", "Phone charger 3", "Phone charger 4", "Power bank", "Power bank 2",
                        "# Lights", "Headlamp", "Power bank", "Power bank 2"])
        // A thing on no template: a copy on none.
        let loose = lib.addThing(name: "Spare cable")!
        let looseCopy = lib.duplicateThing(id: loose.id)
        XCTAssertEqual(looseCopy?.name, "Spare cable 2")
        XCTAssertEqual(lib.listsOf(itemId: looseCopy!.id), [])
        XCTAssertNil(lib.duplicateThing(id: "no-such-thing"))
    }

    func testAKitsCopyHoldsNothingAndAThingInAKitIsCopiedOutsideIt() {
        var lib = library()
        let pouch = lib.addThing(name: "Cable pouch")!.id
        XCTAssertTrue(lib.setKit(kitId: pouch, contents: [id(lib, "Power bank")], check: true))
        let kitCopy = lib.duplicateThing(id: pouch)!
        XCTAssertEqual(lib.kitContents(kitId: kitCopy.id).count, 0, "the kit's copy took what is inside the original")
        XCTAssertNil(kitCopy.extra[KIT_CONTENTS_KEY])
        XCTAssertNil(kitCopy.extra[KIT_CHECK_KEY])
        XCTAssertEqual(lib.kitContents(kitId: pouch).map(\.thing.name), ["Power bank"], "the original kit lost its contents")
        let inside = lib.duplicateThing(id: id(lib, "Power bank"))!
        XCTAssertNil(lib.kitHolding(thingId: inside.id), "the copy went into the original's kit")
        XCTAssertEqual(lib.kitHolding(thingId: id(lib, "Power bank"))?.id, pouch)
    }

    func testABagDuplicatedAsAThingGoesTheBagsWay() {
        var lib = library()
        let backpack = id(lib, "Backpack")
        // The Backpack is also packed on Hiking as a thing.
        XCTAssertTrue(lib.setOnTemplate(itemId: backpack, templateId: templateId(lib, "Hiking"), on: true))
        let copy = lib.duplicateThing(id: backpack)!
        XCTAssertEqual(copy.name, "Backpack 2")
        XCTAssertEqual(lib.bags().map(\.name), ["Backpack", "Backpack 2"], "the bag's copy is not on Your bags after it")
        XCTAssertEqual(lib.listsOf(itemId: copy.id), ["Bags"], "a bag's copy joined its templates as a thing")
        XCTAssertEqual(lib.pockets(bagId: copy.id), ["Lid"], "the bag's pockets were not copied")
    }
}
