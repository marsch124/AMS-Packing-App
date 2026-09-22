import XCTest
import PackingCore
@testable import PackingLibrary

/// Invented data only — this repository is public.
final class CreateTripTests: XCTestCase {

    override func setUp() { PackingEnv.freeze() }
    override func tearDown() { PackingEnv.reset(); _ = setPhases(DEFAULT_PHASES) }

    func testATripIsBuiltFromItsTemplatesAndTheBase() {
        var lib = LibraryTests.sample()
        lib.trips = []
        var base = newList(name: "Common base", role: "base"); base.items = [newItem(name: "Passport")]
        lib.saveTemplate(base)
        let hiking = lib.templates.first { $0.name == "Hiking" }!
        var draft = newEvent(name: "Fjäll", startDate: "2026-10-03", endDate: "2026-10-05")
        draft.activities = [hiking.id]
        let trip = lib.createTrip(draft)
        XCTAssertEqual(lib.trips.count, 1)
        XCTAssertEqual(trip.nights, 2, "nights come from the dates")
        XCTAssertTrue(trip.entries.contains { $0.name == "Passport" }, "the base list is always packed")
        XCTAssertTrue(trip.entries.contains { $0.name == "Headlamp" })
        XCTAssertFalse(trip.entries.contains { $0.name == "Goggles" }, "an unticked list is not")
        XCTAssertEqual(trip.entries.map(\.name), buildTotalEntries(trip, lib.resolvedTemplates()).map(\.name), "the lines are the model's")
        XCTAssertFalse(trip.generatedAt.isEmpty)
    }

    func testAQuickTripSkipsTheBase() {
        var lib = LibraryTests.sample()
        lib.trips = []
        var base = newList(name: "Common base", role: "base"); base.items = [newItem(name: "Passport")]
        lib.saveTemplate(base)
        var draft = newEvent(name: "Swim", mode: "quick")
        draft.activities = [lib.templates.first { $0.name == "Night run" }!.id]
        let trip = lib.createTrip(draft)
        XCTAssertFalse(trip.entries.contains { $0.name == "Passport" })
        XCTAssertTrue(trip.entries.contains { $0.name == "Headlamp" })
    }

    func testTheChoicesAreHisGroupsInHisOrder() {
        var lib = LibraryTests.sample()
        var swim = newList(name: "Swim", group: "WET"); swim.items = [newItem(name: "Goggles")]
        var bike = newList(name: "Bike", group: "WET"); bike.items = [newItem(name: "Helmet")]
        var hike = lib.resolvedTemplates().first { $0.name == "Hiking" }!; hike.group = "GA"
        lib.saveTemplate(swim); lib.saveTemplate(bike); lib.saveTemplate(hike)
        let choices = lib.activityChoices()
        XCTAssertEqual(choices.map { $0.group.id }, ["GA", "WET"])
        XCTAssertEqual(choices.last?.lists.map(\.name), ["Swim", "Bike"], "race order, not the alphabet")
    }
}

final class CustomLineTests: XCTestCase {
    override func setUp() { PackingEnv.freeze() }
    override func tearDown() { PackingEnv.reset(); _ = setPhases(DEFAULT_PHASES) }

    func testATypedThingJoinsTheTripAndSurvivesARegenerate() {
        var lib = LibraryTests.sample()
        let trip = lib.trips[0]
        let before = trip.entries.count
        let line = lib.addCustomLine(tripId: trip.id, name: "  Tripod ")
        XCTAssertEqual(line?.name, "Tripod")
        XCTAssertEqual(lib.trips[0].entries.count, before + 1)
        XCTAssertTrue(lib.trips[0].entries.last!.custom)
        XCTAssertEqual(progress(lib.trips[0].entries).total, before + 1)
        XCTAssertTrue(lib.regenerated(lib.trips[0]).contains { $0.name == "Tripod" }, "a custom line is never dropped")
        XCTAssertNil(lib.addCustomLine(tripId: trip.id, name: "   "), "nothing is added for a blank name")
        XCTAssertNil(lib.addCustomLine(tripId: "no-such-trip", name: "Tripod"))
    }
}

final class ActionsTests: XCTestCase {
    override func setUp() { PackingEnv.freeze() }
    override func tearDown() { PackingEnv.reset() }

    func testToDosAreAddedTickedAndOrderedTheWebAppsWay() {
        var lib = Library()
        let a = lib.addAction(text: " Book the ferry ")!
        let b = lib.addAction(text: "Charge the lamp", priority: "high")!
        XCTAssertEqual(a.text, "Book the ferry")
        XCTAssertEqual(lib.sortedActions().map(\.id), [b.id, a.id], "high before normal")
        XCTAssertTrue(lib.setActionDone(true, id: b.id))
        XCTAssertEqual(lib.sortedActions().map(\.id), [a.id, b.id], "open before done")
        XCTAssertFalse(lib.actions.first { $0.id == b.id }!.doneAt.isEmpty)
        XCTAssertNil(lib.addAction(text: "  "))
        lib.deleteAction(id: a.id)
        XCTAssertEqual(lib.actions.count, 1)
        XCTAssertEqual(lib.records().filter { $0.table == .actions }.count, 1, "one record per to-do")
    }
}
