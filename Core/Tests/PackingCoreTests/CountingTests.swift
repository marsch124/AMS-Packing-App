import XCTest
@testable import PackingCore

// Ported from tests/model.test.mjs — progress, applyReview, pruneSuggestions,
// effectiveQty / qtyNights, containerLimits, bagLoads and packingFlags.
//
// `applyReview` CHANGES the lists it is handed (JS mutates them in place); here that
// is `inout`, so each test keeps its lists in a `var lists` and reads the result there.
final class CountingTests: XCTestCase {
    override func tearDown() { PackingEnv.reset(); super.tearDown() }

    /// `ev.entries.find((e) => e.name === name).x = …`
    private func edit(_ ev: inout TripEvent, _ name: String, _ change: (inout Item) -> Void) throws {
        let i = try XCTUnwrap(ev.entries.firstIndex { $0.name == name })
        change(&ev.entries[i])
    }

    // JS: 'progress: counts checked entries'
    func testProgressCountsCheckedEntries() {
        let entries = [newItem(checked: true), newItem(checked: false), newItem(checked: true)]
        XCTAssertEqual(progress(entries), PackingProgress(done: 2, total: 3, aside: 0, pct: 67))
    }

    // "Not this time": still on the list, not being packed. It has to leave the
    // counts, or a trip where you deliberately leave something behind can never
    // reach 100% and the ring reports a job that is finished as unfinished.
    // JS: 'progress: something set aside leaves the count, and is reported'
    func testProgressSomethingSetAsideLeavesTheCountAndIsReported() {
        let entries = [
            newItem(name: "A", checked: true),
            newItem(name: "B", checked: false),
            newItem(name: "C", skipped: true),
            newItem(name: "D", skipped: true),
        ]
        XCTAssertEqual(progress(entries), PackingProgress(done: 1, total: 2, aside: 2, pct: 50))
    }

    // JS: 'progress: packing everything else reaches 100% with things set aside'
    func testProgressPackingEverythingElseReaches100WithThingsSetAside() {
        let entries = [newItem(checked: true), newItem(checked: true), newItem(skipped: true)]
        let p = progress(entries)
        XCTAssertEqual(p.pct, 100)
        XCTAssertEqual(p.aside, 1)
    }

    // JS: 'applyReview: folds used/unused flags into source-item stats'
    func testApplyReviewFoldsUsedUnusedFlagsIntoSourceItemStats() throws {
        var lists = [newList(name: "Run", items: [newItem(name: "Shoes"), newItem(name: "Belt")])]
        var ev = newEvent(activities: [lists[0].id])
        ev.entries = buildTotalEntries(ev, lists)
        try edit(&ev, "Shoes") { $0.used = true }
        try edit(&ev, "Belt") { $0.used = false }
        let changed = applyReview(ev, &lists, "2026-07-27T00:00:00Z")
        XCTAssertEqual(changed.count, 1)
        let shoes = try XCTUnwrap(lists[0].items.first { $0.name == "Shoes" })
        let belt = try XCTUnwrap(lists[0].items.first { $0.name == "Belt" })
        XCTAssertEqual([shoes.stats.packed, shoes.stats.used, shoes.stats.unused], [1, 1, 0])
        XCTAssertEqual([belt.stats.packed, belt.stats.used, belt.stats.unused], [1, 0, 1])
        // (the returned list is the changed one as it is afterwards, stamped with the time given)
        XCTAssertEqual(changed[0], lists[0])
        XCTAssertEqual(shoes.stats.lastReviewed, "2026-07-27T00:00:00Z")
    }

    // JS: 'applyReview: accumulates across trips'
    func testApplyReviewAccumulatesAcrossTrips() {
        var lists = [newList(name: "Golf", items: [newItem(name: "Umbrella")])]
        func mkReview(_ usedFlag: Bool) {
            var ev = newEvent(activities: [lists[0].id])
            ev.entries = buildTotalEntries(ev, lists)
            ev.entries[0].used = usedFlag
            applyReview(ev, &lists)
        }
        mkReview(false); mkReview(false); mkReview(false)
        let it = lists[0].items[0]
        XCTAssertEqual(it.stats.packed, 3)
        XCTAssertEqual(it.stats.unused, 3)
        XCTAssertEqual(it.stats.used, 0)
    }

    // JS: 'pruneSuggestions: flags packed-but-never-used items, respects keep'
    func testPruneSuggestionsFlagsPackedButNeverUsedItemsRespectsKeep() {
        var list = newList(name: "Travel", items: [
            newItem(name: "Beach blanket", stats: ItemStats(packed: 3, used: 0, unused: 3)),
            newItem(name: "Passport", stats: ItemStats(packed: 3, used: 3, unused: 0)),
            newItem(name: "Umbrella", stats: ItemStats(packed: 1, used: 0, unused: 1)),
        ])
        let s = pruneSuggestions([list], minTrips: 2)
        XCTAssertEqual(s.map { $0.item.name }, ["Beach blanket"])   // Passport used; Umbrella only 1 trip
        // keep flag suppresses the suggestion
        list.items[0].keep = true
        XCTAssertEqual(pruneSuggestions([list], minTrips: 2).count, 0)
    }

    // JS: 'effectiveQty: per-night scales with nights, else explicit qty or 1'
    func testEffectiveQtyPerNightScalesWithNightsElseExplicitQtyOr1() {
        XCTAssertEqual(effectiveQty(newItem(perNight: true), 6), 6)
        XCTAssertEqual(effectiveQty(newItem(perNight: true), 0), 1)   // no nights -> 1
        XCTAssertEqual(effectiveQty(newItem(qty: "3"), 6), 3)
        XCTAssertEqual(effectiveQty(newItem(), 6), 1)
    }

    // JS: 'bagLoads: sums weight×qty per bag with limit warnings'
    func testBagLoadsSumsWeightTimesQtyPerBagWithLimitWarnings() throws {
        let entries = [
            newItem(name: "Socks", container: "Carry-on / hand luggage", weight: 50, perNight: true),
            newItem(name: "Laptop", container: "Carry-on / hand luggage", weight: 1600),
            newItem(name: "Boots", container: "Checked luggage", weight: 900),
        ]
        let loads = bagLoads(entries, 4)   // socks ×4 = 200g + laptop 1600g = 1.8kg carry-on
        let carry = try XCTUnwrap(loads.first { $0.container == "Carry-on / hand luggage" })
        XCTAssertEqual(carry.kg, 1.8)
        XCTAssertEqual(carry.limitKg, 8)
        XCTAssertEqual(carry.over, false)
        // push carry-on over its 8 kg limit
        let heavy = bagLoads([newItem(container: "Carry-on / hand luggage", weight: 9000)], 0)
        XCTAssertEqual(heavy[0].over, true)
    }

    // JS: 'bagLoads & packingFlags: ignore reminders; count flags and known weight'
    func testBagLoadsAndPackingFlagsIgnoreRemindersCountFlagsAndKnownWeight() {
        let entries = [
            newItem(name: "Shampoo", container: "Toiletry bag", weight: 200, liquid: true),
            newItem(name: "Powerbank", container: "Carry-on / hand luggage", weight: 350, restricted: true),
            newItem(name: "Charge devices", container: "Toiletry bag", itemType: "reminder", weight: 999),
        ]
        let f = packingFlags(entries, 0)
        XCTAssertEqual(f.liquids, 1)
        XCTAssertEqual(f.restricted, 1)
        XCTAssertEqual(f.total, 2)        // reminder excluded
        XCTAssertEqual(f.weighed, 2)
        XCTAssertEqual(f.totalKg, 0.6)    // 200 + 350 = 550 -> 0.6 (rounded to 0.1)
        let loads = bagLoads(entries, 0)
        XCTAssertNil(loads.first { $0.grams >= 999 }, "reminder weight not counted")
    }

    // JS: 'bagLoads: what you leave behind is not weighed into the bag'
    func testBagLoadsWhatYouLeaveBehindIsNotWeighedIntoTheBag() throws {
        let entries = [
            newItem(name: "A", container: "Duffel bag", weight: 1000),
            newItem(name: "B", container: "Duffel bag", weight: 500, skipped: true),
        ]
        let duffel = try XCTUnwrap(bagLoads(entries).first { $0.container == "Duffel bag" })
        XCTAssertEqual(duffel.grams, 1000)
        XCTAssertEqual(duffel.items, 1)
    }

    // JS: 'containerLimits + bagLoads: a real bag maxKg drives the over-limit warning'
    func testContainerLimitsAndBagLoadsARealBagMaxKgDrivesTheOverLimitWarning() throws {
        let cl = newList(name: "Containers", role: "container", items: [newItem(name: "Osprey 40", maxKg: 10)])
        let limits = containerLimits([cl])
        XCTAssertEqual(limits["Osprey 40"], 10)
        XCTAssertEqual(limits["Checked luggage"], 23)   // built-in default still present
        let entries = [newItem(name: "Rock", container: "Osprey 40", weight: 12000)]   // 12 kg
        let bag = try XCTUnwrap(bagLoads(entries, 0, limits).first)
        XCTAssertEqual(bag.limitKg, 10)
        XCTAssertEqual(bag.over, true)
        // Without the real limit, an unknown bag has no ceiling and never flags "over".
        XCTAssertEqual(bagLoads(entries, 0)[0].over, false)
    }

    // JS: 'qtyNights: no laundry -> full trip length'
    func testQtyNightsNoLaundryFullTripLength() {
        XCTAssertEqual(qtyNights(newEvent(nights: 12)), 12)
        XCTAssertEqual(qtyNights(newEvent(nights: 3)), 3)
    }

    // JS: 'qtyNights: laundry caps long trips but never raises short ones'
    func testQtyNightsLaundryCapsLongTripsButNeverRaisesShortOnes() {
        XCTAssertEqual(qtyNights(newEvent(nights: 12, laundry: true)), LAUNDRY_CAP_NIGHTS)
        XCTAssertEqual(qtyNights(newEvent(nights: 3, laundry: true)), 3)   // below the cap -> unchanged
        XCTAssertEqual(qtyNights(newEvent(nights: LAUNDRY_CAP_NIGHTS, laundry: true)), LAUNDRY_CAP_NIGHTS)
        XCTAssertEqual(qtyNights(newEvent(nights: 0, laundry: true)), 0)
    }

    // JS: 'laundry feeds effectiveQty: a per-night item packs the cap, not one per night'
    func testLaundryFeedsEffectiveQty() {
        let socks = newItem(name: "Socks", perNight: true)
        let trip = newEvent(nights: 10, laundry: true)
        XCTAssertEqual(effectiveQty(socks, qtyNights(trip)), Double(LAUNDRY_CAP_NIGHTS))   // 4, not 10
        let noLaundry = newEvent(nights: 10)
        XCTAssertEqual(effectiveQty(socks, qtyNights(noLaundry)), 10)
    }

    // --- v162: the review stops counting things that never went in the bag ------

    // JS: 'applyReview: an unticked item on a ticked trip is skipped, not packed'
    func testApplyReviewAnUntickedItemOnATickedTripIsSkippedNotPacked() throws {
        var lists = [newList(name: "Ski", items: [newItem(name: "Skis"), newItem(name: "Snow chains")])]
        var ev = newEvent(activities: [lists[0].id])
        ev.entries = buildTotalEntries(ev, lists)
        try edit(&ev, "Skis") { $0.checked = true; $0.used = true }            // went in the bag, and got used
        try edit(&ev, "Snow chains") { $0.checked = false; $0.used = true }    // looked at, left behind
        applyReview(ev, &lists)
        let s = try XCTUnwrap(lists[0].items.first { $0.name == "Skis" }).stats
        let c = try XCTUnwrap(lists[0].items.first { $0.name == "Snow chains" }).stats
        XCTAssertEqual([s.packed, s.used, s.skipped], [1, 1, 0])
        XCTAssertEqual([c.packed, c.used, c.skipped], [0, 0, 1],
                       "before v162 the chains scored packed:1 used:1 — the exact opposite of the truth")
    }

    // JS: 'applyReview: a trip with no ticks at all still counts, as it always did'
    func testApplyReviewATripWithNoTicksAtAllStillCounts() {
        // He packed without ticking. There is no evidence to read, and learning nothing
        // would be worse than trusting the list — so the old behaviour stands.
        var lists = [newList(name: "Beach", items: [newItem(name: "Towel"), newItem(name: "Snorkel")])]
        var ev = newEvent(activities: [lists[0].id])
        ev.entries = buildTotalEntries(ev, lists)
        for i in ev.entries.indices { ev.entries[i].checked = false; ev.entries[i].used = true }
        applyReview(ev, &lists)
        for it in lists[0].items {
            XCTAssertEqual([it.stats.packed, it.stats.used, it.stats.skipped], [1, 1, 0])
        }
    }

    // JS: 'pruneSuggestions: one quiet trip is not evidence — the default is two'
    func testPruneSuggestionsOneQuietTripIsNotEvidence() {
        var lists = [newList(name: "Hike", items: [newItem(name: "First-aid kit")])]
        func once() {
            var ev = newEvent(activities: [lists[0].id])
            ev.entries = buildTotalEntries(ev, lists)
            ev.entries[0].checked = true
            ev.entries[0].used = false
            applyReview(ev, &lists)
        }
        once()
        XCTAssertEqual(pruneSuggestions(lists).count, 0, "one trip must not offer a Drop on the first-aid kit")
        once()
        let s = pruneSuggestions(lists)
        XCTAssertEqual(s.count, 1)
        XCTAssertEqual(s.first?.reason, "never-used")
        XCTAssertEqual(s.first?.times, 2)
    }

    // JS: 'pruneSuggestions: never-packed is its own signal, and says so'
    func testPruneSuggestionsNeverPackedIsItsOwnSignal() {
        var lists = [newList(name: "RV", items: [newItem(name: "Awning poles")])]
        func skip() {
            var ev = newEvent(activities: [lists[0].id])
            ev.entries = buildTotalEntries(ev, lists)
            ev.entries[0].checked = false   // never ticked...
            ev.entries[0].used = true
            var other = newItem(name: "Decoy")
            other.checked = true; other.used = true; other.sourceListId = ""; other.sourceItemId = ""
            ev.entries.append(other)        // ...but the trip WAS ticked
            applyReview(ev, &lists)
        }
        skip()
        XCTAssertEqual(pruneSuggestions(lists).count, 0, "still only one trip")
        skip()
        let s = pruneSuggestions(lists)
        XCTAssertEqual(s.count, 1)
        XCTAssertEqual(s.first?.reason, "never-packed")
        XCTAssertEqual(s.first?.times, 2)
        XCTAssertEqual(s.first?.stats.packed, 0)
    }

    // JS: 'pruneSuggestions: "Keep" still settles it for good'
    func testPruneSuggestionsKeepStillSettlesItForGood() {
        let list = newList(name: "Hike", items: [newItem(name: "Rope", stats: ItemStats(packed: 9, used: 0), keep: true)])
        XCTAssertEqual(pruneSuggestions([list]).count, 0)
    }

    // MARK: - Not in the JS suite — behaviour checked against the JS, pinned here

    func testEffectiveQtyReadsFreeTextTheWayNumberDoes() {
        XCTAssertEqual(effectiveQty(newItem(qty: "2.5")), 2.5)
        XCTAssertEqual(effectiveQty(newItem(qty: " 4 ")), 4)
        XCTAssertEqual(effectiveQty(newItem(qty: "1 pair")), 1)   // Number('1 pair') is NaN
        XCTAssertEqual(effectiveQty(newItem(qty: "0")), 1)
        XCTAssertEqual(effectiveQty(newItem(qty: "-2")), 1)
        XCTAssertEqual(effectiveQty(nil, 5), 1)
    }

    func testPackingFlagsStillCountsWhatIsSetAsideUnlikeBagLoads() {
        // packingFlags walks every entry; bagLoads walks packable(entries). As in the JS.
        let entries = [newItem(name: "Gel", weight: 100, liquid: true, skipped: true)]
        XCTAssertEqual(packingFlags(entries), PackingFlags(liquids: 1, restricted: 0, total: 1, weighed: 1, totalKg: 0.1))
        XCTAssertEqual(bagLoads(entries), [])
    }

    func testBagLoadsKnownBagsInContainersOrderThenHisOwnInFirstSeenOrder() {
        let entries = [
            newItem(name: "a", container: "Zebra sack", weight: 100), newItem(name: "b", container: "Alpha sack", weight: 100),
            newItem(name: "c", container: "Golf bag", weight: 250), newItem(name: "d", container: "Toiletry bag", weight: 50),
        ]
        XCTAssertEqual(bagLoads(entries).map { $0.container }, ["Toiletry bag", "Golf bag", "Zebra sack", "Alpha sack"])
        XCTAssertEqual(bagLoads(entries).map { $0.kg }, [0.1, 0.3, 0.1, 0.1])   // 50 g rounds UP to 0.1, 250 g to 0.3
    }

    func testPruneSuggestionsMostTimesFirstTiesInListOrder() {
        let list = newList(name: "L", items: [
            newItem(name: "two", stats: ItemStats(packed: 2)), newItem(name: "five", stats: ItemStats(skipped: 5)),
            newItem(name: "also two", stats: ItemStats(skipped: 2)),
        ])
        XCTAssertEqual(pruneSuggestions([list]).map { $0.item.name }, ["five", "two", "also two"])
    }
}
