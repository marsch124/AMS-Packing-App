import XCTest
@testable import PackingCore

// Ported from tests/model.test.mjs — entriesByPhase, groupByContainer / Category /
// Section / Storage, groupBy, groupItemsBySection, sortRowsBy and groupRowsBy.
final class GroupingTests: XCTestCase {
    override func tearDown() {
        PackingEnv.reset()
        setPhases(DEFAULT_PHASES)
        super.tearDown()
    }

    /// The JS tests sort plain `{ n: … }` objects; this is that object.
    private struct Row: Equatable {
        var n = ""
        var m = ""
        var w = 0.0
        var c = ""
        var i = 0
    }

    // JS: 'entriesByPhase: only returns non-empty phases, in timeline order'
    func testEntriesByPhaseOnlyReturnsNonEmptyPhasesInTimelineOrder() {
        let entries = [newItem(name: "A", phase: "morning"), newItem(name: "B", phase: "prep")]
        let groups = entriesByPhase(entries)
        XCTAssertEqual(groups.map { $0.phase.id }, ["prep", "morning"])
    }

    // JS: 'entriesByPhase: an unknown phase gets its own group at the end, not merged away'
    func testEntriesByPhaseAnUnknownPhaseGetsItsOwnGroupAtTheEnd() {
        let groups = entriesByPhase([
            Item(id: "a", name: "Towel", phase: "week"),
            Item(id: "b", name: "Mystery", phase: "from-the-mac"),
            Item(id: "c", name: "Keys", phase: "door"),
        ])
        XCTAssertEqual(groups.map { $0.phase.id }, ["week", "door", "from-the-mac"])
        XCTAssertEqual(groups.last?.entries.count, 1)
        // Nothing is lost, and nothing was quietly moved into "≥1 week ahead".
        XCTAssertEqual(groups.reduce(0) { $0 + $1.entries.count }, 3)
    }

    // JS: 'groupByContainer: orders known containers first'
    func testGroupByContainerOrdersKnownContainersFirst() {
        let entries = [newItem(name: "A", container: "Golf bag"), newItem(name: "B", container: "Toiletry bag")]
        let groups = groupByContainer(entries)
        XCTAssertEqual(groups[0].container, "Toiletry bag")   // Toiletry bag precedes Golf bag in CONTAINERS
    }

    // JS: 'groupByCategory: groups by category in CATEGORIES order'
    func testGroupByCategoryGroupsByCategoryInCategoriesOrder() {
        let entries = [newItem(name: "Boots", category: "Footwear"), newItem(name: "Shirt", category: "Clothing")]
        let groups = groupByCategory(entries)
        XCTAssertEqual(groups[0].category, "Clothing")   // Clothing precedes Footwear in CATEGORIES
    }

    // JS: 'groupBy dispatcher: category / container / when all return labelled groups'
    func testGroupByDispatcherReturnsLabelledGroups() {
        let entries = [newItem(name: "X", category: "Clothing", container: "Golf bag", phase: "morning")]
        XCTAssertEqual(groupBy("category", entries)[0].label, "Clothing")
        XCTAssertEqual(groupBy("container", entries)[0].label, "Golf bag")
        XCTAssertEqual(groupBy("when", entries)[0].label, "Morning list")
    }

    // JS: 'groupItemsBySection: template order, empty sections omitted, ungrouped last'
    func testGroupItemsBySectionTemplateOrderEmptySectionsOmittedUngroupedLast() {
        let sections = [newSection("Lights"), newSection("Rig"), newSection("Regulators")]
        let (L, G) = (sections[0], sections[2])
        let items = [
            newItem(name: "Reg 1", section: G.id),
            newItem(name: "Light 1", section: L.id),
            newItem(name: "Loose thing"),                 // no section
            newItem(name: "Light 2", section: L.id),
        ]
        let groups = groupItemsBySection(items, sections)
        // Rig has no items -> omitted; Lights before Regulators (template order); Ungrouped last.
        XCTAssertEqual(groups.map { $0.section?.name ?? "Ungrouped" }, ["Lights", "Regulators", "Ungrouped"])
        XCTAssertEqual(groups[0].items.count, 2)
        XCTAssertNil(groups[2].section)
    }

    // JS: 'groupItemsBySection ignores a section id from another template'
    func testGroupItemsBySectionIgnoresASectionIdFromAnotherTemplate() {
        let items = [newItem(name: "X4", section: "sec-from-travel")]
        let groups = groupItemsBySection(items, [TemplateSection(id: "s-hk-9", name: "Electronics")])
        XCTAssertEqual(groups.count, 1)
        XCTAssertNil(groups[0].section, "it falls into Ungrouped rather than vanishing")
    }

    // JS: 'groupBySection: trip entries by name, first-appearance order, Everything else last'
    func testGroupBySectionFirstAppearanceOrderEverythingElseLast() {
        let entries = [
            newItem(name: "a", section: "Regulators"),
            newItem(name: "b", section: "Lights"),
            newItem(name: "c"),                            // unsectioned
            newItem(name: "d", section: "Regulators"),
        ]
        let groups = groupBySection(entries)
        XCTAssertEqual(groups.map { $0.label }, ["Regulators", "Lights", "Everything else"])
        XCTAssertEqual(groups[0].entries.count, 2)         // both Regulators merged
    }

    // JS: 'groupByStorage: groups by storage place, alphabetical, "No place set" last'
    func testGroupByStorageAlphabeticalNoPlaceSetLast() {
        let entries = [
            newItem(name: "Tent", storage: "Garage"),
            newItem(name: "Socks"),                        // no place
            newItem(name: "Charger", storage: "Bedroom wardrobe"),
            newItem(name: "Pump", storage: "Garage"),
        ]
        let groups = groupByStorage(entries)
        XCTAssertEqual(groups.map { $0.label }, ["Bedroom wardrobe", "Garage", "No place set"])
        XCTAssertEqual(groups[1].entries.count, 2)         // both Garage items together
        XCTAssertEqual(groupBy("stored", entries)[0].label, "Bedroom wardrobe")   // via the dispatcher
    }

    // ---- All-items index: sorting & grouping ----------------------------------

    // JS: 'sortRowsBy: text sorts A–Z, case-insensitively'
    func testSortRowsByTextSortsAToZCaseInsensitively() {
        let rows = [Row(n: "zebra"), Row(n: "Apple"), Row(n: "mango")]
        XCTAssertEqual(sortRowsBy(rows, { $0.n }).map { $0.n }, ["Apple", "mango", "zebra"])
        XCTAssertEqual(sortRowsBy(rows, { $0.n }, dir: "desc").map { $0.n }, ["zebra", "mango", "Apple"])
    }

    // JS: 'sortRowsBy: blanks sink to the bottom in BOTH directions'
    func testSortRowsByBlanksSinkToTheBottomInBothDirections() {
        let rows = [Row(m: ""), Row(m: "Osprey"), Row(m: "  "), Row(m: "Arcteryx")]
        let asc = sortRowsBy(rows, { $0.m }).map { jsTrim($0.m) }
        let desc = sortRowsBy(rows, { $0.m }, dir: "desc").map { jsTrim($0.m) }
        XCTAssertEqual(asc, ["Arcteryx", "Osprey", "", ""])
        XCTAssertEqual(desc, ["Osprey", "Arcteryx", "", ""], "a reversed sort must not lead with blanks")
    }

    // JS: 'sortRowsBy: numbers compare arithmetically and 0 counts as unrecorded'
    func testSortRowsByNumbersCompareArithmeticallyAndZeroCountsAsUnrecorded() {
        let rows = [Row(w: 90), Row(w: 0), Row(w: 1200), Row(w: 7)]
        XCTAssertEqual(sortRowsBy(rows, { $0.w }, num: true).map { $0.w }, [7, 90, 1200, 0])
        XCTAssertEqual(sortRowsBy(rows, { $0.w }, dir: "desc", num: true).map { $0.w }, [1200, 90, 7, 0])
    }

    // JS: 'sortRowsBy: ties settle by the tie-breaker, and never flip with direction'
    func testSortRowsByTiesSettleByTheTieBreakerAndNeverFlip() {
        let rows = [Row(n: "Towel", c: "Duffel bag"), Row(n: "Cap", c: "Duffel bag"), Row(n: "Map", c: "Day pack")]
        let tie: (Row, Row) -> Int = { a, b in jsLocaleCompare(a.n, b.n) }
        XCTAssertEqual(sortRowsBy(rows, { $0.c }, tie: tie).map { $0.n }, ["Map", "Cap", "Towel"])
        XCTAssertEqual(sortRowsBy(rows, { $0.c }, dir: "desc", tie: tie).map { $0.n }, ["Cap", "Towel", "Map"])
    }

    // JS: 'sortRowsBy: does not mutate the rows it is given'
    func testSortRowsByDoesNotMutateTheRowsItIsGiven() {
        let rows = [Row(n: "b"), Row(n: "a")]
        _ = sortRowsBy(rows, { $0.n })
        XCTAssertEqual(rows.map { $0.n }, ["b", "a"])
    }

    // JS: 'groupRowsBy: known buckets first in order, the rest A–Z, "not set" last'
    func testGroupRowsByKnownBucketsFirstTheRestAToZNotSetLast() {
        let rows = [Row(c: ""), Row(c: "Zulu bag"), Row(c: "Duffel bag"), Row(c: "Toiletry bag"), Row(c: "Alpha bag"), Row(c: "")]
        let out = groupRowsBy(rows, { $0.c }, order: CONTAINERS, emptyLabel: "No bag chosen")
        XCTAssertEqual(out.map { $0.label }, ["Toiletry bag", "Duffel bag", "Alpha bag", "Zulu bag", "No bag chosen"])
        XCTAssertEqual(out.last?.rows.count, 2)
    }

    // JS: 'groupRowsBy: keeps the incoming order inside each bucket (so the sort still applies)'
    func testGroupRowsByKeepsTheIncomingOrderInsideEachBucket() {
        let rows = [Row(c: "A", i: 1), Row(c: "B", i: 2), Row(c: "A", i: 3), Row(c: "A", i: 4)]
        let out = groupRowsBy(rows, { $0.c })
        XCTAssertEqual(out[0].rows.map { $0.i }, [1, 3, 4])
    }

    // JS: 'groupRowsBy: every row lands in exactly one bucket'
    func testGroupRowsByEveryRowLandsInExactlyOneBucket() {
        let rows = (0..<40).map { i in Row(c: i % 5 != 0 ? "bag \(i % 5)" : "") }
        let out = groupRowsBy(rows, { $0.c })
        XCTAssertEqual(out.reduce(0) { $0 + $1.rows.count }, 40)
    }

    // MARK: - Not in the JS suite — behaviour checked against the JS, pinned here

    func testGroupByContainerUnknownBagsFollowTheKnownOnesAlphabeticallyAndBlankIsOther() {
        let entries = [
            Item(name: "a", container: "Zebra sack"), Item(name: "b", container: ""),
            Item(name: "c", container: "Golf bag"), Item(name: "d", container: "Alpha sack"),
        ]
        XCTAssertEqual(groupByContainer(entries).map { $0.container }, ["Golf bag", "Other", "Alpha sack", "Zebra sack"])
        XCTAssertEqual(groupBy("container", entries).map { $0.label }, ["Golf bag", "Other", "Alpha sack", "Zebra sack"])
    }

    func testGroupByWhenCarriesThePhaseHintAndTheOtherModesDoNot() {
        let entries = [newItem(name: "X", phase: "door")]
        XCTAssertEqual(groupBy("when", entries)[0].hint, phase("door")?.hint)
        XCTAssertNil(groupBy("category", entries)[0].hint)
        XCTAssertEqual(groupBy("anything else", entries)[0].label, "At the front door")
    }

    func testSortRowsByReadsAJSONValueTheWayJSReadsAnyValue() {
        // num: a numeric STRING counts, junk and nothing are blank.
        let vals: [JSONValue] = ["12", .null, 3, "x", 0]
        let sorted = sortRowsBy(vals, { (v: JSONValue) -> JSONValue? in v }, num: true)
        XCTAssertEqual(Array(sorted.prefix(2)), [3, "12"])
        // text: a number sorts as its text ("10" before "9"), and null is blank.
        let text: [JSONValue] = [.null, "9", 10]
        XCTAssertEqual(sortRowsBy(text, { (v: JSONValue) -> JSONValue? in v }), [10, "9", .null])
    }
}
