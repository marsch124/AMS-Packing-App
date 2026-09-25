import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// Renaming a list, and getting rid of one. A delete cannot be undone from inside
/// the app, so what it does and does NOT take is worth pinning down.
final class EditListsTests: XCTestCase {
    private func library() -> Library {
        var lib = Library()
        func list(_ name: String, _ names: [String]) -> PackList {
            var l = newList(name: name, group: "WET")
            l.items = names.map { newItem(name: $0) }
            return l
        }
        lib.saveTemplate(list("Mobility", ["Mat", "Strap", "Shared thing"]))
        lib.saveTemplate(list("Breath work", ["Nose clip", "Shared thing"]))
        return lib
    }
    private func id(_ lib: Library, _ name: String) -> String {
        lib.templates.first { $0.name == name }?.id ?? ""
    }

    func testARenameSticksAndRefusesANameHeAlreadyHas() {
        var lib = library()
        let mobility = id(lib, "Mobility")
        XCTAssertTrue(lib.renameTemplate(id: mobility, to: "Mobility & Breath"))
        XCTAssertEqual(lib.templates.first { $0.id == mobility }?.name, "Mobility & Breath")

        XCTAssertFalse(lib.renameTemplate(id: mobility, to: "Breath work"), "that name is taken")
        XCTAssertFalse(lib.renameTemplate(id: mobility, to: "   "), "a list needs a name")
        XCTAssertEqual(lib.templates.first { $0.id == mobility }?.name, "Mobility & Breath", "a refused rename changes nothing")
    }

    func testADeleteTakesTheListAndItsRowsButNeverTheThings() {
        var lib = library()
        let breath = id(lib, "Breath work")
        let thingsBefore = lib.items.count
        XCTAssertTrue(lib.deleteTemplate(id: breath))

        XCTAssertNil(lib.templates.first { $0.id == breath }, "the list is gone")
        XCTAssertTrue(lib.memberships.filter { $0.templateId == breath }.isEmpty, "its rows went with it")
        XCTAssertEqual(lib.items.count, thingsBefore, "not one THING was deleted")
        XCTAssertNotNil(lib.items.first { $0.name == "Nose clip" },
                        "a thing that was only on the deleted list still exists, ready for another list")
    }

    func testTheOtherListIsUntouchedByTheDelete() {
        var lib = library()
        let mobility = id(lib, "Mobility")
        let before = lib.resolvedTemplate(id: mobility)?.items.count
        lib.deleteTemplate(id: id(lib, "Breath work"))
        XCTAssertEqual(lib.resolvedTemplate(id: mobility)?.items.count, before)
    }

    func testItRefusesAListThatIsNotThere() {
        var lib = library()
        XCTAssertFalse(lib.deleteTemplate(id: "nope"))
        XCTAssertFalse(lib.renameTemplate(id: "nope", to: "Whatever"))
        XCTAssertEqual(lib.templates.count, 2)
    }
}
