import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// Photos of a thing (0.90 — his ask of 19 Oct 2026: "A photo or two for each item"): the
/// thing's own `photos`, as a bag's own photos are; two at most. Invented data only — this
/// repository is public.
final class ThingPhotosTests: XCTestCase {
    override func setUp() { PackingEnv.freeze(at: "2026-10-19T12:00:00.000Z") }
    override func tearDown() { PackingEnv.reset() }

    /// Hiking: Rain jacket and Head torch; the trip "Ridge walk" (24–26 Oct 2026) made from it.
    private func library() -> (Library, String) {
        var lib = Library()
        var hiking = newList(name: "Hiking", group: "GA")
        hiking.items = [newItem(name: "Rain jacket"), newItem(name: "Head torch")]
        lib.saveTemplate(hiking)
        let hikingId = lib.templates.first { $0.name == "Hiking" }!.id
        let trip = lib.createTrip(newEvent(name: "Ridge walk", activities: [hikingId], startDate: "2026-10-24", endDate: "2026-10-26")).id
        return (lib, trip)
    }

    private func thing(_ lib: Library, _ name: String) -> Item { lib.items.first { $0.name == name }! }

    func testAThingTakesTwoPhotosOnItsOwnPhotos() {
        var (lib, trip) = library()
        let jacket = thing(lib, "Rain jacket").id
        XCTAssertTrue(lib.thingPhotos(id: jacket).isEmpty)
        XCTAssertNil(lib.firstThingPhoto(id: jacket))
        XCTAssertTrue(lib.takesThingPhoto(id: jacket))
        let first = lib.addThingPhoto(id: jacket, jpeg: Data([1, 2]))!
        XCTAssertEqual(thing(lib, "Rain jacket").photos, [first.id], "the photo is not the thing's own")
        XCTAssertEqual(first.data, "data:image/jpeg;base64,AQI=")
        XCTAssertEqual(first.createdAt, "2026-10-19T12:00:00.000Z", "a photo without its date would be offered by Worth a look")
        XCTAssertEqual(lib.firstThingPhoto(id: jacket)?.id, first.id)
        let second = lib.addThingPhoto(id: jacket, jpeg: Data([3]))!
        XCTAssertEqual(lib.thingPhotos(id: jacket).map(\.id), [first.id, second.id], "not in the order taken")
        XCTAssertFalse(lib.takesThingPhoto(id: jacket))
        XCTAssertNil(lib.addThingPhoto(id: jacket, jpeg: Data([4])), "a third photo of the thing was taken")
        XCTAssertEqual(lib.thingPhotos(id: jacket).count, THING_PHOTOS_MAX)
        XCTAssertNil(lib.addThingPhoto(id: "no-such-thing", jpeg: Data([5])), "a photo was kept for no thing")
        XCTAssertNil(lib.addThingPhoto(id: thing(lib, "Head torch").id, jpeg: Data()), "a photo without bytes was kept")
        XCTAssertTrue(lib.thingPhotos(id: thing(lib, "Head torch").id).isEmpty, "the other thing got a photo")
        // In use: never offered by Worth a look, a week on.
        PackingEnv.freeze(at: "2026-10-26T12:00:00.000Z")
        XCTAssertTrue(lib.photoInUse(first.id))
        XCTAssertFalse(lib.unusedPhotos().contains { $0.id == first.id }, "Worth a look offers the thing's photo")
        // A trip's line is a copy that never carries the thing's photos; a new trip neither.
        XCTAssertFalse(lib.trips.first { $0.id == trip }!.entries.contains { !$0.photos.isEmpty }, "a trip line holds photos")
        let hikingId = lib.templates.first { $0.name == "Hiking" }!.id
        let again = lib.createTrip(newEvent(name: "Ridge walk again", activities: [hikingId]))
        XCTAssertFalse(again.entries.contains { !$0.photos.isEmpty }, "a new trip's line copied the thing's photos")
        // A rename keeps them; the store's records (what iCloud carries) keep them.
        XCTAssertTrue(lib.renameThing(id: jacket, to: "Shell jacket"))
        XCTAssertEqual(lib.thingPhotos(id: jacket).map(\.id), [first.id, second.id], "a rename lost the photos")
        XCTAssertEqual(Library(records: lib.records()).thingPhotos(id: jacket).map(\.id), [first.id, second.id],
                       "the records lost the thing's photos")
    }

    /// His backup file keeps them, and a restore puts them back — picture and all.
    func testAThingsPhotoIsKeptThroughABackupAndARestore() {
        var (lib, _) = library()
        let torch = thing(lib, "Head torch").id
        let photo = lib.addThingPhoto(id: torch, jpeg: Data([0xFF, 0xD8, 0xFF, 0xE0]))!
        let file = lib.backupData(exportedAt: "2026-10-19T12:00:00.000Z")
        let restored = try! Importer.read(file).library
        XCTAssertEqual(restored.thingPhotoIds(id: torch), [photo.id], "the restored thing lost its photo")
        XCTAssertEqual(restored.thingPhotos(id: torch).map(\.data), [photo.data], "the restored photo lost its picture")
        XCTAssertEqual(restored.firstThingPhoto(id: torch)?.id, photo.id)
    }

    func testRemovingAPhotoTakesItsRecordAndTheFirstPhotosThumb() {
        var (lib, _) = library()
        let jacket = thing(lib, "Rain jacket").id
        let first = lib.addThingPhoto(id: jacket, jpeg: Data([1]))!
        let second = lib.addThingPhoto(id: jacket, jpeg: Data([2]))!
        XCTAssertTrue(lib.updateThing(id: jacket) { $0.thumb = "data:image/jpeg;base64,AQ==" })
        XCTAssertTrue(lib.removeThingPhoto(id: jacket, photoId: first.id))
        XCTAssertEqual(thing(lib, "Rain jacket").photos, [second.id])
        XCTAssertEqual(thing(lib, "Rain jacket").thumb, "", "the web app's thumbnail of a removed first photo stayed")
        XCTAssertFalse(lib.photos.contains { $0.id == first.id }, "the removed photo's record stayed")
        XCTAssertFalse(lib.removeThingPhoto(id: jacket, photoId: first.id), "a photo was removed twice")
        XCTAssertTrue(lib.takesThingPhoto(id: jacket), "with one gone, no room for another")
        // A photo something else still shows keeps its record.
        lib.items[lib.items.firstIndex { $0.name == "Head torch" }!].photos = [second.id]
        XCTAssertTrue(lib.removeThingPhoto(id: jacket, photoId: second.id))
        XCTAssertTrue(lib.photos.contains { $0.id == second.id }, "a photo the other thing shows was taken away")
    }

    func testADeletedThingTakesItsPhotosAlong() {
        var (lib, _) = library()
        let jacket = thing(lib, "Rain jacket").id, torch = thing(lib, "Head torch").id
        let mine = lib.addThingPhoto(id: jacket, jpeg: Data([1]))!
        let shared = lib.addThingPhoto(id: jacket, jpeg: Data([2]))!
        lib.items[lib.items.firstIndex { $0.id == torch }!].photos = [shared.id]
        XCTAssertTrue(lib.deleteThing(id: jacket))
        XCTAssertFalse(lib.photos.contains { $0.id == mine.id }, "the deleted thing's photo stayed behind")
        XCTAssertTrue(lib.photos.contains { $0.id == shared.id }, "a photo another thing shows went with the deleted one")
    }

    /// A bag is a thing: its page's photos and its thing page's photos are the same two.
    func testABagsOwnPhotosAreItsThingPhotos() {
        var (lib, _) = library()
        let bag = lib.addBag(name: "Day pack")!.id
        let one = lib.addBagOwnPhoto(id: bag, jpeg: Data([1]))!
        XCTAssertEqual(lib.thingPhotos(id: bag).map(\.id), [one.id])
        let two = lib.addThingPhoto(id: bag, jpeg: Data([2]))!
        XCTAssertEqual(lib.bagOwnPhotos(id: bag).map(\.id), [one.id, two.id])
        XCTAssertNil(lib.addBagOwnPhoto(id: bag, jpeg: Data([3])), "a third photo through the bag's page")
        XCTAssertEqual(BAG_OWN_PHOTOS_MAX, THING_PHOTOS_MAX)
    }
}
