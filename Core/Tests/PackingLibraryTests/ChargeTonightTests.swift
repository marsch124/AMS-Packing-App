import XCTest
import PackingCore
@testable import PackingLibrary

/// "Charge tonight" — the evening before a trip, what still needs charging (spec 07 part 16,
/// his yes of 15 Oct 2026). Invented data only — this repository is public.
///
/// The library is `BatteriesTests.library()`: on the trip "Weekend in the hills" (17–20 Oct
/// 2026, the base template and Hiking) To charge lists the Toothbrush (in the Wash bag), the
/// Power bank (in the Camp pouch) and the Headlamp — the GPS watch is taken out of the pouch.
final class ChargeTonightTests: XCTestCase {
    override func setUp() { PackingEnv.freeze(at: "2026-10-13T09:00:00.000Z") }
    override func tearDown() { PackingEnv.reset() }

    private func library() -> (Library, String) {
        var lib = BatteriesTests.library()
        var t = newEvent(name: "Weekend in the hills", startDate: "2026-10-17", endDate: "2026-10-20")
        t.activities = lib.templates.filter { $0.name == "Hiking" }.map(\.id)
        let id = lib.createTrip(t).id
        return (lib, id)
    }

    private func charge(_ lib: inout Library, _ trip: String, _ name: String, _ on: Bool = true) {
        let row = lib.toCharge(tripId: trip).first { $0.name == name }!
        XCTAssertTrue(lib.setCharged(on, tripId: trip, lineId: row.lineId, contentId: row.contentId))
    }

    private func chargeMessage(_ lib: Library, now: String, movesOn: Bool = true) -> TripMessage? {
        lib.tripMessages(now: now, movesOn: movesOn).first { $0.kind == .charge }
    }

    func testTheEveningBeforeItNamesWhatIsStillToCharge() {
        var (lib, trip) = library()
        let m = lib.chargeTonight(tripId: trip, now: "2026-10-13 14:00")
        XCTAssertEqual(m?.id, "charge-\(trip)")
        XCTAssertEqual(m?.kind, .charge)
        XCTAssertEqual(m?.moment, "2026-10-16 20:00", "not the evening before the first day at 20:00")
        XCTAssertEqual(m?.title, "Charge tonight")
        // The names in To charge's own order — the card the trip shows that evening.
        XCTAssertEqual(lib.chargeCard(tripId: trip, today: "2026-10-16").map(\.name), ["Toothbrush", "Power bank", "Headlamp"])
        XCTAssertEqual(m?.body, "Toothbrush, Power bank, Headlamp")
        // Among the trip's messages, soonest first: before it sets off.
        XCTAssertEqual(lib.tripMessages(now: "2026-10-13 14:00", movesOn: true).map(\.id),
                       ["charge-\(trip)", "moves-onsite-\(trip)", "moves-review-\(trip)"])
        // Charged ones leave the message; the last one charged takes it away; unticked, back.
        charge(&lib, trip, "Power bank")
        XCTAssertEqual(chargeMessage(lib, now: "2026-10-13 14:00")?.body, "Toothbrush, Headlamp")
        charge(&lib, trip, "Toothbrush")
        charge(&lib, trip, "Headlamp")
        XCTAssertNil(chargeMessage(lib, now: "2026-10-13 14:00"), "everything charged, still: Charge tonight")
        charge(&lib, trip, "Headlamp", false)
        XCTAssertEqual(chargeMessage(lib, now: "2026-10-13 14:00")?.body, "Headlamp")
        // Packing is not charging: every line ticked, the Headlamp is still to charge.
        for line in lib.trips[0].entries { _ = lib.setChecked(true, tripId: trip, entryId: line.id) }
        XCTAssertEqual(chargeMessage(lib, now: "2026-10-13 14:00")?.body, "Headlamp", "packing charged it")
    }

    func testItComesOnlyWhileTheEveningIsAheadAndTheTripIsDated() {
        var (lib, trip) = library()
        // Its moment: up to 19:59 that evening it waits; from 20:00 it has come (or gone).
        XCTAssertNotNil(chargeMessage(lib, now: "2026-10-16 19:59"))
        XCTAssertNil(chargeMessage(lib, now: "2026-10-16 20:00"), "the evening has passed")
        XCTAssertNil(chargeMessage(lib, now: "2026-10-17 07:00"))
        // A time he leaves does not move it: the evening before is the evening before.
        XCTAssertTrue(lib.setLeaveTime("06:15", home: false, tripId: trip))
        XCTAssertEqual(chargeMessage(lib, now: "2026-10-13 14:00")?.moment, "2026-10-16 20:00")
        // New dates: it follows; the first of the month goes back to the month before.
        lib.trips[0].startDate = "2026-11-01"; lib.trips[0].endDate = "2026-11-03"
        XCTAssertEqual(chargeMessage(lib, now: "2026-10-13 14:00")?.moment, "2026-10-31 20:00")
        // A trip starting today: its evening before has passed.
        lib.trips[0].startDate = "2026-10-13"; lib.trips[0].endDate = "2026-10-15"
        XCTAssertNil(chargeMessage(lib, now: "2026-10-13 06:00"))
        // No start date: no evening before.
        lib.trips[0].startDate = ""; lib.trips[0].endDate = ""
        XCTAssertNil(lib.chargeTonight(tripId: trip, now: "2026-10-13 14:00"), "an undated trip")
        XCTAssertNil(chargeMessage(lib, now: "2026-10-13 14:00"))
        // Reviewed: none. The switch off: none. Deleted, or no such trip: none.
        lib.trips[0].startDate = "2026-10-17"; lib.trips[0].endDate = "2026-10-20"
        XCTAssertNotNil(chargeMessage(lib, now: "2026-10-13 14:00"))
        XCTAssertNil(chargeMessage(lib, now: "2026-10-13 14:00", movesOn: false), "the switch is off")
        lib.trips[0].reviewedAt = "2026-10-13T08:00:00.000Z"
        XCTAssertNil(chargeMessage(lib, now: "2026-10-13 14:00"), "a reviewed trip")
        lib.trips[0].reviewedAt = ""
        XCTAssertNil(lib.chargeTonight(tripId: "nope", now: "2026-10-13 14:00"))
        _ = lib.deleteTrip(id: trip)
        XCTAssertNil(chargeMessage(lib, now: "2026-10-13 14:00"))
    }

    func testNothingToChargeSaysNothing() {
        var (lib, trip) = library()
        // A thing set aside is not going: not named.
        let headlamp = lib.trips[0].entries.first { $0.name == "Headlamp" }!.id
        XCTAssertTrue(lib.setAside(true, tripId: trip, entryId: headlamp))
        XCTAssertEqual(chargeMessage(lib, now: "2026-10-13 14:00")?.body, "Toothbrush, Power bank")
        // No battery on the trip at all: no message, the other messages unchanged.
        for name in ["Toothbrush", "Power bank", "Headlamp", "GPS watch"] {
            XCTAssertTrue(lib.setThingBattery(id: BatteriesTests.id(lib, name), false))
        }
        XCTAssertNil(lib.chargeTonight(tripId: trip, now: "2026-10-13 14:00"))
        XCTAssertEqual(lib.tripMessages(now: "2026-10-13 14:00", movesOn: true).map(\.kind), [.setOff, .home])
        // A trip with no lines (at Plan): none.
        lib.trips[0].entries = []
        XCTAssertTrue(lib.tripMessages(now: "2026-10-13 14:00", movesOn: true).isEmpty)
    }

    func testFourNamesThenHowManyMore() {
        XCTAssertEqual(Library.chargeTonightNames([]), "")
        XCTAssertEqual(Library.chargeTonightNames(["GPS watch"]), "GPS watch")
        XCTAssertEqual(Library.chargeTonightNames(["GPS watch", "Power bank", "Bike computer", "Headlamp"]),
                       "GPS watch, Power bank, Bike computer, Headlamp")
        XCTAssertEqual(Library.chargeTonightNames(["A", "B", "C", "D", "E"]), "A, B, C, D and 1 more")
        XCTAssertEqual(Library.chargeTonightNames(["A", "B", "C", "D", "E", "F", "G"]), "A, B, C, D and 3 more")
        // On a trip: five things with a battery — the GPS watch put back in the Camp pouch, and
        // a Camera with a battery put in it too (the kit as it is now).
        var (lib, trip) = library()
        let camera = lib.addThing(name: "Camera")!
        XCTAssertTrue(lib.setThingBattery(id: camera.id, true))
        XCTAssertTrue(lib.setKit(kitId: BatteriesTests.id(lib, "Camp pouch"),
                                 contents: BatteriesTests.ids(lib, "Power bank", "GPS watch", "Lighter") + [camera.id], check: false))
        XCTAssertEqual(lib.toCharge(tripId: trip).map(\.name), ["Toothbrush", "Power bank", "GPS watch", "Camera", "Headlamp"])
        XCTAssertEqual(lib.chargeTonight(tripId: trip, now: "2026-10-13 14:00")?.body,
                       "Toothbrush, Power bank, GPS watch, Camera and 1 more")
    }

    func testItIsOneOfTheSixSoonestMessages() {
        var (lib, _) = library()
        let first = lib.trips[0]
        for n in 1...3 {
            var t = first
            t.id = "t\(n)"
            t.startDate = addDays("2026-10-17", n * 10); t.endDate = addDays("2026-10-17", n * 10 + 2)
            lib.trips.append(t)
        }
        // Four trips, three messages each: the six soonest.
        let m = lib.tripMessages(now: "2026-10-13 14:00", movesOn: true)
        XCTAssertEqual(m.count, MOVES_ON_LIMIT)
        XCTAssertEqual(m.map(\.kind), [.charge, .setOff, .home, .charge, .setOff, .home])
        XCTAssertEqual(m.map(\.moment), m.map(\.moment).sorted(), "not soonest first")
    }
}
