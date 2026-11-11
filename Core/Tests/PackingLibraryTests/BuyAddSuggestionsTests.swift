import XCTest
import PackingCore
@testable import PackingLibrary

/// To buy's field offers his own things (0.114) — none already open on To buy — and a tap links the line.
final class BuyAddSuggestionsTests: XCTestCase {
    override func setUp() { PackingEnv.reset(); _ = setPhases(DEFAULT_PHASES) }
    override func tearDown() { PackingEnv.reset(); _ = setPhases(DEFAULT_PHASES) }

    func testOffersOwnThingsSkipsOpenOnesAndLinksTheLine() {
        var lib = Library()
        var old = newItem(name: "Sun cream old")
        old.retired = true
        lib.items.append(contentsOf: [newItem(name: "Sun cream"), old, newItem(name: "Suncap"), newItem(name: "Socks")])
        XCTAssertEqual(lib.buyAddSuggestions(typed: "SUN").map(\.name), ["Sun cream", "Sun cream old", "Suncap"])
        XCTAssertTrue(lib.buyAddSuggestions(typed: " ").isEmpty)

        guard let cream = lib.buyAddSuggestions(typed: "sun c").first else { return XCTFail("no suggestion") }
        let line = lib.addToBuyList(thing: cream)
        XCTAssertEqual(line?.itemId, cream.id)
        XCTAssertFalse(lib.buyAddSuggestions(typed: "sun").contains { $0.id == cream.id })
        _ = lib.addToBuyList(text: "suncap")
        XCTAssertEqual(lib.buyAddSuggestions(typed: "sun").map(\.name), ["Sun cream old"])
    }
}
