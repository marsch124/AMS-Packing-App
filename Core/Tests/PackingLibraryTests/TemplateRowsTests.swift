import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// A template's rows — what THIS template says about a thing — as the spec pass of
/// 5 Oct 2026 found them: a thing's note was frozen onto its rows, the editor dropped
/// words it did not know, a section typed and cancelled stayed, and a row change
/// never reached a trip still ahead.
final class TemplateRowsTests: XCTestCase {
    override func setUp() { PackingEnv.freeze(); _ = setPhases(DEFAULT_PHASES) }
    override func tearDown() { PackingEnv.reset(); _ = setPhases(DEFAULT_PHASES) }

    /// A Swim template with Goggles, and a Towel he owns on no template yet — a
    /// thing with a note and a "how many" of its own.
    private func library() -> Library {
        var lib = Library()
        var swim = newList(name: "Swim", group: "WET")
        swim.items = [newItem(name: "Goggles")]
        lib.saveTemplate(swim)
        var beach = newList(name: "Beach", group: "OE")
        beach.items = [newItem(name: "Sun hat")]
        lib.saveTemplate(beach)
        let towel = lib.addThing(name: "Towel")!
        lib.updateThing(id: towel.id) { $0.note = "Dry it first"; $0.qty = "2" }
        return lib
    }
    private func tpl(_ lib: Library, _ name: String) -> String { lib.templates.first { $0.name == name }!.id }
    private func thing(_ lib: Library, _ name: String) -> String { lib.items.first { $0.name == name }!.id }
    private func place(_ lib: Library, _ thingName: String, on template: String) -> Membership {
        let t = tpl(lib, template), i = thing(lib, thingName)
        return lib.memberships.first { $0.templateId == t && $0.itemId == i }!
    }
    private func row(_ lib: Library, _ thingName: String, on template: String) -> Item {
        lib.resolvedTemplate(id: tpl(lib, template))!.items.first { $0.name == thingName }!
    }

    /// "Blank means the same as the thing itself, so a change to the thing still
    /// reaches this template" — however the thing got onto it, and however often the
    /// template is saved afterwards.
    func testAThingsNoteIsNeverFrozenOntoItsRows() {
        var lib = library()
        let towel = thing(lib, "Towel")
        // Chosen from his things, typed by name, and through a later save of the template.
        XCTAssertEqual(lib.putOnTemplate(templateId: tpl(lib, "Swim"), itemIds: [towel]), 1)
        XCTAssertNotNil(lib.addToTemplate(templateId: tpl(lib, "Beach"), name: "towel"))
        XCTAssertNotNil(lib.addToTemplate(templateId: tpl(lib, "Swim"), name: "Fins"))   // saves Swim again
        for t in ["Swim", "Beach"] {
            XCTAssertEqual(place(lib, "Towel", on: t).note, "", "\(t): the thing's note was copied onto the row")
            XCTAssertEqual(place(lib, "Towel", on: t).qty, "", "\(t): the thing's how-many was copied onto the row")
            XCTAssertEqual(row(lib, "Towel", on: t).note, "Dry it first", "\(t) does not show the thing's note")
        }
        // …so a change to the thing reaches every row.
        lib.updateThing(id: towel) { $0.note = "Hang it up"; $0.qty = "3" }
        XCTAssertEqual(row(lib, "Towel", on: "Swim").note, "Hang it up")
        XCTAssertEqual(row(lib, "Towel", on: "Beach").qty, "3")

        // A row's OWN answer is kept through a save — even one that equals the thing's.
        let swimTowel = place(lib, "Towel", on: "Swim").id
        lib.updateMembership(memId: swimTowel) { $0.note = "Hang it up"; $0.qty = "1" }
        let goggles = lib.resolvedTemplate(id: tpl(lib, "Swim"))!.items.first { $0.name == "Goggles" }!.memId!
        XCTAssertTrue(lib.removeFromTemplate(templateId: tpl(lib, "Swim"), memId: goggles))
        XCTAssertEqual(place(lib, "Towel", on: "Swim").note, "Hang it up", "a row's own note was lost by a save")
        XCTAssertEqual(place(lib, "Towel", on: "Swim").qty, "1", "a row's own how-many was lost by a save")
    }

    /// The rows an older build froze: a place whose note or how-many is EXACTLY the
    /// thing's own goes back to blank; a row of his own is kept; nothing on screen
    /// changes; and a second run changes nothing.
    func testTheCopiesAnOlderBuildMadeFollowTheirThingsAgain() {
        var lib = library()
        let towel = thing(lib, "Towel")
        lib.putOnTemplate(templateId: tpl(lib, "Swim"), itemIds: [towel])
        lib.putOnTemplate(templateId: tpl(lib, "Beach"), itemIds: [towel])
        // What the old save wrote: the thing's own answers, copied.
        lib.updateMembership(memId: place(lib, "Towel", on: "Swim").id) { $0.note = "Dry it first"; $0.qty = "2" }
        lib.updateMembership(memId: place(lib, "Towel", on: "Beach").id) { $0.note = "Shake out the sand" }
        let before = lib.resolvedTemplates()

        XCTAssertEqual(lib.letCopiedAnswersFollowTheirThings(), 1, "one place held a copy")
        XCTAssertEqual(place(lib, "Towel", on: "Swim").note, "")
        XCTAssertEqual(place(lib, "Towel", on: "Swim").qty, "")
        XCTAssertEqual(place(lib, "Towel", on: "Beach").note, "Shake out the sand", "his own note was taken")
        XCTAssertEqual(lib.resolvedTemplates(), before, "the clean-up changed what a row says")
        XCTAssertEqual(lib.letCopiedAnswersFollowTheirThings(), 0, "a second run changed something")

        lib.updateThing(id: towel) { $0.note = "Hang it up" }
        XCTAssertEqual(row(lib, "Towel", on: "Swim").note, "Hang it up", "the cleaned row does not follow the thing")
    }

    /// The row editor's Save: words it does not know are kept unless switched off;
    /// the app's own words in the app's order; answers equal to the thing's left blank.
    func testARowSavedFromTheEditorKeepsWhatItDoesNotKnow() {
        var lib = library()
        let towel = thing(lib, "Towel")
        lib.putOnTemplate(templateId: tpl(lib, "Swim"), itemIds: [towel])
        let m = place(lib, "Towel", on: "Swim")
        // As the web app or an import may have spelt them.
        lib.updateMembership(memId: m.id) { $0.seasons = ["summer"]; $0.transports = ["Boat"]; $0.catering = ["picnic"] }

        let a = Library.RowAnswers(qty: " 2 ", note: "Dry it first",
                                   seasons: ["Winter", "summer"], transports: ["Car", "Boat"], catering: ["self", "picnic"])
        XCTAssertTrue(lib.saveRow(templateId: tpl(lib, "Swim"), memId: m.id, a))
        let saved = place(lib, "Towel", on: "Swim")
        XCTAssertEqual(saved.seasons, ["Winter", "summer"], "a word the app does not know was dropped")
        XCTAssertEqual(saved.transports, ["Car", "Boat"])
        XCTAssertEqual(saved.catering, ["self", "picnic"])
        XCTAssertEqual(saved.qty, "", "a how-many equal to the thing's was stored as the row's own")
        XCTAssertEqual(saved.note, "", "a note equal to the thing's was stored as the row's own")

        // Switched off, it goes.
        var off = a; off.seasons = ["Winter"]
        XCTAssertTrue(lib.saveRow(templateId: tpl(lib, "Swim"), memId: m.id, off))
        XCTAssertEqual(place(lib, "Towel", on: "Swim").seasons, ["Winter"])
        XCTAssertEqual(Library.keptConditions(["Summer", "Winter"], SEASONS, []), ["Summer", "Winter"], "the app's order")
        XCTAssertEqual(Library.unknownConditions(["summer", "Winter", "summer"], SEASONS), ["summer"])
        XCTAssertFalse(lib.saveRow(templateId: tpl(lib, "Beach"), memId: m.id, a), "a row of another template")
    }

    /// A section typed in the row editor is made when the row is SAVED, and holds it.
    /// (Cancel never calls Save, so it leaves the template as it was — the UI test.)
    func testARowsNewSectionIsMadeWhenTheRowIsSaved() {
        var lib = library()
        let swim = tpl(lib, "Swim")
        let goggles = place(lib, "Goggles", on: "Swim").id
        XCTAssertTrue(lib.templates.first { $0.id == swim }!.sections.isEmpty)
        XCTAssertTrue(lib.saveRow(templateId: swim, memId: goggles, Library.RowAnswers(newSection: " Pool kit ")))
        let sections = lib.templates.first { $0.id == swim }!.sections
        XCTAssertEqual(sections.map(\.name), ["Pool kit"])
        XCTAssertEqual(place(lib, "Goggles", on: "Swim").section, sections[0].id, "the row is not in its new section")
        // The same name again is the same section, not a second one.
        XCTAssertTrue(lib.saveRow(templateId: swim, memId: goggles, Library.RowAnswers(newSection: "pool KIT")))
        XCTAssertEqual(lib.templates.first { $0.id == swim }!.sections.count, 1)
    }

    /// His I.7 decision carried to a row: a row's own bag reaches a trip still ahead,
    /// on a line not ticked yet; a ticked line keeps what it was packed with.
    func testARowChangeReachesATripStillAhead() {
        var lib = library()
        let swim = tpl(lib, "Swim")
        lib.putOnTemplate(templateId: swim, itemIds: [thing(lib, "Towel")])
        var trip = newEvent(name: "Pool week", startDate: "2099-06-01", endDate: "2099-06-03")
        trip.activities = [swim]
        trip = lib.createTrip(trip)
        let before = lib.trips[0].entries
        let goggles = before.firstIndex { $0.name == "Goggles" }!
        lib.trips[0].entries[goggles].checked = true

        for name in ["Towel", "Goggles"] {
            XCTAssertTrue(lib.saveRow(templateId: swim, memId: place(lib, name, on: "Swim").id,
                                      Library.RowAnswers(bag: "Swim bag", note: "\(name) note")))
        }
        let towelLine = lib.trips[0].entries.first { $0.name == "Towel" }!
        XCTAssertEqual(towelLine.container, "Swim bag", "the row's new bag did not reach the trip")
        XCTAssertEqual(towelLine.note, "Towel note")
        XCTAssertEqual(towelLine.id, before.first { $0.name == "Towel" }!.id, "the line lost its id")
        XCTAssertEqual(lib.trips[0].entries[goggles].container, before[goggles].container, "a ticked line was changed")
    }

    /// "Only on:" says only what a trip reads on this template: Context counts on a
    /// workout template alone.
    func testOnlyOnSaysWhatATripReadsOnThisTemplate() {
        var row = newItem(name: "Towel")
        row.seasons = ["Summer"]; row.contexts = ["Indoor"]; row.transports = ["Plane"]; row.catering = ["eatout"]
        XCTAssertEqual(Library.onlyOnWords(row, on: newList(name: "Beach", group: "OE")),
                       "Only on: Summer \u{00B7} Plane \u{00B7} Eating out", "a context that does nothing is claimed")
        XCTAssertEqual(Library.onlyOnWords(row, on: newList(name: "Swim", group: "WET")),
                       "Only on: Summer \u{00B7} Indoor \u{00B7} Plane \u{00B7} Eating out")
        XCTAssertEqual(Library.onlyOnWords(newItem(name: "Cap"), on: nil), "")
    }

    /// The first bag pill says where a blank bag really goes.
    func testABlankBagNamesWhereItReallyGoes() {
        var lib = library()
        let towel = lib.items.first { $0.name == "Towel" }!
        XCTAssertEqual(lib.sameBagWords(templateId: tpl(lib, "Swim"), thing: towel), "Same as the thing (\(towel.container))")
        lib.templates[lib.templates.firstIndex { $0.name == "Swim" }!].defaultContainer = "Swim bag"
        XCTAssertEqual(lib.sameBagWords(templateId: tpl(lib, "Swim"), thing: towel), "Same as the template (Swim bag)")
        // …which is where it really goes.
        lib.putOnTemplate(templateId: tpl(lib, "Swim"), itemIds: [towel.id])
        XCTAssertEqual(row(lib, "Towel", on: "Swim").container, "Swim bag")
    }

    /// Typing a thing already on the template does not put it on twice.
    func testTypingAThingAlreadyOnTheTemplateDoesNotAddItTwice() {
        var lib = library()
        let swim = tpl(lib, "Swim")
        XCTAssertTrue(lib.isOnTemplate(templateId: swim, name: " goggles "))
        XCTAssertNil(lib.addToTemplate(templateId: swim, name: "GOGGLES"), "a second Goggles row was made")
        XCTAssertEqual(lib.resolvedTemplate(id: swim)!.items.map(\.name), ["Goggles"])
        XCTAssertFalse(lib.isOnTemplate(templateId: swim, name: "Towel"))
        XCTAssertNotNil(lib.addToTemplate(templateId: swim, name: "Towel"), "a thing he owns could not be put on")
    }

    /// The order things are put on is the order given (the picker gives the order he
    /// ticked them in).
    func testThingsPutOnLandInTheOrderGiven() {
        var lib = library()
        let beach = tpl(lib, "Beach")
        let ids = ["Towel", "Goggles"].map { thing(lib, $0) }
        XCTAssertEqual(lib.putOnTemplate(templateId: beach, itemIds: ids), 2)
        XCTAssertEqual(lib.resolvedTemplate(id: beach)!.items.map(\.name), ["Sun hat", "Towel", "Goggles"])
    }
}

/// A template's face and the words around it: never an emoji, never teal; the
/// Templates tab's line counts what it says; Search and the tab show the same templates.
final class TemplateFacesTests: XCTestCase {
    override func setUp() { PackingEnv.freeze(); _ = setPhases(DEFAULT_PHASES) }
    override func tearDown() { PackingEnv.reset(); _ = setPhases(DEFAULT_PHASES) }

    func testACoverShowsALetterNeverAnEmoji() {
        var l = newList(name: " swim lessons"); l.emoji = "\u{1F3CA}"
        XCTAssertEqual(Library.coverLetter(l), "S")
        XCTAssertEqual(Library.coverLetter(newList(name: "")), "")
    }

    func testNoTemplateIsGivenTealOrCyan() {
        let teal = ["#14b8a6", "#06b6d4"]
        XCTAssertEqual(COVER_COLOURS.count, TEMPLATE_COLORS.count)
        XCTAssertTrue(COVER_COLOURS.allSatisfy { !teal.contains($0.lowercased()) }, "teal is still a cover colour")
        var sawSwapped = false
        for n in 0..<200 {
            var l = newList(name: "T\(n)"); l.id = "id-\(n)"
            let web = listColor(l), here = Library.coverColour(l)
            XCTAssertFalse(teal.contains(here), "\(l.id) got \(here)")
            if teal.contains(web) { sawSwapped = true } else { XCTAssertEqual(here, web, "a colour that was never teal moved") }
        }
        XCTAssertTrue(sawSwapped, "no template landed on a swapped colour — the check proves nothing")
        var own = newList(name: "His"); own.color = "#14b8a6"
        XCTAssertEqual(Library.coverColour(own), "#14b8a6", "his own colour is his data")
        // A new eighth "When" step (after the factory seven) used to be teal.
        let lib = Library()
        let step = lib.newStep(named: "Gym bag")
        XCTAssertFalse(teal.contains(step.color), "the eighth step is \(step.color)")
        XCTAssertEqual(step.label, "Gym bag")
        XCTAssertFalse(teal.contains(Library.newStepColour(after: 2)))
    }

    private func library() -> Library {
        var lib = Library()
        var base = newList(name: "Base", role: "base"); base.items = [newItem(name: "Keys"), newItem(name: "Map")]
        lib.saveTemplate(base)
        var hike = newList(name: "Hiking", group: "GA"); hike.items = [newItem(name: "Boots"), newItem(name: "Map")]
        lib.saveTemplate(hike)
        var loose = newList(name: "Loose items", role: "loose"); loose.items = [newItem(name: "Old thing")]
        lib.saveTemplate(loose)
        lib.addBag(name: "Duffel bag")
        _ = lib.addThing(name: "On no template")
        return lib
    }

    func testTheTemplatesLineCountsWhatItSays() {
        var lib = library()
        let shown = lib.shownTemplates()
        XCTAssertEqual(shown.map(\.name), ["Base", "Hiking"], "the bag list or the loose bin is shown as a template")
        // Keys, Map, Boots — Map once; not the bag, not the loose thing, not the thing on no template.
        XCTAssertEqual(lib.templateSummary(shown).things, 3)
        XCTAssertEqual(lib.templateSummary(shown).templates, 2)
        XCTAssertEqual(lib.templateSummary(shown).trips, 0)
        var trip = newEvent(name: "Walk", startDate: "2026-05-01", endDate: "2026-05-01")
        trip.activities = [lib.templates.first { $0.name == "Hiking" }!.id]
        lib.createTrip(trip)
        lib.trips.append(newEvent(name: "Nothing from them"))       // no template, no lines
        XCTAssertEqual(lib.templateSummary(shown).trips, 1, "a trip packed from none of them was counted")
    }

    func testANameIsTakenOnlyByATemplateHeCanSee() {
        var lib = library()
        XCTAssertTrue(lib.templateNameTaken(" hiking "))
        XCTAssertFalse(lib.templateNameTaken("Containers"), "the bag list's hidden name counts as taken")
        XCTAssertFalse(lib.templateNameTaken("Hiking", except: lib.templates.first { $0.name == "Hiking" }!.id))
        XCTAssertEqual(lib.freeTemplateName("Hiking"), "Hiking 2")
        XCTAssertEqual(lib.freeTemplateName("Climbing"), "Climbing")
        let hiking = lib.templates.first { $0.name == "Hiking" }!.id
        XCTAssertTrue(lib.renameTemplate(id: hiking, to: "Containers"), "a name only the bag list has was refused")
        XCTAssertTrue(lib.worries().isEmpty, "a template named like the hidden bag list reads as two libraries: \(lib.worries())")
        // Two BAG lists still are.
        lib.saveTemplate(newList(name: CONTAINER_LIST_NAME, role: CONTAINER_ROLE))
        XCTAssertEqual(lib.worries().first?.names, [CONTAINER_LIST_NAME])
    }

    func testATemplateMovesToAnotherActivityArea() {
        var lib = library()
        let hiking = lib.templates.first { $0.name == "Hiking" }!.id
        XCTAssertTrue(lib.setTemplateArea(id: hiking, area: "OE"))
        XCTAssertEqual(lib.templates.first { $0.id == hiking }?.group, "OE")
        XCTAssertTrue(lib.setTemplateArea(id: hiking, area: ""))
        XCTAssertEqual(lib.templates.first { $0.id == hiking }?.group, "")
        XCTAssertFalse(lib.setTemplateArea(id: hiking, area: "XX"), "an area that is not his")
        XCTAssertFalse(lib.setTemplateArea(id: "no-such", area: "GA"))
        // A transport template stays where it is (0.71 left "By transport" alone).
        var car = newList(name: "By car", role: "transport"); car.transport = "Car"
        lib.saveTemplate(car)
        XCTAssertFalse(lib.setTemplateArea(id: car.id, area: "GA"), "a transport template got an area")
        XCTAssertFalse(lib.setTemplateArea(id: car.id, area: Library.ALWAYS_PACKED_AREA), "a transport template became always packed")
        XCTAssertEqual(lib.templates.first { $0.id == car.id }?.role, "transport")
    }

    private func names(_ trip: TripEvent) -> [String] { trip.entries.map(\.name).sorted() }

    /// 0.71: his always-packed template had grown too big for a short trip. The way
    /// out: a small always-packed core he makes himself, and the big one becomes a
    /// template he ticks for longer trips. So a template moves INTO Always packed and
    /// back OUT of it from its own page — keeping everything that is its own.
    func testATemplateMovesIntoAndOutOfAlwaysPacked() {
        var lib = library()
        let base = lib.templates.first { $0.name == "Base" }!.id
        let hiking = lib.templates.first { $0.name == "Hiking" }!.id
        // What is the template's own: a section, a row's own note and bag.
        let pockets = lib.addSection(templateId: base, name: "Pockets")!
        let keysRow = lib.memberships.first { $0.templateId == base && lib.items.first { $0.name == "Keys" }?.id == $0.itemId }!
        XCTAssertTrue(lib.updateMembership(memId: keysRow.id) { $0.note = "On the hook"; $0.container = "Duffel bag"; $0.section = pockets.id })
        let rowsBefore = lib.memberships.filter { $0.templateId == base }
        let sectionsBefore = lib.templates.first { $0.id == base }!.sections

        // A trip made before the move: its lines stand on their own.
        var weekend = newEvent(name: "Weekend", startDate: "2099-05-01", endDate: "2099-05-02")
        weekend.activities = [hiking]
        weekend = lib.createTrip(weekend)
        XCTAssertEqual(names(weekend), ["Boots", "Keys", "Map"])

        // OUT of Always packed, into OE: it comes only when ticked.
        XCTAssertTrue(lib.setTemplateArea(id: base, area: "OE"))
        let moved = lib.templates.first { $0.id == base }!
        XCTAssertEqual(moved.role, "", "still always packed")
        XCTAssertEqual(moved.group, "OE")
        XCTAssertEqual(lib.memberships.filter { $0.templateId == base }, rowsBefore, "a row or its own answers changed")
        XCTAssertEqual(moved.sections, sectionsBefore, "its sections changed")
        XCTAssertTrue(lib.activityChoices().flatMap(\.lists).contains { $0.id == base }, "it cannot be ticked for a trip")
        var full = newEvent(name: "Full, Hiking ticked"); full.activities = [hiking]
        XCTAssertEqual(names(lib.createTrip(full)), ["Boots", "Map"], "it came on a Full trip without being ticked")
        full.activities = [hiking, base]
        XCTAssertEqual(names(lib.createTrip(full)), ["Boots", "Keys", "Map"], "ticked, it did not come")
        // None always packed is allowed: a Full trip is then what is ticked.
        XCTAssertTrue(lib.templates.allSatisfy { $0.role != Library.ALWAYS_PACKED_AREA })
        // The trip made before keeps its lines until its settings are saved (a template
        // change adds or takes no lines on a trip already made) — then it follows.
        XCTAssertEqual(names(lib.trips.first { $0.id == weekend.id }!), ["Boots", "Keys", "Map"])
        XCTAssertNotNil(lib.changeTrip(id: weekend.id) { _ in })
        XCTAssertEqual(names(lib.trips.first { $0.id == weekend.id }!), ["Boots", "Map"], "Trip settings' Save kept an unticked template")

        // INTO Always packed — two at once: every Full trip brings both, Quick neither.
        XCTAssertTrue(lib.setTemplateArea(id: base, area: Library.ALWAYS_PACKED_AREA))
        XCTAssertTrue(lib.setTemplateArea(id: hiking, area: Library.ALWAYS_PACKED_AREA))
        XCTAssertEqual(lib.templates.first { $0.id == hiking }?.role, "base")
        XCTAssertEqual(lib.templates.first { $0.id == hiking }?.group, "", "an always-packed template kept an activity area")
        XCTAssertEqual(lib.memberships.filter { $0.templateId == base }, rowsBefore)
        XCTAssertFalse(lib.activityChoices().flatMap(\.lists).contains { $0.id == hiking }, "an always-packed template is offered to tick")
        XCTAssertEqual(names(lib.createTrip(newEvent(name: "Full, nothing ticked"))), ["Boots", "Keys", "Map"],
                       "a Full trip did not bring every always-packed template")
        var swim = newList(name: "Swim", group: "WET"); swim.items = [newItem(name: "Goggles")]
        lib.saveTemplate(swim)
        var quick = newEvent(name: "Quick swim"); quick.mode = "quick"; quick.activities = [swim.id]
        XCTAssertEqual(names(lib.createTrip(quick)), ["Goggles"], "Quick brought an always-packed template")
        // Its row kept its own note and bag all the way through.
        let row = lib.resolvedTemplate(id: base)!.items.first { $0.name == "Keys" }!
        XCTAssertEqual(row.note, "On the hook")
        XCTAssertEqual(row.container, "Duffel bag")
        // Asking for where it already is changes nothing (not even its date).
        let stamp = lib.templates.first { $0.id == base }!.updatedAt
        XCTAssertTrue(lib.setTemplateArea(id: base, area: Library.ALWAYS_PACKED_AREA))
        XCTAssertEqual(lib.templates.first { $0.id == base }!.updatedAt, stamp)
    }
}
