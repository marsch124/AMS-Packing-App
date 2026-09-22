import XCTest
import PackingCore
@testable import PackingLibrary

/// Invented data only — this repository is public.
final class CreateTripTests: XCTestCase {

    override func setUp() { PackingEnv.freeze() }
    override func tearDown() { PackingEnv.reset(); _ = setPhases(DEFAULT_PHASES) }

    func testATripIsBuiltFromItsTemplatesAndTheBase() {
        var lib = LibraryTests.sample()
        lib.trips = []
        var base = newList(name: "Common base", role: "base"); base.items = [newItem(name: "Passport")]
        lib.saveTemplate(base)
        let hiking = lib.templates.first { $0.name == "Hiking" }!
        var draft = newEvent(name: "Fjäll", startDate: "2026-10-03", endDate: "2026-10-05")
        draft.activities = [hiking.id]
        let trip = lib.createTrip(draft)
        XCTAssertEqual(lib.trips.count, 1)
        XCTAssertEqual(trip.nights, 2, "nights come from the dates")
        XCTAssertTrue(trip.entries.contains { $0.name == "Passport" }, "the base list is always packed")
        XCTAssertTrue(trip.entries.contains { $0.name == "Headlamp" })
        XCTAssertFalse(trip.entries.contains { $0.name == "Goggles" }, "an unticked list is not")
        XCTAssertEqual(trip.entries.map(\.name), buildTotalEntries(trip, lib.resolvedTemplates()).map(\.name), "the lines are the model's")
        XCTAssertFalse(trip.generatedAt.isEmpty)
    }

    func testAQuickTripSkipsTheBase() {
        var lib = LibraryTests.sample()
        lib.trips = []
        var base = newList(name: "Common base", role: "base"); base.items = [newItem(name: "Passport")]
        lib.saveTemplate(base)
        var draft = newEvent(name: "Swim", mode: "quick")
        draft.activities = [lib.templates.first { $0.name == "Night run" }!.id]
        let trip = lib.createTrip(draft)
        XCTAssertFalse(trip.entries.contains { $0.name == "Passport" })
        XCTAssertTrue(trip.entries.contains { $0.name == "Headlamp" })
    }

    func testTheChoicesAreHisGroupsInHisOrder() {
        var lib = LibraryTests.sample()
        var swim = newList(name: "Swim", group: "WET"); swim.items = [newItem(name: "Goggles")]
        var bike = newList(name: "Bike", group: "WET"); bike.items = [newItem(name: "Helmet")]
        var hike = lib.resolvedTemplates().first { $0.name == "Hiking" }!; hike.group = "GA"
        lib.saveTemplate(swim); lib.saveTemplate(bike); lib.saveTemplate(hike)
        let choices = lib.activityChoices()
        XCTAssertEqual(choices.map { $0.group.id }, ["GA", "WET"])
        XCTAssertEqual(choices.last?.lists.map(\.name), ["Swim", "Bike"], "race order, not the alphabet")
    }
}

final class CustomLineTests: XCTestCase {
    override func setUp() { PackingEnv.freeze() }
    override func tearDown() { PackingEnv.reset(); _ = setPhases(DEFAULT_PHASES) }

    func testATypedThingJoinsTheTripAndSurvivesARegenerate() {
        var lib = LibraryTests.sample()
        let trip = lib.trips[0]
        let before = trip.entries.count
        let line = lib.addCustomLine(tripId: trip.id, name: "  Tripod ")
        XCTAssertEqual(line?.name, "Tripod")
        XCTAssertEqual(lib.trips[0].entries.count, before + 1)
        XCTAssertTrue(lib.trips[0].entries.last!.custom)
        XCTAssertEqual(progress(lib.trips[0].entries).total, before + 1)
        XCTAssertTrue(lib.regenerated(lib.trips[0]).contains { $0.name == "Tripod" }, "a custom line is never dropped")
        XCTAssertNil(lib.addCustomLine(tripId: trip.id, name: "   "), "nothing is added for a blank name")
        XCTAssertNil(lib.addCustomLine(tripId: "no-such-trip", name: "Tripod"))
    }
}

final class ActionsTests: XCTestCase {
    override func setUp() { PackingEnv.freeze() }
    override func tearDown() { PackingEnv.reset() }

    func testToDosAreAddedTickedAndOrderedTheWebAppsWay() {
        var lib = Library()
        let a = lib.addAction(text: " Book the ferry ")!
        let b = lib.addAction(text: "Charge the lamp", priority: "high")!
        XCTAssertEqual(a.text, "Book the ferry")
        XCTAssertEqual(lib.sortedActions().map(\.id), [b.id, a.id], "high before normal")
        XCTAssertTrue(lib.setActionDone(true, id: b.id))
        XCTAssertEqual(lib.sortedActions().map(\.id), [a.id, b.id], "open before done")
        XCTAssertFalse(lib.actions.first { $0.id == b.id }!.doneAt.isEmpty)
        XCTAssertNil(lib.addAction(text: "  "))
        lib.deleteAction(id: a.id)
        XCTAssertEqual(lib.actions.count, 1)
        XCTAssertEqual(lib.records().filter { $0.table == .actions }.count, 1, "one record per to-do")
    }
}

final class TemplateEditingTests: XCTestCase {
    override func setUp() { PackingEnv.freeze() }
    override func tearDown() { PackingEnv.reset(); _ = setPhases(DEFAULT_PHASES) }

    func testAddingANewNameMakesANewThingAndAKnownNamePutsTheSameThingOn() {
        var lib = LibraryTests.sample()
        let hiking = lib.templates.first { $0.name == "Hiking" }!
        let things = lib.items.count
        XCTAssertNotNil(lib.addToTemplate(templateId: hiking.id, name: " Gaiters "))
        XCTAssertEqual(lib.items.count, things + 1, "a new name is a new thing")
        XCTAssertEqual(lib.resolvedTemplate(id: hiking.id)!.items.last?.name, "Gaiters")
        // The headlamp already exists (it is on Night run too): the same thing goes on.
        let run = lib.templates.first { $0.name == "Night run" }!
        var r = lib.resolvedTemplate(id: run.id)!
        r.items.removeAll { $0.name == "Headlamp" }; lib.saveTemplate(r)
        let lampId = lib.items.first { $0.name == "Headlamp" }!.id
        XCTAssertNotNil(lib.addToTemplate(templateId: run.id, name: "headlamp"))
        XCTAssertEqual(lib.items.count, things + 1, "no second headlamp")
        XCTAssertEqual(lib.resolvedTemplate(id: run.id)!.items.last?.itemId, lampId)
        XCTAssertEqual(lib.resolvedTemplate(id: run.id)!.items.last?.packer, "Anna", "and it brings what it knows about itself")
        XCTAssertNil(lib.addToTemplate(templateId: hiking.id, name: "  "))
    }

    func testRemovingARowKeepsTheThing() {
        var lib = LibraryTests.sample()
        let hiking = lib.templates.first { $0.name == "Hiking" }!
        let row = lib.resolvedTemplate(id: hiking.id)!.items.first { $0.name == "Headlamp" }!
        XCTAssertTrue(lib.removeFromTemplate(templateId: hiking.id, memId: row.memId!))
        XCTAssertFalse(lib.resolvedTemplate(id: hiking.id)!.items.contains { $0.name == "Headlamp" })
        XCTAssertTrue(lib.items.contains { $0.name == "Headlamp" }, "the thing survives")
        XCTAssertTrue(lib.resolvedTemplate(id: lib.templates.first { $0.name == "Night run" }!.id)!.items.contains { $0.name == "Headlamp" })
        XCTAssertFalse(lib.removeFromTemplate(templateId: hiking.id, memId: "no-such"))
    }
}

final class CareTests: XCTestCase {
    override func setUp() { PackingEnv.freeze() }
    override func tearDown() { PackingEnv.reset(); _ = setPhases(DEFAULT_PHASES) }

    func testAThingOnTwoTemplatesIsOneCareRowAndDoneTodayMovesItOn() {
        var lib = LibraryTests.sample()
        let n = lib.items.firstIndex { $0.name == "Headlamp" }!
        lib.items[n].maintenance = Maintenance(notes: "Clean the contacts", intervalDays: 30, lastDone: "2026-01-01")
        let rows = lib.careRows(today: "2026-09-22")
        XCTAssertEqual(rows.count, 1, "the headlamp sits on two templates but is ONE care row")
        XCTAssertEqual(rows[0].status.state, "overdue")
        XCTAssertEqual(rows[0].item.itemId, lib.items[n].id, "the row knows which thing to log")

        XCTAssertTrue(lib.logCare(itemId: lib.items[n].id, on: "2026-09-22"))
        let after = lib.careRows(today: "2026-09-22")
        XCTAssertEqual(after[0].status.state, "ok")
        XCTAssertEqual(after[0].status.nextDue, "2026-10-22")
        XCTAssertEqual(lib.items[n].maintenance?.log.map(\.date), ["2026-09-22"])
        XCTAssertEqual(lib.records().filter { $0.table == .items && $0.key == lib.items[n].id }.count, 1)
        XCTAssertFalse(lib.logCare(itemId: "no-such", on: "2026-09-22"))
    }
}

final class ReviewTests: XCTestCase {
    override func setUp() { PackingEnv.freeze() }
    override func tearDown() { PackingEnv.reset(); _ = setPhases(DEFAULT_PHASES) }

    func testAReviewTeachesTheThingsAndFilesWhatWasMissed() {
        var lib = LibraryTests.sample()
        let trip = lib.trips[0]
        let lamp = trip.entries.first { $0.name == "Headlamp" }!
        let batteries = trip.entries.first { $0.name == "Spare batteries" }!
        lib.setChecked(true, tripId: trip.id, entryId: lamp.id)
        lib.setChecked(true, tripId: trip.id, entryId: batteries.id)
        let lines = lib.reviewLines(tripId: trip.id)
        XCTAssertEqual(Set(lines.packed.map(\.id)), [lamp.id, batteries.id], "only what went in the bag is asked about")
        XCTAssertEqual(lines.neverPacked.count, trip.entries.count - 2)

        let hiking = lib.templates.first { $0.name == "Hiking" }!
        XCTAssertTrue(lib.saveReview(tripId: trip.id, unused: [batteries.id],
                                     missed: [Library.Missed(name: "Tripod", templateId: hiking.id),
                                              Library.Missed(name: "Sit mat", templateId: "")],
                                     when: "2026-09-22T18:00:00.000Z"))
        let stats = { (name: String) in lib.items.first { $0.name == name }!.stats }
        XCTAssertEqual(stats("Headlamp").packed, 1)
        XCTAssertEqual(stats("Headlamp").used, 1)
        XCTAssertEqual(stats("Spare batteries").unused, 1,
                       "packed, not used — and kept, although the thing sits on Hiking TWICE (the stale twin must not overwrite it)")
        XCTAssertEqual(stats("Headlamp").lastReviewed, "2026-09-22T18:00:00.000Z")
        XCTAssertTrue(lib.resolvedTemplate(id: hiking.id)!.items.contains { $0.name == "Tripod" }, "the missed thing comes next time")
        XCTAssertTrue(lib.thingsOnNoList().contains { $0.name == "Sit mat" }, "a missed thing with no list is a thing of its own")
        XCTAssertEqual(lib.trips[0].status, "done")
        XCTAssertEqual(lib.trips[0].reviewedAt, "2026-09-22T18:00:00.000Z")
        XCTAssertFalse(lib.saveReview(tripId: "no-such", unused: [], missed: [], when: "x"))
    }
}

final class ThingsTests: XCTestCase {
    override func setUp() { PackingEnv.freeze() }
    override func tearDown() { PackingEnv.reset(); _ = setPhases(DEFAULT_PHASES) }

    func testYourThingsListsEverythingAndARenameReachesEveryList() {
        var lib = LibraryTests.sample()
        let rows = lib.thingRows()
        XCTAssertEqual(rows.map(\.item.name), ["Headlamp", "Spare batteries"], "A–Z, one row per thing")
        XCTAssertEqual(Set(rows[0].templates), ["Hiking", "Night run"])

        let mat = lib.addThing(name: " Sit mat ")
        XCTAssertEqual(mat?.name, "Sit mat")
        XCTAssertEqual(lib.thingRows().first { $0.item.name == "Sit mat" }?.templates, [], "on no list")
        XCTAssertNil(lib.addThing(name: "sit MAT"), "no second thing of the same name")

        let lamp = lib.items.first { $0.name == "Headlamp" }!
        XCTAssertTrue(lib.renameThing(id: lamp.id, to: "Head torch"))
        for t in lib.resolvedTemplates() where t.name == "Hiking" || t.name == "Night run" {
            XCTAssertTrue(t.items.contains { $0.name == "Head torch" }, "\(t.name) shows the new name")
        }
        XCTAssertTrue(lib.trips[0].entries.contains { $0.name == "Headlamp" }, "a past trip keeps what it was packed as")
        XCTAssertFalse(lib.renameThing(id: lamp.id, to: "Sit mat"), "a name another thing has is refused")
        XCTAssertFalse(lib.renameThing(id: lamp.id, to: "  "))
        XCTAssertTrue(lib.setStorage(id: lamp.id, place: " Hall closet "))
        XCTAssertEqual(lib.items.first { $0.id == lamp.id }?.storage, "Hall closet")
    }
}

final class ThingEditingTests: XCTestCase {
    override func setUp() { PackingEnv.freeze() }
    override func tearDown() { PackingEnv.reset(); _ = setPhases(DEFAULT_PHASES) }

    func testWhatTheThingKnowsReachesEveryListItIsOn() {
        var lib = LibraryTests.sample()
        let lamp = lib.items.first { $0.name == "Headlamp" }!
        XCTAssertTrue(lib.updateThing(id: lamp.id) { it in
            it.category = "Electronics"; it.ownedBy = "Anna"; it.condition = "worn"; it.weight = 95; it.phase = "morning"
        })
        for t in lib.resolvedTemplates() where t.name == "Hiking" || t.name == "Night run" {
            let row = t.items.first { $0.name == "Headlamp" }!
            XCTAssertEqual(row.category, "Electronics", "\(t.name)")
            XCTAssertEqual(row.ownedBy, "Anna")
            XCTAssertEqual(row.condition, "worn")
            XCTAssertEqual(row.weight, 95)
            XCTAssertEqual(row.phase, "morning", "the thing's own When, where no list overrides it")
        }
        // The Night run list keeps its own exception for the bag.
        XCTAssertEqual(lib.resolvedTemplates().first { $0.name == "Night run" }?.items.first?.container, "Duffel bag")
        XCTAssertFalse(lib.updateThing(id: "no-such") { _ in })
    }

    func testAThingIsPutOnAListAndTakenOff() {
        var lib = LibraryTests.sample()
        let swim = lib.templates.first { $0.name == "Swim" } ?? { var l = newList(name: "Swim"); l.items = [newItem(name: "Goggles")]; lib.saveTemplate(l); return lib.templates.first { $0.name == "Swim" }! }()
        let lamp = lib.items.first { $0.name == "Headlamp" }!
        XCTAssertTrue(lib.setOnTemplate(itemId: lamp.id, templateId: swim.id, on: true))
        XCTAssertTrue(lib.resolvedTemplate(id: swim.id)!.items.contains { $0.name == "Headlamp" })
        XCTAssertEqual(lib.memberships.filter { $0.itemId == lamp.id }.count, 3)
        XCTAssertTrue(lib.setOnTemplate(itemId: lamp.id, templateId: swim.id, on: true), "asking twice changes nothing")
        XCTAssertEqual(lib.memberships.filter { $0.itemId == lamp.id }.count, 3)
        XCTAssertTrue(lib.setOnTemplate(itemId: lamp.id, templateId: swim.id, on: false))
        XCTAssertFalse(lib.resolvedTemplate(id: swim.id)!.items.contains { $0.name == "Headlamp" })
        XCTAssertTrue(lib.items.contains { $0.id == lamp.id }, "the thing survives")
        XCTAssertFalse(lib.setOnTemplate(itemId: lamp.id, templateId: "no-such", on: true))
    }
}

final class RowEditingTests: XCTestCase {
    override func setUp() { PackingEnv.freeze() }
    override func tearDown() { PackingEnv.reset(); _ = setPhases(DEFAULT_PHASES) }

    func testThisListsOwnAnswersStayThisListsOwn() {
        var lib = LibraryTests.sample()
        let hiking = lib.templates.first { $0.name == "Hiking" }!
        let run = lib.templates.first { $0.name == "Night run" }!
        let memId = lib.resolvedTemplate(id: hiking.id)!.items.first { $0.name == "Headlamp" }!.memId!
        let section = lib.addSection(templateId: hiking.id, name: " Lights ")!
        XCTAssertEqual(section.name, "Lights")
        XCTAssertEqual(lib.addSection(templateId: hiking.id, name: "lights")?.id, section.id, "the same section, not a second one")

        XCTAssertTrue(lib.updateMembership(memId: memId) { m in
            m.container = "Hiking backpack"; m.phase = "morning"; m.qty = "2"; m.note = "with the red filter"; m.section = section.id
        })
        let here = lib.resolvedTemplate(id: hiking.id)!.items.first { $0.name == "Headlamp" }!
        XCTAssertEqual(here.container, "Hiking backpack")
        XCTAssertEqual(here.phase, "morning")
        XCTAssertEqual(here.qty, "2")
        XCTAssertEqual(here.note, "with the red filter")
        XCTAssertEqual(here.section, section.id)
        // The thing itself, and the other list, are untouched.
        XCTAssertEqual(lib.items.first { $0.name == "Headlamp" }?.container, "Day pack")
        let there = lib.resolvedTemplate(id: run.id)!.items.first { $0.name == "Headlamp" }!
        XCTAssertEqual(there.container, "Duffel bag")
        XCTAssertEqual(there.phase, "week")
        XCTAssertEqual(there.qty, "")

        // Blank again = follow the thing.
        XCTAssertTrue(lib.updateMembership(memId: memId) { $0.container = ""; $0.phase = "" })
        let back = lib.resolvedTemplate(id: hiking.id)!.items.first { $0.name == "Headlamp" }!
        XCTAssertEqual(back.container, "Day pack")
        XCTAssertEqual(back.phase, "week")
        XCTAssertFalse(lib.updateMembership(memId: "no-such") { _ in })
    }

    func testTheRowsOfATemplateGroupIntoItsSections() {
        var lib = LibraryTests.sample()
        let hiking = lib.templates.first { $0.name == "Hiking" }!
        let lights = lib.addSection(templateId: hiking.id, name: "Lights")!
        let memId = lib.resolvedTemplate(id: hiking.id)!.items.first { $0.name == "Headlamp" }!.memId!
        lib.updateMembership(memId: memId) { $0.section = lights.id }
        let list = lib.resolvedTemplate(id: hiking.id)!
        let groups = groupItemsBySection(list.items, list.sections)
        XCTAssertEqual(groups.first?.section?.name, "Lights")
        XCTAssertEqual(groups.first?.items.map(\.name), ["Headlamp"])
        XCTAssertNil(groups.last?.section, "the rest sit in no section")
    }
}
