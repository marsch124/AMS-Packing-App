import XCTest
import PackingCore
@testable import PackingLibrary

final class SettingsListsTests: XCTestCase {
    override func setUp() { PackingEnv.freeze() }
    override func tearDown() {
        PackingEnv.reset(); _ = setPhases(DEFAULT_PHASES); _ = setItemConditions(DEFAULT_ITEM_CONDITIONS)
    }

    func testAListWithNoRowsIsTheFactoryOneAndHisOwnIsStored() {
        var lib = Library()
        XCTAssertEqual(lib.storagePlaces(), DEFAULT_STORAGE_LOCATIONS)
        XCTAssertEqual(lib.people().map(\.name), ["Kim", "Robin"])
        // INVENTED starters — the practice library's two — never anyone's real household:
        // the repository is public (the spec pass, 5 Oct 2026).
        XCTAssertEqual(DEFAULT_PEOPLE.map(\.name), ["Kim", "Robin"])
        XCTAssertEqual(lib.conditions(), DEFAULT_ITEM_CONDITIONS)
        XCTAssertEqual(lib.timeline(), DEFAULT_PHASES)
        XCTAssertEqual(lib.records().filter { $0.table == .shared }.count, 0, "nothing factory-made is ever stored")

        XCTAssertTrue(lib.setNames("places", [" Garage shelf ", "Loft", ""]))
        XCTAssertEqual(lib.storagePlaces(), ["Garage shelf", "Loft"])
        XCTAssertEqual(lib.records().filter { $0.table == .shared }.map(\.key).sorted(), ["places:garage shelf", "places:loft"],
                       "one record per entry — that is what makes them merge between devices")
        XCTAssertTrue(lib.setNames("owners", ["Robin", "Jonas"]))
        XCTAssertEqual(lib.owners(), ["Jonas", "Robin"], "A–Z")
        XCTAssertFalse(lib.setNames("people", ["nope"]), "people are not a name-only list")
    }

    /// His screenshot (2026-09-26): "Whose it is" showed one name once for every
    /// thing he owns. Each owner once — his list first, then anyone a thing names
    /// who is not on the list — however many things share them.
    func testEachOwnerIsOfferedOnce() {
        var lib = Library()
        lib.setNames("owners", ["Kim", "Jonas"])
        for n in 0..<40 {
            var it = newItem(name: "Thing \(n)")
            it.ownedBy = n % 3 == 0 ? "Jonas" : (n % 3 == 1 ? " kim " : "Robin")
            lib.items.append(it)
        }
        XCTAssertEqual(lib.ownerChoices(), ["Jonas", "Kim", "Robin"],
                       "each owner once: the list's own A–Z, then one not on the list")
        XCTAssertEqual(Library().ownerChoices(), [], "nobody named anywhere, nothing offered")
    }

    func testPuttingTheFactoryListBackRemovesItsRows() {
        var lib = Library()
        lib.setNames("places", ["Garage shelf"])
        XCTAssertEqual(lib.records().filter { $0.table == .shared }.count, 1)
        lib.setNames("places", DEFAULT_STORAGE_LOCATIONS)
        XCTAssertEqual(lib.records().filter { $0.table == .shared }.count, 0, "back to factory = no rows, not a copy of the defaults")
        XCTAssertEqual(lib.storagePlaces(), DEFAULT_STORAGE_LOCATIONS)
    }

    func testHisOwnTimelineIsStoredAndTheLiveStepsFollow() {
        var lib = Library()
        var own = DEFAULT_PHASES
        own.append(newPhase("Load the van", own.map(\.id)))
        XCTAssertTrue(lib.setTimeline(own))
        XCTAssertEqual(lib.timeline().count, 8)
        XCTAssertEqual(PHASES.count, 8, "the live steps follow, because every item points into this list")
        XCTAssertEqual(lib.records().filter { $0.table == .phases }.count, 8)
        lib.setTimeline(DEFAULT_PHASES)
        XCTAssertEqual(lib.records().filter { $0.table == .phases }.count, 0, "the factory timeline is not data")
        XCTAssertEqual(lib.timeline(), DEFAULT_PHASES)
    }

    func testWhatIsInUseIsCounted() {
        var lib = LibraryTests.sample()
        lib.updateThing(id: lib.items[0].id) { $0.storage = "Garage shelf"; $0.ownedBy = "Robin" }
        XCTAssertEqual(lib.usesOf("places")["garage shelf"], ChoiceUse(things: 1))
        XCTAssertEqual(lib.usesOf("owners")["robin"], ChoiceUse(things: 1))
        // A step's number is its THINGS; its trips and templates are counted apart.
        let week = lib.usesOf("phases")["week"]
        XCTAssertEqual(week?.things, lib.items.filter { $0.phase == "week" }.count, "trip lines are not things")
        XCTAssertEqual(week?.trips, 1, "the one trip has lines in it")
        XCTAssertNil(lib.usesOf("places")["loft"])
    }

    /// The spec pass (5 Oct 2026): "used by N things" counted every trip line and every
    /// template place of a "When" step as a thing — one step in use on a long trip said
    /// "used by 60 things" with six things on it. Things alone are the number; the trips
    /// and templates that still hold it are said in their own words.
    func testAStepsNumberIsItsThingsAndTheRefusalSaysWhatElseHoldsIt() {
        var lib = Library()
        lib.items = [newItem(name: "Keys", phase: "door")]
        var trip = newEvent(name: "Away")
        trip.entries = (0..<5).map { newItem(name: "Line \($0)", phase: "door") }
        lib.trips = [trip]
        let t = newList(name: "Car")
        lib.templates = [t]
        lib.memberships = [newMembership(itemId: "x", templateId: t.id, phase: "door"),
                           newMembership(itemId: "y", templateId: t.id, phase: "door")]
        let door = lib.usesOf("phases")["door"]
        XCTAssertEqual(door, ChoiceUse(things: 1, trips: 1, templates: 1),
                       "one thing; five lines are ONE trip; two places are ONE template")
        XCTAssertEqual(door?.refusal("At the front door"),
                       "At the front door is still used by 1 thing, on 1 trip and on 1 template, so it stays.")
        XCTAssertEqual(ChoiceUse(things: 3).refusal("Garage"), "Garage is still used by 3 things, so it stays.")
        XCTAssertEqual(ChoiceUse(trips: 2).refusal("Morning list"), "Morning list is still used on 2 trips, so it stays.")
        XCTAssertEqual(ChoiceUse(things: 2, templates: 3).refusal("Wear"), "Wear is still used by 2 things and on 3 templates, so it stays.")
        XCTAssertFalse(ChoiceUse().inUse)
        XCTAssertTrue(ChoiceUse(templates: 1).inUse, "a template place alone keeps a step")
    }

    /// The spec pass (5 Oct 2026): a place, owner or packer he already had was dropped
    /// without a word, and a condition or step with a name he had was added twice. Both
    /// now say "You already have …", which needs the entry it would repeat.
    func testADuplicateIsFoundTheWayTheListWouldSeeIt() {
        var lib = Library()
        lib.setNames("owners", ["Kim", "Jonas"])
        XCTAssertEqual(lib.existingChoice("places", "  garage "), "Garage")
        XCTAssertEqual(lib.existingChoice("owners", "KIM"), "Kim")
        XCTAssertEqual(lib.existingChoice("people", "robin"), "Robin")
        XCTAssertEqual(lib.existingChoice("conditions", "good"), "Good", "a condition by its words, not its id")
        XCTAssertEqual(lib.existingChoice("phases", "morning   LIST"), "Morning list")
        XCTAssertNil(lib.existingChoice("places", "Garage shelf"))
        XCTAssertNil(lib.existingChoice("phases", "Load the van"))
        XCTAssertNil(lib.existingChoice("places", ""))
        XCTAssertNil(lib.existingChoice("places", "garage", except: "Garage"), "an entry may keep its own name")
        XCTAssertNil(lib.existingChoice("conditions", "GOOD", except: "good"))
    }

    /// The spec pass (5 Oct 2026): a place is stored under its normalised name cut to
    /// 60 — two long names alike that far became two records under ONE key, and the next
    /// load kept only one of them. Now they are one name from the start.
    func testTwoLongNamesTheStoreCannotTellApartAreOneName() {
        var lib = Library()
        let base = "Shelf above the workbench in the far corner of the double garage"   // 63 letters
        let a = base + " (left)", b = base + " (right)"
        XCTAssertEqual(Library.choiceKey(a), Library.choiceKey(b), "alike in the first 60")
        lib.setNames("places", [a, b])
        XCTAssertEqual(lib.storagePlaces(), [a], "the first spelling wins; the second is the same place to the store")
        let ids = lib.records().filter { $0.table == .shared }.map(\.key)
        XCTAssertEqual(ids.count, Set(ids).count, "no two records under one key: \(ids)")
        XCTAssertEqual(lib.existingChoice("places", b), a, "so adding the second says he already has it")
        // Packers the same way.
        lib.setPeople([newPerson(name: a), newPerson(name: b)])
        XCTAssertEqual(lib.people().map(\.name), [a])
    }

    // MARK: - Renaming and moving (the spec pass, 5 Oct 2026: "can only add and remove")

    func testRenamingAPlaceCarriesItToEveryThingAndTripLine() {
        var lib = Library()
        lib.items = [newItem(name: "Headlamp", storage: "Garage"), newItem(name: "Saw", storage: " garage "),
                     newItem(name: "Tent", storage: "Loft / attic")]
        var trip = newEvent(name: "Away")
        trip.entries = [newItem(name: "Headlamp", storage: "Garage"), newItem(name: "Tent", storage: "Loft / attic")]
        lib.trips = [trip]
        lib.templates = [newList(name: "Camping")]
        let before = (items: lib.items.count, lines: lib.trips[0].entries.count, templates: lib.templates.count)
        let at = lib.storagePlaces().firstIndex(of: "Garage")

        XCTAssertNil(lib.renameChoice("places", key: "Garage", to: "  Garage shelf "))
        XCTAssertEqual(lib.storagePlaces().firstIndex(of: "Garage shelf"), at, "in the same place in the list")
        XCTAssertFalse(lib.storagePlaces().contains("Garage"))
        XCTAssertEqual(lib.items[0].storage, "Garage shelf")
        XCTAssertEqual(lib.items[1].storage, "Garage shelf", "whatever its spelling was")
        XCTAssertEqual(lib.items[2].storage, "Loft / attic", "another place is left alone")
        XCTAssertEqual(lib.trips[0].entries[0].storage, "Garage shelf", "a trip line follows too")
        XCTAssertEqual(lib.trips[0].entries[1].storage, "Loft / attic")
        XCTAssertEqual(lib.usesOf("places")["garage shelf"]?.things, 2)
        XCTAssertNil(lib.usesOf("places")["garage"], "nothing still says the old name")
        XCTAssertEqual(before.items, lib.items.count)
        XCTAssertEqual(before.lines, lib.trips[0].entries.count)
        XCTAssertEqual(before.templates, lib.templates.count, "nothing is lost on the way")
        XCTAssertEqual(lib.records().filter { $0.table == .shared }.count, DEFAULT_STORAGE_LOCATIONS.count,
                       "the factory list with one renamed is his own now")

        // What is refused, and says why — nothing changes.
        XCTAssertEqual(lib.renameChoice("places", key: "Garage shelf", to: "hall CLOSET"), "You already have Hall closet.")
        XCTAssertEqual(lib.renameChoice("places", key: "Garage shelf", to: "  "), "Type a name first.")
        lib.updateThing(id: lib.items[2].id) { $0.storage = "Shed" }
        XCTAssertEqual(lib.renameChoice("places", key: "Garage shelf", to: "shed"),
                       "Some of your things already say shed. Pick another name.", "two places must not become one")
        XCTAssertEqual(lib.items[0].storage, "Garage shelf")
        // Only its spelling: allowed, and carried.
        XCTAssertNil(lib.renameChoice("places", key: "Garage shelf", to: "garage Shelf"))
        XCTAssertEqual(lib.items[1].storage, "garage Shelf")
    }

    func testRenamingAnOwnerOrAPackerCarriesItToEveryThingAndTripLine() {
        var lib = Library()
        lib.items = [newItem(name: "Headlamp", packer: "Robin", ownedBy: "Robin"), newItem(name: "Tent", packer: "Kim", ownedBy: "Jonas")]
        var trip = newEvent(name: "Away")
        trip.entries = [newItem(name: "Headlamp", packer: "robin", ownedBy: "robin "), newItem(name: "Tent", packer: "Kim", ownedBy: "Jonas")]
        lib.trips = [trip]
        lib.setNames("owners", ["Robin", "Jonas"])
        XCTAssertNil(lib.renameChoice("owners", key: "Robin", to: "Robyn"))
        XCTAssertEqual(lib.owners(), ["Jonas", "Robyn"])
        XCTAssertEqual(lib.items.map(\.ownedBy), ["Robyn", "Jonas"])
        XCTAssertEqual(lib.trips[0].entries.map(\.ownedBy), ["Robyn", "Jonas"], "a trip line follows too")

        XCTAssertEqual(lib.people().map(\.name), ["Kim", "Robin"], "no Packers of his own yet: the ones his things name")
        XCTAssertNil(lib.renameChoice("people", key: "Robin", to: "Alex"))
        XCTAssertEqual(lib.people().map(\.name), ["Kim", "Alex"], "in the same place")
        XCTAssertEqual(lib.items.map(\.packer), ["Alex", "Kim"])
        XCTAssertEqual(lib.trips[0].entries.map(\.packer), ["Alex", "Kim"])
        XCTAssertEqual(lib.records().filter { $0.table == .shared && $0.key.hasPrefix("people:") }.map(\.key).sorted(),
                       ["people:alex", "people:kim"], "his own list now, stored")
    }

    func testRenamingAConditionOrAStepChangesOnlyItsWords() {
        var lib = LibraryTests.sample()
        lib.updateThing(id: lib.items[0].id) { $0.condition = "worn"; $0.phase = "morning" }
        XCTAssertNil(lib.renameChoice("conditions", key: "worn", to: "Worn out"))
        XCTAssertEqual(lib.conditions().first { $0.id == "worn" }?.label, "Worn out")
        XCTAssertEqual(lib.conditions().first { $0.id == "worn" }?.tone, "warn", "its badge stays")
        XCTAssertEqual(lib.items[0].condition, "worn", "things point at its id, which stays")
        XCTAssertEqual(ITEM_CONDITIONS.first { $0.id == "worn" }?.label, "Worn out", "the live list follows")

        XCTAssertNil(lib.renameChoice("phases", key: "morning", to: "Breakfast list"))
        XCTAssertEqual(lib.timeline().first { $0.id == "morning" }?.label, "Breakfast list")
        XCTAssertEqual(lib.timeline().map(\.id), DEFAULT_PHASES.map(\.id), "its place in the timeline stays")
        XCTAssertEqual(lib.timeline().first { $0.id == "morning" }?.leadDays, 0)
        XCTAssertEqual(phaseLabel("morning"), "Breakfast list")
        XCTAssertEqual(lib.items[0].phase, "morning", "things keep the step's id")
        XCTAssertEqual(lib.renameChoice("phases", key: "morning", to: "at the FRONT door"), "You already have At the front door.")
    }

    func testMovingAnEntryChangesItsPlaceAndNothingElse() {
        var lib = Library()
        let places = DEFAULT_STORAGE_LOCATIONS
        XCTAssertTrue(lib.moveChoice("places", key: places[5], by: -1))
        XCTAssertEqual(lib.storagePlaces()[4], places[5])
        XCTAssertEqual(lib.storagePlaces()[5], places[4])
        XCTAssertEqual(lib.storagePlaces().count, places.count)
        XCTAssertFalse(lib.moveChoice("places", key: lib.storagePlaces()[0], by: -1), "the first cannot go up")
        XCTAssertFalse(lib.moveChoice("places", key: lib.storagePlaces().last!, by: 1), "the last cannot go down")
        XCTAssertTrue(lib.moveChoice("places", key: places[5], by: 1))
        XCTAssertEqual(lib.storagePlaces(), places)
        XCTAssertEqual(lib.records().filter { $0.table == .shared }.count, 0, "back in the factory order = nothing stored")

        lib.setNames("owners", ["Kim", "Jonas"])
        XCTAssertFalse(lib.moveChoice("owners", key: "Kim", by: -1), "owners are always A–Z")
        XCTAssertFalse(Library.canMove("owners"))

        // A "When" step: the timeline — and so every trip's order — follows.
        XCTAssertTrue(lib.moveChoice("phases", key: "door", by: -1))
        XCTAssertEqual(Array(lib.timeline().map(\.id)[3...4]), ["door", "morning"])
        XCTAssertEqual(Array(PHASES.map(\.id)[3...4]), ["door", "morning"], "the live steps follow")
        XCTAssertEqual(lib.timeline().first { $0.id == "door" }?.label, "At the front door", "only its place changed")
        XCTAssertTrue(lib.moveChoice("phases", key: "door", by: 1))
        XCTAssertEqual(lib.timeline(), DEFAULT_PHASES)
        XCTAssertEqual(lib.records().filter { $0.table == .phases }.count, 0)

        XCTAssertTrue(lib.moveChoice("people", key: "Robin", by: -1))
        XCTAssertEqual(lib.people().map(\.name), ["Robin", "Kim"])
        XCTAssertTrue(lib.moveChoice("conditions", key: "retire", by: -1))
        XCTAssertEqual(lib.conditions().map(\.id), ["new", "good", "retire", "worn"])
        XCTAssertFalse(lib.moveChoice("conditions", key: "nope", by: 1))
    }

    /// The spec pass (5 Oct 2026): the starters in the code used to be his household by
    /// name; now they are invented. An account that never wrote Packers of its own must
    /// still show HIS people — the ones his things and trip lines already name.
    func testPackersWithNoListOfHisOwnAreThePeopleHisThingsName() {
        var lib = Library()
        lib.items = [newItem(name: "Tent", packer: "Zoe"), newItem(name: "Mat", packer: " bo "),
                     newItem(name: "Stove", packer: "zoe"), newItem(name: "Map")]
        var trip = newEvent(name: "Away")
        trip.entries = [newItem(name: "Rope", packer: "Alex")]
        lib.trips = [trip]
        XCTAssertEqual(lib.people().map(\.name), ["bo", "Zoe"], "each once, A–Z — things, not old trip lines")
        XCTAssertEqual(lib.people().map(\.color), Array(PERSON_COLORS.prefix(2)))
        XCTAssertEqual(lib.records().filter { $0.table == .shared }.count, 0, "nothing is stored by looking")
        // Adding one writes them all as his own.
        lib.setPeople(lib.people() + [newPerson(name: "Sam")])
        XCTAssertEqual(lib.people().map(\.name), ["bo", "Zoe", "Sam"])
        XCTAssertEqual(Library().people().map(\.name), ["Kim", "Robin"], "nobody named anywhere: the starters")
    }

    /// The spec pass (5 Oct 2026, spec 06 item 14): Owners has no factory list, so an
    /// account that never added one showed an empty Owners part in Your choices while
    /// "Whose it is" offered the names his things carry. Those names are his Owners now
    /// — A–Z, each once, things only — and the remove and rename rules hold for them.
    func testOwnersWithNoListOfHisOwnAreTheOwnersHisThingsName() {
        var lib = Library()
        lib.items = [newItem(name: "Tent", ownedBy: "Zoe"), newItem(name: "Mat", ownedBy: " Bo "),
                     newItem(name: "Stove", ownedBy: "zoe"), newItem(name: "Map")]
        var trip = newEvent(name: "Away")
        trip.entries = [newItem(name: "Rope", ownedBy: "Alex")]
        lib.trips = [trip]
        XCTAssertEqual(lib.owners().map(normName), ["bo", "zoe"], "each once, A–Z — things, not old trip lines")
        XCTAssertEqual(lib.owners(), lib.ownerChoices(), "Your choices and Whose it is name the same owners")
        XCTAssertEqual(lib.records().filter { $0.table == .shared }.count, 0, "nothing is stored by looking")
        XCTAssertEqual(Library().owners(), [], "nobody named anywhere: no owners")

        // Every one is in use by a thing, so none can be removed (the screen refuses).
        let uses = lib.usesOf("owners")
        for name in lib.owners() { XCTAssertTrue(uses[normName(name)]?.inUse == true, "\(name) could be removed") }

        // A rename makes the list his own, and his things follow.
        let zoe = lib.owners()[1]
        XCTAssertEqual(lib.renameChoice("owners", key: zoe, to: "Bo"), "You already have Bo.")
        XCTAssertNil(lib.renameChoice("owners", key: zoe, to: "Ann"))
        XCTAssertEqual(lib.owners(), ["Ann", "Bo"], "still A–Z")
        XCTAssertEqual(lib.items.map(\.ownedBy), ["Ann", " Bo ", "Ann", ""], "both spellings follow")
        XCTAssertEqual(lib.records().filter { $0.table == .shared }.map(\.key).sorted(), ["owners:ann", "owners:bo"],
                       "his own list now, stored")
        XCTAssertEqual(lib.trips[0].entries[0].ownedBy, "Alex", "a trip line of another name is left alone")

        // Adding one to a list he never wrote keeps the names his things carry.
        var fresh = Library()
        fresh.items = [newItem(name: "Tent", ownedBy: "Zoe")]
        fresh.setNames("owners", fresh.owners() + ["Sam"])
        XCTAssertEqual(fresh.owners(), ["Sam", "Zoe"])
        XCTAssertFalse(Library.canMove("owners"), "owners stay A–Z")
    }
}
