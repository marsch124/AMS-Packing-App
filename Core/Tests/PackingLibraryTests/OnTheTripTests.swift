import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// On the trip (his ideas 11 and 12, 2 Oct 2026): photos of each packed bag (up to
/// three since the field test, 3 Oct 2026), and "Bought there" lines.
final class OnTheTripTests: XCTestCase {
    override func setUp() { PackingEnv.freeze(at: "2026-10-01T12:00:00.000Z") }
    override func tearDown() { PackingEnv.reset() }

    private func library() -> (Library, String) {
        var lib = Library()
        lib.saveTemplate(newList(name: "Base", role: "base"))
        let base = lib.templates.first { $0.role == "base" }!.id
        let t = lib.addThing(name: "Swimsuit")!
        _ = lib.setOnTemplate(itemId: t.id, templateId: base, on: true)
        let trip = lib.createTrip(newEvent(name: "Away", startDate: "2026-11-01", endDate: "2026-12-31"))
        return (lib, trip.id)
    }

    func testAPackedBagKeepsItsPhoto() {
        var (lib, trip) = library()
        XCTAssertTrue(lib.bagPhotos(tripId: trip, bag: "Suitcase").isEmpty)
        let first = lib.addBagPhoto(tripId: trip, bag: "Suitcase", jpeg: Data([1, 2, 3]))
        XCTAssertEqual(first?.data, "data:image/jpeg;base64,AQID", "the photo was not kept as it was taken")
        XCTAssertEqual(lib.bagPhotos(tripId: trip, bag: "Suitcase").map(\.id), [first?.id].compactMap { $0 })
        XCTAssertEqual(lib.photos.count, 1)
        // Through the stored records — the photo travels as its own record.
        let back = Library(records: lib.records())
        XCTAssertEqual(back.bagPhotos(tripId: trip, bag: "Suitcase").map(\.data), [first?.data].compactMap { $0 },
                       "the stored records lost the photo")
        // Taken away: nothing left, not even an empty record on the trip.
        XCTAssertTrue(lib.removeBagPhoto(tripId: trip, bag: "Suitcase", photoId: first!.id))
        XCTAssertTrue(lib.bagPhotos(tripId: trip, bag: "Suitcase").isEmpty)
        XCTAssertTrue(lib.photos.isEmpty, "a photo nobody shows was kept")
        XCTAssertNil(lib.trips[0].extra[BAG_PHOTOS_KEY])
        XCTAssertNil(lib.addBagPhoto(tripId: "no such trip", bag: "Suitcase", jpeg: Data([1])))
        XCTAssertNil(lib.addBagPhoto(tripId: trip, bag: "Suitcase", jpeg: Data()), "an empty picture was kept")
    }

    /// Their words (field test, 3 Oct 2026): "maybe up to three, because sometimes you
    /// would like a photo from different angles." Three are kept in the order taken, a
    /// fourth is refused, and one taken out of the middle leaves the other two.
    func testABagKeepsUpToThreePhotos() {
        var (lib, trip) = library()
        let shots = (1...3).compactMap { k in lib.addBagPhoto(tripId: trip, bag: "Suitcase", jpeg: Data([UInt8(k)])) }
        XCTAssertEqual(shots.count, 3, "three photos were not all kept")
        XCTAssertEqual(lib.bagPhotos(tripId: trip, bag: "Suitcase").map(\.id), shots.map(\.id), "not in the order taken")
        // Stored as a list of ids — the shape 0.54 writes.
        XCTAssertEqual(lib.trips[0].extra[BAG_PHOTOS_KEY]?.objectValue?["Suitcase"],
                       .array(shots.map { .string($0.id) }), "not stored as a list")
        // A fourth is refused, and nothing of it is kept.
        XCTAssertNil(lib.addBagPhoto(tripId: trip, bag: "Suitcase", jpeg: Data([4])), "a fourth photo was taken")
        XCTAssertEqual(lib.photos.count, 3, "the refused fourth photo was kept anyway")
        XCTAssertEqual(lib.bagPhotos(tripId: trip, bag: "Suitcase").map(\.id), shots.map(\.id))
        // Another bag has its own three.
        XCTAssertNotNil(lib.addBagPhoto(tripId: trip, bag: "Day pack", jpeg: Data([5])), "one bag's photos filled another's")
        // Through the stored records: all three, in order.
        XCTAssertEqual(Library(records: lib.records()).bagPhotos(tripId: trip, bag: "Suitcase").map(\.data),
                       shots.map(\.data), "the stored records lost a photo, or their order")
        // The middle one taken out: the first and the last stay, the middle's record goes.
        XCTAssertTrue(lib.removeBagPhoto(tripId: trip, bag: "Suitcase", photoId: shots[1].id))
        XCTAssertEqual(lib.bagPhotos(tripId: trip, bag: "Suitcase").map(\.id), [shots[0].id, shots[2].id],
                       "taking out the middle photo took the wrong one")
        XCTAssertFalse(lib.photos.contains { $0.id == shots[1].id }, "a photo nobody shows was kept")
        XCTAssertFalse(lib.removeBagPhoto(tripId: trip, bag: "Suitcase", photoId: shots[1].id), "removed twice")
        // Room again for a third.
        XCTAssertNotNil(lib.addBagPhoto(tripId: trip, bag: "Suitcase", jpeg: Data([6])), "no room after one was removed")
    }

    /// A trip saved by 0.52 or 0.53 holds a bag's one photo as a plain id. It is read
    /// as a list of one, the next photo turns it into a list, and removing it works.
    func testABagPhotoKeptByAnOlderVersionIsRead() {
        var (lib, trip) = library()
        let old = PhotoRecord(id: "old-photo", data: "data:image/jpeg;base64,AQID", createdAt: "2026-10-01T12:00:00.000Z")
        lib.photos.append(old)
        lib.trips[0].extra[BAG_PHOTOS_KEY] = .object(["Suitcase": .string(old.id)])
        let back = Library(records: lib.records())
        XCTAssertEqual(back.bagPhotos(tripId: trip, bag: "Suitcase").map(\.id), [old.id], "the older photo was not read")
        XCTAssertTrue(lib.photoInUse(old.id), "the older photo counts as shown nowhere")
        let new = lib.addBagPhoto(tripId: trip, bag: "Suitcase", jpeg: Data([7]))
        XCTAssertEqual(lib.trips[0].extra[BAG_PHOTOS_KEY]?.objectValue?["Suitcase"],
                       .array([.string(old.id), .string(new?.id ?? "")]), "the older photo was lost, or not written as a list")
        XCTAssertTrue(lib.removeBagPhoto(tripId: trip, bag: "Suitcase", photoId: old.id))
        XCTAssertEqual(lib.bagPhotos(tripId: trip, bag: "Suitcase").map(\.id), [new?.id].compactMap { $0 })
        XCTAssertFalse(lib.photos.contains { $0.id == old.id }, "the older photo's record was kept")
        // Removing a lone older-shaped photo clears the bag's entry altogether.
        lib.photos.append(old)
        lib.trips[0].extra[BAG_PHOTOS_KEY] = .object(["Day pack": .string(old.id)])
        XCTAssertTrue(lib.removeBagPhoto(tripId: trip, bag: "Day pack", photoId: old.id))
        XCTAssertNil(lib.trips[0].extra[BAG_PHOTOS_KEY])
    }

    func testAPhotoAThingStillShowsIsNotThrownAway() {
        var (lib, trip) = library()
        let id = lib.addBagPhoto(tripId: trip, bag: "Suitcase", jpeg: Data([1, 2, 3]))!.id
        let n = lib.items.firstIndex { $0.name == "Swimsuit" }!
        lib.items[n].photos = [id]
        _ = lib.removeBagPhoto(tripId: trip, bag: "Suitcase", photoId: id)
        XCTAssertTrue(lib.photos.contains { $0.id == id }, "a photo the swimsuit shows was thrown away")
    }

    /// A photo another bag still lists (on this trip or another) stays when one bag lets it go.
    func testAPhotoAnotherBagStillShowsIsNotThrownAway() {
        var (lib, trip) = library()
        let id = lib.addBagPhoto(tripId: trip, bag: "Suitcase", jpeg: Data([1, 2, 3]))!.id
        let other = lib.createTrip(newEvent(name: "Later", startDate: "2027-01-01", endDate: "2027-01-08"))
        let k = lib.trips.firstIndex { $0.id == other.id }!
        lib.trips[k].extra[BAG_PHOTOS_KEY] = .object(["Day pack": .array([.string("someone-else"), .string(id)])])
        _ = lib.removeBagPhoto(tripId: trip, bag: "Suitcase", photoId: id)
        XCTAssertTrue(lib.photos.contains { $0.id == id }, "a photo another bag shows was thrown away")
    }

    func testABoughtThereLineIsInHandMarkedAndKept() {
        var (lib, trip) = library()
        let cream = lib.addBoughtThere(tripId: trip, name: "Sun cream")
        XCTAssertEqual(cream?.checked, true, "bought there is in hand already")
        XCTAssertTrue(cream.map(Library.isBoughtThere) ?? false, "not marked bought there")
        _ = lib.addCustomLine(tripId: trip, name: "Tripod")
        XCTAssertEqual(lib.boughtThere(tripId: trip).map(\.name), ["Sun cream"], "a line typed at home counts as bought there")
        // Trip settings rebuild the list: a bought-there line stays, still marked.
        _ = lib.changeTrip(id: trip) { $0.season = "Winter" }
        XCTAssertEqual(lib.boughtThere(tripId: trip).map(\.name), ["Sun cream"], "the rebuild lost what was bought there")
        XCTAssertEqual(Library(records: lib.records()).boughtThere(tripId: trip).map(\.name), ["Sun cream"],
                       "the stored records lost what was bought there")
        XCTAssertNil(lib.addBoughtThere(tripId: trip, name: "  "), "a nameless thing was bought")
    }
}
