import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// The bag on the luggage scale (his idea 8, 2 Oct 2026): what the scale says is kept
/// per trip and bag, and it is the weight the bag is judged by.
final class WeighingTests: XCTestCase {
    override func setUp() { PackingEnv.freeze(at: "2026-10-01T12:00:00.000Z") }
    override func tearDown() { PackingEnv.reset() }

    /// A cabin bag with an 8 kg limit, and a trip packing 2.2 kg of things into it.
    private func library() -> (Library, String) {
        var lib = Library()
        let bag = lib.addBag(name: "Cabin bag")!
        _ = lib.setBag(id: bag.id, maxKg: 8)
        lib.saveTemplate(newList(name: "Base", role: "base"))
        let base = lib.templates.first { $0.role == "base" }!.id
        for (name, grams) in [("Laptop", 1800.0), ("Book", 400.0)] {
            let t = lib.addThing(name: name)!
            _ = lib.updateThing(id: t.id) { $0.container = "Cabin bag"; $0.weight = grams }
            _ = lib.setOnTemplate(itemId: t.id, templateId: base, on: true)
        }
        let trip = lib.createTrip(newEvent(name: "Away", startDate: "2026-11-01", endDate: "2026-11-05"))
        return (lib, trip.id)
    }

    private func cabin(_ lib: Library, _ trip: String) -> WeighedBag? {
        lib.weighedBags(tripId: trip).first { $0.load.container == "Cabin bag" }
    }

    func testTheScaleIsWhatTheBagIsJudgedBy() {
        var (lib, trip) = library()
        XCTAssertEqual(cabin(lib, trip)?.grams, 2200, "unweighed, the things' sum")
        XCTAssertNil(cabin(lib, trip)?.scaleGrams)
        XCTAssertEqual(cabin(lib, trip)?.over, false)
        XCTAssertTrue(lib.setWeighed(tripId: trip, bag: "Cabin bag", grams: 8600))
        XCTAssertEqual(cabin(lib, trip)?.grams, 8600, "the scale is not the weight that counts")
        XCTAssertEqual(cabin(lib, trip)?.over, true, "8.6 kg on the scale in an 8 kg bag is not over")
        XCTAssertEqual(cabin(lib, trip)?.load.grams, 2200, "the things' sum is not kept beside it")
        XCTAssertEqual(Library(records: lib.records()).weighed(tripId: trip), ["Cabin bag": 8600], "the stored records lost it")
        XCTAssertTrue(lib.setWeighed(tripId: trip, bag: "Cabin bag", grams: nil))
        XCTAssertTrue(lib.weighed(tripId: trip).isEmpty, "it could not be taken away")
        XCTAssertNil(lib.trips.first { $0.id == trip }?.extra[WEIGHED_KEY], "an empty record is left on the trip")
        XCTAssertFalse(lib.setWeighed(tripId: "no such trip", bag: "Cabin bag", grams: 100))
    }

    func testNonsenseFromTheScaleIsNotKept() {
        var (lib, trip) = library()
        for odd in [0.0, -5, .nan, .infinity] { _ = lib.setWeighed(tripId: trip, bag: "Cabin bag", grams: odd) }
        XCTAssertTrue(lib.weighed(tripId: trip).isEmpty, "a reading of nothing was kept")
        XCTAssertNil(lib.trips.first { $0.id == trip }?.extra[WEIGHED_KEY], "a reading of nothing was stored on the trip")
    }
}
