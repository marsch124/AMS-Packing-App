import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// Check before you go (his ideas 4 and 5, 2 Oct 2026): on a plane trip, what in a
/// cabin bag the airport stops; and what runs out before he is home — a document
/// six months ahead.
final class TripChecksTests: XCTestCase {
    override func setUp() { PackingEnv.freeze(at: "2026-10-01T12:00:00.000Z") }
    override func tearDown() { PackingEnv.reset() }

    private func thing(_ lib: inout Library, _ name: String, bag: String, on template: String,
                       _ change: (inout Item) -> Void = { _ in }) {
        let t = lib.addThing(name: name)!
        _ = lib.updateThing(id: t.id) { $0.container = bag; change(&$0) }
        _ = lib.setOnTemplate(itemId: t.id, templateId: template, on: true)
    }

    /// A cabin bag (by its name), a hold bag, and a two-month plane trip from one base template.
    private func library() -> (Library, String) {
        var lib = Library()
        _ = lib.addBag(name: "Cabin bag")
        _ = lib.addBag(name: "Suitcase")
        lib.saveTemplate(newList(name: "Base", role: "base"))
        let base = lib.templates.first { $0.role == "base" }!.id
        thing(&lib, "Pocket knife", bag: "Cabin bag", on: base) { $0.restricted = true }
        thing(&lib, "Sun cream", bag: "Cabin bag", on: base) { $0.liquid = true }
        thing(&lib, "Shampoo", bag: "Suitcase", on: base) { $0.liquid = true }
        thing(&lib, "Plasters", bag: "Cabin bag", on: base)
        thing(&lib, "Passport", bag: "Cabin bag", on: base) { $0.category = DOCUMENTS_CATEGORY }
        thing(&lib, "ID card", bag: "Cabin bag", on: base) { $0.category = DOCUMENTS_CATEGORY }
        var trip = newEvent(name: "Two months", startDate: "2026-11-01", endDate: "2026-12-31")
        trip.transport = "Plane"
        let made = lib.createTrip(trip)
        XCTAssertEqual(made.entries.first { $0.name == "Shampoo" }?.container, "Suitcase", "the lines lost their bags")
        return (lib, made.id)
    }

    private func set(_ lib: inout Library, _ name: String, _ change: (inout Item) -> Void) {
        let id = lib.items.first { $0.name == name }!.id
        _ = lib.updateThing(id: id, change)
    }

    func testAPlaneTripChecksItsCabinBagsOnly() {
        var (lib, trip) = library()
        let flags = lib.cabinCheck(tripId: trip)
        XCTAssertEqual(flags.map(\.line.name), ["Pocket knife", "Sun cream"],
                       "not allowed first, then the liquids; the shampoo in the hold and the plasters are no matter")
        XCTAssertEqual(flags.map(\.why), [.notAllowed, .liquid])
        XCTAssertEqual(flags[0].thingId, lib.items.first { $0.name == "Pocket knife" }?.id, "a check must open the thing")
        lib.trips[0].transport = "Car"
        XCTAssertTrue(lib.cabinCheck(tripId: trip).isEmpty, "a car trip is checked for the cabin")
        lib.trips[0].transport = "Plane"
        // Set aside: not packed, so not asked about.
        lib.trips[0].entries = lib.trips[0].entries.map { var l = $0; if l.name == "Pocket knife" { l.skipped = true }; return l }
        XCTAssertEqual(lib.cabinCheck(tripId: trip).map(\.line.name), ["Sun cream"], "a thing set aside is still asked about")
    }

    func testTheThingAsItIsNowDecides() {
        var (lib, trip) = library()
        // Ticked: the thing's change no longer reaches this line — the check must still follow it.
        let line = lib.trips[0].entries.first { $0.name == "Sun cream" }!
        _ = lib.setChecked(true, tripId: trip, entryId: line.id)
        set(&lib, "Sun cream") { $0.liquid = false }
        XCTAssertEqual(lib.cabinCheck(tripId: trip).map(\.line.name), ["Pocket knife"], "the liquid switched off is still asked about")
        set(&lib, "Plasters") { $0.restricted = true }
        XCTAssertEqual(lib.cabinCheck(tripId: trip).map(\.line.name), ["Pocket knife", "Plasters"])
    }

    func testABagSaysWhetherItGoesInTheCabin() {
        var (lib, trip) = library()
        let cabin = lib.bags().first { $0.name == "Cabin bag" }!
        let suitcase = lib.bags().first { $0.name == "Suitcase" }!
        XCTAssertTrue(Library.isCabinBag(cabin), "a cabin bag by its name")
        XCTAssertFalse(Library.isCabinBag(suitcase))
        XCTAssertTrue(lib.setBagCabin(id: cabin.id, false))
        XCTAssertTrue(lib.cabinCheck(tripId: trip).isEmpty, "his word that it goes in the hold is not taken")
        XCTAssertTrue(lib.setBagCabin(id: suitcase.id, true))
        XCTAssertEqual(lib.cabinCheck(tripId: trip).map(\.line.name), ["Shampoo"], "a suitcase he takes on board is not checked")
        let back = Library(records: lib.records())
        XCTAssertEqual(back.cabinCheck(tripId: trip).map(\.line.name), ["Shampoo"], "the stored records lost his word")
        let plasters = lib.items.first { $0.name == "Plasters" }!
        XCTAssertFalse(lib.setBagCabin(id: plasters.id, true), "only a bag takes it")
        // A bag he never made: the web app's carry-on is the cabin by its name.
        XCTAssertTrue(lib.isCabin(container: "Carry-on / hand luggage"))
        XCTAssertFalse(lib.isCabin(container: "Checked luggage"))
    }

    /// Field test 7.3/6.1 (3 Oct 2026): the bag they packed into was a name on the lines,
    /// not one of their bags — the trip itself must be able to say it goes in the cabin.
    func testABagNameOnTheTripCanBeSaidToGoInTheCabin() {
        var (lib, trip) = library()
        // A thing packed into a name that is no bag, and says nothing about the cabin.
        let t = lib.addThing(name: "Multitool")!
        _ = lib.updateThing(id: t.id) { $0.container = "Red backpack"; $0.restricted = true }
        _ = lib.setOnTemplate(itemId: t.id, templateId: lib.templates.first { $0.role == "base" }!.id, on: true)
        _ = lib.changeTrip(id: trip) { $0.name = "Two months" }          // rebuild: the multitool comes along
        XCTAssertFalse(lib.cabinCheck(tripId: trip).map(\.line.name).contains("Multitool"), "a bag not said to be the cabin is checked")
        XCTAssertTrue(lib.setCabin(container: "Red backpack", true))
        XCTAssertTrue(lib.bags().contains { $0.name == "Red backpack" }, "the name did not become a bag")
        XCTAssertTrue(lib.cabinCheck(tripId: trip).map(\.line.name).contains("Multitool"), "the cabin bag said from the trip is not checked")
        XCTAssertTrue(lib.setCabin(container: "Red backpack", false))
        XCTAssertFalse(lib.cabinCheck(tripId: trip).map(\.line.name).contains("Multitool"))
        XCTAssertEqual(lib.bags().filter { $0.name == "Red backpack" }.count, 1, "saying it twice made two bags")
        XCTAssertFalse(lib.setCabin(container: "Other", true), "\"Not in a bag\" became a bag")
    }

    /// Field test 6.1: a QUICK trip by plane is checked too — Quick drops the transport
    /// kit, not the transport.
    func testAQuickTripByPlaneIsCheckedToo() {
        var lib = Library()
        _ = lib.addBag(name: "Cabin bag")
        var kit = newList(name: "Kit", group: "GA")
        kit.items = []
        lib.saveTemplate(kit)
        let kitId = lib.templates.first { $0.name == "Kit" }!.id
        let knife = lib.addThing(name: "Knife")!
        _ = lib.updateThing(id: knife.id) { $0.container = "Cabin bag"; $0.restricted = true }
        _ = lib.setOnTemplate(itemId: knife.id, templateId: kitId, on: true)
        var trip = newEvent(name: "Quick hop", startDate: "2026-11-01", endDate: "2026-11-03")
        trip.mode = "quick"; trip.activities = [kitId]; trip.transport = "Plane"
        let made = lib.createTrip(trip)
        XCTAssertEqual(made.entries.map(\.name), ["Knife"], "the quick trip is not just the kit")
        XCTAssertEqual(lib.cabinCheck(tripId: made.id).map(\.line.name), ["Knife"], "a quick trip by plane is not checked")
    }

    func testWhatRunsOutBeforeHomeAndADocumentSixMonthsAhead() {
        var (lib, trip) = library()                               // the trip ends 2026-12-31
        set(&lib, "Sun cream") { $0.expiry = "2026-12-01" }      // runs out during the trip
        set(&lib, "Plasters") { $0.expiry = "2026-09-01" }       // out of date already
        set(&lib, "Shampoo") { $0.expiry = "2027-03-01" }        // good past the trip
        set(&lib, "Passport") { $0.expiry = "2027-05-01" }       // four months after: short of six
        set(&lib, "ID card") { $0.expiry = "2027-08-01" }        // seven months after: fine
        let flags = lib.dateCheck(tripId: trip, todayISO: "2026-10-01")
        XCTAssertEqual(flags.map(\.line.name), ["Plasters", "Sun cream", "Passport"],
                       "soonest first; the shampoo and the ID card are fine")
        XCTAssertEqual(flags.map(\.alreadyOut), [true, false, false])
        XCTAssertEqual(flags.map(\.beforeHome), [true, true, false])
        XCTAssertEqual(flags.map(\.document), [false, false, true])
        // A new passport: the date goes, the passport leaves the check.
        set(&lib, "Passport") { $0.expiry = "" }
        XCTAssertEqual(lib.dateCheck(tripId: trip, todayISO: "2026-10-01").map(\.line.name), ["Plasters", "Sun cream"])
        lib.trips[0].endDate = ""
        XCTAssertTrue(lib.dateCheck(tripId: trip, todayISO: "2026-10-01").isEmpty, "a trip without dates was judged")
    }

    func testSixMonthsOnIsTheSameDayOrTheMonthsLast() {
        XCTAssertEqual(Library.ymd("2026-11-30", plusMonths: 6), "2027-05-30")
        XCTAssertEqual(Library.ymd("2026-08-31", plusMonths: 6), "2027-02-28")
        XCTAssertEqual(Library.ymd("2027-08-31", plusMonths: 6), "2028-02-29")
        XCTAssertEqual(Library.ymd("2026-12-31", plusMonths: 6), "2027-06-30")
    }
}
