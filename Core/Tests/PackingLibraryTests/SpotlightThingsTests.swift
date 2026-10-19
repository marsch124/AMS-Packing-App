import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// Find your things in Spotlight (0.92, his yes of 19 Oct 2026): what Spotlight is handed for each
/// thing — its name, where it is now (the answer "Where is my …?" gives), the words it is found by —
/// which things, and what is handed over again after a change. Invented data only — this
/// repository is public.
final class SpotlightThingsTests: XCTestCase {
    override func setUp() { PackingEnv.freeze(at: "2026-10-01T12:00:00.000Z") }
    override func tearDown() { PackingEnv.reset() }

    /// A Backpack with three pockets and a Tote; a Charger usually in the Backpack's front pocket,
    /// kept in the Hall closet; a Torch in the Backpack (no pocket, no place); a Book in the Tote;
    /// a trip under way (1–5 Oct) built from them.
    private func library() -> (Library, trip: String) {
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
        XCTAssertTrue(lib.setUsualPocket(thingId: thing(lib, "Charger"), pocket: "Front pocket"))
        XCTAssertTrue(lib.setStorage(id: thing(lib, "Charger"), place: "Hall closet"))
        let trip = lib.createTrip(newEvent(name: "Away", startDate: "2026-10-01", endDate: "2026-10-05")).id
        return (lib, trip)
    }

    private func thing(_ lib: Library, _ name: String) -> String { lib.items.first { $0.name == name }!.id }
    private func line(_ lib: Library, _ name: String) -> Item { lib.trips[0].entries.first { $0.name == name }! }
    private func place(_ lib: Library, _ name: String, _ today: String) -> String {
        lib.spotlightThing(id: thing(lib, name), today: today)?.place ?? "(not shown)"
    }

    func testTheLineUnderAThingSaysWhereItIsNow() {
        var (lib, trip) = library()
        // No trip under way: where it usually goes, and where it is kept at home.
        XCTAssertEqual(place(lib, "Charger", "2026-10-20"), "Usually in the Backpack \u{00B7} Front pocket \u{00B7} Kept at home: Hall closet")
        XCTAssertEqual(place(lib, "Torch", "2026-10-20"), "Usually in the Backpack")
        // Under way, not ticked: not packed yet, where it goes — and it is still at home.
        XCTAssertEqual(place(lib, "Charger", "2026-10-03"),
                       "Not packed yet \u{00B7} Goes in the Backpack \u{00B7} Front pocket \u{00B7} Kept at home: Hall closet")
        // Ticked: packed, in its bag and pocket — no longer "kept at home".
        XCTAssertTrue(lib.setChecked(true, tripId: trip, entryId: line(lib, "Charger").id))
        XCTAssertEqual(place(lib, "Charger", "2026-10-03"), "Packed in the Backpack \u{00B7} Front pocket")
        // On the way home (the last day counts): the pocket it went home in.
        XCTAssertTrue(lib.setPackedHome(true, tripId: trip, entryId: line(lib, "Charger").id))
        XCTAssertTrue(lib.setHomePocket("Lid", tripId: trip, entryId: line(lib, "Charger").id))
        XCTAssertEqual(place(lib, "Charger", "2026-10-05"), "Packed for home in the Backpack \u{00B7} Lid")
        // The day after: home again — its usual answer.
        XCTAssertEqual(place(lib, "Charger", "2026-10-06"), "Usually in the Backpack \u{00B7} Front pocket \u{00B7} Kept at home: Hall closet")
        // Packed with no bag on the line.
        XCTAssertTrue(lib.setChecked(true, tripId: trip, entryId: line(lib, "Book").id))
        var book = lib.trips[0]
        book.entries[book.entries.firstIndex { $0.name == "Book" }!].container = ""
        lib.trips[0] = book
        XCTAssertEqual(place(lib, "Book", "2026-10-03"), "Packed, not in a bag")
        // A thing not on the trip under way: its usual answer. With no bag and no place: says so.
        let kite = lib.addThing(name: "Kite")!.id
        _ = lib.updateThing(id: kite) { $0.container = "" }
        XCTAssertEqual(place(lib, "Kite", "2026-10-03"), "No usual bag or place at home yet")
        XCTAssertTrue(lib.setStorage(id: kite, place: "Kim's room"))
        XCTAssertEqual(place(lib, "Kite", "2026-10-03"), "Kept at home: Kim's room", "a place is said with a colon, as on the page")
    }

    func testAThingInAKitIsWhereItsKitIs() {
        var lib = Library()
        let bag = lib.addBag(name: "Day pack")!
        _ = lib.addPocket(bagId: bag.id, name: "Front pocket")
        _ = lib.addBag(name: "Tote")
        let pouch = lib.addThing(name: "Camp pouch")!
        _ = lib.updateThing(id: pouch.id) { $0.container = "Day pack"; $0.storage = "Garage" }
        _ = lib.setUsualPocket(thingId: pouch.id, pocket: "Front pocket")
        let lighter = lib.addThing(name: "Lighter")!
        _ = lib.updateThing(id: lighter.id) { $0.container = ""; $0.storage = "Kitchen drawer" }
        XCTAssertTrue(lib.setKit(kitId: pouch.id, contents: [lighter.id]))
        // In the kit: the kit, where the kit usually goes, and where the KIT is kept at home.
        XCTAssertEqual(place(lib, "Lighter", "2026-10-03"),
                       "In the Camp pouch \u{00B7} Usually in the Day pack \u{00B7} Front pocket \u{00B7} Kept at home: Garage")
        // The kit itself: its own place, no kit named.
        XCTAssertEqual(place(lib, "Camp pouch", "2026-10-03"), "Usually in the Day pack \u{00B7} Front pocket \u{00B7} Kept at home: Garage")
        // Taken out, with a bag of its own: says so, then its own bag and its own place.
        XCTAssertTrue(lib.setTakenOut(thingId: lighter.id, true))
        _ = lib.updateThing(id: lighter.id) { $0.container = "Tote" }
        XCTAssertEqual(place(lib, "Lighter", "2026-10-03"), "Taken out of the Camp pouch \u{00B7} Usually in the Tote \u{00B7} Kept at home: Kitchen drawer")
        // On a trip under way, the kit's line: packed in the bag the kit went in.
        XCTAssertTrue(lib.setTakenOut(thingId: lighter.id, false))
        lib.saveTemplate(newList(name: "Base", role: "base"))
        let base = lib.templates.first { $0.role == "base" }!.id
        _ = lib.setOnTemplate(itemId: pouch.id, templateId: base, on: true)
        _ = lib.setKit(kitId: pouch.id, contents: [lighter.id], check: false)
        var trip = newEvent(name: "Away", startDate: "2026-10-01", endDate: "2026-10-05")
        trip.entries = lib.builtLines(trip)
        lib.trips = [trip]
        let kitLine = lib.trips[0].entries.first { $0.sourceItemId == pouch.id }!
        XCTAssertTrue(lib.setChecked(true, tripId: trip.id, entryId: kitLine.id))
        XCTAssertEqual(place(lib, "Lighter", "2026-10-03"), "In the Camp pouch \u{00B7} Packed in the Day pack \u{00B7} Front pocket")
    }

    /// The line IS the answer "Where is my …?" gives: worked out for all things at once (the kit
    /// index and the trip under way once), it says what asking thing by thing says.
    func testEveryLineIsTheAnswerWhereIsMyGivesThingByThing() {
        var (lib, trip) = library()
        let pouch = lib.addThing(name: "Camp pouch")!.id
        let lighter = lib.addThing(name: "Lighter")!.id
        let cord = lib.addThing(name: "Spare cord")!.id
        _ = lib.updateThing(id: pouch) { $0.container = "Tote"; $0.storage = "Garage" }
        _ = lib.setKit(kitId: pouch, contents: [lighter, cord])
        _ = lib.setTakenOut(thingId: cord, true)
        _ = lib.setChecked(true, tripId: trip, entryId: line(lib, "Torch").id)
        for today in ["2026-10-03", "2026-10-20"] {
            let all = lib.spotlightThings(today: today)
            XCTAssertEqual(all.count, lib.items.count, "a thing is missing on \(today)")
            for t in all {
                let a = lib.whereIs(thingId: t.id, today: today)!
                let kit = lib.kitHolding(thingId: t.id)
                let kept = a.kit.isEmpty ? lib.items.first { $0.id == t.id }!.storage : kit!.storage
                XCTAssertEqual(t.place, SpotlightWords.place(a, keptAt: kept), "\(t.title) on \(today)")
                XCTAssertEqual(lib.spotlightThing(id: t.id, today: today), t, "\(t.title): one and all differ")
            }
        }
    }

    func testAThingIsFoundByItsKindOwnerTemplatesBrandModelAndSwedishNameAndNothingPrivate() {
        var lib = Library()
        lib.saveTemplate(newList(name: "Hiking", group: "GA"))
        lib.saveTemplate(newList(name: "Camping", group: "GA"))
        let lamp = lib.addThing(name: "Headlamp")!.id
        for t in lib.templates { _ = lib.setOnTemplate(itemId: lamp, templateId: t.id, on: true) }
        _ = lib.updateThing(id: lamp) {
            $0.category = "Electronics"; $0.ownedBy = "Kim"; $0.manufacturer = "Exempel"; $0.model = "Spot 400"
            $0.swedish = "Pannlampa"; $0.storage = "Garage"
            // Private: never in what Spotlight is handed.
            $0.note = "Door code 4711"; $0.serial = "SN-998877"; $0.expiry = "2027-06-30"; $0.price = 499
            $0.purchaseLink = "https://example.com/lamp"; $0.warranty = "2028-01-01"; $0.acquired = "2025-03-02"
        }
        let t = lib.spotlightThing(id: lamp, today: "2026-10-03")!
        XCTAssertEqual(t.title, "Headlamp")
        // The templates in the order of his templates, as Your things names them.
        XCTAssertEqual(t.keywords, ["Electronics", "Kim", "Hiking", "Camping", "Exempel", "Spot 400", "Pannlampa"])
        let handed = ([t.title, t.place] + t.keywords).joined(separator: " ")
        for secret in ["4711", "Door code", "SN-998877", "2027", "499", "example.com", "2028", "2025"] {
            XCTAssertFalse(handed.contains(secret), "Spotlight is handed '\(secret)': \(handed)")
        }
        // Each once, never the name again, blanks dropped.
        _ = lib.updateThing(id: lamp) { $0.manufacturer = "kim"; $0.model = " "; $0.swedish = "HEADLAMP" }
        XCTAssertEqual(lib.spotlightThing(id: lamp, today: "2026-10-03")!.keywords, ["Electronics", "Kim", "Hiking", "Camping"])
    }

    func testEveryThingOfHisButTheOnesNotInUseAndTheToDos() {
        var (lib, _) = library()
        let base = lib.templates.first { $0.role == "base" }!.id
        _ = lib.addReminder(templateId: base, name: "Water the plants")
        _ = lib.updateThing(id: thing(lib, "Book")) { $0.retired = true }
        let shown = lib.spotlightThings(today: "2026-10-20").map(\.title)
        // A bag is a thing: "Backpack" finds the bag. A–Z, as Your things lists them.
        XCTAssertEqual(shown, ["Backpack", "Charger", "Torch", "Tote"])
        XCTAssertNil(lib.spotlightThing(id: thing(lib, "Book"), today: "2026-10-20"), "a thing not in use is shown")
        XCTAssertNil(lib.spotlightThing(id: "no-such-thing", today: "2026-10-20"))
    }

    func testItsFirstPhotoGoesWithItAndChangesItsFingerprint() {
        var (lib, _) = library()
        let torch = thing(lib, "Torch")
        XCTAssertEqual(lib.spotlightThing(id: torch, today: "2026-10-20")!.photoId, "", "no photo: the app's icon")
        let before = lib.spotlightThing(id: torch, today: "2026-10-20")!.fingerprint
        let photo = lib.addThingPhoto(id: torch, jpeg: Data([1, 2, 3]))!
        let after = lib.spotlightThing(id: torch, today: "2026-10-20")!
        XCTAssertEqual(after.photoId, photo.id)
        XCTAssertNotEqual(after.fingerprint, before, "a new photo is not handed to Spotlight")
    }

    func testTheFingerprintIsTheSameOnEveryLaunchAndChangesWithWhatIsHanded() {
        let t = SpotlightThing(id: "t1", title: "Headlamp", place: "Usually in the Backpack", keywords: ["Kim"], photoId: "")
        // A fixed text: Swift's own hash changes from launch to launch, which would hand
        // everything to Spotlight again at every start.
        XCTAssertEqual(t.fingerprint, "4a6c5ffb09e4c261")
        XCTAssertEqual(t.fingerprint, SpotlightThing(id: "t1", title: "Headlamp", place: "Usually in the Backpack",
                                                     keywords: ["Kim"], photoId: "").fingerprint)
        var other = t
        for change in [{ (x: inout SpotlightThing) in x.title = "Head torch" }, { $0.place = "Usually in the Tote" },
                       { $0.keywords = ["Robin"] }, { $0.photoId = "p1" }, { $0.id = "t2" }] {
            other = t
            change(&other)
            XCTAssertNotEqual(other.fingerprint, t.fingerprint, "a change is not seen: \(other)")
        }
        // Words split differently are different words.
        let a = SpotlightThing(id: "t1", title: "Headlamp", place: "", keywords: ["Kim Robin"], photoId: "")
        let b = SpotlightThing(id: "t1", title: "Headlamp", place: "", keywords: ["Kim", "Robin"], photoId: "")
        XCTAssertNotEqual(a.fingerprint, b.fingerprint)
    }

    func testOnlyWhatChangedIsHandedOverAgainAndWhatWentIsTakenOut() {
        var (lib, trip) = library()
        func indexed(_ things: [SpotlightThing]) -> [String: String] {
            Dictionary(uniqueKeysWithValues: things.map { ($0.id, $0.fingerprint) })
        }
        // The first time: everything, nothing to take out.
        var now = lib.spotlightThings(today: "2026-10-03")
        var c = SpotlightWords.changes(now, indexed: [:])
        XCTAssertEqual(c.put.map(\.title), ["Backpack", "Book", "Charger", "Torch", "Tote"])
        XCTAssertEqual(c.drop, [])
        var held = indexed(now)
        // Nothing changed: nothing to do.
        c = SpotlightWords.changes(lib.spotlightThings(today: "2026-10-03"), indexed: held)
        XCTAssertTrue(c.put.isEmpty && c.drop.isEmpty, "unchanged things handed over again: \(c)")
        // Renamed, and one packed: just those two.
        XCTAssertTrue(lib.renameThing(id: thing(lib, "Torch"), to: "Head torch"))
        XCTAssertTrue(lib.setChecked(true, tripId: trip, entryId: line(lib, "Charger").id))
        now = lib.spotlightThings(today: "2026-10-03")
        c = SpotlightWords.changes(now, indexed: held)
        XCTAssertEqual(c.put.map(\.title), ["Charger", "Head torch"])
        XCTAssertEqual(c.drop, [])
        held = indexed(now)
        // The trip ends: the day alone changes the line of everything on it — home again.
        c = SpotlightWords.changes(lib.spotlightThings(today: "2026-10-20"), indexed: held)
        XCTAssertEqual(c.put.map(\.title), ["Book", "Charger", "Head torch"])
        // Deleted, or set to Not in use: taken out.
        let book = thing(lib, "Book"), torch = thing(lib, "Head torch")
        XCTAssertTrue(lib.deleteThing(id: book))
        _ = lib.updateThing(id: torch) { $0.retired = true }
        c = SpotlightWords.changes(lib.spotlightThings(today: "2026-10-03"), indexed: held)
        XCTAssertEqual(c.put.map(\.title), [])
        XCTAssertEqual(Set(c.drop), [book, torch])
    }

    func testATappedResultNamesItsThing() {
        let t = SpotlightThing(id: "abc123", title: "Headlamp", place: "", keywords: [], photoId: "")
        XCTAssertEqual(t.identifier, "thing:abc123")
        XCTAssertEqual(SpotlightThing.thingId(t.identifier), "abc123")
        XCTAssertNil(SpotlightThing.thingId("trip:abc123"), "another kind of result opened a thing")
        XCTAssertNil(SpotlightThing.thingId("thing:"))
        XCTAssertNil(SpotlightThing.thingId("abc123"))
    }

    /// His ~420 things, kits among them, are worked out after every settled change: it must stay
    /// cheap (asked thing by thing, each answer worked out the kits again).
    func testFourHundredThingsAreWorkedOutQuickly() {
        var lib = Library()
        let bag = lib.addBag(name: "Backpack")!
        _ = lib.addPocket(bagId: bag.id, name: "Lid")
        var hiking = newList(name: "Hiking", group: "GA")
        hiking.items = (1...420).map { newItem(name: String(format: "Invented thing %03d", $0)) }
        lib.saveTemplate(hiking)
        let ids = lib.items.filter { $0.name.hasPrefix("Invented") }.map(\.id)
        for k in 0..<20 { _ = lib.setKit(kitId: ids[k * 20], contents: Array(ids[(k * 20 + 1)...(k * 20 + 5)])) }
        lib.trips = []
        _ = lib.createTrip(newEvent(name: "Away", activities: [lib.templates.first { $0.name == "Hiking" }!.id],
                                    startDate: "2026-10-01", endDate: "2026-10-05"))
        let started = Date()
        let all = lib.spotlightThings(today: "2026-10-03")
        let took = Date().timeIntervalSince(started)
        XCTAssertEqual(all.count, 421)
        XCTAssertLessThan(took, 2.0, "421 things took \(took) s")
        print("SPOTLIGHT 421 things: \(Int(took * 1000)) ms")
    }
}
