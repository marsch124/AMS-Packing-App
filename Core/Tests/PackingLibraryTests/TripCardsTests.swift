import XCTest
import PackingCore
@testable import PackingLibrary

/// What the Events screen is told about each trip: where it is in its life, how
/// far the packing got, and which pile it belongs in.
final class TripCardsTests: XCTestCase {
    override func setUp() { PackingEnv.reset(); _ = setPhases(DEFAULT_PHASES) }
    override func tearDown() { PackingEnv.reset(); _ = setPhases(DEFAULT_PHASES) }

    private func library() -> Library {
        var lib = Library()
        var list = newList(name: "Base", role: "base")
        list.items = [newItem(name: "Keys"), newItem(name: "Wallet"), newItem(name: "Passport")]
        lib.saveTemplate(list)
        return lib
    }

    @discardableResult
    private func addTrip(_ lib: inout Library, _ name: String, _ start: String, _ end: String) -> String {
        var trip = newEvent(name: name, startDate: start, endDate: end)
        trip.activities = lib.templates.map(\.id)
        trip.entries = buildTotalEntries(trip, lib.resolvedTemplates())
        lib.trips.append(trip)
        return trip.id
    }

    func testATripWithNothingTickedIsPlanned() {
        var lib = library()
        addTrip(&lib, "Later", "2026-11-01", "2026-11-03")
        let card = lib.tripCards(today: "2026-10-01")[0]
        XCTAssertEqual(card.state, .planned)
        XCTAssertEqual(card.when, .comingUp)
        XCTAssertEqual(card.done, 0)
        XCTAssertGreaterThan(card.total, 0)
        XCTAssertEqual(card.part, 0)
    }

    func testTickingOneThingMakesItPacking() {
        var lib = library()
        let id = addTrip(&lib, "Soon", "2026-10-05", "2026-10-06")
        let line = lib.trip(id)!.entries[0]
        _ = lib.setChecked(true, tripId: id, entryId: line.id)
        let card = lib.tripCards(today: "2026-10-01")[0]
        XCTAssertEqual(card.state, .packing)
        XCTAssertEqual(card.done, 1)
        XCTAssertEqual(card.part, 1.0 / Double(card.total), accuracy: 0.0001)
    }

    func testEverythingDecidedIsPacked() {
        var lib = library()
        let id = addTrip(&lib, "Ready", "2026-10-05", "2026-10-06")
        for line in lib.trip(id)!.entries.dropLast() { _ = lib.setChecked(true, tripId: id, entryId: line.id) }
        // The last one is SET ASIDE, not ticked — his rule: that counts as handled.
        _ = lib.setAside(true, tripId: id, entryId: lib.trip(id)!.entries.last!.id)
        let card = lib.tripCards(today: "2026-10-01")[0]
        XCTAssertEqual(card.state, .packed, "set aside should count as decided")
        XCTAssertEqual(card.aside, 1)
        XCTAssertEqual(card.done, card.total)
    }

    func testAReviewedTripSaysSoWhateverItsTicks() {
        var lib = library()
        let id = addTrip(&lib, "Been there", "2026-08-01", "2026-08-03")
        _ = lib.saveReview(tripId: id, unused: [], missed: [], when: nowISO())
        let card = lib.tripCards(today: "2026-10-01")[0]
        XCTAssertEqual(card.state, .reviewed)
        XCTAssertEqual(card.when, .been)
    }

    func testATripHappeningTodayIsNow() {
        var lib = library()
        addTrip(&lib, "On it", "2026-10-01", "2026-10-04")
        XCTAssertEqual(lib.tripCards(today: "2026-10-02")[0].when, .now)
        XCTAssertEqual(lib.tripCards(today: "2026-10-04")[0].when, .now, "the last day still counts as now")
        XCTAssertEqual(lib.tripCards(today: "2026-10-05")[0].when, .been)
    }

    func testTheOpenToDosAreCounted() {
        var lib = library()
        XCTAssertEqual(lib.openToDoCount(), 0)
        let a = lib.addAction(text: "Book the ferry")!
        _ = lib.addAction(text: "Service the bike")
        XCTAssertEqual(lib.openToDoCount(), 2)
        lib.setActionDone(true, id: a.id)
        XCTAssertEqual(lib.openToDoCount(), 1, "a done to-do is not still to do")
    }
}
