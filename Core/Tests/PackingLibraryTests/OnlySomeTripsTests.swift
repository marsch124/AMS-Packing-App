import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// "Only on some trips", set once on the THING (spec 07 part 14) — his words, 10 Oct 2026:
/// "if I have an item on five templates, I need to change this in five places. Doesn't seem
/// optimal." Invented data only — this repository is public.
final class OnlySomeTripsTests: XCTestCase {
    override func setUp() { PackingEnv.freeze(at: "2026-10-10T09:00:00.000Z"); _ = setPhases(DEFAULT_PHASES) }
    override func tearDown() { PackingEnv.reset(); _ = setPhases(DEFAULT_PHASES) }

    /// A base template with a passport; Hiking (an activity) and Swim (a workout) — and a
    /// Towel on all three, a Lamp on the base template and Hiking.
    private func library() -> Library {
        var lib = Library()
        var base = newList(name: "Common base", role: "base")
        base.items = [newItem(name: "Passport"), newItem(name: "Towel"), newItem(name: "Lamp")]
        lib.saveTemplate(base)
        var hiking = newList(name: "Hiking", group: "GA")
        hiking.items = [newItem(name: "Boots"), newItem(name: "Towel"), newItem(name: "Lamp")]
        lib.saveTemplate(hiking)
        var swim = newList(name: "Swim", group: "WET")
        swim.items = [newItem(name: "Goggles"), newItem(name: "Towel")]
        lib.saveTemplate(swim)
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
    /// A trip made from Hiking (and the base template, as every full trip is).
    private func trip(_ lib: inout Library, season: String, transport: String = "Car", also: [String] = []) -> TripEvent {
        var t = newEvent(name: "Away", startDate: "2026-10-20", endDate: "2026-10-22")
        t.activities = (["Hiking"] + also).map { tpl(lib, $0) }
        t.season = season
        t.transport = transport
        return lib.createTrip(t)
    }
    private func names(_ t: TripEvent) -> [String] { t.entries.map(\.name) }

    // MARK: - Following, per kind

    /// Set once on the thing, every template it is on says it — and a row with its own
    /// answer for one kind still follows the thing for the others.
    func testEveryRowFollowsTheThingPerKindUnlessItSetsItsOwn() {
        var lib = library()
        let towel = thing(lib, "Towel")
        XCTAssertTrue(lib.setThingLimits(id: towel, TripLimits(seasons: ["Summer"], transports: ["Car"])))
        XCTAssertEqual(lib.items.first { $0.id == towel }!.extra["onlySeasons"], ["Summer"])
        XCTAssertNil(lib.items.first { $0.id == towel }!.extra["onlyContexts"], "an empty kind is no key")
        for t in ["Common base", "Hiking", "Swim"] {
            XCTAssertEqual(row(lib, "Towel", on: t).seasons, ["Summer"], "\(t) does not follow the thing's Season")
            XCTAssertEqual(row(lib, "Towel", on: t).transports, ["Car"], "\(t) does not follow the thing's Transport")
            XCTAssertEqual(place(lib, "Towel", on: t).seasons, [], "\(t): the thing's answer was copied onto the row")
            XCTAssertEqual(Library.onlyOnWords(row(lib, "Towel", on: t), on: lib.resolvedTemplate(id: tpl(lib, t))),
                           "Only on: Summer \u{00B7} Car")
        }
        // Hiking: its own Transport. Swim: always, whatever season (its own "any").
        lib.updateMembership(memId: place(lib, "Towel", on: "Hiking").id) { $0.transports = ["Plane"] }
        lib.updateMembership(memId: place(lib, "Towel", on: "Swim").id) { Library.setAnyHere(&$0, .seasons, true) }
        XCTAssertEqual(row(lib, "Towel", on: "Hiking").transports, ["Plane"], "Hiking's own Transport")
        XCTAssertEqual(row(lib, "Towel", on: "Hiking").seasons, ["Summer"], "Hiking still follows the thing's Season")
        XCTAssertEqual(row(lib, "Towel", on: "Swim").seasons, [], "Swim's own any season")
        XCTAssertEqual(row(lib, "Towel", on: "Swim").transports, ["Car"], "Swim still follows the thing's Transport")
        XCTAssertEqual(Library.onlyOnWords(row(lib, "Towel", on: "Swim"), on: lib.resolvedTemplate(id: tpl(lib, "Swim"))),
                       "Only on: Car")

        // A change on the thing reaches every row that follows it, and no own answer.
        XCTAssertTrue(lib.setThingLimits(id: towel, TripLimits(seasons: ["Winter"], transports: ["RV"])))
        XCTAssertEqual(row(lib, "Towel", on: "Common base").seasons, ["Winter"])
        XCTAssertEqual(row(lib, "Towel", on: "Hiking").seasons, ["Winter"])
        XCTAssertEqual(row(lib, "Towel", on: "Hiking").transports, ["Plane"], "Hiking's own Transport was overwritten")
        XCTAssertEqual(row(lib, "Towel", on: "Swim").seasons, [], "Swim's own any season was overwritten")
        XCTAssertEqual(row(lib, "Towel", on: "Swim").transports, ["RV"])

        // The thing's page names the templates that set their own.
        XCTAssertEqual(lib.ownLimitWords(thingId: towel), "Set on the template instead: Hiking (Transport), Swim (Season).")
        XCTAssertEqual(lib.ownLimitWords(thingId: towel, on: [tpl(lib, "Hiking")]),
                       "Set on the template instead: Hiking (Transport).")
        XCTAssertEqual(lib.ownLimitWords(thingId: thing(lib, "Lamp")), "")
        // What the row's page says under its pills.
        XCTAssertEqual(Library.limitFromWords(.seasons, shown: ["Winter"], thing: ["Winter"]), "Same as the thing: Winter")
        XCTAssertEqual(Library.limitFromWords(.catering, shown: [], thing: []), "Same as the thing: any food")
        XCTAssertEqual(Library.limitFromWords(.seasons, shown: [], thing: ["Winter"]),
                       "Own choice on this template. The thing says: Winter.")
        XCTAssertEqual(Library.limitFromWords(.catering, shown: ["self"], thing: ["eatout", "mixed"]),
                       "Own choice on this template. The thing says: Eating out, Mix of both.")
    }

    /// Rows stored before 0.73 keep their answers as their own; a thing with no answer
    /// changes nothing anywhere.
    func testRowsFromBeforeKeepTheirOwnAndAThingWithNoAnswerChangesNothing() {
        var lib = library()
        lib.updateMembership(memId: place(lib, "Towel", on: "Hiking").id) { $0.seasons = ["Summer"] }
        let before = lib.resolvedTemplates()
        XCTAssertFalse(lib.setThingLimits(id: thing(lib, "Towel"), TripLimits()), "nothing to write")
        XCTAssertEqual(lib.resolvedTemplates(), before)
        XCTAssertEqual(lib.setThingLimits(id: thing(lib, "Towel"), TripLimits(seasons: ["Winter"])), true)
        XCTAssertEqual(row(lib, "Towel", on: "Hiking").seasons, ["Summer"], "a row's answer from before is its own")
        XCTAssertEqual(row(lib, "Towel", on: "Common base").seasons, ["Winter"])
    }

    // MARK: - The row's page and the thing's page store

    /// The row's Save: the thing's answer = follows; nothing while the thing has a limit =
    /// its own "any"; anything else its own — words the app does not know kept.
    func testARowSavedFromItsPageFollowsOwnsOrIsAnyHere() {
        var lib = library()
        let towel = thing(lib, "Towel")
        lib.setThingLimits(id: towel, TripLimits(seasons: ["Summer"], contexts: ["Indoor"]))
        let swim = tpl(lib, "Swim"), mem = place(lib, "Towel", on: "Swim").id
        func save(_ seasons: Set<String>, contexts: Set<String> = ["Indoor"]) {
            XCTAssertTrue(lib.saveRow(templateId: swim, memId: mem, Library.RowAnswers(seasons: seasons, contexts: contexts)))
        }
        // Shown as the thing says it, saved untouched: it follows.
        save(["Summer"])
        XCTAssertEqual(place(lib, "Towel", on: "Swim").seasons, [])
        XCTAssertTrue(Library.anyHere(place(lib, "Towel", on: "Swim")).isEmpty)
        // Summer tapped off: always on Swim.
        save([])
        XCTAssertEqual(Library.anyHere(place(lib, "Towel", on: "Swim")), [.seasons])
        XCTAssertEqual(place(lib, "Towel", on: "Swim").extra[ONLY_ANY_HERE_KEY], ["seasons"])
        XCTAssertEqual(row(lib, "Towel", on: "Swim").seasons, [])
        XCTAssertEqual(row(lib, "Towel", on: "Swim").contexts, ["Indoor"], "Context still follows the thing")
        // Its own Winter.
        save(["Winter"])
        XCTAssertEqual(place(lib, "Towel", on: "Swim").seasons, ["Winter"])
        XCTAssertNil(place(lib, "Towel", on: "Swim").extra[ONLY_ANY_HERE_KEY], "an own list is no own any")
        // "Same as the thing" again.
        save(["Summer"])
        XCTAssertEqual(place(lib, "Towel", on: "Swim").seasons, [])
        XCTAssertNil(place(lib, "Towel", on: "Swim").extra[ONLY_ANY_HERE_KEY])
        lib.setThingLimits(id: towel, TripLimits(seasons: ["Winter"], contexts: ["Indoor"]))
        XCTAssertEqual(row(lib, "Towel", on: "Swim").seasons, ["Winter"], "the row follows the thing again")

        // A word the app does not know, on the thing: shown and kept by a row that follows.
        lib.setThingLimits(id: towel, TripLimits(seasons: ["summer"]))
        XCTAssertEqual(row(lib, "Towel", on: "Swim").seasons, ["summer"])
        save(["summer"], contexts: [])
        XCTAssertEqual(place(lib, "Towel", on: "Swim").seasons, [], "the thing's own word made the row its own")
        XCTAssertEqual(lib.items.first { $0.id == towel }!.extra["onlySeasons"], ["summer"])
        // …and on the thing's page: kept while on, gone when switched off.
        lib.setThingLimits(id: towel, TripLimits(seasons: ["Winter", "summer"]))
        XCTAssertEqual(lib.items.first { $0.id == towel }!.extra["onlySeasons"], ["Winter", "summer"], "the app's words first")
        lib.setThingLimits(id: towel, TripLimits(seasons: ["Winter"]))
        XCTAssertEqual(lib.items.first { $0.id == towel }!.extra["onlySeasons"], ["Winter"])
    }

    /// Rule 4 on the thing's Save: the rows he set one by one go back to following the
    /// thing once it says the same — so the next change is made in ONE place.
    func testRowsThatSayWhatTheThingNowSaysFollowIt() {
        var lib = library()
        let lamp = thing(lib, "Lamp")
        for t in ["Common base", "Hiking"] {
            lib.updateMembership(memId: place(lib, "Lamp", on: t).id) { $0.seasons = ["Winter"] }
        }
        lib.updateMembership(memId: place(lib, "Lamp", on: "Hiking").id) { $0.transports = ["Car"] }
        XCTAssertTrue(lib.setThingLimits(id: lamp, TripLimits(seasons: ["Winter"])))
        for t in ["Common base", "Hiking"] {
            XCTAssertEqual(place(lib, "Lamp", on: t).seasons, [], "\(t) still keeps its own Winter")
        }
        XCTAssertEqual(place(lib, "Lamp", on: "Hiking").transports, ["Car"], "another kind of its own is kept")
        lib.setThingLimits(id: lamp, TripLimits(seasons: ["Summer", "Winter"]))
        XCTAssertEqual(row(lib, "Lamp", on: "Common base").seasons, ["Summer", "Winter"], "one change reaches every template")
        XCTAssertEqual(row(lib, "Lamp", on: "Hiking").seasons, ["Summer", "Winter"])
        // An own "any" the thing now also says is the same as the thing too.
        lib.updateMembership(memId: place(lib, "Lamp", on: "Hiking").id) { Library.setAnyHere(&$0, .seasons, true) }
        lib.setThingLimits(id: lamp, TripLimits())
        XCTAssertTrue(Library.anyHere(place(lib, "Lamp", on: "Hiking")).isEmpty)
    }

    // MARK: - Saving a template

    /// Every way a template is saved from its resolved rows — a thing typed on, picked on,
    /// a row taken off — leaves each row following the thing: the thing's answers are never
    /// frozen onto its rows. A row's own answer, its own "any" included, survives.
    func testSavingATemplateNeverFreezesTheThingsAnswersOntoItsRows() {
        var lib = library()
        let towel = thing(lib, "Towel")
        lib.setThingLimits(id: towel, TripLimits(seasons: ["Summer"], catering: ["self"]))
        lib.updateMembership(memId: place(lib, "Towel", on: "Swim").id) {
            Library.setAnyHere(&$0, .seasons, true); $0.transports = ["Plane"]
        }
        XCTAssertNotNil(lib.addToTemplate(templateId: tpl(lib, "Swim"), name: "Fins"))            // saves Swim
        XCTAssertNotNil(lib.addToTemplate(templateId: tpl(lib, "Hiking"), name: "Map"))           // saves Hiking
        let boots = lib.resolvedTemplate(id: tpl(lib, "Hiking"))!.items.first { $0.name == "Boots" }!.memId!
        XCTAssertTrue(lib.removeFromTemplate(templateId: tpl(lib, "Hiking"), memId: boots))       // and again
        let shed = newList(name: "Shed")
        lib.saveTemplate(shed)
        XCTAssertEqual(lib.putOnTemplate(templateId: shed.id, itemIds: [towel]), 1)               // a new row
        for t in ["Common base", "Hiking", "Shed"] {
            XCTAssertEqual(place(lib, "Towel", on: t).seasons, [], "\(t): the Season was frozen onto the row")
            XCTAssertEqual(place(lib, "Towel", on: t).catering, [], "\(t): the Food was frozen onto the row")
            XCTAssertNil(place(lib, "Towel", on: t).extra[ONLY_ANY_HERE_KEY], "\(t): marked as its own any")
        }
        XCTAssertEqual(Library.anyHere(place(lib, "Towel", on: "Swim")), [.seasons], "Swim's own any was lost")
        XCTAssertEqual(place(lib, "Towel", on: "Swim").transports, ["Plane"], "Swim's own Transport was lost")
        XCTAssertEqual(place(lib, "Towel", on: "Swim").catering, [], "Swim's Food was frozen")
        // …so the next change on the thing still reaches them all.
        lib.setThingLimits(id: towel, TripLimits(seasons: ["Winter"]))
        XCTAssertEqual(row(lib, "Towel", on: "Shed").seasons, ["Winter"])
        XCTAssertEqual(row(lib, "Towel", on: "Hiking").catering, [])
        XCTAssertEqual(row(lib, "Towel", on: "Swim").seasons, [])
    }

    // MARK: - Trips

    /// Winter set once on a thing on two templates: a summer trip leaves it off from both, a
    /// winter trip has it — and the rebuild (Trip settings → Save) does the same. A row's own
    /// answer wins on its template.
    func testATripAndItsRebuildPackByWhatEachRowReallySays() {
        var lib = library()
        let lamp = thing(lib, "Lamp")
        lib.setThingLimits(id: lamp, TripLimits(seasons: ["Winter"]))
        let summer = trip(&lib, season: "Summer")
        XCTAssertFalse(names(summer).contains("Lamp"), "a summer trip has the winter lamp: \(names(summer))")
        let winter = trip(&lib, season: "Winter")
        XCTAssertEqual(names(winter).filter { $0 == "Lamp" }.count, 1, "a winter trip has the lamp once: \(names(winter))")

        // Trip settings: the summer trip made a winter one, and back.
        XCTAssertNotNil(lib.changeTrip(id: summer.id) { $0.season = "Winter" })
        XCTAssertTrue(names(lib.trips.first { $0.id == summer.id }!).contains("Lamp"), "the rebuild did not bring the lamp")
        XCTAssertNotNil(lib.changeTrip(id: summer.id) { $0.season = "Summer" })
        XCTAssertFalse(names(lib.trips.first { $0.id == summer.id }!).contains("Lamp"), "the rebuild kept the winter lamp")

        // Hiking's own: any season. Hiking now brings it on a summer trip; the base still not.
        lib.updateMembership(memId: place(lib, "Lamp", on: "Hiking").id) { Library.setAnyHere(&$0, .seasons, true) }
        XCTAssertNotNil(lib.changeTrip(id: summer.id) { $0.season = "Summer" })
        let lines = lib.trips.first { $0.id == summer.id }!.entries.filter { $0.name == "Lamp" }
        XCTAssertEqual(lines.map(\.sourceListId), [tpl(lib, "Hiking")], "the row's own answer did not win")

        // A changed answer reaches a trip still ahead only through a rebuild: its open line
        // is refreshed, never taken off (spec 07 part 14, rule 8).
        var w = trip(&lib, season: "Winter")
        XCTAssertTrue(lib.setThingLimits(id: lamp, TripLimits(seasons: ["Summer"])))
        w = lib.trips.first { $0.id == w.id }!
        XCTAssertTrue(names(w).contains("Lamp"), "the line was taken off a trip already made")
        XCTAssertNotNil(lib.changeTrip(id: w.id) { _ in })
        let rebuilt = lib.trips.first { $0.id == w.id }!.entries.filter { $0.name == "Lamp" }
        XCTAssertEqual(rebuilt.map(\.sourceListId), [tpl(lib, "Hiking")], "after the rebuild only Hiking's own any brings it")
    }

    /// Context on the thing counts on a workout template only, as a row's does.
    func testTheThingsContextCountsOnWorkoutTemplatesOnly() {
        var lib = library()
        lib.setThingLimits(id: thing(lib, "Towel"), TripLimits(contexts: ["Indoor"]))
        var t = newEvent(name: "Lake", startDate: "2026-10-20", endDate: "2026-10-21")
        t.activities = [tpl(lib, "Swim")]
        t.mode = "quick"                                     // the workout's own things only
        t.activityContexts = [tpl(lib, "Swim"): ["Outdoor"]]
        XCTAssertFalse(names(lib.createTrip(t)).contains("Towel"), "an outdoor swim took the indoor towel")
        t.activityContexts = [tpl(lib, "Swim"): ["Indoor"]]
        XCTAssertTrue(names(lib.createTrip(t)).contains("Towel"))
        // On Hiking (no workout) the Context says nothing.
        var h = newEvent(name: "Hills", startDate: "2026-10-20", endDate: "2026-10-21")
        h.activities = [tpl(lib, "Hiking")]
        h.mode = "quick"
        h.contexts = ["Outdoor"]
        XCTAssertTrue(names(lib.createTrip(h)).contains("Towel"), "Context narrowed a template that is no workout")
        XCTAssertEqual(lib.ownLimitWords(thingId: thing(lib, "Towel")), "")
    }

    /// A kit in a content's place packs by the content's answer there.
    func testAKitInAContentsPlacePacksByTheContentsAnswer() {
        var lib = library()
        let pouch = lib.addThing(name: "Pouch")!
        XCTAssertTrue(lib.setKit(kitId: pouch.id, contents: [thing(lib, "Lamp")]))
        lib.setThingLimits(id: thing(lib, "Lamp"), TripLimits(seasons: ["Winter"]))
        XCTAssertFalse(names(trip(&lib, season: "Summer")).contains("Pouch"), "the pouch came for a winter-only lamp")
        XCTAssertTrue(names(trip(&lib, season: "Winter")).contains("Pouch"))
    }

    // MARK: - Kept, synced, backed up, restored — and the web app

    func testTheAnswersAreStoredSyncedBackedUpAndRestoredAndTheWebModelSeesAPlainThing() throws {
        var lib = library()
        let towel = thing(lib, "Towel")
        lib.setThingLimits(id: towel, TripLimits(seasons: ["Summer"], transports: ["Car", "Plane"], catering: ["self"]))
        lib.updateMembership(memId: place(lib, "Towel", on: "Swim").id) { Library.setAnyHere(&$0, .seasons, true) }
        lib.updateMembership(memId: place(lib, "Towel", on: "Hiking").id) { $0.transports = ["RV"] }
        let resolved = lib.resolvedTemplates()

        // The store and iCloud: records and back.
        let stored = Library(records: lib.records())
        XCTAssertEqual(stored.items.sorted { $0.id < $1.id }, lib.items.sorted { $0.id < $1.id })
        XCTAssertEqual(stored.memberships.sorted { $0.id < $1.id }, lib.memberships.sorted { $0.id < $1.id })
        XCTAssertEqual(stored.resolvedTemplates(), resolved)

        // A backup as this app writes it, and the older kind rebuilt from the rows: every
        // row reads exactly what it read.
        for (kind, data) in [("as written", lib.backupData(exportedAt: "2026-10-10T09:00:00.000Z")),
                             ("older", BackupTests.olderFile(lib, exportedAt: "2026-10-10T09:00:00.000Z"))] {
            let (back, report) = try BackupTests.read(data)
            XCTAssertTrue(report.isFaithful, "\(kind): " + report.mismatches.joined(separator: "; "))
            XCTAssertEqual(back.resolvedTemplates().map { $0.items.map { [$0.seasons, $0.transports, $0.catering] } },
                           resolved.map { $0.items.map { [$0.seasons, $0.transports, $0.catering] } }, kind)
            XCTAssertEqual(Library.thingLimits(back.items.first { $0.id == towel }!),
                           TripLimits(seasons: ["Summer"], transports: ["Car", "Plane"], catering: ["self"]), kind)
            // …and the next change on the thing still reaches the rows that follow it.
            var after = back
            after.setThingLimits(id: towel, TripLimits(seasons: ["Winter"]))
            XCTAssertEqual(after.resolvedTemplate(id: tpl(lib, "Common base"))!.items.first { $0.name == "Towel" }!.seasons,
                           ["Winter"], "\(kind): the rows no longer follow the thing")
            XCTAssertEqual(after.resolvedTemplate(id: tpl(lib, "Swim"))!.items.first { $0.name == "Towel" }!.seasons,
                           [], "\(kind): Swim's own any")
        }
        let (asWritten, _) = try BackupTests.read(lib.backupData(exportedAt: "2026-10-10T09:00:00.000Z"))
        XCTAssertEqual(BackupTests.differences(lib, asWritten), [], "a restore does not bring back what was here")

        // The web app reads `lists`: each row carries what it really does.
        let file = lib.backupFile(exportedAt: "2026-10-10T09:00:00.000Z")
        let baseRow = file.lists.first { $0.name == "Common base" }!.items.first { $0.name == "Towel" }!
        XCTAssertEqual(baseRow.seasons, ["Summer"])
        XCTAssertEqual(baseRow.transports, ["Car", "Plane"])
        // The web app's own model (PackingCore) resolves the stored place as it always did:
        // the thing's keys ride along unread, and the parity check has nothing new to see.
        let plain = resolveMembership(lib.items.first { $0.id == towel }!, place(lib, "Towel", on: "Common base"))
        XCTAssertEqual(plain.seasons, [])
        XCTAssertEqual(Item(json: lib.items.first { $0.id == towel }!.json), lib.items.first { $0.id == towel }!)
        XCTAssertEqual(Membership(json: place(lib, "Towel", on: "Swim").json), place(lib, "Towel", on: "Swim"))
    }
}
