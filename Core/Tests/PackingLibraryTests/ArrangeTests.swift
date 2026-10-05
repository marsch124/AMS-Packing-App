import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// Arranging a template (his layout "C", 5 Oct 2026): a heading renamed, moved with
/// its rows, or removed with its rows kept; a row moved under its own heading or
/// another. Saved like any template edit, and a new trip reads the new order.
final class ArrangeTests: XCTestCase {
    override func setUp() { PackingEnv.freeze() }
    override func tearDown() { PackingEnv.reset() }

    /// A Hiking template with two headings whose rows were put on in a jumble (as a
    /// template built over months is): Lights (Headlamp, Spare batteries), Clothes
    /// (Boots, Rain jacket), and a Map under no heading. Stored order: Boots,
    /// Headlamp, Map, Rain jacket, Spare batteries.
    private func library() -> Library {
        var lib = Library()
        var hiking = newList(name: "Hiking", group: "GA")
        hiking.items = ["Boots", "Headlamp", "Map", "Rain jacket", "Spare batteries"].map { newItem(name: $0) }
        lib.saveTemplate(hiking)
        let lights = lib.addSection(templateId: hiking.id, name: "Lights")!
        let clothes = lib.addSection(templateId: hiking.id, name: "Clothes")!
        for (thing, section) in [("Boots", clothes), ("Headlamp", lights), ("Rain jacket", clothes), ("Spare batteries", lights)] {
            lib.updateMembership(memId: mem(lib, thing)) { $0.section = section.id }
        }
        return lib
    }
    private func tpl(_ lib: Library) -> String { lib.templates.first { $0.name == "Hiking" }!.id }
    private func section(_ lib: Library, _ name: String) -> String {
        lib.templates.first { $0.name == "Hiking" }!.sections.first { $0.name == name }!.id
    }
    private func mem(_ lib: Library, _ thing: String) -> String {
        lib.resolvedTemplate(id: tpl(lib))!.items.first { $0.name == thing }!.memId!
    }
    /// The page as it reads by Section: each heading's name and its things.
    private func page(_ lib: Library) -> [String] {
        let list = lib.resolvedTemplate(id: tpl(lib))!
        return ThingGrouping.section.groups(list.items, sections: list.sections)
            .map { "\($0.title): \($0.items.map(\.name).joined(separator: ", "))" }
    }
    /// The template's rows in stored order, and their numbers.
    private func stored(_ lib: Library) -> [String] { lib.resolvedTemplate(id: tpl(lib))!.items.map(\.name) }
    private func orders(_ lib: Library) -> [Double] {
        lib.memberships.filter { $0.templateId == tpl(lib) }.map(\.order).sorted()
    }

    func testAHeadingIsRenamedButNeverToANameItAlreadyHas() {
        var lib = library()
        let t = tpl(lib), clothes = section(lib, "Clothes")
        XCTAssertTrue(lib.sectionNameTaken(templateId: t, name: " lights "), "another heading's name, any case")
        XCTAssertFalse(lib.sectionNameTaken(templateId: t, name: "clothes", except: clothes), "its own name is not taken")
        XCTAssertFalse(lib.sectionNameTaken(templateId: t, name: "  "), "blank is never taken")

        let before = lib.templates.first { $0.id == t }!.updatedAt
        PackingEnv.freeze(at: "2026-10-05T12:00:00.000Z", idPrefix: "later-")
        XCTAssertTrue(lib.renameSection(templateId: t, sectionId: clothes, to: "  Clothing "))
        XCTAssertEqual(lib.templates.first { $0.id == t }!.sections.map(\.name), ["Lights", "Clothing"], "trimmed, in place")
        XCTAssertNotEqual(lib.templates.first { $0.id == t }!.updatedAt, before, "a rename is an edit of the template")
        XCTAssertEqual(page(lib), ["Lights: Headlamp, Spare batteries", "Clothing: Boots, Rain jacket", "Everything else: Map"],
                       "its things stay under it")

        XCTAssertFalse(lib.renameSection(templateId: t, sectionId: clothes, to: "LIGHTS"), "a name the template has")
        XCTAssertFalse(lib.renameSection(templateId: t, sectionId: clothes, to: "   "), "blank")
        XCTAssertFalse(lib.renameSection(templateId: t, sectionId: "no-such", to: "Gear"))
        XCTAssertFalse(lib.renameSection(templateId: "no-such", sectionId: clothes, to: "Gear"))
        XCTAssertTrue(lib.renameSection(templateId: t, sectionId: clothes, to: "CLOTHING"), "its own name in other letters")
        XCTAssertEqual(lib.templates.first { $0.id == t }!.sections.map(\.name), ["Lights", "CLOTHING"])
    }

    func testAHeadingMovesWithAllItsThings() {
        var lib = library()
        let t = tpl(lib), lights = section(lib, "Lights"), clothes = section(lib, "Clothes")
        XCTAssertTrue(lib.moveSection(templateId: t, sectionId: clothes, before: lights))
        XCTAssertEqual(page(lib), ["Clothes: Boots, Rain jacket", "Lights: Headlamp, Spare batteries", "Everything else: Map"])
        // The rows are renumbered in that order, whole numbers from 0 — which is what
        // a trip reads.
        XCTAssertEqual(stored(lib), ["Boots", "Rain jacket", "Headlamp", "Spare batteries", "Map"])
        XCTAssertEqual(orders(lib), [0, 1, 2, 3, 4])

        XCTAssertTrue(lib.moveSection(templateId: t, sectionId: clothes), "nil = after the last heading")
        XCTAssertEqual(page(lib), ["Lights: Headlamp, Spare batteries", "Clothes: Boots, Rain jacket", "Everything else: Map"])
        XCTAssertEqual(stored(lib), ["Headlamp", "Spare batteries", "Boots", "Rain jacket", "Map"])

        XCTAssertFalse(lib.moveSection(templateId: t, sectionId: "no-such", before: lights))
        XCTAssertFalse(lib.moveSection(templateId: t, sectionId: clothes, before: "no-such"))
        XCTAssertFalse(lib.moveSection(templateId: "no-such", sectionId: clothes))
        XCTAssertTrue(lib.moveSection(templateId: t, sectionId: lights, before: lights), "before itself: stays")
        XCTAssertEqual(stored(lib), ["Headlamp", "Spare batteries", "Boots", "Rain jacket", "Map"])
    }

    func testARemovedHeadingLeavesItsThingsOnTheTemplate() {
        var lib = library()
        let t = tpl(lib), lights = section(lib, "Lights")
        let things = lib.items
        XCTAssertTrue(lib.removeSection(templateId: t, sectionId: lights))
        XCTAssertEqual(lib.templates.first { $0.id == t }!.sections.map(\.name), ["Clothes"])
        // Nothing is lost: under no heading, together and in their order, first there
        // (not scattered among the Map by the jumbled numbers he never saw).
        XCTAssertEqual(page(lib), ["Clothes: Boots, Rain jacket", "Everything else: Headlamp, Spare batteries, Map"])
        XCTAssertEqual(stored(lib).count, 5)
        XCTAssertEqual(lib.items, things, "no thing is touched")
        XCTAssertEqual(lib.memberships.filter { $0.section == lights }.count, 0, "no row points at the gone heading")
        XCTAssertEqual(orders(lib), [0, 1, 2, 3, 4])

        XCTAssertFalse(lib.removeSection(templateId: t, sectionId: lights), "gone already")
        XCTAssertFalse(lib.removeSection(templateId: "no-such", sectionId: section(lib, "Clothes")))
    }

    func testAThingMovesUnderItsOwnHeadingOrAnother() {
        var lib = library()
        let t = tpl(lib), lights = section(lib, "Lights"), clothes = section(lib, "Clothes")
        let note = { (l: Library) in l.memberships.first { $0.id == self.mem(l, "Map") }!.note }
        lib.updateMembership(memId: mem(lib, "Map")) { $0.note = "the 1:50 000"; $0.container = "Day pack" }

        // Within its heading: before the row named.
        XCTAssertTrue(lib.moveRow(templateId: t, memId: mem(lib, "Spare batteries"), section: lights, before: mem(lib, "Headlamp")))
        XCTAssertEqual(page(lib), ["Lights: Spare batteries, Headlamp", "Clothes: Boots, Rain jacket", "Everything else: Map"])
        // Into another heading, between two of its things.
        XCTAssertTrue(lib.moveRow(templateId: t, memId: mem(lib, "Map"), section: clothes, before: mem(lib, "Rain jacket")))
        XCTAssertEqual(page(lib), ["Lights: Spare batteries, Headlamp", "Clothes: Boots, Map, Rain jacket"])
        XCTAssertEqual(note(lib), "the 1:50 000", "its own answers go with it")
        XCTAssertEqual(lib.resolvedTemplate(id: t)!.items.first { $0.name == "Map" }!.container, "Day pack")
        // To the end of a heading (no `before`, or a `before` under another heading).
        XCTAssertTrue(lib.moveRow(templateId: t, memId: mem(lib, "Boots"), section: lights))
        XCTAssertTrue(lib.moveRow(templateId: t, memId: mem(lib, "Headlamp"), section: clothes, before: mem(lib, "Boots")))
        XCTAssertEqual(page(lib), ["Lights: Spare batteries, Boots", "Clothes: Map, Rain jacket, Headlamp"])
        // Out from under every heading.
        XCTAssertTrue(lib.moveRow(templateId: t, memId: mem(lib, "Map"), section: ""))
        XCTAssertEqual(page(lib), ["Lights: Spare batteries, Boots", "Clothes: Rain jacket, Headlamp", "Everything else: Map"])
        XCTAssertEqual(lib.memberships.first { $0.id == mem(lib, "Map") }!.section, "")
        XCTAssertEqual(orders(lib), [0, 1, 2, 3, 4], "whole numbers from 0, however often he drags")

        XCTAssertFalse(lib.moveRow(templateId: t, memId: mem(lib, "Map"), section: "no-such"), "a heading it does not have")
        XCTAssertFalse(lib.moveRow(templateId: t, memId: "no-such", section: lights))
        XCTAssertFalse(lib.moveRow(templateId: "no-such", memId: mem(lib, "Map"), section: ""))
    }

    /// The page while he arranges is one list: every heading (even an empty one),
    /// its rows, then "Everything else" and the rows under no heading.
    func testThePageWhileArrangingIsOneListOfHeadingsAndRows() {
        var lib = library()
        let t = tpl(lib), lights = section(lib, "Lights"), clothes = section(lib, "Clothes")
        XCTAssertEqual(lib.arrangeLines(templateId: t), [
            .heading(lights), .row(mem(lib, "Headlamp")), .row(mem(lib, "Spare batteries")),
            .heading(clothes), .row(mem(lib, "Boots")), .row(mem(lib, "Rain jacket")),
            .rest, .row(mem(lib, "Map"))])
        // An emptied heading stays, so something can be dragged into it again.
        lib.moveRow(templateId: t, memId: mem(lib, "Boots"), section: "")
        lib.moveRow(templateId: t, memId: mem(lib, "Rain jacket"), section: "")
        XCTAssertEqual(lib.arrangeLines(templateId: t).filter { if case .row = $0 { return false }; return true },
                       [.heading(lights), .heading(clothes), .rest])
        XCTAssertEqual(lib.arrangeLines(templateId: "no-such"), [])
    }

    /// A drag on the page, read the way SwiftUI's list hands it over (`to` counted
    /// before the move). The page: 0 Lights · 1 Headlamp · 2 Spare batteries ·
    /// 3 Clothes · 4 Boots · 5 Rain jacket · 6 Everything else · 7 Map.
    func testADropMovesWhatWasDraggedToWhereItWasDropped() {
        func dropped(_ from: Int, _ to: Int) -> [String] {
            var lib = library()
            XCTAssertTrue(lib.dropLine(templateId: tpl(lib), from: from, to: to), "\(from) → \(to) did nothing")
            return page(lib)
        }
        XCTAssertEqual(dropped(7, 1), ["Lights: Map, Headlamp, Spare batteries", "Clothes: Boots, Rain jacket"],
                       "a thing dragged up under another heading")
        XCTAssertEqual(dropped(1, 3), ["Lights: Spare batteries, Headlamp", "Clothes: Boots, Rain jacket", "Everything else: Map"],
                       "a thing dragged down one place under its own heading")
        XCTAssertEqual(dropped(5, 3), ["Lights: Headlamp, Spare batteries, Rain jacket", "Clothes: Boots", "Everything else: Map"],
                       "a thing dropped just above the next heading ends the heading above")
        XCTAssertEqual(dropped(4, 0), ["Lights: Boots, Headlamp, Spare batteries", "Clothes: Rain jacket", "Everything else: Map"],
                       "above every heading = the top of the first")
        XCTAssertEqual(dropped(1, 8), ["Lights: Spare batteries", "Clothes: Boots, Rain jacket", "Everything else: Map, Headlamp"],
                       "dropped at the very end = under no heading")
        XCTAssertEqual(dropped(3, 0), ["Clothes: Boots, Rain jacket", "Lights: Headlamp, Spare batteries", "Everything else: Map"],
                       "a heading takes its things along")
        XCTAssertEqual(dropped(0, 8), ["Clothes: Boots, Rain jacket", "Lights: Headlamp, Spare batteries", "Everything else: Map"],
                       "a heading dropped at the end is the last heading")
        XCTAssertEqual(dropped(0, 5), ["Clothes: Boots, Rain jacket", "Lights: Headlamp, Spare batteries", "Everything else: Map"],
                       "a heading dropped among another's things lands after them, and takes none of them")

        var lib = library()
        let before = page(lib)
        XCTAssertFalse(lib.dropLine(templateId: tpl(lib), from: 6, to: 0), "Everything else never moves")
        XCTAssertFalse(lib.dropLine(templateId: tpl(lib), from: 9, to: 0))
        XCTAssertFalse(lib.dropLine(templateId: tpl(lib), from: 0, to: 10))
        XCTAssertFalse(lib.dropLine(templateId: "no-such", from: 0, to: 1))
        XCTAssertEqual(page(lib), before)
    }

    /// A template with no headings is arranged as one list.
    func testATemplateWithNoHeadingsIsOneList() {
        var lib = Library()
        var swim = newList(name: "Swim", group: "WET")
        swim.items = ["Goggles", "Swim cap", "Towel"].map { newItem(name: $0) }
        lib.saveTemplate(swim)
        let towel = lib.resolvedTemplate(id: swim.id)!.items.last!.memId!
        let goggles = lib.resolvedTemplate(id: swim.id)!.items.first!.memId!
        XCTAssertTrue(lib.moveRow(templateId: swim.id, memId: towel, section: "", before: goggles))
        XCTAssertEqual(lib.resolvedTemplate(id: swim.id)!.items.map(\.name), ["Towel", "Goggles", "Swim cap"])
        XCTAssertEqual(lib.arrangeLines(templateId: swim.id).count, 3, "no heading lines at all")
        XCTAssertTrue(lib.dropLine(templateId: swim.id, from: 0, to: 3), "dragged to the end")
        XCTAssertEqual(lib.resolvedTemplate(id: swim.id)!.items.map(\.name), ["Goggles", "Swim cap", "Towel"])
    }

    /// Only what changed is written, the way every other edit is stored and synced;
    /// a move that changes nothing writes nothing; and what he arranged survives the
    /// records and a backup.
    func testArrangingIsSavedLikeAnyTemplateEditAndOnlyWhatChanged() throws {
        var lib = library()
        let t = tpl(lib), lights = section(lib, "Lights"), clothes = section(lib, "Clothes")
        lib.moveSection(templateId: t, sectionId: lights)                 // renumbers everything once
        let held = lib.records()
        PackingEnv.freeze(at: "2026-10-05T12:00:00.000Z", idPrefix: "later-")
        // One row moved one place down under its own heading: two rows change number,
        // and the template is stamped as edited.
        XCTAssertTrue(lib.moveRow(templateId: t, memId: mem(lib, "Boots"), section: clothes))
        let changes = recordChanges(from: held, to: lib.records())
        XCTAssertEqual(Set(changes.puts.map(\.table)), [.memberships, .templates])
        XCTAssertEqual(changes.puts.filter { $0.table == .memberships }.count, 2)
        XCTAssertTrue(changes.deletes.isEmpty)
        // Done again, nothing changes and nothing is written — not even the template's
        // "edited" stamp, a day later.
        let now = lib.records()
        PackingEnv.freeze(at: "2026-10-06T12:00:00.000Z", idPrefix: "later2-")
        XCTAssertTrue(lib.moveRow(templateId: t, memId: mem(lib, "Boots"), section: clothes))
        XCTAssertTrue(lib.moveSection(templateId: t, sectionId: lights))
        XCTAssertTrue(recordChanges(from: now, to: lib.records()).isEmpty, "a move to where it already is wrote something")

        lib.renameSection(templateId: t, sectionId: clothes, to: "Clothing")
        let arranged = page(lib)
        XCTAssertEqual(page(Library(records: lib.records())), arranged, "lost through the records (sync)")
        let json = try JSONValue.parse(lib.backupData())
        let (restored, report) = Importer.library(from: BackupFile(json: json))
        XCTAssertTrue(report.isFaithful)
        XCTAssertEqual(page(restored), arranged, "lost through a backup")
    }

    /// A trip takes a template's rows in their order and lists the headings by the
    /// first row under each — so a NEW trip, or a rebuilt one, reads as he arranged
    /// it, and a trip already made is not touched.
    func testANewOrRebuiltTripFollowsTheNewOrderAndAnOldOneIsUntouched() {
        var lib = library()
        let t = tpl(lib), lights = section(lib, "Lights"), clothes = section(lib, "Clothes")
        var draft = newEvent(name: "Hills", startDate: "2026-11-01", endDate: "2026-11-03")
        draft.activities = [t]
        let old = lib.createTrip(draft)
        let headings = { (trip: TripEvent) in groupBySection(trip.entries).map(\.label) }
        XCTAssertEqual(headings(old), ["Clothes", "Lights", "Everything else"], "the jumble: Boots came first")

        lib.moveSection(templateId: t, sectionId: lights, before: clothes)
        lib.moveRow(templateId: t, memId: mem(lib, "Spare batteries"), section: lights, before: mem(lib, "Headlamp"))
        XCTAssertEqual(lib.trips[0], old, "a trip already made was changed")

        draft.id = ""
        let fresh = lib.createTrip(draft)
        XCTAssertEqual(headings(fresh), ["Lights", "Clothes", "Everything else"])
        XCTAssertEqual(fresh.entries.map(\.name), ["Spare batteries", "Headlamp", "Boots", "Rain jacket", "Map"])
        // Rebuilt (Trip settings → Save): its lines in the new order, each keeping its id.
        let rebuilt = lib.regenerated(lib.trips[0])
        XCTAssertEqual(rebuilt.map(\.name), ["Spare batteries", "Headlamp", "Boots", "Rain jacket", "Map"])
        XCTAssertEqual(Set(rebuilt.map(\.id)), Set(old.entries.map(\.id)))
    }
}
