import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// His four bag asks of 19 Oct 2026 (0.90; spec 05, Care → Bags and a bag's page): sorting Your
/// bags, a bag's Notes, and duplicating a bag. Invented data only — this repository is public.
final class BagSortingTests: XCTestCase {
    override func tearDown() { PackingEnv.reset() }

    /// The clock at `iso`, ids made from it as the app makes them (the web app's own form).
    private func at(_ iso: String) {
        let date = ISO8601DateFormatter().date(from: iso)!
        PackingEnv.now = { date }
        PackingEnv.makeId = { PackingEnv.defaultMakeId() }
    }

    /// Four bags, made on four days: the Sports bag (1 Sep), the Camera bag (2 Sep), the Wheeled duffel
    /// (3 Sep), the Backpack (4 Sep) — arranged by him as Wheeled duffel, Sports bag, Backpack, Camera bag.
    /// Trips: Old coast (10 Aug, a swimsuit in the Sports bag), Autumn (1 Oct, a lens in the Camera bag,
    /// the Backpack put on by "+ Add a bag"), Mountains (20 Nov, the lens again).
    private func library() -> Library {
        var lib = Library()
        for (day, name) in [("01", "Sports bag"), ("02", "Camera bag"), ("03", "Wheeled duffel"), ("04", "Backpack")] {
            at("2026-09-\(day)T10:00:00Z")
            XCTAssertNotNil(lib.addBag(name: name))
        }
        at("2026-09-05T10:00:00Z")
        XCTAssertTrue(lib.moveBag(named: "Wheeled duffel", by: -1))
        XCTAssertTrue(lib.moveBag(named: "Wheeled duffel", by: -1))
        XCTAssertTrue(lib.moveBag(named: "Backpack", by: -1))
        var swim = newList(name: "Swim")
        swim.items = [newItem(name: "Swimsuit", container: "Sports bag")]
        lib.saveTemplate(swim)
        var photo = newList(name: "Photo")
        photo.items = [newItem(name: "Lens", container: "Camera bag")]
        lib.saveTemplate(photo)
        let swimId = lib.templates.first { $0.name == "Swim" }!.id, photoId = lib.templates.first { $0.name == "Photo" }!.id
        _ = lib.createTrip(newEvent(name: "Old coast", activities: [swimId], startDate: "2026-08-10", endDate: "2026-08-12"))
        let autumn = lib.createTrip(newEvent(name: "Autumn", activities: [photoId], startDate: "2026-10-01", endDate: "2026-10-03")).id
        XCTAssertTrue(lib.addBagToTrip(tripId: autumn, bag: "Backpack"))
        _ = lib.createTrip(newEvent(name: "Mountains", activities: [photoId], startDate: "2026-11-20", endDate: "2026-11-22"))
        return lib
    }

    private func names(_ bags: [Item]) -> [String] { bags.map(\.name) }
    private func id(_ lib: Library, _ name: String) -> String { lib.items.first { $0.name == name }!.id }

    // MARK: - Sort

    func testYourBagsSortByOwnOrderNameUseAndWhenAdded() {
        let lib = library()
        XCTAssertEqual(names(lib.sortedBags(.own)), ["Wheeled duffel", "Sports bag", "Backpack", "Camera bag"],
                       "Own order is not the order he arranged")
        XCTAssertEqual(names(lib.sortedBags(.name)), ["Backpack", "Camera bag", "Sports bag", "Wheeled duffel"])
        // The newest trip each went on — a trip ahead counts; "+ Add a bag" counts; never on a trip: last.
        XCTAssertEqual(names(lib.sortedBags(.used)), ["Camera bag", "Backpack", "Sports bag", "Wheeled duffel"],
                       "Last used is not by the newest trip")
        XCTAssertEqual(lib.bagLastTrips()[normName("Camera bag")], "2026-11-20")
        XCTAssertEqual(names(lib.sortedBags(.added)), ["Backpack", "Wheeled duffel", "Camera bag", "Sports bag"],
                       "Last added is not by when each joined Your bags")
        // Nothing edited yet: Last edited is when each was added.
        XCTAssertEqual(names(lib.sortedBags(.edited)), names(lib.sortedBags(.added)))
        XCTAssertEqual(BagSort.allCases.map(\.label), ["Own order", "A\u{2013}Z", "Last used", "Last added", "Last edited"])
    }

    func testBagsWithNoAnswerOrTheSameAnswerKeepHisOwnOrder() {
        var lib = library()
        // Two more bags moved in at one moment (the web app's move): a tie, in his order.
        at("2026-09-06T10:00:00Z")
        let frozen = PackingEnv.now
        PackingEnv.makeId = { String(Int64(frozen().timeIntervalSince1970 * 1000), radix: 36) + "-0-same" }
        XCTAssertNotNil(lib.addBag(name: "Zip pouch"))
        PackingEnv.makeId = { String(Int64(frozen().timeIntervalSince1970 * 1000), radix: 36) + "-1-same" }
        XCTAssertNotNil(lib.addBag(name: "Admin pouch"))
        XCTAssertEqual(Array(names(lib.sortedBags(.added)).prefix(2)), ["Zip pouch", "Admin pouch"],
                       "two bags added at one moment did not keep his order")
        // An id that is no time ("id-7", the parity checker's): last.
        PackingEnv.makeId = { "id-7" }
        XCTAssertNotNil(lib.addBag(name: "Old tote"))
        XCTAssertEqual(names(lib.sortedBags(.added)).last, "Old tote")
        XCTAssertNil(Library.idTime("id-7"))
        XCTAssertNil(Library.idTime("zzzzzzzzzzzz-0-x"), "a time past 2100 is no time")
        XCTAssertEqual(Library.idTime(String(Int64(1_789_000_000_000), radix: 36) + "-0-abc"), jsISOString(Date(timeIntervalSince1970: 1_789_000_000)))
        // Never used: the never-used keep his order at the end.
        XCTAssertEqual(Array(names(lib.sortedBags(.used)).suffix(4)), ["Wheeled duffel", "Zip pouch", "Admin pouch", "Old tote"])
    }

    func testABagIsStampedWhenItChangesButNotForItsReviewCounts() {
        var lib = library()
        // His max weight on the Sports bag, on 5 Oct: Last edited puts it first.
        var before = lib
        XCTAssertTrue(lib.setBag(id: id(lib, "Sports bag"), maxKg: 20))
        XCTAssertEqual(lib.stampEditedBags(since: before, at: "2026-10-05T08:00:00.000Z"), 1)
        XCTAssertEqual(Library.bagEditedAt(lib.items.first { $0.name == "Sports bag" }!), "2026-10-05T08:00:00.000Z")
        XCTAssertEqual(names(lib.sortedBags(.edited)), ["Sports bag", "Backpack", "Wheeled duffel", "Camera bag"],
                       "Last edited does not put the bag just changed first")
        // A note on the Camera bag, on 6 Oct.
        before = lib
        XCTAssertTrue(lib.setThingNote(id: id(lib, "Camera bag"), "  Fits the long lens  "))
        XCTAssertEqual(lib.stampEditedBags(since: before, at: "2026-10-06T08:00:00.000Z"), 1)
        XCTAssertEqual(names(lib.sortedBags(.edited)).first, "Camera bag")
        // Not an edit: its review counts (a trip's review writes them), a thing that is no bag, a new bag.
        before = lib
        XCTAssertTrue(lib.updateThing(id: id(lib, "Backpack")) { $0.stats = ItemStats(packed: 3, used: 2) })
        XCTAssertTrue(lib.updateThing(id: id(lib, "Lens")) { $0.weight = 900 })
        at("2026-10-07T10:00:00Z")
        XCTAssertNotNil(lib.addBag(name: "Gym bag"))
        XCTAssertEqual(lib.stampEditedBags(since: before, at: "2026-10-07T08:00:00.000Z"), 0, "stamped what he did not edit")
        XCTAssertNil(Library.bagEditedAt(lib.items.first { $0.name == "Gym bag" }!))
        XCTAssertEqual(names(lib.sortedBags(.edited)).first, "Gym bag", "a new bag does not count as edited when added")
        // Synced (the store's records) and in a backup: the stamp and the rows' moments stay.
        let stored = Library(records: lib.records())
        XCTAssertEqual(names(stored.sortedBags(.edited)), names(lib.sortedBags(.edited)), "the records lost when a bag was edited")
        XCTAssertEqual(names(stored.sortedBags(.added)), names(lib.sortedBags(.added)), "the records lost when a bag was added")
        let restored = try! Importer.read(lib.backupData(exportedAt: "2026-10-08T12:00:00.000Z")).library
        XCTAssertEqual(names(restored.sortedBags(.edited)), names(lib.sortedBags(.edited)), "a backup lost when a bag was edited")
        XCTAssertEqual(names(restored.sortedBags(.added)), names(lib.sortedBags(.added)), "a backup lost when a bag was added")
        XCTAssertEqual(names(restored.sortedBags(.used)), names(lib.sortedBags(.used)))
    }

    // MARK: - Notes

    func testABagsNotesAreItsThingsOwnAndSearchFindsThem() {
        var lib = library()
        let duffel = id(lib, "Wheeled duffel")
        XCTAssertTrue(lib.setThingNote(id: duffel, "Zip sticks — use the wax\nStrap in the side pocket "))
        XCTAssertEqual(lib.items.first { $0.id == duffel }!.note, "Zip sticks — use the wax\nStrap in the side pocket",
                       "the bag's Notes are not its thing's own note")
        XCTAssertEqual(lib.noteHits("the wax")[duffel]?.line, "Zip sticks — use the wax", "Search does not find the bag by its Notes")
        XCTAssertNil(lib.noteHits("the wax")[duffel]?.template)
        XCTAssertFalse(lib.setThingNote(id: "nobody", "x"))
        XCTAssertEqual(Library(records: lib.records()).items.first { $0.id == duffel }!.note,
                       "Zip sticks — use the wax\nStrap in the side pocket", "the records lost the bag's Notes")
    }

    // MARK: - Duplicate

    func testADuplicateTakesEverythingThatDescribesTheBagButNotItsPhotosTripsOrContents() {
        var lib = library()
        let duffel = id(lib, "Wheeled duffel")
        XCTAssertTrue(lib.setBag(id: duffel, maxKg: 23, capacityL: 90, emptyGrams: 3400))
        XCTAssertTrue(lib.setBagDetails(BagDetails(brand: "Exempel", colour: "Black", type: .duffel, size: .large,
                                                   sizeNote: "80 × 40 × 40 cm", marks: "red strap"), id: duffel))
        XCTAssertTrue(lib.addPocket(bagId: duffel, name: "Lid"))
        XCTAssertTrue(lib.setBagCabin(id: duffel, false))
        XCTAssertTrue(lib.setBagAirTag(id: duffel, true))
        XCTAssertTrue(lib.setThingNote(id: duffel, "Wheels squeak"))
        XCTAssertTrue(lib.updateThing(id: duffel) {
            $0.photos = ["photo-a"]; $0.thumb = "data:x"; $0.stats = ItemStats(packed: 4, used: 4)
            $0.serial = "SN-1"; $0.keep = true; $0.storage = "Attic"; $0.condition = "good"
            $0.maintenance = Maintenance(notes: "Oil the wheels", intervalDays: 365, lastDone: "2026-05-01",
                                         log: [MaintenanceLogEntry(date: "2026-05-01")])
            $0.extra[KIT_CONTENTS_KEY] = .array([.string("x")])
            $0.extra[BAG_EDITED_KEY] = .string("2026-09-30T00:00:00.000Z")
        })
        // A thing usually packed in it, and a trip it went on.
        var trip = newList(name: "Road")
        trip.items = [newItem(name: "Rain cover", container: "Wheeled duffel")]
        lib.saveTemplate(trip)
        let road = lib.templates.first { $0.name == "Road" }!.id
        _ = lib.createTrip(newEvent(name: "Road trip", activities: [road], startDate: "2026-10-10", endDate: "2026-10-11"))
        XCTAssertEqual(lib.bagFacts(name: "Wheeled duffel").things.map(\.name), ["Rain cover"])

        at("2026-10-19T09:00:00Z")
        guard let copy = lib.duplicateBag(id: duffel) else { return XCTFail("the bag was not duplicated") }
        XCTAssertEqual(copy.name, "Wheeled duffel 2")
        XCTAssertNotEqual(copy.id, duffel)
        XCTAssertEqual([copy.maxKg, copy.capacityL, copy.weight], [23, 90, 3400], "the numbers were not copied")
        XCTAssertEqual(lib.bagDetails(id: copy.id), BagDetails(brand: "Exempel", colour: "Black", type: .duffel, size: .large,
                                                               sizeNote: "80 × 40 × 40 cm", marks: "red strap"),
                       "the lost-luggage details were not copied")
        XCTAssertEqual(lib.pockets(bagId: copy.id), ["Lid"], "the pockets were not copied")
        XCTAssertFalse(Library.isCabinBag(copy))
        XCTAssertTrue(Library.hasAirTag(copy), "Has an AirTag was not copied")
        XCTAssertEqual(copy.note, "Wheels squeak", "the Notes were not copied")
        XCTAssertEqual([copy.storage, copy.condition], ["Attic", "good"])
        XCTAssertEqual(copy.maintenance?.notes, "Oil the wheels")
        XCTAssertEqual(copy.maintenance?.intervalDays, 365)
        // Not copied.
        XCTAssertEqual(copy.photos, [], "the photos were copied")
        XCTAssertEqual(copy.thumb, "")
        XCTAssertEqual(copy.stats, ItemStats(), "the review counts were copied")
        XCTAssertEqual(copy.serial, "")
        XCTAssertFalse(copy.keep)
        XCTAssertEqual(copy.maintenance?.lastDone, "")
        XCTAssertEqual(copy.maintenance?.log.count, 0, "the care log was copied")
        XCTAssertNil(copy.extra[KIT_CONTENTS_KEY], "what is inside was copied")
        XCTAssertNil(Library.bagEditedAt(copy), "the edit stamp was copied")
        XCTAssertEqual(lib.bagFacts(name: copy.name).things.count, 0, "the things in the original moved into the copy")
        XCTAssertEqual(lib.bagFacts(name: copy.name).trips.count, 0, "the copy has the original's trips")
        XCTAssertEqual(lib.bagFacts(name: "Wheeled duffel").things.map(\.name), ["Rain cover"])
        // Right after the original in his own order — and the newest added.
        XCTAssertEqual(names(lib.sortedBags(.own)), ["Wheeled duffel", "Wheeled duffel 2", "Sports bag", "Backpack", "Camera bag"])
        XCTAssertEqual(names(lib.sortedBags(.added)).first, "Wheeled duffel 2")
        // Again: the next free number, right after the original; a copy's copy counts on.
        XCTAssertEqual(lib.duplicateBag(id: duffel)?.name, "Wheeled duffel 3")
        XCTAssertEqual(lib.duplicateBag(id: copy.id)?.name, "Wheeled duffel 4")
        XCTAssertEqual(names(lib.sortedBags(.own)),
                       ["Wheeled duffel", "Wheeled duffel 3", "Wheeled duffel 2", "Wheeled duffel 4", "Sports bag", "Backpack", "Camera bag"])
        // The last bag in his order: its copy is last.
        XCTAssertEqual(lib.duplicateBag(id: id(lib, "Camera bag"))?.name, "Camera bag 2")
        XCTAssertEqual(names(lib.sortedBags(.own)).suffix(2), ["Camera bag", "Camera bag 2"])
        // Not a bag: nothing.
        XCTAssertNil(lib.duplicateBag(id: id(lib, "Lens")))
        // A copy is a thing like any other: kept by the records and a backup.
        XCTAssertNotNil(Library(records: lib.records()).bags().first { $0.name == "Wheeled duffel 2" })
        let restored = try! Importer.read(lib.backupData(exportedAt: "2026-10-19T12:00:00.000Z")).library
        XCTAssertEqual(restored.pockets(bag: "Wheeled duffel 2"), ["Lid"], "a backup lost the copy")
    }

    func testACopysNameIsTheNextFreeNumberAmongAllHisThings() {
        var lib = library()
        XCTAssertNotNil(lib.addThing(name: "Backpack 2"))        // a thing, not a bag, already has it
        XCTAssertEqual(lib.duplicateName(of: "Backpack"), "Backpack 3")
        XCTAssertEqual(lib.duplicateName(of: "Backpack 2"), "Backpack 3")
        XCTAssertNotNil(lib.addBag(name: "Size 40"))
        XCTAssertEqual(lib.duplicateName(of: "Size 40"), "Size 40 2", "a name ending in a number lost its number")
        XCTAssertEqual(lib.bagId(named: " camera BAG "), id(lib, "Camera bag"))
        XCTAssertNil(lib.bagId(named: "Other"))
        XCTAssertNil(lib.bagId(named: "Lens"))
    }
}
