import XCTest
import PackingCore
@testable import PackingLibrary

/// Batteries and To charge (spec 07 part 15). Invented data only — this repository is public.
final class BatteriesTests: XCTestCase {

    override func setUp() { PackingEnv.freeze(at: "2026-10-13T09:00:00.000Z") }
    override func tearDown() { PackingEnv.reset() }

    /// The base template: a Toothbrush, a Passport and a Phone charger (the web app's
    /// "Charging" flag — a charger, no battery); Hiking: a Camp pouch, a Headlamp and a Map.
    /// The Camp pouch holds a Power bank, a GPS watch (taken out for now) and a Lighter; the
    /// Wash bag (on no template) holds the Toothbrush and Soap. With a battery: the Headlamp,
    /// the Power bank, the GPS watch and the (electric) Toothbrush.
    static func library() -> Library {
        var lib = Library()
        var base = newList(name: "Common base", role: "base")
        base.items = [newItem(name: "Toothbrush"), newItem(name: "Passport"), newItem(name: "Phone charger")]
        lib.saveTemplate(base)
        var hiking = newList(name: "Hiking", group: "GA")
        hiking.items = [newItem(name: "Camp pouch"), newItem(name: "Headlamp"), newItem(name: "Map")]
        lib.saveTemplate(hiking)
        for name in ["Power bank", "GPS watch", "Lighter", "Wash bag", "Soap"] { _ = lib.addThing(name: name) }
        _ = lib.updateThing(id: id(lib, "Phone charger")) { $0.charging = true; $0.chargeType = "usb-c" }
        for name in ["Headlamp", "Power bank", "GPS watch", "Toothbrush"] {
            XCTAssertTrue(lib.setThingBattery(id: id(lib, name), true))
        }
        // Neither kit is checked before each trip (switched off: a new kit starts on, 0.76).
        XCTAssertTrue(lib.setKit(kitId: id(lib, "Camp pouch"), contents: ids(lib, "Power bank", "GPS watch", "Lighter"),
                                 takenOut: Set(ids(lib, "GPS watch")), check: false))
        XCTAssertTrue(lib.setKit(kitId: id(lib, "Wash bag"), contents: ids(lib, "Toothbrush", "Soap"), check: false))
        return lib
    }

    static func id(_ lib: Library, _ name: String) -> String { lib.items.first { $0.name == name }!.id }
    static func ids(_ lib: Library, _ names: String...) -> [String] { names.map { id(lib, $0) } }
    func id(_ lib: Library, _ name: String) -> String { BatteriesTests.id(lib, name) }

    func trip(_ lib: inout Library, start: String = "2026-10-17", end: String = "2026-10-20") -> TripEvent {
        var t = newEvent(name: "Weekend in the hills", startDate: start, endDate: end)
        t.activities = lib.templates.filter { $0.name == "Hiking" }.map(\.id)
        return lib.createTrip(t)
    }

    func line(_ lib: Library, _ tripId: String, _ name: String) -> Item {
        lib.trips.first { $0.id == tripId }!.entries.first { $0.name == name }!
    }

    /// "Headlamp", "Power bank in Camp pouch" … — what the card lists, in its order.
    func said(_ rows: [ChargeRow]) -> [String] {
        rows.map { ($0.kit.isEmpty ? $0.name : "\($0.name) in \($0.kit)") + ($0.charged ? " ✓" : "") }
    }

    // MARK: - The thing

    func testAThingSaysItHasABatteryAndThatIsNotTheWebAppsChargingFlag() {
        var lib = BatteriesTests.library()
        let headlamp = lib.items.first { $0.name == "Headlamp" }!
        XCTAssertTrue(Library.hasBattery(headlamp))
        XCTAssertEqual(headlamp.extra[BATTERY_KEY], .bool(true))
        XCTAssertFalse(headlamp.charging, "a battery is not the web app's Charging flag")
        // The phone charger needs a cable, not charging: the web flag alone puts nothing on To charge.
        let charger = lib.items.first { $0.name == "Phone charger" }!
        XCTAssertTrue(charger.charging)
        XCTAssertFalse(Library.hasBattery(charger))
        XCTAssertEqual(lib.batteryThings().map(\.name), ["GPS watch", "Headlamp", "Power bank", "Toothbrush"])
        // Off: the key goes — never written false.
        XCTAssertTrue(lib.setThingBattery(id: headlamp.id, false))
        XCTAssertNil(lib.items.first { $0.name == "Headlamp" }!.extra[BATTERY_KEY])
        XCTAssertFalse(lib.setThingBattery(id: "no-such-thing", true))
        var draft = headlamp
        Library.setBattery(&draft, false)
        XCTAssertNil(draft.extra[BATTERY_KEY])
        Library.setBattery(&draft, true)
        XCTAssertTrue(Library.hasBattery(draft))
    }

    // MARK: - On a trip

    func testToChargeListsEveryBatteryThingOnTheTripTheOnesInsideItsKitsToo() {
        var lib = BatteriesTests.library()
        let t = trip(&lib).id
        // The Wash bag in the toothbrush's place; the pouch's Power bank — the GPS watch is taken out,
        // so it is not on this trip; the phone charger only carries the web app's flag.
        XCTAssertEqual(said(lib.toCharge(tripId: t)), ["Toothbrush in Wash bag", "Power bank in Camp pouch", "Headlamp"])
        // The thing as it is NOW: switched on after the trip was made, it shows.
        _ = lib.setThingBattery(id: id(lib, "Map"), true)
        XCTAssertEqual(said(lib.toCharge(tripId: t)).last, "Map")
        // Put back in its kit, the watch goes with the trip.
        _ = lib.setTakenOut(thingId: id(lib, "GPS watch"), false)
        XCTAssertEqual(said(lib.toCharge(tripId: t)), ["Toothbrush in Wash bag", "Power bank in Camp pouch",
                                                       "GPS watch in Camp pouch", "Headlamp", "Map"])
        // A kit with a battery of its own comes first, then what is inside it.
        _ = lib.setThingBattery(id: id(lib, "Camp pouch"), true)
        XCTAssertEqual(said(lib.toCharge(tripId: t)).prefix(4), ["Toothbrush in Wash bag", "Camp pouch",
                                                                 "Power bank in Camp pouch", "GPS watch in Camp pouch"])
        // Not this time: it is not going.
        XCTAssertTrue(lib.setAside(true, tripId: t, entryId: line(lib, t, "Headlamp").id))
        XCTAssertFalse(said(lib.toCharge(tripId: t)).contains("Headlamp"))
        // A reminder is never a thing to charge; a line typed on the trip has no thing behind it.
        if let hiking = lib.templates.first(where: { $0.name == "Hiking" }) {
            _ = lib.addReminder(templateId: hiking.id, name: "Charge the watch")
        }
        XCTAssertNotNil(lib.changeTrip(id: t) { _ in })
        XCTAssertTrue(lib.trips[0].entries.contains { $0.name == "Charge the watch" }, "the rebuild brought the reminder")
        XCTAssertFalse(said(lib.toCharge(tripId: t)).contains("Charge the watch"))
        XCTAssertNotNil(lib.addCustomLine(tripId: t, name: "Spare batteries"))
        XCTAssertFalse(said(lib.toCharge(tripId: t)).contains("Spare batteries"))
        XCTAssertEqual(lib.toCharge(tripId: "no-such-trip"), [])
    }

    func testTheChargeTickIsApartFromPacking() {
        var lib = BatteriesTests.library()
        let t = trip(&lib).id
        let pouch = line(lib, t, "Camp pouch").id, lamp = line(lib, t, "Headlamp").id
        let bank = id(lib, "Power bank")
        let before = progress(lib.trips[0].entries)

        // Charging the headlamp does not pack it.
        XCTAssertTrue(lib.setCharged(true, tripId: t, lineId: lamp))
        XCTAssertEqual(line(lib, t, "Headlamp").extra[CHARGED_KEY], .bool(true))
        XCTAssertFalse(line(lib, t, "Headlamp").checked, "charging it packed it")
        XCTAssertEqual(progress(lib.trips[0].entries).done, before.done)
        // Charging the power bank inside the pouch marks the pouch's line, nothing else.
        XCTAssertTrue(lib.setCharged(true, tripId: t, lineId: pouch, contentId: bank))
        XCTAssertEqual(line(lib, t, "Camp pouch").extra[KIT_CHARGED_KEY], JSONValue([bank]))
        XCTAssertFalse(line(lib, t, "Camp pouch").checked)
        XCTAssertEqual(said(lib.toCharge(tripId: t)), ["Toothbrush in Wash bag", "Power bank in Camp pouch ✓", "Headlamp ✓"])
        XCTAssertEqual(Library.chargeWords(lib.toCharge(tripId: t)), "2 of 3")

        // Packing never marks charged — nor takes the mark away.
        XCTAssertTrue(lib.setChecked(true, tripId: t, entryId: line(lib, t, "Wash bag").id))
        XCTAssertEqual(said(lib.toCharge(tripId: t)).first, "Toothbrush in Wash bag", "packing the wash bag charged it")
        _ = lib.setAllChecked(true, tripId: t)
        _ = lib.setAllChecked(false, tripId: t)
        XCTAssertEqual(said(lib.toCharge(tripId: t)), ["Toothbrush in Wash bag", "Power bank in Camp pouch ✓", "Headlamp ✓"])

        // Unticked: the marks go, an empty list is never kept.
        XCTAssertTrue(lib.setCharged(false, tripId: t, lineId: pouch, contentId: bank))
        XCTAssertNil(line(lib, t, "Camp pouch").extra[KIT_CHARGED_KEY])
        XCTAssertTrue(lib.setCharged(false, tripId: t, lineId: lamp))
        XCTAssertNil(line(lib, t, "Headlamp").extra[CHARGED_KEY])
        // Only what is inside the kit now: the taken-out watch, or a thing in no kit, cannot be marked there.
        XCTAssertFalse(lib.setCharged(true, tripId: t, lineId: pouch, contentId: id(lib, "GPS watch")))
        XCTAssertFalse(lib.setCharged(true, tripId: t, lineId: pouch, contentId: id(lib, "Map")))
        XCTAssertFalse(lib.setCharged(true, tripId: t, lineId: "no-such-line"))
    }

    func testToChargeShowsFromTheDayBeforeTheTripThroughItsLastDay() {
        var lib = BatteriesTests.library()
        let t = trip(&lib).id
        let trip = lib.trips.first { $0.id == t }!
        XCTAssertFalse(Library.chargeWindow(trip, today: "2026-10-15"), "two days before")
        XCTAssertTrue(Library.chargeWindow(trip, today: "2026-10-16"), "the day before")
        XCTAssertTrue(Library.chargeWindow(trip, today: "2026-10-17"))
        XCTAssertTrue(Library.chargeWindow(trip, today: "2026-10-20"), "the last day: he may charge again on site")
        XCTAssertFalse(Library.chargeWindow(trip, today: "2026-10-21"), "the day after")
        XCTAssertEqual(lib.chargeCard(tripId: t, today: "2026-10-15"), [])
        XCTAssertEqual(lib.chargeCard(tripId: t, today: "2026-10-16").count, 3)
        // One day only: the end is the start.
        var day = trip; day.endDate = ""
        XCTAssertTrue(Library.chargeWindow(day, today: "2026-10-17"))
        XCTAssertFalse(Library.chargeWindow(day, today: "2026-10-18"))
        // No dates: nothing to wait for.
        var undated = trip; undated.startDate = ""; undated.endDate = ""
        XCTAssertTrue(Library.chargeWindow(undated, today: "2026-10-13"))
        // Reviewed: never.
        XCTAssertTrue(lib.saveReview(tripId: t, unused: [], missed: [], when: "2026-10-17T18:00:00.000Z"))
        XCTAssertFalse(Library.chargeWindow(lib.trips.first { $0.id == t }!, today: "2026-10-17"))
        XCTAssertEqual(lib.chargeCard(tripId: t, today: "2026-10-17"), [])
        // Nothing with a battery: no card.
        for name in ["Headlamp", "Power bank", "GPS watch", "Toothbrush"] { _ = lib.setThingBattery(id: id(lib, name), false) }
        let other = self.trip(&lib).id
        XCTAssertEqual(lib.chargeCard(tripId: other, today: "2026-10-16"), [])
    }

    func testBatteriesAndChargeTicksAreStoredSyncedBackedUpRestoredAndKeptByARebuildButNeverSentOrStartedAgain() throws {
        var lib = BatteriesTests.library()
        let t = trip(&lib).id
        let pouch = line(lib, t, "Camp pouch").id, lamp = line(lib, t, "Headlamp").id
        XCTAssertTrue(lib.setCharged(true, tripId: t, lineId: lamp))
        XCTAssertTrue(lib.setCharged(true, tripId: t, lineId: pouch, contentId: id(lib, "Power bank")))
        let shown = said(lib.toCharge(tripId: t))
        XCTAssertEqual(shown, ["Toothbrush in Wash bag", "Power bank in Camp pouch ✓", "Headlamp ✓"])

        // The store and iCloud: records and back.
        let stored = Library(records: lib.records())
        XCTAssertEqual(stored.trips, lib.trips)
        XCTAssertEqual(said(stored.toCharge(tripId: t)), shown)
        XCTAssertEqual(stored.batteryThings().map(\.name), lib.batteryThings().map(\.name))
        // A backup file, read back as Settings reads it — as this app writes it, and the older
        // kind rebuilt from the template rows.
        for data in [lib.backupData(exportedAt: "2026-10-13T09:00:00.000Z"),
                     BackupTests.olderFile(lib, exportedAt: "2026-10-13T09:00:00.000Z")] {
            let (back, report) = try BackupTests.read(data)
            XCTAssertTrue(report.isFaithful, report.mismatches.joined(separator: "; "))
            XCTAssertEqual(back.batteryThings().map(\.name), ["GPS watch", "Headlamp", "Power bank", "Toothbrush"])
            XCTAssertEqual(said(back.toCharge(tripId: t)), shown)
        }
        // The web app's model reads a plain thing and a plain line: the keys ride along unread.
        let headlamp = lib.items.first { $0.name == "Headlamp" }!
        XCTAssertEqual(Item(json: headlamp.json), headlamp)
        XCTAssertEqual(coerceItem(headlamp).extra[BATTERY_KEY], .bool(true))
        let pl = line(lib, t, "Camp pouch")
        XCTAssertEqual(Item(json: pl.json).extra[KIT_CHARGED_KEY], pl.extra[KIT_CHARGED_KEY])

        // A rebuild (Trip settings → Save) and a change to a thing reaching the trip keep the marks.
        XCTAssertNotNil(lib.changeTrip(id: t) { $0.season = "Winter" })
        _ = lib.updateThing(id: id(lib, "Headlamp")) { $0.note = "Spare batteries in the lid" }
        XCTAssertEqual(said(lib.toCharge(tripId: t)), shown)

        // Sent, or started again: the charge was for that trip.
        let sent = Library.justTheList(lib.trips.first { $0.id == t }!)
        XCTAssertTrue(sent.entries.allSatisfy { $0.extra[CHARGED_KEY] == nil && $0.extra[KIT_CHARGED_KEY] == nil })
        let again = lib.startAgain(from: t, name: "Again")!
        XCTAssertTrue(again.entries.allSatisfy { $0.extra[CHARGED_KEY] == nil && $0.extra[KIT_CHARGED_KEY] == nil })
        XCTAssertEqual(said(lib.toCharge(tripId: again.id)), ["Toothbrush in Wash bag", "Power bank in Camp pouch", "Headlamp"])
        XCTAssertEqual(said(lib.toCharge(tripId: t)), shown, "the trip itself keeps its own")
    }
}
