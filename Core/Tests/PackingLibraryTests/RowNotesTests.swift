import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// A thing's page lists the notes its templates keep for it (spec 05, item 18): a
/// web-app library keeps its notes on the rows, and the page's Notes looked empty.
final class RowNotesTests: XCTestCase {
    private func library() -> Library {
        var lib = Library()
        var hiking = newList(name: "Hiking", group: "GA")
        hiking.items = [newItem(name: "Boots"), newItem(name: "Map")]
        lib.saveTemplate(hiking)
        var swim = newList(name: "Swim", group: "WET")
        swim.items = [newItem(name: "Towel")]
        lib.saveTemplate(swim)
        return lib
    }

    private func setRowNote(_ lib: inout Library, template: String, thing: String, _ note: String) {
        let t = lib.templates.first { $0.name == template }!.id
        let i = lib.items.first { $0.name == thing }!.id
        let n = lib.memberships.firstIndex { $0.templateId == t && $0.itemId == i }!
        lib.memberships[n].note = note
    }

    func testATemplatesOwnNoteForAThingIsListed() {
        var lib = library()
        setRowNote(&lib, template: "Hiking", thing: "Boots", "  Wax them first ")
        let boots = lib.items.first { $0.name == "Boots" }!.id
        XCTAssertEqual(lib.rowNotes(itemId: boots), [RowNote(template: "Hiking", note: "Wax them first")])
        let map = lib.items.first { $0.name == "Map" }!.id
        XCTAssertEqual(lib.rowNotes(itemId: map), [], "a row with no note of its own was listed")
    }

    func testANoteTheThingAlreadySaysIsNotRepeated() {
        var lib = library()
        let n = lib.items.firstIndex { $0.name == "Boots" }!
        lib.items[n].note = "Wax them first"
        setRowNote(&lib, template: "Hiking", thing: "Boots", "Wax them first")
        XCTAssertEqual(lib.rowNotes(itemId: lib.items[n].id), [], "the thing's own note was listed again")
    }

    func testEveryTemplateIsListedInItsOrderAndOneNoteOnce() {
        var lib = library()
        lib.putOnTemplate(templateId: lib.templates.first { $0.name == "Swim" }!.id,
                          itemIds: [lib.items.first { $0.name == "Boots" }!.id])
        setRowNote(&lib, template: "Swim", thing: "Boots", "For the walk down")
        setRowNote(&lib, template: "Hiking", thing: "Boots", "Wax them first")
        let boots = lib.items.first { $0.name == "Boots" }!.id
        XCTAssertEqual(lib.rowNotes(itemId: boots).map(\.template), ["Hiking", "Swim"])
        // The thing twice on Hiking, both places with the same note: said once.
        let hiking = lib.templates.first { $0.name == "Hiking" }!.id
        var twin = lib.memberships.first { $0.templateId == hiking && $0.itemId == boots }!
        twin.id = "twin"
        lib.memberships.append(twin)
        XCTAssertEqual(lib.rowNotes(itemId: boots).map(\.template), ["Hiking", "Swim"], "one note on one template was listed twice")
        XCTAssertEqual(lib.rowNotes(itemId: "no-such-thing"), [])
    }
}
