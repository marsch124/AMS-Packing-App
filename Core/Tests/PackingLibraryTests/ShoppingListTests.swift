import XCTest
import PackingCore
@testable import PackingLibrary

/// The buy-list: what the library offers to buy, and what happens to an offer
/// once it is taken up.
final class ShoppingListTests: XCTestCase {
    override func setUp() {
        PackingEnv.reset(); _ = setPhases(DEFAULT_PHASES); _ = setItemConditions(DEFAULT_ITEM_CONDITIONS)
    }
    override func tearDown() {
        PackingEnv.reset(); _ = setPhases(DEFAULT_PHASES); _ = setItemConditions(DEFAULT_ITEM_CONDITIONS)
    }

    private func library() -> Library {
        var lib = Library()
        var list = newList(name: "Base", role: "base")
        list.items = [newItem(name: "Sun cream"), newItem(name: "Walking boots"),
                      newItem(name: "Head torch"), newItem(name: "Old map")]
        lib.saveTemplate(list)
        func change(_ name: String, _ body: (inout Item) -> Void) {
            guard let n = lib.items.firstIndex(where: { $0.name == name }) else { return XCTFail("no \(name)") }
            body(&lib.items[n])
        }
        change("Sun cream") { $0.consumable = true }
        change("Walking boots") { $0.condition = "retire" }       // "Needs replacing"
        change("Old map") { $0.consumable = true; $0.retired = true }
        return lib
    }

    func testTheReasonsAreWhatTheThingItselfSays() {
        let lib = library()
        let by = Dictionary(uniqueKeysWithValues: lib.buySuggestions(today: "2026-09-22").map { ($0.item.name, $0.reason) })
        XCTAssertEqual(by["Sun cream"], "Restock")
        XCTAssertEqual(by["Walking boots"], "Needs replacing")
        XCTAssertNil(by["Head torch"], "a thing with nothing wrong was offered")
        XCTAssertNil(by["Old map"], "a retired thing was offered")
    }

    func testTheWorstReasonComesFirst() {
        let names = library().buySuggestions(today: "2026-09-22").map { $0.item.name }
        XCTAssertEqual(names.first, "Walking boots", "needs replacing should lead")
    }

    func testTakingUpAnOfferPutsItOnTheListAndStopsTheOffer() {
        var lib = library()
        let boots = lib.buySuggestions(today: "2026-09-22").first { $0.item.name == "Walking boots" }
        XCTAssertNotNil(boots)
        XCTAssertNotNil(lib.addToBuyList(boots!))
        XCTAssertEqual(lib.buyList().map(\.text), ["Walking boots"])
        XCTAssertFalse(lib.buySuggestions(today: "2026-09-22").contains { $0.item.name == "Walking boots" },
                       "it was offered again although it is already on the list")
        // …and the to-do list is a different list.
        XCTAssertTrue(lib.sortedActions().isEmpty, "a buy-list line turned up among the to-dos")
    }

    func testABoughtLineStopsBeingOpenButTheOfferStaysAway() {
        var lib = library()
        let cream = lib.buySuggestions(today: "2026-09-22").first { $0.item.name == "Sun cream" }!
        let line = lib.addToBuyList(cream)!
        lib.setActionDone(true, id: line.id)
        XCTAssertEqual(lib.buyList().count, 1)
        XCTAssertTrue(lib.buyList()[0].done)
        // A bought consumable is worth buying again — the web app offers it once the
        // line is ticked, because the open-list check only counts OPEN lines.
        XCTAssertTrue(lib.buySuggestions(today: "2026-09-22").contains { $0.item.name == "Sun cream" })
    }

    func testALineHeTypesHimselfNeedsNoThing() {
        var lib = library()
        XCTAssertNotNil(lib.addToBuyList(text: "Gas canister"))
        XCTAssertNil(lib.addToBuyList(text: "   "), "an empty line was added")
        XCTAssertEqual(lib.buyList().map(\.text), ["Gas canister"])
        XCTAssertEqual(lib.buyList()[0].itemId, "")
    }
}
