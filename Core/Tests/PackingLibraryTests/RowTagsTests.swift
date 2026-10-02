import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// "Only on some trips" (his ask, 2 Oct 2026): a template row's Season, Context,
/// Transport and Food tags decide which trips it comes along on — per template.
final class RowTagsTests: XCTestCase {
    override func setUp() { PackingEnv.freeze() }
    override func tearDown() { PackingEnv.reset() }

    func testATaggedRowComesOnlyOnTripsThatMatch() {
        var lib = Library()
        var beach = newList(name: "Beach", group: "GA")
        beach.items = [newItem(name: "Sunscreen"), newItem(name: "Beach towel")]
        lib.saveTemplate(beach)
        var swim = newList(name: "Swim", group: "WET")
        swim.items = [newItem(name: "Goggles"), newItem(name: "Wetsuit")]
        lib.saveTemplate(swim)
        let beachId = lib.templates.first { $0.name == "Beach" }!.id, swimId = lib.templates.first { $0.name == "Swim" }!.id
        func mem(_ thing: String, _ template: String) -> String {
            let item = lib.items.first { $0.name == thing }!.id
            return lib.memberships.first { $0.itemId == item && $0.templateId == template }!.id
        }
        XCTAssertTrue(lib.updateMembership(memId: mem("Beach towel", beachId)) { $0.seasons = ["Summer"]; $0.transports = ["Plane"] })
        XCTAssertTrue(lib.updateMembership(memId: mem("Wetsuit", swimId)) { $0.contexts = ["Outdoor"] })

        func names(_ season: String, _ transport: String, _ contexts: [String]) -> [String] {
            var t = newEvent(name: "t")
            t.activities = [beachId, swimId]; t.season = season; t.transport = transport; t.contexts = contexts
            return buildTotalEntries(t, lib.resolvedTemplates()).map(\.name).sorted()
        }
        XCTAssertEqual(names("Summer", "Plane", ["Outdoor"]), ["Beach towel", "Goggles", "Sunscreen", "Wetsuit"])
        XCTAssertFalse(names("Winter", "Plane", ["Outdoor"]).contains("Beach towel"), "a Summer-only row came on a winter trip")
        XCTAssertFalse(names("Summer", "Car", ["Outdoor"]).contains("Beach towel"), "a Plane-only row came on a car trip")
        XCTAssertFalse(names("Summer", "Plane", ["Indoor"]).contains("Wetsuit"), "an Outdoor-only row came to the indoor pool")
        XCTAssertTrue(names("Summer", "Plane", ["Indoor", "Outdoor"]).contains("Wetsuit"), "Indoor + Outdoor must take both")
        XCTAssertTrue(names("Winter", "Car", []).contains("Sunscreen"), "an untagged row must always come")
        // Stored and read back, the tags stay.
        let back = Library(records: lib.records())
        XCTAssertEqual(back.memberships.first { $0.id == mem("Beach towel", beachId) }?.seasons, ["Summer"])
    }
}
