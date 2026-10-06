import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// A thing's section on each template, set from the thing's own page (0.64). His ask
/// (6 Oct 2026): sections give "a visual structure to the packing", and he wanted to
/// set a thing's section "already in this view" — its page.
final class ThingSectionTests: XCTestCase {
    override func setUp() { PackingEnv.freeze(); _ = setPhases(DEFAULT_PHASES) }
    override func tearDown() { PackingEnv.reset(); _ = setPhases(DEFAULT_PHASES) }

    /// Hiking (Headlamp, Map; a section "Lights") and Beach (Map) — the Map on both.
    private func library() -> Library {
        var lib = Library()
        var hiking = newList(name: "Hiking", group: "GA")
        hiking.items = [newItem(name: "Headlamp"), newItem(name: "Map")]
        lib.saveTemplate(hiking)
        var beach = newList(name: "Beach", group: "OE")
        beach.items = [newItem(name: "Map"), newItem(name: "Sun hat")]
        lib.saveTemplate(beach)
        _ = lib.addSection(templateId: tpl(lib, "Hiking"), name: "Lights")
        return lib
    }
    private func tpl(_ lib: Library, _ name: String) -> String { lib.templates.first { $0.name == name }!.id }
    private func thing(_ lib: Library, _ name: String) -> String { lib.items.first { $0.name == name }!.id }
    private func sections(_ lib: Library, _ template: String) -> [TemplateSection] {
        lib.templates.first { $0.name == template }!.sections
    }
    private func place(_ lib: Library, _ thingName: String, on template: String) -> Membership {
        let t = tpl(lib, template), i = thing(lib, thingName)
        return lib.memberships.first { $0.templateId == t && $0.itemId == i }!
    }

    /// Chosen on Hiking, the Map sits under Lights there — and only there: Beach keeps
    /// it under no heading. "No section" takes it out again.
    func testASectionIsSetOnOneTemplateOnly() {
        var lib = library()
        let map = thing(lib, "Map"), hiking = tpl(lib, "Hiking")
        let lights = sections(lib, "Hiking")[0].id
        XCTAssertEqual(lib.thingSection(itemId: map, templateId: hiking), "")

        XCTAssertTrue(lib.setThingSection(itemId: map, templateId: hiking, section: lights))
        XCTAssertEqual(place(lib, "Map", on: "Hiking").section, lights)
        XCTAssertEqual(lib.thingSection(itemId: map, templateId: hiking), lights)
        XCTAssertEqual(place(lib, "Map", on: "Beach").section, "", "another template's place was moved")
        // The template's page reads it under that heading.
        let groups = groupItemsBySection(lib.resolvedTemplate(id: hiking)!.items, sections(lib, "Hiking"))
        XCTAssertEqual(groups.first?.section?.name, "Lights")
        XCTAssertEqual(groups.first?.items.map(\.name), ["Map"])

        XCTAssertTrue(lib.setThingSection(itemId: map, templateId: hiking, section: ""))
        XCTAssertEqual(place(lib, "Map", on: "Hiking").section, "", "No section did not take it out")
    }

    /// A name typed on the page: a new section is made and holds the thing; the same
    /// name again (any capitals) is that section, never a second one; the name of a
    /// section the template already has chooses it.
    func testATypedSectionIsMadeOnceAndAKnownNameIsChosen() {
        var lib = library()
        let map = thing(lib, "Map"), hiking = tpl(lib, "Hiking")
        XCTAssertTrue(lib.setThingSection(itemId: map, templateId: hiking, section: "", newSection: " Navigation "))
        XCTAssertEqual(sections(lib, "Hiking").map(\.name), ["Lights", "Navigation"])
        XCTAssertEqual(place(lib, "Map", on: "Hiking").section, sections(lib, "Hiking")[1].id)

        XCTAssertFalse(lib.setThingSection(itemId: map, templateId: hiking, section: "", newSection: "navigation"),
                       "the section it is already in counted as a change")
        XCTAssertEqual(sections(lib, "Hiking").count, 2, "the same name made a second section")

        XCTAssertTrue(lib.setThingSection(itemId: map, templateId: hiking, section: "", newSection: "LIGHTS"))
        XCTAssertEqual(sections(lib, "Hiking").count, 2, "a name the template has made a new section")
        XCTAssertEqual(place(lib, "Map", on: "Hiking").section, sections(lib, "Hiking")[0].id)
        // A typed name wins over the id handed with it.
        XCTAssertTrue(lib.setThingSection(itemId: map, templateId: hiking, section: sections(lib, "Hiking")[0].id,
                                          newSection: "Rig"))
        XCTAssertEqual(place(lib, "Map", on: "Hiking").section, sections(lib, "Hiking")[2].id)
    }

    /// Unchanged is a no-op: nothing written, no section made, no trip touched. So is
    /// a section of another template, and a template the thing is not on.
    func testNothingIsWrittenWhenNothingChanges() {
        var lib = library()
        let map = thing(lib, "Map"), hiking = tpl(lib, "Hiking"), beach = tpl(lib, "Beach")
        let lights = sections(lib, "Hiking")[0].id
        XCTAssertTrue(lib.setThingSection(itemId: map, templateId: hiking, section: lights))
        var trip = newEvent(name: "Hills", startDate: "2099-06-01", endDate: "2099-06-03")
        trip.activities = [hiking]
        _ = lib.createTrip(trip)
        let before = lib

        XCTAssertFalse(lib.setThingSection(itemId: map, templateId: hiking, section: lights), "the same section")
        XCTAssertFalse(lib.setThingSection(itemId: map, templateId: hiking, section: "", newSection: " lights "),
                       "the name of the section it is in")
        XCTAssertFalse(lib.setThingSection(itemId: map, templateId: beach, section: lights),
                       "Hiking's section was put on Beach")
        XCTAssertFalse(lib.setThingSection(itemId: map, templateId: beach, section: "gone"), "an unknown section")
        XCTAssertFalse(lib.setThingSection(itemId: thing(lib, "Sun hat"), templateId: hiking, section: lights),
                       "a thing that is not on the template")
        XCTAssertFalse(lib.setThingSection(itemId: map, templateId: "nowhere", section: ""), "an unknown template")
        XCTAssertEqual(lib, before, "a no-op changed the library")
    }

    /// On a template twice, the page speaks for the FIRST place as the template reads
    /// its rows (by order, not by where it is stored); the second keeps its own section.
    func testAThingTwiceOnATemplateSetsItsFirstPlace() {
        var lib = library()
        let map = thing(lib, "Map"), hiking = tpl(lib, "Hiking")
        let lights = sections(lib, "Hiking")[0].id
        let first = place(lib, "Map", on: "Hiking")
        // A second place, stored first but read last (a later order).
        var again = newMembership(itemId: map, templateId: hiking)
        again.order = first.order + 10
        again.phase = "morning"
        lib.memberships.insert(again, at: 0)
        XCTAssertEqual(lib.firstPlace(itemId: map, templateId: hiking)?.id, first.id)

        XCTAssertTrue(lib.setThingSection(itemId: map, templateId: hiking, section: lights))
        XCTAssertEqual(lib.memberships.first { $0.id == first.id }?.section, lights)
        XCTAssertEqual(lib.memberships.first { $0.id == again.id }?.section, "", "the second place was moved too")
    }

    /// A section from elsewhere (another template's, or one since removed) reads as
    /// none on the page, as on the template's page — and stays stored until he
    /// chooses something else.
    func testASectionFromElsewhereReadsAsNone() {
        var lib = library()
        let map = thing(lib, "Map"), beach = tpl(lib, "Beach")
        let lights = sections(lib, "Hiking")[0].id
        lib.updateMembership(memId: place(lib, "Map", on: "Beach").id) { $0.section = lights }
        XCTAssertEqual(lib.thingSection(itemId: map, templateId: beach), "")
        XCTAssertEqual(place(lib, "Map", on: "Beach").section, lights)
    }

    /// Saved from the page, the section reaches the trips still ahead the way a row
    /// saved in the row editor does: an open line moves under its new heading; a
    /// ticked line, and a trip that is over, keep what they were packed with.
    func testTheSectionReachesATripStillAheadOnly() {
        var lib = library()
        let map = thing(lib, "Map"), hiking = tpl(lib, "Hiking")
        var ahead = newEvent(name: "Hills", startDate: "2099-06-01", endDate: "2099-06-03")
        ahead.activities = [hiking]
        ahead = lib.createTrip(ahead)
        var ticked = newEvent(name: "Hills again", startDate: "2099-07-01", endDate: "2099-07-03")
        ticked.activities = [hiking]
        ticked = lib.createTrip(ticked)
        var over = newEvent(name: "Last year", startDate: "2001-06-01", endDate: "2001-06-03")
        over.activities = [hiking]
        over = lib.createTrip(over)
        func line(_ trip: TripEvent) -> Item { lib.trips.first { $0.id == trip.id }!.entries.first { $0.name == "Map" }! }
        XCTAssertTrue(lib.setChecked(true, tripId: ticked.id, entryId: line(ticked).id))
        let packedId = line(ahead).id

        XCTAssertTrue(lib.setThingSection(itemId: map, templateId: hiking, section: "", newSection: "Navigation"))
        XCTAssertEqual(line(ahead).section, "Navigation", "the trip still ahead did not follow")
        XCTAssertEqual(line(ahead).id, packedId, "the line lost its id")
        XCTAssertEqual(groupBy("section", lib.trips.first { $0.id == ahead.id }!.entries).map(\.label),
                       ["Navigation", "Everything else"], "the trip sorted by Section does not read it")
        XCTAssertEqual(line(ticked).section, "", "a ticked line was changed")
        XCTAssertEqual(line(over).section, "", "a trip that is over was changed")
    }
}
