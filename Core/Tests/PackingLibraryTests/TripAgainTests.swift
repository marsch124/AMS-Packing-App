import XCTest
@testable import PackingCore
@testable import PackingLibrary

final class TripAgainTests: XCTestCase {
    override func setUp() { PackingEnv.freeze() }
    override func tearDown() { PackingEnv.reset() }

    /// The web app's "Start a new trip from this one": the list as it ended up,
    /// hand-added lines and set-asides included; nothing ticked, no answers from
    /// the old review, no dates, no weather — and the old trip untouched.
    func testANewTripStartsFromThisOnesList() {
        var lib = Library()
        var old = newEvent(name: "Run and swim", mode: "quick", activities: ["run", "swim"], transport: "RV",
                           season: "Summer", contexts: ["Outdoor"], weatherOn: ["rain"], catering: "self",
                           startDate: "2026-09-26", endDate: "2026-09-27", laundry: true, destination: "Finspång")
        var shoes = newItem(name: "Running shoes"); shoes.checked = true; shoes.used = true
        shoes.extra["packedAt"] = .string("2026-09-25T18:00:00.000Z")
        var cap = newItem(name: "Swim cap"); cap.skipped = true
        var mine = newItem(name: "Tripod"); mine.custom = true; mine.checked = true; mine.used = false
        old.entries = [shoes, cap, mine]
        old.status = "done"; old.reviewedAt = "2026-09-28T08:00:00.000Z"
        lib.trips = [old]

        let copy = lib.startAgain(from: old.id, name: "  Run and swim (again) ")
        XCTAssertNotNil(copy)
        guard let copy else { return }
        XCTAssertEqual(lib.trips.count, 2, "the copy is a trip of its own")
        XCTAssertEqual(copy.name, "Run and swim (again)", "the name is trimmed")
        XCTAssertNotEqual(copy.id, old.id)
        XCTAssertEqual(copy.entries.map(\.name), ["Running shoes", "Swim cap", "Tripod"], "the list as it ended up")
        XCTAssertTrue(Set(copy.entries.map(\.id)).isDisjoint(with: old.entries.map(\.id)), "its lines are its own")
        XCTAssertFalse(copy.entries.contains { $0.checked }, "nothing ticked")
        XCTAssertTrue(copy.entries.allSatisfy { $0.used == nil }, "no answers from the old review")
        XCTAssertNil(copy.entries[0].extra["packedAt"], "no packing time")
        XCTAssertTrue(copy.entries[1].skipped, "a set-aside stays set aside, as in the web app")
        XCTAssertTrue(copy.entries[2].custom, "a hand-added line comes along")
        XCTAssertEqual(copy.mode, "quick"); XCTAssertEqual(copy.activities, ["run", "swim"])
        XCTAssertEqual(copy.transport, "RV"); XCTAssertEqual(copy.contexts, ["Outdoor"])
        XCTAssertEqual(copy.weatherOn, ["rain"]); XCTAssertEqual(copy.catering, "self")
        XCTAssertTrue(copy.laundry); XCTAssertEqual(copy.destination, "Finspång")
        XCTAssertEqual(copy.startDate, "", "no dates: they belonged to the old trip")
        XCTAssertEqual(copy.endDate, "")
        XCTAssertEqual(copy.status, "active", "not reviewed")
        XCTAssertEqual(copy.reviewedAt, "")
        XCTAssertEqual(lib.trips[0].entries.filter(\.checked).count, 2, "the old trip keeps its ticks")
        XCTAssertEqual(lib.trips[0].status, "done")

        XCTAssertNil(lib.startAgain(from: old.id, name: "   "), "no name, no trip")
        XCTAssertNil(lib.startAgain(from: "nope", name: "X"))
        XCTAssertEqual(lib.trips.count, 2)
        XCTAssertEqual(Library.againName("Run and swim"), "Run and swim (again)")
        XCTAssertEqual(Library.againName(""), "Trip (again)")
    }
}
