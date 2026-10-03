import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// His bags: a limit set on one must be the limit every trip measures it against.
final class BagsTests: XCTestCase {
    func testABagGetsMadeAndItsListWithIt() {
        var lib = Library()
        XCTAssertNil(lib.bagList, "a fresh library has no bag list")
        XCTAssertNotNil(lib.addBag(name: "Duffel bag"))
        XCTAssertEqual(lib.bagList?.role, CONTAINER_ROLE, "the list was made for it")
        XCTAssertEqual(lib.bags().map(\.name), ["Duffel bag"])
    }

    func testTwoBagsWithOneNameAreRefused() {
        var lib = Library()
        lib.addBag(name: "Duffel bag")
        XCTAssertNil(lib.addBag(name: "duffel BAG"), "bags are joined by name, so one name is one bag")
        XCTAssertEqual(lib.bags().count, 1)
    }

    func testALimitSetHereIsTheLimitATripUses() {
        var lib = Library()
        let bag = lib.addBag(name: "Duffel bag")!
        XCTAssertTrue(lib.setBag(id: bag.id, maxKg: 10))

        // A trip with 12 kg in that bag.
        var heavy = newItem(name: "Weights"); heavy.weight = 12000; heavy.container = "Duffel bag"
        let loads = bagLoads([heavy], 0, lib.bagLimits())
        XCTAssertEqual(loads.first?.limitKg, 10, "the trip must see the limit he set")
        XCTAssertEqual(loads.first?.over, true, "12 kg in a 10 kg bag is over")
    }

    func testSettingNumbersOnSomethingThatIsNotABagIsRefused() {
        var lib = Library()
        let thing = lib.addThing(name: "Towel")!
        XCTAssertFalse(lib.setBag(id: thing.id, maxKg: 5), "only a bag has a limit")
        XCTAssertEqual(lib.items.first { $0.id == thing.id }?.maxKg, 0)
    }

    func testAThingHeAlreadyOwnsBecomesABagRatherThanBeingRefused() {
        var lib = Library()
        let thing = lib.addThing(name: "Toiletry bag")!
        let bag = lib.addBag(name: "Toiletry bag")
        XCTAssertEqual(bag?.id, thing.id, "the thing he owns IS the bag — not a second thing")
        XCTAssertEqual(lib.bags().map(\.name), ["Toiletry bag"])
        XCTAssertEqual(lib.items.filter { $0.name == "Toiletry bag" }.count, 1, "never two things of one name")
    }
}

/// His asks (2026-09-26): rename and delete a bag from Your bags. A bag is found by
/// its NAME everywhere, so both must carry through every field — his choices: a
/// rename reaches all trips; a delete moves its things to a bag he picks.
final class BagEditsTests: XCTestCase {
    override func setUp() { PackingEnv.freeze() }
    override func tearDown() { PackingEnv.reset() }

    private func library() -> (Library, duffel: String, swim: String, trip: String) {
        var lib = Library()
        let duffel = lib.addBag(name: "Duffel bag")!.id
        let swim = lib.addBag(name: "Swim bag")!.id
        lib.setBag(id: duffel, maxKg: 20)
        // The list's own default bag outranks a thing's own bag on a trip (the web
        // app's rule), so the Duffel bag is the default and the Swim bag an exception.
        var l = newList(name: "Swim", defaultContainer: "Duffel bag")
        l.items = [newItem(name: "Goggles", container: "Swim bag"), newItem(name: "Towel", container: "Duffel bag"),
                   { var i = newItem(name: "Socks", container: "Duffel bag"); i.weight = 300; return i }()]
        lib.saveTemplate(l)
        // One list row with its own bag: the Towel goes in the Swim bag on this list.
        if let t = lib.items.first(where: { $0.name == "Towel" }),
           let m = lib.memberships.firstIndex(where: { $0.itemId == t.id }) { lib.memberships[m].container = "Swim bag" }
        var draft = newEvent(name: "Pool", startDate: "2026-09-20", endDate: "2026-09-21")
        draft.activities = [lib.templates.first { $0.name == "Swim" }!.id]
        draft.mode = "quick"
        let trip = lib.createTrip(draft)
        return (lib, duffel, swim, trip.id)
    }

    func testARenamedBagTakesItsThingsListsTripsAndLimitAlong() {
        var (lib, duffel, _, _) = library()
        XCTAssertTrue(lib.renameThing(id: duffel, to: "Big duffel"))
        XCTAssertFalse(lib.items.contains { $0.container == "Duffel bag" }, "a thing still names the old bag")
        XCTAssertEqual(lib.items.first { $0.name == "Socks" }?.container, "Big duffel")
        XCTAssertFalse(lib.trips[0].entries.contains { $0.container == "Duffel bag" || $0.defContainer == "Duffel bag" },
                       "a trip line still names the old bag — his choice: all trips")
        XCTAssertEqual(lib.bagLimits()["Big duffel"], 20, "its limit follows the name")
        XCTAssertEqual(lib.templates.first { $0.name == "Swim" }?.defaultContainer, "Big duffel", "a list's default bag follows")
        XCTAssertTrue(lib.bags().contains { $0.name == "Big duffel" })
        XCTAssertFalse(lib.renameThing(id: duffel, to: "Swim bag"), "two bags with one name would be one bag")
    }

    func testADeletedBagMovesItsThingsToTheBagHePicks() {
        var (lib, duffel, swim, _) = library()
        XCTAssertEqual(lib.bagFacts(name: "Swim bag").things.map(\.name), ["Goggles", "Towel"], "its own and a list's exception")
        XCTAssertFalse(lib.deleteBag(id: swim, moveTo: "Nowhere"), "only to one of his bags")
        XCTAssertTrue(lib.deleteBag(id: swim, moveTo: "Duffel bag"))
        XCTAssertEqual(lib.bags().map(\.name), ["Duffel bag"])
        XCTAssertFalse(lib.items.contains { $0.name == "Swim bag" }, "the bag was on no list of his, so the thing goes too")
        XCTAssertEqual(lib.items.first { $0.name == "Goggles" }?.container, "Duffel bag")
        XCTAssertFalse(lib.memberships.contains { $0.container == "Swim bag" }, "a list row still names it")
        XCTAssertFalse(lib.trips[0].entries.contains { $0.container == "Swim bag" }, "a trip line still names it")
        XCTAssertTrue(lib.deleteBag(id: duffel, moveTo: ""), "his last bag may go with no bag to move to")
        XCTAssertEqual(lib.items.first { $0.name == "Goggles" }?.container, "")
    }

    /// His ask (2026-09-27): deleting a bag may leave its things with NO bag — and a
    /// bag nothing is packed in is known to be unused, so it can simply go.
    func testABagCanGoWithItsThingsLeftWithoutABag() {
        var (lib, duffel, swim, _) = library()
        let spare = lib.addBag(name: "Handbag")!.id
        XCTAssertFalse(lib.bagIsUsed(name: "Handbag"), "nothing is packed in the new bag")
        XCTAssertTrue(lib.bagIsUsed(name: "Swim bag"))
        XCTAssertTrue(lib.bagIsUsed(name: "Duffel bag"))
        XCTAssertTrue(lib.deleteBag(id: spare, moveTo: ""))
        XCTAssertTrue(lib.deleteBag(id: swim, moveTo: ""), "no bag, while he still has another")
        XCTAssertEqual(lib.items.first { $0.name == "Goggles" }?.container, "", "its thing is left without a bag")
        XCTAssertFalse(lib.memberships.contains { $0.container == "Swim bag" })
        XCTAssertFalse(lib.trips[0].entries.contains { $0.container == "Swim bag" }, "a trip line still names it")
        XCTAssertFalse(lib.bagIsUsed(name: "Swim bag"))
        XCTAssertEqual(lib.bags().map(\.id), [duffel])
    }

    /// His ask (2026-09-27): the app says "Bags" everywhere. The bag list is stored
    /// under the web app's name "Containers"; wherever a list's name is shown it reads "Bags".
    func testTheBagListIsShownAsBags() {
        let (lib, duffel, _, _) = library()
        XCTAssertEqual(lib.bagList?.name, CONTAINER_LIST_NAME, "the stored name stays the web app's")
        XCTAssertEqual(lib.shownName(lib.bagList!), "Bags")
        let row = lib.thingRows().first { $0.item.id == duffel }
        XCTAssertEqual(row?.templates, ["Bags"], "Your things shows the bag list as Bags")
        XCTAssertFalse(lib.thingRows().contains { $0.templates.contains("Containers") })
    }

    /// His Day pack (2026-09-27): a bag that is ALSO a thing on a list (he packs
    /// the day pack itself on Travel). Deleted as a bag only, it stays on the list;
    /// deleted completely, it is gone from every list. Past trips keep their lines.
    func testABagThatIsAlsoOnAListIsKeptOrDeletedCompletely() {
        var (lib, duffel, swim, trip) = library()
        let swimList = lib.templates.first { $0.name == "Swim" }!.id
        lib.setOnTemplate(itemId: swim, templateId: swimList, on: true)
        XCTAssertEqual(lib.listsHoldingBag(id: swim), ["Swim"])
        XCTAssertTrue(lib.deleteBag(id: swim, moveTo: "Duffel bag"))
        XCTAssertFalse(lib.bags().contains { $0.id == swim }, "no longer a bag")
        XCTAssertTrue(lib.items.contains { $0.id == swim }, "bag only: the thing stays on Swim")
        XCTAssertEqual(lib.listsOf(itemId: swim), ["Swim"])

        lib.setOnTemplate(itemId: duffel, templateId: swimList, on: true)
        let lines = lib.trips.first { $0.id == trip }!.entries.count
        XCTAssertTrue(lib.deleteBag(id: duffel, moveTo: "", completely: true))
        XCTAssertFalse(lib.items.contains { $0.id == duffel }, "completely: the thing is gone")
        XCTAssertFalse(lib.memberships.contains { $0.itemId == duffel }, "and off every list")
        XCTAssertEqual(lib.trips.first { $0.id == trip }!.entries.count, lines, "past trips keep their lines")
    }

    /// His ask (2026-09-27): a thing can be deleted — off every list and kit. A bag
    /// is refused here: its delete asks where its things go.
    func testAThingIsDeletedButABagIsNotDeletedAsAThing() {
        var (lib, duffel, _, _) = library()
        let socks = lib.items.first { $0.name == "Socks" }!.id
        lib.kits = [Kit(id: "k1", name: "Run kit", emoji: "", note: "", itemIds: [socks, "other"], createdAt: "", updatedAt: "", extra: [:])]
        XCTAssertEqual(lib.listsOf(itemId: socks), ["Swim"])
        XCTAssertTrue(lib.deleteThing(id: socks))
        XCTAssertFalse(lib.items.contains { $0.id == socks })
        XCTAssertFalse(lib.memberships.contains { $0.itemId == socks }, "still on a list")
        XCTAssertEqual(lib.kits[0].itemIds, ["other"], "still in a kit")
        XCTAssertFalse(lib.deleteThing(id: duffel), "a bag goes through its own delete")
        XCTAssertFalse(lib.deleteThing(id: "nope"))
    }

    func testABagKnowsItsTrips() {
        let (lib, _, _, trip) = library()
        let facts = lib.bagFacts(name: "Duffel bag")
        XCTAssertEqual(facts.trips.map(\.tripId), [trip])
        XCTAssertEqual(facts.trips.first?.limitKg, 20)
        XCTAssertGreaterThan(facts.heaviest?.grams ?? 0, 0)
    }
}

/// What a trip keeps about a bag BY ITS NAME — the luggage scale's reading and the
/// photos of it packed. Until 3 Oct 2026 a rename or a delete left them under the old
/// name: nothing deleted, but the trip's reading and photos silently gone from view.
final class BagNotesTests: XCTestCase {
    override func setUp() { PackingEnv.freeze(at: "2026-10-03T12:00:00.000Z") }
    override func tearDown() { PackingEnv.reset() }

    /// Two bags, and two trips packing a thing into each.
    private func library() -> (Library, duffel: String, swim: String, trips: [String]) {
        var lib = Library()
        let duffel = lib.addBag(name: "Duffel bag")!.id
        let swim = lib.addBag(name: "Swim bag")!.id
        lib.saveTemplate(newList(name: "Base", role: "base"))
        let base = lib.templates.first { $0.role == "base" }!.id
        for (name, bag) in [("Towel", "Duffel bag"), ("Goggles", "Swim bag")] {
            let t = lib.addThing(name: name)!
            _ = lib.updateThing(id: t.id) { $0.container = bag; $0.weight = 300 }
            _ = lib.setOnTemplate(itemId: t.id, templateId: base, on: true)
        }
        var trips: [String] = []
        for (name, day) in [("Spring", "2026-04-01"), ("Autumn", "2026-11-01")] {
            trips.append(lib.createTrip(newEvent(name: name, startDate: day, endDate: day)).id)
        }
        return (lib, duffel, swim, trips)
    }

    private func trip(_ lib: Library, _ id: String) -> TripEvent { lib.trips.first { $0.id == id }! }

    func testARenamedBagTakesItsScaleReadingAndPhotosAlongOnEveryTrip() {
        var (lib, duffel, _, trips) = library()
        var shots: [String: [String]] = [:]
        for (k, t) in trips.enumerated() {
            _ = lib.setWeighed(tripId: t, bag: "Duffel bag", grams: Double(9000 + k * 1000))
            shots[t] = (1...2).compactMap { n in lib.addBagPhoto(tripId: t, bag: "Duffel bag", jpeg: Data([UInt8(k), UInt8(n)]))?.id }
        }
        XCTAssertTrue(lib.renameThing(id: duffel, to: "Big duffel"))
        for (k, t) in trips.enumerated() {
            XCTAssertEqual(lib.weighed(tripId: t), ["Big duffel": Double(9000 + k * 1000)],
                           "the scale reading stayed under the old name")
            XCTAssertEqual(lib.weighedBags(tripId: t).first { $0.load.container == "Big duffel" }?.scaleGrams,
                           Double(9000 + k * 1000), "the trip's Bags card lost the reading")
            XCTAssertEqual(lib.bagPhotoIds(tripId: t, bag: "Big duffel"), shots[t],
                           "the photos stayed under the old name, or lost their order")
            XCTAssertNil(trip(lib, t).extra[BAG_PHOTOS_KEY]?.objectValue?["Duffel bag"], "photos left under the old name")
        }
        XCTAssertEqual(lib.photos.count, 4, "a photo record was lost")
        XCTAssertEqual(Library(records: lib.records()).bagPhotos(tripId: trips[0], bag: "Big duffel").map(\.id), shots[trips[0]],
                       "the stored records lost the moved photos")
    }

    /// 0.52 and 0.53 kept a bag's one photo as a plain id, not a list; and a trip may
    /// hold the name spelled another way. Both are this bag, and both move.
    func testAPhotoKeptByAnOlderVersionAndAnotherSpellingFollowTheRename() {
        var (lib, duffel, _, trips) = library()
        lib.photos.append(PhotoRecord(id: "old-photo", data: "data:image/jpeg;base64,AQID", createdAt: "2026-04-01T12:00:00.000Z"))
        let n = lib.trips.firstIndex { $0.id == trips[0] }!
        lib.trips[n].extra[BAG_PHOTOS_KEY] = .object(["duffel  BAG ": .string("old-photo")])
        lib.trips[n].extra[WEIGHED_KEY] = .object(["duffel  BAG ": .number(8000)])
        XCTAssertTrue(lib.renameThing(id: duffel, to: "Big duffel"))
        XCTAssertEqual(lib.bagPhotoIds(tripId: trips[0], bag: "Big duffel"), ["old-photo"], "the older photo was left behind")
        XCTAssertEqual(trip(lib, trips[0]).extra[BAG_PHOTOS_KEY], .object(["Big duffel": .array([.string("old-photo")])]),
                       "not stored as the list 0.54 writes, or something left under the old name")
        XCTAssertEqual(lib.weighed(tripId: trips[0]), ["Big duffel": 8000], "a reading under another spelling was left behind")
        XCTAssertTrue(lib.photos.contains { $0.id == "old-photo" }, "the older photo's record was lost")
    }

    /// The new name already has its own on a trip (here: kept from a bag that once had
    /// that name). Its own reading stays; photos: its own first, then the moved ones,
    /// up to three. The one pushed out goes — unless something else still shows it.
    func testARenameOntoANameTheTripAlreadyKeepsMergesThem() {
        var (lib, duffel, _, trips) = library()
        let t = trips[1]
        _ = lib.setWeighed(tripId: t, bag: "Big duffel", grams: 15000)
        let own = (1...2).compactMap { k in lib.addBagPhoto(tripId: t, bag: "Big duffel", jpeg: Data([9, UInt8(k)]))?.id }
        _ = lib.setWeighed(tripId: t, bag: "Duffel bag", grams: 4000)
        let moved = (1...3).compactMap { k in lib.addBagPhoto(tripId: t, bag: "Duffel bag", jpeg: Data([8, UInt8(k)]))?.id }
        // The third moved photo is also shown on the other trip's Swim bag.
        let other = lib.trips.firstIndex { $0.id == trips[0] }!
        lib.trips[other].extra[BAG_PHOTOS_KEY] = .object(["Swim bag": .array([.string(moved[2])])])

        XCTAssertTrue(lib.renameThing(id: duffel, to: "Big duffel"))
        XCTAssertEqual(lib.weighed(tripId: t), ["Big duffel": 15000], "the new name's own reading was replaced")
        XCTAssertEqual(lib.bagPhotoIds(tripId: t, bag: "Big duffel"), own + [moved[0]],
                       "not its own first, then the moved ones, up to three")
        XCTAssertNil(trip(lib, t).extra[BAG_PHOTOS_KEY]?.objectValue?["Duffel bag"], "photos left under the old name")
        XCTAssertFalse(lib.photos.contains { $0.id == moved[1] }, "a photo nothing shows any more was kept")
        XCTAssertTrue(lib.photos.contains { $0.id == moved[2] }, "a photo another bag still shows was deleted")
    }

    /// A deleted bag's things move to the bag he picks — and so do its photos. Its
    /// scale reading goes along only where that bag had nothing of its own on the
    /// trip: a reading is what ONE bag weighed, and the bag kept is judged by it.
    func testADeletedBagTakesItsPhotosAndReadingToTheBagHePicks() {
        var (lib, _, swim, trips) = library()
        // Spring: both bags went, both weighed. Autumn: only the Swim bag went.
        _ = lib.setWeighed(tripId: trips[0], bag: "Duffel bag", grams: 12000)
        let duffelShot = lib.addBagPhoto(tripId: trips[0], bag: "Duffel bag", jpeg: Data([1]))!.id
        _ = lib.setWeighed(tripId: trips[0], bag: "Swim bag", grams: 2500)
        let swimShot = lib.addBagPhoto(tripId: trips[0], bag: "Swim bag", jpeg: Data([2]))!.id
        let autumn = lib.trips.firstIndex { $0.id == trips[1] }!
        lib.trips[autumn].entries.removeAll { $0.container == "Duffel bag" }
        _ = lib.setWeighed(tripId: trips[1], bag: "Swim bag", grams: 2600)

        XCTAssertTrue(lib.deleteBag(id: swim, moveTo: "Duffel bag"))
        XCTAssertEqual(lib.weighed(tripId: trips[0]), ["Duffel bag": 12000], "the bag he picked lost its own reading")
        XCTAssertEqual(lib.bagPhotoIds(tripId: trips[0], bag: "Duffel bag"), [duffelShot, swimShot],
                       "the deleted bag's photo did not follow its things")
        XCTAssertEqual(lib.weighed(tripId: trips[1]), ["Duffel bag": 2600],
                       "where only the deleted bag went, its reading is the reading of what it held")

        // And a Duffel bag that went on Spring unweighed does not take the Swim bag's reading.
        var (again, _, swim2, trips2) = library()
        _ = again.setWeighed(tripId: trips2[0], bag: "Swim bag", grams: 2500)
        XCTAssertTrue(again.deleteBag(id: swim2, moveTo: "Duffel bag"))
        XCTAssertTrue(again.weighed(tripId: trips2[0]).isEmpty,
                      "the Duffel bag is judged by a reading that never included its own things")
        XCTAssertEqual(again.weighedBags(tripId: trips2[0]).first { $0.load.container == "Duffel bag" }?.grams, 600,
                       "unweighed, its things' sum")
    }

    /// Deleted with NO bag: its things show under "Other" ("Not in a bag" on the way
    /// home), and its photos go with them. Its reading goes — loose things were never
    /// one bag on the scale.
    func testABagDeletedWithNoBagLeavesItsPhotosWithItsThingsAndDropsItsReading() {
        var (lib, _, swim, trips) = library()
        _ = lib.setWeighed(tripId: trips[0], bag: "Swim bag", grams: 2500)
        let shot = lib.addBagPhoto(tripId: trips[0], bag: "Swim bag", jpeg: Data([3]))!.id
        XCTAssertTrue(lib.deleteBag(id: swim, moveTo: ""))
        XCTAssertTrue(lib.weighedBags(tripId: trips[0]).contains { $0.load.container == "Other" }, "the things are not under Other")
        XCTAssertEqual(lib.bagPhotoIds(tripId: trips[0], bag: "Other"), [shot], "the photo did not go with its things")
        XCTAssertTrue(lib.photos.contains { $0.id == shot }, "the photo's record was lost")
        XCTAssertTrue(lib.weighed(tripId: trips[0]).isEmpty, "a bag that is gone still has a scale reading")
        XCTAssertNil(trip(lib, trips[0]).extra[WEIGHED_KEY], "an empty record is left on the trip")
    }
}
