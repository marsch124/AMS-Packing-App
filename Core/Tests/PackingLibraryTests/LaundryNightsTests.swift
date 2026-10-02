import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// Laundry nights (his idea, 2 Oct 2026): a trip says how many nights' worth to pack
/// before a wash; without a choice it is the web app's 4.
final class LaundryNightsTests: XCTestCase {
    override func setUp() { PackingEnv.freeze() }
    override func tearDown() { PackingEnv.reset() }

    func testTheTripsChoiceCapsThePerNightCount() {
        var trip = newEvent(name: "Two months", startDate: "2026-11-01", endDate: "2026-12-31")
        trip.nights = 60
        XCTAssertEqual(qtyNights(trip), 60, "no laundry: every night counts")
        trip.laundry = true
        XCTAssertEqual(qtyNights(trip), LAUNDRY_CAP_NIGHTS, "laundry without a choice: the web app's 4")
        trip.extra[LAUNDRY_NIGHTS_KEY] = .number(7)
        XCTAssertEqual(qtyNights(trip), 7, "his choice of 7 is not used")
        var sock = newItem(name: "Socks"); sock.perNight = true
        XCTAssertEqual(effectiveQty(sock, qtyNights(trip)), 7)
        XCTAssertTrue(laundryWashes(trip), "60 nights packing 7: washed")
        trip.nights = 6
        XCTAssertFalse(laundryWashes(trip), "6 nights packing 7 washes nothing, yet says laundry")
        XCTAssertEqual(qtyNights(trip), 6)
        trip.nights = 3
        XCTAssertEqual(qtyNights(trip), 3, "a short trip is never raised to the cap")
        trip.nights = 60
        for odd in [0.0, -2, 100, .nan] {
            trip.extra[LAUNDRY_NIGHTS_KEY] = .number(odd)
            XCTAssertEqual(qtyNights(trip), LAUNDRY_CAP_NIGHTS, "an impossible choice (\(odd)) is not ignored")
        }
    }

    func testAStartedAgainTripAndTheStoredRecordsKeepTheChoice() {
        var lib = Library()
        var trip = newEvent(name: "Two months", startDate: "2026-11-01", endDate: "2026-12-31")
        trip.laundry = true
        trip.extra[LAUNDRY_NIGHTS_KEY] = .number(7)
        let made = lib.createTrip(trip)
        XCTAssertEqual(laundryNights(lib.trips[0]), 7, "creating the trip lost the choice")
        let again = lib.startAgain(from: made.id, name: "Next time")
        XCTAssertEqual(again.map(laundryNights), 7, "Start again lost the choice")
        let back = Library(records: lib.records())
        XCTAssertEqual(back.trips.first { $0.id == made.id }.map(laundryNights), 7, "the stored records lost the choice")
    }
}
