import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// Take a break, and messages when a trip moves on (spec 07 part 16, his yes of 13 Oct 2026).
/// Invented data only — this repository is public.
final class TakeABreakTests: XCTestCase {
    override func setUp() { PackingEnv.freeze(at: "2026-10-13T12:00:00.000Z") }
    override func tearDown() { PackingEnv.reset() }

    /// The base template: a Passport, a Charger and a Toothbrush; Bike: a Helmet and a Pump;
    /// Golf: Clubs, Balls and Tees — and on Bike a reminder, "Book the bike rack", at
    /// Preparations. The trip "Sun week" (14–20 Oct 2026, to Seaside) from Bike and Golf.
    private func library() -> (Library, String) {
        var lib = Library()
        var base = newList(name: "Common base", role: "base")
        base.items = [newItem(name: "Passport"), newItem(name: "Charger"), newItem(name: "Toothbrush")]
        lib.saveTemplate(base)
        var bike = newList(name: "Bike")
        bike.items = [newItem(name: "Helmet"), newItem(name: "Pump")]
        lib.saveTemplate(bike)
        var golf = newList(name: "Golf")
        golf.items = [newItem(name: "Clubs"), newItem(name: "Balls"), newItem(name: "Tees")]
        lib.saveTemplate(golf)
        let bikeId = lib.templates.first { $0.name == "Bike" }!.id
        let golfId = lib.templates.first { $0.name == "Golf" }!.id
        XCTAssertNotNil(lib.addReminder(templateId: bikeId, name: "Book the bike rack", when: "prep"))
        let trip = lib.createTrip(newEvent(name: "Sun week", activities: [bikeId, golfId],
                                           startDate: "2026-10-14", endDate: "2026-10-20", destination: "Seaside")).id
        return (lib, trip)
    }

    private func line(_ lib: Library, _ name: String) -> String { lib.trips[0].entries.first { $0.name == name }!.id }
    private func tick(_ lib: inout Library, _ trip: String, _ names: String...) {
        for n in names { XCTAssertTrue(lib.setChecked(true, tripId: trip, entryId: line(lib, n))) }
    }

    // MARK: - The overview

    func testTheOverviewSaysHowFarHeHasComeInTheTripsOwnSorting() {
        var (lib, trip) = library()
        XCTAssertEqual(lib.trips[0].entries.count, 9, "the trip's lines: 3 base, 2 bike, 3 golf, 1 reminder")
        tick(&lib, trip, "Helmet", "Pump", "Passport", "Clubs")
        _ = lib.setAside(true, tripId: trip, entryId: line(lib, "Tees"))
        let o = lib.breakOverview(tripId: trip, sorting: "template", today: "2026-10-13")!
        // The trip header's own numbers: every line not set aside, the reminder too.
        XCTAssertEqual(o.packedWords, "4 of 8 packed")
        XCTAssertEqual(o.left, 4)
        XCTAssertEqual(o.leftWords, "4 things left")
        // Per template, as the trip shows it sorted by Template — the reminder is Bike's.
        XCTAssertEqual(o.groupWords, "Common base 2 left \u{00B7} Bike 1 left \u{00B7} Golf 1 left")
        tick(&lib, trip, "Book the bike rack")
        XCTAssertEqual(lib.breakOverview(tripId: trip, sorting: "template", today: "2026-10-13")!.groupWords,
                       "Common base 2 left \u{00B7} Bike \u{2713} \u{00B7} Golf 1 left")
        // The reminder, and To do: "1 left" until ticked, then "all done".
        XCTAssertEqual(o.todoWords, "To do: 1 left")
        XCTAssertEqual(lib.breakOverview(tripId: trip, sorting: "template", today: "2026-10-13")!.todoWords, "To do: all done")
        // Sorted by Into, the reminder stands under "To do" (no bag), the things under their bag.
        let into = lib.breakOverview(tripId: trip, sorting: "container", today: "2026-10-13")!
        XCTAssertEqual(into.groups.map(\.label), ["Carry-on / hand luggage", "To do"], into.groupWords)
        XCTAssertEqual(into.groups.first { $0.label == "To do" }?.left, 0)
        // Sorted by When: the web app's groups, the counts the headings have.
        let when = lib.breakOverview(tripId: trip, sorting: "when", today: "2026-10-13")!
        XCTAssertEqual(when.groups.reduce(0) { $0 + $1.lines }, 8, when.groupWords)
        XCTAssertEqual(when.groups.first { $0.label == "Preparations" }?.words, "Preparations \u{2713}")
        // A group whose every line is set aside is not named; nothing set aside — every group is.
        XCTAssertFalse(when.groupWords.isEmpty)
        // No battery on the trip: no To charge words. No such trip: nil.
        XCTAssertEqual(o.chargeWords, "")
        XCTAssertNil(lib.breakOverview(tripId: "nope", sorting: "when", today: "2026-10-13"))
    }

    func testToChargeIsCountedAsTheTripsCardShowsIt() {
        var (lib, trip) = library()
        XCTAssertTrue(lib.setThingBattery(id: lib.items.first { $0.name == "Charger" }!.id, true))
        XCTAssertTrue(lib.setThingBattery(id: lib.items.first { $0.name == "Pump" }!.id, true))
        // The card shows from the day before the trip: so does the overview's line.
        XCTAssertEqual(lib.breakOverview(tripId: trip, sorting: "when", today: "2026-10-12")!.chargeWords, "")
        XCTAssertEqual(lib.breakOverview(tripId: trip, sorting: "when", today: "2026-10-13")!.chargeWords, "To charge: 2 left")
        XCTAssertTrue(lib.setCharged(true, tripId: trip, lineId: line(lib, "Pump")))
        XCTAssertEqual(lib.breakOverview(tripId: trip, sorting: "when", today: "2026-10-13")!.chargeWords, "To charge: 1 left")
        XCTAssertTrue(lib.setCharged(true, tripId: trip, lineId: line(lib, "Charger")))
        XCTAssertEqual(lib.breakOverview(tripId: trip, sorting: "when", today: "2026-10-13")!.chargeWords, "To charge: all charged")
    }

    // MARK: - The choices

    func testTheChoicesAreAnHourThisEveningOrTomorrow() {
        XCTAssertEqual(Library.breakMoment(.hour, now: "2026-10-13 14:20"), "2026-10-13 15:20")
        XCTAssertEqual(Library.breakMoment(.hour, now: "2026-10-13 23:40"), "2026-10-14 00:40", "an hour over midnight")
        XCTAssertEqual(Library.breakMoment(.evening, now: "2026-10-13 14:20"), "2026-10-13 19:00")
        XCTAssertEqual(Library.breakMoment(.evening, now: "2026-10-13 18:30"), "2026-10-13 19:00", "half an hour ahead is offered")
        XCTAssertNil(Library.breakMoment(.evening, now: "2026-10-13 18:31"), "less than half an hour: In an hour says it")
        XCTAssertNil(Library.breakMoment(.evening, now: "2026-10-13 21:00"))
        XCTAssertEqual(Library.breakMoment(.tomorrow, now: "2026-10-13 14:20"), "2026-10-14 18:00")
        XCTAssertEqual(Library.breakMoment(.tomorrow, now: "2026-10-31 14:20", tomorrowAt: "7:45"), "2026-11-01 07:45")
        XCTAssertNil(Library.breakMoment(.tomorrow, now: "2026-10-13 14:20", tomorrowAt: "later"))
        XCTAssertNil(Library.breakMoment(.pause, now: "2026-10-13 14:20"), "Just pause has no reminder")
        XCTAssertEqual(Library.cleanMoment("2026-10-13 9:05"), "2026-10-13 09:05")
        XCTAssertNil(Library.cleanMoment("tonight"))
    }

    // MARK: - The break on the trip

    func testABreakIsKeptOnTheTripReplacedAndTakenAway() {
        var (lib, trip) = library()
        XCTAssertEqual(Library.breakUntil(lib.trips[0]), "")
        XCTAssertTrue(lib.setBreak(until: "2026-10-13 19:00", tripId: trip))
        XCTAssertEqual(Library.breakUntil(lib.trips[0]), "2026-10-13 19:00")
        // A new choice replaces it: one break per trip.
        XCTAssertTrue(lib.setBreak(until: "2026-10-13 21:00", tripId: trip))
        XCTAssertEqual(lib.tripMessages(now: "2026-10-13 14:00", movesOn: false).map(\.moment), ["2026-10-13 21:00"])
        XCTAssertFalse(lib.setBreak(until: "soon", tripId: trip), "a moment that is not one was kept")
        // In the stored records (synced: a break taken on the Mac reminds him on the iPhone) and a backup.
        XCTAssertEqual(Library.breakUntil(Library(records: lib.records()).trips[0]), "2026-10-13 21:00")
        let restored = try! Importer.read(lib.backupData(exportedAt: "2026-10-13T12:00:00.000Z")).library
        XCTAssertEqual(Library.breakUntil(restored.trips[0]), "2026-10-13 21:00", "a backup lost the break")
        // His own: a shared trip goes without it (their phone must not call them back to packing),
        // and a trip started again from this one has none.
        XCTAssertNil(Library.justTheList(lib.trips[0]).extra[BREAK_UNTIL_KEY], "a shared trip carries his break")
        XCTAssertEqual(Library.breakUntil(lib.startAgain(from: trip, name: "Sun week again")!), "")
        XCTAssertEqual(Library.breakUntil(lib.trips[0]), "2026-10-13 21:00", "sharing took his own break away")
        // Just pause: taken away, no key left.
        XCTAssertTrue(lib.setBreak(until: nil, tripId: trip))
        XCTAssertNil(lib.trips[0].extra[BREAK_UNTIL_KEY], "Just pause left a key")
        XCTAssertTrue(lib.tripMessages(now: "2026-10-13 14:00", movesOn: false).isEmpty)
        XCTAssertFalse(lib.setBreak(until: nil, tripId: "nope"))
    }

    func testABreakPastItsTimeOrAfterHeLeavesIsRefused() {
        var (lib, trip) = library()
        XCTAssertNil(lib.breakRefusal(tripId: trip, until: "2026-10-13 19:00", now: "2026-10-13 14:00"))
        XCTAssertEqual(lib.breakRefusal(tripId: trip, until: "2026-10-13 13:00", now: "2026-10-13 14:00"),
                       "That time has passed \u{2014} pick a later one.")
        // The trip sets off on the 14th: with no time he leaves, from the start of that day.
        XCTAssertEqual(lib.breakRefusal(tripId: trip, until: "2026-10-14 18:00", now: "2026-10-13 14:00"),
                       "You leave before then \u{2014} pick an earlier time.")
        // Leaving at 10:00: 09:59 may be, 10:00 is too late.
        XCTAssertTrue(lib.setLeaveTime("10:00", home: false, tripId: trip))
        XCTAssertNil(lib.breakRefusal(tripId: trip, until: "2026-10-14 09:59", now: "2026-10-13 14:00"))
        XCTAssertNotNil(lib.breakRefusal(tripId: trip, until: "2026-10-14 10:00", now: "2026-10-13 14:00"))
        for n in ["Passport", "Charger", "Toothbrush", "Helmet", "Pump", "Clubs", "Balls", "Tees", "Book the bike rack"] {
            tick(&lib, trip, n)
        }
        XCTAssertEqual(lib.breakRefusal(tripId: trip, until: "2026-10-13 19:00", now: "2026-10-13 14:00"), "Everything is packed.")
    }

    func testTheBreakSaysWhatIsLeftAndGoesWhenEverythingIsPacked() {
        var (lib, trip) = library()
        tick(&lib, trip, "Passport", "Helmet")
        XCTAssertTrue(lib.setBreak(until: "2026-10-13 19:00", tripId: trip))
        let m = lib.tripMessages(now: "2026-10-13 14:00", movesOn: false)
        XCTAssertEqual(m.count, 1)
        XCTAssertEqual(m.first?.id, "break-\(trip)")
        XCTAssertEqual(m.first?.kind, .breakOver)
        XCTAssertEqual(m.first?.day, "2026-10-13")
        XCTAssertEqual(m.first?.time, "19:00")
        XCTAssertEqual(m.first?.title, "\u{1F392} Back to packing Sun week", "the reminder does not start with the backpack (0.84)")
        XCTAssertEqual(m.first?.body, "7 things left")
        // The count is the one at the last change.
        tick(&lib, trip, "Pump", "Clubs", "Balls", "Tees", "Toothbrush", "Charger")
        XCTAssertEqual(lib.tripMessages(now: "2026-10-13 14:00", movesOn: false).first?.body, "1 thing left")
        // Its moment past: none.
        XCTAssertTrue(lib.tripMessages(now: "2026-10-13 19:00", movesOn: false).isEmpty)
        // The last thing ticked: none — nothing to come back to.
        tick(&lib, trip, "Book the bike rack")
        XCTAssertTrue(lib.tripMessages(now: "2026-10-13 14:00", movesOn: false).isEmpty, "a break with nothing left")
        // Reviewed or deleted: none.
        _ = lib.setChecked(false, tripId: trip, entryId: line(lib, "Pump"))
        XCTAssertEqual(lib.tripMessages(now: "2026-10-13 14:00", movesOn: false).count, 1)
        lib.trips[0].reviewedAt = "2026-10-13T12:00:00.000Z"
        XCTAssertTrue(lib.tripMessages(now: "2026-10-13 14:00", movesOn: false).isEmpty)
        lib.trips[0].reviewedAt = ""
        _ = lib.deleteTrip(id: trip)
        XCTAssertTrue(lib.tripMessages(now: "2026-10-13 14:00", movesOn: false).isEmpty)
    }

    // MARK: - Messages when a trip moves on

    func testATripSaysWhenItSetsOffAndWhenToReviewIt() {
        var (lib, trip) = library()
        var m = lib.tripMessages(now: "2026-10-13 14:00", movesOn: true)
        XCTAssertEqual(m.map(\.id), ["moves-onsite-\(trip)", "moves-review-\(trip)"])
        // Pack → On site: no time he leaves, the first day at 08:00.
        XCTAssertEqual(m[0].moment, "2026-10-14 08:00")
        XCTAssertEqual(m[0].kind, .setOff)
        XCTAssertEqual(m[0].title, "Have a good trip \u{2014} Sun week")
        XCTAssertEqual(m[0].body, "The trip is On site now: what you buy, use up or want to fix goes there.")
        // On site → Review: the day after the last, at 10:00.
        XCTAssertEqual(m[1].moment, "2026-10-21 10:00")
        XCTAssertEqual(m[1].kind, .home)
        XCTAssertEqual(m[1].title, "Welcome home \u{2014} review Sun week in two minutes?")
        XCTAssertEqual(m[1].body, "What did you use, what did you miss? The next list learns from it.")
        // A time he leaves moves it there (a new time, a new plan); taken away, back to 08:00.
        XCTAssertTrue(lib.setLeaveTime("06:30", home: false, tripId: trip))
        XCTAssertEqual(lib.tripMessages(now: "2026-10-13 14:00", movesOn: true).first?.moment, "2026-10-14 06:30")
        XCTAssertTrue(lib.setLeaveTime("", home: false, tripId: trip))
        // New dates: the messages follow.
        lib.trips[0].startDate = "2026-10-15"; lib.trips[0].endDate = "2026-10-16"
        XCTAssertEqual(lib.tripMessages(now: "2026-10-13 14:00", movesOn: true).map(\.moment), ["2026-10-15 08:00", "2026-10-17 10:00"])
        // Once set off, only the review is left; after its moment, nothing.
        m = lib.tripMessages(now: "2026-10-15 08:00", movesOn: true)
        XCTAssertEqual(m.map(\.kind), [.home], "the set-off message after he set off")
        XCTAssertTrue(lib.tripMessages(now: "2026-10-17 10:00", movesOn: true).isEmpty)
        // Already On site by a thing bought there: no set-off message.
        XCTAssertNotNil(lib.addBoughtOnSite(tripId: trip, name: "Sun hat"))
        XCTAssertEqual(lib.tripMessages(now: "2026-10-13 14:00", movesOn: true).map(\.kind), [.home])
        // The switch off: none of these (a break still comes).
        XCTAssertTrue(lib.tripMessages(now: "2026-10-13 14:00", movesOn: false).isEmpty)
        // Reviewed early: none. Deleted: none.
        lib.trips[0].reviewedAt = "2026-10-16T18:00:00.000Z"
        XCTAssertTrue(lib.tripMessages(now: "2026-10-13 14:00", movesOn: true).isEmpty, "a reviewed trip is asked to be reviewed")
        lib.trips[0].reviewedAt = ""
        _ = lib.deleteTrip(id: trip)
        XCTAssertTrue(lib.tripMessages(now: "2026-10-13 14:00", movesOn: true).isEmpty)
    }

    func testATripWithoutDatesOrLinesSaysNothing() {
        var (lib, trip) = library()
        lib.trips[0].startDate = ""; lib.trips[0].endDate = ""
        XCTAssertTrue(lib.tripMessages(now: "2026-10-13 14:00", movesOn: true).isEmpty, "an undated trip")
        lib.trips[0].startDate = "2026-10-14"; lib.trips[0].endDate = ""
        // A one-day trip: its review the next morning.
        XCTAssertEqual(lib.tripMessages(now: "2026-10-13 14:00", movesOn: true).map(\.moment), ["2026-10-14 08:00", "2026-10-15 10:00"])
        lib.trips[0].entries = []
        XCTAssertTrue(lib.tripMessages(now: "2026-10-13 14:00", movesOn: true).isEmpty, "a trip with no lines is still at Plan")
        _ = trip
    }

    func testOnlyTheSixSoonestMovesOnMessagesWaitButEveryBreakDoes() {
        var (lib, _) = library()
        let first = lib.trips[0]
        for n in 1...5 {
            var t = first
            t.id = "t\(n)"
            t.name = "Trip \(n)"
            t.startDate = addDays("2026-10-20", n * 10); t.endDate = addDays("2026-10-20", n * 10 + 2)
            lib.trips.append(t)
        }
        _ = lib.setBreak(until: "2026-10-13 19:00", tripId: "t5")
        let m = lib.tripMessages(now: "2026-10-13 14:00", movesOn: true)
        XCTAssertEqual(m.filter { $0.kind != .breakOver }.count, MOVES_ON_LIMIT)
        XCTAssertEqual(m.first?.id, "break-t5", "the break of the trip furthest ahead was dropped")
        XCTAssertEqual(m.map(\.moment), m.map(\.moment).sorted(), "not soonest first")
        XCTAssertEqual(m.last?.moment, "2026-11-12 10:00", "not the soonest six")
    }

    // MARK: - In the calendar

    func testTheBreakGoesInTheCalendarAsAFile() {
        var (lib, trip) = library()
        XCTAssertNil(lib.breakCalendarFile(tripId: trip), "a calendar entry with no break")
        tick(&lib, trip, "Passport")
        lib.trips[0].name = "Sun week, Seaside; 2"
        XCTAssertTrue(lib.setBreak(until: "2026-10-13 23:45", tripId: trip))
        let e = lib.breakEvent(tripId: trip)!
        XCTAssertEqual(e.title, "\u{1F392} Back to packing Sun week, Seaside; 2")
        XCTAssertEqual(e.notes, "1 of 9 packed \u{00B7} 8 things left")
        XCTAssertEqual(e.start, "2026-10-13 23:45")
        XCTAssertEqual(e.end, "2026-10-14 00:15", "half an hour, over midnight")
        let file = lib.breakCalendarFile(tripId: trip)!
        XCTAssertEqual(file, [
            "BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//AMS Packing//Take a break//EN", "CALSCALE:GREGORIAN",
            "BEGIN:VEVENT", "UID:break-\(trip)-20261013T234500@ams-packing", "DTSTAMP:20261013T120000Z",
            "DTSTART:20261013T234500", "DTEND:20261014T001500",
            "SUMMARY:\u{1F392} Back to packing Sun week\\, Seaside\\; 2",
            "DESCRIPTION:1 of 9 packed \u{00B7} 8 things left",
            "BEGIN:VALARM", "ACTION:DISPLAY", "DESCRIPTION:\u{1F392} Back to packing Sun week\\, Seaside\\; 2", "TRIGGER:PT0M", "END:VALARM",
            "END:VEVENT", "END:VCALENDAR",
        ].joined(separator: "\r\n") + "\r\n")
    }
}
