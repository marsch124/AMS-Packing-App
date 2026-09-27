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
