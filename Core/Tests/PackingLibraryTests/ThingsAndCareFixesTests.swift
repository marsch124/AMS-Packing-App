import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// The spec pass of 5 Oct 2026 over Things, Care, the table and To do: each test
/// pins one fix, named after what he would notice.
final class ThingsAndCareFixesTests: XCTestCase {
    override func setUp() {
        PackingEnv.freeze(at: "2026-10-05T12:00:00.000Z")
        _ = setPhases(DEFAULT_PHASES)
        _ = setItemConditions(DEFAULT_ITEM_CONDITIONS)
    }
    override func tearDown() {
        PackingEnv.reset()
        _ = setPhases(DEFAULT_PHASES)
        _ = setItemConditions(DEFAULT_ITEM_CONDITIONS)
    }

    /// Travel (Boots, Torch) and his bag list holding a bag of his own.
    private func library() -> Library {
        var lib = Library()
        var travel = newList(name: "Travel", role: "base")
        travel.items = ["Boots", "Torch"].map { newItem(name: $0) }
        lib.saveTemplate(travel)
        lib.addBag(name: "Sit bag")
        return lib
    }

    // MARK: Bags in the table

    func testTheBagNamesOfferedIncludeHisOwnBags() {
        let lib = library()
        let names = lib.bagNames()
        XCTAssertEqual(Array(names.prefix(CONTAINERS.count)), CONTAINERS, "the built-in names lead")
        XCTAssertEqual(names.last, "Sit bag", "his own bag is not offered — only the built-in names")
        XCTAssertEqual(names, containerNames(lib.resolvedTemplates()), "the table and the thing's page must offer the same bags")
    }

    func testHisBagListIsNotATemplateAThingIsTickedOnto() {
        let lib = library()
        XCTAssertEqual(lib.templates.count, 2)
        XCTAssertEqual(lib.templatesForThings().map(\.name), ["Travel"], "ticking the bag list made a thing a bag")
        let bagList = lib.bagList!.id
        XCTAssertFalse(lib.tableKnows("list:\(bagList)"), "the bag list is still a column, a filter or a sort key")
        XCTAssertTrue(lib.tableKnows("list:\(lib.templatesForThings()[0].id)"))
    }

    // MARK: Conditions: stored as the id

    func testAConditionStoredAsItsLabelIsRepairedToItsId() {
        var lib = library()
        func set(_ name: String, _ value: String) {
            let n = lib.items.firstIndex { $0.name == name }!
            lib.items[n].condition = value
        }
        set("Boots", "Needs replacing")        // as the table stored it before 0.6x
        set("Torch", "worn")                    // an id: left alone
        set("Sit bag", "Sliten")                // nothing of his: kept, never "corrected"
        XCTAssertEqual(lib.conditionLabel("Needs replacing"), "Needs replacing")
        XCTAssertEqual(lib.conditionLabel("retire"), "Needs replacing", "the table showed the raw id")
        XCTAssertEqual(lib.conditionLabel("Sliten"), "Sliten")
        XCTAssertFalse(conditionReplaces(lib.items.first { $0.name == "Boots" }!.condition),
                       "(the label is not an id: this is the bug being repaired)")

        XCTAssertEqual(lib.repairConditionLabels(), 1)
        XCTAssertEqual(lib.items.first { $0.name == "Boots" }?.condition, "retire", "the label was not turned into its id")
        XCTAssertEqual(lib.items.first { $0.name == "Torch" }?.condition, "worn")
        XCTAssertEqual(lib.items.first { $0.name == "Sit bag" }?.condition, "Sliten", "an unknown condition was changed")
        XCTAssertEqual(lib.repairConditionLabels(), 0, "a second run changed something again")

        // …and with that, everything that reads the id sees it.
        XCTAssertTrue(lib.buySuggestions(today: "2026-10-05").contains { $0.item.name == "Boots" && $0.reason == "Needs replacing" },
                      "the repaired thing is not offered on To buy")
        XCTAssertEqual(lib.usesOf("conditions")[normName("retire")]?.things, 1, "Your choices does not see it in use")
    }

    func testHisOwnConditionIsRepairedByItsOwnLabel() {
        var lib = library()
        _ = lib.setConditions(DEFAULT_ITEM_CONDITIONS + [ItemCondition(id: "patched", label: "Patched up")])
        let n = lib.items.firstIndex { $0.name == "Boots" }!
        lib.items[n].condition = "patched UP "
        lib.items[n] = coerceItem(lib.items[n])
        XCTAssertEqual(lib.repairConditionLabels(), 1)
        XCTAssertEqual(lib.items[n].condition, "patched")
    }

    // MARK: Amounts typed by hand

    func testAnAmountTakesACommaOrAPointAndRefusesWhatIsNotANumber() {
        XCTAssertEqual(readAmount("12,5"), 12.5, "the Swedish comma")
        XCTAssertEqual(readAmount(" 88.7 "), 88.7)
        XCTAssertEqual(readAmount("12."), 12)
        XCTAssertEqual(readAmount(""), 0, "empty is 'not known'")
        XCTAssertEqual(readAmount("   "), 0)
        XCTAssertNil(readAmount("abc"), "a typo became 0")
        XCTAssertNil(readAmount("-3"), "a negative amount")
        XCTAssertNil(readAmount("1e3"))
        XCTAssertNil(readAmount("1.2.3"))
        XCTAssertNil(readAmount("."))
        XCTAssertEqual(amountText(88.7), "88.7", "a decimal weight shown cut down")
        XCTAssertEqual(amountText(88), "88")
        XCTAssertEqual(amountText(12.25), "12.25")
        XCTAssertEqual(amountText(0), "")
    }

    // MARK: Undo after Change all

    func testUndoPutsBackOnlyWhatChangeAllChanged() {
        var lib = library()
        let ids = lib.items.filter { ["Boots", "Torch"].contains($0.name) }.map(\.id)
        let before = lib.items.filter { ids.contains($0.id) }
        for id in ids { _ = lib.updateThing(id: id) { $0.condition = "worn" } }
        let after = lib.items.filter { ids.contains($0.id) }
        // A cell edited afterwards, on one of them…
        _ = lib.updateThing(id: ids[0]) { $0.weight = 950 }
        // …and the changed field itself set again by hand on the other.
        _ = lib.updateThing(id: ids[1]) { $0.condition = "good" }

        XCTAssertEqual(lib.undoChange(before: before, after: after), 1)
        let first = lib.items.first { $0.id == ids[0] }!, second = lib.items.first { $0.id == ids[1] }!
        XCTAssertEqual(first.condition, "", "Undo did not put the condition back")
        XCTAssertEqual(first.weight, 950, "Undo also undid the weight he typed afterwards")
        XCTAssertEqual(second.condition, "good", "Undo overwrote what he set by hand after the change")
    }

    // MARK: The table's memory of templates that are gone

    func testAFilterForADeletedTemplateIsForgotten() {
        var lib = library()
        var swim = newList(name: "Swim")
        swim.items = [newItem(name: "Goggles")]
        lib.saveTemplate(swim)
        let swimId = lib.templates.first { $0.name == "Swim" }!.id
        let filters: ThingFilters = ["list:\(swimId)": [FILTER_ON], "ownedBy": ["kim"], "condition": []]
        XCTAssertEqual(Set(lib.liveFilters(filters).keys), ["list:\(swimId)", "ownedBy"])
        lib.templates.removeAll { $0.id == swimId }
        XCTAssertEqual(Set(lib.liveFilters(filters).keys), ["ownedBy"], "the gone template's filter still filters")
        XCTAssertFalse(lib.tableKnows("section:\(swimId)"), "a gone template's sections still sort")
        XCTAssertTrue(lib.tableKnows("weight"))
        XCTAssertTrue(lib.tableKnows("name"))
    }

    // MARK: Sorting the table as everything else sorts

    func testTheTableSortsAccentedNamesAsYourThingsDoes() {
        var lib = Library()
        for name in ["Zip ties", "Éclair tin", "Apple box", "Öljett", "ägg kopp", "Bag"] { lib.addThing(name: name) }
        let yourThings = lib.thingRows().map(\.item.name)
        XCTAssertEqual(lib.sortThings(lib.items, by: [SortLevel(key: "name")]).map(\.name), yourThings,
                       "the table sorts å, ä, ö and é differently from Your things")
        XCTAssertEqual(lib.sortThings(lib.items, by: [SortLevel(key: "name", descending: true)]).map(\.name),
                       yourThings.reversed())
    }

    // MARK: Care

    func testCareListsAThingOnNoTemplateAndLeavesOutOneNotInUse() {
        var lib = library()
        let loose = lib.addThing(name: "Kayak")!
        let n = lib.items.firstIndex { $0.id == loose.id }!
        lib.items[n].maintenance = Maintenance(notes: "Rinse", intervalDays: 30, lastDone: "2026-08-01")
        let b = lib.items.firstIndex { $0.name == "Boots" }!
        lib.items[b].maintenance = Maintenance(notes: "Wax", intervalDays: 30, lastDone: "2026-08-01")
        lib.items[b].retired = true

        let rows = lib.careRows(today: "2026-10-05")
        XCTAssertEqual(rows.map(\.item.name), ["Kayak"], "a thing on no template is missing, or one not in use is there")
        XCTAssertEqual(rows.first?.item.itemId ?? rows.first?.item.id, loose.id, "Done today would not find the thing")
        XCTAssertEqual(rows.first?.listName, "", "a thing on no template has no template to name")
        let stats = lib.kitStats(today: "2026-10-05")
        XCTAssertEqual(stats.overdue, 1, "the loose kayak is overdue and not counted")
        XCTAssertEqual(lib.careMonth("2026-10", today: "2026-10-05").overdue, 1, "the calendar does not see it")
    }

    func testCareAndTheDashboardSayBagsNeverContainers() {
        var lib = library()
        let bag = lib.bags().first!
        let n = lib.items.firstIndex { $0.id == bag.id }!
        lib.items[n].maintenance = Maintenance(notes: "Reproof", intervalDays: 365, lastDone: "2026-06-01")
        lib.items[n].weight = 700
        XCTAssertEqual(lib.careRows(today: "2026-10-05").first?.listName, "Bags")
        XCTAssertTrue(lib.kitStats(today: "2026-10-05").lists.contains { $0.label == "Bags" })
        XCTAssertFalse(lib.kitStats(today: "2026-10-05").lists.contains { $0.label == CONTAINER_LIST_NAME },
                       "the dashboard says Containers")
    }

    func testTheYearAheadCountsCalendarMonths() {
        var lib = library()
        func care(_ name: String, last: String, every: Int) {
            let n = lib.items.firstIndex { $0.name == name }!
            lib.items[n].maintenance = Maintenance(notes: "x", intervalDays: every, lastDone: last)
        }
        care("Boots", last: "2026-10-03", every: 29)    // due 1 Nov: next month, 27 days away
        care("Torch", last: "2026-09-01", every: 365)   // due 1 Sep 2027: the 12th month counted, Sep 2026 → Aug 2027 is the year
        care("Sit bag", last: "2026-10-01", every: 30)  // due 31 Oct: this month
        let months = lib.kitStats(today: "2026-10-05").dueByMonth
        XCTAssertEqual(months[0], 1, "31 October is this month")
        XCTAssertEqual(months[1], 1, "1 November is next month, though under 30 days away")
        XCTAssertEqual(months[11], 1, "September 2027 is the twelfth month from October 2026")
        XCTAssertEqual(months.reduce(0, +), 3)
        care("Torch", last: "2026-10-05", every: 365)   // due 5 Oct 2027: the thirteenth month — not this year
        XCTAssertEqual(lib.kitStats(today: "2026-10-05").dueByMonth.reduce(0, +), 2,
                       "a service a year away was piled into the last bar")
    }

    // MARK: To do and To buy

    func testALineRemovedComesBackWithUndoAndItsReminderIsNamed() {
        var lib = Library()
        let socks = lib.addToBuyList(text: "Socks")!
        let call = lib.addAction(text: "Call the vet", priority: "high")!
        XCTAssertTrue(lib.markSent(actionId: socks.id, reminderId: "r-1"))
        let gone = lib.removeLine(id: socks.id)
        XCTAssertEqual(gone?.reminderId, "r-1", "the app would not know which reminder to take out")
        XCTAssertFalse(lib.actions.contains { $0.id == socks.id })
        XCTAssertNil(lib.removeLine(id: "nope"))
        XCTAssertTrue(lib.putBackLine(gone!.line))
        XCTAssertEqual(lib.buyList().map(\.text), ["Socks"], "Undo did not bring the line back")
        XCTAssertEqual(lib.buyLinesToSend().map(\.id), [socks.id], "a line brought back still says it is in Reminders")
        XCTAssertFalse(lib.putBackLine(gone!.line), "Undo twice made two lines")
        let removed = lib.removeLine(id: call.id)!
        XCTAssertNil(removed.reminderId)
        lib.putBackLine(removed.line)
        XCTAssertEqual(lib.sortedActions(kind: "todo").first?.priority, "high", "the to-do came back changed")
    }

    func testALineWhoseReminderWasDeletedThereCanBeSentAgain() {
        var lib = Library()
        let socks = lib.addToBuyList(text: "Socks")!
        let tape = lib.addToBuyList(text: "Tape")!
        lib.markSent(actionId: socks.id, reminderId: "r-1")
        lib.markSent(actionId: tape.id, reminderId: "r-2")
        XCTAssertTrue(lib.buyLinesToSend().isEmpty)
        XCTAssertEqual(lib.buyLinesToSend(gone: ["r-2"]).map(\.text), ["Tape"], "a line whose reminder was deleted is stuck as sent")
        XCTAssertEqual(lib.reminderOf(actionId: tape.id), "r-2")
        _ = lib.setActionDone(true, id: tape.id)
        XCTAssertTrue(lib.buyLinesToSend(gone: ["r-2"]).isEmpty, "a bought line is offered for sending")
    }
}
