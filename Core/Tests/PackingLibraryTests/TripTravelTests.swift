import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// Flights and stay (0.80, the lost-luggage information part B, his yes of 13 Oct 2026): on a
/// plane trip, the flights, the destination, where he stays and until when — and per bag the
/// number on its bag tag. Invented flights, hotels and numbers only: this repository is public.
final class TripTravelTests: XCTestCase {
    override func setUp() { PackingEnv.freeze(at: "2026-10-13T12:00:00.000Z") }
    override func tearDown() { PackingEnv.reset() }

    /// The trip "Sun week" (14–20 Oct 2026) by Plane, place "Seaside"; a Passport in the Big case
    /// (one of his bags) and a Charger in the Day pack.
    private func library() -> (Library, String) {
        var lib = Library()
        var base = newList(name: "Base", role: "base")
        base.items = [newItem(name: "Passport", container: "Big case"), newItem(name: "Charger", container: "Day pack")]
        lib.saveTemplate(base)
        XCTAssertNotNil(lib.addBag(name: "Big case"))
        XCTAssertNotNil(lib.addBag(name: "Day pack"))
        let trip = lib.createTrip(newEvent(name: "Sun week", transport: "Plane", startDate: "2026-10-14",
                                           endDate: "2026-10-20", destination: "Seaside")).id
        return (lib, trip)
    }

    private var invented: TripTravel {
        TripTravel(flights: [FlightLeg(number: "zz 101", date: "2026-10-14", from: "North Field", to: "Sunport"),
                             FlightLeg(number: "ZZ 102", from: "Sunport", to: "North Field")],
                   destination: "Sun Town",
                   stay: TripStay(name: "Hotel Invented", address: "1 Made-up Street\n\n  Sun Town ", phone: "+00 123 456"))
    }

    func testFlightsAndStayAreKeptCleanedOnTheTrip() {
        var (lib, trip) = library()
        XCTAssertTrue(lib.travel(tripId: trip)!.isEmpty, "a new trip had travel")
        XCTAssertNil(lib.trips[0].extra[TRIP_TRAVEL_KEY], "a trip without flights wrote a key")
        XCTAssertTrue(lib.setTravel(invented, tripId: trip))
        let t = lib.travel(tripId: trip)!
        XCTAssertEqual(t.flights.map(\.number), ["ZZ 101", "ZZ 102"], "flight numbers not in capitals")
        XCTAssertEqual(t.flights.map(\.date), ["2026-10-14", "2026-10-20"], "the way home without a day did not get the last day")
        XCTAssertEqual(t.flights.map(\.to), ["Sunport", "North Field"])
        XCTAssertEqual(t.destination, "Sun Town")
        XCTAssertEqual(t.stay, TripStay(name: "Hotel Invented", address: "1 Made-up Street\nSun Town", phone: "+00 123 456",
                                        until: "2026-10-20"), "the stay was not kept, or not until the last day")
        XCTAssertFalse(lib.setTravel(invented, tripId: "nope"))
        // Kept in the stored records (synced) and in a backup.
        XCTAssertEqual(Library.travel(Library(records: lib.records()).trips[0]), t)
        let restored = try! Importer.read(lib.backupData(exportedAt: "2026-10-13T12:00:00.000Z")).library
        XCTAssertEqual(Library.travel(restored.trips[0]), t, "a backup lost the flights and stay")
        // Everything taken away: no key left.
        XCTAssertTrue(lib.setTravel(TripTravel(flights: [FlightLeg(), FlightLeg()]), tripId: trip))
        XCTAssertNil(lib.trips[0].extra[TRIP_TRAVEL_KEY], "an empty block left a key")
    }

    func testLegsNothingWasTypedInGoAndTheBlockShowsOutAndHome() {
        XCTAssertEqual(TripTravel().legsForEditing.count, 2, "the block did not offer out and home")
        let three = TripTravel(flights: [FlightLeg(number: "A1"), FlightLeg(), FlightLeg(number: "B2"), FlightLeg(number: "C3")])
        XCTAssertEqual(three.legsForEditing.count, 4)
        let kept = Library.cleaned(three, firstDay: "2026-10-14", lastDay: "2026-10-20")
        XCTAssertEqual(kept.flights.map(\.number), ["A1", "B2", "C3"], "an empty leg was kept")
        XCTAssertEqual(kept.flights.map(\.date), ["2026-10-14", "2026-10-14", "2026-10-20"], "a change of plane is on the first day")
        // Out left empty: Home is still the way home, on the last day.
        let home = Library.cleaned(TripTravel(flights: [FlightLeg(), FlightLeg(number: "B2")]), firstDay: "2026-10-14", lastDay: "2026-10-20")
        XCTAssertEqual(home.flights.map(\.date), ["2026-10-20"], "Home alone was put on the first day")
        // A trip without dates: no day made up.
        XCTAssertEqual(Library.cleaned(three).flights.map(\.date), ["", "", ""])
        // A day typed is his, whatever the trip's.
        let own = Library.cleaned(TripTravel(flights: [FlightLeg(number: "A1", date: "2026-10-15")]), firstDay: "2026-10-14")
        XCTAssertEqual(own.flights.first?.date, "2026-10-15")
        // A stay with only a day is no stay.
        XCTAssertTrue(Library.cleaned(TripTravel(stay: TripStay(until: "2026-10-20"))).isEmpty)
    }

    func testTheDestinationFallsBackToTheTripsPlace() {
        var (lib, trip) = library()
        XCTAssertEqual(Library.travelDestination(lib.trips[0]), "Seaside")
        _ = lib.setTravel(invented, tripId: trip)
        XCTAssertEqual(Library.travelDestination(lib.trips[0]), "Sun Town")
    }

    func testOnlyAPlaneTripShowsItAndPlaneOffKeepsIt() {
        var (lib, trip) = library()
        _ = lib.setTravel(invented, tripId: trip)
        XCTAssertNotNil(Library.planeTravel(lib.trips[0]))
        _ = lib.changeTrip(id: trip) { $0.transport = "Car" }
        XCTAssertNil(Library.planeTravel(lib.trips[0]), "a trip by car showed flights")
        _ = lib.changeTrip(id: trip) { $0.transport = "Plane" }
        XCTAssertEqual(Library.planeTravel(lib.trips[0])?.flights.count, 2, "Plane off and on again lost the flights")
    }

    func testCreateAndTripSettingsLeaveTheBagTagsAlone() {
        var (lib, trip) = library()
        XCTAssertTrue(lib.setBagTag("ab 123456", tripId: trip, bag: "Big case"))
        Library.setFlightsAndStay(&lib.trips[0], invented)
        XCTAssertEqual(Library.bagTag(lib.trips[0], bag: "big case"), "AB 123456", "saving the block lost a bag tag")
        XCTAssertEqual(Library.travel(lib.trips[0]).flights.count, 2)
    }

    func testABagTagIsKeptPerBagAndTakenAwayWithNothing() {
        var (lib, trip) = library()
        XCTAssertTrue(lib.setBagTag(" ab  123456 ", tripId: trip, bag: "Big case"))
        XCTAssertTrue(lib.setBagTag("CD 9", tripId: trip, bag: "Day pack"))
        XCTAssertEqual(Library.bagTag(lib.trips[0], bag: "Big case"), "AB 123456")
        // One per bag, by name as normName sees it.
        XCTAssertTrue(lib.setBagTag("EF 7", tripId: trip, bag: "BIG CASE"))
        XCTAssertEqual(lib.travel(tripId: trip)!.bagTags, ["BIG CASE": "EF 7", "Day pack": "CD 9"])
        XCTAssertFalse(lib.setBagTag("X1", tripId: trip, bag: "Other"), "loose things took a bag tag")
        XCTAssertFalse(lib.setBagTag("X1", tripId: trip, bag: " "))
        XCTAssertTrue(lib.setBagTag("", tripId: trip, bag: "big case"))
        XCTAssertTrue(lib.setBagTag("", tripId: trip, bag: "Day pack"))
        XCTAssertNil(lib.trips[0].extra[BAG_TAGS_KEY], "the last tag taken away left a key")
    }

    func testOnlyACheckedBagOnAPlaneTripIsAskedForItsTag() {
        var (lib, trip) = library()
        XCTAssertTrue(lib.asksBagTag(tripId: trip, bag: "Big case"))
        XCTAssertTrue(lib.asksBagTag(tripId: trip, bag: "a name on the lines only"), "a bag that is only a name was not asked")
        XCTAssertFalse(lib.asksBagTag(tripId: trip, bag: "Other"), "loose things were asked for a tag")
        XCTAssertFalse(lib.asksBagTag(tripId: trip, bag: "Carry-on / hand luggage"), "a cabin bag (by its name) was asked for a tag")
        let pack = lib.bags().first { $0.name == "Day pack" }!.id
        XCTAssertTrue(lib.setBagCabin(id: pack, true))
        XCTAssertFalse(lib.asksBagTag(tripId: trip, bag: "Day pack"), "a bag he says goes in the cabin was asked for a tag")
        XCTAssertFalse(lib.asksBagTag(tripId: "nope", bag: "Big case"))
        _ = lib.changeTrip(id: trip) { $0.transport = "RV" }
        XCTAssertFalse(lib.asksBagTag(tripId: trip, bag: "Big case"), "a trip not by plane was asked for a tag")
    }

    func testABagRenamedTakesItsTagAlongTwoMadeOneKeepTheirOwn() {
        var (lib, trip) = library()
        _ = lib.setBagTag("AB 1", tripId: trip, bag: "Big case")
        _ = lib.setBagTag("CD 2", tripId: trip, bag: "Day pack")
        let big = lib.bags().first { $0.name == "Big case" }!.id
        XCTAssertTrue(lib.renameThing(id: big, to: "Blue case"))
        XCTAssertEqual(Library.bagTag(lib.trips[0], bag: "Blue case"), "AB 1", "a renamed bag lost its tag")
        XCTAssertEqual(Library.bagTag(lib.trips[0], bag: "Big case"), "")
        // The Blue case deleted, its things into the Day pack: the Day pack keeps its own tag.
        let blue = lib.bags().first { $0.name == "Blue case" }!.id
        XCTAssertTrue(lib.deleteBag(id: blue, moveTo: "Day pack"))
        XCTAssertEqual(lib.travel(tripId: trip)!.bagTags, ["Day pack": "CD 2"], "two bags made one took the other's tag")
        // Deleted with no bag: its tag goes.
        let pack = lib.bags().first { $0.name == "Day pack" }!.id
        XCTAssertTrue(lib.deleteBag(id: pack, moveTo: ""))
        XCTAssertNil(lib.trips[0].extra[BAG_TAGS_KEY], "loose things kept a bag's tag")
    }

    func testAStartAgainTakesNoneOfItASharedTripKeepsFlightsButNotTags() {
        var (lib, trip) = library()
        _ = lib.setTravel(invented, tripId: trip)
        _ = lib.setBagTag("AB 1", tripId: trip, bag: "Big case")
        // Start a new trip from this one: other flights, another stay, new tags.
        let again = lib.startAgain(from: trip, name: "Sun week (again)")!
        XCTAssertTrue(Library.travel(again).isEmpty, "a new trip from this one kept its flights, stay or tags")
        // Shared: they travel together — same flights, same stay — but the tags are on HIS bags.
        let link = lib.shareLink(tripId: trip)!
        guard case .trip(let got)? = Library.readShared(link) else { return XCTFail("the link did not open") }
        var other = Library()
        let theirs = other.importTrip(got)
        XCTAssertEqual(Library.travel(theirs).flights.map(\.number), ["ZZ 101", "ZZ 102"], "a shared trip lost its flights")
        XCTAssertEqual(Library.travel(theirs).stay.name, "Hotel Invented")
        XCTAssertTrue(Library.travel(theirs).bagTags.isEmpty, "his bag tags went with a shared trip")
    }
}
