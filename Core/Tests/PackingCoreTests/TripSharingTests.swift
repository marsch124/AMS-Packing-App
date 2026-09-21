import XCTest
@testable import PackingCore

// Ported from tests/model.test.mjs — "Trip sharing (manual, backend-free)", the v186
// address tests, and the two trip-link tests of "Squeezing a share code".
//
// The JS `sampleTripEvent()` builds its entries with `seedLists()` + `buildTotalEntries()`,
// which belong to other slices. Here the trip gets invented entries of the same kind
// (materialised lines with a source link); nothing these tests assert depends on which.
final class TripSharingTests: XCTestCase {
    override func tearDown() { PackingEnv.reset(); super.tearDown() }

    private func sampleEntries(_ n: Int = 24) -> [Item] {
        (0..<n).map { i in
            newItem(name: "Thing \(i)", category: i % 2 == 0 ? "Clothing" : "Tech", weight: Double(100 + i),
                    sourceListId: "list-1", sourceItemId: "item-\(i)")
        }
    }
    private func sampleTripEvent() -> TripEvent {
        var ev = newEvent(name: "Vasa Diveweekend", activities: ["list-1"], transport: "Plane", season: "Summer", nights: 3)
        ev.entries = sampleEntries()
        // Simulate real trip state that must NOT leak to the receiver.
        ev.entries[0].checked = true
        ev.entries[0].used = false
        ev.status = "done"
        ev.reviewedAt = "2026-07-01T00:00:00.000Z"
        return ev
    }

    // JS: 'buildTripBundle: self-contained, event-only envelope'
    func testBuildTripBundleSelfContainedEventOnlyEnvelope() {
        let ev = sampleTripEvent()
        let b = buildTripBundle(ev)
        XCTAssertEqual(b.app, "ams-packing-list")
        XCTAssertEqual(b.kind, "trip")
        XCTAssertEqual(b.version, 1)
        XCTAssertFalse(b.exportedAt.isEmpty)
        XCTAssertEqual(b.event["name"]?.stringValue, "Vasa Diveweekend")
        XCTAssertGreaterThan(b.event["entries"]?.arrayValue?.count ?? 0, 0)
    }

    // JS: 'parseTripBundle: round-trips entries but resets id, status and packed state'
    func testParseTripBundleRoundTripsEntriesButResetsIdStatusAndPackedState() throws {
        let ev = sampleTripEvent()
        let json = buildTripBundle(ev).text()
        let got = try parseTripBundle(json)
        XCTAssertEqual(got.name, ev.name)
        XCTAssertEqual(got.entries.count, ev.entries.count)
        XCTAssertNotEqual(got.id, ev.id, "fresh id so import never clobbers an existing event")
        XCTAssertEqual(got.status, "active")
        XCTAssertEqual(got.reviewedAt, "")
        XCTAssertTrue(got.entries.allSatisfy { $0.checked == false }, "receiver starts unpacked")
    }

    // JS: 'parseTripBundle: accepts a parsed object as well as a JSON string'
    func testParseTripBundleAcceptsAParsedObjectAsWellAsAJSONString() throws {
        let ev = sampleTripEvent()
        XCTAssertEqual(try parseTripBundle(buildTripBundle(ev)).name, ev.name)
        XCTAssertEqual(try parseTripBundle(json: buildTripBundle(ev).json).name, ev.name)
    }

    // JS: 'parseTripBundle: rejects non-trip payloads'
    func testParseTripBundleRejectsNonTripPayloads() {
        XCTAssertThrowsError(try parseTripBundle("{\"app\":\"ams-packing-list\",\"kind\":\"backup\"}"))
        XCTAssertThrowsError(try parseTripBundle("not json at all"))
        XCTAssertThrowsError(try parseTripBundle("{\"kind\":\"trip\"}"))
    }

    // A synced trip is a synced ROW, and the sync addon writes the signed-in
    // account's address into `owner` and `realmId` on it. Until v186 the bundle was
    // the whole row, so every shared trip — link, QR or file — carried the address.
    // (Here only a value built in memory can hold those two keys, in `extra`.)
    private func syncStampedTrip() -> TripEvent {
        var ev = sampleTripEvent()
        ev.extra["owner"] = "someone@example.com"
        ev.extra["realmId"] = "someone@example.com"
        ev.entries[0].extra["owner"] = "someone@example.com"
        ev.entries[0].extra["realmId"] = "someone@example.com"
        ev.entries[1].ownedBy = "Anna"
        ev.entries[2].ownedBy = "someone@example.com"
        return ev
    }

    // JS: 'buildTripBundle: a shared trip never carries the sync address'
    func testBuildTripBundleASharedTripNeverCarriesTheSyncAddress() throws {
        let ev = syncStampedTrip()
        let b = buildTripBundle(ev)
        XCTAssertFalse(b.text().contains("@"), "no address anywhere in the bundle")
        XCTAssertNil(b.event["owner"])
        XCTAssertNil(b.event["realmId"])
        XCTAssertEqual(b.event["entries"]?.arrayValue?[1]["ownedBy"]?.stringValue, "Anna", "a real name still travels")
        var short = ev
        short.entries = Array(ev.entries.prefix(20))
        let link = try XCTUnwrap(encodeTripLink(short), "a short trip fits in a link")
        XCTAssertFalse(try unpackShare(String(link.dropFirst("#/t/".count))).contains("@"), "nor in the link")
        // and sharing must not have changed the trip it was made from
        XCTAssertEqual(ev.extra["owner"], "someone@example.com")
        XCTAssertEqual(ev.entries[0].extra["owner"], "someone@example.com")
    }

    // JS: 'parseTripBundle: an OLD bundle carrying the sender’s address cannot plant it'
    func testParseTripBundleAnOldBundleCarryingTheSendersAddressCannotPlantIt() throws {
        let ev = sampleTripEvent()
        // exactly what a pre-v186 app wrote: the whole row, reserved fields and all
        var event = ev.json.objectValue ?? [:]
        event["owner"] = "someone@example.com"
        event["realmId"] = "someone@example.com"
        event["entries"] = .array(ev.entries.enumerated().map { i, e in
            var o = e.json.objectValue ?? [:]
            o["owner"] = "someone@example.com"
            o["realmId"] = "someone@example.com"
            o["ownedBy"] = i == 0 ? "someone@example.com" : "Anna"
            return .object(o)
        })
        let old: JSONValue = ["app": "ams-packing-list", "kind": "trip", "version": 1,
                              "exportedAt": "2026-09-01T00:00:00.000Z", "event": .object(event)]
        let got = try parseTripBundle(old.text())
        XCTAssertFalse(got.json.text().contains("@"), "nothing of the address arrives")
        XCTAssertNil(got.json["owner"], "or the receiver’s own sync would treat the trip as someone else’s")
        XCTAssertNil(got.json["realmId"])
        XCTAssertTrue(got.entries.allSatisfy { $0.json["owner"] == nil && $0.json["realmId"] == nil })
        XCTAssertEqual(got.entries[0].ownedBy, "")
        XCTAssertEqual(got.entries[1].ownedBy, "Anna")
    }

    // JS: 'buildTripBundle/parseTripBundle: the small things under an item arrive as words'
    func testTheSmallThingsUnderAnItemArriveAsWords() throws {
        var ev = sampleTripEvent()
        ev.entries[0].sub = ["Spare laces", "Insoles"]
        let b = buildTripBundle(ev)
        XCTAssertEqual(b.event["entries"]?.arrayValue?[0]["sub"]?.value, ["Spare laces", "Insoles"])
        XCTAssertEqual(try parseTripBundle(b.text()).entries[0].sub, ["Spare laces", "Insoles"])
    }

    // JS: 'parseTripBundle: an OLD bundle whose sub-items were taken apart letter by letter is put back together'
    func testAnOldBundleWhoseSubItemsWereTakenApartIsPutBackTogether() throws {
        let ev = sampleTripEvent()
        var bundle = buildTripBundle(ev).json
        var event = bundle["event"] ?? [:]
        var entries = event["entries"]?.arrayValue ?? []
        // what slimEntry made of ["ab", "Cap"] before v186
        entries[0]["sub"] = [["0": "a", "1": "b"], ["0": "C", "1": "a", "2": "p"]]
        event["entries"] = .array(entries)
        bundle["event"] = event
        XCTAssertEqual(try parseTripBundle(bundle.text()).entries[0].sub, ["ab", "Cap"])
    }

    // JS: 'encodeTripLink / decodeTripLink: full round-trip through a deep link'
    func testEncodeTripLinkDecodeTripLinkFullRoundTrip() throws {
        var ev = newEvent(name: "Weekend run", activities: ["list-1"], nights: 1)
        ev.entries = sampleEntries(5)
        let frag = try XCTUnwrap(encodeTripLink(ev))
        XCTAssertTrue(frag.hasPrefix("#/t/"))
        let got = try decodeTripLink(String(frag.dropFirst("#/t/".count)))
        XCTAssertEqual(got.name, "Weekend run")
        XCTAssertEqual(got.entries.count, 5)
    }

    // JS: 'encodeTripLink: returns null when the payload is too large for a link'
    func testEncodeTripLinkReturnsNilWhenThePayloadIsTooLarge() {
        var ev = newEvent(name: "Everything", activities: ["list-1"])
        // Varied lines — notes nothing else repeats — so the link really grows.
        let all: [Item] = (0..<200).map { i in
            newItem(name: "Thing \(i)", category: "Clothing", note: "note \(i * 7919 % 1000) for \(i * 104_729 % 997)",
                    weight: Double(i * 37 % 911), sourceListId: "list-1", sourceItemId: "item-\(i)")
        }
        // Repeat the materialised entries until even the slimmed link would overflow.
        ev.entries = []
        while encodeTripLink(ev) != nil { ev.entries.append(contentsOf: all) }
        XCTAssertNil(encodeTripLink(ev))
        XCTAssertGreaterThan(ev.entries.count, 30, "a normal-sized trip still fits; only very large ones fall back to a file")
    }

    // JS: 'packer flows onto a trip entry and survives the share bundle'
    func testPackerFlowsOntoATripEntryAndSurvivesTheShareBundle() throws {
        XCTAssertEqual(newItem(name: "Tent", packer: "Anna").packer, "Anna")
        var ev = newEvent(name: "Trip")
        ev.entries = [newItem(name: "Tent", packer: "Anna")]
        let back = try parseTripBundle(buildTripBundle(ev))
        XCTAssertEqual(back.entries[0].packer, "Anna")
    }

    // JS: 'encodeTripLink: a big trip now fits a link, and decodes back to the same trip'
    func testABigTripNowFitsALinkAndDecodesBackToTheSameTrip() throws {
        var ev = newEvent(name: "Long haul", startDate: "2026-10-01", endDate: "2026-10-14")
        // 300 entries, the shape a real week-away list has
        ev.entries = (0..<300).map { i in
            Item(id: "e\(i)", name: "Item \(i)", qty: "1", category: "Clothing",
                 container: "Carry-on / hand luggage", phase: "week", extra: ["packed": false])
        }
        let frag = try XCTUnwrap(encodeTripLink(ev), "a 300-line trip travels as a link")
        XCTAssertLessThan(frag.utf16.count, TRIP_LINK_MAX, "link is \(frag.count) characters")
        XCTAssertTrue(frag.hasPrefix("#/t/"))
        let back = try decodeTripLink(String(frag.dropFirst("#/t/".count)))
        XCTAssertEqual(back.name, "Long haul")
        XCTAssertEqual(back.entries.count, 300)
        XCTAssertEqual(back.entries[42].name, "Item 42")
    }

    // --- not in the JS suite ---

    /// The same trip `ShareReferenceFixtures` was made from, built the way the app
    /// builds a hand-added line (`newItem`), so its JS key order is the canonical one.
    private func referenceTrip() -> TripEvent {
        var ev = newEvent(id: "ev-1", name: "Fjällvecka / test", transport: "Plane", weatherOn: ["cold"],
                          startDate: "2026-10-01", endDate: "2026-10-04", nights: 3, destination: "Åre",
                          createdAt: "2026-01-01T00:00:00.000Z", updatedAt: "2026-01-01T00:00:00.000Z")
        ev.entries = [
            newItem(id: "e1", name: "Tent", sub: ["Pegs", "Guy 😀"], note: "line1\nline2", weight: 2300.5,
                    packer: "Alex", custom: true, checked: true, used: false),
            newItem(id: "e2", name: "Charger", qty: "2", itemType: "reminder", charging: true, chargeType: "usb-c",
                    photos: ["ph-1"],
                    maintenance: Maintenance(notes: "Check cable", intervalDays: 90,
                                             log: [MaintenanceLogEntry(date: "2026-02-01", note: "ok")]),
                    custom: true),
            newItem(id: "e3", name: "Sunscreen", container: "", liquid: true, consumable: true, custom: true),
        ]
        ev.entries[2].skipped = true
        ev.geo = GeoFix(lat: 63.4, lon: 13.08, place: "Åre, SE")
        ev.entries[0].ownedBy = "Alex"
        ev.entries[1].ownedBy = "someone@example.com"
        ev.extra["owner"] = "someone@example.com"
        ev.extra["realmId"] = "someone@example.com"
        ev.entries[0].extra["owner"] = "someone@example.com"
        return ev
    }

    func testTheBundleTextIsByteForByteTheWebApps() throws {
        let when = "2026-09-21T10:00:00.000Z"
        let b = buildTripBundle(referenceTrip(), whenISO: when)
        XCTAssertEqual(b.text(), ShareRef.tripText)
        XCTAssertEqual(b.text(pretty: true), ShareRef.tripPretty, "the file the app saves")
        XCTAssertEqual(encodeTripLink(referenceTrip(), whenISO: when), ShareRef.tripLink)
        XCTAssertEqual(b.exportedAt, when)
    }

    func testALinkMadeByTheWebAppOpensHere() throws {
        PackingEnv.freeze(at: "2026-09-22T08:00:00.000Z")
        let got = try decodeTripLink(String(ShareRef.tripLink.dropFirst("#/t/".count)))
        XCTAssertEqual(got.name, "Fjällvecka / test")
        XCTAssertEqual(got.id, "id-1", "ids are drawn in the JS order: the trip, then each entry")
        XCTAssertEqual(got.entries.map { $0.id }, ["id-2", "id-3", "id-4"])
        XCTAssertEqual(got.createdAt, "2026-09-22T08:00:00.000Z")
        XCTAssertEqual(got.updatedAt, got.createdAt)
        XCTAssertEqual(got.entries.map { $0.name }, ["Tent", "Charger", "Sunscreen"])
        XCTAssertEqual(got.entries.map { $0.sub }, [["Pegs", "Guy 😀"], [], []])
        XCTAssertEqual(got.entries.map { $0.ownedBy }, ["Alex", "", ""])
        XCTAssertEqual(got.entries[0].note, "line1\nline2")
        XCTAssertEqual(got.entries[0].weight, 2300.5)
        XCTAssertEqual(got.entries[1].maintenance?.intervalDays, 90)
        XCTAssertEqual(got.entries[2].container, "", "coerceItem never invents a container")
        XCTAssertTrue(got.entries[2].skipped)
        XCTAssertNil(got.entries[0].used)
        XCTAssertEqual(got.geo, GeoFix(lat: 63.4, lon: 13.08, place: "Åre, SE"))
        XCTAssertEqual(got.weatherOn, ["cold"])
    }

    func testAnOldWebBundleIsReadAsTheWebAppReadsIt() throws {
        // Sub-items taken apart unit by unit — an emoji as two lone halves, which
        // Foundation's JSON reader refuses on its own — and the row's address and all.
        let got = try parseTripBundle(ShareRef.oldTripText)
        XCTAssertEqual(got.name, "Old link")
        XCTAssertEqual(got.entries.map { $0.sub }, [["Pegs", "Guy 😀", "Named", "Plain"], []])
        XCTAssertEqual(got.entries.map { $0.ownedBy }, ["Kim", ""], "a legacy `owner` that is a NAME is adopted; an address is not")
        XCTAssertFalse(got.json.text().contains("@"))
    }

    func testJunkInABundle() throws {
        // `event` only has to be truthy; whatever it is, what comes out is an event.
        XCTAssertEqual(try parseTripBundle(json: ["kind": "trip", "event": true]).entries, [])
        XCTAssertEqual(try parseTripBundle(json: ["kind": "trip", "event": []]).name, "")
        XCTAssertThrowsError(try parseTripBundle(json: ["kind": "trip", "event": ""]))
        XCTAssertThrowsError(try parseTripBundle(json: ["kind": "trip", "event": 0]))
        XCTAssertThrowsError(try parseTripBundle(json: ["kind": "trip", "event": nil]))
        XCTAssertThrowsError(try parseTripBundle(json: [["kind": "trip"]]))
        XCTAssertThrowsError(try parseTripBundle(json: nil))
        // An entry that is a string or null: JS throws (a TypeError) when it sets its id.
        XCTAssertThrowsError(try parseTripBundle(json: ["kind": "trip", "event": ["entries": ["junk"]]])) {
            XCTAssertEqual(($0 as? ShareError)?.message, "This does not look like a shared AMS trip.")
        }
        XCTAssertThrowsError(try parseTripBundle(json: ["kind": "trip", "event": ["entries": [nil]]]))
        // The JS form for a trip that may not be there.
        XCTAssertThrowsError(try buildTripBundle(nil as TripEvent?)) { XCTAssertEqual(($0 as? ShareError)?.message, "No trip to share.") }
        XCTAssertThrowsError(try encodeTripLink(nil as TripEvent?))
    }

    func testSlimEntryDropsWhatTheReceiverNeverNeeds() {
        var e = newItem(id: "x", name: "Tent", sub: ["", "Pegs"], ownedBy: "  Anna   Berg ",
                        sourceListId: "l", sourceItemId: "i", custom: true, checked: true, used: true, edited: true)
        e.stats.packed = 3
        XCTAssertEqual(slimEntry(e).text(),
                       "{\"name\":\"Tent\",\"category\":\"Comfort & misc\",\"container\":\"Carry-on / hand luggage\",\"phase\":\"week\",\"sub\":[\"Pegs\"],\"ownedBy\":\"Anna Berg\",\"_edited\":true}")
        XCTAssertEqual(subName(["name": "Named"]), "Named")
        XCTAssertEqual(subName(["a", "b", 3, "c"]), "ab", "joined while the pieces are strings")
        XCTAssertEqual(subName(7), "")
        XCTAssertEqual(subName(nil), "")
        XCTAssertTrue(isDefaulty("") && isDefaulty(false) && isDefaulty(0) && isDefaulty(nil) && isDefaulty([]))
        XCTAssertFalse(isDefaulty([:]) || isDefaulty("0") || isDefaulty([0]))
        XCTAssertEqual(TRIP_KIND, "trip")
        XCTAssertEqual(TRIP_LINK_MAX, 30000)
    }
}

// Every JS test of this section is ported above. Two are ported with different DATA,
// because what builds theirs belongs to other slices (`seedLists`, `buildTotalEntries`):
// `sampleTripEvent()` and the two `encodeTripLink` tests use invented materialised
// entries instead. The assertions are the JS ones, word for word.
