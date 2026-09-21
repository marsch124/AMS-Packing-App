import XCTest
import PackingCore
@testable import PackingLibrary

/// Invented data only — this repository is public.
final class LibraryTests: XCTestCase {

    override func setUp() { PackingEnv.freeze() }
    override func tearDown() {
        PackingEnv.reset()
        _ = setPhases(DEFAULT_PHASES)
        _ = setItemConditions(DEFAULT_ITEM_CONDITIONS)
    }

    /// A small library: a headlamp on two templates (in a different bag on each),
    /// spare batteries twice on ONE template with a different "When", and a trip.
    static func sample() -> Library {
        var lib = Library()
        let lamp = newItem(name: "Headlamp", container: "Day pack", phase: "week", consumable: true,
                           kit: "Light kit", packer: "Anna", ownedBy: "Anna")
        var hiking = newList(name: "Hiking")
        hiking.items = [lamp,
                        newItem(name: "Spare batteries", container: "Day pack", phase: "week"),
                        newItem(name: "Spare batteries", container: "Day pack", phase: "morning")]
        lib.saveTemplate(hiking)
        var running = newList(name: "Night run")
        var lampThere = lamp
        lampThere.container = "Duffel bag"            // an exception on THIS list only
        running.items = [lampThere]
        lib.saveTemplate(running)

        var trip = newEvent(name: "Weekend in the hills")
        trip.activities = [hiking.id]
        trip.entries = buildTotalEntries(trip, lib.resolvedTemplates())
        lib.trips = [trip]
        return lib
    }

    func sorted(_ r: [StoredRecord]) -> [StoredRecord] { r.sorted { $0.id < $1.id } }

    func testOneThingOnTwoTemplatesIsOneItemWithTwoMemberships() {
        let lib = LibraryTests.sample()
        XCTAssertEqual(lib.items.filter { $0.name == "Headlamp" }.count, 1)
        let lampId = lib.items.first { $0.name == "Headlamp" }!.id
        XCTAssertEqual(lib.memberships.filter { $0.itemId == lampId }.count, 2)
        let bags = lib.resolvedTemplates().map { t in t.items.first { $0.name == "Headlamp" }?.container ?? "" }
        XCTAssertEqual(Set(bags), ["Day pack", "Duffel bag"], "each list keeps its own bag for the same thing")
    }

    func testTheSameThingTwiceOnOneTemplateKeepsBothRows() {
        let lib = LibraryTests.sample()
        let hiking = lib.resolvedTemplates().first { $0.name == "Hiking" }!
        let phases = hiking.items.filter { $0.name == "Spare batteries" }.map(\.phase)
        XCTAssertEqual(phases, ["week", "morning"])
        XCTAssertEqual(lib.items.filter { $0.name == "Spare batteries" }.count, 1)
    }

    func testRecordsRoundTrip() {
        let lib = LibraryTests.sample()
        let back = Library(records: lib.records())
        XCTAssertTrue(recordChanges(from: lib.records(), to: back.records()).isEmpty)
        XCTAssertEqual(back.trips.first?.entries.map(\.id), lib.trips.first?.entries.map(\.id), "the lines keep their order")
        XCTAssertEqual(back.resolvedTemplates(), lib.resolvedTemplates())
    }

    func testATickIsOneSmallRecord() {
        var lib = LibraryTests.sample()
        let before = lib.records()
        let trip = lib.trips[0]
        XCTAssertTrue(lib.setChecked(true, tripId: trip.id, entryId: trip.entries[1].id))
        let changes = recordChanges(from: before, to: lib.records())
        XCTAssertEqual(changes.puts.map(\.table), [.entries], "a tick must not rewrite the trip, or two devices ticking would overwrite each other")
        XCTAssertTrue(changes.deletes.isEmpty)
    }

    func testALineTheTripHeadHasNotHeardOfIsStillShown() {
        let lib = LibraryTests.sample()
        var records = lib.records()
        let trip = lib.trips[0]
        // The other device added a line while this one saved the head.
        let extra = newItem(name: "Gaiters")
        records.append(StoredRecord(table: .entries, key: "\(trip.id)|\(extra.id)", parent: trip.id, json: extra.json))
        let back = Library(records: records)
        XCTAssertEqual(back.trips[0].entries.count, trip.entries.count + 1)
        XCTAssertEqual(back.trips[0].entries.last?.name, "Gaiters")
    }

    func testTwoRecordsWithOneKeySettleTheSameWayOnBothDevices() {
        let old = StoredRecord(table: .phases, key: "prep", json: ["id": "prep", "label": "Before"],
                               updatedAt: Date(timeIntervalSince1970: 100))
        let new = StoredRecord(table: .phases, key: "prep", json: ["id": "prep", "label": "Preparations"],
                               updatedAt: Date(timeIntervalSince1970: 200))
        XCTAssertEqual(settleDuplicates([old, new]).kept, [new])
        XCTAssertEqual(settleDuplicates([new, old]).kept, [new])
        XCTAssertEqual(settleDuplicates([new, old]).dropped, [old])
        // Written in the same instant: the content decides, not the order they arrived in.
        var twin = old; twin.json = ["id": "prep", "label": "Zebra"]
        XCTAssertEqual(settleDuplicates([old, twin]).kept, settleDuplicates([twin, old]).kept)
    }

    func testTakingAThingOffItsLastListKeepsTheThing() {
        var lib = LibraryTests.sample()
        var running = lib.resolvedTemplates().first { $0.name == "Night run" }!
        running.items = []
        lib.saveTemplate(running)
        var hiking = lib.resolvedTemplates().first { $0.name == "Hiking" }!
        hiking.items.removeAll { $0.name == "Headlamp" }
        lib.saveTemplate(hiking)
        XCTAssertEqual(lib.thingsOnNoList().map(\.name), ["Headlamp"])
        XCTAssertEqual(lib.thingsOnNoList().first?.packer, "Anna", "and it keeps what it knew about itself")
    }

    func testRegeneratingNeverDropsTheLinesOfADeletedTemplate() {
        var lib = LibraryTests.sample()
        let trip = lib.trips[0]
        XCTAssertGreaterThan(trip.entries.count, 0)
        XCTAssertTrue(trip.entries.allSatisfy { !$0.checked }, "unticked lines are the ones at risk")
        // He deletes the template the trip was built from.
        lib.templates.removeAll { $0.name == "Hiking" }
        lib.memberships.removeAll { $0.templateId == trip.activities[0] }
        XCTAssertEqual(regenerateEntries(trip, lib.resolvedTemplates()).count, 0, "the model alone would empty the trip")
        XCTAssertEqual(lib.regenerated(trip).map(\.id), trip.entries.map(\.id), "the library keeps every line, in order")
    }

    func testRegeneratingStillDropsWhatALivingTemplateNoLongerHas() {
        var lib = LibraryTests.sample()
        let trip = lib.trips[0]
        var hiking = lib.resolvedTemplates().first { $0.name == "Hiking" }!
        hiking.items.removeAll { $0.name == "Headlamp" }
        lib.saveTemplate(hiking)
        XCTAssertFalse(lib.regenerated(trip).contains { $0.name == "Headlamp" })
    }

    func testAnEmptyStoreIsAnEmptyLibrary() {
        XCTAssertTrue(Library(records: []).isEmpty)
        XCTAssertTrue(Library().records().isEmpty, "nothing is ever seeded into the store")
    }

    func testTheStoreOnlyEverSeesTheDifference() throws {
        let store = MemoryStore()
        var lib = LibraryTests.sample()
        try store.apply(recordChanges(from: [], to: lib.records()))
        let held = try store.loadAll()
        lib.setChecked(true, tripId: lib.trips[0].id, entryId: lib.trips[0].entries[0].id)
        try store.apply(recordChanges(from: held, to: lib.records()))
        XCTAssertEqual(store.log.last?.puts.count, 1)
        XCTAssertEqual(Library(records: try store.loadAll()).trips[0].entries[0].checked, true)
    }
}
