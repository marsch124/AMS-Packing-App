import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// Lost luggage, part C (spec 07 part 18 C, his yes of 13 Oct 2026): the Lost bag page — his
/// details for the desk, and everything a baggage desk asks about one bag of a trip.
/// Invented data only — this repository is public.
final class LostBagTests: XCTestCase {
    override func setUp() { PackingEnv.freeze(at: "2026-10-14T12:00:00.000Z") }
    override func tearDown() { PackingEnv.reset() }

    private let carryOn = "Carry-on / hand luggage"

    /// The base template: a Passport and a Charger in the carry-on; Hike: Boots, a Jacket, Socks
    /// (three) and a Map in the Day pack (one of his bags, with an AirTag), a Water bottle in no
    /// bag, a reminder "Charge the watch" in the Day pack. The trip "Sun week" (14–20 Nov 2026)
    /// from Hike, by plane.
    private func library(plane: Bool = true) -> (Library, String) {
        var lib = Library()
        var base = newList(name: "Common base", role: "base")
        base.items = [newItem(name: "Passport"), newItem(name: "Charger")]
        lib.saveTemplate(base)
        var hike = newList(name: "Hike")
        var socks = newItem(name: "Socks", container: "Day pack")
        socks.qty = "3"
        var reminder = newItem(name: "Charge the watch", container: "Day pack")
        reminder.itemType = "reminder"
        hike.items = [newItem(name: "Boots", container: "Day pack"), newItem(name: "Jacket", container: "Day pack"), socks,
                      newItem(name: "Map", container: "Day pack"), newItem(name: "Water bottle", container: ""), reminder]
        lib.saveTemplate(hike)
        let pack = lib.addBag(name: "Day pack")!
        _ = lib.setBagAirTag(id: pack.id, true)
        let hikeId = lib.templates.first { $0.name == "Hike" }!.id
        var event = newEvent(name: "Sun week", activities: [hikeId], startDate: "2026-11-14", endDate: "2026-11-20")
        if plane { event.transport = "Plane" }
        let trip = lib.createTrip(event).id
        return (lib, trip)
    }

    private func line(_ lib: Library, _ name: String) -> String { lib.trips[0].entries.first { $0.name == name }!.id }
    private func row(_ page: LostBagPage, _ key: String) -> LostBagRow {
        (page.you + page.travel + page.bagRows).first { $0.key == key }!
    }

    /// Everything filled in: his details, the flights and stay, the tag, the bag's details, a photo.
    private func filledIn(_ lib: inout Library, _ trip: String) {
        lib.setDeskDetails(DeskDetails(name: "Kim Example", phone: "+46 70 000 00 00", email: "kim@example.com",
                                       address: "Exempelgatan 1\n123 45 Exempelstad"))
        _ = lib.setTravel(TripTravel(flights: [FlightLeg(number: "SK 1234", date: "2026-11-14", from: "ARN", to: "AGP"),
                                               FlightLeg(number: "SK 1235", date: "2026-11-20", from: "AGP", to: "ARN")],
                                     destination: "Málaga",
                                     stay: TripStay(name: "Hotel Exempel", address: "Calle Falsa 1\nMálaga", phone: "+34 900 000 000"),
                                     bagTags: ["Day pack": "SK 123456"]), tripId: trip)
        _ = lib.setBagDetails(BagDetails(brand: "Exempel", colour: "Green", type: .backpack, size: .medium,
                                         sizeNote: "55 × 35 × 25 cm", marks: "red strap"), bag: "Day pack")
        XCTAssertNotNil(lib.addBagPhoto(tripId: trip, bag: "Day pack", jpeg: Data([1, 2, 3])))
    }

    // MARK: - His details for the desk

    func testTheDeskDetailsAreKeptForTheLibraryCleanedSyncedAndBackedUp() {
        var (lib, _) = library()
        XCTAssertEqual(lib.deskDetails(), DeskDetails())
        XCTAssertNil(lib.meta[LOST_DESK_KEY], "nothing said, no key")
        XCTAssertTrue(lib.setDeskDetails(DeskDetails(name: "  Kim   Example ", phone: " +46 70 000 00 00 ", email: " kim@example.com ",
                                                     address: "  Exempelgatan 1 \n\n 123 45  Exempelstad\n")))
        XCTAssertEqual(lib.deskDetails(), DeskDetails(name: "Kim Example", phone: "+46 70 000 00 00", email: "kim@example.com",
                                                      address: "Exempelgatan 1\n123 45 Exempelstad"))
        XCTAssertFalse(lib.setDeskDetails(lib.deskDetails()), "the same again is no change")
        // Only what is said is written.
        lib.setDeskDetails(DeskDetails(phone: "+46 70 000 00 00"))
        XCTAssertEqual(lib.meta[LOST_DESK_KEY]?.objectValue?.keys.sorted(), ["phone"])
        lib.setDeskDetails(DeskDetails(name: "Kim Example", phone: "+46 70 000 00 00", email: "kim@example.com", address: "Exempelgatan 1"))
        let want = lib.deskDetails()
        // The store's records (iCloud carries them), and a backup.
        XCTAssertEqual(Library(records: lib.records()).deskDetails(), want, "the records lost his details")
        let file = lib.backupData(exportedAt: "2026-10-14T12:00:00.000Z")
        let json = try! JSONSerialization.jsonObject(with: file) as! [String: Any]
        XCTAssertNotNil((json["prefs"] as? [String: Any])?[LOST_DESK_KEY], "a backup does not carry his details")
        XCTAssertEqual(try! Importer.read(file).library.deskDetails(), want, "a backup lost his details")
        // A trip shared with someone carries none of it (it is not the trip's).
        let sent = Library.justTheList(lib.trips[0])
        XCTAssertFalse("\(sent.json)".contains("Exempelgatan"), "a shared trip carries his address")
        // Nothing said again: the key goes.
        XCTAssertTrue(lib.setDeskDetails(DeskDetails(name: "  ", address: "\n")))
        XCTAssertNil(lib.meta[LOST_DESK_KEY], "nothing said, no key")
    }

    func testTheDeskNameIsTheOneTypedElseThisIsMe() {
        var (lib, _) = library()
        XCTAssertEqual(lib.deskName(), "", "nobody marked, nothing typed")
        if let n = lib.items.firstIndex(where: { $0.name == "Boots" }) { lib.items[n].ownedBy = "Kim" }
        XCTAssertTrue(lib.setMe("Kim"))
        XCTAssertEqual(lib.deskName(), "Kim", "This is me is the name while none is typed")
        lib.setDeskDetails(DeskDetails(name: "Kim Example"))
        XCTAssertEqual(lib.deskName(), "Kim Example", "the full name typed wins")
    }

    // MARK: - The page

    func testThePageGathersYouTheTripAndTheBag() {
        var (lib, trip) = library()
        filledIn(&lib, trip)
        let page = lib.lostBag(tripId: trip, bag: "Day pack")!
        XCTAssertEqual(page.bag, "Day pack")
        XCTAssertNotNil(page.bagId, "the Day pack is one of his bags")
        XCTAssertEqual(page.tripLine, "Sun week \u{00B7} 14 Nov 2026 \u{2013} 20 Nov 2026")
        XCTAssertTrue(page.planeTrip)
        XCTAssertEqual(page.you.map(\.key), ["you-name", "you-phone", "you-email", "you-address"])
        XCTAssertEqual(row(page, "you-address").lines, ["Exempelgatan 1", "123 45 Exempelstad"])
        XCTAssertEqual(page.travel.map(\.key), ["trip-going", "trip-stay", "trip-until", "trip-flights", "trip-tag"])
        XCTAssertEqual(row(page, "trip-going").words, "Málaga")
        XCTAssertEqual(row(page, "trip-stay").lines, ["Hotel Exempel", "Calle Falsa 1", "Málaga", "+34 900 000 000"])
        XCTAssertEqual(row(page, "trip-until").words, "20 Nov 2026", "a stay without a last day lasts the trip")
        XCTAssertEqual(row(page, "trip-flights").lines, ["SK 1234 \u{00B7} 14 Nov 2026 \u{00B7} ARN \u{2192} AGP",
                                                         "SK 1235 \u{00B7} 20 Nov 2026 \u{00B7} AGP \u{2192} ARN"])
        XCTAssertEqual(row(page, "trip-tag").words, "SK 123456")
        XCTAssertEqual(page.bagRows.map(\.words), ["Backpack", "Exempel", "Green", "Medium, 55 × 35 × 25 cm", "red strap"])
        XCTAssertTrue(page.airTag)
        XCTAssertEqual(page.airTagWords, "Yes")
        XCTAssertEqual(page.photoIds.count, 1)
        XCTAssertEqual(page.groupPhotoId, "")
        XCTAssertEqual(page.missing, 0)
        XCTAssertEqual(page.missingWords, "")
        XCTAssertEqual(page.shortWords, "all filled in")
        // A flight with only a number and a destination; the photo of all the bags shows too.
        _ = lib.setTravel(TripTravel(flights: [FlightLeg(number: "sk 99", to: "AGP")]), tripId: trip)
        XCTAssertEqual(row(lib.lostBag(tripId: trip, bag: "Day pack")!, "trip-flights").lines, ["SK 99 \u{00B7} 14 Nov 2026 \u{00B7} to AGP"])
        let all = lib.setGroupPhoto(tripId: trip, jpeg: Data([7]))!
        XCTAssertEqual(lib.lostBag(tripId: trip, bag: "Day pack")!.groupPhotoId, all.id)
        // How the bag looks (its own photo, from its page) counts as a photo of it too.
        var looks = library().0
        let tripB = looks.trips[0].id
        XCTAssertTrue(looks.lostBag(tripId: tripB, bag: "Day pack")!.noPhoto)
        let pack = looks.bags().first { $0.name == "Day pack" }!.id
        XCTAssertNotNil(looks.addBagOwnPhoto(id: pack, jpeg: Data([5])))
        let page2 = looks.lostBag(tripId: tripB, bag: "Day pack")!
        XCTAssertEqual(page2.lookIds.count, 1)
        XCTAssertFalse(page2.noPhoto, "the photo of how the bag looks is a photo of it")
        XCTAssertTrue(page2.text.contains("Photos: 1 (in the PDF)"))
    }

    func testWhatIsNotKnownSaysNotFilledInAndWhereItIsFilledIn() {
        let (lib, trip) = library()
        let page = lib.lostBag(tripId: trip, bag: "Day pack")!
        // Nothing of his, no flights or stay, no tag, no details, no photo: every row but Until
        // (the trip's last day) — and the AirTag, an answer either way.
        XCTAssertEqual(page.you.filter(\.missing).count, 4)
        XCTAssertEqual(page.travel.filter(\.missing).map(\.key), ["trip-going", "trip-stay", "trip-flights", "trip-tag"])
        XCTAssertEqual(row(page, "trip-until").words, "20 Nov 2026")
        XCTAssertEqual(page.bagRows.filter(\.missing).count, 5)
        XCTAssertEqual(page.missing, 4 + 4 + 5 + 1, "and the bag's own photo")
        XCTAssertEqual(page.missingWords, "14 not filled in \u{2014} tap one to fill it in.")
        XCTAssertEqual(page.shortWords, "14 not filled in")
        XCTAssertEqual(row(page, "you-email").words, LOST_NOT_FILLED)
        // Where each is filled in.
        XCTAssertEqual(Set(page.you.map(\.fill)), [.me])
        XCTAssertEqual(page.travel.map(\.fill), [.trip, .trip, .trip, .trip, .tag])
        XCTAssertEqual(Set(page.bagRows.map(\.fill)), [.bag])
        // One left: "tap it".
        var one = lib
        var full = lib
        filledIn(&full, trip)
        one = full
        one.setDeskDetails(DeskDetails(name: "Kim Example", phone: "+46 70 000 00 00", address: "Exempelgatan 1"))
        XCTAssertEqual(one.lostBag(tripId: trip, bag: "Day pack")!.missingWords, "1 not filled in \u{2014} tap it to fill it in.")
        // The trip's Place is where he is going while part B has none.
        var placed = lib
        placed.trips[0].destination = "Exempelby"
        XCTAssertEqual(row(placed.lostBag(tripId: trip, bag: "Day pack")!, "trip-going").words, "Exempelby")
    }

    func testATripNotByPlaneAsksNoFlightsStayOrTag() {
        let (lib, trip) = library(plane: false)
        let page = lib.lostBag(tripId: trip, bag: "Day pack")!
        XCTAssertFalse(page.planeTrip)
        XCTAssertEqual(page.travel.map(\.key), ["trip-going"], "a car trip asks no flights")
        XCTAssertTrue(page.text.contains(LOST_NOT_PLANE))
        // Typed while it was a plane trip, then switched off: kept, and not shown.
        var was = lib
        _ = was.setTravel(TripTravel(flights: [FlightLeg(number: "SK 1")]), tripId: trip)
        XCTAssertEqual(was.lostBag(tripId: trip, bag: "Day pack")!.travel.map(\.key), ["trip-going"])
    }

    func testAFewThingsInItAreWhatWentInTheFirstEightAndHowManyMore() {
        var (lib, trip) = library()
        // Nothing ticked: everything meant to go in, in the trip's order; reminders and the bottle
        // in no bag left out; Socks with their count.
        var page = lib.lostBag(tripId: trip, bag: "Day pack")!
        XCTAssertEqual(page.inside, ["Boots", "Jacket", "Socks \u{00D7}3", "Map"])
        XCTAssertEqual(page.moreInside, 0)
        // Ticked: only what went in. A line set aside is never in it.
        _ = lib.setChecked(true, tripId: trip, entryId: line(lib, "Boots"))
        _ = lib.setChecked(true, tripId: trip, entryId: line(lib, "Map"))
        _ = lib.setAside(true, tripId: trip, entryId: line(lib, "Map"))
        page = lib.lostBag(tripId: trip, bag: "Day pack")!
        XCTAssertEqual(page.inside, ["Boots"])
        // The bag by another spelling is the same bag.
        XCTAssertEqual(lib.lostBag(tripId: trip, bag: "day PACK")!.inside, ["Boots"])
        // Twelve things: the first eight, and 4 more.
        for k in 1...10 { lib.trips[0].entries.append(newItem(name: "Thing \(k)", container: "Day pack")) }
        _ = lib.setChecked(false, tripId: trip, entryId: line(lib, "Boots"))
        page = lib.lostBag(tripId: trip, bag: "Day pack")!
        XCTAssertEqual(page.inside.count, LOST_INSIDE_SHOWN)
        XCTAssertEqual(page.inside.prefix(3), ["Boots", "Jacket", "Socks \u{00D7}3"])
        XCTAssertEqual(page.moreInside, 13 - LOST_INSIDE_SHOWN)
        XCTAssertTrue(page.text.hasSuffix("and \(13 - LOST_INSIDE_SHOWN) more"))
        // Nothing of the list in the bag.
        XCTAssertEqual(lib.lostBag(tripId: trip, bag: "Empty bag")!.inside, [])
        XCTAssertTrue(lib.lostBag(tripId: trip, bag: "Empty bag")!.text.contains(Library.lostNothingInside))
    }

    func testOnlyABagHasAPage() {
        let (lib, trip) = library()
        XCTAssertNil(lib.lostBag(tripId: trip, bag: "Other"), "Not in a bag is no bag")
        XCTAssertNil(lib.lostBag(tripId: trip, bag: "  "))
        XCTAssertNil(lib.lostBag(tripId: "nope", bag: "Day pack"))
        // A bag that is only a name on the lines has a page, without details or an AirTag.
        let page = lib.lostBag(tripId: trip, bag: carryOn)!
        XCTAssertNil(page.bagId)
        XCTAssertFalse(page.airTag)
        XCTAssertEqual(page.airTagWords, "No")
        XCTAssertEqual(page.inside, ["Passport", "Charger"])
        XCTAssertEqual(page.pdfName, "Lost bag \u{2013} Carry-on - hand luggage.pdf", "a / cannot be in a file name")
    }

    func testTheTextIsWhatADeskReads() {
        var (lib, trip) = library()
        filledIn(&lib, trip)
        lib.setDeskDetails(DeskDetails(name: "Kim Example", phone: "+46 70 000 00 00",
                                       address: "Exempelgatan 1\n123 45 Exempelstad"))
        _ = lib.setChecked(true, tripId: trip, entryId: line(lib, "Boots"))
        _ = lib.setChecked(true, tripId: trip, entryId: line(lib, "Jacket"))
        XCTAssertEqual(lib.lostBag(tripId: trip, bag: "Day pack")!.text, """
        LOST BAG: Day pack
        Trip: Sun week \u{00B7} 14 Nov 2026 \u{2013} 20 Nov 2026

        ABOUT ME
        Name: Kim Example
        Phone: +46 70 000 00 00
        E-mail: not filled in
        Home address: Exempelgatan 1, 123 45 Exempelstad

        THE TRIP
        Going to: Málaga
        Staying at: Hotel Exempel, Calle Falsa 1, Málaga, +34 900 000 000
        Until: 20 Nov 2026
        Flights: SK 1234 \u{00B7} 14 Nov 2026 \u{00B7} ARN \u{2192} AGP; SK 1235 \u{00B7} 20 Nov 2026 \u{00B7} AGP \u{2192} ARN
        Bag-tag number: SK 123456

        THE BAG
        Type: Backpack
        Brand: Exempel
        Colour: Green
        Size: Medium, 55 × 35 × 25 cm
        Distinctive marks: red strap
        AirTag: Yes. In Find My, Share Item Location gives the airline a link to where it is.
        Photos: 1 (in the PDF)

        A FEW THINGS IN IT
        Boots
        Jacket
        """)
    }
}
