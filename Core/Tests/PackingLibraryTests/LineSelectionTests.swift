import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// Several lines selected on the Mac (0.105, his yes of 28 Oct 2026): ⌘-click, ⇧-click in the list's order
/// across headings, ⌘A, Esc — and the actions on the selection, each ONE change of the library: Tick, Untick,
/// Not this time, Move to bag.
final class LineSelectionTests: XCTestCase {
    override func setUp() { PackingEnv.freeze(at: "2026-10-01T12:00:00.000Z") }
    override func tearDown() { PackingEnv.reset() }

    /// The list as shown, sorted From where: Toothbrush; Passport, Charger; Torch, Map; Boots, Jacket.
    private let shown = ["tooth", "pass", "charger", "torch", "map", "boots", "jacket"]

    func testCommandAndShiftClickSelectInTheOrderTheListShows() {
        var s = LineSelection()
        s.toggle("pass")
        XCTAssertEqual(s.ids, ["pass"])
        // ⇧-click: every line between, in the list's order, across the headings — not the trip's order.
        s.extend(to: "map", shown: shown)
        XCTAssertEqual(s.ordered(shown), ["pass", "charger", "torch", "map"])
        // A second ⇧-click moves the END of the range: the Torch and the Map are let go.
        s.extend(to: "charger", shown: shown)
        XCTAssertEqual(s.ordered(shown), ["pass", "charger"])
        // Upwards from the anchor too.
        s.extend(to: "tooth", shown: shown)
        XCTAssertEqual(s.ordered(shown), ["tooth", "pass"])
        // ⌘-click adds one more without touching the range, and starts a new anchor.
        s.toggle("jacket")
        XCTAssertEqual(s.ordered(shown), ["tooth", "pass", "jacket"])
        s.extend(to: "map", shown: shown)
        XCTAssertEqual(s.ordered(shown), ["tooth", "pass", "map", "boots", "jacket"], "the range from the new anchor joins the rest")
        // ⌘-click on a selected line takes it out.
        s.toggle("pass")
        XCTAssertFalse(s.contains("pass"))
        XCTAssertEqual(s.count, 4)

        // ⇧-click with nothing ⌘-clicked: the line alone.
        var t = LineSelection()
        t.extend(to: "torch", shown: shown)
        XCTAssertEqual(t.ids, ["torch"])
        t.extend(to: "boots", shown: shown)
        XCTAssertEqual(t.ordered(shown), ["torch", "map", "boots"], "the first ⇧-click is the anchor")

        // ⌘A: every line shown; Esc clears.
        t.selectAll(shown)
        XCTAssertEqual(t.count, 7)
        t.clear()
        XCTAssertTrue(t.isEmpty)
        XCTAssertNil(t.anchor)

        // A heading folded: its lines leave the selection, and an anchor folded away is forgotten.
        var u = LineSelection()
        u.toggle("tooth"); u.toggle("torch"); u.toggle("map")
        u.keep(only: ["tooth", "pass", "charger", "boots", "jacket"])
        XCTAssertEqual(u.ids, ["tooth"])
        XCTAssertNil(u.anchor)
        XCTAssertEqual(LineSelection.things(1), "1 thing")
        XCTAssertEqual(LineSelection.things(4), "4 things")
    }

    /// A backpack with a front pocket and a day pack with a lid; Passport, Charger and Map in the backpack,
    /// a reminder; a trip under way (1–5 Oct).
    private func library() -> (Library, trip: String) {
        var lib = Library()
        let backpack = lib.addBag(name: "Backpack")!.id
        let day = lib.addBag(name: "Day pack")!.id
        XCTAssertTrue(lib.addPocket(bagId: backpack, name: "Front pocket"))
        XCTAssertTrue(lib.addPocket(bagId: day, name: "Lid"))
        lib.saveTemplate(newList(name: "Base", role: "base"))
        let base = lib.templates.first { $0.role == "base" }!.id
        for name in ["Passport", "Charger", "Map"] {
            let t = lib.addThing(name: name)!
            _ = lib.updateThing(id: t.id) { $0.container = "Backpack" }
            _ = lib.setOnTemplate(itemId: t.id, templateId: base, on: true)
        }
        XCTAssertTrue(lib.setUsualPocket(thingId: lib.items.first { $0.name == "Charger" }!.id, pocket: "Front pocket"))
        let trip = lib.createTrip(newEvent(name: "Away", startDate: "2026-10-01", endDate: "2026-10-05")).id
        _ = lib.addCustomLine(tripId: trip, name: "Call the neighbour")
        if let n = lib.trips[0].entries.firstIndex(where: { $0.name == "Call the neighbour" }) {
            lib.trips[0].entries[n].itemType = REMINDER_TYPE
        }
        return (lib, trip)
    }

    private func line(_ lib: Library, _ name: String) -> Item { lib.trips[0].entries.first { $0.name == name }! }
    private func ids(_ lib: Library, _ names: [String]) -> [String] { names.map { line(lib, $0).id } }

    /// Tick, Untick and Not this time on a selection: exactly the lines selected, each as a tap or ⊘ would.
    func testTickUntickAndNotThisTimeActOnEverySelectedLine() {
        var (lib, trip) = library()
        let two = ids(lib, ["Passport", "Charger"])
        let ticked = lib.setChecked(true, tripId: trip, entryIds: two)
        XCTAssertEqual(ticked.count, 2)
        XCTAssertTrue(line(lib, "Passport").checked && line(lib, "Charger").checked)
        XCTAssertFalse(line(lib, "Map").checked, "a line not selected was ticked")
        XCTAssertEqual(Library.pocket(line(lib, "Charger")), "Front pocket", "the usual pocket did not come with the tick")
        XCTAssertEqual(lib.setChecked(false, tripId: trip, entryIds: two).count, 2)
        XCTAssertFalse(line(lib, "Passport").checked || line(lib, "Charger").checked)

        _ = lib.setChecked(true, tripId: trip, entryIds: two)
        XCTAssertEqual(lib.setAside(true, tripId: trip, entryIds: ids(lib, ["Passport", "Charger", "Map"])), 3)
        XCTAssertTrue(["Passport", "Charger", "Map"].allSatisfy { isSetAside(line(lib, $0)) })
        XCTAssertFalse(line(lib, "Passport").checked, "set aside kept its tick")
        XCTAssertEqual(lib.setAside(true, tripId: trip, entryIds: two), 0, "a line already set aside counted again")
        XCTAssertEqual(lib.setAside(false, tripId: trip, entryIds: two), 2)
        XCTAssertFalse(isSetAside(line(lib, "Passport")))
        XCTAssertTrue(isSetAside(line(lib, "Map")), "a line not given was taken back")
        XCTAssertEqual(lib.setAside(true, tripId: "nope", entryIds: two), 0)
    }

    /// Move to bag: the lines go into the bag on this trip only — the thing keeps its own bag — and a rebuild
    /// from Trip settings and a later change to the thing leave them there. The pocket of the old bag goes (a
    /// ticked line gets the new bag's usual one); a reminder goes in no bag; and it survives the stored records
    /// and a backup.
    func testMoveToBagMovesTheLinesOnThisTripOnly() throws {
        var (lib, trip) = library()
        _ = lib.setChecked(true, tripId: trip, entryIds: ids(lib, ["Charger"]))
        XCTAssertEqual(Library.pocket(line(lib, "Charger")), "Front pocket")
        let moved = lib.moveLines(tripId: trip, entryIds: ids(lib, ["Passport", "Charger", "Call the neighbour"]), toBag: "Day pack")
        XCTAssertEqual(moved, 2, "the reminder went into a bag, or a line did not move")
        XCTAssertEqual(line(lib, "Passport").container, "Day pack")
        XCTAssertEqual(line(lib, "Charger").container, "Day pack")
        XCTAssertEqual(line(lib, "Map").container, "Backpack", "a line not selected moved")
        XCTAssertNotEqual(line(lib, "Call the neighbour").container, "Day pack", "a reminder went into a bag")
        XCTAssertEqual(Library.pocket(line(lib, "Charger")), "", "the backpack's front pocket stayed with a line in the day pack")
        XCTAssertTrue(line(lib, "Charger").checked, "moving took the tick")
        XCTAssertEqual(lib.items.first { $0.name == "Passport" }!.container, "Backpack", "the thing itself changed bag")
        XCTAssertEqual(lib.moveLines(tripId: trip, entryIds: ids(lib, ["Passport"]), toBag: "day PACK"), 0, "moved into the bag it is in")
        XCTAssertEqual(lib.moveLines(tripId: trip, entryIds: ids(lib, ["Map"]), toBag: "  "), 0, "moved into no bag")
        // What Move to bag offers: the trip's bags in the Bags card's order (the first line's bag first).
        XCTAssertEqual(lib.dayBags(tripId: trip), ["Day pack", "Backpack"], "the trip's bags")

        // A change to the thing, and a rebuild, leave the moved lines where he put them.
        let passport = lib.items.first { $0.name == "Passport" }!.id
        _ = lib.updateThing(id: passport) { $0.weight = 40 }
        _ = lib.followThing(id: passport, today: "2026-10-01")
        XCTAssertEqual(line(lib, "Passport").container, "Day pack", "a change to the thing took the line back")
        XCTAssertNotNil(lib.changeTrip(id: trip) { $0.name = "Away again" })
        XCTAssertEqual(line(lib, "Passport").container, "Day pack", "Trip settings' rebuild took the line back")

        // Kept in the stored records (synced), and in a backup.
        XCTAssertEqual(Library(records: lib.records()).trips[0].entries.first { $0.name == "Passport" }?.container, "Day pack")
        let restored = try Importer.read(lib.backupData(exportedAt: "2026-10-01T12:00:00.000Z")).library
        XCTAssertEqual(restored.trips[0].entries.first { $0.name == "Passport" }?.container, "Day pack", "a backup lost the move")
    }
}
