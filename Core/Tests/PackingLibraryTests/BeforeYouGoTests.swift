import XCTest
import PackingCore
@testable import PackingLibrary

/// Before you go (0.77, his yes of 13 Oct 2026): the flags, the reminders due and To charge on
/// ONE card, with one number for everything left. Invented data only — this repository is public.
final class BeforeYouGoTests: XCTestCase {

    override func setUp() { PackingEnv.freeze(at: "2026-10-13T09:00:00.000Z") }
    override func tearDown() { PackingEnv.reset() }

    func line(_ lib: Library, _ tripId: String, _ name: String) -> Int {
        lib.trips.first { $0.id == tripId }!.entries.firstIndex { $0.name == name }!
    }

    /// The batteries' library (a Toothbrush in the Wash bag, a Power bank in the Camp pouch and a
    /// Headlamp with a battery), Hiking with two reminders — a week ahead and the day before — and
    /// a trip from 20 to 22 Oct. Each part comes when its own rule says so; the count is every
    /// flag, every reminder due and every thing not charged; the colour is red for a flag that
    /// will stop him, orange while anything is left, green ("All set") once all is charged.
    func testOneCardHoldsTheFlagsTheRemindersDueAndToChargeAndCountsWhatIsLeft() {
        var lib = BatteriesTests.library()
        let hiking = lib.templates.first { $0.name == "Hiking" }!.id
        XCTAssertNotNil(lib.addReminder(templateId: hiking, name: "Check the forecast", when: "week"))
        XCTAssertNotNil(lib.addReminder(templateId: hiking, name: "Leave a route note", when: "daybefore"))
        var t = newEvent(name: "Weekend in the hills", startDate: "2026-10-20", endDate: "2026-10-22")
        t.activities = [hiking]
        let trip = lib.createTrip(t).id

        // Two weeks ahead: nothing — no card.
        XCTAssertTrue(lib.beforeYouGo(tripId: trip, today: "2026-10-01").isEmpty, "a card two weeks ahead")

        // A week ahead: one reminder due, nothing to charge yet (that is from the day before).
        var card = lib.beforeYouGo(tripId: trip, today: "2026-10-13")
        XCTAssertEqual(card.due.map(\.name), ["Check the forecast"])
        XCTAssertEqual(card.charge, [], "To charge a week ahead")
        XCTAssertEqual(card.left, 1)
        XCTAssertEqual(card.tone, .orange, "a reminder alone is still to do")
        XCTAssertEqual(card.countWords, "1")

        // The day before: both reminders and three things to charge — five left.
        card = lib.beforeYouGo(tripId: trip, today: "2026-10-19")
        XCTAssertEqual(card.due.map(\.name), ["Check the forecast", "Leave a route note"])
        XCTAssertEqual(card.charge.map(\.name), ["Toothbrush", "Power bank", "Headlamp"])
        XCTAssertEqual(card.left, 5)
        XCTAssertEqual(card.tone, .orange)

        // Charged is not left; a ticked reminder leaves the card.
        let first = lib.trips[0].entries.first { $0.name == "Check the forecast" }!.id
        XCTAssertTrue(lib.setChecked(true, tripId: trip, entryId: first))
        for row in card.charge.prefix(2) {
            XCTAssertTrue(lib.setCharged(true, tripId: trip, lineId: row.lineId, contentId: row.contentId))
        }
        card = lib.beforeYouGo(tripId: trip, today: "2026-10-19")
        XCTAssertEqual(card.due.map(\.name), ["Leave a route note"])
        XCTAssertEqual(card.charge.count, 3, "a charged thing left To charge")
        XCTAssertEqual(card.left, 2, "charged things are counted as left")

        // The last of each: all set — the card stays, green, and says so.
        let second = lib.trips[0].entries.first { $0.name == "Leave a route note" }!.id
        XCTAssertTrue(lib.setChecked(true, tripId: trip, entryId: second))
        let lamp = card.charge[2]
        XCTAssertTrue(lib.setCharged(true, tripId: trip, lineId: lamp.lineId, contentId: lamp.contentId))
        card = lib.beforeYouGo(tripId: trip, today: "2026-10-19")
        XCTAssertFalse(card.isEmpty, "all charged, the card went")
        XCTAssertEqual(card.left, 0)
        XCTAssertTrue(card.allSet)
        XCTAssertEqual(card.tone, .green)
        XCTAssertEqual(card.countWords, "All set")

        // By plane, the pouch in the hold: its power bank is a red flag — red, one left.
        lib.trips[0].transport = "Plane"
        lib.trips[0].entries[line(lib, trip, "Camp pouch")].container = "Checked luggage"
        card = lib.beforeYouGo(tripId: trip, today: "2026-10-19")
        XCTAssertEqual(card.cabin.map(\.why), [.battery])
        XCTAssertEqual(card.left, 1)
        XCTAssertFalse(card.allSet)
        XCTAssertEqual(card.tone, .red, "a battery in the hold is not red")
        XCTAssertEqual(card.countWords, "1")

        // A passport short of six months only wants a look: with the pouch in the cabin, orange.
        lib.trips[0].entries[line(lib, trip, "Camp pouch")].container = "Cabin bag"
        _ = lib.updateThing(id: BatteriesTests.id(lib, "Passport")) { $0.expiry = "2027-03-01"; $0.category = DOCUMENTS_CATEGORY }
        card = lib.beforeYouGo(tripId: trip, today: "2026-10-19")
        XCTAssertEqual(card.cabin, [])
        XCTAssertEqual(card.dates.map(\.line.name), ["Passport"])
        XCTAssertFalse(card.dates[0].isRed)
        XCTAssertEqual(card.tone, .orange, "a document short of six months is red")
        XCTAssertEqual(card.left, 1)

        // After the trip: To charge is gone, the passport still wants a look.
        card = lib.beforeYouGo(tripId: trip, today: "2026-10-23")
        XCTAssertEqual(card.charge, [], "To charge after the last day")
        XCTAssertEqual(card.left, 1)
        _ = lib.updateThing(id: BatteriesTests.id(lib, "Passport")) { $0.expiry = "" }
        XCTAssertTrue(lib.beforeYouGo(tripId: trip, today: "2026-10-23").isEmpty, "nothing left, but a card")
        XCTAssertTrue(lib.beforeYouGo(tripId: "no-such-trip", today: "2026-10-19").isEmpty)
    }
}
