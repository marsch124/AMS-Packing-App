import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// A template's sections renamed, moved and removed from a thing's page (0.68, his ask:
/// "Rename, Change and Delete Sections from this here as well"), held until Save and then
/// written through Arrange's own functions.
final class SectionEditsTests: XCTestCase {
    override func setUp() { PackingEnv.freeze() }
    override func tearDown() { PackingEnv.reset() }

    /// Hiking: Lights (Headlamp, Spare batteries), Clothes (Boots, Rain jacket), Map under none.
    private func library() -> Library {
        var lib = Library()
        var hiking = newList(name: "Hiking", group: "GA")
        hiking.items = ["Boots", "Headlamp", "Map", "Rain jacket", "Spare batteries"].map { newItem(name: $0) }
        lib.saveTemplate(hiking)
        let lights = lib.addSection(templateId: hiking.id, name: "Lights")!
        let clothes = lib.addSection(templateId: hiking.id, name: "Clothes")!
        for (thing, section) in [("Boots", clothes), ("Headlamp", lights), ("Rain jacket", clothes), ("Spare batteries", lights)] {
            let row = lib.resolvedTemplate(id: hiking.id)!.items.first { $0.name == thing }!.memId!
            lib.updateMembership(memId: row) { $0.section = section.id }
        }
        return lib
    }
    private func tpl(_ lib: Library) -> String { lib.templates.first { $0.name == "Hiking" }!.id }
    private func section(_ lib: Library, _ name: String) -> String {
        lib.templates.first { $0.name == "Hiking" }!.sections.first { $0.name == name }!.id
    }
    private func page(_ lib: Library) -> [String] {
        let list = lib.resolvedTemplate(id: tpl(lib))!
        return ThingGrouping.section.groups(list.items, sections: list.sections)
            .map { "\($0.title): \($0.items.map(\.name).joined(separator: ", "))" }
    }

    func testARenamedSectionKeepsItsThings() {
        var lib = library()
        let lights = section(lib, "Lights")
        XCTAssertTrue(lib.applySectionEdits(templateId: tpl(lib), SectionEdits(names: [lights: "Lamps"])))
        XCTAssertEqual(page(lib), ["Lamps: Headlamp, Spare batteries", "Clothes: Boots, Rain jacket", "Everything else: Map"])
        XCTAssertEqual(section(lib, "Lamps"), lights, "the same section, its name changed")
    }

    func testTheOrderIsTheTemplatesAndANewTripReadsIt() {
        var lib = library()
        let lights = section(lib, "Lights"), clothes = section(lib, "Clothes")
        XCTAssertTrue(lib.applySectionEdits(templateId: tpl(lib), SectionEdits(order: [clothes, lights])))
        XCTAssertEqual(lib.templates.first { $0.name == "Hiking" }!.sections.map(\.name), ["Clothes", "Lights"])
        XCTAssertEqual(page(lib), ["Clothes: Boots, Rain jacket", "Lights: Headlamp, Spare batteries", "Everything else: Map"])
        // A trip lists its headings by the first line met — the rows were renumbered.
        var trip = newEvent(name: "Hills", startDate: "2026-11-01", endDate: "2026-11-02")
        trip.activities = [tpl(lib)]
        let lines = buildTotalEntries(trip, lib.resolvedTemplates())
        var seen: [String] = []
        for l in lines where !l.section.isEmpty && !seen.contains(l.section) { seen.append(l.section) }
        XCTAssertEqual(seen, ["Clothes", "Lights"], "a new trip does not read the new order")
    }

    func testARemovedSectionLeavesItsThingsOnTheTemplateWithNone() {
        var lib = library()
        let lights = section(lib, "Lights")
        let things = lib.memberships.filter { $0.templateId == tpl(lib) }.count
        XCTAssertTrue(lib.applySectionEdits(templateId: tpl(lib), SectionEdits(removed: [lights])))
        XCTAssertEqual(lib.templates.first { $0.name == "Hiking" }!.sections.map(\.name), ["Clothes"])
        XCTAssertEqual(lib.memberships.filter { $0.templateId == tpl(lib) }.count, things, "a thing left the template")
        XCTAssertEqual(page(lib), ["Clothes: Boots, Rain jacket", "Everything else: Headlamp, Spare batteries, Map"])
    }

    func testAllThreeAtOnceAndASwapOfNames() {
        var lib = library()
        let lights = section(lib, "Lights"), clothes = section(lib, "Clothes")
        _ = lib.addSection(templateId: tpl(lib), name: "Food")
        let food = section(lib, "Food")
        // Lights ↔ Clothes swap names, Food goes, and the order turns round.
        let edits = SectionEdits(names: [lights: "Clothes", clothes: "Lights"], order: [food, clothes, lights], removed: [food])
        XCTAssertTrue(lib.applySectionEdits(templateId: tpl(lib), edits))
        let now = lib.templates.first { $0.name == "Hiking" }!.sections
        XCTAssertEqual(now.map(\.id), [clothes, lights])
        XCTAssertEqual(now.map(\.name), ["Lights", "Clothes"], "the swap did not give each its name")
        XCTAssertEqual(page(lib), ["Lights: Boots, Rain jacket", "Clothes: Headlamp, Spare batteries", "Everything else: Map"])
    }

    func testNothingToDoWritesNothing() {
        var lib = library()
        let before = lib
        let lights = section(lib, "Lights"), clothes = section(lib, "Clothes")
        XCTAssertFalse(lib.applySectionEdits(templateId: tpl(lib), SectionEdits()))
        XCTAssertFalse(lib.applySectionEdits(templateId: tpl(lib), SectionEdits(names: [lights: "Lights"], order: [lights, clothes])),
                       "the same names and order are no change")
        XCTAssertFalse(lib.applySectionEdits(templateId: "nope", SectionEdits(removed: [lights])))
        XCTAssertEqual(lib, before)
    }

    func testThePageShowsTheEditsAndRefusesASecondName() {
        let lib = library()
        let lights = section(lib, "Lights"), clothes = section(lib, "Clothes")
        let edits = SectionEdits(names: [lights: "Lamps"], order: [clothes, lights], removed: [clothes])
        XCTAssertEqual(lib.sectionsAsEdited(templateId: tpl(lib), edits).map(\.name), ["Clothes", "Lamps"],
                       "the removed one is still shown (struck out), in the new order")
        XCTAssertTrue(lib.sectionNameTaken(templateId: tpl(lib), name: " lamps", except: clothes, SectionEdits(names: [lights: "Lamps"])))
        XCTAssertFalse(lib.sectionNameTaken(templateId: tpl(lib), name: "Clothes", except: lights, SectionEdits(removed: [clothes])),
                       "a removed section's name is free")
        XCTAssertFalse(lib.sectionNameTaken(templateId: tpl(lib), name: "Lights", except: lights, SectionEdits()), "its own name")
    }
}
