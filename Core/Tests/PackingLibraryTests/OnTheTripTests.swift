import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// On the trip (his ideas 11 and 12, 2 Oct 2026): a photo of each packed bag, and
/// "Bought there" lines.
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
        XCTAssertNil(lib.bagPhoto(tripId: trip, bag: "Suitcase"))
        XCTAssertTrue(lib.setBagPhoto(tripId: trip, bag: "Suitcase", jpeg: Data([1, 2, 3])))
        let first = lib.bagPhoto(tripId: trip, bag: "Suitcase")
        XCTAssertEqual(first?.data, "data:image/jpeg;base64,AQID", "the photo was not kept as it was taken")
        XCTAssertEqual(lib.photos.count, 1)
        // Through the stored records — the photo travels as its own record.
        let back = Library(records: lib.records())
        XCTAssertEqual(back.bagPhoto(tripId: trip, bag: "Suitcase")?.data, first?.data, "the stored records lost the photo")
        // A new photo replaces it, and the old one goes.
        XCTAssertTrue(lib.setBagPhoto(tripId: trip, bag: "Suitcase", jpeg: Data([4, 5, 6])))
        XCTAssertEqual(lib.photos.count, 1, "the replaced photo was left behind")
        XCTAssertNotEqual(lib.bagPhoto(tripId: trip, bag: "Suitcase")?.id, first?.id)
        // Taken away: nothing left, not even an empty record on the trip.
        XCTAssertTrue(lib.setBagPhoto(tripId: trip, bag: "Suitcase", jpeg: nil))
        XCTAssertNil(lib.bagPhoto(tripId: trip, bag: "Suitcase"))
        XCTAssertTrue(lib.photos.isEmpty, "a photo nobody shows was kept")
        XCTAssertNil(lib.trips[0].extra[BAG_PHOTOS_KEY])
        XCTAssertFalse(lib.setBagPhoto(tripId: "no such trip", bag: "Suitcase", jpeg: Data([1])))
    }

    func testAPhotoAThingStillShowsIsNotThrownAway() {
        var (lib, trip) = library()
        _ = lib.setBagPhoto(tripId: trip, bag: "Suitcase", jpeg: Data([1, 2, 3]))
        let id = lib.bagPhoto(tripId: trip, bag: "Suitcase")!.id
        let n = lib.items.firstIndex { $0.name == "Swimsuit" }!
        lib.items[n].photos = [id]
        _ = lib.setBagPhoto(tripId: trip, bag: "Suitcase", jpeg: nil)
        XCTAssertTrue(lib.photos.contains { $0.id == id }, "a photo the swimsuit shows was thrown away")
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
