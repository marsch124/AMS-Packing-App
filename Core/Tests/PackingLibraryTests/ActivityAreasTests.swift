import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// His own activity areas (0.89) — his words, 18 Oct 2026: "I would like the ability to add
/// and adjust activity areas so that I can organize templates." An area is his list: made,
/// renamed, moved and removed the way Your choices does it, kept in a `meta` record so it
/// syncs and in the backup's `prefs`, while the web app's model never sees anything new.
final class ActivityAreasTests: XCTestCase {
    override func setUp() { PackingEnv.freeze(at: "2026-10-18T09:00:00.000Z") }
    override func tearDown() { PackingEnv.reset() }

    /// The sample's shape: Common base (always packed), Hiking in GA, Swim and Run in WET,
    /// Picnic in no area, and a car template.
    private func library() -> Library {
        var lib = Library()
        lib.saveTemplate(newList(name: "Common base", role: "base"))
        lib.saveTemplate(newList(name: "Hiking", group: "GA"))
        lib.saveTemplate(newList(name: "Run", group: "WET"))
        lib.saveTemplate(newList(name: "Swim", group: "WET"))
        lib.saveTemplate(newList(name: "Picnic"))
        lib.saveTemplate(newList(name: "Car", role: "transport", transport: "Car"))
        return lib
    }
    private func id(_ lib: Library, _ name: String) -> String { lib.templates.first { $0.name == name }!.id }
    private func template(_ lib: Library, _ name: String) -> PackList { lib.templates.first { $0.name == name }! }
    /// Area headings as Create new trip and the Templates tab read them, with their templates.
    private func shown(_ lib: Library) -> [String] {
        lib.activityChoices().map { "\(Library.areaWords(ActivityArea(id: $0.group.id, name: $0.group.label))): \($0.lists.map(\.name).joined(separator: ", "))" }
    }

    func testWithNoListOfHisTheThreeAreasAreTheAppsAndNothingIsStored() {
        let lib = library()
        XCTAssertEqual(lib.activityAreas().map(\.id), ["GA", "WET", "OE"])
        XCTAssertEqual(lib.activityAreas().map(\.name), ["Goal Activity", "Workout, Exercise & Training", "Other Events"])
        XCTAssertNil(lib.meta[Library.areasKey], "the factory areas were stored")
        XCTAssertEqual(shown(lib), ["GA · Goal Activity: Hiking", "WET · Workout, Exercise & Training: Swim, Run",
                                    "Other Templates: Picnic"], "the areas are not as before 0.89")
        XCTAssertEqual(lib.areaOf(template(lib, "Common base")), "", "an always-packed template is in an area")
        XCTAssertEqual(lib.areaOf(template(lib, "Car")), "")
    }

    /// Make one, file a template in it from its page, see it in his order — and the template
    /// keeps a `group` the web app reads ("") with his area in `extra`.
    func testANewAreaHoldsATemplateInHisOrder() {
        var lib = library()
        var e = ChoiceEdits(kind: "areas")
        e.added = ["Mountains"]
        e.order = [ChoiceEdits.addedKey(0), "GA", "WET", "OE"]
        let map = lib.applyChoiceEditsNow(e)
        let mountains = map[ChoiceEdits.addedKey(0)]!
        XCTAssertTrue(mountains.hasPrefix("area-"), "a new area's id: \(mountains)")
        XCTAssertEqual(lib.activityAreas().map(\.name), ["Mountains", "Goal Activity", "Workout, Exercise & Training", "Other Events"])
        XCTAssertTrue(lib.setTemplateArea(id: id(lib, "Hiking"), area: mountains))
        let hiking = template(lib, "Hiking")
        XCTAssertEqual(hiking.group, "", "his own area went into the web app's field")
        XCTAssertEqual(hiking.extra[Library.areaKey]?.stringValue, mountains)
        XCTAssertEqual(lib.areaOf(hiking), mountains)
        XCTAssertEqual(shown(lib), ["Mountains: Hiking", "WET · Workout, Exercise & Training: Swim, Run", "Other Templates: Picnic"])
        // …and back into a built-in: `group` again, his area gone from `extra`.
        XCTAssertTrue(lib.setTemplateArea(id: id(lib, "Hiking"), area: "OE"))
        XCTAssertEqual(template(lib, "Hiking").group, "OE")
        XCTAssertNil(template(lib, "Hiking").extra[Library.areaKey])
        // An area that is not his is refused; so is a transport template.
        XCTAssertFalse(lib.setTemplateArea(id: id(lib, "Hiking"), area: "area-nobody"))
        XCTAssertFalse(lib.setTemplateArea(id: id(lib, "Car"), area: mountains))
        // Into Always packed: no area of his left on it.
        XCTAssertTrue(lib.setTemplateArea(id: id(lib, "Picnic"), area: mountains))
        XCTAssertTrue(lib.setTemplateArea(id: id(lib, "Picnic"), area: Library.ALWAYS_PACKED_AREA))
        XCTAssertNil(template(lib, "Picnic").extra[Library.areaKey], "an always-packed template kept an area")
    }

    func testARenamedAreaIsFollowedByItsTemplatesAndABuiltInKeepsItsRole() {
        var lib = library()
        var e = ChoiceEdits(kind: "areas")
        e.names["WET"] = "Training"
        e.names["GA"] = "Big goals"
        lib.applyChoiceEditsNow(e)
        XCTAssertEqual(shown(lib), ["Big goals: Hiking", "Training: Swim, Run", "Other Templates: Picnic"],
                       "a renamed built-in shows his name alone, its templates follow")
        XCTAssertEqual(template(lib, "Swim").group, "WET", "the workout area lost its code")
        XCTAssertTrue(contextApplies(template(lib, "Swim")), "a renamed workout area stopped being the workouts")
        XCTAssertEqual(lib.activityChoices()[1].lists.map(\.name), ["Swim", "Run"], "Swim/Bike/Run order went")
        // Two areas swapping names both get theirs.
        var swap = ChoiceEdits(kind: "areas")
        swap.names["WET"] = "Big goals"
        swap.names["GA"] = "Training"
        lib.applyChoiceEditsNow(swap)
        XCTAssertEqual(lib.activityAreas().map(\.name).prefix(2), ["Training", "Big goals"])
        // A built-in under its own name again shows its code; the list is the factory's again: nothing stored.
        var back = ChoiceEdits(kind: "areas")
        back.names["GA"] = "Goal Activity"
        back.names["WET"] = "Workout, Exercise & Training"
        lib.applyChoiceEditsNow(back)
        XCTAssertEqual(lib.areaTitle("GA"), "GA · Goal Activity")
        XCTAssertNil(lib.meta[Library.areasKey], "the list as shipped is still stored")
    }

    func testANameIsRefusedWhenHeHasItOrItIsAHeadingOfItsOwn() {
        let lib = library()
        let e = ChoiceEdits(kind: "areas")
        XCTAssertEqual(lib.choiceNameProblem(e, key: "OE", name: "goal  activity"), "You already have Goal Activity.")
        XCTAssertEqual(lib.choiceNameProblem(e, key: "OE", name: "other templates"),
                       "Other Templates is a heading of its own on Templates. Pick another name.")
        XCTAssertEqual(lib.choiceNameProblem(e, key: "OE", name: "Always packed"),
                       "Always Packed is a heading of its own on Templates. Pick another name.")
        XCTAssertEqual(lib.choiceNameProblem(e, key: "OE", name: " "), "Type a name first.")
        XCTAssertNil(lib.choiceNameProblem(e, key: "OE", name: "Small joys"))
        var made = lib
        XCTAssertNil(made.addChoice("areas", "Goal activity"), "a second Goal Activity was made")
        XCTAssertNil(made.addChoice("areas", "By transport"), "an area called By Transport was made")
    }

    /// Remove asks — or, while templates are in it, names them and keeps it. The workout area
    /// never goes; GA and OE go once empty; a template whose area went falls under Other Templates.
    func testAnAreaInUseStaysAndSaysWhichTemplatesAnEmptyOneGoes() {
        var lib = library()
        let mountains = lib.addChoice("areas", "Mountains")!
        XCTAssertTrue(lib.setTemplateArea(id: id(lib, "Picnic"), area: mountains))
        XCTAssertEqual(lib.choiceRemoveProblem("areas", key: mountains, label: "Mountains"),
                       "Mountains still holds Picnic, so it stays. Move it to another area on its page first.")
        XCTAssertTrue(lib.setTemplateArea(id: id(lib, "Hiking"), area: mountains))
        XCTAssertEqual(lib.removeChoice("areas", key: mountains),
                       "Mountains still holds Hiking and Picnic, so it stays. Move them to another area on their page first.")
        XCTAssertEqual(lib.choiceUse("areas", key: mountains).templates, 2)
        XCTAssertEqual(lib.removeChoice("areas", key: "WET"),
                       "Workout, Exercise & Training is where your workouts live \u{2014} each gets its own Context on a trip \u{2014} so it stays.")
        XCTAssertNil(lib.removeChoice("areas", key: "OE"), "an empty built-in could not go")
        XCTAssertEqual(lib.activityAreas().map(\.id), ["GA", "WET", mountains])
        XCTAssertFalse(lib.setTemplateArea(id: id(lib, "Swim"), area: "OE"), "a removed area still takes templates")
        // Held on a page: the removal waits for Save, and one still in use by then stays.
        var e = ChoiceEdits(kind: "areas")
        e.removed = [mountains, "GA"]
        XCTAssertEqual(lib.activityAreas().count, 3, "nothing changes before Save")
        lib.applyChoiceEditsNow(e)
        XCTAssertEqual(lib.activityAreas().map(\.id), ["WET", mountains], "the empty GA did not go, or the used one did")
        // The other device took his area away meanwhile: its templates fall under Other Templates.
        var other = lib
        other.setActivityAreas([ActivityArea(id: "WET", name: "Workout, Exercise & Training")])
        XCTAssertEqual(shown(other), ["WET · Workout, Exercise & Training: Swim, Run", "Other Templates: Hiking, Picnic"])
        // The workout area is there whatever a list says.
        other.meta[Library.areasKey] = .array([["id": "x1", "name": "Only mine"]])
        XCTAssertEqual(other.activityAreas().map(\.id), ["x1", "WET"])
    }

    func testAnAreaMovesUpAndDown() {
        var lib = library()
        XCTAssertTrue(lib.moveChoice("areas", key: "OE", by: -1))
        XCTAssertEqual(lib.activityAreas().map(\.id), ["GA", "OE", "WET"])
        XCTAssertFalse(lib.moveChoice("areas", key: "GA", by: -1), "the first moved up")
        XCTAssertTrue(lib.moveChoice("areas", key: "OE", by: 1))
        XCTAssertNil(lib.meta[Library.areasKey], "back in the factory order, still stored")
        XCTAssertTrue(Library.canMove("areas"))
        XCTAssertTrue(Library.choiceOrders("areas"))
    }

    /// Both devices see the same areas: the list is a record of its own, the template's area
    /// rides in its own record — and a backup and a restore bring both back exactly. The web
    /// app's model keeps its view: a template in his own area reads as one with no area.
    func testTheAreasSurviveTheStoreABackupAndARestore() throws {
        var lib = library()
        let mountains = lib.addChoice("areas", "Mountains")!
        XCTAssertTrue(lib.moveChoice("areas", key: mountains, by: -1))
        XCTAssertNil(lib.renameChoice("areas", key: "GA", to: "Big goals"))
        XCTAssertTrue(lib.setTemplateArea(id: id(lib, "Hiking"), area: mountains))
        let want = shown(lib)
        XCTAssertEqual(want, ["WET · Workout, Exercise & Training: Swim, Run", "Mountains: Hiking", "Other Templates: Picnic"])
        let names = ["Big goals", "Workout, Exercise & Training", "Mountains", "Other Events"]
        XCTAssertEqual(lib.activityAreas().map(\.name), names)

        // iCloud: the records, read back.
        let synced = Library(records: lib.records())
        XCTAssertEqual(synced.activityAreas(), lib.activityAreas(), "the stored records lost his areas")
        XCTAssertEqual(shown(synced), want)

        // A backup, read back (the one-time import reads it the same way).
        let (back, report) = Importer.library(from: lib.backupFile(exportedAt: "2026-10-18T09:00:00.000Z"))
        XCTAssertTrue(report.isFaithful, report.mismatches.prefix(3).joined(separator: "; "))
        XCTAssertEqual(back.activityAreas(), lib.activityAreas(), "a backup lost his areas")
        XCTAssertEqual(shown(back), want, "a backup lost which area a template is in")

        // A restore over a device that holds something else: exactly the file's areas.
        var current = library()
        _ = current.addChoice("areas", "Beach")
        let file = try Importer.read(lib.backupData(exportedAt: "2026-10-18T09:00:00.000Z")).library
        let store = MemoryStore(current.records())
        try store.apply(recordChanges(from: current.records(), to: Importer.restoring(file, over: current).records()))
        let after = Library(records: try store.loadAll())
        XCTAssertEqual(after.activityAreas().map(\.name), names, "a restore did not bring his areas back exactly")
        XCTAssertEqual(shown(after), want)

        // The web app's model: the template's `group` is still one it knows, nothing else changes.
        let web = try XCTUnwrap(coerceList(json: back.resolvedTemplate(id: id(back, "Hiking"))!.json))
        XCTAssertEqual(web.group, "", "the web app would read an area code it does not know")
        XCTAssertEqual(web.extra[Library.areaKey]?.stringValue, mountains, "the web model's view dropped his area")
    }

    /// A shared template replacing his keeps his area; a small core's big template can go
    /// into one of his areas; a new template can be made in one.
    func testHisAreaIsKeptByAReplaceAndOfferedToASmallCoreAndANewTemplate() throws {
        var lib = library()
        let mountains = lib.addChoice("areas", "Mountains")!
        XCTAssertTrue(lib.setTemplateArea(id: id(lib, "Hiking"), area: mountains))
        _ = lib.addToTemplate(templateId: id(lib, "Hiking"), name: "Hiking boots")
        let link = try XCTUnwrap(lib.shareLink(templateId: id(lib, "Hiking")))
        guard case .template(let shared)? = Library.readShared(link) else { return XCTFail("not read as a template") }
        XCTAssertNotNil(lib.importTemplate(shared, replacing: id(lib, "Hiking")))
        XCTAssertEqual(lib.areaOf(template(lib, "Hiking")), mountains, "replacing his Hiking took it out of his area")

        let made = Library.filed(newList(name: "Glacier"), in: mountains)
        lib.saveTemplate(made)
        XCTAssertEqual(lib.areaOf(template(lib, "Glacier")), mountains, "a new template lost the area it was made in")
        XCTAssertEqual(Library.filed(newList(name: "x"), in: "OE").group, "OE")
    }
}
