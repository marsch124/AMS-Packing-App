import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// Packing Stations (0.81, spec 07 part 17 "0.81" — his decisions of 14 Oct 2026 on 0.79's
/// Packing day): Remind me and Add a reminder write a To do on the trip; "+ Add a bag" puts one of
/// his bags, or a new one, on the trip; the trip header's colours. Invented data only — this
/// repository is public.
final class PackingStationsTests: XCTestCase {
    override func setUp() { PackingEnv.freeze(at: "2026-10-13T12:00:00.000Z") }
    override func tearDown() { PackingEnv.reset() }

    private let carryOn = "Carry-on / hand luggage"
    private let today = "2026-10-13"

    /// As PackingDayTests: the base template (Passport, Charger, Toothbrush in the carry-on), Hike
    /// (Boots and a Jacket in the Day pack — one of his bags — a Water bottle in no bag); the trip
    /// "Hill week", 20–24 Oct 2026, from Hike.
    private func library() -> (Library, String) {
        var lib = Library()
        var base = newList(name: "Common base", role: "base")
        base.items = [newItem(name: "Passport"), newItem(name: "Charger"), newItem(name: "Toothbrush")]
        lib.saveTemplate(base)
        var hike = newList(name: "Hike")
        hike.items = [newItem(name: "Boots", container: "Day pack"), newItem(name: "Jacket", container: "Day pack"),
                      newItem(name: "Water bottle", container: "")]
        lib.saveTemplate(hike)
        XCTAssertNotNil(lib.addBag(name: "Day pack"))
        let hikeId = lib.templates.first { $0.name == "Hike" }!.id
        let trip = lib.createTrip(newEvent(name: "Hill week", activities: [hikeId], startDate: "2026-10-20", endDate: "2026-10-24")).id
        return (lib, trip)
    }

    private func day(_ lib: Library, _ trip: String) -> PackingDay { lib.packingDay(tripId: trip)! }

    // MARK: - Remind me and Add a reminder: a To do on the trip

    func testRemindMeOffersWhatIsNotTickedYet() {
        var (lib, trip) = library()
        _ = lib.setAirTag(container: "Day pack", true)
        var bags = day(lib, trip).bags
        XCTAssertEqual(PackingDay.reminder(for: bags[0]), "Name tag for \(carryOn)")
        XCTAssertEqual(PackingDay.reminder(for: bags[1]), "Name tag and AirTag for Day pack")
        XCTAssertFalse(PackingDay.tagsDone(bags[1]))
        _ = lib.setNameTag(true, tripId: trip, bag: "Day pack")
        bags = day(lib, trip).bags
        XCTAssertEqual(PackingDay.reminder(for: bags[1]), "AirTag for Day pack")
        _ = lib.setAirTagIn(true, tripId: trip, bag: "Day pack")
        bags = day(lib, trip).bags
        XCTAssertTrue(PackingDay.tagsDone(bags[1]))
        XCTAssertEqual(PackingDay.reminder(for: bags[1]), "Name tag for Day pack", "all ticked: the name tag")
        // The carry-on has no AirTag: its name tag alone makes it done.
        _ = lib.setNameTag(true, tripId: trip, bag: carryOn)
        XCTAssertTrue(PackingDay.tagsDone(day(lib, trip).bags[0]))
    }

    func testAToDoWrittenOnTheTripIsDueAtOnceAndShowsInBeforeYouGo() {
        var (lib, trip) = library()
        let before = progress(lib.trips[0].entries)
        XCTAssertTrue(lib.dueReminders(tripId: trip, today: today).isEmpty)
        let line = lib.addTripTodo(tripId: trip, name: "  Name tag for Day pack ", today: today)
        XCTAssertNotNil(line)
        let kept = lib.trips[0].entries.last!
        XCTAssertEqual(kept.name, "Name tag for Day pack")
        XCTAssertTrue(Library.isReminder(kept), "not a reminder line")
        XCTAssertTrue(Library.isTripTodo(kept))
        XCTAssertTrue(kept.custom, "a rebuild would drop it")
        XCTAssertFalse(kept.checked)
        XCTAssertEqual(kept.container, "", "a To do goes in no bag")
        XCTAssertEqual(kept.category, REMINDERS_CATEGORY)
        // Its When: the latest step already due — a week ahead (the 13th, for the 20th).
        XCTAssertEqual(kept.phase, "week")
        // Due at once: in Before you go's To do, counted as left.
        XCTAssertEqual(lib.dueReminders(tripId: trip, today: today).map(\.name), ["Name tag for Day pack"])
        let card = lib.beforeYouGo(tripId: trip, today: today)
        XCTAssertEqual(card.due.map(\.name), ["Name tag for Day pack"])
        XCTAssertEqual(card.left, 1)
        // It counts on the list as any reminder does — and is no bag.
        XCTAssertEqual(progress(lib.trips[0].entries).total, before.total + 1)
        XCTAssertEqual(day(lib, trip).total, before.total + 1)
        XCTAssertEqual(lib.dayBags(tripId: trip), [carryOn, "Day pack"])
        // One open To do of a name is enough; nothing written is nothing.
        XCTAssertEqual(lib.tripTodoProblem(tripId: trip, name: "name tag for day pack"), .alreadyThere)
        XCTAssertNil(lib.addTripTodo(tripId: trip, name: "Name tag for Day pack", today: today))
        XCTAssertEqual(lib.tripTodoProblem(tripId: trip, name: "   "), .blank)
        XCTAssertNil(lib.addTripTodo(tripId: trip, name: "", today: today))
        XCTAssertNil(lib.addTripTodo(tripId: "nope", name: "Buy euros", today: today))
        // Ticked (in Before you go or on the list), it is done — and may be written again.
        XCTAssertTrue(lib.setChecked(true, tripId: trip, entryId: kept.id))
        XCTAssertTrue(lib.dueReminders(tripId: trip, today: today).isEmpty)
        XCTAssertNil(lib.tripTodoProblem(tripId: trip, name: "Name tag for Day pack"))
    }

    func testAToDoIsDueWhateverTheTripsDatesAndSortsUnderASensibleStep() {
        var (lib, trip) = library()
        // Tomorrow: the day before is due — the latest step due.
        lib.trips[0].startDate = "2026-10-14"
        XCTAssertEqual(lib.todoWhen(tripId: trip, today: today), "daybefore")
        // Today: the steps of the day itself are due — the first of them.
        lib.trips[0].startDate = today
        XCTAssertEqual(lib.todoWhen(tripId: trip, today: today), "morning")
        // Far ahead (nothing due yet), and undated: the earliest step.
        lib.trips[0].startDate = "2027-03-01"
        XCTAssertEqual(lib.todoWhen(tripId: trip, today: today), "prep")
        lib.trips[0].startDate = ""
        lib.trips[0].endDate = ""
        XCTAssertEqual(lib.todoWhen(tripId: trip, today: today), "prep")
        // Undated, a template's reminder is never due — a To do written on the trip is.
        XCTAssertNotNil(lib.addTripTodo(tripId: trip, name: "Buy euros", today: today))
        XCTAssertEqual(lib.dueReminders(tripId: trip, today: today).map(\.name), ["Buy euros"])
        XCTAssertEqual(lib.trips[0].entries.last!.phase, "prep")
    }

    func testAToDoIsSyncedAndBackedUpButNeitherSharedNorCopiedAsDueAtOnce() {
        var (lib, trip) = library()
        _ = lib.addTripTodo(tripId: trip, name: "AirTag for Day pack", today: today)
        let stored = Library(records: lib.records())
        XCTAssertEqual(stored.dueReminders(tripId: trip, today: today).map(\.name), ["AirTag for Day pack"], "the records lost it")
        let restored = try! Importer.read(lib.backupData(exportedAt: "2026-10-13T12:00:00.000Z")).library
        XCTAssertTrue(Library.isTripTodo(restored.trips[0].entries.last!), "a backup lost the mark")
        // Shared: the line goes, as a plain reminder.
        let sent = Library.justTheList(lib.trips[0])
        XCTAssertEqual(sent.entries.last!.name, "AirTag for Day pack")
        XCTAssertNil(sent.entries.last!.extra[TRIP_TODO_KEY], "a shared trip carries his To do as due at once")
        // A new trip from this one: the reminder comes along, due by its When like any other.
        let again = lib.startAgain(from: trip, name: "Hill week (again)")!
        let copied = again.entries.first { $0.name == "AirTag for Day pack" }
        XCTAssertNotNil(copied)
        XCTAssertNil(copied?.extra[TRIP_TODO_KEY], "copied as due at once")
    }

    // MARK: - "+ Add a bag"

    func testAddABagPutsOneOfHisBagsOnTheTripAndEveryStationAsksAboutIt() {
        var (lib, trip) = library()
        XCTAssertNotNil(lib.addBag(name: "Duffel"))
        // Offered: his bags not on the trip — the Day pack is.
        XCTAssertEqual(lib.bagsToAdd(tripId: trip).map(\.name), ["Duffel"])
        XCTAssertTrue(lib.addBagToTrip(tripId: trip, bag: "Duffel"))
        XCTAssertEqual(lib.dayBags(tripId: trip), [carryOn, "Day pack", "Duffel"])
        XCTAssertTrue(lib.bagsToAdd(tripId: trip).isEmpty)
        // The Bags card lists it last, empty, added.
        let rows = lib.weighedBags(tripId: trip)
        XCTAssertEqual(rows.map(\.load.container), [carryOn, "Day pack", "Other", "Duffel"])
        XCTAssertEqual(rows.last!.load.items, 0)
        XCTAssertTrue(rows.last!.added)
        XCTAssertFalse(rows[0].added)
        // Every station asks about it.
        let d = day(lib, trip)
        XCTAssertEqual(d.bags.map(\.name), [carryOn, "Day pack", "Duffel"])
        XCTAssertEqual(d.bags.last!.things, 0)
        XCTAssertEqual(d.words(.bagsOut), "0 of 3 out")
        XCTAssertEqual(d.words(.weigh), "0 of 3 weighed")
        XCTAssertEqual(d.words(.tags), "0 of 3 ticked")
        XCTAssertEqual(d.words(.photos), "0 of 4 photos")
        _ = lib.setWeighed(tripId: trip, bag: "Duffel", grams: 1800)
        XCTAssertEqual(lib.weighedBags(tripId: trip).last!.scaleGrams, 1800)
        XCTAssertEqual(day(lib, trip).words(.weigh), "1 of 3 weighed")
        // Never twice, never "Other", never a bag the lines already pack into.
        XCTAssertFalse(lib.addBagToTrip(tripId: trip, bag: "duffel"))
        XCTAssertFalse(lib.addBagToTrip(tripId: trip, bag: "Other"))
        XCTAssertFalse(lib.addBagToTrip(tripId: trip, bag: "  "))
        XCTAssertFalse(lib.addBagToTrip(tripId: trip, bag: carryOn))
        XCTAssertFalse(lib.addBagToTrip(tripId: "nope", bag: "Duffel"))
        XCTAssertEqual(Library.addedBags(lib.trips[0]), ["Duffel"])
        // Something packed into it: still ONE bag, now with a thing.
        let water = lib.trips[0].entries.firstIndex { $0.name == "Water bottle" }!
        lib.trips[0].entries[water].container = "Duffel"
        XCTAssertEqual(lib.dayBags(tripId: trip), [carryOn, "Day pack", "Duffel"])
        XCTAssertEqual(day(lib, trip).bags.last!.things, 1)
        XCTAssertTrue(lib.weighedBags(tripId: trip).last!.added)
        lib.trips[0].entries[water].container = ""
        // Taken off again: off the trip; a bag the lines put there cannot be "taken off".
        XCTAssertTrue(lib.removeAddedBag(tripId: trip, bag: "Duffel"))
        XCTAssertEqual(lib.dayBags(tripId: trip), [carryOn, "Day pack"])
        XCTAssertNil(lib.trips[0].extra[DAY_ADDED_BAGS_KEY], "an empty list is kept")
        XCTAssertFalse(lib.removeAddedBag(tripId: trip, bag: "Day pack"))
        XCTAssertEqual(lib.bagsToAdd(tripId: trip).map(\.name), ["Duffel"])
    }

    func testANewBagIsMadeHisAndPutOnTheTrip() {
        var (lib, trip) = library()
        XCTAssertNotNil(lib.addBag(name: "Weekend bag"))
        XCTAssertEqual(lib.newTripBagProblem(tripId: trip, name: " "), .blank)
        XCTAssertEqual(lib.newTripBagProblem(tripId: trip, name: "other"), .notABag)
        XCTAssertEqual(lib.newTripBagProblem(tripId: trip, name: "day PACK"), .onTheTrip("Day pack"))
        XCTAssertEqual(lib.newTripBagProblem(tripId: trip, name: "carry-on / HAND luggage"), .onTheTrip(carryOn))
        XCTAssertEqual(lib.newTripBagProblem(tripId: trip, name: "weekend bag"), .yours("Weekend bag"))
        XCTAssertNil(lib.addNewBagToTrip(tripId: trip, name: "weekend bag", cabin: nil, maxKg: nil))
        // A cabin bag by its name, with a max.
        XCTAssertTrue(Library.cabinByItsName("Cabin roller"))
        let roller = lib.addNewBagToTrip(tripId: trip, name: " Cabin roller ", cabin: nil, maxKg: 8)
        XCTAssertEqual(roller?.name, "Cabin roller")
        XCTAssertTrue(lib.bags().contains { $0.name == "Cabin roller" }, "not one of his bags (Care → Bags)")
        XCTAssertNil(roller?.extra[CABIN_KEY], "no word given: the name decides")
        XCTAssertTrue(lib.isCabin(container: "Cabin roller"))
        XCTAssertEqual(lib.weighedBags(tripId: trip).last!.load.limitKg, 8)
        // Said NOT to go in the cabin, and no max.
        let duffel = lib.addNewBagToTrip(tripId: trip, name: "Big duffel", cabin: false, maxKg: nil)!
        XCTAssertEqual(duffel.extra[CABIN_KEY]?.boolValue, false)
        XCTAssertFalse(lib.isCabin(container: "Big duffel"))
        XCTAssertEqual(lib.weighedBags(tripId: trip).last!.load.limitKg, 0)
        // Said to go in the cabin; a max of 0 is none.
        let hold = lib.addNewBagToTrip(tripId: trip, name: "Sling", cabin: true, maxKg: 0)!
        XCTAssertTrue(Library.isCabinBag(hold))
        XCTAssertEqual(lib.dayBags(tripId: trip), [carryOn, "Day pack", "Cabin roller", "Big duffel", "Sling"])
        XCTAssertNil(lib.addNewBagToTrip(tripId: "nope", name: "Tote", cabin: nil, maxKg: nil))
    }

    func testAnAddedBagFollowsARenameAndIsNeitherSharedNorCopied() {
        var (lib, trip) = library()
        let duffel = lib.addBag(name: "Duffel")!
        XCTAssertTrue(lib.addBagToTrip(tripId: trip, bag: "Duffel"))
        _ = lib.setBagOut(true, tripId: trip, bag: "Duffel")
        // Renamed: it stays on the trip under its new name, laid out.
        XCTAssertTrue(lib.renameThing(id: duffel.id, to: "Holdall"))
        XCTAssertEqual(Library.addedBags(lib.trips[0]), ["Holdall"])
        XCTAssertEqual(lib.dayBags(tripId: trip), [carryOn, "Day pack", "Holdall"])
        XCTAssertTrue(day(lib, trip).bags.last!.out)
        // Synced and backed up.
        let want = day(lib, trip)
        XCTAssertEqual(Library(records: lib.records()).packingDay(tripId: trip), want, "the records lost the added bag")
        let restored = try! Importer.read(lib.backupData(exportedAt: "2026-10-13T12:00:00.000Z")).library
        XCTAssertEqual(restored.packingDay(tripId: trip), want, "a backup lost the added bag")
        // Not shared, not copied.
        XCTAssertNil(Library.justTheList(lib.trips[0]).extra[DAY_ADDED_BAGS_KEY])
        let again = lib.startAgain(from: trip, name: "Hill week (again)")!
        XCTAssertNil(again.extra[DAY_ADDED_BAGS_KEY])
        XCTAssertEqual(lib.dayBags(tripId: again.id), [carryOn, "Day pack"])
        // Deleted with "No bag": off the trip.
        XCTAssertTrue(lib.deleteBag(id: duffel.id, moveTo: ""))
        XCTAssertNil(lib.trips[0].extra[DAY_ADDED_BAGS_KEY], "a deleted bag is still on the trip")
    }

    // MARK: - The trip header's colours

    func testTheHeaderButtonsWearTheirOwnColoursAndReadDayAndNight() {
        // His pick (variant A): Review in the Templates violet, Take a break in coffee amber, Done green.
        XCTAssertEqual(TripHeaderTone.review.ring.day, "#7c5cd6")
        XCTAssertEqual(TripHeaderTone.done.ring.day, "#2f9e63")
        XCTAssertTrue(TripHeaderTone.done.filled)
        XCTAssertFalse(TripHeaderTone.review.filled || TripHeaderTone.takeABreak.filled)
        let rings = TripHeaderTone.allCases.map(\.ring.day) + TripHeaderTone.allCases.map(\.ring.night)
        XCTAssertEqual(Set(TripHeaderTone.allCases.map(\.ring.day)).count, 3, "two header buttons share a colour")
        XCTAssertEqual(rings.count, 6)
        // Amber: warm — more red than green, more green than blue — and neither the violet nor the green.
        for hex in [TripHeaderTone.takeABreak.ring.day, TripHeaderTone.takeABreak.ring.night] {
            let v = UInt32(hex.dropFirst(), radix: 16)!
            let (r, g, b) = ((v >> 16) & 0xff, (v >> 8) & 0xff, v & 0xff)
            XCTAssertTrue(r > g && g > b, "\(hex) is not an amber")
        }
        // Every outlined button's words read at 4.5 : 1 on its own 10 % fill — on the page and on a
        // card, by day and by night; Done's white words on its green, 3 : 1 (bold, as before).
        let surfaces = [("day page", "#f4f6f7", false), ("day card", "#ffffff", false),
                        ("night page", "#0e1416", true), ("night card", "#161f22", true)]
        for tone in TripHeaderTone.allCases {
            for (name, base, night) in surfaces {
                let ring = night ? tone.ring.night : tone.ring.day
                let words = night ? tone.words.night : tone.words.day
                let fill = tone.filled ? ring : blendHex(ring, over: base, opacity: 0.10)
                let ratio = contrastRatio(words, fill)
                XCTAssertGreaterThanOrEqual(ratio, tone.filled ? 3.0 : 4.5, "\(tone) on the \(name): \(ratio)")
            }
        }
    }
}
