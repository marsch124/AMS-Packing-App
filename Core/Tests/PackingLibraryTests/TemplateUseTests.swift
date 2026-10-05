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

    /// A trip still ahead is not "last taken" (the spec pass, 5 Oct 2026: the card
    /// said "in 30 days" where it meant "last"): it is the NEXT one.
    func testATripStillAheadIsNextNotLast() {
        var (lib, _, hikeId) = library()
        addTrip(&lib, "Coming up", "2026-11-04", using: [hikeId])
        addTrip(&lib, "Later still", "2026-12-24", using: [hikeId])
        var use = lib.templateUse(today: "2026-10-05")[hikeId]
        XCTAssertEqual(use?.lastTrip, "", "a trip that has not begun counts as taken")
        XCTAssertEqual(use?.nextTrip, "Coming up", "the soonest trip ahead is not the next")
        XCTAssertEqual(use?.trips, 2)
        XCTAssertEqual(Library.TemplateUse.line(use, today: "2026-10-05"), "Next: in 30 days \u{00B7} Coming up")
        XCTAssertEqual(Library.TemplateUse.line(use, today: "2026-11-03"), "Next: tomorrow \u{00B7} Coming up")

        addTrip(&lib, "Last walk", "2026-10-03", using: [hikeId])
        use = lib.templateUse(today: "2026-10-05")[hikeId]
        XCTAssertEqual(Library.TemplateUse.line(use, today: "2026-10-05"), "2 days ago \u{00B7} Last walk",
                       "a template that has been out says when it was last out")
        XCTAssertEqual(Library.TemplateUse.line(nil, today: "2026-10-05"), "Never taken along")
        // Begun today counts as taken.
        addTrip(&lib, "Today's", "2026-10-05", using: [hikeId])
        XCTAssertEqual(lib.templateUse(today: "2026-10-05")[hikeId]?.lastTrip, "Today's")
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
