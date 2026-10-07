import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// Search also finds notes (0.69): a thing's own Notes and the notes its templates keep
/// for it, with the line that matched.
final class NoteSearchTests: XCTestCase {
    private func library() -> Library {
        var lib = Library()
        var hiking = newList(name: "Hiking", group: "GA")
        hiking.items = [newItem(name: "Boots"), newItem(name: "Pump"), newItem(name: "Map")]
        lib.saveTemplate(hiking)
        var swim = newList(name: "Swim", group: "WET")
        swim.items = [newItem(name: "Towel"), newItem(name: "Pump")]
        lib.saveTemplate(swim)
        return lib
    }

    private func setRowNote(_ lib: inout Library, template: String, thing: String, _ note: String) {
        let t = lib.templates.first { $0.name == template }!.id
        let i = lib.items.first { $0.name == thing }!.id
        let n = lib.memberships.firstIndex { $0.templateId == t && $0.itemId == i }!
        lib.memberships[n].note = note
    }

    private func id(_ lib: Library, _ name: String) -> String { lib.items.first { $0.name == name }!.id }

    func testAThingIsFoundByItsOwnNoteWithTheLineThatMatched() {
        var lib = library()
        let n = lib.items.firstIndex { $0.name == "Pump" }!
        lib.items[n].note = "Bought 2024\nNeeds the BLUE adapter for the bike\nKeep dry"
        let hits = lib.noteHits("blue  adapter")
        XCTAssertEqual(hits[id(lib, "Pump")], NoteHit(template: nil, line: "Needs the BLUE adapter for the bike"),
                       "the line that matched, as he wrote it (case and spaces do not count)")
        XCTAssertEqual(hits.count, 1, "only the thing whose notes say it")
        XCTAssertEqual(lib.noteHits("   "), [:], "an empty search finds nothing")
    }

    func testATemplatesOwnNoteFindsTheThingAndNamesTheTemplate() {
        var lib = library()
        setRowNote(&lib, template: "Swim", thing: "Towel", "The big striped one")
        let hits = lib.noteHits("striped")
        XCTAssertEqual(hits[id(lib, "Towel")], NoteHit(template: "Swim", line: "The big striped one"))
    }

    func testItsOwnNoteComesFirstThenTheTemplatesInOrder() {
        var lib = library()
        setRowNote(&lib, template: "Swim", thing: "Pump", "Adapter for the pool float")
        setRowNote(&lib, template: "Hiking", thing: "Pump", "Adapter for the mattress")
        XCTAssertEqual(lib.noteHits("adapter")[id(lib, "Pump")]?.template, "Hiking", "the templates' order, as the thing's page lists them")
        let n = lib.items.firstIndex { $0.name == "Pump" }!
        lib.items[n].note = "Adapter in the lid"
        XCTAssertEqual(lib.noteHits("adapter")[id(lib, "Pump")], NoteHit(template: nil, line: "Adapter in the lid"))
    }

    func testANoteThatOnlyRepeatsTheThingsOwnIsNotTheTemplates() {
        var lib = library()
        let n = lib.items.firstIndex { $0.name == "Boots" }!
        lib.items[n].note = "Wax them first"
        setRowNote(&lib, template: "Hiking", thing: "Boots", "Wax them first")
        XCTAssertEqual(lib.noteHits("wax")[id(lib, "Boots")]?.template, nil)
    }

    func testALongLineIsCutSoTheWordsShow() {
        var lib = library()
        let n = lib.items.firstIndex { $0.name == "Map" }!
        let long = "This old paper map covers the whole northern valley including every hut and the long ridge walk, folded in the red case"
        lib.items[n].note = long
        let line = lib.noteHits("red case")[id(lib, "Map")]?.line ?? ""
        XCTAssertTrue(line.hasPrefix("\u{2026}"), "a long line is not cut: '\(line)'")
        XCTAssertTrue(line.hasSuffix("folded in the red case"), "'\(line)'")
        XCTAssertLessThan(line.count, long.count)
        // Words near the start: the line as it is.
        XCTAssertEqual(lib.noteHits("paper")[id(lib, "Map")]?.line, long)
    }
}
