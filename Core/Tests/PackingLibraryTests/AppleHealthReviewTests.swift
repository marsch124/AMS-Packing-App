import XCTest
import PackingCore
@testable import PackingLibrary

/// Apple Health fills in the review (0.70, chapter 07 part 7): the workout → template table,
/// the contexts Apple Health gives, the template's own "Counts as", and what "Use these"
/// marks — with INVENTED workouts and invented things only (no Apple Health in a test, and
/// this repository is public).
final class AppleHealthReviewTests: XCTestCase {
    override func setUp() { PackingEnv.freeze() }
    override func tearDown() { PackingEnv.reset() }

    // MARK: Invented workouts

    private func swim(_ day: String, _ location: Int? = SwimmingLocation.pool) -> HealthWorkout {
        HealthWorkout(activityType: HealthActivity.swimming, day: day, swimmingLocation: location)
    }
    private func run(_ day: String, indoor: Bool? = false) -> HealthWorkout {
        HealthWorkout(activityType: HealthActivity.running, day: day, indoor: indoor)
    }
    private func ride(_ day: String, indoor: Bool? = false) -> HealthWorkout {
        HealthWorkout(activityType: HealthActivity.cycling, day: day, indoor: indoor)
    }

    // MARK: An invented library: a base, three workouts and a holiday template

    private struct Camp {
        var lib: Library
        var trip: String
        var swim: String, run: String, bike: String, travel: String, base: String
        /// A line's id by the thing's name.
        func line(_ name: String) -> String { lib.trips.first { $0.id == trip }!.entries.first { $0.name == name }!.id }
    }

    /// Common base: Passport, Towel. Swim: Goggles, Swim cap, Towel (also on the base),
    /// Wetsuit (Outdoor), Pool buoy (Indoor). Run: Trail shoes (Outdoor), Treadmill towel
    /// (Indoor), Running cap (someone else's), Race belt (Race), Race flats (Outdoor, Race),
    /// Gel belt (also on Bike). Bike: Bike helmet, Gel belt. Travel (a holiday template):
    /// Guidebook. Kim is on most things, Robin on the running cap. A trip of all four,
    /// 10–14 Aug 2026.
    private func camp(mode: String = "trip") -> Camp {
        var lib = Library()
        lib.saveTemplate(newList(name: "Common base", role: "base", items: [newItem(name: "Passport"), newItem(name: "Towel")]))
        lib.saveTemplate(newList(name: "Swim", group: "WET", items: [
            newItem(name: "Goggles"), newItem(name: "Swim cap"), newItem(name: "Towel"),
            newItem(name: "Wetsuit", contexts: ["Outdoor"]), newItem(name: "Pool buoy", contexts: ["Indoor"]),
        ]))
        lib.saveTemplate(newList(name: "Run", group: "WET", items: [
            newItem(name: "Trail shoes", contexts: ["Outdoor"]), newItem(name: "Treadmill towel", contexts: ["Indoor"]),
            newItem(name: "Running cap"), newItem(name: "Race belt", contexts: ["Race"]),
            newItem(name: "Race flats", contexts: ["Outdoor", "Race"]), newItem(name: "Gel belt"),
        ]))
        lib.saveTemplate(newList(name: "Bike", group: "WET", items: [newItem(name: "Bike helmet"), newItem(name: "Gel belt")]))
        lib.saveTemplate(newList(name: "Travel", group: "GA", items: [newItem(name: "Guidebook")]))
        for n in lib.items.indices { lib.items[n].ownedBy = lib.items[n].name == "Running cap" ? "Robin" : "Kim" }
        let id = { (name: String) in lib.templates.first { $0.name == name }!.id }
        let made = lib.createTrip(newEvent(name: "Training camp", mode: mode,
                                           activities: [id("Swim"), id("Run"), id("Bike"), id("Travel")],
                                           startDate: "2026-08-10", endDate: "2026-08-14"))
        return Camp(lib: lib, trip: made.id, swim: id("Swim"), run: id("Run"), bike: id("Bike"),
                    travel: id("Travel"), base: id("Common base"))
    }

    /// The marks "Use these" would set, by thing name: "used", "didn't use", or absent.
    private func marks(_ c: Camp, _ workouts: [HealthWorkout]) -> [String: String] {
        let review = c.lib.healthReview(tripId: c.trip, workouts: workouts)
        let entries = c.lib.trips.first { $0.id == c.trip }!.entries
        var out: [String: String] = [:]
        for (line, used) in review.marks {
            out[entries.first { $0.id == line }!.name] = used ? "used" : "didn't use"
        }
        return out
    }

    // MARK: Which workout meets which template — every row of the table

    func testEveryAppleHealthWorkoutTypeMeetsItsKind() {
        let table: [(UInt, WorkoutKind?)] = [
            (HealthActivity.swimming, .swim), (HealthActivity.cycling, .bike), (HealthActivity.running, .run),
            (HealthActivity.traditionalStrengthTraining, .strength), (HealthActivity.functionalStrengthTraining, .strength),
            (HealthActivity.coreTraining, .strength),
            (HealthActivity.yoga, .mobility), (HealthActivity.mindAndBody, .mobility), (HealthActivity.flexibility, .mobility),
            (HealthActivity.cooldown, .mobility), (HealthActivity.preparationAndRecovery, .mobility),
            (HealthActivity.hiking, .hiking), (HealthActivity.golf, .golf), (HealthActivity.climbing, .climbing),
            (HealthActivity.underwaterDiving, .diving),
            // Anything else is ignored: a walk, tennis, rowing, "other", a lone change-over.
            (HealthActivity.walking, nil), (48, nil), (35, nil), (3000, nil), (HealthActivity.transition, nil),
        ]
        for (type, kind) in table { XCTAssertEqual(WorkoutKind.of(activityType: type), kind, "activity type \(type)") }
        // Apple's own numbers, written out in the model — one wrong number would read a
        // walk as a run on his phone, and no test with invented records would see it.
        XCTAssertEqual([HealthActivity.climbing, HealthActivity.cycling, HealthActivity.functionalStrengthTraining,
                        HealthActivity.golf, HealthActivity.hiking, HealthActivity.mindAndBody,
                        HealthActivity.preparationAndRecovery, HealthActivity.running, HealthActivity.swimming,
                        HealthActivity.traditionalStrengthTraining, HealthActivity.walking, HealthActivity.yoga,
                        HealthActivity.coreTraining, HealthActivity.flexibility, HealthActivity.cooldown,
                        HealthActivity.swimBikeRun, HealthActivity.transition, HealthActivity.underwaterDiving],
                       [9, 13, 20, 21, 24, 29, 33, 37, 46, 50, 52, 57, 59, 62, 80, 82, 83, 84])
    }

    func testEachWorkoutGetsItsContextFromAppleHealth() {
        let d = "2026-08-11"
        func context(_ w: HealthWorkout) -> String? { metWorkouts([w]).first?.context }
        // Swim: the swimming location.
        XCTAssertEqual(context(swim(d, SwimmingLocation.pool)), "Indoor")
        XCTAssertEqual(context(swim(d, SwimmingLocation.openWater)), "Outdoor")
        XCTAssertNil(context(swim(d, SwimmingLocation.unknown)), "an unknown swim is either")
        XCTAssertNil(context(swim(d, nil)), "a swim without a location is either")
        XCTAssertNil(context(HealthWorkout(activityType: HealthActivity.swimming, day: d, indoor: true)),
                     "a swim is placed by its location, not by 'indoor workout'")
        // Bike, Run, Climbing: indoor workout → Indoor, otherwise Outdoor.
        for type in [HealthActivity.cycling, HealthActivity.running, HealthActivity.climbing] {
            XCTAssertEqual(context(HealthWorkout(activityType: type, day: d, indoor: true)), "Indoor", "\(type)")
            XCTAssertEqual(context(HealthWorkout(activityType: type, day: d, indoor: false)), "Outdoor", "\(type)")
            XCTAssertEqual(context(HealthWorkout(activityType: type, day: d)), "Outdoor", "\(type) not said = outdoors")
        }
        // Strength is indoors; mobility either; hiking, golf and diving outdoors — whatever is said.
        for type in [HealthActivity.traditionalStrengthTraining, HealthActivity.functionalStrengthTraining, HealthActivity.coreTraining] {
            XCTAssertEqual(context(HealthWorkout(activityType: type, day: d, indoor: false)), "Indoor", "\(type)")
        }
        for type in [HealthActivity.yoga, HealthActivity.mindAndBody, HealthActivity.flexibility,
                     HealthActivity.cooldown, HealthActivity.preparationAndRecovery] {
            XCTAssertNil(context(HealthWorkout(activityType: type, day: d, indoor: true)), "\(type)")
        }
        for type in [HealthActivity.hiking, HealthActivity.golf, HealthActivity.underwaterDiving] {
            XCTAssertEqual(context(HealthWorkout(activityType: type, day: d, indoor: true)), "Outdoor", "\(type)")
        }
        // A walk is no workout here.
        XCTAssertTrue(metWorkouts([HealthWorkout(activityType: HealthActivity.walking, day: d)]).isEmpty)
    }

    func testATriathlonCountsAsItsSwimRideAndRun() {
        let race = HealthWorkout(activityType: HealthActivity.swimBikeRun, day: "2026-08-12", parts: [
            swim("2026-08-12", SwimmingLocation.openWater),
            HealthWorkout(activityType: HealthActivity.transition, day: "2026-08-12"),
            ride("2026-08-12"),
            HealthWorkout(activityType: HealthActivity.transition, day: "2026-08-12"),
            run("2026-08-12"),
        ])
        XCTAssertEqual(metWorkouts([race]), [MetWorkout(kind: .swim, context: "Outdoor", day: "2026-08-12"),
                                            MetWorkout(kind: .bike, context: "Outdoor", day: "2026-08-12"),
                                            MetWorkout(kind: .run, context: "Outdoor", day: "2026-08-12")])
        XCTAssertTrue(metWorkouts([HealthWorkout(activityType: HealthActivity.swimBikeRun, day: "2026-08-12")]).isEmpty,
                      "a multisport workout without its parts says nothing")
    }

    func testATemplateMeetsAWorkoutByItsName() {
        let table: [(String, WorkoutKind?)] = [
            ("Swim", .swim), ("swim ", .swim), ("Swimming", .swim), ("Bike", .bike), ("Cycling", .bike),
            ("Run", .run), ("Running", .run), ("Strength", .strength), ("Gym", .strength),
            ("Mobility", .mobility), ("Breath work", .mobility), ("Breathwork", .mobility),
            ("Mobility & Breath work", .mobility), ("Yoga", .mobility),
            ("Hiking", .hiking), ("Golf", .golf), ("Climbing", .climbing),
            ("Diving", .diving), ("Freediving", .diving), ("Diving and Freediving", .diving),
            // The whole name, not a word in it — as the workout colours compare.
            ("Swim training", nil), ("Run club", nil), ("Travel", nil), ("Race", nil), ("", nil),
        ]
        for (name, kind) in table { XCTAssertEqual(WorkoutKind.named(name), kind, "'\(name)'") }
        XCTAssertNil(Library.workoutKind(of: newList(name: "Swim", role: "base")), "the common base never meets a workout")
        XCTAssertNil(Library.workoutKind(of: newList(name: "Run", role: "transport")), "nor does a transport template")
        XCTAssertEqual(Library.workoutKind(of: newList(name: "Golf", group: "GA")), .golf, "any activity area")
    }

    // MARK: "Counts as" on the template

    func testCountsAsIsHisLinkAndTravelsWithTheTemplate() {
        var c = camp()
        XCTAssertNil(c.lib.countsAsChoice(templateId: c.travel))
        XCTAssertNil(c.lib.workoutKind(templateId: c.travel), "Travel is no workout by its name")

        XCTAssertTrue(c.lib.setCountsAs(templateId: c.travel, to: WorkoutKind.hiking.rawValue))
        XCTAssertEqual(c.lib.workoutKind(templateId: c.travel), .hiking)
        XCTAssertTrue(c.lib.setCountsAs(templateId: c.swim, to: Library.countsAsNothing))
        XCTAssertNil(c.lib.workoutKind(templateId: c.swim), "Nothing wins over the name")
        XCTAssertEqual(c.lib.countsAsChoice(templateId: c.swim), "none")

        // Later edits save the whole template again — the link must survive them.
        _ = c.lib.addToTemplate(templateId: c.travel, name: "Sun hat")
        XCTAssertTrue(c.lib.renameTemplate(id: c.travel, to: "Holiday"))
        XCTAssertEqual(c.lib.workoutKind(templateId: c.travel), .hiking, "an edit to the template lost the link")
        XCTAssertEqual(Library.workoutKind(of: c.lib.resolvedTemplate(id: c.travel)!), .hiking, "a resolved template lost it")
        // …and iCloud's records and a backup carry it.
        let synced = Library(records: c.lib.records())
        XCTAssertEqual(synced.workoutKind(templateId: c.travel), .hiking, "the stored records lost the link")
        XCTAssertEqual(synced.countsAsChoice(templateId: c.swim), "none")
        let (back, report) = Importer.library(from: c.lib.backupFile(exportedAt: "2026-10-07T08:00:00.000Z"))
        XCTAssertTrue(report.isFaithful, report.mismatches.prefix(3).joined(separator: "; "))
        XCTAssertEqual(back.workoutKind(templateId: c.travel), .hiking, "a backup lost the link")
        XCTAssertEqual(back.countsAsChoice(templateId: c.swim), "none")

        // Back to the name; nonsense and missing templates are refused.
        XCTAssertTrue(c.lib.setCountsAs(templateId: c.swim, to: nil))
        XCTAssertEqual(c.lib.workoutKind(templateId: c.swim), .swim)
        XCTAssertNil(c.lib.countsAsChoice(templateId: c.swim))
        XCTAssertFalse(c.lib.setCountsAs(templateId: c.swim, to: "tennis"))
        XCTAssertEqual(c.lib.workoutKind(templateId: c.swim), .swim, "a refused value changed the link")
        XCTAssertFalse(c.lib.setCountsAs(templateId: "nope", to: "swim"))
    }

    func testALinkedTemplateIsMarkedAndANothingTemplateIsLeftAlone() {
        var c = camp()
        let week = [swim("2026-08-11"), run("2026-08-12"), ride("2026-08-13"),
                    HealthWorkout(activityType: HealthActivity.hiking, day: "2026-08-13")]
        XCTAssertNil(marks(c, week)["Guidebook"], "a holiday template is not a workout")
        XCTAssertTrue(c.lib.setCountsAs(templateId: c.travel, to: "hiking"))
        XCTAssertEqual(marks(c, week)["Guidebook"], "used", "Travel counts as Hiking now, and he hiked")
        XCTAssertEqual(marks(c, Array(week.prefix(3)))["Guidebook"], "didn't use", "no hike → didn't use")
        XCTAssertTrue(c.lib.setCountsAs(templateId: c.bike, to: Library.countsAsNothing))
        let m = marks(c, [swim("2026-08-11")])
        XCTAssertNil(m["Bike helmet"], "a template linked to Nothing is left as it is")
        XCTAssertNil(m["Gel belt"], "…and so is a thing it shares with a workout (it is not a workout)")
        let rows = c.lib.healthReview(tripId: c.trip, workouts: [swim("2026-08-11")]).rows.map(\.words)
        XCTAssertFalse(rows.contains("No bike"), "Nothing is no workout to miss: \(rows)")
    }

    // MARK: The days

    func testOnlyTheTripsDaysCountAndAnUndatedTripHasNoBlock() {
        var c = camp()
        XCTAssertEqual(c.lib.healthDays(tripId: c.trip)?.first, "2026-08-10")
        XCTAssertEqual(c.lib.healthDays(tripId: c.trip)?.last, "2026-08-14")
        let review = c.lib.healthReview(tripId: c.trip, workouts: [
            swim("2026-08-09"), swim("2026-08-10"), swim("2026-08-14"), swim("2026-08-15"),
        ])
        XCTAssertEqual(review.workouts, 2, "the first and the last day count, the days around them do not")
        XCTAssertEqual(review.rows.first?.words, "Swim \u{00B7} indoor \u{00B7} 2 times")
        XCTAssertEqual(c.lib.healthReview(tripId: c.trip, workouts: [swim("2026-08-20")]), Library.HealthReview(),
                       "workouts only on other days = no workouts")

        let n = c.lib.trips.firstIndex { $0.id == c.trip }!
        c.lib.trips[n].endDate = ""
        XCTAssertEqual(c.lib.healthDays(tripId: c.trip)?.last, "2026-08-10", "no last day = the first day only")
        c.lib.trips[n].endDate = "2026-08-01"
        XCTAssertEqual(c.lib.healthDays(tripId: c.trip)?.last, "2026-08-10", "a last day before the first = the first only")
        c.lib.trips[n].startDate = ""
        XCTAssertNil(c.lib.healthDays(tripId: c.trip), "an undated trip gets no block")
        XCTAssertEqual(c.lib.healthReview(tripId: c.trip, workouts: [swim("2026-08-11")]), Library.HealthReview())
        XCTAssertNil(c.lib.healthDays(tripId: "nope"))
    }

    func testTwoTripsOnTheSameDaysReadTheSameWorkouts() {
        var c = camp()
        let twin = c.lib.createTrip(newEvent(name: "Same week", mode: "quick", activities: [c.swim],
                                             startDate: "2026-08-10", endDate: "2026-08-14"))
        let week = [swim("2026-08-11")]
        XCTAssertEqual(c.lib.healthReview(tripId: twin.id, workouts: week).rows.first,
                       c.lib.healthReview(tripId: c.trip, workouts: week).rows.first, "he was on both")
    }

    // MARK: The rows

    func testTheRowsNameEachKindItsContextAndHowOftenThenWhatWasNotDone() {
        let c = camp()
        let review = c.lib.healthReview(tripId: c.trip, workouts: [
            swim("2026-08-10"), swim("2026-08-11"), swim("2026-08-12"),
            run("2026-08-11"), run("2026-08-13"),
            HealthWorkout(activityType: HealthActivity.yoga, day: "2026-08-12"),
            HealthWorkout(activityType: HealthActivity.walking, day: "2026-08-12"),
        ])
        XCTAssertEqual(review.rows.map(\.words), [
            "Swim \u{00B7} indoor \u{00B7} 3 times",
            "Run \u{00B7} outdoor \u{00B7} 2 times",
            "Mobility & breath work \u{00B7} once",
            "No bike",
        ])
        XCTAssertEqual(review.rows.map(\.done), [true, true, true, false])
        XCTAssertEqual(review.workouts, 6, "the walk is not counted")

        let mixed = c.lib.healthReview(tripId: c.trip, workouts: [
            swim("2026-08-10"), swim("2026-08-11", SwimmingLocation.openWater), swim("2026-08-12"),
            swim("2026-08-13", nil), ride("2026-08-12", indoor: true),
        ])
        XCTAssertEqual(mixed.rows.map(\.words), [
            "Swim \u{00B7} 2 indoor, 1 outdoor \u{00B7} 4 times",
            "Bike \u{00B7} indoor \u{00B7} once",
            "No run",
        ])
        let unknown = c.lib.healthReview(tripId: c.trip, workouts: [swim("2026-08-10", nil), run("2026-08-10")])
        XCTAssertEqual(unknown.rows.first?.words, "Swim \u{00B7} once", "a context Apple Health could not tell is not named")
    }

    func testNoWorkoutsMeansNoRowsAndNoMarks() {
        let c = camp()
        XCTAssertEqual(c.lib.healthReview(tripId: c.trip, workouts: []), Library.HealthReview())
        XCTAssertEqual(c.lib.healthReview(tripId: c.trip, workouts: [HealthWorkout(activityType: HealthActivity.walking, day: "2026-08-11")]),
                       Library.HealthReview(), "only workouts the review ignores = none")
    }

    // MARK: The marks

    func testDoneNotDoneAndTheOtherContext() {
        let c = camp()
        // Three pool swims and two outdoor runs; no ride.
        let m = marks(c, [swim("2026-08-10"), swim("2026-08-11"), swim("2026-08-12"), run("2026-08-11"), run("2026-08-13")])
        XCTAssertEqual(m["Goggles"], "used", "a swim was done")
        XCTAssertEqual(m["Swim cap"], "used")
        XCTAssertEqual(m["Pool buoy"], "used", "Indoor line, indoor swims")
        XCTAssertEqual(m["Wetsuit"], "didn't use", "Outdoor line, only indoor swims")
        XCTAssertEqual(m["Trail shoes"], "used", "Outdoor line, outdoor runs")
        XCTAssertEqual(m["Treadmill towel"], "didn't use", "Indoor line, only outdoor runs")
        XCTAssertEqual(m["Bike helmet"], "didn't use", "no ride at all")
        XCTAssertEqual(m["Gel belt"], "used", "on Run and Bike: one done is enough")
        XCTAssertNil(m["Race belt"], "Race is not in Apple Health: left as it is")
        XCTAssertEqual(m["Race flats"], "used", "Outdoor or Race, and he ran outdoors")
        XCTAssertNil(m["Running cap"], "someone else's thing")
        XCTAssertNil(m["Towel"], "on the common base too: the base wins")
        XCTAssertNil(m["Passport"], "the common base")
        XCTAssertNil(m["Guidebook"], "a template that is no workout")
        XCTAssertEqual(m.count, 9)
    }

    func testRaceAndAnyContextLines() {
        let c = camp()
        // Only indoor runs: the Race flats (Outdoor or Race) may have run the race indoors.
        var m = marks(c, [run("2026-08-11", indoor: true)])
        XCTAssertNil(m["Race flats"], "the other context, but it may have been the race")
        XCTAssertEqual(m["Trail shoes"], "didn't use")
        XCTAssertEqual(m["Treadmill towel"], "used")
        // No run at all: no race either.
        m = marks(c, [swim("2026-08-11")])
        XCTAssertEqual(m["Race flats"], "didn't use", "no run at all, so no race")
        XCTAssertNil(m["Race belt"], "Race only is always left as it is")
        // A swim Apple Health cannot place counts for either context.
        m = marks(c, [swim("2026-08-11", nil)])
        XCTAssertEqual(m["Wetsuit"], "used")
        XCTAssertEqual(m["Pool buoy"], "used")
    }

    func testThingsForSomeoneElseAndBothHaveOneAndThingsOnTwoTemplates() {
        var c = camp()
        let week = [swim("2026-08-11"), run("2026-08-12")]
        // "Both have one" (no name) is his.
        let cap = c.lib.items.firstIndex { $0.name == "Swim cap" }!
        c.lib.items[cap].ownedBy = ""
        XCTAssertEqual(marks(c, week)["Swim cap"], "used", "Both have one counts as his")
        // Robin's goggles say nothing, used or not.
        let goggles = c.lib.items.firstIndex { $0.name == "Goggles" }!
        c.lib.items[goggles].ownedBy = "robin "
        XCTAssertNil(marks(c, week)["Goggles"], "someone else's — compared as names")
        XCTAssertNil(marks(c, [run("2026-08-12")])["Goggles"], "not even when no swim was done")
        // The Towel: on Swim and on the base — the base wins, even with no swim.
        XCTAssertNil(marks(c, [run("2026-08-12")])["Towel"])
        // …but on a Quick trip the base is not packed, and Swim alone brought it.
        let quick = camp(mode: "quick")
        XCTAssertEqual(marks(quick, [run("2026-08-12")])["Towel"], "didn't use")
        XCTAssertNil(marks(quick, [run("2026-08-12")])["Passport"], "the base is not on a quick trip at all")
    }

    func testWhoHeIsIsTheNameOnMostOfHisThings() {
        var c = camp()
        XCTAssertEqual(c.lib.mainOwner(), "Kim")
        for n in c.lib.items.indices { c.lib.items[n].ownedBy = "" }
        XCTAssertEqual(c.lib.mainOwner(), "", "nobody named: every thing is his")
        XCTAssertNotNil(marks(c, [swim("2026-08-11")])["Running cap"], "with nobody named, the cap is his too")
        c.lib.items[0].ownedBy = "Robin"; c.lib.items[1].ownedBy = "Kim"
        XCTAssertEqual(c.lib.mainOwner(), "Kim", "a tie: the first A–Z")
    }

    func testThisIsMeDecidesWhoseThingsAppleHealthMarks() {
        var c = camp()
        let week = [swim("2026-08-11")]
        XCTAssertNil(c.lib.me(), "nobody marked yet")
        XCTAssertEqual(c.lib.mainOwner(), "Kim", "the guess while nobody is marked")
        XCTAssertNil(marks(c, week)["Running cap"], "Robin's, by the guess")

        // He says he is Robin: Robin's things and "Both have one" are his now, Kim's are not.
        XCTAssertTrue(c.lib.setMe("robin"))
        XCTAssertEqual(c.lib.me(), "Robin", "spelled as Owners shows it")
        XCTAssertEqual(c.lib.mainOwner(), "Robin", "the mark wins over the guess")
        let cap = c.lib.items.firstIndex { $0.name == "Swim cap" }!
        c.lib.items[cap].ownedBy = ""
        var m = marks(c, week)
        XCTAssertEqual(m["Running cap"], "didn't use", "his cap now — and no run")
        XCTAssertNil(m["Goggles"], "Kim's goggles say nothing now")
        XCTAssertEqual(m["Swim cap"], "used", "Both have one counts as his")

        // One at most: marking another moves the mark; a name that is no owner is refused.
        XCTAssertTrue(c.lib.setMe("Kim"))
        XCTAssertEqual(c.lib.me(), "Kim")
        XCTAssertFalse(c.lib.setMe("Nobody"))
        XCTAssertEqual(c.lib.me(), "Kim", "a refused name moved the mark")

        // Renamed in Your choices, the mark follows; iCloud's records and a backup keep it.
        XCTAssertNil(c.lib.renameChoice("owners", key: "Kim", to: "Kim Berg"))
        XCTAssertEqual(c.lib.me(), "Kim Berg", "a rename lost the mark")
        XCTAssertEqual(Library(records: c.lib.records()).me(), "Kim Berg", "the stored records lost the mark")
        let (back, report) = Importer.library(from: c.lib.backupFile(exportedAt: "2026-10-07T08:00:00.000Z"))
        XCTAssertTrue(report.isFaithful, report.mismatches.prefix(3).joined(separator: "; "))
        XCTAssertEqual(back.me(), "Kim Berg", "a backup lost the mark")

        // Unmarked: back to the guess.
        XCTAssertTrue(c.lib.setMe(nil))
        XCTAssertNil(c.lib.me())
        XCTAssertEqual(c.lib.mainOwner(), "Kim Berg")
    }

    func testLinesWithoutATemplateAndLinesThatNeverWentAreLeftAlone() {
        var c = camp()
        let n = c.lib.trips.firstIndex { $0.id == c.trip }!
        var own = newItem(name: "Spare laces"); own.custom = true; own.checked = true
        c.lib.trips[n].entries.append(own)
        // Something was ticked, so only ticked lines went — the rest are not asked about.
        let goggles = c.lib.trips[n].entries.firstIndex { $0.name == "Goggles" }!
        c.lib.trips[n].entries[goggles].checked = true
        let m = marks(c, [run("2026-08-12")])
        XCTAssertNil(m["Spare laces"], "added by hand on the trip: no template")
        XCTAssertEqual(m["Goggles"], "didn't use", "it went, and no swim was done")
        XCTAssertNil(m["Bike helmet"], "never went in the bag: not asked about")
        XCTAssertEqual(m.count, 1)
    }

    func testARowTakenOffItsTemplateSinceStillCountsForItsTemplate() {
        var c = camp()
        let wetsuit = c.lib.resolvedTemplate(id: c.swim)!.items.first { $0.name == "Wetsuit" }!
        XCTAssertTrue(c.lib.removeFromTemplate(templateId: c.swim, memId: wetsuit.memId!))
        XCTAssertEqual(marks(c, [swim("2026-08-11")])["Wetsuit"], "used", "its template is still Swim, for any context")
        XCTAssertEqual(marks(c, [run("2026-08-11")])["Wetsuit"], "didn't use")
    }

    func testAWatchThatSyncsLaterIsReadAgain() {
        let c = camp()
        XCTAssertEqual(marks(c, [swim("2026-08-11")])["Trail shoes"], "didn't use", "no run yet")
        XCTAssertEqual(marks(c, [swim("2026-08-11"), run("2026-08-14")])["Trail shoes"], "used",
                       "the run arrived: read again, the answer follows")
    }

    // MARK: His own answers, and nothing saved

    func testUseTheseKeepsHisOwnAnswersAndSavesNothing() {
        let c = camp()
        let review = c.lib.healthReview(tripId: c.trip, workouts: [swim("2026-08-11"), run("2026-08-12")])
        let wetsuit = c.line("Wetsuit"), goggles = c.line("Goggles"), helmet = c.line("Bike helmet"), shoes = c.line("Trail shoes")
        // He had marked the Goggles "didn't use" himself, and the Bike helmet "used" (tapped twice).
        let after = Library.unusedAfterHealth(review.marks, unused: [goggles], answeredByHand: [goggles, helmet])
        XCTAssertTrue(after.contains(goggles), "his own 'didn't use' stays")
        XCTAssertFalse(after.contains(helmet), "his own 'used' stays")
        XCTAssertTrue(after.contains(wetsuit), "marked didn't use")
        XCTAssertFalse(after.contains(shoes))
        // A mark set by an earlier press is put right by a later one.
        let again = Library.unusedAfterHealth([wetsuit: true], unused: after, answeredByHand: [goggles, helmet])
        XCTAssertFalse(again.contains(wetsuit))
        // Reading Apple Health changes nothing in the library; only Save does.
        XCTAssertEqual(c.lib.trips.first { $0.id == c.trip }!.reviewedAt, "", "the trip is not reviewed")
        XCTAssertTrue(c.lib.items.allSatisfy { $0.stats.lastReviewed.isEmpty })
    }

    func testTheSavedReviewTeachesTheThingsWhatAppleHealthMarked() {
        var c = camp()
        let review = c.lib.healthReview(tripId: c.trip, workouts: [swim("2026-08-11"), run("2026-08-12")])
        let unused = Library.unusedAfterHealth(review.marks, unused: [], answeredByHand: [])
        XCTAssertTrue(c.lib.saveReview(tripId: c.trip, unused: unused, missed: [], when: "2026-08-15T09:00:00.000Z"))
        let helmet = c.lib.items.first { $0.name == "Bike helmet" }!
        XCTAssertEqual(helmet.stats.unused, 1, "no ride: the helmet went unused")
        let goggles = c.lib.items.first { $0.name == "Goggles" }!
        XCTAssertEqual(goggles.stats.used, 1)
        let cap = c.lib.items.first { $0.name == "Running cap" }!
        XCTAssertEqual(cap.stats.used, 1, "someone else's: left as the review assumes — used")
    }
}
