import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// The Packing day (spec 07 part 17, his yes of 13 Oct 2026): the stations of the Pack step.
/// Invented data only — this repository is public.
final class PackingDayTests: XCTestCase {
    override func setUp() { PackingEnv.freeze(at: "2026-10-13T12:00:00.000Z") }
    override func tearDown() { PackingEnv.reset() }

    private let carryOn = "Carry-on / hand luggage"

    /// The base template: a Passport, a Charger and a Toothbrush, in the carry-on; Hike: Boots
    /// and a Jacket in the Day pack (one of his bags), a Water bottle in no bag. The trip "Hill
    /// week" (20–24 Oct 2026) from Hike.
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

    private func line(_ lib: Library, _ name: String) -> String { lib.trips[0].entries.first { $0.name == name }!.id }
    private func day(_ lib: Library, _ trip: String) -> PackingDay { lib.packingDay(tripId: trip)! }

    // MARK: - The marks

    func testEachStationWearsHisPick() {
        // His picks of 13 Oct 2026 (the station sheet): day B, Bags out A, Pack C, Weigh A, Tags A, Photos C, Ready A.
        XCTAssertEqual(PackingDayStation.allCases.map(\.name), ["Bags out", "Pack", "Weigh", "Tags", "Photos", "Ready"])
        XCTAssertEqual(PackingDayStation.allCases.map(\.rawValue), ["bags", "pack", "weigh", "tags", "photos", "ready"])
        XCTAssertEqual(PackingDayStation.allCases.map(\.mark.key),
                       ["bagsOnFloor", "listIntoCase", "luggageScale", "tagAndAirTag", "photoPrint", "bagByDoor"])
        XCTAssertEqual(PackingDayStation.dayMark.label, "A sun rising out of an open case")
        XCTAssertTrue(PackingDayStation.pack.mark.path.hasPrefix("M4 12.5h16 M4 12.5v5.8"), "Pack is not the list into the case")
        XCTAssertTrue(PackingDayStation.photos.mark.path.contains("A1.5 1.5 -8 0 1"), "Photos is not the tilted print")
        // The Pack STATION is not the Pack STEP's suitcase with a tick.
        XCTAssertNotEqual(PackingDayStation.pack.mark.path, Library.LoopStep.pack.mark.path)
        // Only the commands the app draws, and every mark different.
        let all = PackingDayStation.allCases.map(\.mark.path) + [PackingDayStation.dayMark.path]
        XCTAssertEqual(Set(all).count, 7)
        for path in all {
            XCTAssertTrue(path.allSatisfy { !$0.isLetter || "MLHVCSQAZmlhvcsqaz".contains($0) }, path)
        }
    }

    // MARK: - The trip's bags

    func testTheDayAsksAboutTheBagsTheTripsBagsCardLists() {
        var (lib, trip) = library()
        // The card's bags, in its order, without "Not in a bag".
        XCTAssertEqual(lib.weighedBags(tripId: trip).map(\.load.container), [carryOn, "Day pack", "Other"])
        XCTAssertEqual(lib.dayBags(tripId: trip), [carryOn, "Day pack"])
        let d = day(lib, trip)
        XCTAssertEqual(d.bags.map(\.things), [3, 2])
        XCTAssertTrue(d.groupPhotoAsked, "two bags: a photo of both")
        // A bag whose every line is set aside is not asked about.
        _ = lib.setAside(true, tripId: trip, entryId: line(lib, "Boots"))
        _ = lib.setAside(true, tripId: trip, entryId: line(lib, "Jacket"))
        XCTAssertEqual(lib.dayBags(tripId: trip), [carryOn])
        // ONE bag: no photo of all of them — the bag's own is that photo.
        let one = day(lib, trip)
        XCTAssertFalse(one.groupPhotoAsked)
        XCTAssertEqual(one.counts(.photos).of, 1)
        XCTAssertEqual(one.words(.photos), "0 of 1 photo")
        XCTAssertNil(lib.packingDay(tripId: "nope"))
    }

    func testATripWithoutBagsCannotDoTheBagStationsAndIsReadyWhenPacked() {
        var lib = Library()
        var base = newList(name: "Common base", role: "base")
        base.items = [newItem(name: "Passport", container: ""), newItem(name: "Map", container: "")]
        lib.saveTemplate(base)
        let trip = lib.createTrip(newEvent(name: "Walk", startDate: "2026-10-20", endDate: "2026-10-20")).id
        XCTAssertEqual(lib.trips[0].entries.count, 2)
        var d = day(lib, trip)
        XCTAssertTrue(d.bags.isEmpty)
        for s in [PackingDayStation.bagsOut, .weigh, .tags, .photos] {
            XCTAssertFalse(d.usable(s), s.name)
            XCTAssertFalse(d.done(s), s.name)
            XCTAssertEqual(d.state(s), "no bags yet")
        }
        XCTAssertEqual(d.current, .pack)
        XCTAssertEqual(d.next(after: .pack), .ready, "no bag station is offered on a trip without bags")
        XCTAssertEqual(d.words(.ready), "0 of 1 done")
        for l in lib.trips[0].entries { _ = lib.setChecked(true, tripId: trip, entryId: l.id) }
        d = day(lib, trip)
        XCTAssertTrue(d.ready, "with no bags, Ready waits for the packing only")
        XCTAssertEqual(d.current, .ready)
        XCTAssertEqual(d.state(.ready), "done")
        XCTAssertEqual(d.words(.ready), "Ready to go")
    }

    // MARK: - Each station

    func testEachStationIsDoneWhenEveryBagHasWhatItAsks() {
        var (lib, trip) = library()
        var d = day(lib, trip)
        XCTAssertEqual(d.current, .bagsOut)
        XCTAssertEqual(PackingDayStation.allCases.map { d.state($0) },
                       ["0 of 2 out", "0 of 6 packed", "0 of 2 weighed", "0 of 2 ticked", "0 of 3 photos", "0 of 5 done"])

        // Bags out — by name, at once; the same bag is never in the list twice.
        XCTAssertTrue(lib.setBagOut(true, tripId: trip, bag: carryOn))
        XCTAssertTrue(lib.setBagOut(true, tripId: trip, bag: "carry-on / HAND luggage"))
        XCTAssertEqual(Library.dayNames(lib.trips[0], DAY_BAGS_OUT_KEY).count, 1)
        XCTAssertEqual(day(lib, trip).words(.bagsOut), "1 of 2 out")
        XCTAssertTrue(lib.setBagOut(true, tripId: trip, bag: "Day pack"))
        d = day(lib, trip)
        XCTAssertTrue(d.done(.bagsOut))
        XCTAssertEqual(d.current, .pack)
        XCTAssertTrue(lib.setBagOut(false, tripId: trip, bag: "Day pack"))
        XCTAssertFalse(day(lib, trip).done(.bagsOut))
        XCTAssertTrue(lib.setBagOut(true, tripId: trip, bag: "Day pack"))
        XCTAssertFalse(lib.setBagOut(true, tripId: trip, bag: "Other"), "no bag is no bag to lay out")
        XCTAssertFalse(lib.setBagOut(true, tripId: "nope", bag: carryOn))

        // Pack — the header's own rule: everything not set aside, ticked.
        for l in lib.trips[0].entries where l.name != "Water bottle" { _ = lib.setChecked(true, tripId: trip, entryId: l.id) }
        XCTAssertEqual(day(lib, trip).words(.pack), "5 of 6 packed")
        _ = lib.setAside(true, tripId: trip, entryId: line(lib, "Water bottle"))
        d = day(lib, trip)
        XCTAssertTrue(d.done(.pack), "set aside counts as handled")
        XCTAssertEqual(d.current, .weigh)

        // Weigh — the luggage scale's reading, the Bags card's own; the things' sum is no weighing.
        XCTAssertTrue(lib.setWeighed(tripId: trip, bag: carryOn, grams: 6400))
        XCTAssertEqual(day(lib, trip).words(.weigh), "1 of 2 weighed")
        XCTAssertTrue(lib.setWeighed(tripId: trip, bag: "Day pack", grams: 2100))
        XCTAssertTrue(day(lib, trip).done(.weigh))

        // Tags — a name tag per bag; the AirTag only for a bag that has one.
        XCTAssertTrue(lib.setNameTag(true, tripId: trip, bag: carryOn))
        XCTAssertTrue(lib.setNameTag(true, tripId: trip, bag: "Day pack"))
        XCTAssertTrue(day(lib, trip).done(.tags), "no bag has an AirTag: the name tags are all")
        XCTAssertTrue(lib.setAirTag(container: "Day pack", true))
        d = day(lib, trip)
        XCTAssertFalse(d.done(.tags), "a bag with an AirTag asks for it")
        XCTAssertEqual(d.words(.tags), "2 of 3 ticked")
        XCTAssertTrue(lib.setAirTagIn(true, tripId: trip, bag: "Day pack"))
        XCTAssertTrue(day(lib, trip).done(.tags))
        // An AirTag tick for a bag without one is not asked — and does not count.
        XCTAssertTrue(lib.setAirTagIn(true, tripId: trip, bag: carryOn))
        XCTAssertEqual(day(lib, trip).counts(.tags).of, 3)
        XCTAssertEqual(day(lib, trip).counts(.tags).done, 3)

        // Photos — each bag's own (the Bags card's), and the one of all of them.
        XCTAssertEqual(day(lib, trip).current, .photos)
        XCTAssertNotNil(lib.addBagPhoto(tripId: trip, bag: carryOn, jpeg: Data([1, 2, 3])))
        XCTAssertNotNil(lib.addBagPhoto(tripId: trip, bag: "Day pack", jpeg: Data([4, 5, 6])))
        d = day(lib, trip)
        XCTAssertFalse(d.done(.photos), "two bags and no photo of both")
        XCTAssertEqual(d.words(.photos), "2 of 3 photos")
        XCTAssertNotNil(lib.setGroupPhoto(tripId: trip, jpeg: Data([7, 8, 9])))
        d = day(lib, trip)
        XCTAssertTrue(d.done(.photos))

        // Ready — every other station green.
        XCTAssertTrue(d.ready)
        XCTAssertEqual(d.current, .ready)
        XCTAssertEqual(PackingDayStation.allCases.map { d.state($0) }, ["done", "done", "done", "done", "done", "done"])
        XCTAssertEqual(d.words(.ready), "Ready to go")
        // A line unticked: Pack and Ready are open again, and Pack is the next one.
        _ = lib.setChecked(false, tripId: trip, entryId: line(lib, "Passport"))
        d = day(lib, trip)
        XCTAssertFalse(d.ready)
        XCTAssertEqual(d.current, .pack)
        XCTAssertEqual(d.words(.ready), "4 of 5 done")
    }

    func testTheNextStationIsOfferedRoundTheRow() {
        var (lib, trip) = library()
        var d = day(lib, trip)
        XCTAssertEqual(d.next(after: .bagsOut), .pack)
        XCTAssertEqual(d.next(after: .photos), .bagsOut, "round from the start again")
        XCTAssertNil(d.next(after: .ready))
        _ = lib.setBagOut(true, tripId: trip, bag: carryOn)
        _ = lib.setBagOut(true, tripId: trip, bag: "Day pack")
        _ = lib.setWeighed(tripId: trip, bag: carryOn, grams: 5000)
        _ = lib.setWeighed(tripId: trip, bag: "Day pack", grams: 2000)
        d = day(lib, trip)
        XCTAssertEqual(d.next(after: .bagsOut), .pack, "Weigh is done: Pack, never a station done")
        XCTAssertEqual(d.next(after: .pack), .tags)
        XCTAssertEqual(d.next(after: .photos), .pack, "never the station shown, never one done")
        XCTAssertEqual(d.next(after: .tags), .photos)
    }

    // MARK: - Has an AirTag

    func testHasAnAirTagIsTheBagsOwn() {
        var (lib, trip) = library()
        let pack = lib.bags().first { $0.name == "Day pack" }!.id
        XCTAssertFalse(lib.hasAirTag(container: "Day pack"))
        XCTAssertTrue(lib.setBagAirTag(id: pack, true))
        XCTAssertTrue(lib.hasAirTag(container: "day pack"), "by its name, as the trip's lines name it")
        XCTAssertEqual(lib.items.first { $0.id == pack }?.extra[AIRTAG_KEY], .bool(true))
        XCTAssertTrue(lib.setBagAirTag(id: pack, false))
        XCTAssertNil(lib.items.first { $0.id == pack }?.extra[AIRTAG_KEY], "off is no key, never false")
        // Only a bag takes it.
        XCTAssertFalse(lib.setBagAirTag(id: lib.items.first { $0.name == "Boots" }!.id, true))
        // From the trip: a name that is no bag yet becomes one — switched on; off leaves it none.
        XCTAssertFalse(lib.bags().contains { $0.name == carryOn })
        XCTAssertTrue(lib.setAirTag(container: carryOn, false))
        XCTAssertFalse(lib.bags().contains { $0.name == carryOn }, "switched off, a name stays a name")
        XCTAssertTrue(lib.setAirTag(container: carryOn, true))
        XCTAssertTrue(lib.bags().contains { $0.name == carryOn }, "the carry-on became one of his bags")
        XCTAssertTrue(lib.hasAirTag(container: carryOn))
        XCTAssertFalse(lib.setAirTag(container: "Other", true))
        XCTAssertTrue(day(lib, trip).bags.first { $0.name == carryOn }!.hasAirTag)
    }

    // MARK: - The photo of all the bags

    func testThePhotoOfAllTheBagsIsOnePerTripKeptInUseAndGoesWithTheTrip() {
        var (lib, trip) = library()
        let first = lib.setGroupPhoto(tripId: trip, jpeg: Data([1]))!
        XCTAssertEqual(lib.groupPhoto(tripId: trip)?.id, first.id)
        XCTAssertTrue(lib.photoInUse(first.id))
        XCTAssertTrue(lib.photoIdsInUse().contains(first.id))
        PackingEnv.freeze(at: "2026-10-20T12:00:00.000Z")
        XCTAssertFalse(lib.unusedPhotos().contains { $0.id == first.id }, "Worth a look offers the photo of all the bags")
        // A new one replaces it — the old record goes.
        let second = lib.setGroupPhoto(tripId: trip, jpeg: Data([2]))!
        XCTAssertEqual(Library.groupPhotoId(lib.trips[0]), second.id)
        XCTAssertFalse(lib.photos.contains { $0.id == first.id }, "the replaced photo stayed behind")
        XCTAssertTrue(lib.removeGroupPhoto(tripId: trip))
        XCTAssertNil(lib.trips[0].extra[DAY_GROUP_PHOTO_KEY])
        XCTAssertFalse(lib.photos.contains { $0.id == second.id })
        XCTAssertFalse(lib.removeGroupPhoto(tripId: trip), "nothing to remove")
        // It goes with the trip.
        let third = lib.setGroupPhoto(tripId: trip, jpeg: Data([3]))!
        XCTAssertTrue(lib.deleteTrip(id: trip))
        XCTAssertFalse(lib.photos.contains { $0.id == third.id }, "a deleted trip left its photo of all the bags behind")
        XCTAssertNil(lib.setGroupPhoto(tripId: trip, jpeg: Data([4])))
    }

    // MARK: - Weigh opens by itself

    func testWeighOpensItselfOnceWhenEverythingIsPacked() {
        var (lib, trip) = library()
        let today = "2026-10-13"
        XCTAssertFalse(lib.weighOpensItself(tripId: trip, today: today), "nothing packed yet")
        for l in lib.trips[0].entries { _ = lib.setChecked(true, tripId: trip, entryId: l.id) }
        XCTAssertTrue(lib.weighOpensItself(tripId: trip, today: today))
        // Not once the trip has set off (On site), nor on a trip whose bags are weighed.
        XCTAssertFalse(lib.weighOpensItself(tripId: trip, today: "2026-10-21"))
        _ = lib.setWeighed(tripId: trip, bag: carryOn, grams: 5000)
        _ = lib.setWeighed(tripId: trip, bag: "Day pack", grams: 2000)
        XCTAssertFalse(lib.weighOpensItself(tripId: trip, today: today), "every bag is weighed already")
        _ = lib.setWeighed(tripId: trip, bag: "Day pack", grams: nil)
        XCTAssertTrue(lib.weighOpensItself(tripId: trip, today: today))
        // Once: the trip keeps that it was offered.
        XCTAssertTrue(lib.setWeighOffered(tripId: trip))
        XCTAssertFalse(lib.weighOpensItself(tripId: trip, today: today), "Weigh offered twice")
        XCTAssertTrue(Library.weighOffered(lib.trips[0]))
        XCTAssertFalse(lib.weighOpensItself(tripId: "nope", today: today))
    }

    // MARK: - A bag renamed, two bags made one, a bag deleted

    func testTheDaysTicksFollowABagsRenameAndAreDroppedWhenBagsBecomeOne() {
        var (lib, trip) = library()
        for bag in [carryOn, "Day pack"] {
            _ = lib.setBagOut(true, tripId: trip, bag: bag)
            _ = lib.setNameTag(true, tripId: trip, bag: bag)
        }
        _ = lib.setAirTagIn(true, tripId: trip, bag: "Day pack")
        let pack = lib.bags().first { $0.name == "Day pack" }!.id
        // Renamed: every tick goes along.
        XCTAssertTrue(lib.renameThing(id: pack, to: "Hill pack"))
        XCTAssertEqual(Set(Library.dayNames(lib.trips[0], DAY_BAGS_OUT_KEY)), [carryOn, "Hill pack"])
        XCTAssertEqual(Library.dayNames(lib.trips[0], DAY_AIRTAGS_KEY), ["Hill pack"])
        XCTAssertTrue(day(lib, trip).done(.bagsOut), "the renamed bag is no longer out")
        // Deleted, its things into the carry-on: two bags made one — the carry-on keeps its own.
        _ = lib.setNameTag(false, tripId: trip, bag: carryOn)
        XCTAssertNotNil(lib.addBag(name: carryOn), "the carry-on, one of his bags to move things into")
        XCTAssertTrue(lib.deleteBag(id: pack, moveTo: carryOn))
        XCTAssertEqual(Library.dayNames(lib.trips[0], DAY_BAGS_OUT_KEY), [carryOn])
        XCTAssertNil(lib.trips[0].extra[DAY_NAME_TAGS_KEY], "the deleted bag's name tag tagged the carry-on")
        XCTAssertNil(lib.trips[0].extra[DAY_AIRTAGS_KEY])
        // To no bag: dropped.
        var (other, trip2) = library()
        _ = other.setBagOut(true, tripId: trip2, bag: "Day pack")
        XCTAssertTrue(other.deleteBag(id: other.bags().first { $0.name == "Day pack" }!.id, moveTo: ""))
        XCTAssertNil(other.trips[0].extra[DAY_BAGS_OUT_KEY], "a bag gone to no bag is still out")
    }

    // MARK: - Kept, synced, backed up — not shared, not copied

    func testTheDayIsSyncedBackedUpAndRestoredButNeitherSharedNorCopied() {
        var (lib, trip) = library()
        _ = lib.setBagOut(true, tripId: trip, bag: carryOn)
        _ = lib.setNameTag(true, tripId: trip, bag: "Day pack")
        _ = lib.setAirTagIn(true, tripId: trip, bag: "Day pack")
        _ = lib.setAirTag(container: "Day pack", true)
        _ = lib.setWeighOffered(tripId: trip)
        let photo = lib.setGroupPhoto(tripId: trip, jpeg: Data([9, 9]))!
        let want = day(lib, trip)
        // The store's records (iCloud carries them), and a backup.
        let stored = Library(records: lib.records())
        XCTAssertEqual(stored.packingDay(tripId: trip), want, "the records lost the day")
        XCTAssertTrue(Library.weighOffered(stored.trips[0]))
        XCTAssertNotNil(stored.groupPhoto(tripId: trip))
        let restored = try! Importer.read(lib.backupData(exportedAt: "2026-10-13T12:00:00.000Z")).library
        XCTAssertEqual(restored.packingDay(tripId: trip), want, "a backup lost the day")
        XCTAssertEqual(restored.groupPhoto(tripId: trip)?.id, photo.id)
        XCTAssertTrue(restored.hasAirTag(container: "Day pack"))
        // Shared: none of it.
        let sent = Library.justTheList(lib.trips[0])
        for key in DAY_TRIP_KEYS { XCTAssertNil(sent.extra[key], "a shared trip carries \(key)") }
        // A new trip from this one starts its day afresh.
        let again = lib.startAgain(from: trip, name: "Hill week (again)")!
        for key in DAY_TRIP_KEYS { XCTAssertNil(again.extra[key], "a new trip from this one copied \(key)") }
        XCTAssertEqual(lib.packingDay(tripId: again.id)!.words(.ready), "0 of 5 done")
    }
}
