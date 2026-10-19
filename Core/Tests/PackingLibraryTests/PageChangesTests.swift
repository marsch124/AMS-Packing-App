import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// Cancel everywhere (0.92): a page that changes the library at once works on a copy while it is
/// open, and its Save hands over only what the page changed (`Library.applyingPage`). His words,
/// 19 Oct 2026: "I open an item and change some property. How do I cancel that?"
final class PageChangesTests: XCTestCase {
    override func setUp() { PackingEnv.freeze(at: "2026-10-19T12:00:00.000Z") }
    override func tearDown() {
        PackingEnv.reset(); _ = setPhases(DEFAULT_PHASES); _ = setItemConditions(DEFAULT_ITEM_CONDITIONS)
    }

    /// A template "Hiking" with a Torch and a Map, and a thing on no template, a Kettle.
    private func library() -> Library {
        var lib = Library()
        lib.setNames("places", ["Garage", "Loft"])
        lib.saveTemplate(newList(name: "Hiking"))
        let hiking = lib.templates.first { $0.name == "Hiking" }!.id
        for name in ["Torch", "Map"] { _ = lib.addToTemplate(templateId: hiking, name: name) }
        _ = lib.addThing(name: "Kettle")
        return lib
    }

    private func template(_ lib: Library, _ name: String) -> PackList? {
        lib.templates.first { $0.name == name }
    }

    func testNothingChangedOnThePageChangesNothing() {
        let live = library()
        XCTAssertEqual(live.applyingPage(from: live, to: live), live)
    }

    /// Renamed, a thing added and one taken off, a place added — all on the copy. Meanwhile the
    /// other device added a thing and a place of its own: Save keeps both sides.
    func testSaveHandsOverWhatThePageChangedAndKeepsWhatChangedElsewhere() {
        let opened = library()
        let hiking = template(opened, "Hiking")!.id
        var page = opened
        XCTAssertTrue(page.renameTemplate(id: hiking, to: "Hill walk"))
        _ = page.addToTemplate(templateId: hiking, name: "Compass")
        let map = page.memberships.first { m in page.items.first { $0.id == m.itemId }?.name == "Map" }!.id
        XCTAssertNotNil(page.removeFromTemplate(templateId: hiking, memId: map))
        _ = page.addChoice("places", "Shed")

        var live = opened
        _ = live.addThing(name: "Tent")                         // the other device, meanwhile
        _ = live.addChoice("places", "Cellar")

        let saved = live.applyingPage(from: opened, to: page)
        XCTAssertEqual(template(saved, "Hill walk")?.id, hiking, "the rename was not handed over")
        XCTAssertNil(template(saved, "Hiking"))
        let rows = saved.resolvedTemplate(id: hiking)!.items.map(\.name).sorted()
        XCTAssertEqual(rows, ["Compass", "Torch"], "the template's rows are not the page's")
        XCTAssertTrue(saved.items.contains { $0.name == "Tent" }, "Save undid the other device's thing")
        XCTAssertTrue(saved.items.contains { $0.name == "Kettle" })
        let places = saved.storagePlaces()
        XCTAssertTrue(places.contains("Shed"), "the page's place was not handed over: \(places)")
        XCTAssertTrue(places.contains("Cellar"), "Save undid the other device's place: \(places)")
    }

    /// Cancel is the copy thrown away: the real library never saw the page's changes.
    func testCancelLeavesTheLibraryAsItWas() {
        let opened = library()
        let hiking = template(opened, "Hiking")!.id
        var page = opened
        XCTAssertTrue(page.renameTemplate(id: hiking, to: "Hill walk"))
        XCTAssertNotEqual(page, opened)
        // Cancel hands nothing over: the library is the one the page opened on.
        XCTAssertEqual(opened.applyingPage(from: page, to: page), opened)
        XCTAssertEqual(template(opened, "Hiking")?.id, hiking)
    }

    /// A record the page deleted goes, and only that one.
    func testADeleteOnThePageDeletesOnlyThat() {
        let opened = library()
        var page = opened
        let kettle = page.items.first { $0.name == "Kettle" }!.id
        XCTAssertTrue(page.deleteThing(id: kettle))
        var live = opened
        _ = live.addThing(name: "Tent")
        let saved = live.applyingPage(from: opened, to: page)
        XCTAssertFalse(saved.items.contains { $0.id == kettle }, "the page's delete was lost")
        XCTAssertEqual(saved.items.count, opened.items.count, "one gone, one come: \(saved.items.map(\.name))")
    }
}
