import XCTest
@testable import PackingCore
@testable import PackingLibrary

final class TripAgainTests: XCTestCase {
    override func setUp() { PackingEnv.freeze() }
    override func tearDown() { PackingEnv.reset() }

    /// The web app's "Start a new trip from this one": the list as it ended up,
    /// hand-added lines included; nothing ticked, nothing set aside (the spec pass,
    /// 5 Oct 2026), no answers from the old review, no dates, no weather — and the old
    /// trip untouched.
    func testANewTripStartsFromThisOnesList() {
        var lib = Library()
        var old = newEvent(name: "Run and swim", mode: "quick", activities: ["run", "swim"], transport: "RV",
                           season: "Summer", contexts: ["Outdoor"], weatherOn: ["rain"], catering: "self",
                           startDate: "2026-09-26", endDate: "2026-09-27", laundry: true, destination: "Finspång")
        var shoes = newItem(name: "Running shoes"); shoes.checked = true; shoes.used = true
        shoes.extra["packedAt"] = .string("2026-09-25T18:00:00.000Z")
        var cap = newItem(name: "Swim cap"); cap.skipped = true
        var mine = newItem(name: "Tripod"); mine.custom = true; mine.checked = true; mine.used = false
        old.entries = [shoes, cap, mine]
        old.status = "done"; old.reviewedAt = "2026-09-28T08:00:00.000Z"
        lib.trips = [old]

        let copy = lib.startAgain(from: old.id, name: "  Run and swim (again) ")
        XCTAssertNotNil(copy)
        guard let copy else { return }
        XCTAssertEqual(lib.trips.count, 2, "the copy is a trip of its own")
        XCTAssertEqual(copy.name, "Run and swim (again)", "the name is trimmed")
        XCTAssertNotEqual(copy.id, old.id)
        XCTAssertEqual(copy.entries.map(\.name), ["Running shoes", "Swim cap", "Tripod"], "the list as it ended up")
        XCTAssertTrue(Set(copy.entries.map(\.id)).isDisjoint(with: old.entries.map(\.id)), "its lines are its own")
        XCTAssertFalse(copy.entries.contains { $0.checked }, "nothing ticked")
        XCTAssertTrue(copy.entries.allSatisfy { $0.used == nil }, "no answers from the old review")
        XCTAssertNil(copy.entries[0].extra["packedAt"], "no packing time")
        XCTAssertFalse(copy.entries[1].skipped, "\"not this time\" was for the old trip")
        XCTAssertTrue(copy.entries[2].custom, "a hand-added line comes along")
        XCTAssertEqual(copy.mode, "quick"); XCTAssertEqual(copy.activities, ["run", "swim"])
        XCTAssertEqual(copy.transport, "RV"); XCTAssertEqual(copy.contexts, ["Outdoor"])
        XCTAssertEqual(copy.weatherOn, ["rain"]); XCTAssertEqual(copy.catering, "self")
        XCTAssertTrue(copy.laundry); XCTAssertEqual(copy.destination, "Finspång")
        XCTAssertEqual(copy.startDate, "", "no dates: they belonged to the old trip")
        XCTAssertEqual(copy.endDate, "")
        XCTAssertEqual(copy.status, "active", "not reviewed")
        XCTAssertEqual(copy.reviewedAt, "")
        XCTAssertEqual(lib.trips[0].entries.filter(\.checked).count, 2, "the old trip keeps its ticks")
        XCTAssertEqual(lib.trips[0].status, "done")

        XCTAssertNil(lib.startAgain(from: old.id, name: "   "), "no name, no trip")
        XCTAssertNil(lib.startAgain(from: "nope", name: "X"))
        XCTAssertEqual(lib.trips.count, 2)
        XCTAssertEqual(Library.againName("Run and swim"), "Run and swim (again)")
        XCTAssertEqual(Library.againName(""), "Trip (again)")
    }

    /// The spec pass (5 Oct 2026): what happened ON the old trip stays with it. Before,
    /// a copied bought-on-site mark made the new trip stand at On site the moment it
    /// was made, and the way home's ticks, used up and notes came back on it.
    func testANewTripLeavesWhatHappenedOnTheOldOneBehind() {
        var lib = Library()
        var old = newEvent(name: "Away", startDate: "2026-09-26", endDate: "2026-09-28")
        var tent = newItem(name: "Tent"); tent.checked = true
        tent.extra[HOME_KEY] = .bool(true); tent.extra[HOME_NOTE_KEY] = .string("Zip broken")
        var cream = newItem(name: "Sun cream"); cream.checked = true; cream.extra[USED_UP_KEY] = .bool(true)
        var hat = newItem(name: "Sun hat"); hat.custom = true; hat.checked = true; hat.extra[BOUGHT_ON_SITE_KEY] = .bool(true)
        var kite = newItem(name: "Kite"); kite.skipped = true
        var changed = newItem(name: "Map"); changed.edited = true
        old.entries = [tent, cream, hat, kite, changed]
        lib.trips = [old]

        guard let copy = lib.startAgain(from: old.id, name: "Away again") else { return XCTFail("no copy") }
        XCTAssertEqual(copy.entries.map(\.name), ["Tent", "Sun cream", "Sun hat", "Kite", "Map"], "the same list")
        for line in copy.entries {
            XCTAssertFalse(line.checked, "\(line.name) came ticked")
            XCTAssertFalse(line.skipped, "\(line.name) came set aside")
            XCTAssertFalse(Library.isBoughtOnSite(line), "\(line.name) came marked bought on site")
            XCTAssertFalse(Library.isPackedHome(line), "\(line.name) came ticked for the way home")
            XCTAssertFalse(Library.isUsedUp(line), "\(line.name) came used up")
            XCTAssertEqual(Library.homeNote(line), "", "\(line.name) came with the old trip's note")
        }
        XCTAssertTrue(copy.entries[2].custom, "a line typed by hand is still one (a rebuild keeps it)")
        XCTAssertTrue(copy.entries[4].edited, "a line changed on the trip is still changed")
        XCTAssertEqual(lib.loopStep(tripId: copy.id, today: "2026-10-05"), .pack, "the new trip jumped to On site")
        XCTAssertFalse(lib.onSiteBegun(tripId: copy.id, today: "2026-10-05"), "the new trip shows the On site door")
        XCTAssertTrue(Library.isBoughtOnSite(lib.trips[0].entries[2]), "the old trip lost its own marks")
    }
}
