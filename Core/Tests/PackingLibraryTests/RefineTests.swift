import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// Refine: what two or more reviewed trips say a list carries for nothing.
final class RefineTests: XCTestCase {
    override func setUp() { PackingEnv.freeze() }
    override func tearDown() { PackingEnv.reset() }

    private func library() -> (Library, hike: String, run: String) {
        var lib = Library()
        var hike = newList(name: "Hike"); hike.items = [newItem(name: "Tripod"), newItem(name: "Map"), newItem(name: "First aid")]
        var run = newList(name: "Run"); run.items = [newItem(name: "Tripod")]
        lib.saveTemplate(hike); lib.saveTemplate(run)
        func set(_ name: String, _ s: ItemStats) { _ = lib.updateThing(id: lib.items.first { $0.name == name }!.id) { $0.stats = s } }
        set("Tripod", ItemStats(packed: 3, used: 0, unused: 3))          // packed 3×, never used
        set("Map", ItemStats(packed: 0, skipped: 2))                     // listed 2×, never packed
        set("First aid", ItemStats(packed: 1, used: 0, unused: 1))       // one quiet trip — not evidence
        let h = lib.templates.first { $0.name == "Hike" }!.id, r = lib.templates.first { $0.name == "Run" }!.id
        return (lib, h, r)
    }

    func testTwoTripsOfEvidenceAreOfferedAndOneIsNot() {
        let (lib, _, _) = library()
        let s = lib.refineSuggestions()
        XCTAssertEqual(Set(s.map { "\($0.item.name)|\($0.listName)|\($0.reason)" }),
                       ["Tripod|Hike|never-used", "Tripod|Run|never-used", "Map|Hike|never-packed"])
        XCTAssertFalse(s.contains { $0.item.name == "First aid" }, "one quiet trip is not evidence")
        XCTAssertEqual(s.first?.times, 3, "most trips first")
    }

    func testKeepSettlesItAndDropTakesItOffOneListOnly() {
        var (lib, hike, run) = library()
        let tripod = lib.items.first { $0.name == "Tripod" }!.id
        let map = lib.items.first { $0.name == "Map" }!.id
        XCTAssertTrue(lib.dropFromList(itemId: tripod, listId: hike))
        XCTAssertEqual(lib.listsOf(itemId: tripod), ["Run"], "dropped from Hike only")
        XCTAssertTrue(lib.items.contains { $0.id == tripod }, "the thing stays his")
        XCTAssertFalse(lib.dropFromList(itemId: tripod, listId: hike), "not on that list any more")
        XCTAssertTrue(lib.keepThing(id: map))
        let left = lib.refineSuggestions().map { "\($0.item.name)|\($0.listName)" }
        XCTAssertEqual(left, ["Tripod|Run"], "kept and dropped are no longer offered")
        _ = run
    }
}
