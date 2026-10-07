import XCTest
import PackingCore
@testable import PackingLibrary

/// Kits — things that hold things (spec 07, part 9). Invented data only — this
/// repository is public.
final class ThingKitsTests: XCTestCase {

    override func setUp() { PackingEnv.freeze(at: "2026-10-07T09:00:00.000Z") }
    override func tearDown() { PackingEnv.reset() }

    /// A base template with a toothbrush and a passport; Hiking with a camp pouch and a
    /// map; a carry-on bag. The Camp pouch (60 g) holds a lighter (30 g, not allowed in
    /// the cabin), spare cord (80 g, two of them) and plasters (20 g); the Wash bag (100 g),
    /// on no template, holds the toothbrush (also on the base template on its own) and
    /// soap (90 g) — and is checked before each trip.
    static func library() -> Library {
        var lib = Library()
        var base = newList(name: "Common base", role: "base")
        base.items = [newItem(name: "Toothbrush"), newItem(name: "Passport")]
        lib.saveTemplate(base)
        var hiking = newList(name: "Hiking", group: "GA")
        hiking.items = [newItem(name: "Camp pouch"), newItem(name: "Map")]
        lib.saveTemplate(hiking)
        for name in ["Lighter", "Spare cord", "Plasters", "Wash bag", "Soap"] { _ = lib.addThing(name: name) }
        _ = lib.addBag(name: "Carry-on / hand luggage")
        let grams: [String: Double] = ["Camp pouch": 60, "Lighter": 30, "Spare cord": 80, "Plasters": 20,
                                       "Wash bag": 100, "Soap": 90, "Toothbrush": 18, "Map": 70]
        for n in lib.items.indices {
            if let g = grams[lib.items[n].name] { lib.items[n].weight = g }
            lib.items[n].container = lib.items[n].name == "Carry-on / hand luggage" ? "" : "Carry-on / hand luggage"
        }
        lib.items[lib.items.firstIndex { $0.name == "Spare cord" }!].qty = "2"
        lib.items[lib.items.firstIndex { $0.name == "Lighter" }!].restricted = true
        XCTAssertTrue(lib.setKit(kitId: id(lib, "Camp pouch"), contents: ids(lib, "Lighter", "Spare cord", "Plasters")))
        XCTAssertTrue(lib.setKit(kitId: id(lib, "Wash bag"), contents: ids(lib, "Toothbrush", "Soap"), check: true))
        return lib
    }

    static func id(_ lib: Library, _ name: String) -> String { lib.items.first { $0.name == name }!.id }
    static func ids(_ lib: Library, _ names: String...) -> [String] { names.map { id(lib, $0) } }
    func id(_ lib: Library, _ name: String) -> String { ThingKitsTests.id(lib, name) }
    func names(_ contents: [KitContent]) -> [String] { contents.map(\.thing.name) }

    func trip(_ lib: inout Library, end: String = "2026-10-20") -> TripEvent {
        var t = newEvent(name: "Weekend in the hills", startDate: "2026-10-17", endDate: end)
        t.activities = lib.templates.filter { $0.name == "Hiking" }.map(\.id)
        return lib.createTrip(t)
    }

    // MARK: - What is inside

    func testAKitHoldsThingsInHisOrderAndAThingIsInOneKitOnly() {
        var lib = ThingKitsTests.library()
        let pouch = id(lib, "Camp pouch"), wash = id(lib, "Wash bag"), cord = id(lib, "Spare cord")
        XCTAssertEqual(names(lib.kitContents(kitId: pouch)), ["Lighter", "Spare cord", "Plasters"], "his order")
        XCTAssertTrue(lib.isKit(pouch))
        XCTAssertFalse(lib.isKit(id(lib, "Map")))
        XCTAssertEqual(lib.kitHolding(thingId: cord)?.name, "Camp pouch")
        XCTAssertNil(lib.kitHolding(thingId: id(lib, "Map")))

        // Into the wash bag: out of the pouch, in the record too.
        XCTAssertTrue(lib.addToKit(kitId: wash, thingId: cord))
        XCTAssertEqual(lib.kitHolding(thingId: cord)?.name, "Wash bag")
        XCTAssertEqual(names(lib.kitContents(kitId: pouch)), ["Lighter", "Plasters"])
        XCTAssertFalse(Library.listedContents(lib.items.first { $0.id == pouch }!).contains(cord), "the pouch no longer lists it")
        XCTAssertEqual(names(lib.kitContents(kitId: wash)), ["Toothbrush", "Soap", "Spare cord"], "added at the end")
        XCTAssertFalse(lib.addToKit(kitId: wash, thingId: cord), "already in it")

        // Out for good: a thing of its own again.
        XCTAssertTrue(lib.removeFromKit(thingId: cord))
        XCTAssertNil(lib.kitHolding(thingId: cord))
        // Everything out: a plain thing again, and no key left on it.
        XCTAssertTrue(lib.setKit(kitId: pouch, contents: []))
        XCTAssertFalse(lib.isKit(pouch))
        let plain = lib.items.first { $0.id == pouch }!
        XCTAssertNil(plain.extra[KIT_CONTENTS_KEY]); XCTAssertNil(plain.extra[KIT_OUT_KEY]); XCTAssertNil(plain.extra[KIT_CHECK_KEY])
    }

    func testAKitNeverGoesInsideAKitAndABagIsNeitherAKitNorInsideOne() {
        var lib = ThingKitsTests.library()
        let pouch = id(lib, "Camp pouch"), wash = id(lib, "Wash bag"), lighter = id(lib, "Lighter")
        let bag = id(lib, "Carry-on / hand luggage"), map = id(lib, "Map")
        XCTAssertEqual(lib.kitRefusal(thingId: pouch, kitId: pouch), "A thing cannot go inside itself.")
        XCTAssertEqual(lib.kitRefusal(thingId: wash, kitId: pouch), "Wash bag holds things itself: a kit cannot go inside another kit.")
        XCTAssertEqual(lib.kitRefusal(thingId: map, kitId: lighter), "Lighter is inside Camp pouch: a kit cannot go inside another kit.")
        XCTAssertEqual(lib.kitRefusal(thingId: bag, kitId: pouch), "A bag cannot go inside a kit.")
        XCTAssertEqual(lib.kitRefusal(thingId: map, kitId: bag), "A bag holds its things by itself.")
        XCTAssertEqual(lib.kitRefusal(thingId: map, kitId: pouch), "")
        let before = lib
        XCTAssertFalse(lib.addToKit(kitId: pouch, thingId: wash))
        XCTAssertFalse(lib.addToKit(kitId: lighter, thingId: map))
        XCTAssertFalse(lib.addToKit(kitId: bag, thingId: map))
        XCTAssertEqual(lib, before, "nothing written")
        // What is offered: not itself, not a kit, not a bag, not what is in it already —
        // a thing in another kit is offered (it moves).
        let offered = lib.kitCandidates(kitId: pouch).map(\.name)
        XCTAssertEqual(offered, ["Map", "Passport", "Soap", "Toothbrush"])
        // A to-do is never inside a kit.
        var todo = newItem(name: "Charge the lamp"); todo.itemType = "reminder"
        lib.items.append(todo)
        XCTAssertEqual(lib.kitRefusal(thingId: todo.id, kitId: pouch), "A to-do cannot go inside a kit.")
    }

    func testTwoKitsListingOneThingSettleOnTheKitThatSortsFirst() {
        // What two devices can leave behind: each put the soap in its own kit.
        var lib = ThingKitsTests.library()
        let pouch = id(lib, "Camp pouch"), wash = id(lib, "Wash bag"), soap = id(lib, "Soap")
        let n = lib.items.firstIndex { $0.id == pouch }!
        lib.items[n].extra[KIT_CONTENTS_KEY] = JSONValue(Library.listedContents(lib.items[n]) + [soap])
        let first = [pouch, wash].min()!
        XCTAssertEqual(lib.kitIndex().holder[soap], first, "one kit holds it — the same on every device")
        XCTAssertEqual(lib.kitIndex().contents.values.flatMap { $0 }.filter { $0.thing.id == soap }.count, 1)
        // The other kit's page saves what it holds, and lists it no more.
        let other = first == pouch ? wash : pouch
        lib.setKit(kitId: other, contents: lib.kitContents(kitId: other).map(\.thing.id),
                   check: Library.kitCheck(lib.items.first { $0.id == other }!))
        XCTAssertFalse(Library.listedContents(lib.items.first { $0.id == other }!).contains(soap))
        XCTAssertEqual(lib.kitHolding(thingId: soap)?.id, first)
    }

    func testTakenOutSaysWhatIsMissingUntilItIsPutBack() {
        var lib = ThingKitsTests.library()
        var t = trip(&lib)
        let lighter = id(lib, "Lighter")
        XCTAssertTrue(lib.setTakenOut(thingId: lighter, true))
        XCTAssertTrue(lib.isTakenOut(thingId: lighter))
        t = lib.trips.first { $0.id == t.id }!
        let line = t.entries.first { $0.name == "Camp pouch" }!
        let kit = lib.kitOnLine(line)!
        XCTAssertEqual(kit.insideWords, "2 inside")
        XCTAssertEqual(kit.missingWords, "1 missing: Lighter")
        XCTAssertTrue(lib.setTakenOut(thingId: id(lib, "Plasters"), true))
        XCTAssertEqual(lib.kitOnLine(line)!.missingWords, "2 missing: Lighter, Plasters", "in his order")
        XCTAssertTrue(lib.setTakenOut(thingId: lighter, false))
        XCTAssertTrue(lib.setTakenOut(thingId: id(lib, "Plasters"), false))
        XCTAssertEqual(lib.kitOnLine(line)!.missingWords, "")
        XCTAssertEqual(lib.kitOnLine(line)!.insideWords, "3 inside")
        XCTAssertNil(lib.items.first { $0.name == "Camp pouch" }!.extra[KIT_OUT_KEY], "nothing out, no key")
        XCTAssertFalse(lib.setTakenOut(thingId: id(lib, "Map"), true), "the map is in no kit")
        // Removed from the kit for good, it is no longer missing from it either.
        XCTAssertTrue(lib.setTakenOut(thingId: lighter, true))
        XCTAssertTrue(lib.removeFromKit(thingId: lighter))
        XCTAssertNil(lib.items.first { $0.name == "Camp pouch" }!.extra[KIT_OUT_KEY])
    }

    // MARK: - Weight

    func testAKitWeighsItselfAndWhatIsInsideIt() {
        var lib = ThingKitsTests.library()
        let pouch = lib.items.first { $0.name == "Camp pouch" }!
        // 60 + 30 + 80 × 2 + 20
        XCTAssertEqual(lib.packedWeight(pouch), 270)
        XCTAssertEqual(lib.packedWeight(lib.items.first { $0.name == "Map" }!), 70, "a plain thing: its own")
        _ = lib.setTakenOut(thingId: id(lib, "Spare cord"), true)
        XCTAssertEqual(lib.packedWeight(lib.items.first { $0.id == pouch.id }!), 110, "what is taken out is not in it")
        _ = lib.setTakenOut(thingId: id(lib, "Spare cord"), false)

        // The bag bars.
        var t = trip(&lib)
        t = lib.trips.first { $0.id == t.id }!
        let carry = lib.weighedBags(tripId: t.id).first { $0.load.container == "Carry-on / hand luggage" }!
        // Passport 0, Wash bag 100 + 18 + 90, Camp pouch 270, Map 70.
        XCTAssertEqual(carry.load.grams, 548)
        // Care's heaviest things, and what each template weighs.
        let stats = lib.kitStats(today: "2026-10-07")
        XCTAssertEqual(stats.heaviest.prefix(2).map(\.name), ["Camp pouch", "Wash bag"])
        XCTAssertEqual(stats.heaviest.first?.grams, 270)
        XCTAssertEqual(stats.lists.first { $0.label == "Hiking" }?.grams, 340)
        XCTAssertEqual(stats.totalGrams, 468, "each thing counted once in the total")
        // The table: sorted and filtered by the weight with what is inside.
        XCTAssertEqual(lib.sortValue(pouch, key: "weight", memberships: [:]), String(format: "%012.2f", 270.0))
        XCTAssertEqual(lib.filterValues(pouch, column: "weight"), ["w2"], "100 – 500 g, not under 100 g")
    }

    // MARK: - On a trip

    func testATripHasTheKitAsOneLineAndNeverWhatIsInside() {
        var lib = ThingKitsTests.library()
        let t = trip(&lib)
        let lines = t.entries.map(\.name)
        XCTAssertEqual(lines, ["Wash bag", "Passport", "Camp pouch", "Map"],
                       "the toothbrush on the base template brings its wash bag, in its place")
        for inside in ["Lighter", "Spare cord", "Plasters", "Toothbrush", "Soap"] {
            XCTAssertFalse(lines.contains(inside), "\(inside) is never a line of its own")
        }
        let wash = t.entries.first { $0.name == "Wash bag" }!
        XCTAssertEqual(wash.sourceItemId, id(lib, "Wash bag"))
        XCTAssertEqual(wash.sourceListId, lib.templates.first { $0.name == "Common base" }!.id, "from the template the toothbrush is on")
        XCTAssertEqual(lib.kitLines(tripId: t.id).count, 2)
        XCTAssertNil(lib.kitOnLine(t.entries.first { $0.name == "Map" }!))
    }

    func testAKitOnTheTemplateOfItsContentsOrOnTwoTemplatesIsStillOneLine() {
        var lib = ThingKitsTests.library()
        let hiking = lib.templates.first { $0.name == "Hiking" }!.id
        let base = lib.templates.first { $0.role == "base" }!.id
        // The lighter on Hiking too, beside its pouch; the soap on Hiking without its bag
        // (which the toothbrush already brings from the base template); the pouch on the
        // base template as well.
        _ = lib.setOnTemplate(itemId: id(lib, "Lighter"), templateId: hiking, on: true)
        _ = lib.setOnTemplate(itemId: id(lib, "Soap"), templateId: hiking, on: true)
        _ = lib.setOnTemplate(itemId: id(lib, "Camp pouch"), templateId: base, on: true)
        let t = trip(&lib)
        XCTAssertEqual(t.entries.map(\.name).sorted(), ["Camp pouch", "Map", "Passport", "Wash bag"])
        XCTAssertEqual(Set(t.entries.map(\.id)).count, t.entries.count)
    }

    func testARebuildAndAChangeToAThingNeverBringAContentBack() {
        var lib = ThingKitsTests.library()
        var t = trip(&lib)
        let map = id(lib, "Map"), pouch = id(lib, "Camp pouch")
        // The map goes into the pouch after the trip was made: a rebuild takes its line
        // away (it was not ticked) — the pouch is on the trip already.
        XCTAssertTrue(lib.addToKit(kitId: pouch, thingId: map))
        t = lib.trips.first { $0.id == t.id }!
        XCTAssertTrue(t.entries.contains { $0.name == "Map" }, "a trip made before keeps its line until it is rebuilt")
        XCTAssertEqual(lib.regenerated(t).map(\.name), ["Wash bag", "Passport", "Camp pouch"])
        // A change to the map reaches no line: it has none of its own on a rebuilt trip.
        lib.trips[0].entries = lib.regenerated(t)
        XCTAssertTrue(lib.updateThing(id: map) { $0.weight = 75 })
        XCTAssertFalse(lib.trips[0].entries.contains { $0.sourceItemId == map })
        // A ticked line of it stays, as every ticked line does.
        lib.trips[0].entries.append(Item(name: "Map", sourceListId: lib.templates.first { $0.name == "Hiking" }!.id,
                                         sourceItemId: map, checked: true))
        XCTAssertTrue(lib.regenerated(lib.trips[0]).contains { $0.sourceItemId == map && $0.checked })
    }

    func testAKitCheckedBeforeEachTripIsPackedOnlyWhenAllInsideIsTicked() {
        var lib = ThingKitsTests.library()
        let t = trip(&lib)
        let line = t.entries.first { $0.name == "Wash bag" }!
        let brush = id(lib, "Toothbrush"), soap = id(lib, "Soap")
        XCTAssertEqual(lib.kitOnLine(line)!.toTickWords, "Tick what is inside first: 2 to go.")
        XCTAssertFalse(lib.setChecked(true, tripId: t.id, entryId: line.id), "not before what is inside is ticked")
        XCTAssertTrue(lib.setKitContentTicked(true, tripId: t.id, entryId: line.id, contentId: brush))
        var now = lib.trips[0].entries.first { $0.id == line.id }!
        XCTAssertFalse(now.checked)
        XCTAssertEqual(lib.kitOnLine(now)!.toTick, 1)
        XCTAssertTrue(lib.setKitContentTicked(true, tripId: t.id, entryId: line.id, contentId: soap))
        now = lib.trips[0].entries.first { $0.id == line.id }!
        XCTAssertTrue(now.checked, "the last one ticked packs the kit")
        XCTAssertNil(now.extra[KIT_TICKED_KEY], "a packed kit keeps no list of ticks")
        XCTAssertEqual(lib.kitOnLine(now)!.ticked, [brush, soap])
        // One unticked: the kit is not packed, the other stays ticked.
        XCTAssertTrue(lib.setKitContentTicked(false, tripId: t.id, entryId: line.id, contentId: soap))
        now = lib.trips[0].entries.first { $0.id == line.id }!
        XCTAssertFalse(now.checked)
        XCTAssertEqual(lib.kitOnLine(now)!.ticked, [brush])
        // The kit's own untick starts it over.
        XCTAssertTrue(lib.setKitContentTicked(true, tripId: t.id, entryId: line.id, contentId: soap))
        XCTAssertTrue(lib.setChecked(false, tripId: t.id, entryId: line.id))
        now = lib.trips[0].entries.first { $0.id == line.id }!
        XCTAssertEqual(lib.kitOnLine(now)!.ticked, [])
        // Taken out: not asked for. With nothing left to tick, the kit ticks as any line.
        _ = lib.setTakenOut(thingId: brush, true)
        XCTAssertTrue(lib.setKitContentTicked(true, tripId: t.id, entryId: line.id, contentId: soap))
        XCTAssertTrue(lib.trips[0].entries.first { $0.id == line.id }!.checked)
        XCTAssertFalse(lib.setKitContentTicked(true, tripId: t.id, entryId: line.id, contentId: brush), "it is not in the bag")
        // Without the check, a kit ticks at once.
        let pouch = lib.trips[0].entries.first { $0.name == "Camp pouch" }!
        XCTAssertTrue(lib.setChecked(true, tripId: t.id, entryId: pouch.id))
        XCTAssertFalse(lib.setKitContentTicked(false, tripId: t.id, entryId: line.id, contentId: brush))
        // Set aside: nothing inside it is ticked.
        _ = lib.setChecked(false, tripId: t.id, entryId: line.id)
        _ = lib.setAside(true, tripId: t.id, entryId: line.id)
        XCTAssertFalse(lib.setKitContentTicked(true, tripId: t.id, entryId: line.id, contentId: soap))
    }

    // MARK: - Care and the checks before you go

    func testWhatIsInsideAKitIsSaidOnTheKit() {
        var lib = ThingKitsTests.library()
        let pouch = id(lib, "Camp pouch"), plasters = id(lib, "Plasters"), cord = id(lib, "Spare cord")
        _ = lib.updateThing(id: plasters) { $0.expiry = "2026-10-17" }
        _ = lib.updateThing(id: cord) { $0.maintenance = Maintenance(notes: "Check for fraying", intervalDays: 30, lastDone: "2026-08-01") }
        XCTAssertEqual(lib.kitWarnings(kitId: pouch, today: "2026-10-07"),
                       ["Spare cord is overdue for care", "Plasters runs out in 10 days"])
        // On a trip: before its last day only.
        XCTAssertEqual(lib.kitWarnings(kitId: pouch, today: "2026-10-07", before: "2026-10-12"), ["Spare cord is overdue for care"])
        XCTAssertEqual(lib.kitWarnings(kitId: pouch, today: "2026-10-20"), ["Spare cord is overdue for care", "Plasters is out of date"])
        _ = lib.setTakenOut(thingId: cord, true)
        XCTAssertEqual(lib.kitWarnings(kitId: pouch, today: "2026-10-07"), ["Plasters runs out in 10 days"], "taken out, not in it")
        // Care says which kit a thing is in.
        _ = lib.setTakenOut(thingId: cord, false)
        let row = lib.careRows(today: "2026-10-07").first { $0.item.name == "Spare cord" }!
        XCTAssertEqual(row.listName, "Inside the Camp pouch")
    }

    func testTheChecksBeforeYouGoLookInsideAKit() {
        var lib = ThingKitsTests.library()
        _ = lib.updateThing(id: id(lib, "Plasters")) { $0.expiry = "2026-10-18" }
        var draft = newEvent(name: "Flying out", startDate: "2026-10-17", endDate: "2026-10-20")
        draft.transport = "Plane"
        draft.activities = lib.templates.filter { $0.name == "Hiking" }.map(\.id)
        let t = lib.createTrip(draft)
        let cabin = lib.cabinCheck(tripId: t.id)
        XCTAssertEqual(cabin.map(\.line.name), ["Lighter, in the Camp pouch"])
        XCTAssertEqual(cabin.first?.thingId, id(lib, "Lighter"), "it opens the lighter")
        XCTAssertEqual(cabin.first?.why, .notAllowed)
        let dates = lib.dateCheck(tripId: t.id, todayISO: "2026-10-07")
        XCTAssertEqual(dates.map(\.line.name), ["Plasters, in the Camp pouch"])
        XCTAssertEqual(dates.first?.thingId, id(lib, "Plasters"))
        XCTAssertTrue(dates.first?.beforeHome == true)
        // Taken out of the pouch, it is not in the cabin bag.
        _ = lib.setTakenOut(thingId: id(lib, "Lighter"), true)
        XCTAssertEqual(lib.cabinCheck(tripId: t.id), [])
    }

    func testAThingAlsoOnATemplateOnItsOwnIsPointedOut() {
        let lib = ThingKitsTests.library()
        XCTAssertEqual(lib.kitAlsoOn(thingId: id(lib, "Toothbrush")), ["Common base"])
        XCTAssertEqual(lib.kitAlsoOn(thingId: id(lib, "Lighter")), [])
        XCTAssertEqual(lib.kitAlsoOn(thingId: id(lib, "Map")), [], "not in a kit")
    }

    // MARK: - Kept like every other field of a thing

    func testAKitIsStoredSyncedBackedUpAndRestoredWithTheThing() throws {
        var lib = ThingKitsTests.library()
        _ = lib.setTakenOut(thingId: id(lib, "Plasters"), true)
        _ = trip(&lib)
        let washLine = lib.trips[0].entries.first { $0.name == "Wash bag" }!
        _ = lib.setKitContentTicked(true, tripId: lib.trips[0].id, entryId: washLine.id, contentId: id(lib, "Soap"))
        let index = lib.kitIndex()
        /// Which kit holds what, and what is taken out.
        func shape(_ idx: KitIndex) -> [String: [String]] {
            idx.contents.mapValues { $0.map { "\($0.thing.id)\($0.takenOut ? " out" : "")" } }
        }

        // The store and iCloud: records and back.
        let stored = Library(records: lib.records())
        XCTAssertEqual(stored.kitIndex(), index)
        XCTAssertEqual(stored.trips, lib.trips, "the ticks inside the wash bag")

        // A backup file, read back as Settings reads it — the file as this app writes it,
        // and the older kind rebuilt from the template rows.
        for data in [lib.backupData(exportedAt: "2026-10-07T09:00:00.000Z"),
                     BackupTests.olderFile(lib, exportedAt: "2026-10-07T09:00:00.000Z")] {
            let (back, report) = try BackupTests.read(data)
            XCTAssertTrue(report.isFaithful, report.mismatches.joined(separator: "; "))
            XCTAssertEqual(shape(back.kitIndex()), shape(index))
            XCTAssertTrue(back.isTakenOut(thingId: id(lib, "Plasters")))
            XCTAssertTrue(Library.kitCheck(back.items.first { $0.name == "Wash bag" }!))
        }
        // The web app's model reads a kit as a plain thing: its keys ride along unread.
        let pouch = lib.items.first { $0.name == "Camp pouch" }!
        XCTAssertEqual(Item(json: pouch.json), pouch)
        XCTAssertEqual(coerceItem(pouch).extra[KIT_CONTENTS_KEY], pouch.extra[KIT_CONTENTS_KEY])
    }

    func testDeletingAThingTakesItOutOfItsKitAndDeletingAKitFreesWhatWasInside() {
        var lib = ThingKitsTests.library()
        let lighter = id(lib, "Lighter"), wash = id(lib, "Wash bag")
        XCTAssertTrue(lib.deleteThing(id: lighter))
        XCTAssertEqual(names(lib.kitContents(kitId: id(lib, "Camp pouch"))), ["Spare cord", "Plasters"])
        XCTAssertFalse(Library.listedContents(lib.items.first { $0.name == "Camp pouch" }!).contains(lighter))
        XCTAssertTrue(lib.deleteThing(id: wash))
        XCTAssertNil(lib.kitHolding(thingId: id(lib, "Soap")))
        XCTAssertNil(lib.kitHolding(thingId: id(lib, "Toothbrush")))
        // …so the toothbrush is a line of its own again.
        let t = trip(&lib)
        XCTAssertTrue(t.entries.contains { $0.name == "Toothbrush" })
    }

    func testASharedTripAndATripStartedAgainCarryNoTicksInsideAKit() {
        var lib = ThingKitsTests.library()
        let t = trip(&lib)
        let line = t.entries.first { $0.name == "Wash bag" }!
        _ = lib.setKitContentTicked(true, tripId: t.id, entryId: line.id, contentId: id(lib, "Soap"))
        let sent = Library.justTheList(lib.trips[0])
        XCTAssertNil(sent.entries.first { $0.name == "Wash bag" }!.extra[KIT_TICKED_KEY])
        let again = lib.startAgain(from: t.id, name: "Again")!
        XCTAssertNil(again.entries.first { $0.name == "Wash bag" }!.extra[KIT_TICKED_KEY])
        XCTAssertNotNil(lib.trips[0].entries.first { $0.id == line.id }!.extra[KIT_TICKED_KEY], "the trip itself keeps its own")
    }
}
