import XCTest
@testable import PackingCore
@testable import PackingLibrary

final class TripEditsTests: XCTestCase {
    override func setUp() { PackingEnv.freeze() }
    override func tearDown() { PackingEnv.reset() }

    /// His two test trips had no way out (the gap list, 2026-09-26). A deleted trip
    /// takes its lines with it — out of the records too, so no device keeps them —
    /// and leaves every thing, list and other trip as it was.
    func testADeletedTripTakesOnlyItself() {
        var lib = Library()
        lib.saveTemplate({ var l = newList(name: "Hike"); l.items = [newItem(name: "Boots"), newItem(name: "Map")]; return l }())
        var keep = newEvent(name: "Keep me", startDate: "2026-10-01", endDate: "2026-10-02")
        keep.entries = [newItem(name: "Boots")]
        var gone = newEvent(name: "Test trip", startDate: "2026-09-26", endDate: "2026-09-27")
        gone.entries = [newItem(name: "Map"), newItem(name: "Towel")]
        lib.trips = [keep, gone]
        let things = lib.items.count, lists = lib.templates.count, rows = lib.memberships.count
        let lines = lib.records().filter { $0.table == .entries }.count

        XCTAssertTrue(lib.deleteTrip(id: gone.id))
        XCTAssertEqual(lib.trips.map(\.name), ["Keep me"], "only the chosen trip goes")
        XCTAssertEqual(lib.records().filter { $0.table == .entries }.count, lines - 2, "its lines leave the records")
        XCTAssertEqual(lib.items.count, things, "no thing is touched")
        XCTAssertEqual(lib.templates.count, lists, "no list is touched")
        XCTAssertEqual(lib.memberships.count, rows)
        XCTAssertFalse(lib.deleteTrip(id: gone.id), "a trip that is not there: false")
    }

    /// A trip's folds go with it (the spec pass, 5 Oct 2026: they were kept for ever),
    /// and a fold made sweeps out those of trips this device no longer has.
    func testATripsFoldsGoWithIt() {
        let a = TripFolds.key(trip: "trip-a", view: "when", heading: "Morning list")
        let b = TripFolds.key(trip: "trip-b", view: "container", heading: "Day pack")
        var raw = TripFolds.toggled("", a, trips: ["trip-a", "trip-b"])
        raw = TripFolds.toggled(raw, b, trips: ["trip-a", "trip-b"])
        XCTAssertTrue(TripFolds.isFolded(raw, a)); XCTAssertTrue(TripFolds.isFolded(raw, b))
        XCTAssertFalse(TripFolds.isFolded(raw, TripFolds.key(trip: "trip-a", view: "container", heading: "Morning list")),
                       "a fold is per sorting")
        raw = TripFolds.toggled(raw, a, trips: ["trip-a", "trip-b"])
        XCTAssertFalse(TripFolds.isFolded(raw, a), "a second press did not open it")
        raw = TripFolds.toggled(raw, a, trips: ["trip-a", "trip-b"])
        XCTAssertEqual(TripFolds.without(trip: "trip-a", in: raw), b, "the deleted trip's folds stayed")
        // trip-b is gone from this device: the next fold anywhere takes its folds away.
        let c = TripFolds.key(trip: "trip-a", view: "when", heading: "Day before")
        XCTAssertEqual(TripFolds.toggled(raw, c, trips: ["trip-a"]), [a, c].joined(separator: "\n"),
                       "a gone trip's folds were kept")
    }
}

final class SetPlaceTests: XCTestCase {
    override func setUp() { PackingEnv.freeze() }
    override func tearDown() { PackingEnv.reset() }

    /// His ask (2026-09-26): a place set from the trip's "No place set" goes onto
    /// the THING and onto every line of it on this trip (a thing on two lists sits
    /// on the trip twice); a typed line changes alone; a new place joins his list.
    func testAPlaceSetOnTheTripReachesTheThingAndItsTwin() {
        var lib = Library()
        // Different bags on the two lists — as his Underwear (Checked luggage / RV box).
        lib.saveTemplate({ var l = newList(name: "Run"); l.items = [newItem(name: "Socks", container: "Duffel bag"), newItem(name: "Cap")]; return l }())
        lib.saveTemplate({ var l = newList(name: "Swim"); l.items = [newItem(name: "Socks", container: "Swim bag")]; return l }())
        var draft = newEvent(name: "Weekend", startDate: "2026-10-03", endDate: "2026-10-04")
        draft.activities = lib.templates.map(\.id)
        draft.mode = "quick"
        let trip = lib.createTrip(draft)
        let custom = lib.addCustomLine(tripId: trip.id, name: "Tripod")!
        let socks = lib.trips[0].entries.filter { $0.name == "Socks" }
        XCTAssertEqual(socks.count, 2, "the same thing, on the trip from two lists")

        XCTAssertTrue(lib.setPlace(" Hall shelf ", tripId: trip.id, entryId: socks[0].id))
        let lines = lib.trips[0].entries
        XCTAssertEqual(lines.filter { $0.name == "Socks" }.map(\.storage), ["Hall shelf", "Hall shelf"], "both lines of the thing")
        XCTAssertEqual(lib.items.first { $0.name == "Socks" }?.storage, "Hall shelf", "the thing itself, for every later trip")
        XCTAssertEqual(lines.first { $0.name == "Cap" }?.storage, "", "another thing is not touched")
        XCTAssertTrue(lib.storagePlaces().contains("Hall shelf"), "a new place joins his list")

        XCTAssertTrue(lib.setPlace("Garage", tripId: trip.id, entryId: custom.id))
        XCTAssertEqual(lib.trips[0].entries.first { $0.id == custom.id }?.storage, "Garage", "a typed line gets its place")
        XCTAssertFalse(lib.setPlace("  ", tripId: trip.id, entryId: custom.id), "an empty place is refused")
    }
}

/// The gap list's first High item (2026-09-27): a trip's settings changed after it
/// is made, and its list rebuilt without losing what he did.
final class ChangeTripTests: XCTestCase {
    override func setUp() { PackingEnv.freeze() }
    override func tearDown() { PackingEnv.reset() }

    func testAChangedTripRebuildsAndKeepsWhatHeDid() {
        var lib = Library()
        lib.saveTemplate({ var l = newList(name: "Hike"); l.items = [newItem(name: "Boots"), newItem(name: "Map")]; return l }())
        lib.saveTemplate({ var l = newList(name: "Run"); l.items = [newItem(name: "Shoes"), newItem(name: "Cap")]; return l }())
        let hike = lib.templates.first { $0.name == "Hike" }!.id, run = lib.templates.first { $0.name == "Run" }!.id
        var draft = newEvent(name: "Weekend", startDate: "2026-10-03", endDate: "2026-10-04")
        draft.activities = [hike]; draft.mode = "quick"
        let trip = lib.createTrip(draft)
        let boots = lib.trips[0].entries.first { $0.name == "Boots" }!.id
        lib.setChecked(true, tripId: trip.id, entryId: boots)
        let tripod = lib.addCustomLine(tripId: trip.id, name: "Tripod")!.id

        // Run instead of Hike, a new name, a longer stay.
        let r = lib.changeTrip(id: trip.id) { t in
            t.activities = [run]; t.name = " Long weekend "; t.endDate = "2026-10-06"
        }
        let names = Set(lib.trips[0].entries.map(\.name))
        XCTAssertEqual(r, Library.TripRebuilt(added: 2, removed: 1), "Shoes and Cap in, the unticked Map out")
        XCTAssertTrue(names.isSuperset(of: ["Shoes", "Cap"]), "Run's things arrived")
        XCTAssertFalse(names.contains("Map"), "an unticked line no longer asked for goes")
        XCTAssertTrue(lib.trips[0].entries.contains { $0.id == boots && $0.checked }, "a TICKED line stays, ticked")
        XCTAssertTrue(lib.trips[0].entries.contains { $0.id == tripod }, "a hand-added line stays")
        XCTAssertEqual(lib.trips[0].name, "Long weekend")
        XCTAssertEqual(lib.trips[0].nights, 3)

        XCTAssertNil(lib.changeTrip(id: trip.id) { $0.name = "  " }, "a trip needs a name")
        XCTAssertNil(lib.changeTrip(id: trip.id) { $0.activities = [] }, "a quick trip needs a list")
        XCTAssertEqual(lib.trips[0].name, "Long weekend", "a refused change changes nothing")
        XCTAssertNil(lib.changeTrip(id: "nope") { _ in })
    }

    /// His E.6 crash (28 Sep, Mac): a thing on the trip TWICE — from two templates,
    /// into two bags — and the dates changed. Both fresh lines took the same old line,
    /// the trip held one id twice, and the Mac app stopped. Each line must come back
    /// once, with its own tick, and no id twice.
    func testAThingOnTheTripTwiceKeepsBothLinesAndTheirTicks() {
        var lib = Library()
        lib.saveTemplate({ var l = newList(name: "Swim"); l.items = [newItem(name: "Underwear"), newItem(name: "Goggles")]; return l }())
        lib.saveTemplate({ var l = newList(name: "Run"); l.items = [newItem(name: "Underwear"), newItem(name: "Shoes")]; return l }())
        let swim = lib.templates.first { $0.name == "Swim" }!.id, run = lib.templates.first { $0.name == "Run" }!.id
        let underwear = lib.items.first { $0.name == "Underwear" }!.id
        // The same thing, a different bag on each template.
        for (list, bag) in [(swim, "Swim bag"), (run, "Duffel bag")] {
            if let m = lib.memberships.firstIndex(where: { $0.itemId == underwear && $0.templateId == list }) { lib.memberships[m].container = bag }
        }
        var draft = newEvent(name: "Swim and run", startDate: "2026-10-03", endDate: "2026-10-04")
        draft.activities = [swim, run]; draft.mode = "quick"
        let trip = lib.createTrip(draft)
        let twice = lib.trips[0].entries.filter { $0.name == "Underwear" }
        XCTAssertEqual(twice.count, 2, "the setup must put Underwear on the trip twice, in two bags")
        guard twice.count == 2 else { return }
        let duffel = twice.first { $0.container == "Duffel bag" }!.id
        lib.setChecked(true, tripId: trip.id, entryId: duffel)

        XCTAssertNotNil(lib.changeTrip(id: trip.id) { $0.endDate = "2026-10-06" })
        let after = lib.trips[0].entries
        XCTAssertEqual(Set(after.map(\.id)).count, after.count, "one id twice on the trip: the Mac app stops on this")
        let lines = after.filter { $0.name == "Underwear" }
        XCTAssertEqual(lines.count, 2, "a line was lost or doubled: \(lines.map(\.container))")
        XCTAssertEqual(lines.first { $0.container == "Duffel bag" }?.checked, true, "the Duffel bag line lost its tick")
        XCTAssertEqual(lines.first { $0.container == "Swim bag" }?.checked, false, "the tick moved to the other bag's line")
        XCTAssertEqual(lines.first { $0.container == "Duffel bag" }?.id, duffel, "the ticked line did not keep its id")
    }

    /// The spec pass (5 Oct 2026, his first finding): the first Save in Trip settings on
    /// a trip someone SENT threw its whole list away, ticks too — a shared trip travels
    /// without the links a rebuild matches lines by — and replaced it with what his
    /// own templates give; on a Quick one Save quietly did nothing.
    func testATripSomeoneSentKeepsItsListOnSave() throws {
        // The sender's library and trip.
        var sender = Library()
        sender.saveTemplate({ var l = newList(name: "Hike", group: "GA"); l.items = [newItem(name: "Boots"), newItem(name: "Map")]; return l }())
        var draft = newEvent(name: "Hills", startDate: "2026-10-10", endDate: "2026-10-12")
        draft.activities = sender.templates.map(\.id)
        let sent = sender.createTrip(draft)
        let link = try XCTUnwrap(sender.shareLink(tripId: sent.id))

        // His library: an always-packed template, a transport kit, and a Map of his own.
        var lib = Library()
        lib.saveTemplate({ var l = newList(name: "Common base", role: "base"); l.items = [newItem(name: "Passport"), newItem(name: "Map")]; return l }())
        lib.saveTemplate({ var l = newList(name: "Car kit", role: "transport"); l.transport = "Car"; l.items = [newItem(name: "Jumper cables")]; return l }())
        lib.saveTemplate({ var l = newList(name: "Swim", group: "WET"); l.items = [newItem(name: "Goggles"), newItem(name: "Map")]; return l }())
        guard case .trip(let got)? = Library.readShared(link) else { return XCTFail("the link does not read back") }
        let trip = lib.importTrip(got)
        let boots = trip.entries.first { $0.name == "Boots" }!.id
        _ = lib.setChecked(true, tripId: trip.id, entryId: boots)

        // Save with only a new name: the list stays exactly as it came, the tick too.
        let r = lib.changeTrip(id: trip.id) { $0.name = "Hills with friends" }
        XCTAssertEqual(r, Library.TripRebuilt(added: 0, removed: 0), "Save changed a received list")
        XCTAssertEqual(lib.trips[0].entries.map(\.name), ["Boots", "Map"], "the received list was not kept")
        XCTAssertTrue(lib.trips[0].entries.contains { $0.id == boots && $0.checked }, "the received line lost its tick")

        // A template of his ticked: its things join — a thing of the same name in the
        // same bag is not doubled.
        let swim = lib.templates.first { $0.name == "Swim" }!.id
        XCTAssertNotNil(lib.changeTrip(id: trip.id) { $0.activities.append(swim) })
        XCTAssertEqual(lib.trips[0].entries.map(\.name).sorted(), ["Boots", "Goggles", "Map"], "the template did not add to it")

        // Quick switched off: now his always-packed and transport templates come too,
        // and the received lines still stay.
        XCTAssertNotNil(lib.changeTrip(id: trip.id) { $0.mode = "trip" })
        XCTAssertEqual(Set(lib.trips[0].entries.map(\.name)), ["Boots", "Map", "Goggles", "Passport", "Jumper cables"])
        XCTAssertEqual(lib.trips[0].entries.filter { $0.name == "Map" }.count, 1, "the Map came twice")
    }

    /// Weather gear "forced on" for a trip (Trip settings, the spec pass 5 Oct 2026):
    /// his tagged gear comes onto the list whatever the forecast says, and goes again
    /// when the condition is switched off — unless it was ticked.
    func testWeatherGearForcedOnComesWithTheList() {
        var lib = Library()
        lib.saveTemplate({ var l = newList(name: "Hike", group: "GA")
            var shell = newItem(name: "Rain shell"); shell.weather = ["rain"]
            var hat = newItem(name: "Sun hat"); hat.weather = ["hot"]
            l.items = [newItem(name: "Boots"), shell, hat]; return l }())
        var draft = newEvent(name: "Hills", mode: "quick")
        draft.activities = lib.templates.map(\.id)
        let trip = lib.createTrip(draft)
        XCTAssertEqual(trip.entries.map(\.name), ["Boots"], "weather gear waits for the forecast")
        XCTAssertEqual(lib.changeTrip(id: trip.id) { $0.weatherOn = ["rain"] }, Library.TripRebuilt(added: 1, removed: 0))
        XCTAssertEqual(lib.trips[0].entries.map(\.name), ["Boots", "Rain shell"])
        XCTAssertEqual(lib.trips[0].weatherOn, ["rain"])
        XCTAssertNotNil(lib.changeTrip(id: trip.id) { $0.weatherOn = [] })
        XCTAssertEqual(lib.trips[0].entries.map(\.name), ["Boots"], "switched off, the gear stayed")
    }
}
