import XCTest
import PackingCore
@testable import PackingLibrary

/// The template's "Add" field offers his own things not yet on it, and puts that very thing on.
final class TemplateAddSuggestionsTests: XCTestCase {
    override func setUp() { PackingEnv.reset(); _ = setPhases(DEFAULT_PHASES) }
    override func tearDown() { PackingEnv.reset(); _ = setPhases(DEFAULT_PHASES) }

    private func library() -> (Library, String) {
        var lib = Library()
        var hiking = newList(name: "Hiking", group: "GA")
        hiking.items = [newItem(name: "Chalk")]
        lib.saveTemplate(hiking)
        let names = ["Charger cable", "Camera charger", "Charm", "Chart", "Socks", "Éclair"]
        lib.items.append(contentsOf: names.map { newItem(name: $0) })
        return (lib, lib.templates.first { $0.name == "Hiking" }!.id)
    }

    func testMatchesOrderAndLimit() {
        let (lib, id) = library()
        let got = lib.templateAddSuggestions(templateId: id, typed: " char ").map(\.name)
        XCTAssertEqual(got, ["Charger cable", "Charm", "Chart", "Camera charger"])
        XCTAssertEqual(lib.templateAddSuggestions(templateId: id, typed: "char", limit: 2).count, 2)
        XCTAssertEqual(lib.templateAddSuggestions(templateId: id, typed: "ECLA").map(\.name), ["Éclair"])
    }

    func testAlreadyOnTemplateLeftOutAndBlankIsEmpty() {
        let (lib, id) = library()
        XCTAssertFalse(lib.templateAddSuggestions(templateId: id, typed: "cha").map(\.name).contains("Chalk"))
        XCTAssertTrue(lib.templateAddSuggestions(templateId: id, typed: "  ").isEmpty)
    }

    func testPuttingOneOnMakesItOnTheTemplate() {
        var (lib, id) = library()
        guard let charm = lib.templateAddSuggestions(templateId: id, typed: "charm").first else { return XCTFail("no suggestion") }
        XCTAssertFalse(lib.isOnTemplate(templateId: id, name: "Charm"))
        XCTAssertEqual(lib.putOnTemplate(templateId: id, itemIds: [charm.id]), 1)
        XCTAssertTrue(lib.isOnTemplate(templateId: id, name: "Charm"))
        XCTAssertFalse(lib.templateAddSuggestions(templateId: id, typed: "charm").contains { $0.id == charm.id })
    }
}
