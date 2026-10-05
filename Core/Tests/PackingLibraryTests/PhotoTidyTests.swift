import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// A deleted trip takes its photos along (his ask, 4 Oct 2026: the practice trip
/// was gone, its bag photo stayed behind), and Worth a look offers to remove the
/// ones left behind before.
final class PhotoTidyTests: XCTestCase {
    override func setUp() { PackingEnv.freeze(at: "2026-10-04T10:00:00.000Z") }
    override func tearDown() { PackingEnv.reset() }

    private func library() -> (Library, String) {
        var lib = Library()
        var hiking = newList(name: "Hiking", group: "GA")
        hiking.items = [newItem(name: "Boots")]
        lib.saveTemplate(hiking)
        var trip = newEvent(name: "Weekend")
        trip.activities = [lib.templates[0].id]
        trip.entries = buildTotalEntries(trip, lib.resolvedTemplates())
        lib.trips = [trip]
        return (lib, trip.id)
    }

    func testDeletingATripTakesItsBagPhotosAlong() {
        var (lib, trip) = library()
        let photo = lib.addBagPhoto(tripId: trip, bag: "Carry-on", jpeg: Data([1, 2, 3]))!
        XCTAssertEqual(lib.photos.map(\.id), [photo.id])
        XCTAssertTrue(lib.deleteTrip(id: trip))
        XCTAssertTrue(lib.photos.isEmpty, "the deleted trip's bag photo stayed behind")
    }

    func testAPhotoSomethingElseStillShowsStays() {
        var (lib, trip) = library()
        let photo = lib.addBagPhoto(tripId: trip, bag: "Carry-on", jpeg: Data([1, 2, 3]))!
        lib.items[0].photos = [photo.id]
        XCTAssertTrue(lib.deleteTrip(id: trip))
        XCTAssertEqual(lib.photos.map(\.id), [photo.id], "a photo the thing still shows was taken with the trip")
    }

    func testWorthALookOffersToRemoveAPhotoLeftBehind() {
        var (lib, _) = library()
        lib.photos = [PhotoRecord(id: "old", data: "data:image/jpeg;base64,AQID", createdAt: "2026-10-02T09:00:00.000Z"),
                      PhotoRecord(id: "new", data: "data:image/jpeg;base64,AQID", createdAt: "2026-10-04T09:30:00.000Z"),
                      PhotoRecord(id: "undated", data: "data:image/jpeg;base64,AQID", createdAt: "")]
        // The one from an hour ago may be on its way with its trip, and one whose age
        // cannot be read may be too: never offered.
        XCTAssertEqual(lib.unusedPhotos().map(\.id), ["old"])
        let worry = lib.worries().first { $0.fix == Library.FIX_UNUSED_PHOTOS }
        XCTAssertEqual(worry?.says, "1 photo is no longer shown anywhere \u{2014} left behind by a deleted trip.")
        XCTAssertEqual(worry?.fixSays, "Remove it")
        XCTAssertEqual(lib.repair(Library.FIX_UNUSED_PHOTOS), 1)
        XCTAssertEqual(lib.photos.map(\.id), ["new", "undated"])
        XCTAssertNil(lib.worries().first { $0.fix == Library.FIX_UNUSED_PHOTOS }, "the worry outlived its repair")
    }

    /// Worth a look is asked on every drawing of Settings. It used to check each photo
    /// against every thing and trip line in turn; now one walk gathers what is shown
    /// (the spec pass, 5 Oct 2026). Same answer as the one-by-one check — a thing's
    /// photo, a line's, a bag's in either stored shape — and the loose one alone is
    /// offered.
    func testOneWalkFindsEveryPhotoStillShownAsTheOneByOneCheckDoes() {
        var (lib, trip) = library()
        let bag = lib.addBagPhoto(tripId: trip, bag: "Carry-on", jpeg: Data([1, 2, 3]))!
        let n = lib.trips.firstIndex { $0.id == trip }!
        var bags = lib.trips[n].extra[BAG_PHOTOS_KEY]?.objectValue ?? [:]
        bags["Duffel"] = .string("single")                    // the older one-photo shape
        lib.trips[n].extra[BAG_PHOTOS_KEY] = .object(bags)
        lib.trips[n].entries[0].photos = ["line"]
        lib.items[0].photos = ["thing"]
        let old = "2026-10-01T09:00:00.000Z"
        lib.photos = [bag] + ["single", "line", "thing", "loose"].map {
            PhotoRecord(id: $0, data: "data:image/jpeg;base64,AQID", createdAt: old)
        }
        XCTAssertEqual(lib.photoIdsInUse(), [bag.id, "single", "line", "thing"])
        for photo in lib.photos {
            XCTAssertEqual(lib.photoIdsInUse().contains(photo.id), lib.photoInUse(photo.id), photo.id)
        }
        XCTAssertEqual(lib.unusedPhotos().map(\.id), ["loose"])
        lib.photos.append(PhotoRecord(id: "undated", data: "data:image/jpeg;base64,AQID", createdAt: ""))
        XCTAssertEqual(lib.undatedUnusedPhotos().map(\.id), ["undated"])
    }
}
