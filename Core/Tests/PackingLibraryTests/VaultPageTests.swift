import XCTest
import PackingCore
@testable import PackingLibrary

/// A trip page in his Obsidian vault (spec 07 part 8, 0.70): the page's words for the
/// sample trip, and the marks that let the iPhone ask and the Mac answer.
/// Invented data only — this repository is public.
final class VaultPageTests: XCTestCase {

    override func setUp() { PackingEnv.freeze() }
    override func tearDown() { PackingEnv.reset() }

    static let utc = TimeZone(identifier: "UTC")!
    static let reviewedAt = "2026-07-07T10:00:00.000Z"
    /// A tiny "JPEG" — the page only copies bytes, it never looks at them.
    static let jpeg = Data([0xFF, 0xD8, 0xFF, 0xD9])

    /// The sample trip: "Weekend in the hills", 3–5 Jul 2026 in Testville, built from
    /// Hiking and the base template; everything packed (the boots in the day pack, which
    /// was weighed); a photo of each bag; a sun hat bought on site; a note on the rain
    /// jacket; the map not used; a power bank (onto Hiking) and a sit mat (on no
    /// template) missed. Not reviewed yet — `reviewed()` does that.
    static func sample() -> (lib: Library, tripId: String) {
        var lib = Library()
        var base = newList(name: "Common base", role: "base")
        base.items = [newItem(name: "Passport"), newItem(name: "Toothbrush")]
        lib.saveTemplate(base)
        var hiking = newList(name: "Hiking", group: "GA")
        hiking.items = [newItem(name: "Hiking boots", container: "Day pack"), newItem(name: "Rain jacket"), newItem(name: "Map")]
        lib.saveTemplate(hiking)
        let grams: [String: Double] = ["Passport": 35, "Toothbrush": 18, "Hiking boots": 1250, "Rain jacket": 420, "Map": 60]
        for n in lib.items.indices { lib.items[n].weight = grams[lib.items[n].name] ?? 0 }

        var draft = newEvent(name: "Weekend in the hills", startDate: "2026-07-03", endDate: "2026-07-05")
        draft.activities = [lib.templates.first { $0.name == "Hiking" }!.id]
        draft.destination = "Testville"
        let trip = lib.createTrip(draft)
        let days = [WeatherDay(date: "2026-07-03", code: 2, tmax: 19, tmin: 12, precipProb: 40, wind: 20),
                    WeatherDay(date: "2026-07-04", code: 61, tmax: 15, tmin: 9, precipProb: 80, wind: 12),
                    WeatherDay(date: "2026-07-05", code: 0, tmax: 21, tmin: 11, precipProb: 0, wind: 8)]
        lib.setWeather(tripId: trip.id, place: "Testville", lat: nil, lon: nil,
                       snapshot: WeatherSnapshot(place: "Testville, SE", fetchedAt: nowISO(), daily: days))
        for e in lib.trip(trip.id)!.entries { lib.setChecked(true, tripId: trip.id, entryId: e.id) }
        lib.setWeighed(tripId: trip.id, bag: "Day pack", grams: 1400)
        XCTAssertNotNil(lib.addBagPhoto(tripId: trip.id, bag: "Carry-on / hand luggage", jpeg: jpeg))
        XCTAssertNotNil(lib.addBagPhoto(tripId: trip.id, bag: "Day pack", jpeg: jpeg))
        XCTAssertNotNil(lib.addBoughtOnSite(tripId: trip.id, name: "Sun hat"))
        let jacket = lib.trip(trip.id)!.entries.first { $0.name == "Rain jacket" }!
        lib.setHomeNote("zip broken", tripId: trip.id, entryId: jacket.id)
        return (lib, trip.id)
    }

    static func reviewed() -> (lib: Library, tripId: String) {
        var (lib, id) = sample()
        let map = lib.trip(id)!.entries.first { $0.name == "Map" }!
        let hiking = lib.templates.first { $0.name == "Hiking" }!
        XCTAssertTrue(lib.saveReview(tripId: id, unused: [map.id],
                                     missed: [Library.Missed(name: "Power bank", templateId: hiking.id),
                                              Library.Missed(name: "Sit mat", templateId: "")],
                                     when: reviewedAt))
        return (lib, id)
    }

    // MARK: - The page

    func testTheSampleTripsPageHasItsNameFrontMatterAndSections() throws {
        let (lib, id) = VaultPageTests.reviewed()
        let page = try XCTUnwrap(lib.vaultPage(tripId: id, zone: VaultPageTests.utc))
        XCTAssertEqual(page.fileName, "2026-07 Weekend in the hills.md")
        let front = page.text.components(separatedBy: "\n").prefix(17).joined(separator: "\n")
        XCTAssertEqual(front, """
            ---
            type: trip
            start: 2026-07-03
            end: 2026-07-05
            nights: 2
            place: "Testville"
            transport: "Car"
            season: "Summer"
            templates:
              - "Common base"
              - "Hiking"
            packed: "6/6"
            weight: 1.9
            reviewed: 2026-07-07
            ---

            # Weekend in the hills
            """)
        XCTAssertTrue(page.text.contains("\n3 Jul 2026 \u{2013} 5 Jul 2026 \u{00B7} 2 nights \u{00B7} Testville\n"), page.text)
        // The sections, in the agreed order — no Workouts: nothing was read from Apple Health.
        let heads = page.text.components(separatedBy: "\n").filter { $0.hasPrefix("## ") }
        XCTAssertEqual(heads, ["## Weather", "## Bags", "## Didn't use", "## Missed", "## Bought on site", "## Notes"])
    }

    func testEachSectionSaysWhatTheTripRecorded() throws {
        let (lib, id) = VaultPageTests.reviewed()
        let text = try XCTUnwrap(lib.vaultPage(tripId: id, zone: VaultPageTests.utc)).text
        func section(_ name: String) -> [String] {
            let all = text.components(separatedBy: "\n")
            guard let at = all.firstIndex(of: "## \(name)") else { return [] }
            return Array(all[(at + 1)...].prefix { !$0.hasPrefix("## ") && !$0.hasPrefix("*Written") }).filter { !$0.isEmpty }
        }
        XCTAssertEqual(section("Weather"), [
            "Testville, SE \u{00B7} 9\u{2013}21\u{00B0}C \u{00B7} rain",
            "- Fri 3 Jul 2026: Partly cloudy \u{00B7} 12\u{2013}19\u{00B0}C \u{00B7} rain 40 % \u{00B7} wind 20 km/h",
            "- Sat 4 Jul 2026: Rain \u{00B7} 9\u{2013}15\u{00B0}C \u{00B7} rain 80 % \u{00B7} wind 12 km/h",
            "- Sun 5 Jul 2026: Clear \u{00B7} 11\u{2013}21\u{00B0}C \u{00B7} wind 8 km/h"])
        XCTAssertEqual(section("Bags"), [
            "### Carry-on / hand luggage \u{00B7} 533 g \u{00B7} max 8 kg",
            "![Carry-on / hand luggage, photo 1](attachments/2026-07%20Weekend%20in%20the%20hills%20-%20Carry-on%20-%20hand%20luggage%201.jpg)",
            "### Day pack \u{00B7} 1.4 kg weighed \u{00B7} max 8 kg",
            "![Day pack, photo 1](attachments/2026-07%20Weekend%20in%20the%20hills%20-%20Day%20pack%201.jpg)"])
        XCTAssertEqual(section("Didn't use"), ["- Map"])
        XCTAssertEqual(section("Missed"), ["- Power bank \u{2014} onto Hiking",
                                           "- Sit mat \u{2014} a thing of its own, on no template"])
        XCTAssertEqual(section("Bought on site"), ["- Sun hat"])
        XCTAssertEqual(section("Notes"), ["- **Rain jacket**: zip broken"])
        XCTAssertTrue(text.hasSuffix("*Written by AMS Packing. Sending the trip again replaces this page.*\n"))
    }

    func testTheBagsPhotosAreCopiedBesideThePage() throws {
        let (lib, id) = VaultPageTests.reviewed()
        let page = try XCTUnwrap(lib.vaultPage(tripId: id, zone: VaultPageTests.utc))
        XCTAssertEqual(page.attachments.map(\.fileName), ["2026-07 Weekend in the hills - Carry-on - hand luggage 1.jpg",
                                                          "2026-07 Weekend in the hills - Day pack 1.jpg"])
        for a in page.attachments {
            XCTAssertEqual(lib.vaultPhoto(a.photoId)?.data, VaultPageTests.jpeg, "the photo's own bytes are copied")
            XCTAssertEqual(lib.vaultPhoto(a.photoId)?.ending, "jpg")
        }
        XCTAssertEqual(VAULT_ATTACHMENTS_FOLDER, "attachments")
    }

    func testThePageIsTheSameEveryTime() {
        let (lib, id) = VaultPageTests.reviewed()
        XCTAssertEqual(lib.vaultPage(tripId: id, zone: VaultPageTests.utc), lib.vaultPage(tripId: id, zone: VaultPageTests.utc))
    }

    func testOnlyAReviewedTripHasAPage() {
        let (lib, id) = VaultPageTests.sample()
        XCTAssertNil(lib.vaultPage(tripId: id), "before the review there is nothing to write")
        XCTAssertNil(lib.vaultPage(tripId: "no-such-trip"))
        // A trip the web app marked done, with no review time, counts as reviewed (one rule).
        var web = lib
        web.trips[0].status = "done"
        XCTAssertNotNil(web.vaultPage(tripId: id, zone: VaultPageTests.utc))
    }

    func testTheDayOfTheReviewIsTheDevicesDay() throws {
        var (lib, id) = VaultPageTests.reviewed()
        lib.trips[0].reviewedAt = "2026-07-07T23:30:00.000Z"
        let stockholm = TimeZone(identifier: "Europe/Stockholm")!
        XCTAssertTrue(try XCTUnwrap(lib.vaultPage(tripId: id, zone: stockholm)).text.contains("\nreviewed: 2026-07-08\n"),
                      "half past eleven UTC is the next morning in Sweden")
        XCTAssertTrue(try XCTUnwrap(lib.vaultPage(tripId: id, zone: VaultPageTests.utc)).text.contains("\nreviewed: 2026-07-07\n"))
    }

    func testAnUndatedTripIsNamedByTheMonthOfItsReview() throws {
        var (lib, id) = VaultPageTests.reviewed()
        lib.trips[0].startDate = ""
        lib.trips[0].endDate = ""
        let page = try XCTUnwrap(lib.vaultPage(tripId: id, zone: VaultPageTests.utc))
        XCTAssertEqual(page.fileName, "2026-07 Weekend in the hills.md")
        XCTAssertTrue(page.text.contains("\nstart:\nend:\n"), "an empty date is an empty value")
        XCTAssertTrue(page.text.contains("\nNo dates \u{00B7} 2 nights \u{00B7} Testville\n"))
    }

    func testNamesAreMadeSafeForAFileAndForMarkdown() throws {
        var (lib, id) = VaultPageTests.reviewed()
        lib.trips[0].name = "  .Hut / Lake: *wet* #2  "
        lib.trips[0].destination = "Nice \"old\" town"
        let page = try XCTUnwrap(lib.vaultPage(tripId: id, zone: VaultPageTests.utc))
        XCTAssertEqual(page.fileName, "2026-07 Hut - Lake- -wet- -2.md", "no / : * # in a file name, no hidden file")
        XCTAssertTrue(page.text.contains("\n# .Hut / Lake: \\*wet\\* \\#2\n"), "his words, read as typed")
        XCTAssertTrue(page.text.contains("\nplace: \"Nice \\\"old\\\" town\"\n"), "a quote inside a YAML string")
        lib.trips[0].name = "   "
        XCTAssertEqual(lib.vaultPage(tripId: id, zone: VaultPageTests.utc)?.fileName, "2026-07 Trip.md")
    }

    func testAnOlderReviewSaysMissedWasNotRecorded() throws {
        var (lib, id) = VaultPageTests.reviewed()
        lib.trips[0].extra[MISSED_AT_REVIEW_KEY] = nil
        let text = try XCTUnwrap(lib.vaultPage(tripId: id, zone: VaultPageTests.utc)).text
        XCTAssertTrue(text.contains("## Missed\n\nNot recorded: this trip was reviewed before version 0.70.\n"), text)
    }

    func testWorkoutsFromAppleHealthGetASectionOfTheirOwn() throws {
        var (lib, id) = VaultPageTests.reviewed()
        lib.trips[0].extra[TRIP_WORKOUTS_KEY] = .array([.string("Swim \u{00B7} indoor \u{00B7} 3 times"), .string(" "), .string("No bike")])
        let text = try XCTUnwrap(lib.vaultPage(tripId: id, zone: VaultPageTests.utc)).text
        XCTAssertTrue(text.contains("## Workouts\n\n- Swim \u{00B7} indoor \u{00B7} 3 times\n- No bike\n\n## Bags"), text)
    }

    func testATripWithNothingOnSiteSaysSo() throws {
        var (lib, id) = VaultPageTests.reviewed()
        lib.trips[0].entries.removeAll { Library.isBoughtOnSite($0) }
        for n in lib.trips[0].entries.indices {
            lib.trips[0].entries[n].extra[HOME_NOTE_KEY] = nil
            lib.trips[0].entries[n].used = true
        }
        lib.trips[0].weather = nil
        lib.trips[0].extra[MISSED_AT_REVIEW_KEY] = .array([])
        let text = try XCTUnwrap(lib.vaultPage(tripId: id, zone: VaultPageTests.utc)).text
        for said in ["## Weather\n\nNo forecast was kept on this trip.\n", "## Didn't use\n\nNothing \u{2014} everything that went was used.\n",
                     "## Missed\n\nNothing.\n", "## Bought on site\n\nNothing.\n", "## Notes\n\nNo notes.\n"] {
            XCTAssertTrue(text.contains(said), "missing: \(said)")
        }
    }

    // MARK: - The marks: the iPhone asks, the Mac answers

    func testASavedReviewAsksForThePageAndKeepsWhatWasMissed() {
        let (before, _) = VaultPageTests.sample()
        XCTAssertEqual(before.tripsWaitingForVault(), [], "nothing is asked for before the review")
        let (lib, id) = VaultPageTests.reviewed()
        XCTAssertEqual(lib.tripsWaitingForVault(), [id])
        XCTAssertEqual(lib.trip(id)?.extra[VAULT_WAITING_KEY]?.stringValue, VaultPageTests.reviewedAt)
        XCTAssertEqual(lib.missedAtReview(tripId: id)?.map(\.name), ["Power bank", "Sit mat"])
        XCTAssertEqual(lib.missedAtReview(tripId: id)?.map(\.template), ["Hiking", ""])
    }

    func testTheMacWritingThePageAnswersTheWish() {
        var (lib, id) = VaultPageTests.reviewed()
        XCTAssertFalse(lib.vaultPageWritten(tripId: id, file: ""), "no file, nothing written")
        XCTAssertTrue(lib.vaultPageWritten(tripId: id, file: "2026-07 Weekend in the hills.md", at: "2026-07-07T10:05:00.000Z"))
        XCTAssertEqual(lib.tripsWaitingForVault(), [])
        XCTAssertEqual(lib.vaultWritten(tripId: id)?.file, "2026-07 Weekend in the hills.md")
        XCTAssertEqual(lib.vaultWritten(tripId: id)?.at, "2026-07-07T10:05:00.000Z")
        // The iPhone's "Send to Obsidian": asked again — the Mac rewrites it.
        XCTAssertTrue(lib.askForVaultPage(tripId: id, at: "2026-07-09T08:00:00.000Z"))
        XCTAssertEqual(lib.tripsWaitingForVault(), [id])
        XCTAssertNotNil(lib.vaultWritten(tripId: id), "what was written before is still said")
    }

    func testOnlyAReviewedTripCanAskForAPage() {
        var (lib, id) = VaultPageTests.sample()
        XCTAssertFalse(lib.askForVaultPage(tripId: id))
        XCTAssertFalse(lib.askForVaultPage(tripId: "no-such-trip"))
        XCTAssertEqual(lib.tripsWaitingForVault(), [])
    }

    func testTheMarksTravelWithTheTripButNotWhenItIsShared() {
        var (lib, id) = VaultPageTests.reviewed()
        lib.trips[0].extra[TRIP_WORKOUTS_KEY] = .array([.string("No bike")])
        lib.vaultPageWritten(tripId: id, file: "x.md")
        lib.askForVaultPage(tripId: id)
        let back = Library(records: lib.records())
        XCTAssertEqual(back.tripsWaitingForVault(), [id], "the wish syncs: it is on the trip's own record")
        XCTAssertEqual(back.vaultWritten(tripId: id)?.file, "x.md")
        XCTAssertEqual(back.missedAtReview(tripId: id)?.count, 2)
        let sent = Library.justTheList(lib.trip(id)!)
        for key in [MISSED_AT_REVIEW_KEY, TRIP_WORKOUTS_KEY, VAULT_WAITING_KEY, VAULT_WRITTEN_KEY] {
            XCTAssertNil(sent.extra[key], "\(key) is his, not the list's")
        }
    }
}
