import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// A trip grouped by Whose it is (0.103, his idea of 27 Oct 2026: "pack everything that we share
/// on my own, so that when she comes home I have already packed a lot"): the lines under the
/// owner of the THING behind each one — the owners' order of Your choices, the owners no list
/// knows after them, "Both have one" (no owner) last. Invented names only.
final class TripByWhoseTests: XCTestCase {
    override func setUp() { PackingEnv.reset(); _ = setPhases(DEFAULT_PHASES) }
    override func tearDown() { PackingEnv.reset(); _ = setPhases(DEFAULT_PHASES) }

    /// Seven things on one template, in this order: Passport (Ben), Phone charger (Anna),
    /// Toothbrush (no one: both have one), Sun hat (Zed — on no list), Rain jacket (Cleo — on no
    /// list), Map (Anna), Tent (no one). Your choices holds Ben and Anna (kept A–Z: Anna, Ben).
    private func library(owners list: [String]? = ["Ben", "Anna"]) -> (Library, String) {
        var lib = Library()
        var l = newList(name: "Weekend", group: "GA", role: "")
        l.items = ["Passport", "Phone charger", "Toothbrush", "Sun hat", "Rain jacket", "Map", "Tent"].map { newItem(name: $0) }
        lib.saveTemplate(l)
        let owned = ["Passport": "Ben", "Phone charger": "Anna", "Sun hat": "Zed", "Rain jacket": "Cleo", "Map": "Anna"]
        for n in lib.items.indices { lib.items[n].ownedBy = owned[lib.items[n].name] ?? "" }
        if let list { lib.setNames("owners", list) }
        var trip = newEvent(name: "Test week")
        trip.activities = lib.templates.map(\.id)
        trip = lib.createTrip(trip)
        return (lib, trip.id)
    }

    private func headings(_ groups: [EntryGroup]) -> [String] { groups.map(\.label) }
    private func names(_ group: EntryGroup) -> [String] { group.entries.map(\.name) }
    private func whose(_ lib: Library, _ id: String) -> [EntryGroup] {
        lib.linesGrouped(tripId: id, sorting: "whose", lines: lib.trips.first { $0.id == id }!.entries)
    }

    func testTheHeadingsFollowYourChoicesThenStraysThenBothHaveOne() {
        let (lib, id) = library()
        XCTAssertEqual(lib.trips[0].entries.count, 7, "the trip has not all seven lines")
        let groups = whose(lib, id)
        // The list's own order (Anna, Ben — not Ben first, as his line comes first on the trip),
        // then the names no list holds A–Z (Cleo, Zed), then "Both have one" last.
        XCTAssertEqual(headings(groups), ["Anna", "Ben", "Cleo", "Zed", OWNER_BOTH], "not the owners' order")
        XCTAssertEqual(names(groups[0]), ["Phone charger", "Map"], "Anna's lines, in the trip's order")
        XCTAssertEqual(names(groups[1]), ["Passport"])
        XCTAssertEqual(names(groups[2]), ["Rain jacket"])
        XCTAssertEqual(names(groups[3]), ["Sun hat"])
        XCTAssertEqual(names(groups[4]), ["Toothbrush", "Tent"], "what no one owns is not under Both have one")
        XCTAssertEqual(OWNER_BOTH, "Both have one")
        XCTAssertEqual(groups.flatMap(\.entries).count, 7, "a line is under no heading, or two")
    }

    func testAThingWhoseOwnerIsNoLongerOnTheListStillHasItsHeading() {
        var (lib, id) = library()
        // Ben leaves Your choices; the Passport still says Ben.
        lib.setNames("owners", ["Anna"])
        XCTAssertEqual(headings(whose(lib, id)), ["Anna", "Ben", "Cleo", "Zed", OWNER_BOTH],
                       "an owner no longer on the list lost his lines' heading")
        XCTAssertEqual(names(whose(lib, id)[1]), ["Passport"])
    }

    func testTheOwnerIsReadFromTheThingNowNotFromTheLine() {
        var (lib, id) = library()
        // The line carries no owner (spec 03: "Not carried: … owner") — so a change on the thing
        // reaches an open trip at once, with no rebuild.
        XCTAssertEqual(lib.trips[0].entries.map(\.ownedBy).filter { !$0.isEmpty }, [], "a line carries an owner")
        let tent = lib.items.firstIndex { $0.name == "Tent" }!
        lib.items[tent].ownedBy = "Ben"
        let groups = whose(lib, id)
        XCTAssertEqual(names(groups[1]), ["Passport", "Tent"], "the Tent did not move to Ben")
        XCTAssertEqual(names(groups.last!), ["Toothbrush"])
    }

    func testALineTypedOnTheTripHasNoOwner() {
        var (lib, id) = library()
        _ = lib.addCustomLine(tripId: id, name: "Tripod")
        let groups = whose(lib, id)
        XCTAssertEqual(groups.last?.label, OWNER_BOTH)
        XCTAssertEqual(groups.last.map(names), ["Toothbrush", "Tent", "Tripod"], "a typed line is not under Both have one")
    }

    func testSpellingAndSpacesDoNotSplitAHeading() {
        var (lib, id) = library()
        let map = lib.items.firstIndex { $0.name == "Map" }!
        lib.items[map].ownedBy = "  anna "
        let groups = whose(lib, id)
        XCTAssertEqual(headings(groups).first, "Anna", "the list's spelling is the heading's")
        XCTAssertEqual(names(groups[0]), ["Phone charger", "Map"], "'  anna ' is not Anna")
        // An owner typed as the words for no owner is no owner.
        let tent = lib.items.firstIndex { $0.name == "Tent" }!
        lib.items[tent].ownedBy = "both have one"
        XCTAssertEqual(names(whose(lib, id).last!), ["Toothbrush", "Tent"])
        XCTAssertEqual(whose(lib, id).filter { $0.label.lowercased() == "both have one" }.count, 1, "two Both have one headings")
    }

    func testWithNoListOfYourOwnTheThingsOwnersAreOfferedAToZ() {
        let (lib, id) = library(owners: nil)
        XCTAssertEqual(headings(whose(lib, id)), ["Anna", "Ben", "Cleo", "Zed", OWNER_BOTH])
    }

    func testATripNobodyOwnsHasOneHeadingAndAnEmptyTripNone() {
        var (lib, id) = library()
        for n in lib.items.indices { lib.items[n].ownedBy = "" }
        let groups = whose(lib, id)
        XCTAssertEqual(headings(groups), [OWNER_BOTH])
        XCTAssertEqual(groups[0].entries.count, 7)
        XCTAssertEqual(lib.linesGrouped(tripId: id, sorting: "whose", lines: []).count, 0, "a heading with no lines")
    }

    func testTheLinesGivenAreTheLinesGroupedAsUnderEveryGrouping() {
        // The place filter and "only what is still unticked" hand over fewer lines: only those.
        var (lib, id) = library()
        _ = lib.setChecked(true, tripId: id, entryIds: lib.trips[0].entries.filter { $0.name == "Passport" || $0.name == "Map" }.map(\.id))
        let open = lib.trips[0].entries.filter { !$0.checked }
        let groups = lib.linesGrouped(tripId: id, sorting: "whose", lines: open)
        XCTAssertEqual(headings(groups), ["Anna", "Cleo", "Zed", OWNER_BOTH], "Ben has nothing left but is shown")
        XCTAssertEqual(names(groups[0]), ["Phone charger"])
    }

    func testTakeABreakReadsTheSameHeadings() {
        var (lib, id) = library()
        let mine = lib.trips[0].entries.filter { $0.name == "Phone charger" || $0.name == "Map" }.map(\.id)
        _ = lib.setChecked(true, tripId: id, entryIds: mine)
        let o = lib.breakOverview(tripId: id, sorting: "whose", today: "2026-10-27")!
        XCTAssertEqual(o.groupWords, "Anna \u{2713} \u{00B7} Ben 1 left \u{00B7} Cleo 1 left \u{00B7} Zed 1 left \u{00B7} Both have one 2 left")
    }
}
