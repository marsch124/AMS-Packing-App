import XCTest
import PackingCore
@testable import PackingLibrary

/// The trip's "＋ Add" field offers his own things, and adds that very thing.
final class AddSuggestionsTests: XCTestCase {
    override func setUp() { PackingEnv.reset(); _ = setPhases(DEFAULT_PHASES) }
    override func tearDown() { PackingEnv.reset(); _ = setPhases(DEFAULT_PHASES) }

    private func library() -> (Library, String) {
        var lib = Library()
        var names = ["Charger cable", "Camera charger", "Charm", "Chart", "Chalk", "Socks"]
        names = names + ["Éclair"]
        lib.items = names.map { newItem(name: $0) }
        var trip = newEvent(name: "T", startDate: "2026-10-03", endDate: "2026-10-05")
        trip.entries = []
        lib.trips = [trip]
        return (lib, trip.id)
    }

    func testStartsWithComesFirstAndLimitHolds() {
        let (lib, id) = library()
        let got = lib.addSuggestions(tripId: id, typed: " char ").map(\.name)
        XCTAssertEqual(got, ["Charger cable", "Charm", "Chart", "Camera charger"])
        XCTAssertEqual(lib.addSuggestions(tripId: id, typed: "char", limit: 2).count, 2)
    }

    func testEmptyAndDiacritics() {
        let (lib, id) = library()
        XCTAssertTrue(lib.addSuggestions(tripId: id, typed: "  ").isEmpty)
        XCTAssertEqual(lib.addSuggestions(tripId: id, typed: "ECLA").map(\.name), ["Éclair"])
    }

    func testAlreadyOnTripLeftOut() {
        var (lib, id) = library()
        let chalk = lib.items.first { $0.name == "Chalk" }!
        _ = lib.addOwnThing(tripId: id, itemId: chalk.id)
        _ = lib.addCustomLine(tripId: id, name: "charm")
        let got = lib.addSuggestions(tripId: id, typed: "cha").map(\.name)
        XCTAssertFalse(got.contains("Chalk"))
        XCTAssertFalse(got.contains("Charm"))
    }

    func testAddOwnThingCarriesItsFields() {
        var (lib, id) = library()
        var thing = newItem(name: "Tripod", container: "Duffel", phase: "day-before")
        thing.weight = 900
        lib.items.append(thing)
        guard let line = lib.addOwnThing(tripId: id, itemId: thing.id) else { return XCTFail("no line") }
        XCTAssertEqual(line.container, "Duffel")
        XCTAssertEqual(line.phase, "day-before")
        XCTAssertEqual(line.sourceItemId, thing.id)
        XCTAssertEqual(line.weight, 900)
        XCTAssertTrue(lib.trip(id)!.entries.contains { $0.sourceItemId == thing.id })
    }
}
