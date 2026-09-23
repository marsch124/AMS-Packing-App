import XCTest
import PackingCore
@testable import PackingLibrary

/// What his kit adds up to: weight, where things live, what is due — and tips
/// that are only ever said when they are TRUE of his library.
final class KitStatsTests: XCTestCase {
    override func setUp() { PackingEnv.reset(); _ = setPhases(DEFAULT_PHASES) }
    override func tearDown() { PackingEnv.reset(); _ = setPhases(DEFAULT_PHASES) }

    private func library() -> Library {
        var lib = Library()
        var base = newList(name: "Travel", role: "base")
        base.items = [
            { var i = newItem(name: "Tent"); i.weight = 2400; i.storage = "Garage"; return i }(),
            { var i = newItem(name: "Sleeping bag"); i.weight = 900; i.storage = "Garage"; return i }(),
            { var i = newItem(name: "Head torch"); i.weight = 80; i.storage = "Hall closet"; return i }(),
            { var i = newItem(name: "Toothbrush"); return i }(),          // no weight, no place
        ]
        lib.saveTemplate(base)
        return lib
    }

    func testItCountsWhatIsThereAndSaysWhatIsMissing() {
        let s = library().kitStats(today: "2026-09-23")
        XCTAssertEqual(s.things, 4)
        XCTAssertEqual(s.weighed, 3)
        XCTAssertEqual(s.unweighed, 1)
        XCTAssertEqual(s.totalGrams, 3380)
        XCTAssertEqual(s.totalKilos, 3.4)
        XCTAssertEqual(s.withPlace, 3)
        XCTAssertEqual(s.withoutPlace, 1)
    }

    func testTheHeaviestComeFirst() {
        let s = library().kitStats(today: "2026-09-23")
        XCTAssertEqual(s.heaviest.map(\.name), ["Tent", "Sleeping bag", "Head torch"])
        XCTAssertEqual(s.heaviest.first?.place, "Garage")
    }

    func testWhereThingsLive() {
        let s = library().kitStats(today: "2026-09-23")
        XCTAssertEqual(s.places.first?.label, "Garage")
        XCTAssertEqual(s.places.first?.count, 2)
        XCTAssertEqual(s.places.first?.grams, 3300)
        XCTAssertTrue(s.places.contains { $0.label == "Nowhere said" && $0.count == 1 },
                      "a thing with no place should be counted as such, not hidden")
    }

    func testWhatEachListWeighs() {
        let s = library().kitStats(today: "2026-09-23")
        XCTAssertEqual(s.lists.first?.label, "Travel")
        XCTAssertEqual(s.lists.first?.grams, 3380)
    }

    func testCareDueIsCountedAndSpreadOverTheYear() {
        var lib = library()
        if let n = lib.items.firstIndex(where: { $0.name == "Tent" }) {
            lib.items[n].maintenance = Maintenance(notes: "Air it", intervalDays: 90, lastDone: "2026-01-01")
        }
        if let n = lib.items.firstIndex(where: { $0.name == "Sleeping bag" }) {
            lib.items[n].maintenance = Maintenance(notes: "Wash", intervalDays: 365, lastDone: "2026-09-01")
        }
        let s = lib.kitStats(today: "2026-09-23")
        XCTAssertEqual(s.withCare, 2)
        XCTAssertEqual(s.overdue, 1, "the tent was due in April")
        XCTAssertEqual(s.dueByMonth.reduce(0, +), 1, "only what is still ahead falls in a month")
    }

    func testATipIsOnlySaidWhenItIsTrue() {
        let s = library().kitStats(today: "2026-09-23")
        XCTAssertTrue(s.tips.contains { $0.contains("no storage place") })
        XCTAssertFalse(s.tips.contains { $0.contains("overdue") }, "nothing is overdue and it said so anyway")
        XCTAssertFalse(s.tips.contains { $0.contains("came home unused") }, "nothing has been reviewed yet")
        XCTAssertFalse(s.tips.contains { $0.contains("care notes") },
                       "a library of four things should not be nagged about care schedules")
    }

    /// The care nudge is for a library big enough for it to matter — his has 431
    /// things and two care notes.
    func testABigLibraryWithNoCareNotesIsNudged() {
        var lib = Library()
        var list = newList(name: "Everything", role: "base")
        list.items = (1...60).map { n in
            var i = newItem(name: "Thing \(n)"); i.storage = "Garage"; i.weight = 100; return i
        }
        lib.saveTemplate(list)
        let s = lib.kitStats(today: "2026-09-23")
        XCTAssertTrue(s.tips.contains { $0.contains("care notes") }, "60 things and no care notes went unmentioned")
        XCTAssertFalse(s.tips.contains { $0.contains("no storage place") }, "they all have a place")
    }

    func testThingsThatGoAlongAndAreNeverUsedAreNoticed() {
        var lib = library()
        if let n = lib.items.firstIndex(where: { $0.name == "Head torch" }) {
            lib.items[n].stats = ItemStats(packed: 3, used: 0, unused: 3, skipped: 0, lastReviewed: "2026-09-01")
        }
        let s = lib.kitStats(today: "2026-09-23")
        XCTAssertEqual(s.neverUsed, ["Head torch"])
        XCTAssertTrue(s.tips.contains { $0.contains("came home unused") })
    }

    func testARetiredThingIsNotPartOfTheKit() {
        var lib = library()
        if let n = lib.items.firstIndex(where: { $0.name == "Tent" }) { lib.items[n].retired = true }
        let s = lib.kitStats(today: "2026-09-23")
        XCTAssertEqual(s.things, 3)
        XCTAssertEqual(s.totalGrams, 980, "a retired thing still counted towards the weight")
    }
}
