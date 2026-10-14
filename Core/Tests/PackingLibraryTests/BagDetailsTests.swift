import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// Lost luggage, part A (spec 07 part 18 A, his yes for 0.80): a bag's details for the airline's
/// baggage desk, said once on the bag and read by every trip. Invented data only — this
/// repository is public.
final class BagDetailsTests: XCTestCase {
    override func setUp() { PackingEnv.freeze(at: "2026-10-14T12:00:00.000Z") }
    override func tearDown() { PackingEnv.reset() }

    /// Travel: Boots in the Big case, and the Day pack — packed as a thing on Travel AND one of
    /// his bags. The Big case is one of his bags too. The trip "Coast week" (20–24 Oct 2026).
    private func library() -> (Library, String) {
        var lib = Library()
        var travel = newList(name: "Travel")
        travel.items = [newItem(name: "Boots", container: "Big case"), newItem(name: "Day pack", container: "Big case")]
        lib.saveTemplate(travel)
        XCTAssertNotNil(lib.addBag(name: "Big case"))
        XCTAssertNotNil(lib.addBag(name: "Day pack"), "a thing he packs becomes a bag")
        let travelId = lib.templates.first { $0.name == "Travel" }!.id
        let trip = lib.createTrip(newEvent(name: "Coast week", activities: [travelId], startDate: "2026-10-20", endDate: "2026-10-24")).id
        return (lib, trip)
    }

    private func bag(_ lib: Library, _ name: String) -> Item { lib.items.first { $0.name == name }! }

    private let full = BagDetails(brand: " Samsonite ", colour: "Black", type: .hardCase, size: .large,
                                  sizeNote: "75 × 50 × 30 cm ", marks: " red strap, sticker on the side")

    // MARK: - The bag's own

    func testTheDetailsAreTheBagsOwnAndBrandAndColourAreItsThingsOwn() {
        var (lib, _) = library()
        let caseId = bag(lib, "Big case").id
        XCTAssertEqual(lib.bagDetails(id: caseId), BagDetails(), "a new bag has details")
        XCTAssertTrue(lib.bagDetails(bag: "Big case").isEmpty)
        XCTAssertTrue(lib.setBagDetails(full, id: caseId))
        // Brand, colour and the size's note are the THING's own fields — the ones its page shows.
        let thing = bag(lib, "Big case")
        XCTAssertEqual(thing.manufacturer, "Samsonite", "the brand is not the thing's own Brand")
        XCTAssertEqual(thing.color, "Black", "the colour is not the thing's own Colour")
        XCTAssertEqual(thing.size, "75 × 50 × 30 cm", "the size's note is not the thing's own Size")
        // Type, size and marks: extra keys, as stored words.
        XCTAssertEqual(thing.extra[BAG_TYPE_KEY], .string("hard"))
        XCTAssertEqual(thing.extra[BAG_SIZE_KEY], .string("large"))
        XCTAssertEqual(thing.extra[BAG_MARKS_KEY], .string("red strap, sticker on the side"))
        // Read back by its name as a trip's lines spell it, trimmed.
        XCTAssertEqual(lib.bagDetails(bag: "big CASE"), full.trimmed, "not read by the name the lines use")
        XCTAssertEqual(lib.bagDetails(id: caseId), full.trimmed)
        // Said by the thing's page ("Its details"): the bag page reads the same value.
        XCTAssertTrue(lib.updateThing(id: caseId) { $0.manufacturer = "Rimowa"; $0.color = "Grey" })
        XCTAssertEqual(lib.bagDetails(bag: "Big case").brand, "Rimowa")
        XCTAssertEqual(lib.bagDetails(bag: "Big case").colour, "Grey")
        // Emptied: an extra key goes — never an empty string; the own fields are "".
        var none = lib.bagDetails(id: caseId)!
        none.type = nil; none.size = nil; none.marks = "  "; none.sizeNote = ""; none.brand = ""
        XCTAssertTrue(lib.setBagDetails(none, id: caseId))
        for key in BAG_DETAIL_KEYS { XCTAssertNil(bag(lib, "Big case").extra[key], "\(key) stays when emptied") }
        XCTAssertEqual(bag(lib, "Big case").size, "")
        XCTAssertEqual(bag(lib, "Big case").manufacturer, "")
        XCTAssertEqual(lib.bagDetails(bag: "Big case"), BagDetails(colour: "Grey"))
        // Only a bag takes them.
        let boots = bag(lib, "Boots")
        XCTAssertFalse(lib.setBagDetails(full, id: boots.id))
        XCTAssertNil(lib.bagDetails(id: boots.id))
        XCTAssertEqual(bag(lib, "Boots"), boots, "a thing that is no bag was changed")
        XCTAssertEqual(lib.bagDetails(bag: "Boots"), BagDetails(), "a thing that is no bag has details")
    }

    func testANameOnTheLinesBecomesABagOnlyWhenSomethingIsSaid() {
        var (lib, _) = library()
        let carryOn = "Carry-on / hand luggage"
        XCTAssertTrue(lib.bagDetails(bag: carryOn).isEmpty, "a name on the lines has details")
        XCTAssertTrue(lib.setBagDetails(BagDetails(brand: "  "), bag: carryOn))
        XCTAssertFalse(lib.bags().contains { $0.name == carryOn }, "nothing said, yet the name became a bag")
        XCTAssertTrue(lib.setBagDetails(BagDetails(type: .softCase), bag: carryOn))
        XCTAssertTrue(lib.bags().contains { $0.name == carryOn }, "said by name, the carry-on did not become one of his bags")
        XCTAssertEqual(lib.bagDetails(bag: carryOn).type, .softCase)
        // By name onto a bag he has: the same bag, no second one.
        let count = lib.bags().count
        XCTAssertTrue(lib.setBagDetails(BagDetails(marks: "yellow ribbon"), bag: "BIG case"))
        XCTAssertEqual(lib.bags().count, count)
        XCTAssertEqual(lib.bagDetails(bag: "Big case").marks, "yellow ribbon")
        // "Other" (no bag) and "" are refused.
        XCTAssertFalse(lib.setBagDetails(full, bag: "Other"))
        XCTAssertFalse(lib.setBagDetails(full, bag: " "))
        XCTAssertTrue(lib.bagDetails(bag: "Other").isEmpty)
    }

    func testOnlyWhatChangedIsWrittenSoALaterVersionsAnswerStays() {
        var (lib, _) = library()
        let caseId = bag(lib, "Big case").id
        // A later version wrote a type and a size this one does not know.
        XCTAssertTrue(lib.updateThing(id: caseId) { $0.extra[BAG_TYPE_KEY] = .string("trunk"); $0.extra[BAG_SIZE_KEY] = .string("xl") })
        var d = lib.bagDetails(id: caseId)!
        XCTAssertNil(d.type, "an unknown type read as one")
        XCTAssertNil(d.size)
        d.brand = "Tumi"
        XCTAssertTrue(lib.setBagDetails(d, id: caseId))
        XCTAssertEqual(bag(lib, "Big case").manufacturer, "Tumi")
        XCTAssertEqual(bag(lib, "Big case").extra[BAG_TYPE_KEY], .string("trunk"), "a later version's type was wiped")
        XCTAssertEqual(bag(lib, "Big case").extra[BAG_SIZE_KEY], .string("xl"), "a later version's size was wiped")
        // Chosen here, it is replaced — his answer wins.
        d.type = .duffel
        XCTAssertTrue(lib.setBagDetails(d, id: caseId))
        XCTAssertEqual(bag(lib, "Big case").extra[BAG_TYPE_KEY], .string("duffel"))
        // The same answers again (spaces around the words): nothing is written.
        let before = lib
        var same = lib.bagDetails(id: caseId)!
        same.brand = "  Tumi "
        XCTAssertTrue(lib.setBagDetails(same, id: caseId))
        XCTAssertEqual(lib.items, before.items, "the same answers wrote the bag again")
    }

    // MARK: - Kept, synced, backed up — never on a trip line or a share

    func testTheDetailsFollowARenameAndAreSyncedBackedUpButNeverOnATripLine() {
        var (lib, trip) = library()
        let packId = bag(lib, "Day pack").id
        XCTAssertTrue(lib.setBagDetails(full, id: packId))
        // Renamed: the details go along (they are the bag's thing's).
        XCTAssertTrue(lib.renameThing(id: packId, to: "Hill pack"))
        XCTAssertEqual(lib.bagDetails(bag: "Hill pack"), full.trimmed, "the details stayed with the old name")
        XCTAssertTrue(lib.bagDetails(bag: "Day pack").isEmpty)
        // The store's records (iCloud carries them), and a backup.
        let stored = Library(records: lib.records())
        XCTAssertEqual(stored.bagDetails(bag: "Hill pack"), full.trimmed, "the records lost the details")
        let restored = try! Importer.read(lib.backupData(exportedAt: "2026-10-14T12:00:00.000Z")).library
        XCTAssertEqual(restored.bagDetails(bag: "Hill pack"), full.trimmed, "a backup lost the details")
        // The bag is also a thing he packs on Travel: its trip line carries none of them…
        guard let line = lib.trips.first(where: { $0.id == trip })?.entries.first(where: { $0.sourceItemId == packId }) else {
            return XCTFail("the trip has no Day pack line")
        }
        for key in BAG_DETAIL_KEYS { XCTAssertNil(line.extra[key], "a trip line carries the bag's \(key)") }
        XCTAssertEqual([line.manufacturer, line.color, line.size], ["", "", ""], "a trip line carries the bag's brand, colour or size")
        // …nor does a line made after they were said (a new trip from Travel), nor a shared trip.
        let travelId = lib.templates.first { $0.name == "Travel" }!.id
        let again = lib.createTrip(newEvent(name: "Coast again", activities: [travelId], startDate: "2026-11-02", endDate: "2026-11-04"))
        let fresh = again.entries.first { $0.sourceItemId == packId }
        XCTAssertNotNil(fresh)
        for key in BAG_DETAIL_KEYS { XCTAssertNil(fresh?.extra[key], "a new trip's line carries the bag's \(key)") }
        let sent = Library.justTheList(again)
        XCTAssertFalse(sent.entries.contains { l in BAG_DETAIL_KEYS.contains { l.extra[$0] != nil } }, "a shared trip carries bag details")
        // Deleted completely, they go with the thing.
        XCTAssertTrue(lib.deleteBag(id: packId, moveTo: "Big case", completely: true))
        XCTAssertNil(lib.items.first { $0.id == packId })
        XCTAssertTrue(lib.bagDetails(bag: "Hill pack").isEmpty)
    }

    // MARK: - Photos of the bag itself

    func testABagsOwnPhotosAreItsThingsPhotosTwoAtMostAndApartFromTheTrips() {
        var (lib, trip) = library()
        let caseId = bag(lib, "Big case").id
        XCTAssertTrue(lib.bagOwnPhotos(id: caseId).isEmpty)
        let first = lib.addBagOwnPhoto(id: caseId, jpeg: Data([1]))!
        XCTAssertEqual(bag(lib, "Big case").photos, [first.id], "the photo is not the thing's own")
        XCTAssertEqual(lib.bagDetails(bag: "big case").photoIds, [first.id], "the details do not show the photo")
        XCTAssertEqual(lib.bagOwnPhotos(bag: "BIG CASE").map(\.id), [first.id])
        let second = lib.addBagOwnPhoto(id: caseId, jpeg: Data([2]))!
        XCTAssertNil(lib.addBagOwnPhoto(id: caseId, jpeg: Data([3])), "a third photo of the bag was taken")
        XCTAssertEqual(lib.bagOwnPhotos(id: caseId).map(\.id), [first.id, second.id])
        XCTAssertNil(lib.addBagOwnPhoto(id: bag(lib, "Boots").id, jpeg: Data([4])), "a thing that is no bag took a bag photo")
        XCTAssertNil(lib.addBagOwnPhoto(id: caseId, jpeg: Data()))
        // In use: never offered by Worth a look, a week on.
        XCTAssertTrue(lib.photoInUse(first.id))
        PackingEnv.freeze(at: "2026-10-21T12:00:00.000Z")
        XCTAssertFalse(lib.unusedPhotos().contains { $0.id == first.id }, "Worth a look offers the bag's own photo")
        // The details' writer never touches them; a name with only photo ids becomes no bag.
        XCTAssertTrue(lib.setBagDetails(BagDetails(brand: "Tumi"), id: caseId))
        XCTAssertEqual(lib.bagDetails(id: caseId)?.photoIds, [first.id, second.id], "writing the details took the photos away")
        XCTAssertTrue(lib.setBagDetails(BagDetails(photoIds: [first.id]), bag: "Carry-on / hand luggage"))
        XCTAssertFalse(lib.bags().contains { $0.name == "Carry-on / hand luggage" }, "photo ids alone made a bag")
        // Not a photo of it PACKED: the trip's photos and the Packing day count none of them.
        XCTAssertTrue(lib.bagPhotoIds(tripId: trip, bag: "Big case").isEmpty)
        XCTAssertEqual(lib.packingDay(tripId: trip)?.bags.first { $0.name == "Big case" }?.photos, 0,
                       "the bag's own photo counts as a photo of it packed")
        // Renamed, synced, backed up: they go along.
        XCTAssertTrue(lib.renameThing(id: caseId, to: "Blue case"))
        XCTAssertEqual(lib.bagOwnPhotos(bag: "Blue case").count, 2, "the photos stayed with the old name")
        XCTAssertEqual(Library(records: lib.records()).bagOwnPhotos(bag: "Blue case").count, 2, "the records lost the bag's photos")
        let restored = try! Importer.read(lib.backupData(exportedAt: "2026-10-21T12:00:00.000Z")).library
        XCTAssertEqual(restored.bagOwnPhotos(bag: "Blue case").map(\.id), [first.id, second.id], "a backup lost the bag's photos")
        // Removed: its record goes, and the web app's thumbnail of the first photo with it.
        XCTAssertTrue(lib.updateThing(id: caseId) { $0.thumb = "data:image/jpeg;base64,AQ==" })
        XCTAssertTrue(lib.removeBagOwnPhoto(id: caseId, photoId: first.id))
        XCTAssertEqual(bag(lib, "Blue case").photos, [second.id])
        XCTAssertEqual(bag(lib, "Blue case").thumb, "", "the thumbnail of a removed first photo stayed")
        XCTAssertFalse(lib.photos.contains { $0.id == first.id }, "the removed photo's record stayed")
        XCTAssertFalse(lib.removeBagOwnPhoto(id: caseId, photoId: first.id))
        XCTAssertNotNil(lib.addBagOwnPhoto(id: caseId, jpeg: Data([5])), "with one gone, a second is refused")
    }

    // MARK: - The words

    func testTheDeskHearsPlainWords() {
        XCTAssertEqual(BagType.allCases.map(\.name),
                       ["Hard case", "Soft case", "Duffel", "Backpack", "Holdall / weekend bag", "Garment bag", "Other"])
        XCTAssertEqual(BagType.allCases.map(\.rawValue), ["hard", "soft", "duffel", "backpack", "holdall", "garment", "other"])
        XCTAssertEqual(BagSize.allCases.map(\.name), ["Cabin", "Medium", "Large"])
        XCTAssertEqual(BagSize.allCases.map(\.rawValue), ["cabin", "medium", "large"])
        XCTAssertEqual(BagDetails.colourPills.map(\.label), ["Black", "Grey", "Blue", "Red", "Green", "Beige", "Multi"])
        let multi = BagDetails.colourPills.last!
        XCTAssertEqual(multi.value, "Multicoloured")
        // A pill is lit by its word or its label, however it is spelt; never by nothing.
        XCTAssertTrue(BagDetails(colour: "black ").lit(BagDetails.colourPills[0]), "a pill is lit only by its exact spelling")
        XCTAssertTrue(BagDetails(colour: "multi").lit(multi))
        XCTAssertTrue(BagDetails(colour: "Multicoloured").lit(multi))
        XCTAssertFalse(BagDetails(colour: "Dark blue").lit(BagDetails.colourPills[2]))
        XCTAssertFalse(BagDetails().lit(BagDetails.colourPills[0]))
        // The size, and the whole bag on one line for the desk.
        XCTAssertEqual(full.sizeWords, "Large, 75 × 50 × 30 cm")
        XCTAssertEqual(BagDetails(size: .cabin).sizeWords, "Cabin")
        XCTAssertEqual(BagDetails(sizeNote: "40 l").sizeWords, "40 l")
        XCTAssertEqual(full.summary, "Black · Samsonite · Hard case · Large, 75 × 50 × 30 cm · red strap, sticker on the side")
        XCTAssertEqual(BagDetails(colour: "Red", type: .duffel).summary, "Red · Duffel")
        XCTAssertEqual(BagDetails().summary, "")
        XCTAssertTrue(BagDetails(brand: " ", marks: "\n").isEmpty)
        XCTAssertFalse(BagDetails(size: .medium).isEmpty)
    }
}
