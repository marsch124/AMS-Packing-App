import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// Reminders on a template (spec 07, part 12; his idea of 7 Oct 2026): a list of
/// simple reminders per template, made of what the web app already knows — items
/// whose `itemType` is "reminder" — and carried onto a trip as lines that are ticked
/// but never packed. Invented names only.
final class TemplateRemindersTests: XCTestCase {
    override func setUp() { PackingEnv.freeze(at: "2026-10-01T12:00:00.000Z") }
    override func tearDown() { PackingEnv.reset() }

    /// Two templates: a base one with a thing on it, and a workout.
    private func library() -> (Library, base: String, row: String) {
        var lib = Library()
        var base = newList(name: "Base", role: "base")
        base.items = [newItem(name: "Kettle", weight: 900)]
        lib.saveTemplate(base)
        lib.saveTemplate(newList(name: "Rowing", group: "WET"))
        return (lib, lib.templates.first { $0.role == "base" }!.id, lib.templates.first { $0.name == "Rowing" }!.id)
    }

    func testAReminderIsTheWebAppsOwnKindOfItem() {
        var (lib, base, _) = library()
        let r = lib.addReminder(templateId: base, name: "  Fill the flask ", when: "daybefore")
        XCTAssertEqual(r?.name, "Fill the flask", "the name is trimmed")
        let item = lib.items.first { $0.name == "Fill the flask" }!
        XCTAssertEqual(item.itemType, "reminder", "a reminder is the web app's itemType, not a new shape")
        XCTAssertEqual(item.category, "Reminders")
        XCTAssertEqual(item.container, "", "a reminder goes in no bag")
        XCTAssertEqual(item.weight, 0, "a reminder is never weighed")
        XCTAssertTrue(item.shortList, "a quick trip brings it too")
        XCTAssertEqual(lib.reminders(templateId: base).map(\.name), ["Fill the flask"])
        XCTAssertEqual(lib.reminders(templateId: base).first?.phase, "daybefore")
        XCTAssertEqual(lib.resolvedTemplate(id: base)?.items.last?.name, "Fill the flask", "last among the rows")
    }

    func testANameIsRefusedWhenBlankAlreadyHereOrOneOfHisThings() {
        var (lib, base, rowing) = library()
        XCTAssertNil(lib.addReminder(templateId: base, name: "   "))
        XCTAssertEqual(lib.reminderNameProblem(templateId: base, name: " "), .blank)
        XCTAssertNotNil(lib.addReminder(templateId: base, name: "Oil the chain"))
        XCTAssertEqual(lib.reminderNameProblem(templateId: base, name: "oil  THE chain"), .alreadyHere)
        XCTAssertNil(lib.addReminder(templateId: base, name: "Oil the chain"), "twice on one template")
        XCTAssertEqual(lib.reminderNameProblem(templateId: base, name: "kettle"), .aThing, "a thing is no reminder")
        // The same reminder on another template is ONE reminder, two places.
        XCTAssertNotNil(lib.addReminder(templateId: rowing, name: "Oil the chain"))
        XCTAssertEqual(lib.items.filter { $0.name == "Oil the chain" }.count, 1)
        XCTAssertEqual(lib.reminders(templateId: rowing).map(\.name), ["Oil the chain"])
    }

    func testANewReminderStartsAtTheLastOnesWhenElseTheDayBefore() {
        var (lib, base, _) = library()
        XCTAssertEqual(lib.whenForNewReminder(templateId: base), "daybefore", "the day before, when it has none")
        lib.addReminder(templateId: base, name: "Book the court", when: "prep")
        XCTAssertEqual(lib.whenForNewReminder(templateId: base), "prep", "the last reminder's When")
        XCTAssertEqual(lib.addReminder(templateId: base, name: "Pay the fee")?.phase, "prep")
    }

    func testRenameIsForThisTemplateOnly() {
        var (lib, base, rowing) = library()
        lib.addReminder(templateId: base, name: "Wax the skis", when: "week")
        lib.addReminder(templateId: rowing, name: "Wax the skis", when: "morning")
        let here = lib.reminders(templateId: rowing)[0].memId!
        XCTAssertTrue(lib.renameReminder(templateId: rowing, memId: here, to: "Wax the boat"))
        XCTAssertEqual(lib.reminders(templateId: base).map(\.name), ["Wax the skis"], "the other template keeps its name")
        XCTAssertEqual(lib.reminders(templateId: rowing).map(\.name), ["Wax the boat"])
        XCTAssertEqual(lib.reminders(templateId: rowing)[0].phase, "morning", "its When stays")
        XCTAssertEqual(lib.reminders(templateId: rowing)[0].memId, here, "its place stays")
        // Alone on its template, it is renamed in place: the same reminder.
        let id = lib.items.first { $0.name == "Wax the boat" }!.id
        XCTAssertTrue(lib.renameReminder(templateId: rowing, memId: here, to: "Wash the boat"))
        XCTAssertEqual(lib.items.first { $0.name == "Wash the boat" }?.id, id)
        XCTAssertNil(lib.items.first { $0.name == "Wax the boat" })
        XCTAssertFalse(lib.renameReminder(templateId: rowing, memId: here, to: "Kettle"), "a thing's name")
        XCTAssertFalse(lib.renameReminder(templateId: rowing, memId: here, to: ""), "blank")
    }

    func testOrderWhenAndRemove() {
        var (lib, base, _) = library()
        for n in ["One", "Two", "Three"] { lib.addReminder(templateId: base, name: "Step \(n)") }
        let mids = lib.reminders(templateId: base).compactMap(\.memId)
        XCTAssertTrue(lib.moveReminder(templateId: base, memId: mids[2], by: -1))
        XCTAssertEqual(lib.reminders(templateId: base).map(\.name), ["Step One", "Step Three", "Step Two"])
        XCTAssertFalse(lib.moveReminder(templateId: base, memId: mids[0], by: -1), "the first goes no higher")
        XCTAssertEqual(lib.resolvedTemplate(id: base)?.items.first?.name, "Kettle", "the thing keeps its place")
        XCTAssertTrue(lib.setReminderWhen(templateId: base, memId: mids[0], when: "door"))
        XCTAssertEqual(lib.reminders(templateId: base)[0].phase, "door")
        XCTAssertTrue(lib.removeReminder(templateId: base, memId: mids[1]))
        XCTAssertNil(lib.items.first { $0.name == "Step Two" }, "a reminder on no template goes altogether")
        XCTAssertEqual(lib.reminders(templateId: base).map(\.name), ["Step One", "Step Three"])
    }

    func testRemindersAreNotAmongHisThingsNorArranged() {
        var (lib, base, _) = library()
        lib.addReminder(templateId: base, name: "Lock the shed")
        XCTAssertEqual(lib.thingRows().map(\.item.name), ["Kettle"], "Your things lists things only")
        XCTAssertEqual(lib.ownThings().map(\.name), ["Kettle"])
        XCTAssertEqual(lib.templateSummary(lib.shownTemplates()).things, 1)
        XCTAssertEqual(lib.arrangeLines(templateId: base).count, 1, "Arrange moves the things only")
        // A reminder on NO template (from the web app) still shows, so it can be deleted.
        var loose = catalogItemFromResolved(newItem(name: "Old note", itemType: "reminder"))
        loose.id = "loose"
        lib.items.append(loose)
        XCTAssertTrue(lib.thingRows().contains { $0.item.name == "Old note" })
    }

    func testOnATripAReminderIsTickedButNeverPackedWeighedOrReviewed() {
        var (lib, base, _) = library()
        lib.addReminder(templateId: base, name: "Feed the cat", when: "daybefore")
        let trip = lib.createTrip(newEvent(name: "Away", startDate: "2026-10-03", endDate: "2026-10-05"))
        let line = trip.entries.first { $0.name == "Feed the cat" }!
        XCTAssertEqual(line.itemType, "reminder")
        XCTAssertEqual(line.phase, "daybefore", "at its When")
        XCTAssertEqual(lib.weighedBags(tripId: trip.id).map(\.load.items).reduce(0, +), 1, "in no bag: only the kettle")
        XCTAssertFalse(lib.reviewLines(tripId: trip.id).packed.contains { $0.name == "Feed the cat" }, "never asked about")
        let step = lib.packingSteps(tripId: trip.id).first { $0.phaseId == "daybefore" }!
        XCTAssertEqual(step.todo, 1)
        XCTAssertEqual(step.left, 0, "no thing to pack on that step")
        XCTAssertEqual(step.says, "Day before (stage / move to RV): 1 to do")
        XCTAssertTrue(lib.setChecked(true, tripId: trip.id, entryId: line.id), "ticked like a line")
        XCTAssertNil(lib.packingSteps(tripId: trip.id).first { $0.phaseId == "daybefore" })
    }

    func testDueRemindersAreThoseWhoseStepHasCome() {
        var (lib, base, _) = library()
        lib.addReminder(templateId: base, name: "Book a taxi", when: "week")
        lib.addReminder(templateId: base, name: "Water the plants", when: "daybefore")
        let trip = lib.createTrip(newEvent(name: "Away", startDate: "2026-10-05", endDate: "2026-10-07"))
        XCTAssertEqual(lib.dueReminders(tripId: trip.id, today: "2026-10-01").map(\.name), ["Book a taxi"])
        XCTAssertEqual(lib.dueReminders(tripId: trip.id, today: "2026-10-04").map(\.name), ["Book a taxi", "Water the plants"])
        XCTAssertEqual(lib.nextTrip(today: "2026-10-04")?.due, ["Book a taxi", "Water the plants"])
        XCTAssertEqual(lib.nextTrip(today: "2026-10-04")?.left, 1, "the things still to pack: the kettle")
        let taxi = lib.trips[0].entries.first { $0.name == "Book a taxi" }!
        _ = lib.setChecked(true, tripId: trip.id, entryId: taxi.id)
        XCTAssertEqual(lib.dueReminders(tripId: trip.id, today: "2026-10-04").map(\.name), ["Water the plants"], "ticked is done")
        let undated = lib.createTrip(newEvent(name: "Some day"))
        XCTAssertEqual(lib.dueReminders(tripId: undated.id, today: "2026-10-04"), [], "no date, nothing due")
    }

    func testAStepSaysThingsAndRemindersApart() {
        let s = Library.PackingStep(phaseId: "week", label: "Week", task: false, date: "2026-10-01", left: 3, todo: 2)
        XCTAssertEqual(s.says, "Week: 3 to pack, 2 to do")
        let prep = Library.PackingStep(phaseId: "prep", label: "Preparations", task: true, date: "2026-10-01", left: 1, todo: 2)
        XCTAssertEqual(prep.says, "Preparations: 3 to do", "on a step of things to do, reminders are to do too")
    }
}
