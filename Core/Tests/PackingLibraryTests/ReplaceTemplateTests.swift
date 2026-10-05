import XCTest
import PackingCore
@testable import PackingLibrary

/// "Replace your Hiking instead" with a shared Hiking (the spec pass, 2026-10-05): it
/// takes the sender's things and keeps what is his. Invented data only.
final class ReplaceTemplateTests: XCTestCase {

    override func setUp() { PackingEnv.freeze() }
    override func tearDown() { PackingEnv.reset() }

    /// His Hiking: a cover, a group, a default bag, a section, his icon — and a
    /// headlamp with answers of its own on it (only in winter, two of them, a note,
    /// a kit, the Lights section, the duffel instead of the day pack).
    private func his() -> (Library, String) {
        var me = Library()
        let lights = TemplateSection(id: "his-lights", name: "Lights")
        var hiking = newList(name: "Hiking", emoji: "⛰", color: "#123456", sections: [lights], group: "GA",
                             defaultContainer: "Day pack")
        var lamp = newItem(name: "Headlamp")
        lamp.seasons = ["Winter"]; lamp.qty = "2"; lamp.note = "spare strap"; lamp.kit = "Night kit"
        lamp.section = lights.id; lamp.ovContainer = "Duffel bag"; lamp.ovPhase = "morning"
        hiking.items = [lamp, newItem(name: "Map"), newItem(name: "Rain jacket")]
        me.saveTemplate(hiking)
        _ = me.setTemplateIcon(id: hiking.id, key: "boot")
        return (me, hiking.id)
    }

    /// Their hiking: another cover, group and bag, "always packed", and the headlamp
    /// with none of his answers; a water filter and poles he does not have.
    private func theirs() throws -> SharedList {
        var them = Library()
        let lights = TemplateSection(name: "lights"), water = TemplateSection(name: "Water")
        var hiking = newList(name: "hiking", emoji: "🥾", color: "#abcdef", sections: [lights, water], group: "WET",
                             role: "base", defaultContainer: "Backpack")
        var lamp = newItem(name: "Headlamp"); lamp.note = "theirs"
        var filter = newItem(name: "Water filter"); filter.section = water.id
        var poles = newItem(name: "Trekking poles"); poles.section = lights.id
        hiking.items = [lamp, newItem(name: "Map"), filter, poles]
        them.saveTemplate(hiking)
        return try decodeListShare(try encodeListShare(them.resolvedTemplate(id: hiking.id)))
    }

    func testReplaceTakesTheirThingsAndKeepsWhatIsHis() throws {
        var (me, id) = his()
        let shared = try theirs()
        let before = me.templates.first { $0.id == id }!
        let lamp = me.items.first { $0.name == "Headlamp" }!.id
        let hisPlace = me.memberships.first { $0.itemId == lamp }!

        XCTAssertNotNil(me.replaceTemplate(id: id, with: shared))
        let after = me.templates.first { $0.id == id }!
        // The template is his, as he set it up.
        XCTAssertEqual([after.name, after.emoji, after.color, after.group, after.role, after.defaultContainer],
                       [before.name, before.emoji, before.color, before.group, before.role, before.defaultContainer])
        XCTAssertEqual(me.chosenIcon(templateId: id), "boot", "the icon he picked was lost")
        // Their things, in their order; his Rain jacket leaves the template, not his things.
        XCTAssertEqual(me.resolvedTemplate(id: id)?.items.map(\.name), ["Headlamp", "Map", "Water filter", "Trekking poles"])
        XCTAssertNotNil(me.items.first { $0.name == "Rain jacket" })
        // The headlamp keeps every answer he gave it on this template.
        var place = me.memberships.first { $0.itemId == lamp && $0.templateId == id }!
        XCTAssertEqual(place.order, 0)
        place.order = hisPlace.order
        XCTAssertEqual(place, hisPlace, "his answers on the headlamp were overwritten")
        // A new thing in a section he has by name goes into HIS section; one he has not is added.
        let poles = me.memberships.first { $0.itemId == me.items.first { $0.name == "Trekking poles" }!.id }!
        XCTAssertEqual(poles.section, "his-lights")
        XCTAssertEqual(after.sections.map(\.name), ["Lights", "Water"])
        let filter = me.memberships.first { $0.itemId == me.items.first { $0.name == "Water filter" }!.id }!
        XCTAssertEqual(after.sections.first { $0.id == filter.section }?.name, "Water")
    }

    func testTheQuestionSaysWhatReplaceDoes() throws {
        let (me, id) = his()
        let shared = try theirs()
        XCTAssertEqual(me.replacePreview(id: id, with: shared)?.comeIn, 2)
        XCTAssertEqual(me.replacePreview(id: id, with: shared)?.leave, 1)
        XCTAssertEqual(me.replaceWords(id: id, with: shared),
                       "2 things come in and 1 thing leaves it. Your icon, sections, bags and answers on the things you had stay yours.")
        // The same things again: nothing comes or goes.
        let same = try decodeListShare(try encodeListShare(me.resolvedTemplate(id: id)))
        XCTAssertEqual(me.replaceWords(id: id, with: same),
                       "It keeps the same things, in their order. Your icon, sections, bags and answers on the things you had stay yours.")
        XCTAssertNil(me.replacePreview(id: "no-such", with: shared))
    }
}
