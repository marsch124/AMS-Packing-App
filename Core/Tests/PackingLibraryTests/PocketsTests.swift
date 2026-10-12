import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// Bag pockets and "Where is my charger?" (0.69, stop B of his idea plan): a bag's
/// pockets, a thing's usual pocket, a line's pocket on the way out and the way home, and
/// the answer to "Where is my …?".
final class PocketsTests: XCTestCase {
    override func setUp() { PackingEnv.freeze(at: "2026-10-01T12:00:00.000Z") }
    override func tearDown() { PackingEnv.reset() }

    /// A backpack with three pockets; a charger usually in its front pocket, a torch in it
    /// with no pocket, a book in another bag; a trip under way (1–5 Oct) built from them.
    private func library() -> (Library, bag: String, trip: String) {
        var lib = Library()
        let backpack = lib.addBag(name: "Backpack")!.id
        _ = lib.addBag(name: "Tote")
        for p in ["Main", "Front pocket", "Lid"] { XCTAssertTrue(lib.addPocket(bagId: backpack, name: p)) }
        lib.saveTemplate(newList(name: "Base", role: "base"))
        let base = lib.templates.first { $0.role == "base" }!.id
        for (name, bag) in [("Charger", "Backpack"), ("Torch", "Backpack"), ("Book", "Tote")] {
            let t = lib.addThing(name: name)!
            _ = lib.updateThing(id: t.id) { $0.container = bag }
            _ = lib.setOnTemplate(itemId: t.id, templateId: base, on: true)
        }
        XCTAssertTrue(lib.setUsualPocket(thingId: thing(lib, "Charger"), pocket: "front POCKET"), "a pocket is found by its name")
        let trip = lib.createTrip(newEvent(name: "Away", startDate: "2026-10-01", endDate: "2026-10-05", destination: "Seaside")).id
        return (lib, backpack, trip)
    }

    private func thing(_ lib: Library, _ name: String) -> String { lib.items.first { $0.name == name }!.id }
    private func line(_ lib: Library, _ name: String) -> Item { lib.trips[0].entries.first { $0.name == name }! }

    func testABagListsItsPocketsAndHeAddsRenamesMovesAndRemovesThem() {
        var (lib, bag, _) = library()
        XCTAssertEqual(lib.pockets(bagId: bag), ["Main", "Front pocket", "Lid"])
        XCTAssertEqual(lib.pockets(bag: "backpack"), ["Main", "Front pocket", "Lid"], "found by the bag's name")
        XCTAssertFalse(lib.addPocket(bagId: bag, name: " main "), "two pockets of one name")
        XCTAssertFalse(lib.addPocket(bagId: bag, name: "  "), "a pocket with no name")
        XCTAssertFalse(lib.addPocket(bagId: thing(lib, "Charger"), name: "Side"), "a thing that is no bag got a pocket")
        XCTAssertTrue(lib.movePocket(bagId: bag, from: 2, to: 0))
        XCTAssertEqual(lib.pockets(bagId: bag), ["Lid", "Main", "Front pocket"])
        XCTAssertFalse(lib.renamePocket(bagId: bag, from: "Lid", to: "main"), "renamed onto another pocket")
        XCTAssertTrue(lib.renamePocket(bagId: bag, from: "Lid", to: "Top lid"))
        XCTAssertTrue(lib.removePocket(bagId: bag, name: "main"))
        XCTAssertEqual(lib.pockets(bagId: bag), ["Top lid", "Front pocket"])
        XCTAssertEqual(lib.pocketsByBag()["backpack"], ["Top lid", "Front pocket"])
        XCTAssertNil(lib.pocketsByBag()["tote"], "a bag with no pockets is listed with pockets")
        // A bag with no pockets: nothing stored at all — exactly what it was before.
        XCTAssertNil(lib.items.first { $0.name == "Tote" }!.extra[POCKETS_KEY])
    }

    func testTickingALineBringsItsUsualPocketAndHeCanChooseAnother() {
        var (lib, _, trip) = library()
        XCTAssertEqual(lib.suggestedPocket(for: line(lib, "Charger")), "Front pocket")
        XCTAssertTrue(lib.setChecked(true, tripId: trip, entryId: line(lib, "Charger").id))
        XCTAssertEqual(Library.pocket(line(lib, "Charger")), "Front pocket", "the usual pocket did not come with the tick")
        _ = lib.setChecked(true, tripId: trip, entryId: line(lib, "Torch").id)
        XCTAssertEqual(Library.pocket(line(lib, "Torch")), "", "a thing with no usual pocket got one")
        XCTAssertTrue(lib.setPocket("Lid", tripId: trip, entryId: line(lib, "Torch").id))
        XCTAssertEqual(Library.pocket(line(lib, "Torch")), "Lid")
        // Unticked and ticked again: his choice stands, it is not overwritten by the usual one.
        XCTAssertTrue(lib.setPocket("Main", tripId: trip, entryId: line(lib, "Charger").id))
        _ = lib.setChecked(false, tripId: trip, entryId: line(lib, "Charger").id)
        _ = lib.setChecked(true, tripId: trip, entryId: line(lib, "Charger").id)
        XCTAssertEqual(Library.pocket(line(lib, "Charger")), "Main")
        XCTAssertEqual(Library.bagAndPocket(line(lib, "Charger").container, Library.pocket(line(lib, "Charger"))), "Backpack \u{00B7} Main")
        // Kept in the stored records (synced), and in a backup.
        let back = Library(records: lib.records())
        XCTAssertEqual(Library.pocket(back.trips[0].entries.first { $0.name == "Torch" }!), "Lid")
        XCTAssertEqual(back.pockets(bag: "Backpack"), ["Main", "Front pocket", "Lid"])
        XCTAssertEqual(back.usualPocket(thingId: thing(back, "Charger")), "Front pocket")
        let restored = try! Importer.read(lib.backupData(exportedAt: "2026-10-01T12:00:00.000Z")).library
        XCTAssertEqual(restored.pockets(bag: "Backpack"), ["Main", "Front pocket", "Lid"], "a backup lost the pockets")
        XCTAssertEqual(restored.usualPocket(thingId: thing(restored, "Charger")), "Front pocket", "a backup lost the usual pocket")
        XCTAssertEqual(Library.pocket(restored.trips[0].entries.first { $0.name == "Torch" }!), "Lid", "a backup lost a line's pocket")
    }

    func testAUsualPocketHoldsOnlyWhileItsBagHasIt() {
        var (lib, bag, _) = library()
        XCTAssertFalse(lib.setUsualPocket(thingId: thing(lib, "Book"), pocket: "Lid"), "a pocket of another bag")
        // A new usual bag: the old bag's pocket no longer counts.
        _ = lib.updateThing(id: thing(lib, "Charger")) { $0.container = "Tote" }
        XCTAssertEqual(lib.usualPocket(thingId: thing(lib, "Charger")), "")
        _ = lib.updateThing(id: thing(lib, "Charger")) { $0.container = "Backpack" }
        XCTAssertEqual(lib.usualPocket(thingId: thing(lib, "Charger")), "Front pocket")
        XCTAssertTrue(lib.setUsualPocket(thingId: thing(lib, "Charger"), pocket: ""))
        XCTAssertNil(lib.items.first { $0.name == "Charger" }!.extra[USUAL_POCKET_KEY], "a cleared usual pocket left a key")
        _ = bag
    }

    func testARenameReachesThingsAndLinesAndARemoveLeavesThemInTheBag() {
        var (lib, bag, trip) = library()
        _ = lib.setChecked(true, tripId: trip, entryId: line(lib, "Charger").id)
        XCTAssertTrue(lib.renamePocket(bagId: bag, from: "Front pocket", to: "Outer pocket"))
        XCTAssertEqual(lib.usualPocket(thingId: thing(lib, "Charger")), "Outer pocket", "the thing lost its pocket on a rename")
        XCTAssertEqual(Library.pocket(line(lib, "Charger")), "Outer pocket", "the trip line lost its pocket on a rename")
        XCTAssertTrue(lib.removePocket(bagId: bag, name: "Outer pocket"))
        XCTAssertEqual(Library.usualPocket(lib.items.first { $0.name == "Charger" }!), "")
        XCTAssertEqual(Library.pocket(line(lib, "Charger")), "", "a line still in a pocket that is gone")
    }

    func testABagDeletedIntoAnotherTakesItsPocketsAlong() {
        var (lib, bag, trip) = library()
        _ = lib.setChecked(true, tripId: trip, entryId: line(lib, "Charger").id)
        XCTAssertTrue(lib.deleteBag(id: bag, moveTo: "Tote"))
        XCTAssertEqual(line(lib, "Charger").container, "Tote")
        XCTAssertEqual(Library.pocket(line(lib, "Charger")), "", "the line is in the Tote's front pocket, which does not exist")
        XCTAssertEqual(Library.usualPocket(lib.items.first { $0.name == "Charger" }!), "")
    }

    func testPackToGoHomeKeepsItsOwnPockets() {
        var (lib, _, trip) = library()
        _ = lib.setChecked(true, tripId: trip, entryId: line(lib, "Charger").id)
        XCTAssertTrue(lib.setPackedHome(true, tripId: trip, entryId: line(lib, "Charger").id))
        XCTAssertEqual(Library.homePocket(line(lib, "Charger")), "Front pocket", "the way home did not start from the pocket it went out in")
        XCTAssertTrue(lib.setHomePocket("Lid", tripId: trip, entryId: line(lib, "Charger").id))
        XCTAssertEqual(Library.homePocket(line(lib, "Charger")), "Lid")
        XCTAssertEqual(Library.pocket(line(lib, "Charger")), "Front pocket", "the way out was changed by the way home")
        // A new trip from this one, or one shared, starts with no pockets of this one's.
        let again = lib.startAgain(from: trip, name: "Again")!
        XCTAssertTrue(again.entries.allSatisfy { Library.pocket($0).isEmpty && Library.homePocket($0).isEmpty })
        XCTAssertTrue(Library.justTheList(lib.trips[0]).entries.allSatisfy { Library.pocket($0).isEmpty })
    }

    func testWhereIsMyCharger() {
        var (lib, _, trip) = library()
        // Under way, not ticked: where it goes.
        var a = lib.whereIs("charger", today: "2026-10-03")
        XCTAssertEqual(a?.kind, .notPacked)
        XCTAssertEqual(a?.said, "Not packed yet. It goes in Backpack, front pocket.")
        _ = lib.setChecked(true, tripId: trip, entryId: line(lib, "Charger").id)
        a = lib.whereIs("Charger", today: "2026-10-03")
        XCTAssertEqual(a?.kind, .packed)
        XCTAssertEqual(a?.said, "Backpack, front pocket.")
        XCTAssertEqual(a?.shown, "Backpack \u{00B7} Front pocket")
        XCTAssertEqual(a?.tripName, "Away")
        // On the way home (the last day counts): the home pocket.
        _ = lib.setPackedHome(true, tripId: trip, entryId: line(lib, "Charger").id)
        _ = lib.setHomePocket("Lid", tripId: trip, entryId: line(lib, "Charger").id)
        XCTAssertEqual(lib.whereIs("charger", today: "2026-10-05")?.said, "Backpack, lid.")
        // No trip under way: its usual bag and pocket.
        a = lib.whereIs("charger", today: "2026-10-20")
        XCTAssertEqual(a?.kind, .usual)
        XCTAssertEqual(a?.said, "Usually in Backpack, front pocket.")
        XCTAssertEqual(lib.whereIs("torch", today: "2026-10-20")?.said, "Usually in Backpack.")
        XCTAssertNil(lib.whereIs("kite", today: "2026-10-03"), "an answer for a thing he does not have")
        // A line typed on the trip, with no thing behind it, is found on the trip.
        let typed = lib.addCustomLine(tripId: trip, name: "Tripod", container: "Tote")!
        _ = lib.setChecked(true, tripId: trip, entryId: typed.id)
        XCTAssertEqual(lib.whereIs("tripod", today: "2026-10-03")?.said, "Tote.")
        XCTAssertEqual(WhereAnswer.soft("USB pocket"), "USB pocket")
    }

    func testAnAbsentPocketChangesNothing() {
        // A library from before 0.69: no key anywhere — no pockets, nothing suggested,
        // a tick writes no pocket, and the records are what they were.
        var lib = Library()
        _ = lib.addBag(name: "Backpack")
        lib.saveTemplate(newList(name: "Base", role: "base"))
        let base = lib.templates.first { $0.role == "base" }!.id
        let t = lib.addThing(name: "Charger")!
        _ = lib.updateThing(id: t.id) { $0.container = "Backpack" }
        _ = lib.setOnTemplate(itemId: t.id, templateId: base, on: true)
        let trip = lib.createTrip(newEvent(name: "Away", startDate: "2026-10-01", endDate: "2026-10-05")).id
        let before = lib.trips[0].entries[0]
        _ = lib.setChecked(true, tripId: trip, entryId: before.id)
        var expected = before
        expected.checked = true
        XCTAssertEqual(lib.trips[0].entries[0], expected, "a tick without pockets wrote more than the tick")
        XCTAssertEqual(lib.pocketsByBag(), [:])
    }

    func testWhereIsAThingInsideAKit() {
        // A thing inside a kit (0.70) is where the KIT is: the kit first, then the kit's
        // bag with its pocket (0.73, his ask: the kit's name, then the bag it is in). Taken
        // out of the kit, it says so, then its own place if it has one.
        var lib = Library()
        let bag = lib.addBag(name: "Day pack")!
        _ = lib.addPocket(bagId: bag.id, name: "Front pocket")
        let pouch = lib.addThing(name: "Camp pouch")!
        _ = lib.updateThing(id: pouch.id) { $0.container = "Day pack" }
        _ = lib.setUsualPocket(thingId: pouch.id, pocket: "Front pocket")
        let lighter = lib.addThing(name: "Lighter")!
        _ = lib.updateThing(id: lighter.id) { $0.container = "" }   // no bag of its own
        XCTAssertTrue(lib.setKit(kitId: pouch.id, contents: [lighter.id]))
        // No trip under way: where the kit usually goes.
        var a = lib.whereIs("lighter", today: "2026-10-03")
        XCTAssertEqual(a?.name, "Lighter")
        XCTAssertEqual(a?.kind, .usual)
        XCTAssertEqual(a?.kit, "Camp pouch")
        XCTAssertEqual(a?.kitWords, "In the Camp pouch")
        XCTAssertEqual(a?.shown, "Day pack \u{00B7} Front pocket", "the place is not where the kit is")
        XCTAssertEqual(a?.said, "In the Camp pouch, usually in the Day pack (front pocket).")
        XCTAssertEqual(lib.whereIs(thingId: lighter.id, today: "2026-10-03"), a, "Siri and Search answer differently")
        // The kit asked about itself: its own place, no kit named.
        XCTAssertEqual(lib.whereIs("camp pouch", today: "2026-10-03")?.said, "Usually in Day pack, front pocket.")
        XCTAssertEqual(lib.whereIs("camp pouch", today: "2026-10-03")?.kitWords, "")
        // Taken out, with no place of its own: just that.
        XCTAssertTrue(lib.setTakenOut(thingId: lighter.id, true))
        a = lib.whereIs("lighter", today: "2026-10-03")
        XCTAssertEqual(a?.kit, "")
        XCTAssertEqual(a?.takenOutOf, "Camp pouch")
        XCTAssertEqual(a?.kitWords, "Taken out of the Camp pouch")
        XCTAssertEqual(a?.said, "Taken out of the Camp pouch.")
        XCTAssertEqual(a?.shown, "Not in a bag")
        // Taken out, with a usual bag of its own: that as well.
        _ = lib.updateThing(id: lighter.id) { $0.container = "Tote" }
        XCTAssertEqual(lib.whereIs("lighter", today: "2026-10-03")?.said, "Taken out of the Camp pouch. Usually in Tote.")
        XCTAssertEqual(lib.whereIs("lighter", today: "2026-10-03")?.shown, "Tote")
        // Put back: the kit again, never its own bag.
        XCTAssertTrue(lib.setTakenOut(thingId: lighter.id, false))
        XCTAssertEqual(lib.whereIs("lighter", today: "2026-10-03")?.said, "In the Camp pouch, usually in the Day pack (front pocket).")
        // A kit in no bag: just the kit.
        _ = lib.updateThing(id: pouch.id) { $0.container = "" }
        a = lib.whereIs("lighter", today: "2026-10-03")
        XCTAssertEqual(a?.said, "In the Camp pouch.")
        XCTAssertEqual(a?.shown, "Not in a bag")
        XCTAssertEqual(a?.kitWords, "In the Camp pouch")
    }

    func testWhereIsAThingInsideAKitOnTheTripUnderWay() {
        // On the trip under way the kit's LINE answers: not packed yet, packed in the pocket
        // chosen, packed for home. Taken out, the thing has no line: it says so and where
        // it usually goes.
        var lib = Library()
        let backpack = lib.addBag(name: "Backpack")!.id
        for p in ["Main", "Lid"] { _ = lib.addPocket(bagId: backpack, name: p) }
        lib.saveTemplate(newList(name: "Base", role: "base"))
        let base = lib.templates.first { $0.role == "base" }!.id
        let pouch = lib.addThing(name: "Camp pouch")!
        _ = lib.updateThing(id: pouch.id) { $0.container = "Backpack" }
        _ = lib.setUsualPocket(thingId: pouch.id, pocket: "Lid")
        _ = lib.setOnTemplate(itemId: pouch.id, templateId: base, on: true)
        let lighter = lib.addThing(name: "Lighter")!
        _ = lib.updateThing(id: lighter.id) { $0.container = "" }   // no bag of its own
        XCTAssertTrue(lib.setKit(kitId: pouch.id, contents: [lighter.id]))
        var trip = newEvent(name: "Away", startDate: "2026-10-01", endDate: "2026-10-05")
        trip.entries = lib.builtLines(trip)
        lib.trips = [trip]
        let kitLine = lib.trips[0].entries.first { $0.sourceItemId == pouch.id }!
        XCTAssertFalse(lib.trips[0].entries.contains { $0.sourceItemId == lighter.id }, "what is inside became a line")
        var a = lib.whereIs("lighter", today: "2026-10-03")
        XCTAssertEqual(a?.kind, .notPacked)
        XCTAssertEqual(a?.tripName, "Away")
        XCTAssertEqual(a?.said, "In the Camp pouch, not packed yet. It goes in the Backpack (lid).")
        XCTAssertTrue(lib.setChecked(true, tripId: trip.id, entryId: kitLine.id))
        XCTAssertTrue(lib.setPocket("Main", tripId: trip.id, entryId: kitLine.id))
        a = lib.whereIs(thingId: lighter.id, today: "2026-10-03")
        XCTAssertEqual(a?.kind, .packed)
        XCTAssertEqual(a?.said, "In the Camp pouch, in the Backpack (main).", "not where the kit was packed")
        XCTAssertEqual(a?.shown, "Backpack \u{00B7} Main")
        XCTAssertTrue(lib.setPackedHome(true, tripId: trip.id, entryId: kitLine.id))
        XCTAssertTrue(lib.setHomePocket("Lid", tripId: trip.id, entryId: kitLine.id))
        a = lib.whereIs("lighter", today: "2026-10-05")
        XCTAssertEqual(a?.kind, .packedHome)
        XCTAssertEqual(a?.said, "In the Camp pouch, in the Backpack (lid).")
        // Taken out on the trip: the lighter is not on it (no line of its own).
        XCTAssertTrue(lib.setTakenOut(thingId: lighter.id, true))
        a = lib.whereIs("lighter", today: "2026-10-03")
        XCTAssertEqual(a?.kind, .usual)
        XCTAssertEqual(a?.said, "Taken out of the Camp pouch.")
        XCTAssertEqual(a?.kitWords, "Taken out of the Camp pouch")
        // A trip made before the lighter went into the kit keeps its own line: asked by
        // name, it still answers with its kit — as Siri does.
        XCTAssertTrue(lib.setTakenOut(thingId: lighter.id, false))
        var old = lib.trips[0]
        var own = newItem(name: "Lighter")
        own.sourceItemId = lighter.id
        own.container = "Backpack"
        old.entries.append(own)
        lib.trips[0] = old
        XCTAssertEqual(lib.whereIs("lighter", today: "2026-10-05")?.said, "In the Camp pouch, in the Backpack (lid).")
        XCTAssertEqual(lib.whereIs("lighter", today: "2026-10-05"), lib.whereIs(thingId: lighter.id, today: "2026-10-05"))
    }
}
