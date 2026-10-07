import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// His own lists changed from inside a drop-down (0.69, his ask: "work on all the drop-downs
/// so that they can be edited, changed, added, and deleted from within the drop-downs"),
/// held until Save and then written through the lists' own functions. Per list: a rename
/// follows everything that used the old name, a removal is refused while the entry is in
/// use, and the order he gives is kept.
final class ChoiceEditsTests: XCTestCase {
    override func setUp() { PackingEnv.freeze(at: "2026-10-01T12:00:00.000Z") }
    override func tearDown() {
        PackingEnv.reset(); _ = setPhases(DEFAULT_PHASES); _ = setItemConditions(DEFAULT_ITEM_CONDITIONS)
    }

    /// A Backpack (pockets Main, Front pocket) and a Tote; a Charger kept in the Garage,
    /// Kim's, Electronics, usually in the Backpack's front pocket; a Book in the Tote; a
    /// trip under way built from both.
    private func library() -> Library {
        var lib = Library()
        lib.setNames("places", ["Garage", "Hall closet", "Loft"])
        lib.setNames("owners", ["Kim", "Robin"])
        let backpack = lib.addBag(name: "Backpack")!.id
        _ = lib.addBag(name: "Tote")
        _ = lib.addBag(name: "Spare bag")
        for p in ["Main", "Front pocket"] { XCTAssertTrue(lib.addPocket(bagId: backpack, name: p)) }
        lib.saveTemplate(newList(name: "Base", role: "base"))
        let base = lib.templates.first { $0.role == "base" }!.id
        for (name, bag) in [("Charger", "Backpack"), ("Book", "Tote")] {
            let t = lib.addThing(name: name)!
            _ = lib.updateThing(id: t.id) {
                $0.container = bag; $0.storage = "Garage"; $0.ownedBy = "Kim"; $0.category = "Electronics"
                $0.condition = "worn"; $0.phase = "daybefore"
            }
            _ = lib.setOnTemplate(itemId: t.id, templateId: base, on: true)
        }
        XCTAssertTrue(lib.setUsualPocket(thingId: thing(lib, "Charger"), pocket: "Front pocket"))
        _ = lib.createTrip(newEvent(name: "Away", startDate: "2026-10-01", endDate: "2026-10-05", destination: "Seaside"))
        return lib
    }
    private func thing(_ lib: Library, _ name: String) -> String { lib.items.first { $0.name == name }!.id }
    private func item(_ lib: Library, _ name: String) -> Item { lib.items.first { $0.name == name }! }
    private func line(_ lib: Library, _ name: String) -> Item { lib.trips[0].entries.first { $0.name == name }! }
    private func labels(_ lib: Library, _ e: ChoiceEdits) -> [String] { lib.choicesAsEdited(e).map(\.label) }

    // MARK: Kept at home (places)

    func testAPlaceRenamedFromADropDownFollowsEverywhereAndKeepsItsCode() {
        var lib = library()
        let code = lib.placeCode(for: "Garage")!
        var e = ChoiceEdits(kind: "places")
        XCTAssertEqual(lib.choiceNameProblem(e, key: "Garage", name: "loft"), "You already have Loft.")
        XCTAssertEqual(lib.choiceNameProblem(e, key: "Garage", name: " "), "Type a name first.")
        XCTAssertNil(lib.choiceNameProblem(e, key: "Garage", name: "Shed"))
        e.names["Garage"] = "Shed"
        XCTAssertEqual(labels(lib, e), ["Shed", "Hall closet", "Loft"], "the page shows the new name")
        XCTAssertEqual(lib.storagePlaces(), ["Garage", "Hall closet", "Loft"], "nothing changes before Save")
        let map = lib.applyChoiceEdits(e)
        XCTAssertEqual(map["Garage"], "Shed")
        XCTAssertEqual(Library.choiceValue("garage", after: map), "Shed", "the page's own choice follows, whatever its spelling")
        XCTAssertEqual(lib.storagePlaces(), ["Shed", "Hall closet", "Loft"])
        XCTAssertEqual(item(lib, "Charger").storage, "Shed")
        XCTAssertEqual(line(lib, "Charger").storage, "Shed", "a trip line kept the old name")
        XCTAssertEqual(lib.placeCode(for: "Shed"), code, "the place's code changed with its name")
        XCTAssertEqual(lib.place(forCode: code), "Shed")
    }

    func testAPlaceInUseIsNotRemovedAndAnUnusedOneIs() {
        var lib = library()
        let refusal = lib.choiceRemoveProblem("places", key: "Garage", label: "Garage")
        XCTAssertEqual(refusal, "Garage is still used by 2 things, so it stays.")
        // The page's own thing counts by what the page says, not by what it had.
        XCTAssertEqual(lib.choiceRemoveProblem("places", key: "Garage", label: "Garage", except: thing(lib, "Charger")),
                       "Garage is still used by 1 thing, so it stays.")
        XCTAssertNotNil(lib.choiceRemoveProblem("places", key: "Loft", label: "Loft", pageSays: true), "the page's choice did not count")
        XCTAssertNil(lib.choiceRemoveProblem("places", key: "Loft", label: "Loft"))
        var e = ChoiceEdits(kind: "places")
        e.removed = ["Loft", "Garage"]
        XCTAssertEqual(lib.choicesAsEdited(e).filter(\.removed).map(\.key), ["Garage", "Loft"], "struck out until Save")
        lib.applyChoiceEdits(e)
        lib.applyChoiceRemovals(e)
        XCTAssertEqual(lib.storagePlaces(), ["Garage", "Hall closet"], "the place in use went, or the unused one stayed")
    }

    func testPlacesKeepTheOrderGivenAndANewOneIsMadeOnSave() {
        var lib = library()
        var e = ChoiceEdits(kind: "places")
        e.added = ["Workbench"]
        e.order = ["Loft", ChoiceEdits.addedKey(0), "Garage", "Hall closet"]
        XCTAssertEqual(labels(lib, e), ["Loft", "Workbench", "Garage", "Hall closet"])
        XCTAssertEqual(lib.storagePlaces().count, 3, "added before Save")
        let map = lib.applyChoiceEdits(e)
        XCTAssertEqual(map[ChoiceEdits.addedKey(0)], "Workbench")
        XCTAssertEqual(lib.storagePlaces(), ["Loft", "Workbench", "Garage", "Hall closet"])
    }

    func testAnAddedEntryCanBeRenamedOrTakenBackBeforeSave() {
        var lib = library()
        var e = ChoiceEdits(kind: "places")
        e.added = ["Workbnch", "Cellar"]
        e.names[ChoiceEdits.addedKey(0)] = "Workbench"
        e.removed = [ChoiceEdits.addedKey(1)]
        XCTAssertEqual(labels(lib, e).suffix(2), ["Workbench", "Cellar"])
        XCTAssertEqual(lib.choiceNameProblem(e, key: ChoiceEdits.addedKey(1), name: "workbench"), "You already have Workbench.")
        let map = lib.applyChoiceEdits(e)
        lib.applyChoiceRemovals(e, renamed: map)
        XCTAssertEqual(map[ChoiceEdits.addedKey(0)], "Workbench")
        XCTAssertEqual(lib.storagePlaces(), ["Garage", "Hall closet", "Loft", "Workbench"], "a taken-back entry was made")
    }

    func testTwoPlacesThatSwapNamesBothGetTheirs() {
        var lib = library()
        var e = ChoiceEdits(kind: "places")
        e.names = ["Garage": "Loft", "Loft": "Garage"]
        XCTAssertNil(lib.choiceNameProblem(ChoiceEdits(kind: "places"), key: "Loft", name: "Shed"))
        lib.applyChoiceEdits(e)
        XCTAssertEqual(lib.storagePlaces(), ["Loft", "Hall closet", "Garage"])
        XCTAssertEqual(item(lib, "Charger").storage, "Loft", "the Garage's things did not follow it to its new name")
    }

    // MARK: Whose it is (owners)

    func testAnOwnerRenamedFollowsAndThisIsMeFollowsAndOwnersStayAToZ() {
        var lib = library()
        XCTAssertTrue(lib.setMe("Kim"))
        XCTAssertFalse(Library.choiceOrders("owners"), "owners have an order of their own")
        var e = ChoiceEdits(kind: "owners")
        e.names["Kim"] = "Alex"
        lib.applyChoiceEdits(e)
        XCTAssertEqual(lib.owners(), ["Alex", "Robin"], "A–Z")
        XCTAssertEqual(item(lib, "Book").ownedBy, "Alex")
        XCTAssertEqual(lib.me(), "Alex", "This is me did not follow the rename")
        XCTAssertEqual(lib.choiceRemoveProblem("owners", key: "Alex", label: "Alex"), "Alex is still used by 2 things, so it stays.")
        XCTAssertNil(lib.removeChoice("owners", key: "Robin"))
        XCTAssertEqual(lib.owners(), ["Alex"])
    }

    // MARK: Kind of thing (categories)

    func testAKindOfThingIsRenamedMovedAddedAndKeptWithTheLibrary() {
        var lib = library()
        XCTAssertEqual(lib.categories(), CATEGORIES)
        var e = ChoiceEdits(kind: "categories")
        e.names["Electronics"] = "Gadgets"
        e.added = ["Camping"]
        e.order = [ChoiceEdits.addedKey(0)] + CATEGORIES
        let map = lib.applyChoiceEdits(e)
        XCTAssertEqual(map["Electronics"], "Gadgets")
        XCTAssertEqual(lib.categories().first, "Camping")
        XCTAssertTrue(lib.categories().contains("Gadgets") && !lib.categories().contains("Electronics"))
        XCTAssertEqual(item(lib, "Charger").category, "Gadgets", "a thing kept the old kind")
        XCTAssertEqual(line(lib, "Charger").category, "Gadgets", "a trip line kept the old kind")
        // Synced: a record of its own.
        XCTAssertEqual(Library(records: lib.records()).categories(), lib.categories())
        // …and in a backup.
        XCTAssertEqual(Importer.library(from: lib.backupFile(exportedAt: "2026-10-01T12:00:00.000Z")).0.categories(), lib.categories())
        // In use, it stays; unused, it goes; the list back as shipped stores nothing.
        XCTAssertEqual(lib.removeChoice("categories", key: "Gadgets"), "Gadgets is still used by 2 things, so it stays.")
        XCTAssertNil(lib.removeChoice("categories", key: "Camping"))
        XCTAssertTrue(lib.moveChoice("categories", key: "Clothing", by: 1))
        XCTAssertTrue(lib.moveChoice("categories", key: "Clothing", by: -1))
        var back = ChoiceEdits(kind: "categories")
        back.names["Gadgets"] = "Electronics"
        lib.applyChoiceEdits(back)
        XCTAssertNil(lib.meta[Library.categoriesKey], "the list as shipped is still stored")
    }

    func testTheKindsTheAppReadsKeepTheirNames() {
        var lib = library()
        let e = ChoiceEdits(kind: "categories")
        XCTAssertNotNil(lib.choiceFixed("categories", DOCUMENTS_CATEGORY))
        XCTAssertNotNil(lib.choiceFixed("categories", REMINDERS_CATEGORY))
        XCTAssertNil(lib.choiceFixed("categories", "Clothing"))
        XCTAssertNotNil(lib.choiceNameProblem(e, key: DOCUMENTS_CATEGORY, name: "Papers"))
        XCTAssertNotNil(lib.renameChoice("categories", key: REMINDERS_CATEGORY, to: "Notes"))
        XCTAssertNotNil(lib.removeChoice("categories", key: DOCUMENTS_CATEGORY))
        XCTAssertEqual(lib.categories(), CATEGORIES)
    }

    // MARK: When (steps) and Condition

    func testAStepIsRenamedByItsIdAndOneInUseOnATripStays() {
        var lib = library()
        var e = ChoiceEdits(kind: "phases")
        e.names["daybefore"] = "The evening before"
        e.added = ["At the door"]
        let map = lib.applyChoiceEdits(e)
        XCTAssertNil(map["daybefore"], "an id does not change")
        let made = map[ChoiceEdits.addedKey(0)]!
        XCTAssertEqual(lib.timeline().last?.id, made)
        XCTAssertEqual(lib.timeline().first { $0.id == "daybefore" }?.label, "The evening before")
        XCTAssertEqual(item(lib, "Charger").phase, "daybefore")
        let refusal = lib.choiceRemoveProblem("phases", key: "daybefore", label: "The evening before", except: thing(lib, "Charger"))
        XCTAssertEqual(refusal, "The evening before is still used by 1 thing and on 1 trip, so it stays.")
        XCTAssertNil(lib.removeChoice("phases", key: made))
        XCTAssertFalse(lib.timeline().contains { $0.id == made })
        XCTAssertTrue(lib.moveChoice("phases", key: "daybefore", by: -1))
    }

    func testAConditionIsRenamedAddedAndRefusedWhileInUse() {
        var lib = library()
        var e = ChoiceEdits(kind: "conditions")
        e.names["worn"] = "Well used"
        e.added = ["Lent out"]
        let map = lib.applyChoiceEdits(e)
        XCTAssertEqual(lib.conditions().first { $0.id == "worn" }?.label, "Well used")
        XCTAssertEqual(lib.conditions().last?.id, map[ChoiceEdits.addedKey(0)])
        XCTAssertEqual(lib.removeChoice("conditions", key: "worn"), "Well used is still used by 2 things, so it stays.")
    }

    // MARK: Usually packed in (bags) and pockets

    func testABagRenamedFromADropDownCarriesItsThingsAndPockets() {
        var lib = library()
        var e = ChoiceEdits(kind: "bags")
        XCTAssertEqual(lib.choiceNameProblem(e, key: "Backpack", name: "Book"), "You already have something called Book.")
        e.names["Backpack"] = "Rucksack"
        let map = lib.applyChoiceEdits(e)
        XCTAssertEqual(map["Backpack"], "Rucksack")
        XCTAssertEqual(item(lib, "Charger").container, "Rucksack")
        XCTAssertEqual(line(lib, "Charger").container, "Rucksack")
        XCTAssertEqual(lib.pockets(bag: "Rucksack"), ["Main", "Front pocket"], "the pockets did not go with the bag")
        XCTAssertEqual(Library.usualPocket(item(lib, "Charger")), "Front pocket")
    }

    func testABagInUseOrPackedOnATemplateIsLeftToItsPage() {
        var lib = library()
        let refusal = lib.choiceRemoveProblem("bags", key: "Tote", label: "Tote")!
        XCTAssertTrue(refusal.hasPrefix("Tote is still used by 1 thing"), refusal)
        XCTAssertTrue(refusal.hasSuffix("Its page asks where they go instead."), refusal)
        // Also on a template as a thing he packs: its page asks.
        let base = lib.templates.first { $0.role == "base" }!.id
        _ = lib.setOnTemplate(itemId: thing(lib, "Spare bag"), templateId: base, on: true)
        XCTAssertNotNil(lib.choiceRemoveProblem("bags", key: "Spare bag", label: "Spare bag"))
        _ = lib.setOnTemplate(itemId: thing(lib, "Spare bag"), templateId: base, on: false)
        XCTAssertNil(lib.removeChoice("bags", key: "Spare bag"))
        XCTAssertEqual(lib.choiceRows("bags").map(\.key), ["Backpack", "Tote"])
    }

    func testBagsKeepTheOrderGivenAndANewBagIsMadeOnSave() {
        var lib = library()
        var e = ChoiceEdits(kind: "bags")
        e.added = ["Duffel"]
        e.order = ["Tote", ChoiceEdits.addedKey(0), "Backpack", "Spare bag"]
        let map = lib.applyChoiceEdits(e)
        XCTAssertEqual(map[ChoiceEdits.addedKey(0)], "Duffel")
        XCTAssertEqual(lib.bagNames(), ["Tote", "Duffel", "Backpack", "Spare bag"])
    }

    func testAPocketRenamedFollowsAndOneInUseStays() {
        var lib = library()
        var e = ChoiceEdits(kind: "pockets", bag: "Backpack")
        e.names["Front pocket"] = "Outer pocket"
        e.order = ["Front pocket", "Main"]
        let map = lib.applyChoiceEdits(e)
        XCTAssertEqual(Library.choiceValue("Front pocket", after: map), "Outer pocket")
        XCTAssertEqual(lib.pockets(bag: "Backpack"), ["Outer pocket", "Main"])
        XCTAssertEqual(Library.usualPocket(item(lib, "Charger")), "Outer pocket")
        XCTAssertEqual(lib.removeChoice("pockets", key: "Outer pocket", bag: "Backpack"),
                       "Outer pocket is still used by 1 thing, so it stays.")
        XCTAssertNil(lib.removeChoice("pockets", key: "Main", bag: "Backpack"))
        XCTAssertEqual(lib.pockets(bag: "Backpack"), ["Outer pocket"])
    }
}
