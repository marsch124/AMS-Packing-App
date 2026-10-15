import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// No tags inside another bag (0.86, spec 07 part 17 "0.86" — his yes of 15 Oct 2026: "Yes - no
/// tags inside another bag"): Packing Stations' Tags lists only the bags that travel by themselves.
/// Invented data only — this repository is public.
final class TagsInsideTests: XCTestCase {
    override func setUp() { PackingEnv.freeze(at: "2026-10-13T12:00:00.000Z") }
    override func tearDown() { PackingEnv.reset() }

    private let carryOn = "Carry-on / hand luggage"

    /// As PackingDayTests, plus a Toiletry bag: the base template holds a Passport and a Charger in
    /// the carry-on, a Toothbrush in the Toiletry bag, and the Toiletry bag itself — packed in the
    /// carry-on (one of his bags too); Hike: Boots and a Jacket in the Day pack (one of his bags), a
    /// Water bottle in no bag. The trip "Hill week", 20–24 Oct 2026, from Hike.
    private func library() -> (Library, String) {
        var lib = Library()
        var base = newList(name: "Common base", role: "base")
        base.items = [newItem(name: "Passport"), newItem(name: "Charger"),
                      newItem(name: "Toothbrush", container: "Toiletry bag"),
                      newItem(name: "Toiletry bag", container: carryOn)]
        lib.saveTemplate(base)
        var hike = newList(name: "Hike")
        hike.items = [newItem(name: "Boots", container: "Day pack"), newItem(name: "Jacket", container: "Day pack"),
                      newItem(name: "Water bottle", container: "")]
        lib.saveTemplate(hike)
        XCTAssertNotNil(lib.addBag(name: "Day pack"))
        XCTAssertNotNil(lib.addBag(name: "Toiletry bag"), "the thing he packs becomes one of his bags")
        let hikeId = lib.templates.first { $0.name == "Hike" }!.id
        let trip = lib.createTrip(newEvent(name: "Hill week", activities: [hikeId], startDate: "2026-10-20", endDate: "2026-10-24")).id
        return (lib, trip)
    }

    private func day(_ lib: Library, _ trip: String) -> PackingDay { lib.packingDay(tripId: trip)! }
    private func line(_ lib: Library, _ name: String) -> String { lib.trips[0].entries.first { $0.name == name }!.id }
    private func thing(_ lib: Library, _ name: String) -> String { lib.items.first { $0.name == name }!.id }

    func testTagsLeaveOutABagPackedInsideAnotherAndAskAgainOnceItTravelsAlone() {
        var (lib, trip) = library()
        // Every station but Tags still asks about all three bags (the card's order: the web app's
        // built-in bag order puts the Toiletry bag first).
        XCTAssertEqual(lib.dayBags(tripId: trip), ["Toiletry bag", carryOn, "Day pack"])
        var d = day(lib, trip)
        XCTAssertEqual(d.bags.map(\.inside), [carryOn, "", ""], "the Toiletry bag's own line is packed in the carry-on")
        XCTAssertEqual(d.words(.bagsOut), "0 of 3 out")
        XCTAssertEqual(d.words(.weigh), "0 of 3 weighed")
        XCTAssertEqual(d.words(.photos), "0 of 4 photos")
        // Tags: only the bags that travel by themselves.
        XCTAssertEqual(d.tagged.map(\.name), [carryOn, "Day pack"])
        XCTAssertEqual(d.insideAnother.map(\.name), ["Toiletry bag"])
        XCTAssertEqual(d.words(.tags), "0 of 2 ticked")
        XCTAssertEqual(d.tagsInsideWords, "No tags inside another bag: Toiletry bag (in the Carry-on / hand luggage).")
        XCTAssertEqual(lib.bagInside(tripId: trip, bag: "toiletry BAG"), carryOn)
        XCTAssertEqual(lib.bagInside(tripId: trip, bag: carryOn), "")
        // Its AirTag is not asked for either: it is found with the bag it is in.
        XCTAssertTrue(lib.setAirTag(container: "Toiletry bag", true))
        XCTAssertEqual(day(lib, trip).counts(.tags).of, 2, "an AirTag inside an inner bag was asked for")
        // Done with the two that travel alone; a tick kept for the inner bag counts for nothing.
        XCTAssertTrue(lib.setNameTag(true, tripId: trip, bag: "Toiletry bag"))
        XCTAssertEqual(day(lib, trip).words(.tags), "0 of 2 ticked", "the inner bag's tick counted")
        _ = lib.setNameTag(true, tripId: trip, bag: carryOn)
        _ = lib.setNameTag(true, tripId: trip, bag: "Day pack")
        d = day(lib, trip)
        XCTAssertTrue(d.done(.tags), "the bags that travel alone are tagged: '\(d.words(.tags))'")
        XCTAssertEqual(d.state(.tags), "done")
        XCTAssertEqual(d.counts(.ready).done, 1, "Ready does not count Tags as done")

        // Taken out to travel alone — its Usually packed in No bag, which reaches the trip ahead: Tags
        // asks about it again, its kept name tag counts again, its AirTag is asked for.
        XCTAssertTrue(lib.updateThing(id: thing(lib, "Toiletry bag")) { $0.container = "" })
        XCTAssertEqual(lib.trips[0].entries.first { $0.name == "Toiletry bag" }?.container, "", "the change did not reach the trip")
        d = day(lib, trip)
        XCTAssertEqual(d.tagged.map(\.name), ["Toiletry bag", carryOn, "Day pack"])
        XCTAssertEqual(d.tagsInsideWords, "")
        XCTAssertEqual(d.words(.tags), "3 of 4 ticked", "the Toiletry bag's name tag and AirTag")
        XCTAssertFalse(d.done(.tags))
    }

    func testOnlyTheBagsOwnLineOnTheTripSaysItIsInside() {
        var (lib, trip) = library()
        // The thing's Usually packed in alone is no evidence: a bag made in the app starts "in the
        // carry-on" (the built-in default), and the Day pack has no line of its own on the trip —
        // it travels by itself.
        XCTAssertEqual(lib.items.first { $0.name == "Day pack" }?.container, carryOn, "the default changed")
        XCTAssertEqual(lib.bagInside(tripId: trip, bag: "Day pack"), "")
        // Set aside, its line says nothing: the bag is asked about.
        _ = lib.setAside(true, tripId: trip, entryId: line(lib, "Toiletry bag"))
        XCTAssertEqual(day(lib, trip).tagged.map(\.name), ["Toiletry bag", carryOn, "Day pack"])
        _ = lib.setAside(false, tripId: trip, entryId: line(lib, "Toiletry bag"))
        XCTAssertEqual(lib.bagInside(tripId: trip, bag: "Toiletry bag"), carryOn)
        // A reminder of its name is no line of the bag.
        var t = lib.trips[0]
        if let n = t.entries.firstIndex(where: { $0.name == "Toiletry bag" }) {
            t.entries[n].itemType = REMINDER_TYPE
        }
        lib.trips[0] = t
        XCTAssertEqual(lib.bagInside(tripId: trip, bag: "Toiletry bag"), "")
        // Its own line, found by its thing even under another name (a line keeps the name it was
        // packed with), packed in the Day pack this time.
        t = lib.trips[0]
        if let n = t.entries.firstIndex(where: { $0.name == "Toiletry bag" }) {
            t.entries[n].itemType = "item"
            t.entries[n].name = "Wash kit"
            t.entries[n].container = "Day pack"
        }
        lib.trips[0] = t
        XCTAssertEqual(lib.bagInside(tripId: trip, bag: "Toiletry bag"), "Day pack", "found by name only, not by its thing")
        XCTAssertEqual(day(lib, trip).tagsInsideWords, "No tags inside another bag: Toiletry bag (in the Day pack).")
        // Packed in itself, or in no bag: it travels by itself.
        for bag in ["Toiletry bag", "", "Other"] {
            t = lib.trips[0]
            if let n = t.entries.firstIndex(where: { $0.name == "Wash kit" }) { t.entries[n].container = bag }
            lib.trips[0] = t
            XCTAssertEqual(lib.bagInside(tripId: trip, bag: "Toiletry bag"), "", "packed in '\(bag)'")
        }
        XCTAssertEqual(lib.bagInside(tripId: "nope", bag: "Toiletry bag"), "")
    }

    func testABagInsideABagInsideABagAndARingWithNothingOutsideIt() {
        var lib = Library()
        var base = newList(name: "Common base", role: "base")
        base.items = [newItem(name: "Passport", container: carryOn),
                      newItem(name: "Toiletry bag", container: carryOn),
                      newItem(name: "Toothbrush", container: "Toiletry bag"),
                      newItem(name: "Pill pouch", container: "Toiletry bag"),
                      newItem(name: "Pills", container: "Pill pouch"),
                      // A ring: each pouch said to be inside the other — nothing is outside them.
                      newItem(name: "Red pouch", container: "Blue pouch"),
                      newItem(name: "Blue pouch", container: "Red pouch"),
                      newItem(name: "Coin purse", container: "Red pouch"),
                      newItem(name: "Coins", container: "Coin purse")]
        lib.saveTemplate(base)
        let trip = lib.createTrip(newEvent(name: "Town", startDate: "2026-10-20", endDate: "2026-10-21")).id
        let d = day(lib, trip)
        XCTAssertEqual(Dictionary(uniqueKeysWithValues: d.bags.map { ($0.name, $0.inside) }),
                       ["Toiletry bag": carryOn, carryOn: "", "Pill pouch": "Toiletry bag",
                        "Red pouch": "", "Blue pouch": "", "Coin purse": "Red pouch"])
        XCTAssertEqual(Set(d.tagged.map(\.name)), [carryOn, "Red pouch", "Blue pouch"])
        XCTAssertEqual(d.tagsInsideWords,
                       "No tags inside another bag: " + d.insideAnother.map { "\($0.name) (in the \($0.inside))" }.joined(separator: ", ") + ".")
        XCTAssertTrue(d.tagsInsideWords.contains("Pill pouch (in the Toiletry bag)"), d.tagsInsideWords)
    }

    func testABagAddedToTheTripWithNoLineOfItsOwnIsAskedAbout() {
        var (lib, trip) = library()
        // The Duffel, made by "+ Add a bag": empty, no line of its own — it travels by itself.
        XCTAssertNotNil(lib.addNewBagToTrip(tripId: trip, name: "Duffel", cabin: false, maxKg: nil))
        let d = day(lib, trip)
        XCTAssertEqual(d.tagged.map(\.name), [carryOn, "Day pack", "Duffel"])
        XCTAssertEqual(d.words(.tags), "0 of 3 ticked")
    }
}
