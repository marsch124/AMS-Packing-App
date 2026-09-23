import XCTest
import PackingCore
@testable import PackingLibrary

/// When each list was last taken along — the line that makes the Templates screen
/// worth looking at rather than a list of names.
final class TemplateUseTests: XCTestCase {
    override func setUp() { PackingEnv.reset(); _ = setPhases(DEFAULT_PHASES) }
    override func tearDown() { PackingEnv.reset(); _ = setPhases(DEFAULT_PHASES) }

    private func library() -> (Library, String, String) {
        var lib = Library()
        var base = newList(name: "Base", role: "base")
        base.items = [newItem(name: "Keys")]
        lib.saveTemplate(base)
        var hike = newList(name: "Hiking", group: "GA")
        hike.items = [newItem(name: "Boots")]
        lib.saveTemplate(hike)
        let baseId = lib.templates.first { $0.name == "Base" }!.id
        let hikeId = lib.templates.first { $0.name == "Hiking" }!.id
        return (lib, baseId, hikeId)
    }

    private func addTrip(_ lib: inout Library, _ name: String, _ start: String, using: [String]) {
        var trip = newEvent(name: name, startDate: start, endDate: start)
        trip.activities = using
        trip.entries = buildTotalEntries(trip, lib.resolvedTemplates())
        lib.trips.append(trip)
    }

    func testAListNobodyHasTakenSaysNothing() {
        let (lib, baseId, _) = library()
        XCTAssertNil(lib.templateUse()[baseId])
    }

    func testTheMostRecentTripWins() {
        var (lib, baseId, hikeId) = library()
        addTrip(&lib, "Old walk", "2026-05-01", using: [hikeId])
        addTrip(&lib, "Last walk", "2026-08-14", using: [hikeId])
        addTrip(&lib, "Town", "2026-07-01", using: [])          // base comes along by role

        let use = lib.templateUse()
        XCTAssertEqual(use[hikeId]?.lastTrip, "Last walk")
        XCTAssertEqual(use[hikeId]?.lastDate, "2026-08-14")
        XCTAssertEqual(use[hikeId]?.trips, 2)
        XCTAssertEqual(use[baseId]?.trips, 3, "the base list goes on every trip through its lines")
    }

    func testATripWithNoDateStillCountsButNeverWins() {
        var (lib, _, hikeId) = library()
        addTrip(&lib, "Dated", "2026-08-14", using: [hikeId])
        addTrip(&lib, "No date", "", using: [hikeId])
        let use = lib.templateUse()
        XCTAssertEqual(use[hikeId]?.trips, 2)
        XCTAssertEqual(use[hikeId]?.lastTrip, "Dated", "a trip with no date should not look like the latest")
    }
}
