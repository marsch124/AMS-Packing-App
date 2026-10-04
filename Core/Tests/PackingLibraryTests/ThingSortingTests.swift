import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// Sorting by more than one column (his ask, 4 Oct 2026): "sorting on travel as a
/// top sort criterion and then sorting on section as an under criterion."
final class ThingSortingTests: XCTestCase {
    override func setUp() { PackingEnv.freeze() }
    override func tearDown() { PackingEnv.reset() }

    /// Travel with two sections in the order Shoes, Clothes; a thing on Travel
    /// without a section; things not on Travel at all.
    private func library() -> (Library, String) {
        var lib = Library()
        var travel = newList(name: "Travel", group: "GA")
        travel.items = ["Shirt", "Boots", "Charger", "Sandals"].map { newItem(name: $0) }
        lib.saveTemplate(travel)
        var swim = newList(name: "Swim", group: "WET")
        swim.items = ["Goggles", "Apron"].map { newItem(name: $0) }
        lib.saveTemplate(swim)
        let id = lib.templates.first { $0.name == "Travel" }!.id
        let shoes = lib.addSection(templateId: id, name: "Shoes")!
        let clothes = lib.addSection(templateId: id, name: "Clothes")!
        let where_ = ["Shirt": clothes.id, "Boots": shoes.id, "Sandals": shoes.id]
        for (name, section) in where_ {
            let item = lib.items.first { $0.name == name }!.id
            let mem = lib.memberships.first { $0.itemId == item && $0.templateId == id }!.id
            _ = lib.updateMembership(memId: mem) { $0.section = section }
        }
        let grams: [String: Double] = ["Shirt": 200, "Boots": 1200, "Sandals": 400, "Goggles": 50]
        for n in lib.items.indices { lib.items[n].weight = grams[lib.items[n].name] ?? 0 }
        return (lib, id)
    }

    private func order(_ lib: Library, _ levels: [SortLevel]) -> [String] {
        lib.sortThings(lib.items, by: levels).map(\.name)
    }

    func testTravelThenItsSectionsListsTheTravelThingsSectionBySection() {
        let (lib, id) = library()
        XCTAssertEqual(order(lib, [SortLevel(key: "list:\(id)"), SortLevel(key: "section:\(id)")]),
                       ["Boots", "Sandals", "Shirt", "Charger", "Apron", "Goggles"],
                       "Shoes first (the template's order, not A–Z), then Clothes, then on Travel with no section, then the rest by name")
    }

    func testALowerLevelOnlyDecidesBetweenThingsTheLevelAboveCallsEqual() {
        let (lib, id) = library()
        // Within Shoes, the heavier first.
        XCTAssertEqual(order(lib, [SortLevel(key: "section:\(id)"), SortLevel(key: "weight", descending: true)]).prefix(3),
                       ["Boots", "Sandals", "Shirt"])
        XCTAssertEqual(order(lib, [SortLevel(key: "section:\(id)"), SortLevel(key: "weight")]).prefix(3),
                       ["Sandals", "Boots", "Shirt"])
    }

    func testABlankGoesLastWhicheverWayTheLevelRuns() {
        let (lib, _) = library()
        XCTAssertEqual(order(lib, [SortLevel(key: "weight")]), ["Goggles", "Shirt", "Sandals", "Boots", "Apron", "Charger"])
        XCTAssertEqual(order(lib, [SortLevel(key: "weight", descending: true)]), ["Boots", "Sandals", "Shirt", "Goggles", "Apron", "Charger"])
    }

    func testOnlyThreeLevelsCountAndNoLevelMeansByName() {
        let (lib, _) = library()
        XCTAssertEqual(order(lib, []), ["Apron", "Boots", "Charger", "Goggles", "Sandals", "Shirt"])
        let four = [SortLevel(key: "name"), SortLevel(key: "name"), SortLevel(key: "name"), SortLevel(key: "weight")]
        XCTAssertEqual(order(lib, four), order(lib, []), "a fourth level must not count")
    }
}
