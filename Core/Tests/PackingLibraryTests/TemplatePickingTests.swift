import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// His tests H.9 and H.3 (2026-09-28): things he already owns are picked onto a
/// template (never twice), and a set of things groups the ways the trip sorts.
final class TemplatePickingTests: XCTestCase {
    private func library() -> Library {
        var lib = Library()
        var swim = newList(name: "Swim", group: "WET")
        swim.items = [newItem(name: "Goggles")]
        lib.saveTemplate(swim)
        var run = newList(name: "Run", group: "WET")
        run.items = [newItem(name: "Shoes"), newItem(name: "Cap")]
        lib.saveTemplate(run)
        return lib
    }
    private func id(_ lib: Library, template name: String) -> String { lib.templates.first { $0.name == name }?.id ?? "" }
    private func id(_ lib: Library, thing name: String) -> String { lib.items.first { $0.name == name }?.id ?? "" }

    func testThingsHeOwnsArePutOnATemplateOnceEach() {
        var lib = library()
        let swim = id(lib, template: "Swim")
        let thingsBefore = lib.items.count
        let cap = id(lib, thing: "Cap"), shoes = id(lib, thing: "Shoes"), goggles = id(lib, thing: "Goggles")

        XCTAssertEqual(lib.putOnTemplate(templateId: swim, itemIds: [cap, shoes, cap, goggles, "nope"]), 2,
                       "Cap and Shoes go on; Cap once, Goggles is already there, an unknown id is skipped")
        let names = lib.resolvedTemplate(id: swim)?.items.map(\.name).sorted()
        XCTAssertEqual(names, ["Cap", "Goggles", "Shoes"])
        XCTAssertEqual(lib.items.count, thingsBefore, "no new THING was made — the same things, one more place each")
        XCTAssertEqual(lib.thingIds(onTemplate: swim), [cap, shoes, goggles])
        XCTAssertEqual(lib.resolvedTemplate(id: id(lib, template: "Run"))?.items.count, 2, "Run keeps its own two")
        XCTAssertEqual(lib.putOnTemplate(templateId: "nope", itemIds: [cap]), 0)
    }

    func testThingsGroupTheWaysTheTripSorts() {
        var a = newItem(name: "bottle"); a.storage = "Kitchen"; a.category = "Food & drink"; a.container = "Day pack"
        var b = newItem(name: "Apple"); b.storage = "kitchen"; b.category = ""; b.container = "Day pack"
        var c = newItem(name: "Cap"); c.storage = ""; c.category = "Clothing"; c.container = "Duffel bag"
        let items = [a, b, c]

        let places = ThingGrouping.fromWhere.groups(items)
        XCTAssertEqual(places.map(\.title), ["Kitchen", "No place set"], "one Kitchen however it is spelt; not said last")
        XCTAssertEqual(places[0].items.map(\.name), ["Apple", "bottle"], "A–Z inside a group")

        XCTAssertEqual(ThingGrouping.kind.groups(items).map(\.title), ["Clothing", "Food & drink", "No kind set"])
        XCTAssertEqual(ThingGrouping.into.groups(items).map(\.title).sorted(), ["Day pack", "Duffel bag"])
        XCTAssertEqual(ThingGrouping.name.groups(items).first?.items.map(\.name), ["Apple", "bottle", "Cap"])
        XCTAssertTrue(ThingGrouping.name.groups([]).isEmpty)
        XCTAssertEqual(ThingGrouping.allCases.map(\.label), ["Section", "When", "Into", "From where", "Kind", "A–Z"])
    }
}
