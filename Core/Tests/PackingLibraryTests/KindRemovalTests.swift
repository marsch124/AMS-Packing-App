import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// A kind of thing removed while things still have it (0.107 — his words, 30 Oct 2026: "I need the ability to delete
/// a Kind of thing, even if there are items that are connected to this very Kind of thing choice. Example: I don't
/// understand why I defined Reminders. I want them gone"). Your choices asks where its things go; on Done every thing
/// and every trip line of that kind takes the kind chosen, in one change that syncs, backs up and is undone whole.
/// Invented data only — this repository is public.
final class KindRemovalTests: XCTestCase {
    override func setUp() { PackingEnv.freeze(at: "2026-10-13T12:00:00.000Z") }
    override func tearDown() { PackingEnv.reset() }

    /// His kinds: the app's twelve and Other. On the base template a Charger and a Lamp (Electronics), a Jacket
    /// (Clothing) and the reminder "Fill the flask" (Reminders); the trip "Lake week" (20–24 Oct) from it.
    private func library() -> (Library, base: String, trip: String) {
        var lib = Library()
        lib.saveTemplate(newList(name: "Base", role: "base"))
        let base = lib.templates.first { $0.role == "base" }!.id
        lib.setCategories(CATEGORIES + ["Other"])
        for (name, kind) in [("Charger", "Electronics"), ("Lamp", "electronics "), ("Jacket", "Clothing")] {
            let t = lib.addThing(name: name)!
            _ = lib.updateThing(id: t.id) { $0.category = kind }
            _ = lib.setOnTemplate(itemId: t.id, templateId: base, on: true)
        }
        XCTAssertNotNil(lib.addReminder(templateId: base, name: "Fill the flask", when: "daybefore"))
        let trip = lib.createTrip(newEvent(name: "Lake week", startDate: "2026-10-20", endDate: "2026-10-24")).id
        return (lib, base, trip)
    }
    private func item(_ lib: Library, _ name: String) -> Item { lib.items.first { $0.name == name }! }
    private func line(_ lib: Library, _ name: String) -> Item? { lib.trips.first?.entries.first { $0.name == name } }

    func testAKindInUseIsRemovedAndEveryThingAndLineMovesToTheKindChosen() {
        var (lib, _, _) = library()
        XCTAssertEqual(lib.kindUse("Electronics"), KindUse(things: 2, reminders: 0), "any spelling of it is the kind")
        XCTAssertNil(lib.removeKind("Electronics", moveTo: "Charging"))
        XCTAssertFalse(lib.categories().contains("Electronics"), "the kind is still on his list")
        XCTAssertEqual(lib.categories(), CATEGORIES.filter { $0 != "Electronics" } + ["Other"], "the other kinds moved")
        XCTAssertEqual(item(lib, "Charger").category, "Charging")
        XCTAssertEqual(item(lib, "Lamp").category, "Charging", "a thing that spelt it otherwise kept it")
        XCTAssertEqual(item(lib, "Jacket").category, "Clothing", "a thing of another kind moved")
        XCTAssertEqual(line(lib, "Charger")?.category, "Charging", "a trip line kept the removed kind")
        XCTAssertEqual(line(lib, "Jacket")?.category, "Clothing")
        XCTAssertEqual(lib.kindUse("Electronics"), KindUse())
        // Synced as records, and in a backup.
        let synced = Library(records: lib.records())
        XCTAssertEqual(synced.categories(), lib.categories())
        XCTAssertEqual(synced.items.first { $0.name == "Lamp" }?.category, "Charging")
        let restored = Importer.library(from: lib.backupFile(exportedAt: "2026-10-13T12:00:00.000Z")).0
        XCTAssertEqual(restored.categories(), lib.categories())
        XCTAssertEqual(restored.items.first { $0.name == "Charger" }?.category, "Charging")
    }

    func testWhereTheThingsGoUnlessHeSaysOtherwise() {
        var (lib, _, _) = library()
        XCTAssertEqual(lib.fallbackKind(without: "Electronics"), "Other", "his Other first")
        XCTAssertEqual(lib.fallbackKind(without: "Other"), CATEGORY_DEFAULT, "then the app's own catch-all")
        lib.setCategories(["Gear", "Clothes", "Other"])
        XCTAssertEqual(lib.fallbackKind(without: "other"), "Gear", "then the first of his kinds")
        XCTAssertEqual(lib.fallbackKind(without: "Gear"), "Other")
        // A target that is none of his kinds — or the kind itself — is not taken: the things go where they would.
        var (other, _, _) = library()
        XCTAssertNil(other.removeKind("Electronics", moveTo: "Nonsense"))
        XCTAssertEqual(item(other, "Charger").category, "Other")
        var (same, _, _) = library()
        XCTAssertNil(same.removeKind("Electronics", moveTo: "electronics"))
        XCTAssertEqual(item(same, "Lamp").category, "Other")
        // The target as his list spells it.
        var (spelt, _, _) = library()
        XCTAssertNil(spelt.removeKind("Electronics", moveTo: " charging"))
        XCTAssertEqual(item(spelt, "Charger").category, "Charging")
    }

    func testRemindersGoesAndItsRemindersStayReminders() {
        var (lib, base, trip) = library()
        XCTAssertEqual(lib.kindUse(REMINDERS_CATEGORY), KindUse(things: 0, reminders: 1))
        XCTAssertNil(lib.kindRemoveProblem(REMINDERS_CATEGORY), "Reminders cannot be removed")
        XCTAssertNil(lib.removeKind(REMINDERS_CATEGORY, moveTo: "Other"))
        XCTAssertFalse(lib.categories().contains(REMINDERS_CATEGORY))
        let flask = item(lib, "Fill the flask")
        XCTAssertEqual(flask.category, "Other")
        XCTAssertTrue(Library.isReminder(flask), "the reminder is no reminder now")
        XCTAssertEqual(lib.reminders(templateId: base).map(\.name), ["Fill the flask"], "the template lost its reminder")
        XCTAssertFalse(lib.ownThings().contains { $0.id == flask.id }, "the reminder shows among his things")
        XCTAssertEqual(line(lib, "Fill the flask")?.category, "Other")
        XCTAssertTrue(line(lib, "Fill the flask").map(Library.isReminder) ?? false, "the trip's reminder is no reminder now")
        XCTAssertEqual(lib.dueReminders(tripId: trip, today: "2026-10-19").map(\.name), ["Fill the flask"], "the reminder is not due the day before")
        // Not brought back: the next reminder is Other.
        _ = lib.addReminder(templateId: base, name: "Wax the skis")
        XCTAssertEqual(item(lib, "Wax the skis").category, "Other")
        XCTAssertFalse(lib.categories().contains(REMINDERS_CATEGORY))
        // It keeps its name while he has it.
        var (kept, _, _) = library()
        XCTAssertNotNil(kept.renameChoice("categories", key: REMINDERS_CATEGORY, to: "To-dos"))
    }

    func testDocumentsAndMoneyAndTheLastKindStay() {
        var (lib, _, _) = library()
        XCTAssertEqual(lib.kindRemoveProblem(DOCUMENTS_CATEGORY), "Documents & money is read by Before you go, so it stays.")
        XCTAssertEqual(lib.removeKind(DOCUMENTS_CATEGORY, moveTo: "Other"), "Documents & money is read by Before you go, so it stays.")
        XCTAssertTrue(lib.categories().contains(DOCUMENTS_CATEGORY))
        lib.setCategories(["Gear"])
        XCTAssertEqual(lib.removeKind("Gear", moveTo: ""), "Gear is your only kind of thing, so it stays.")
        XCTAssertEqual(lib.categories(), ["Gear"])
    }

    func testAnUnusedKindGoesAndNothingElseChanges() {
        var (lib, _, _) = library()
        let before = lib
        XCTAssertEqual(lib.kindUse("Footwear"), KindUse())
        XCTAssertNil(lib.removeKind("Footwear", moveTo: ""))
        XCTAssertFalse(lib.categories().contains("Footwear"))
        XCTAssertEqual(lib.items, before.items, "a thing changed for a kind nobody had")
        XCTAssertEqual(lib.trips, before.trips)
    }

    func testTheCardSaysHowManyAndWhere() {
        XCTAssertEqual(KindUse(things: 10).says, "10 things have this kind.")
        XCTAssertEqual(KindUse(things: 1).says, "1 thing has this kind.")
        XCTAssertEqual(KindUse(reminders: 2).says, "2 reminders have this kind.")
        XCTAssertEqual(KindUse(reminders: 1).says, "1 reminder has this kind.")
        XCTAssertEqual(KindUse(things: 3, reminders: 1).says, "3 things and 1 reminder have this kind.")
        XCTAssertEqual(KindUse(things: 3).moveTo, "Move them to")
        XCTAssertEqual(KindUse(reminders: 1).moveTo, "Move it to")
        XCTAssertTrue(KindUse(things: 1).inUse)
        XCTAssertFalse(KindUse().inUse)
    }

    func testTheDropDownSaysWhereAKindInUseCanBeRemoved() {
        var (lib, _, _) = library()
        XCTAssertEqual(lib.removeChoice("categories", key: "Clothing"),
                       "Clothing is still used by 1 thing. Your choices in Settings removes it and moves its things to another kind.")
        XCTAssertTrue(lib.categories().contains("Clothing"), "the drop-down took it away")
        XCTAssertEqual(lib.removeChoice("places", key: "Garage"), nil, "another list's words changed")
    }

    /// A thing's Kind of thing holds the removal (0.107, his second screenshot): `ChoiceEdits.moves`, written on Save
    /// AFTER the thing — every thing and trip line of the kind take the kind chosen, one renamed or made on the same page
    /// included. Put back drops the move; a removal with no move is still refused while in use (the other device's
    /// use). Documents & money has no tools in the list; Reminders has them, its pen still refused.
    func testAThingsKindOfThingHoldsTheRemovalUntilSave() {
        var (lib, _, _) = library()
        XCTAssertTrue(lib.choiceLocked("categories", DOCUMENTS_CATEGORY))
        XCTAssertFalse(lib.choiceLocked("categories", REMINDERS_CATEGORY), "Reminders still has no tools")
        XCTAssertFalse(lib.choiceLocked("places", DOCUMENTS_CATEGORY))
        var e = ChoiceEdits(kind: "categories")
        XCTAssertNotNil(lib.choiceNameProblem(e, key: REMINDERS_CATEGORY, name: "To-dos"), "Reminders' pen renames it")
        XCTAssertEqual(lib.choiceRemoveProblem("categories", key: DOCUMENTS_CATEGORY, label: DOCUMENTS_CATEGORY),
                       "Documents & money is read by Before you go, so it stays.")
        XCTAssertNil(lib.choiceRemoveProblem("categories", key: "Footwear", label: "Footwear"))
        let charger = item(lib, "Charger").id
        XCTAssertEqual(lib.kindUse("Electronics", except: charger), KindUse(things: 1), "the page's own thing is counted")
        // Electronics to a kind renamed on the same page; Reminders to one made on it.
        e.names["Charging"] = "Power"
        e.added = ["Gadgets"]
        e.removed = ["Electronics", REMINDERS_CATEGORY]
        e.moves = ["Electronics": "Charging", REMINDERS_CATEGORY: ChoiceEdits.addedKey(0)]
        var onlyMove = ChoiceEdits(kind: "categories")
        onlyMove.moves = ["Electronics": "Charging"]
        XCTAssertFalse(onlyMove.isEmpty, "a held move is no change")
        // The page's Save: `applyPageChoices` (the app) writes each list by `applyChoiceEdits`, the thing, then the
        // removals by `applyChoiceRemovals`.
        let map = lib.applyChoiceEdits(e)
        XCTAssertEqual(item(lib, "Charger").category, "Electronics", "moved before the page's thing was written")
        lib.applyChoiceRemovals(e, renamed: map)
        XCTAssertEqual(item(lib, "Charger").category, "Power")
        XCTAssertEqual(item(lib, "Lamp").category, "Power")
        XCTAssertEqual(line(lib, "Charger")?.category, "Power")
        XCTAssertEqual(item(lib, "Fill the flask").category, "Gadgets")
        XCTAssertTrue(Library.isReminder(item(lib, "Fill the flask")), "the reminder is no reminder now")
        XCTAssertFalse(lib.categories().contains("Electronics"))
        XCTAssertFalse(lib.categories().contains(REMINDERS_CATEGORY))
        XCTAssertTrue(lib.categories().contains("Power") && lib.categories().contains("Gadgets"))
        // No move held (Put back drops it): a kind still in use stays, as before.
        var (other, _, _) = library()
        var plain = ChoiceEdits(kind: "categories")
        plain.removed = ["Clothing"]
        other.applyChoiceRemovals(plain, renamed: other.applyChoiceEdits(plain))
        XCTAssertTrue(other.categories().contains("Clothing"), "a kind in use went without a move")
        XCTAssertEqual(item(other, "Jacket").category, "Clothing")
        // The fallback as a page shows the list.
        XCTAssertEqual(Library.fallbackKindIndex(["Gear", "comfort & misc", "OTHER"]), 2)
        XCTAssertEqual(Library.fallbackKindIndex(["Gear", "Comfort & misc"]), 1)
        XCTAssertEqual(Library.fallbackKindIndex(["Gear"]), 0)
        XCTAssertNil(Library.fallbackKindIndex([]))
    }

    /// Your choices works on a copy (`PageDraft`): Done hands over what the page changed — the kind and its things
    /// — and keeps what the other device changed meanwhile.
    func testRemovedOnThePageItIsHandedOverByDoneWithTheOtherDevicesChange() {
        let (opened, _, _) = library()
        var page = opened
        XCTAssertNil(page.removeKind("Electronics", moveTo: "Charging"))
        var live = opened
        let jacket = item(live, "Jacket").id
        _ = live.updateThing(id: jacket) { $0.note = "Wash cold" }               // the other device, meanwhile
        let after = live.applyingPage(from: opened, to: page)
        XCTAssertEqual(after.categories(), page.categories())
        XCTAssertEqual(item(after, "Charger").category, "Charging")
        XCTAssertEqual(item(after, "Lamp").category, "Charging")
        XCTAssertEqual(line(after, "Charger")?.category, "Charging")
        XCTAssertEqual(item(after, "Jacket").note, "Wash cold", "Done undid the other device's change")
        XCTAssertEqual(opened.crossings(opened: opened, page: page), [], "nothing crossed, nothing to ask")
    }

    /// Done is ONE step (`change(named: "Change Your Choices")`): undo takes the kind back in its place, with its
    /// things and its trip lines; redo removes it again.
    func testTheRemovalIsOneStepThatUndoTakesBackWhole() {
        let (lib, _, _) = library()
        var book = UndoBook()
        let old = lib.records()
        var next = lib
        XCTAssertNil(next.removeKind("Electronics", moveTo: "Charging"))
        book.record(name: "Change Your Choices", from: old, to: next.records(), library: next)
        guard let r = book.undoing(next) else { return XCTFail("nothing to undo") }
        book.undone(r)
        XCTAssertEqual(r.library.categories(), lib.categories(), "the kind is not back in its place")
        XCTAssertEqual(item(r.library, "Charger").category, "Electronics")
        XCTAssertEqual(item(r.library, "Lamp").category, "electronics ", "the thing's own spelling is not back")
        XCTAssertEqual(line(r.library, "Charger")?.category, "Electronics", "the trip line is not back")
        XCTAssertNil(UndoBook.note(r, otherDevice: "your iPhone"), "a whole undo said it was partly undone")
        guard let again = book.redoing(r.library) else { return XCTFail("nothing to redo") }
        XCTAssertFalse(again.library.categories().contains("Electronics"))
        XCTAssertEqual(item(again.library, "Charger").category, "Charging")
    }
}
