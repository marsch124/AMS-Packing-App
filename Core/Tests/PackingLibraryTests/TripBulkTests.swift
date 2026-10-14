import XCTest
@testable import PackingCore
@testable import PackingLibrary

final class TripBulkTests: XCTestCase {
    override func setUp() { PackingEnv.reset(); _ = setPhases(DEFAULT_PHASES) }
    override func tearDown() { PackingEnv.reset(); _ = setPhases(DEFAULT_PHASES) }

    /// "Mark everything packed" and "Clear every tick": every line but those set
    /// aside, which are not being packed; the count says how many moved.
    func testEverythingIsTickedAndClearedButWhatIsSetAside() {
        var lib = Library()
        var trip = newEvent(name: "Trip")
        var a = newItem(name: "A"); a.checked = true
        let b = newItem(name: "B"), c = newItem(name: "C")
        var d = newItem(name: "D"); d.skipped = true
        trip.entries = [a, b, c, d]
        lib.trips = [trip]

        XCTAssertEqual(lib.setAllChecked(true, tripId: trip.id), 2, "only the two unticked lines move")
        XCTAssertEqual(lib.trips[0].entries.map(\.checked), [true, true, true, false], "a set-aside line is not ticked")
        XCTAssertEqual(progress(lib.trips[0].entries).done, 3)
        XCTAssertEqual(lib.setAllChecked(true, tripId: trip.id), 0, "nothing left to tick")

        XCTAssertEqual(lib.setAllChecked(false, tripId: trip.id), 3)
        XCTAssertFalse(lib.trips[0].entries.contains { $0.checked }, "a tick survived Clear")
        XCTAssertTrue(lib.trips[0].entries[3].skipped, "Clear touched the set-aside line")
        XCTAssertEqual(lib.setAllChecked(true, tripId: "nope"), 0)
    }

    // MARK: - Undo (0.79, his decision of 13 Oct 2026)

    private func four() -> (Library, TripEvent) {
        var lib = Library()
        var trip = newEvent(name: "Trip")
        var a = newItem(name: "A"); a.checked = true
        let b = newItem(name: "B"), c = newItem(name: "C")
        var d = newItem(name: "D"); d.skipped = true
        trip.entries = [a, b, c, d]
        lib.trips = [trip]
        return (lib, trip)
    }

    private func ticks(_ lib: Library) -> [Bool] { lib.trips[0].entries.map(\.checked) }

    /// A heading's round tick says which lines it changed — not the one ticked already, not the
    /// one set aside — and Undo puts back just those: the line ticked before stays ticked.
    func testAHeadingsTickIsUndoneLineForLine() {
        var (lib, trip) = four()
        let change = lib.setChecked(true, tripId: trip.id, entryIds: trip.entries.map(\.id))
        XCTAssertEqual(change.lines.map(\.id), [trip.entries[1].id, trip.entries[2].id], "only B and C were changed")
        XCTAssertTrue(change.checked)
        XCTAssertEqual(ticks(lib), [true, true, true, false], "a set-aside line was ticked")
        XCTAssertEqual(lib.undo(change), 2)
        XCTAssertEqual(ticks(lib), [true, false, false, false], "Undo did not put back exactly what was there")
        XCTAssertEqual(lib.undo(change), 0, "a second Undo changed something")

        // Untick the same way: what was ticked goes, and comes back.
        let off = lib.setChecked(false, tripId: trip.id, entryIds: trip.entries.map(\.id))
        XCTAssertEqual(off.lines.map(\.id), [trip.entries[0].id])
        XCTAssertEqual(lib.undo(off), 1)
        XCTAssertEqual(ticks(lib), [true, false, false, false])

        // Nothing to change: nothing to undo.
        XCTAssertTrue(lib.setChecked(true, tripId: trip.id, entryIds: [trip.entries[0].id]).isEmpty)
        XCTAssertTrue(lib.setChecked(true, tripId: "nope", entryIds: [trip.entries[1].id]).isEmpty)
    }

    /// Clear every tick in Trip settings, and its Undo: a line he changed since is left as he
    /// left it, a line set aside since is not ticked underneath, a line gone is skipped.
    func testClearingEveryTickIsUndoneButNotWhatHeChangedSince() {
        var (lib, trip) = four()
        _ = lib.setAllChecked(true, tripId: trip.id)
        let cleared = lib.setEveryTick(false, tripId: trip.id)
        XCTAssertEqual(cleared.count, 3)
        XCTAssertFalse(cleared.checked)
        XCTAssertEqual(ticks(lib), [false, false, false, false])
        // Since: B ticked again by hand, C set aside.
        _ = lib.setChecked(true, tripId: trip.id, entryId: trip.entries[1].id)
        _ = lib.setAside(true, tripId: trip.id, entryId: trip.entries[2].id)
        XCTAssertEqual(lib.undo(cleared), 1, "only A should go back")
        XCTAssertEqual(ticks(lib), [true, true, false, false], "C was ticked underneath its set-aside")
        // A trip rebuilt without A: nothing to put back, nothing breaks.
        let again = lib.setEveryTick(false, tripId: trip.id)
        lib.trips[0].entries.removeFirst()
        XCTAssertEqual(lib.undo(again), 1, "B is still there to go back")
        XCTAssertEqual(lib.undo(TicksChanged(tripId: "nope", checked: false, lines: again.lines)), 0)
    }

    /// A kit checked before each trip is packed when all inside is ticked; Clear empties what
    /// is inside it (unticking a kit starts it over) — Undo packs it again with all of it, and
    /// a kit still waiting for what is inside refuses a heading's tick, so it is no change.
    func testUndoingAClearPacksAKitAgainWithWhatWasInside() {
        var lib = ThingKitsTests.library()
        var t = newEvent(name: "Weekend in the hills", startDate: "2026-10-17", endDate: "2026-10-20")
        t.activities = lib.templates.filter { $0.name == "Hiking" }.map(\.id)
        let trip = lib.createTrip(t)
        let wash = trip.entries.first { $0.name == "Wash bag" }!.id
        let brush = ThingKitsTests.id(lib, "Toothbrush"), soap = ThingKitsTests.id(lib, "Soap")
        func washLine() -> Item { lib.trips[0].entries.first { $0.id == wash }! }

        XCTAssertTrue(lib.setKitContentTicked(true, tripId: trip.id, entryId: wash, contentId: brush))
        XCTAssertTrue(lib.setChecked(true, tripId: trip.id, entryIds: [wash]).isEmpty, "a kit with the soap to go was ticked")
        XCTAssertEqual(lib.kitOnLine(washLine())!.ticked, [brush], "the refused tick lost what was ticked inside")
        XCTAssertTrue(lib.setKitContentTicked(true, tripId: trip.id, entryId: wash, contentId: soap))
        XCTAssertTrue(washLine().checked, "the last one ticked packs the kit")

        let cleared = lib.setEveryTick(false, tripId: trip.id)
        XCTAssertTrue(cleared.lines.contains { $0.id == wash })
        XCTAssertEqual(lib.kitOnLine(washLine())!.ticked, [], "Clear left ticks inside the kit")
        XCTAssertEqual(lib.undo(cleared), cleared.count)
        XCTAssertTrue(washLine().checked, "Undo did not pack the kit again")
        XCTAssertEqual(lib.kitOnLine(washLine())!.ticked, [brush, soap], "the kit came back without what was inside")
        XCTAssertNil(washLine().extra[KIT_TICKED_KEY], "a packed kit keeps no list of ticks")

        // A heading's untick of the packed kit, undone: packed again, all inside ticked.
        let off = lib.setChecked(false, tripId: trip.id, entryIds: [wash])
        XCTAssertEqual(off.count, 1)
        XCTAssertEqual(lib.undo(off), 1)
        XCTAssertTrue(washLine().checked)
        XCTAssertEqual(lib.kitOnLine(washLine())!.ticked, [brush, soap])
    }

    /// A tick brings a line's usual pocket; Undo of a heading's tick takes it away again — the
    /// line is as it was, not unticked with a pocket chosen.
    func testUndoTakesAwayThePocketTheTickChose() {
        var lib = Library()
        let backpack = lib.addBag(name: "Backpack")!.id
        XCTAssertTrue(lib.addPocket(bagId: backpack, name: "Front pocket"))
        lib.saveTemplate(newList(name: "Base", role: "base"))
        let base = lib.templates.first { $0.role == "base" }!.id
        let charger = lib.addThing(name: "Charger")!.id
        _ = lib.updateThing(id: charger) { $0.container = "Backpack" }
        _ = lib.setOnTemplate(itemId: charger, templateId: base, on: true)
        XCTAssertTrue(lib.setUsualPocket(thingId: charger, pocket: "Front pocket"))
        let trip = lib.createTrip(newEvent(name: "Away", startDate: "2026-10-01", endDate: "2026-10-05"))
        let line = trip.entries.first { $0.name == "Charger" }!.id

        let change = lib.setChecked(true, tripId: trip.id, entryIds: [line])
        XCTAssertEqual(Library.pocket(lib.trips[0].entries[0]), "Front pocket")
        XCTAssertEqual(lib.undo(change), 1)
        XCTAssertFalse(lib.trips[0].entries[0].checked)
        XCTAssertNil(lib.trips[0].entries[0].extra[POCKET_KEY], "Undo left the pocket the tick chose")
    }

    private func rainy() -> (Library, String) {
        var lib = Library()
        var hike = newList(name: "Hiking", group: "GA")
        var coat = newItem(name: "Rain shell"); coat.weather = ["rain"]; coat.weight = 420; coat.category = "Clothing"
        hike.items = [coat, newItem(name: "Walking poles")]
        lib.saveTemplate(hike)
        var trip = newEvent(name: "Two nights out", startDate: "2026-10-03", endDate: "2026-10-05")
        trip.nights = 2
        trip.activities = lib.templates.filter { $0.name == "Hiking" }.map { $0.id }
        trip.entries = buildTotalEntries(trip, lib.resolvedTemplates())
        lib.trips = [trip]
        let days = (0...2).map { n in
            WeatherDay(date: "2026-10-0\(3 + n)", code: 61, tmax: 8, tmin: 2, precipProb: 90, wind: 24)
        }
        _ = lib.setWeather(tripId: trip.id, place: "Testville", lat: 10.5, lon: 20.5,
                           snapshot: WeatherSnapshot(place: "Testville, SE", lat: 10.5, lon: 20.5,
                                                     fetchedAt: nowISO(), daily: days))
        return (lib, trip.id)
    }

    /// The weather card's "Add all": everything it asks for arrives once, and then
    /// nothing is asked for.
    func testAddAllTakesEveryWeatherSuggestionOnce() {
        var (lib, id) = rainy()
        let asked = lib.weatherMissing(tripId: id)
        XCTAssertGreaterThanOrEqual(asked.count, 2, "the rainy trip should ask for several things")
        let before = lib.trip(id)?.entries.count ?? 0
        XCTAssertEqual(lib.addAllWeatherGear(tripId: id), asked.count)
        XCTAssertEqual(lib.trip(id)?.entries.count, before + asked.count)
        XCTAssertTrue(lib.weatherMissing(tripId: id).isEmpty, "still asking after Add all")
        XCTAssertEqual(lib.addAllWeatherGear(tripId: id), 0, "a second Add all added again")
    }

    /// His own weather gear keeps where it came from (the web app's entryFromWeatherSpec),
    /// so the review credits that thing — and its weight counts in the bags.
    func testHisOwnWeatherGearKeepsItsSource() {
        var (lib, id) = rainy()
        guard let shell = lib.weatherMissing(tripId: id).first(where: { $0.name == "Rain shell" }) else {
            return XCTFail("his rain shell is not suggested")
        }
        let line = lib.addWeatherGear(tripId: id, shell)
        XCTAssertEqual(line?.sourceItemId, shell.sourceItemId)
        XCTAssertNotNil(line?.sourceItemId, "the line forgot the thing it came from")
        XCTAssertEqual(line?.weight, 420)
        XCTAssertEqual(line?.category, "Clothing")
        XCTAssertEqual(lib.trip(id)?.entries.last?.sourceItemId, shell.sourceItemId, "not stored on the trip")
        XCTAssertTrue(lib.trip(id)?.entries.last?.custom ?? false, "a weather line must survive a rebuild")
    }
}
