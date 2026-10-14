import XCTest
import PackingCore
@testable import PackingLibrary

/// Progress you can see — the moment of a tick, his pace and what is left (spec 07 part 20).
/// Invented data only — this repository is public.
final class PackingPaceTests: XCTestCase {

    /// 13 Oct 2026 09:00 UTC, in seconds since 1970 — "now" until a test moves it.
    static let base: Double = 1_760_346_000

    override func setUp() { PackingEnv.freeze(at: "2025-10-13T09:00:00.000Z") }
    override func tearDown() { PackingEnv.reset() }

    /// The clock `seconds` after `base`.
    func at(_ seconds: Double) {
        let d = Date(timeIntervalSince1970: PackingPaceTests.base + seconds)
        PackingEnv.now = { d }
    }

    /// A trip of `count` lines typed on it ("Thing 1" …), nothing ticked.
    func trip(_ lib: inout Library, _ name: String = "Weekend in the hills", lines count: Int) -> String {
        var t = newEvent(name: name, startDate: "2026-10-17", endDate: "2026-10-19")
        t.entries = (1...count).map { Item(id: "\(name)-\($0)", name: "Thing \($0)") }
        lib.trips.append(t)
        return t.id
    }

    /// Each line of the trip ticked at its moment (seconds after `base`), as a tap would.
    func tick(_ lib: inout Library, _ tripId: String, at moments: [Double]) {
        let ids = lib.trips.first { $0.id == tripId }!.entries.map(\.id)
        for (n, m) in moments.enumerated() {
            at(m)
            XCTAssertTrue(lib.setChecked(true, tripId: tripId, entryId: ids[n]))
        }
    }

    func moment(_ lib: Library, _ tripId: String, _ n: Int) -> Double? {
        Library.tickedAt(lib.trips.first { $0.id == tripId }!.entries[n]).map { $0 - PackingPaceTests.base }
    }

    // MARK: - The moment of a tick

    func testATickKeepsItsMomentAndAnUntickTakesIt() {
        var lib = Library()
        let t = trip(&lib, lines: 2)
        let first = lib.trips[0].entries[0].id
        at(12)
        XCTAssertTrue(lib.setChecked(true, tripId: t, entryId: first))
        XCTAssertEqual(lib.trips[0].entries[0].extra[TICKED_AT_KEY], .number(PackingPaceTests.base + 12), "whole seconds since 1970")
        at(40)
        XCTAssertTrue(lib.setChecked(true, tripId: t, entryId: first))
        XCTAssertEqual(moment(lib, t, 0), 12, "ticked again, it keeps its first moment")
        XCTAssertTrue(lib.setChecked(false, tripId: t, entryId: first))
        XCTAssertNil(lib.trips[0].entries[0].extra[TICKED_AT_KEY], "an untick takes the moment away")
        // Bought on site is in hand, not packed: no moment.
        let bought = lib.addBoughtOnSite(tripId: t, name: "Sun hat")!
        let line = lib.trips[0].entries.first { $0.id == bought.id }!
        XCTAssertTrue(line.checked)
        XCTAssertNil(line.extra[TICKED_AT_KEY])
    }

    func testAHeadingsTickGivesItsLinesOneMomentAndUndoPutsBackWhatWasThere() {
        var lib = Library()
        let t = trip(&lib, lines: 4)
        let ids = lib.trips[0].entries.map(\.id)
        tick(&lib, t, at: [0, 30])
        // The heading unticks the first two: their moments go — Undo brings them back as they were.
        at(100)
        let off = lib.setChecked(false, tripId: t, entryIds: [ids[0], ids[1]])
        XCTAssertNil(moment(lib, t, 0))
        XCTAssertNil(moment(lib, t, 1))
        XCTAssertEqual(lib.undo(off), 2)
        XCTAssertEqual(moment(lib, t, 0), 0, "Undo did not put back the first moment")
        XCTAssertEqual(moment(lib, t, 1), 30, "Undo did not put back the second moment")
        // The heading ticks the other two: ONE moment for both — and Undo takes it again.
        at(200)
        let on = lib.setChecked(true, tripId: t, entryIds: [ids[2], ids[3]])
        XCTAssertEqual(moment(lib, t, 2), 200)
        XCTAssertEqual(moment(lib, t, 3), 200)
        XCTAssertEqual(lib.undo(on), 2)
        XCTAssertNil(moment(lib, t, 2), "Undo left the moment of a tick it took back")
        XCTAssertNil(moment(lib, t, 3))
    }

    func testAKitGetsItsMomentWhenTheLastThingInsideIsTicked() {
        var lib = ThingKitsTests.library()
        var draft = newEvent(name: "Weekend in the hills", startDate: "2026-10-17", endDate: "2026-10-20")
        draft.activities = lib.templates.filter { $0.name == "Hiking" }.map(\.id)
        let t = lib.createTrip(draft)
        let wash = t.entries.first { $0.name == "Wash bag" }!.id
        let brush = ThingKitsTests.id(lib, "Toothbrush"), soap = ThingKitsTests.id(lib, "Soap")
        func line() -> Item { lib.trips[0].entries.first { $0.id == wash }! }
        at(5)
        XCTAssertTrue(lib.setKitContentTicked(true, tripId: t.id, entryId: wash, contentId: brush))
        XCTAssertNil(line().extra[TICKED_AT_KEY], "half a kit is not packed")
        at(25)
        XCTAssertTrue(lib.setKitContentTicked(true, tripId: t.id, entryId: wash, contentId: soap))
        XCTAssertTrue(line().checked)
        XCTAssertEqual(Library.tickedAt(line()), PackingPaceTests.base + 25, "the kit packed by its last thing has no moment")
        XCTAssertTrue(lib.setKitContentTicked(false, tripId: t.id, entryId: wash, contentId: soap))
        XCTAssertNil(line().extra[TICKED_AT_KEY], "a kit no longer packed kept its moment")
    }

    // MARK: - His pace

    func testTheGapsBetweenHisTicksAreHisPaceAndALongOneIsABreak() {
        var lib = Library()
        // 26 lines, 30 s apart — but a coffee of 20 minutes after the 13th.
        let t = trip(&lib, lines: 26)
        let moments = (0..<26).map { n in Double(n) * 30 + (n >= 13 ? 1200 : 0) }
        tick(&lib, t, at: moments)
        let pace = lib.packingPace()
        XCTAssertEqual(pace.timedTicks, 24, "25 gaps, one of them a break")
        XCTAssertTrue(pace.measured)
        XCTAssertEqual(pace.secondsPerThing, 30, accuracy: 0.001)
        // A line unticked again, or set aside, is not counted (its moment is gone, or unread).
        let ids = lib.trips[0].entries.map(\.id)
        XCTAssertTrue(lib.setChecked(false, tripId: t, entryId: ids[25]))
        _ = lib.setAside(true, tripId: t, entryId: ids[24])
        XCTAssertEqual(lib.packingPace().timedTicks, 22)
    }

    func testOnePressOfManyLinesSharesItsGap() {
        var lib = Library()
        let t = trip(&lib, lines: 26)
        let ids = lib.trips[0].entries.map(\.id)
        // 21 lines ticked one by one, 60 s apart; then five by the heading, 100 s after the last.
        tick(&lib, t, at: (0..<21).map { Double($0) * 60 })
        at(20 * 60 + 100)
        XCTAssertEqual(lib.setChecked(true, tripId: t, entryIds: Array(ids[21...])).count, 5)
        let pace = lib.packingPace()
        XCTAssertEqual(pace.timedTicks, 25, "20 by hand and the heading's five")
        XCTAssertEqual(pace.secondsPerThing, 60, accuracy: 0.001)
        // The five count 20 s each: with more of them than of the rest, the median is theirs.
        var many = Library()
        let m = trip(&many, lines: 40)
        let all = many.trips[0].entries.map(\.id)
        tick(&many, m, at: (0..<11).map { Double($0) * 60 })
        at(600 + 290)
        XCTAssertEqual(many.setChecked(true, tripId: m, entryIds: Array(all[11...])).count, 29)
        XCTAssertEqual(many.packingPace().timedTicks, 39)
        XCTAssertEqual(many.packingPace().secondsPerThing, 10, accuracy: 0.001, "290 s for 29 things is 10 s each")
    }

    func testBeforeTwentyTimedTicksItIs45SecondsAndTripsAreNeverComparedWithEachOther() {
        var lib = Library()
        let t = trip(&lib, lines: 20)
        tick(&lib, t, at: (0..<20).map { Double($0) * 10 })
        var pace = lib.packingPace()
        XCTAssertEqual(pace.timedTicks, 19)
        XCTAssertFalse(pace.measured)
        XCTAssertEqual(pace.secondsPerThing, PACE_DEFAULT_SECONDS)
        // A tick on another trip a few seconds later is no gap of this one.
        let other = trip(&lib, "Swim", lines: 1)
        tick(&lib, other, at: [195])
        XCTAssertEqual(lib.packingPace().timedTicks, 19, "two trips' ticks were compared")
        // One more on the first trip: 20 timed, measured.
        lib.trips[0].entries.append(Item(id: "late", name: "Thing 21"))
        at(200)
        XCTAssertTrue(lib.setChecked(true, tripId: t, entryId: "late"))
        pace = lib.packingPace()
        XCTAssertEqual(pace.timedTicks, 20)
        XCTAssertTrue(pace.measured)
        XCTAssertEqual(pace.secondsPerThing, 10, accuracy: 0.001)
    }

    func testHisPaceIsTheMedianOfTheNewest200TimedTicks() {
        var lib = Library()
        // An old trip packed slowly (60 s a thing), a new one fast (20 s).
        let old = trip(&lib, "Old", lines: 150)
        tick(&lib, old, at: (0..<150).map { Double($0) * 60 })
        let new = trip(&lib, "New", lines: 150)
        tick(&lib, new, at: (0..<150).map { 100_000 + Double($0) * 20 })
        let pace = lib.packingPace()
        XCTAssertEqual(pace.timedTicks, PACE_RECENT_TICKS)
        // The newest 200: the new trip's 149 and 51 of the old one — the median is the new pace.
        // (All 298 would give 40, between the two.)
        XCTAssertEqual(pace.secondsPerThing, 20, accuracy: 0.001, "not the newest 200")
        XCTAssertEqual(Library.median([10, 40, 30, 20]), 25, "an even count: the mean of the two middle ones")
        XCTAssertEqual(Library.median([30, 10, 20]), 20)
    }

    // MARK: - The words

    func testTheTimeIsSaidRoundedToTheMinuteThenToFive() {
        let said: [(Double, String)] = [
            (0, "less than a minute"), (59, "less than a minute"), (60, "about 1 min"),
            (4 * 60 + 29, "about 4 min"), (9 * 60 + 29, "about 9 min"), (9 * 60 + 30, "about 10 min"),
            (12 * 60 + 29, "about 10 min"), (12 * 60 + 30, "about 15 min"), (25 * 60, "about 25 min"),
            (57 * 60 + 29, "about 55 min"), (57 * 60 + 30, "about 1 h"), (85 * 60, "about 1 h 25 min"),
            (120 * 60, "about 2 h"),
        ]
        for (seconds, words) in said {
            XCTAssertEqual(Library.aboutWords(seconds), words, "\(seconds) s")
        }
    }

    func testWhatIsLeftSaysTheThingsTheChargingAndTheTime() {
        var lib = BatteriesTests.library()
        var draft = newEvent(name: "Weekend in the hills", startDate: "2026-10-17", endDate: "2026-10-20")
        draft.activities = lib.templates.filter { $0.name == "Hiking" }.map(\.id)
        let t = lib.createTrip(draft)
        let lines = t.entries.count
        XCTAssertGreaterThan(lines, 1)
        // A week before: no To charge card yet. The rest at 45 s a thing.
        var w = lib.whatsLeft(tripId: t.id, today: "2026-10-10")!
        XCTAssertEqual(w.left, lines)
        XCTAssertEqual(w.toCharge, 0)
        XCTAssertEqual(w.words, "\(lines) left \u{00B7} \(Library.aboutWords(Double(lines) * 45))")
        // The day before: the card shows, and what is not charged is counted.
        let charge = lib.chargeCard(tripId: t.id, today: "2026-10-16")
        XCTAssertGreaterThan(charge.count, 1)
        XCTAssertTrue(lib.setCharged(true, tripId: t.id, lineId: charge[0].lineId, contentId: charge[0].contentId))
        w = lib.whatsLeft(tripId: t.id, today: "2026-10-16")!
        XCTAssertEqual(w.toCharge, charge.count - 1)
        // One ticked: one fewer left.
        XCTAssertTrue(lib.setChecked(true, tripId: t.id, entryId: t.entries.first { $0.name == "Map" }!.id))
        w = lib.whatsLeft(tripId: t.id, today: "2026-10-16")!
        XCTAssertEqual(w.left, lines - 1)
        XCTAssertEqual(w.words, "\(lines - 1) left \u{00B7} \(charge.count - 1) to charge \u{00B7} \(Library.aboutWords(Double(lines - 1) * 45))")
        // Everything packed: All packed — and what is still to charge.
        _ = lib.setAllChecked(true, tripId: t.id)
        w = lib.whatsLeft(tripId: t.id, today: "2026-10-16")!
        XCTAssertTrue(w.allPacked)
        XCTAssertEqual(w.words, "All packed \u{00B7} \(charge.count - 1) to charge")
        for row in lib.chargeCard(tripId: t.id, today: "2026-10-16") {
            XCTAssertTrue(lib.setCharged(true, tripId: t.id, lineId: row.lineId, contentId: row.contentId))
        }
        XCTAssertEqual(lib.whatsLeft(tripId: t.id, today: "2026-10-16")?.words, "All packed")
        // A trip with nothing to pack says nothing.
        for line in lib.trips[0].entries { _ = lib.setChecked(false, tripId: t.id, entryId: line.id); _ = lib.setAside(true, tripId: t.id, entryId: line.id) }
        XCTAssertNil(lib.whatsLeft(tripId: t.id, today: "2026-10-16"))
        XCTAssertNil(lib.whatsLeft(tripId: "nope", today: "2026-10-16"))
    }

    // MARK: - Kept, and not passed on

    func testTheMomentIsStoredBackedUpAndKeptByARebuildButNeverSentOrStartedAgain() throws {
        var lib = BatteriesTests.library()
        var draft = newEvent(name: "Weekend in the hills", startDate: "2026-10-17", endDate: "2026-10-20")
        draft.activities = lib.templates.filter { $0.name == "Hiking" }.map(\.id)
        let t = lib.createTrip(draft).id
        let map = lib.trips[0].entries.first { $0.name == "Map" }!.id
        at(42)
        XCTAssertTrue(lib.setChecked(true, tripId: t, entryId: map))
        func stamp(_ l: Library, _ trip: String = "") -> Double? {
            l.trips.first { $0.id == (trip.isEmpty ? t : trip) }?.entries.first { $0.name == "Map" }.flatMap(Library.tickedAt)
        }
        XCTAssertEqual(stamp(lib), PackingPaceTests.base + 42)
        // The store and iCloud: records and back.
        let stored = Library(records: lib.records())
        XCTAssertEqual(stored.trips, lib.trips)
        XCTAssertEqual(stamp(stored), PackingPaceTests.base + 42)
        // A backup, as this app writes it and the older kind.
        for data in [lib.backupData(exportedAt: "2026-10-13T09:00:00.000Z"),
                     BackupTests.olderFile(lib, exportedAt: "2026-10-13T09:00:00.000Z")] {
            let (back, report) = try BackupTests.read(data)
            XCTAssertTrue(report.isFaithful, report.mismatches.joined(separator: "; "))
            XCTAssertEqual(stamp(back), PackingPaceTests.base + 42)
        }
        // The web app's model reads a plain line: the key rides along.
        let line = lib.trips[0].entries.first { $0.id == map }!
        XCTAssertEqual(Item(json: line.json).extra[TICKED_AT_KEY], line.extra[TICKED_AT_KEY])
        // A rebuild (Trip settings → Save) and a change to the thing keep it.
        XCTAssertNotNil(lib.changeTrip(id: t) { $0.season = "Winter" })
        _ = lib.updateThing(id: BatteriesTests.id(lib, "Map")) { $0.note = "The 1:50 000 one" }
        XCTAssertEqual(stamp(lib), PackingPaceTests.base + 42, "a rebuild lost the moment")
        // Sent, or started again: his pace is his, and the new trip has nothing ticked.
        let sent = Library.justTheList(lib.trips.first { $0.id == t }!)
        XCTAssertTrue(sent.entries.allSatisfy { $0.extra[TICKED_AT_KEY] == nil }, "a shared trip carries his tick moments")
        let again = lib.startAgain(from: t, name: "Again")!
        XCTAssertTrue(again.entries.allSatisfy { $0.extra[TICKED_AT_KEY] == nil }, "a trip started again carries the old moments")
    }
}
