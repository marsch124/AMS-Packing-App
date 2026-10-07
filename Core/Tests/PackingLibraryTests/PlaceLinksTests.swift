import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// "Tap the garage, see the garage" (0.69, stop A of his idea plan): a place's printed
/// code carries its short code in a link, and what it opens depends on the day.
final class PlaceLinksTests: XCTestCase {
    override func setUp() { PackingEnv.freeze(at: "2026-10-01T12:00:00.000Z") }
    override func tearDown() { PackingEnv.reset() }

    /// Four things on the base template: two in the Garage, one in the Hall closet, one
    /// nowhere — and a trip from `start` to `end`, built from it.
    private func library(start: String = "", end: String = "") -> (Library, String) {
        var lib = Library()
        lib.saveTemplate(newList(name: "Base", role: "base"))
        let base = lib.templates.first { $0.role == "base" }!.id
        for (name, place) in [("Pump", "Garage"), ("Helmet", "garage "), ("Boots", "Hall closet"), ("Sun hat", "")] {
            let t = lib.addThing(name: name)!
            let n = lib.items.firstIndex { $0.id == t.id }!
            lib.items[n].storage = place
            _ = lib.setOnTemplate(itemId: t.id, templateId: base, on: true)
        }
        let trip = lib.createTrip(newEvent(name: "Away", startDate: start, endDate: end)).id
        return (lib, trip)
    }

    func testALinkCarriesThePlacesCodeInCapitals() {
        XCTAssertEqual(PlaceLink.text(code: "g4r"), "AMSPACKING://P/G4R", "capitals: the code's compact mode")
        let url = PlaceLink.url(code: "G4R")!
        XCTAssertEqual(PlaceLink.code(in: url), "G4R")
        XCTAssertEqual(PlaceLink.code(in: URL(string: "amspacking://p/g4r")!), "G4R", "any case")
        XCTAssertNil(PlaceLink.code(in: URL(string: "https://p/G4R")!), "another scheme is not a place's code")
        XCTAssertNil(PlaceLink.code(in: URL(string: "AMSPACKING://T/G4R")!), "another kind of link is not a place")
        XCTAssertNil(PlaceLink.code(in: URL(string: "AMSPACKING://P/")!))
        XCTAssertNil(PlaceLink.code(in: URL(string: "AMSPACKING://P/G4R/X")!))
        XCTAssertNil(PlaceLink.code(in: URL(string: "AMSPACKING://P/TOOLONG")!), "two to four characters")
        XCTAssertLessThanOrEqual(PlaceLink.text(code: "ZZZZ").count, 20, "a four-character code no longer fits the smallest square code")
    }

    func testEachPlaceGetsAShortCodeThatIsKeptAndTheSameEverywhere() {
        var (lib, _) = library()
        let would = lib.placeCode(for: "Garage")!
        XCTAssertTrue(Library.isPlaceCode(would), would)
        XCTAssertEqual(would.count, 3)
        XCTAssertEqual(lib.place(forCode: would), nil, "not given yet")
        XCTAssertEqual(lib.givePlaceCode("garage"), would, "given as it was shown")
        XCTAssertEqual(lib.place(forCode: would), "Garage", "the list's spelling")
        XCTAssertEqual(lib.place(forCode: would.lowercased()), "Garage")
        XCTAssertEqual(lib.givePlaceCode("Garage"), would, "a second code for one place")
        XCTAssertEqual(lib.placeCodes().count, 1)
        // Kept with the library, and the other device would give the same.
        let back = Library(records: lib.records())
        XCTAssertEqual(back.place(forCode: would), "Garage", "the code was not stored")
        let (other, _) = library()
        XCTAssertEqual(other.placeCode(for: "GARAGE"), would, "another device would give the Garage another code")
        // Each place its own.
        let hall = lib.givePlaceCode("Hall closet")!
        XCTAssertNotEqual(hall, would)
        XCTAssertNil(lib.place(forCode: "ZZ9"), "a code never given")
    }

    func testACodeIsNeverGivenToAnotherPlace() {
        var (lib, _) = library()
        // The code a place would get is already another's (a place removed long ago).
        let wanted = lib.placeCode(for: "Basement / cellar")!
        lib.meta[Library.placeCodeKey(wanted)] = .string("Somewhere gone")
        let got = lib.placeCode(for: "Basement / cellar")!
        XCTAssertNotEqual(got, wanted, "a code given to another place was given again")
        XCTAssertEqual(lib.givePlaceCode("Basement / cellar"), got)
        XCTAssertNil(lib.place(forCode: wanted), "the gone place's code opens something")
        // A removed place keeps its code, so nothing else can be given it.
        let utility = lib.givePlaceCode("Utility room")!
        _ = lib.setNames("places", lib.storagePlaces().filter { $0 != "Utility room" })
        XCTAssertNil(lib.place(forCode: utility), "a removed place's code still opens it")
        XCTAssertTrue(lib.placeCodes().keys.contains(utility), "a removed place's code was dropped: it could be given again")
    }

    func testACodeSurvivesABackupAndRestore() throws {
        var (lib, _) = library()
        let code = lib.givePlaceCode("Garage")!
        let restored = try Importer.read(lib.backupData()).library
        XCTAssertEqual(restored.place(forCode: code), "Garage", "a label printed before the restore lost its place")
        XCTAssertEqual(restored.placeCodes(), lib.placeCodes())
    }

    func testALabelPrintedBeforeARenameStillFindsThePlace() {
        var (lib, _) = library()
        let code = lib.givePlaceCode("Garage")!
        XCTAssertNil(lib.renameChoice("places", key: "Garage", to: "Workshop"))
        XCTAssertEqual(lib.place(forCode: code), "Workshop", "the old label lost its place")
        XCTAssertEqual(lib.placeCode(for: "Workshop"), code, "the renamed place got a new code")
        XCTAssertNil(lib.renameChoice("places", key: "Workshop", to: "Shed"))
        XCTAssertEqual(lib.place(forCode: code), "Shed", "two renames: the label lost its place")
        // The things followed every rename.
        XCTAssertEqual(lib.thingsKept(at: "Shed").map(\.name), ["Helmet", "Pump"])
    }

    func testAPlaceIsFoundAsTheListSpellsItOrAsThingsSayIt() {
        var (lib, _) = library()
        XCTAssertEqual(lib.placeNamed("garage"), "Garage", "the list's spelling")
        XCTAssertEqual(lib.placeNamed("  HALL closet "), "Hall closet")
        XCTAssertNil(lib.placeNamed("Boat house"), "a name nothing knows")
        XCTAssertNil(lib.placeNamed(""))
        let n = lib.items.firstIndex { $0.name == "Sun hat" }!
        lib.items[n].storage = "Boat house"
        XCTAssertEqual(lib.placeNamed("boat HOUSE"), "Boat house", "on things but not on the list")
    }

    func testThePackingWindowIsTheEarliestPackingStep() {
        let (lib, _) = library()
        XCTAssertEqual(lib.packingWindowDays(), 7, "≥1 week ahead; Preparations (30, a step to DO) does not count")
        var mine = DEFAULT_PHASES
        mine[1].leadDays = 10
        var other = lib
        _ = other.setTimeline(mine)
        defer { _ = setPhases(DEFAULT_PHASES) }
        XCTAssertEqual(other.packingWindowDays(), 10)
    }

    func testATripBeingPackedOpensOnItsPlace() {
        // Today is 1 Oct; the trip starts in 5 days — inside the week.
        let (lib, trip) = library(start: "2026-10-06", end: "2026-10-08")
        XCTAssertEqual(lib.placeVisit(today: "2026-10-01"), .packing(tripId: trip))
        XCTAssertEqual(lib.tripLines(tripId: trip, at: "Garage").map(\.name), ["Pump", "Helmet"],
                       "the trip's lines from the Garage, in the trip's order, however the place is spelt")
        // On the day it starts he is still packing.
        XCTAssertEqual(lib.placeVisit(today: "2026-10-06"), .packing(tripId: trip))
        // Eight days ahead is outside the week: everything kept there.
        XCTAssertEqual(lib.placeVisit(today: "2026-09-28"), .keptThere)
    }

    func testTheSoonestTripIsTheOneBeingPacked() {
        var (lib, later) = library(start: "2026-10-06", end: "2026-10-08")
        let sooner = lib.createTrip(newEvent(name: "Sooner", startDate: "2026-10-03", endDate: "2026-10-04")).id
        XCTAssertEqual(lib.placeVisit(today: "2026-10-01"), .packing(tripId: sooner))
        XCTAssertNotEqual(sooner, later)
        // Reviewed: no longer counts.
        let n = lib.trips.firstIndex { $0.id == sooner }!
        lib.trips[n].status = "done"
        XCTAssertEqual(lib.placeVisit(today: "2026-10-01"), .packing(tripId: later))
    }

    func testBackFromATripShowsWhatGoesBackThere() {
        var (lib, trip) = library(start: "2026-09-26", end: "2026-09-30")
        // Nothing ticked on the way out: nothing came along, so nothing goes back.
        XCTAssertEqual(lib.placeVisit(today: "2026-10-01"), .keptThere)
        for line in lib.trips[0].entries { _ = lib.setChecked(true, tripId: trip, entryId: line.id) }
        XCTAssertEqual(lib.placeVisit(today: "2026-10-01"), .goingBack(tripId: trip), "the day after the trip")
        XCTAssertEqual(lib.placeVisit(today: "2026-09-28"), .goingBack(tripId: trip), "during the trip")
        XCTAssertEqual(lib.placeVisit(today: "2026-10-02"), .keptThere, "two days after: no longer")
        XCTAssertEqual(lib.goingBack(tripId: trip, to: "Garage").map(\.name), ["Pump", "Helmet"])
        // Used up on site: it does not go back.
        let pump = lib.trips[0].entries.first { $0.name == "Pump" }!.id
        _ = lib.setUsedUp(true, tripId: trip, entryId: pump)
        XCTAssertEqual(lib.goingBack(tripId: trip, to: "garage").map(\.name), ["Helmet"])
    }

    func testComingHomeComesBeforeTheNextTripsPacking() {
        var (lib, back) = library(start: "2026-09-26", end: "2026-09-30")
        for line in lib.trips[0].entries { _ = lib.setChecked(true, tripId: back, entryId: line.id) }
        let next = lib.createTrip(newEvent(name: "Next", startDate: "2026-10-04", endDate: "2026-10-05")).id
        XCTAssertEqual(lib.placeVisit(today: "2026-10-01"), .goingBack(tripId: back), "unpacking first")
        XCTAssertEqual(lib.placeVisit(today: "2026-10-02"), .packing(tripId: next), "then packing for the next")
    }

    func testATripWithoutDatesNeverOpens() {
        let (lib, _) = library()
        XCTAssertEqual(lib.placeVisit(today: "2026-10-01"), .keptThere)
    }

    func testEverythingKeptThereIsAToZ() {
        let (lib, _) = library()
        XCTAssertEqual(lib.thingsKept(at: "GARAGE").map(\.name), ["Helmet", "Pump"])
        XCTAssertEqual(lib.thingsKept(at: "Hall closet").map(\.name), ["Boots"])
        XCTAssertEqual(lib.thingsKept(at: "").map(\.name), [], "a blank place holds nothing")
    }
}
