import XCTest
@testable import PackingCore

// Ported from tests/model.test.mjs — itemMatchesEvent, listsForEvent, buildTotalEntries,
// regenerateEntries and sectionName.
final class TripBuildingTests: XCTestCase {
    override func tearDown() { PackingEnv.reset(); super.tearDown() }

    // JS: 'itemMatchesEvent: empty constraints always apply'
    func testItemMatchesEventEmptyConstraintsAlwaysApply() {
        let it = newItem(name: "Phone")
        XCTAssertEqual(itemMatchesEvent(it, newEvent(transport: "Plane", season: "Winter", catering: "self")), true)
    }

    // JS: 'itemMatchesEvent: season constraint filters'
    func testItemMatchesEventSeasonConstraintFilters() {
        let summer = newItem(name: "Sunscreen", seasons: ["Summer"])
        XCTAssertEqual(itemMatchesEvent(summer, newEvent(season: "Summer")), true)
        XCTAssertEqual(itemMatchesEvent(summer, newEvent(season: "Winter")), false)
    }

    // JS: 'itemMatchesEvent: transport + catering constraints'
    func testItemMatchesEventTransportAndCateringConstraints() {
        let rvOnly = newItem(name: "Camping stove", transports: ["RV"], catering: ["self", "mixed"])
        XCTAssertEqual(itemMatchesEvent(rvOnly, newEvent(transport: "RV", catering: "self")), true)
        XCTAssertEqual(itemMatchesEvent(rvOnly, newEvent(transport: "RV", catering: "eatout")), false)
        XCTAssertEqual(itemMatchesEvent(rvOnly, newEvent(transport: "Car", catering: "self")), false)
    }

    // JS: 'itemMatchesEvent: context applies to WET lists only'
    func testItemMatchesEventContextAppliesToWETListsOnly() {
        let raceItem = newItem(name: "Race belt", contexts: ["Race"])
        let wet = newList(name: "Run", group: "WET")
        let ga = newList(name: "Hiking", group: "GA")
        // On a WET list, the event context narrows as before.
        XCTAssertEqual(itemMatchesEvent(raceItem, newEvent(contexts: ["Race"]), wet), true)
        XCTAssertEqual(itemMatchesEvent(raceItem, newEvent(contexts: ["Indoor"]), wet), false)
        XCTAssertEqual(itemMatchesEvent(raceItem, newEvent(contexts: []), wet), true)   // no context pinned -> keep
        // On a non-WET list (or with no list), context is ignored -> the item always applies.
        XCTAssertEqual(itemMatchesEvent(raceItem, newEvent(contexts: ["Indoor"]), ga), true)
        XCTAssertEqual(itemMatchesEvent(raceItem, newEvent(contexts: ["Indoor"])), true)
    }

    // JS: 'buildTotalEntries: combines chosen lists and filters by event'
    func testBuildTotalEntriesCombinesChosenListsAndFiltersByEvent() {
        let hiking = newList(name: "Hiking", items: [
            newItem(name: "Boots", container: "Hiking backpack", phase: "week"),
            newItem(name: "Sun hat", container: "Hiking backpack", phase: "week", seasons: ["Summer"]),
        ])
        let swim = newList(name: "Swim", items: [newItem(name: "Goggles", container: "Swim bag", phase: "week")])
        let ev = newEvent(activities: [hiking.id, swim.id], season: "Winter")
        let entries = buildTotalEntries(ev, [hiking, swim])
        let names = entries.map { $0.name }.sorted()
        XCTAssertEqual(names, ["Boots", "Goggles"])   // sun hat dropped (winter)
    }

    // JS: 'buildTotalEntries: de-duplicates by name+container across lists'
    func testBuildTotalEntriesDeDuplicatesByNameAndContainerAcrossLists() {
        let a = newList(name: "A", items: [newItem(name: "Toothbrush", container: "Toiletry bag")])
        let b = newList(name: "B", items: [newItem(name: "Toothbrush", container: "Toiletry bag")])
        let ev = newEvent(activities: [a.id, b.id])
        XCTAssertEqual(buildTotalEntries(ev, [a, b]).count, 1)
    }

    // JS: 'buildTotalEntries: only includes chosen activities'
    func testBuildTotalEntriesOnlyIncludesChosenActivities() {
        let a = newList(name: "A", items: [newItem(name: "X")])
        let b = newList(name: "B", items: [newItem(name: "Y")])
        let ev = newEvent(activities: [a.id])
        XCTAssertEqual(buildTotalEntries(ev, [a, b]).map { $0.name }, ["X"])
    }

    // JS: 'listsForEvent / buildTotalEntries: the loose bin is never fed to a trip'
    func testTheLooseBinIsNeverFedToATrip() {
        let loose = newList(name: "Loose items", role: "loose", items: [newItem(name: "Sun hat")])
        let swim = newList(name: "Swim", items: [newItem(name: "Goggles", container: "Swim bag")])
        // Even if the loose list id is (wrongly) ticked as an activity, it contributes nothing.
        let ev = newEvent(activities: [loose.id, swim.id])
        XCTAssertEqual(listsForEvent(ev, [loose, swim]).map { $0.name }, ["Swim"])
        XCTAssertEqual(buildTotalEntries(ev, [loose, swim]).map { $0.name }, ["Goggles"])
    }

    // JS: 'regenerateEntries: keeps checked state and custom additions'
    func testRegenerateEntriesKeepsCheckedStateAndCustomAdditions() throws {
        let list = newList(name: "Run", items: [newItem(name: "Shoes"), newItem(name: "Watch")])
        var ev = newEvent(activities: [list.id])
        ev.entries = buildTotalEntries(ev, [list])
        // user ticks Shoes and adds a custom item
        let i = try XCTUnwrap(ev.entries.firstIndex { $0.name == "Shoes" })
        ev.entries[i].checked = true
        ev.entries.append(newItem(name: "Snacks", custom: true))

        let again = regenerateEntries(ev, [list])
        XCTAssertEqual(again.first { $0.name == "Shoes" }?.checked, true, "checked state preserved")
        XCTAssertNotNil(again.first { $0.name == "Snacks" && $0.custom }, "custom item preserved")
        XCTAssertEqual(again.filter { $0.name == "Watch" }.count, 1, "no duplicate for unchanged item")
    }

    // JS: 'regenerateEntries: adds newly matching items after a list grows'
    func testRegenerateEntriesAddsNewlyMatchingItemsAfterAListGrows() {
        var list = newList(name: "Run", items: [newItem(name: "Shoes")])
        var ev = newEvent(activities: [list.id])
        ev.entries = buildTotalEntries(ev, [list])
        list.items.append(newItem(name: "Cap"))
        let again = regenerateEntries(ev, [list])
        XCTAssertEqual(again.map { $0.name }.sorted(), ["Cap", "Shoes"])
    }

    // JS: 'buildTotalEntries: weather-tagged items stay OUT of the base list'
    func testBuildTotalEntriesWeatherTaggedItemsStayOutOfTheBaseList() {
        let list = newList(name: "Hiking", items: [
            newItem(name: "Boots"),
            newItem(name: "Rain suit", weather: ["rain"]),
        ])
        let ev = newEvent(activities: [list.id])
        let names = buildTotalEntries(ev, [list]).map { $0.name }
        XCTAssertEqual(names, ["Boots"], "rain suit is conditional, not in the base list")
    }

    // JS: 'buildTotalEntries: carries the item storage location onto trip entries'
    func testBuildTotalEntriesCarriesTheItemStorageLocationOntoTripEntries() throws {
        let list = newList(name: "Gear", items: [newItem(name: "Wetsuit", container: "Duffel bag", storage: "Garage shelf 3")])
        let ev = newEvent(activities: [list.id])
        let entry = try XCTUnwrap(buildTotalEntries(ev, [list]).first)
        XCTAssertEqual(entry.storage, "Garage shelf 3")
    }

    // JS: 'buildTotalEntries: excludes items marked "Not in use" (retired)'
    func testBuildTotalEntriesExcludesItemsMarkedNotInUse() {
        let kit = newList(name: "Kit", items: [
            newItem(name: "Tent", container: "Backpack"),
            newItem(name: "Old stove", container: "Backpack", retired: true, retiredReason: "broken"),
        ])
        let ev = newEvent(activities: [kit.id])
        let names = buildTotalEntries(ev, [kit]).map { $0.name }
        XCTAssertEqual(names, ["Tent"])   // the retired stove never joins the trip
    }

    // JS: 'sectionName + buildTotalEntries: trip line carries the section DISPLAY NAME'
    func testSectionNameAndBuildTotalEntriesTripLineCarriesTheSectionDisplayName() {
        let light = newSection("Lights")
        var list = coerceList(newList(id: "dive", name: "Diving", sections: [light], role: ""))
        let torch = newItem(name: "Head torch", section: light.id)
        XCTAssertEqual(sectionName(list, light.id), "Lights")
        list.items = [torch]
        let ev = newEvent(mode: "quick", activities: ["dive"])
        let entries = buildTotalEntries(ev, [list])
        XCTAssertEqual(entries[0].section, "Lights")   // id resolved to name for the trip
    }

    // JS: 'a kit-tagged item carries its kit onto a built trip entry'
    func testAKitTaggedItemCarriesItsKitOntoABuiltTripEntry() throws {
        let list = coerceList(newList(name: "Travel", role: "base", items: [newItem(name: "Power bank", kit: "Charging kit")]))
        let ev = newEvent(mode: "trip")
        let entries = buildTotalEntries(ev, [list])
        let e = try XCTUnwrap(entries.first { $0.name == "Power bank" })
        XCTAssertEqual(e.kit, "Charging kit")
    }

    // JS: 'an item default packer lands on the trip line buildTotalEntries makes'
    func testAnItemDefaultPackerLandsOnTheTripLine() {
        let list = newList(name: "Dive", role: "base", items: [newItem(name: "Wetsuit", packer: "Anna"), newItem(name: "Fins")])
        let entries = buildTotalEntries(newEvent(name: "Trip"), [list])
        XCTAssertEqual(entries.first { $0.name == "Wetsuit" }?.packer, "Anna")
        XCTAssertEqual(entries.first { $0.name == "Fins" }?.packer, "")   // unassigned stays anyone's
    }

    // MARK: - JS tests that lean on seedLists(), ported against an invented stand-in
    //
    // `js/seed.js` (the 200-item starter library) is not part of this package, so these
    // five cannot run on the real seed. They are the ONLY tests of the base / transport /
    // quick-mode rules, so rather than drop them they run — same assertions — on a small
    // invented set of lists with the same shape: one base list, three transport lists,
    // two activity lists.

    private func miniSeed() -> [PackList] {
        [
            newList(id: "base", name: "Common base", role: "base", items: [
                newItem(name: "Passport", container: "Carry-on / hand luggage"),
                newItem(name: "Toothbrush", container: "Toiletry bag"),
                newItem(name: "Phone charger", container: "Tech pouch"),
                newItem(name: "Umbrella", weather: ["rain"]),
            ]),
            newList(id: "t-car", name: "Car kit", role: "transport", transport: "Car", items: [
                newItem(name: "Ice scraper", container: "Other"),
                newItem(name: "Snow chains", container: "Other", weather: ["snow"]),
            ]),
            newList(id: "t-plane", name: "Plane kit", role: "transport", transport: "Plane", items: [
                newItem(name: "Neck pillow"),
            ]),
            newList(id: "t-rv", name: "RV kit", role: "transport", transport: "RV", items: [
                newItem(name: "Awning mat", container: "RV storage box", weather: ["hot"]),
                newItem(name: "Levelling blocks", container: "RV storage box"),
                newItem(name: "Water hose", container: "RV storage box"),
            ]),
            newList(id: "swim", name: "Swim", group: "WET", items: [
                newItem(name: "Goggles", container: "Swim bag"),
                newItem(name: "Swim cap", container: "Swim bag"),
            ]),
            newList(id: "run", name: "Run", group: "WET", items: [
                newItem(name: "Running shoes", container: "Triathlon bag"),
                newItem(name: "Treadmill towel", container: "Triathlon bag", contexts: ["Indoor"]),
            ]),
        ]
    }

    // JS: 'listsForEvent: always includes the base, adds only the matching transport list'
    func testListsForEventAlwaysIncludesTheBaseAddsOnlyTheMatchingTransportList() throws {
        let lists = miniSeed()
        let baseId = try XCTUnwrap(lists.first { $0.role == "base" }).id
        let rvId = try XCTUnwrap(lists.first { $0.role == "transport" && $0.transport == "RV" }).id
        let carId = try XCTUnwrap(lists.first { $0.role == "transport" && $0.transport == "Car" }).id

        let rvTrip = newEvent(activities: [], transport: "RV")
        let ids = listsForEvent(rvTrip, lists).map { $0.id }
        XCTAssertTrue(ids.contains(baseId), "common base always in")
        XCTAssertTrue(ids.contains(rvId), "RV list in for an RV trip")
        XCTAssertFalse(ids.contains(carId), "other transport lists stay out")

        let carTrip = newEvent(activities: [], transport: "Car")
        let carIds = listsForEvent(carTrip, lists).map { $0.id }
        XCTAssertTrue(carIds.contains(baseId) && carIds.contains(carId) && !carIds.contains(rvId))
    }

    // JS: 'buildTotalEntries: an RV trip with zero ticked activities still gets base + RV kit'
    func testAnRVTripWithZeroTickedActivitiesStillGetsBaseAndRVKit() throws {
        let lists = miniSeed()
        let rv = try XCTUnwrap(lists.first { $0.role == "transport" && $0.transport == "RV" })
        let rvSample = try XCTUnwrap(rv.items.first { !$0.name.isEmpty && $0.weather.isEmpty })
        let trip = newEvent(activities: [], transport: "RV", season: "Summer")
        let entries = buildTotalEntries(trip, lists)
        XCTAssertTrue(entries.count > 0, "a no-activity RV trip is not empty")
        XCTAssertTrue(entries.contains { $0.sourceListId == rv.id }, "RV items are present without ticking anything")
        XCTAssertTrue(entries.contains { $0.name == rvSample.name }, "RV item \"\(rvSample.name)\" made it in")
    }

    // JS: 'buildTotalEntries: switching transport away from RV drops the RV-only kit'
    func testSwitchingTransportAwayFromRVDropsTheRVOnlyKit() throws {
        let lists = miniSeed()
        let rv = try XCTUnwrap(lists.first { $0.role == "transport" && $0.transport == "RV" })
        let carTrip = newEvent(activities: [], transport: "Car", season: "Summer")
        let entries = buildTotalEntries(carTrip, lists)
        XCTAssertFalse(entries.contains { $0.sourceListId == rv.id }, "no RV list items on a Car trip")
    }

    // JS: 'quick mode: only the ticked activities feed the list — no base, no transport kit'
    func testQuickModeOnlyTheTickedActivitiesFeedTheList() throws {
        let lists = miniSeed()
        let swim = try XCTUnwrap(lists.first { $0.name == "Swim" })
        let baseId = try XCTUnwrap(lists.first { $0.role == "base" }).id
        let transportIds = Set(lists.filter { $0.role == "transport" }.map { $0.id })

        let quick = newEvent(mode: "quick", activities: [swim.id], transport: "RV", season: "Summer")
        let chosen = listsForEvent(quick, lists).map { $0.id }
        XCTAssertEqual(chosen, [swim.id], "quick list is exactly the ticked activity")
        XCTAssertFalse(chosen.contains(baseId), "no common base in quick mode")
        XCTAssertFalse(transportIds.contains { chosen.contains($0) }, "no transport kit in quick mode even if transport is set")

        let entries = buildTotalEntries(quick, lists)
        XCTAssertTrue(entries.count > 0 && entries.count < 40, "quick swim bag is small (\(entries.count))")
        XCTAssertTrue(entries.allSatisfy { $0.sourceListId == swim.id }, "every quick item comes from the Swim list")
    }

    // JS: 'quick vs trip: the same ticked activity yields far fewer items in quick mode'
    func testQuickVsTripTheSameTickedActivityYieldsFewerItemsInQuickMode() throws {
        let lists = miniSeed()
        let run = try XCTUnwrap(lists.first { $0.name == "Run" })
        let trip = buildTotalEntries(newEvent(mode: "trip", activities: [run.id], transport: "Car", season: "Summer", contexts: ["Outdoor"]), lists)
        let quick = buildTotalEntries(newEvent(mode: "quick", activities: [run.id], transport: "Car", season: "Summer", contexts: ["Outdoor"]), lists)
        XCTAssertTrue(quick.count < trip.count, "quick (\(quick.count)) is smaller than full trip (\(trip.count))")
        // (the stand-in also pins the WET context rule: the Indoor-only towel stays home)
        XCTAssertEqual(quick.map { $0.name }, ["Running shoes"])
    }

    // MARK: - Not in the JS suite — the shape of a built entry, pinned for the parity checker

    func testABuiltEntryCarriesOnlyTheFieldsEntryFromItemNames() throws {
        PackingEnv.freeze()
        let sec = TemplateSection(id: "s1", name: "Rig")
        let src = newItem(id: "src-1", name: "Regulator", swedish: "Regulator", qty: "2", category: "Sport gear",
                          container: "Duffel bag", phase: "daybefore", charging: true, chargeType: "usb-c",
                          shortList: true, seasons: ["Summer"], weather: [], sub: ["hose"], note: "serviced",
                          weight: 1200, liquid: true, restricted: true, perNight: true, consumable: true,
                          section: "s1", kit: "Dive kit", packer: "Anna", storage: "Garage", photos: ["p1"],
                          thumb: "data:x", stats: ItemStats(packed: 4, used: 4), manufacturer: "Apeks", keep: true)
        let list = newList(id: "dive", name: "Diving", sections: [sec], items: [src])
        let e = try XCTUnwrap(buildTotalEntries(newEvent(activities: ["dive"]), [list]).first)
        XCTAssertEqual(e.sourceListId, "dive")
        XCTAssertEqual(e.sourceItemId, "src-1")
        XCTAssertNotEqual(e.id, "src-1")
        XCTAssertEqual([e.name, e.swedish, e.qty, e.category, e.container, e.phase, e.chargeType, e.note],
                       ["Regulator", "Regulator", "2", "Sport gear", "Duffel bag", "daybefore", "usb-c", "serviced"])
        XCTAssertEqual([e.charging, e.shortList, e.liquid, e.restricted, e.perNight], [true, true, true, true, true])
        XCTAssertEqual([e.section, e.kit, e.packer, e.storage], ["Rig", "Dive kit", "Anna", "Garage"])
        XCTAssertEqual(e.sub, ["hose"])
        XCTAssertEqual(e.weight, 1200)
        // …and what does NOT cross over:
        XCTAssertEqual(e.seasons, [])
        XCTAssertEqual(e.photos, [])
        XCTAssertEqual(e.thumb, "")
        XCTAssertEqual(e.stats, ItemStats())
        XCTAssertEqual(e.manufacturer, "")
        XCTAssertFalse(e.consumable)
        XCTAssertFalse(e.keep)
        XCTAssertFalse(e.custom)
        XCTAssertFalse(e.checked)
    }

    func testRegenerateDropsAnUntouchedLineWhoseSourceNoLongerMatchesButKeepsAnEditedOne() throws {
        let list = newList(name: "Hike", items: [newItem(name: "Sun hat", seasons: ["Summer"]), newItem(name: "Gaiters", seasons: ["Summer"])])
        var ev = newEvent(activities: [list.id], season: "Summer")
        ev.entries = buildTotalEntries(ev, [list])
        let i = try XCTUnwrap(ev.entries.firstIndex { $0.name == "Gaiters" })
        ev.entries[i].edited = true
        ev.season = "Winter"
        XCTAssertEqual(regenerateEntries(ev, [list]).map { $0.name }, ["Gaiters"])
    }
}

// JS tests in this area that are NOT ported here, and why:
//  • 'seedLists: Run has an after phase, a reminder, a charging item and a short-list flag'
//    — a test of js/seed.js (it only passes the seed through buildTotalEntries). The seed
//    library is not in this package; it belongs with whoever ports seed.js.
//  • 'encodeTripLink / decodeTripLink: full round-trip…', 'encodeTripLink: returns null when
//    the payload is too large…' — use buildTotalEntries as set-up only; owned by the SHARING slice.
//  • 'buildCatalog: a trip built from resolved templates matches one built from the originals'
//    — uses buildTotalEntries as the yardstick; owned by the CATALOGUE slice (needs buildCatalog
//    and resolveTemplate, and seedLists()).
