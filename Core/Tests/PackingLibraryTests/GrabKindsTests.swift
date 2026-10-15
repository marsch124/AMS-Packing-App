import XCTest
import PackingCore
@testable import PackingLibrary

/// An open grab list grouped by Kind of thing (0.84) — his words, 15 Oct 2026: "a bit more
/// visual with some grouping … only for visuals but important to me".
final class GrabKindsTests: XCTestCase {
    override func setUp() { PackingEnv.reset() }
    override func tearDown() { PackingEnv.reset() }

    /// Things of his with a kind each; "Spare tube" is a thing with no kind.
    private func library(_ kinds: [String: String]) -> Library {
        var lib = Library()
        for (name, kind) in kinds.sorted(by: { $0.key < $1.key }) {
            guard let t = lib.addThing(name: name), let n = lib.items.firstIndex(where: { $0.id == t.id }) else { continue }
            lib.items[n].category = kind
        }
        return lib
    }

    private func shown(_ lib: Library, _ names: [String]) -> [String] {
        lib.grabGroups(names).map { g in "\(g.kind): " + g.rows.map { names[$0] }.joined(separator: ", ") }
    }

    func testThingsGoUnderTheirKindInHisOrderAndTheRestUnderOtherLast() {
        let lib = library(["Helmet": "Sport gear", "Cycling gloves": "Clothing", "iPhone": "Electronics",
                           "Bike computer": "Electronics", "Sunglasses": "Clothing"])
        let list = ["Helmet", "Sunglasses", "Cycling gloves", "Drink bottle", "iPhone", "Bike computer", "GPS course"]
        // The app's twelve: Clothing, …, Sport gear, …, Electronics, … — the list's order within each.
        XCTAssertEqual(shown(lib, list), ["Clothing: Sunglasses, Cycling gloves", "Sport gear: Helmet",
                                          "Electronics: iPhone, Bike computer", "Other: Drink bottle, GPS course"])
        // Every place of the list is under exactly one heading.
        XCTAssertEqual(lib.grabGroups(list).flatMap(\.rows).sorted(), Array(list.indices))
    }

    func testHisOwnOrderOfKindsDecidesAndHisSpellingIsTheHeading() {
        var lib = library(["Helmet": "sport gear", "iPhone": "Electronics", "Gloves": "Clothing"])
        lib.setCategories(["Electronics", "Sport gear", "Clothing", "Comfort & misc"])
        XCTAssertEqual(shown(lib, ["Gloves", "Helmet", "iPhone"]),
                       ["Electronics: iPhone", "Sport gear: Helmet", "Clothing: Gloves"])
    }

    func testAListOfOneKindStaysFlat() {
        let lib = library(["iPhone": "Electronics", "Bike computer": "Electronics"])
        XCTAssertEqual(lib.grabGroups(["iPhone", "Bike computer"]), [], "one kind: no headings")
        // "Other" sorts nothing, so one kind and some unknown names stay flat too.
        XCTAssertEqual(lib.grabGroups(["iPhone", "Drink bottle", "Bike computer"]), [])
        XCTAssertEqual(lib.grabGroups(["Drink bottle", "Towel"]), [], "nothing known: no headings")
        XCTAssertEqual(lib.grabGroups([]), [])
    }

    func testNamesMatchHisThingsLooselyAndAThingWithNoKindIsOther() {
        var lib = library(["Helmet": "Sport gear", "iPhone": "Electronics", "Spare tube": "Clothing"])
        if let n = lib.items.firstIndex(where: { $0.name == "Spare tube" }) { lib.items[n].category = "  " }
        XCTAssertEqual(lib.grabKind(of: "  helmet "), "Sport gear", "by the plain name, as everywhere")
        XCTAssertEqual(lib.grabKind(of: "IPHONE"), "Electronics")
        XCTAssertEqual(lib.grabKind(of: "Spare tube"), "", "a thing with no kind")
        XCTAssertEqual(lib.grabKind(of: "Drink bottle"), "", "not one of his things")
        XCTAssertEqual(shown(lib, ["Spare tube", "iPhone", "helmet"]), ["Sport gear: helmet", "Electronics: iPhone", "Other: Spare tube"])
    }

    func testAKindNoLongerOnHisListComesAfterHisAndBeforeOther() {
        var lib = library(["Helmet": "Sport gear", "Bar": "Snacks", "iPhone": "Electronics", "Map": "Paper"])
        lib.setCategories(["Electronics", "Sport gear"])
        XCTAssertEqual(shown(lib, ["Map", "Bar", "Helmet", "Drink", "iPhone"]),
                       ["Electronics: iPhone", "Sport gear: Helmet", "Paper: Map", "Snacks: Bar", "Other: Drink"])
    }

    func testHisOwnKindCalledOtherIsTheOtherHeadingLast() {
        var lib = library(["Helmet": "Sport gear", "iPhone": "Electronics", "Tools": "other"])
        lib.setCategories(["Other", "Electronics", "Sport gear"])
        XCTAssertEqual(shown(lib, ["Tools", "iPhone", "Drink", "Helmet"]),
                       ["Electronics: iPhone", "Sport gear: Helmet", "Other: Tools, Drink"])
        // …and it does not count as a kind: one real kind plus "Other" stays flat.
        XCTAssertEqual(lib.grabGroups(["Tools", "iPhone"]), [])
    }
}
