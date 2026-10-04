import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// Every column of the things table is a filter (his ask, 4 Oct 2026): "all
/// existing columns to be able to be used as filter criteria".
final class ThingFiltersTests: XCTestCase {
    override func setUp() { PackingEnv.freeze() }
    override func tearDown() { PackingEnv.reset() }

    /// Travel (with a Clothes section) and Swim; owners, weights, a flag.
    private func library() -> Library {
        var lib = Library()
        var travel = newList(name: "Travel", group: "GA")
        travel.items = [newItem(name: "Jacket"), newItem(name: "Socks"), newItem(name: "Charger")]
        lib.saveTemplate(travel)
        var swim = newList(name: "Swim", group: "WET")
        swim.items = [newItem(name: "Goggles"), newItem(name: "Socks")]
        lib.saveTemplate(swim)
        lib.saveTemplate({ var l = newList(name: "Spare"); l.items = [newItem(name: "Umbrella")]; return l }())
        _ = lib.setOnTemplate(itemId: lib.items.first { $0.name == "Umbrella" }!.id,
                              templateId: lib.templates.first { $0.name == "Spare" }!.id, on: false)
        let travelId = lib.templates.first { $0.name == "Travel" }!.id
        let clothes = lib.addSection(templateId: travelId, name: "Clothes")!
        for name in ["Jacket", "Socks"] {
            let item = lib.items.first { $0.name == name }!.id
            let mem = lib.memberships.first { $0.itemId == item && $0.templateId == travelId }!.id
            _ = lib.updateMembership(memId: mem) { $0.section = clothes.id; $0.qty = name == "Socks" ? "3" : "" }
        }
        let owners = ["Jacket": "Kim", "Socks": "Robin", "Charger": "kim ", "Goggles": ""]
        let grams: [String: Double] = ["Jacket": 900, "Socks": 60, "Charger": 120, "Umbrella": 1400]
        for n in lib.items.indices {
            lib.items[n].ownedBy = owners[lib.items[n].name] ?? ""
            lib.items[n].weight = grams[lib.items[n].name] ?? 0
            lib.items[n].charging = lib.items[n].name == "Charger"
        }
        return lib
    }

    private func names(_ lib: Library, _ filters: ThingFilters) -> [String] {
        lib.items.filter { lib.passes($0, filters) }.map(\.name).sorted()
    }

    func testAWordsColumnOffersItsAnswersAToZWithBlankLastAndFilters() {
        let lib = library()
        let answers = lib.filterAnswers(column: "ownedBy", among: lib.items)
        // "kim " and "Kim" are one owner; the first spelling is the one shown.
        // No owner: each has one of their own (his words, 4 Oct 2026).
        XCTAssertEqual(answers.map(\.label), ["Kim", "Robin", "Both have one"])
        XCTAssertEqual(answers.map(\.count), [2, 1, 2])
        XCTAssertEqual(names(lib, ["ownedBy": ["kim"]]), ["Charger", "Jacket"])
        XCTAssertEqual(names(lib, ["ownedBy": ["kim", "robin"]]), ["Charger", "Jacket", "Socks"], "two answers in one column = either")
        XCTAssertEqual(names(lib, ["ownedBy": [""]]), ["Goggles", "Umbrella"], "Blank keeps the things with no owner")
        XCTAssertEqual(names(lib, ["ownedBy": []]).count, lib.items.count, "nothing ticked filters nothing")
    }

    func testTwoColumnsMustBothHold() {
        let lib = library()
        XCTAssertEqual(names(lib, ["ownedBy": ["kim"], "charging": ["no"]]), ["Jacket"])
        XCTAssertEqual(lib.filterAnswers(column: "charging", among: lib.items).map(\.label), ["Yes", "No"])
    }

    func testWeightsAreGroupedLightToHeavy() {
        let lib = library()
        XCTAssertEqual(lib.filterAnswers(column: "weight", among: lib.items).map(\.label),
                       ["Under 100 g", "100 – 500 g", "500 g – 1 kg", "Over 1 kg", "No weight"])
        XCTAssertEqual(names(lib, ["weight": ["w3", "w4"]]), ["Jacket", "Umbrella"])
        XCTAssertEqual(names(lib, ["weight": [""]]), ["Goggles"])
    }

    /// "Travel section" — the field test's own example.
    func testATemplateFiltersByBeingOnItAndByItsSections() {
        let lib = library()
        let travel = lib.templates.first { $0.name == "Travel" }!
        let column = "list:\(travel.id)"
        let clothes = travel.sections.first { $0.name == "Clothes" }!
        XCTAssertEqual(lib.filterAnswers(column: column, among: lib.items).map(\.label),
                       ["On it", "Section: Clothes", "On it, no section", "Not on it"])
        XCTAssertEqual(names(lib, [column: [FILTER_SECTION + clothes.id]]), ["Jacket", "Socks"])
        XCTAssertEqual(names(lib, [column: [FILTER_ON]]), ["Charger", "Jacket", "Socks"])
        XCTAssertEqual(names(lib, [column: [FILTER_OFF]]), ["Goggles", "Umbrella"])
        XCTAssertEqual(names(lib, [column: [FILTER_SECTION + clothes.id], "ownedBy": ["robin"]]), ["Socks"])
    }

    func testThePerTemplateColumnsSayWhenAThingIsOnNoneOrSeveral() {
        let lib = library()
        XCTAssertEqual(lib.filterAnswers(column: "listQty", among: lib.items).map(\.label),
                       ["Blank", "On several templates", "On no template"])
        // Socks is on two templates, so its 3 is not an answer of the column.
        XCTAssertEqual(names(lib, ["listQty": [FILTER_SEVERAL]]), ["Socks"])
        XCTAssertEqual(names(lib, ["listQty": [FILTER_NO_TEMPLATE]]), ["Umbrella"])
        let sections = lib.filterAnswers(column: "listSection", among: lib.items).map(\.label)
        XCTAssertEqual(sections, ["Clothes (Travel)", "No section", "On several templates", "On no template"])
    }

    func testAnswersCountOnlyTheThingsInView() {
        let lib = library()
        let kims = lib.items.filter { lib.passes($0, ["ownedBy": ["kim"]]) }
        XCTAssertEqual(lib.filterAnswers(column: "charging", among: kims).map { "\($0.label) \($0.count)" }, ["Yes 1", "No 1"])
        XCTAssertEqual(lib.filterSummary(column: "ownedBy", kept: ["kim", "robin"]), "Kim, Robin")
    }
}
