import XCTest
@testable import PackingCore

/// Context PER WORKOUT (0.67) — his ask: "it could be outdoors Run and indoors Swim".
/// Native only (the web app has no `activityContexts`), so these are not ported from
/// tests/model.test.mjs; the parity checker holds the other half: a trip WITHOUT the
/// field must build, read and write exactly as before.
final class WorkoutContextsTests: XCTestCase {
    override func tearDown() { PackingEnv.reset(); super.tearDown() }

    /// Two workouts with things for each context, and a goal activity that has some too.
    private func lists() -> (run: PackList, swim: PackList, hike: PackList) {
        let run = newList(id: "run", name: "Run", group: "WET", items: [
            newItem(name: "Trail shoes", contexts: ["Outdoor"]),
            newItem(name: "Treadmill towel", contexts: ["Indoor"]),
            newItem(name: "Race belt", contexts: ["Race"]),
            newItem(name: "Socks"),
        ])
        let swim = newList(id: "swim", name: "Swim", group: "WET", items: [
            newItem(name: "Pool goggles", contexts: ["Indoor"]),
            newItem(name: "Wetsuit", contexts: ["Outdoor"]),
            newItem(name: "Swim cap"),
        ])
        let hike = newList(id: "hike", name: "Hiking", group: "GA", items: [
            newItem(name: "Head torch", contexts: ["Indoor"]),     // a GA list: context never narrows it
        ])
        return (run, swim, hike)
    }

    private func names(_ ev: TripEvent, _ l: (run: PackList, swim: PackList, hike: PackList)) -> [String] {
        buildTotalEntries(ev, [l.run, l.swim, l.hike]).map(\.name)
    }

    /// Run outdoors and Swim indoors on ONE trip: each workout is narrowed by its own.
    func testEachWorkoutIsNarrowedByItsOwnContext() {
        let l = lists()
        let ev = newEvent(activities: ["run", "swim"], activityContexts: ["run": ["Outdoor"], "swim": ["Indoor"]])
        XCTAssertEqual(names(ev, l), ["Trail shoes", "Socks", "Pool goggles", "Swim cap"])
        XCTAssertEqual(contextsFor(ev, l.run), ["Outdoor"])
        XCTAssertEqual(contextsFor(ev, l.swim), ["Indoor"])
        // Two contexts on one workout: either one brings a thing.
        let both = newEvent(activities: ["run"], activityContexts: ["run": ["Outdoor", "Race"]])
        XCTAssertEqual(names(both, l), ["Trail shoes", "Race belt", "Socks"])
    }

    /// A workout without an entry falls back to the trip-wide `contexts` — every trip
    /// made before 0.67 builds as it did; one WITH an entry is not touched by them.
    func testAWorkoutWithoutItsOwnFallsBackToTheTripsContext() {
        let l = lists()
        let old = newEvent(activities: ["run", "swim"], contexts: ["Indoor"])
        XCTAssertEqual(names(old, l), ["Treadmill towel", "Socks", "Pool goggles", "Swim cap"], "an old trip builds as before")
        let mixed = newEvent(activities: ["run", "swim"], contexts: ["Indoor"], activityContexts: ["run": ["Race"]])
        XCTAssertEqual(names(mixed, l), ["Race belt", "Socks", "Pool goggles", "Swim cap"],
                       "Run by its own (Race); Swim, with none of its own, by the trip's (Indoor)")
        XCTAssertEqual(contextsFor(mixed, l.swim), ["Indoor"])
        XCTAssertEqual(contextsFor(mixed, nil), ["Indoor"], "no template: the trip's")
    }

    /// An EMPTY entry is a choice too: nothing picked for that workout = all its things,
    /// even when the trip-wide contexts would narrow it.
    func testAnEmptyEntryNarrowsNothing() {
        let l = lists()
        let ev = newEvent(activities: ["run"], contexts: ["Indoor"], activityContexts: ["run": []])
        XCTAssertEqual(names(ev, l), ["Trail shoes", "Treadmill towel", "Race belt", "Socks"])
    }

    /// Context only ever narrows a WET template — an entry for a goal activity changes nothing.
    func testAnEntryForANonWorkoutTemplateChangesNothing() {
        let l = lists()
        let ev = newEvent(activities: ["hike"], activityContexts: ["hike": ["Outdoor"]])
        XCTAssertEqual(names(ev, l), ["Head torch"])
        XCTAssertTrue(itemMatchesEvent(l.hike.items[0], ev, l.hike))
    }

    /// The field travels in the trip's JSON (sync records and backups are that JSON):
    /// read back the same; absent = no key at all, so an old trip is written exactly as
    /// before; junk is read as nothing rather than as a crash.
    func testItRoundTripsThroughJSONAndIsAbsentWhenEmpty() throws {
        let ev = newEvent(id: "t1", name: "Lake week", activities: ["run", "swim"],
                          activityContexts: ["run": ["Outdoor"], "swim": ["Indoor", "Race"], "bike": []])
        XCTAssertEqual(ev.json[ACTIVITY_CONTEXTS_KEY], ["run": ["Outdoor"], "swim": ["Indoor", "Race"], "bike": []])
        let back = try XCTUnwrap(coerceEvent(json: ev.json))
        XCTAssertEqual(back.activityContexts, ev.activityContexts)
        XCTAssertNil(back.extra[ACTIVITY_CONTEXTS_KEY], "a known key, not an unknown one kept in extra")
        let coded = try JSONDecoder().decode(TripEvent.self, from: JSONEncoder().encode(ev))
        XCTAssertEqual(coded, ev)

        let plain = newEvent(id: "t2", name: "Old trip", contexts: ["Outdoor"])
        XCTAssertNil(plain.json[ACTIVITY_CONTEXTS_KEY], "no entries, no key: an old trip's JSON is unchanged")
        XCTAssertEqual(plain.json.objectValue?.keys.sorted(), TripEvent.knownKeys.subtracting([ACTIVITY_CONTEXTS_KEY]).sorted())
        XCTAssertEqual(coerceEvent(json: plain.json)?.activityContexts, [:])

        XCTAssertEqual(coerceEvent(json: [ACTIVITY_CONTEXTS_KEY: ["run", "swim"]])?.activityContexts, [:], "an array is not a map")
        XCTAssertEqual(coerceEvent(json: [ACTIVITY_CONTEXTS_KEY: "Outdoor"])?.activityContexts, [:])
        XCTAssertEqual(coerceEvent(json: [ACTIVITY_CONTEXTS_KEY: .null])?.activityContexts, [:])
        XCTAssertEqual(coerceEvent(json: [ACTIVITY_CONTEXTS_KEY: ["": ["Indoor"], "run": "Outdoor", "swim": ["Indoor", 3]]])?.activityContexts,
                       ["run": [], "swim": ["Indoor", "3"]], "an empty id is dropped; a value that is not a list reads as an empty one")
    }

    /// A trip SENT (file or link) carries each workout's context, so the receiver's
    /// Trip settings shows — and a rebuild keeps — what the sender picked.
    func testASharedTripCarriesEachWorkoutsContext() throws {
        var ev = newEvent(name: "Run and swim", activities: ["run", "swim"],
                          activityContexts: ["run": ["Outdoor"], "swim": ["Indoor"]])
        ev.entries = [newItem(name: "Trail shoes")]
        let file = try parseTripBundle(buildTripBundle(ev).text(pretty: true))
        XCTAssertEqual(file.activityContexts, ["run": ["Outdoor"], "swim": ["Indoor"]])
        let frag = try XCTUnwrap(encodeTripLink(ev))
        let link = try decodeTripLink(String(frag.dropFirst("#/t/".count)))
        XCTAssertEqual(link.activityContexts, ["run": ["Outdoor"], "swim": ["Indoor"]])
        // A trip without it sends no such key.
        XCTAssertFalse(buildTripBundle(newEvent(name: "Plain")).text().contains(ACTIVITY_CONTEXTS_KEY))
    }
}
