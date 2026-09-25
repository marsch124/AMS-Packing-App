import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// His bags: a limit set on one must be the limit every trip measures it against.
final class ContainersTests: XCTestCase {
    func testABagGetsMadeAndItsListWithIt() {
        var lib = Library()
        XCTAssertNil(lib.containerList, "a fresh library has no Containers list")
        XCTAssertNotNil(lib.addBag(name: "Duffel bag"))
        XCTAssertEqual(lib.containerList?.role, CONTAINER_ROLE, "the list was made for it")
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
