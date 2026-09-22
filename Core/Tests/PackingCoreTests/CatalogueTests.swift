import XCTest
@testable import PackingCore

// Ported from tests/model.test.mjs — the write path of the relational core:
// applyIntrinsic, links, sections by name, the container repair, catalogItemFromResolved,
// membershipFromResolved, containerOverrideFor, buildCatalog.
//
// JS mutates (`applyIntrinsic(cat, edited)` changes `cat`); Swift returns the updated
// copy, so those lines read `cat = applyIntrinsic(cat, edited)`. The owner's first
// name in two JS tests is replaced by an invented one ("Jonas").
final class CatalogueTests: XCTestCase {
    override func tearDown() { PackingEnv.reset(); super.tearDown() }

    // MARK: buildCatalog over a whole seed

    // JS: 'buildCatalog: counts match the analysis (unique items, one membership per copy)'
    func testBuildCatalogCountsMatchTheAnalysis() {
        let lists = miniSeedLists()
        let totalCopies = lists.reduce(0) { n, l in n + l.items.filter { !jsTrim($0.name).isEmpty }.count }
        let uniqueNames = Set(lists.flatMap { l in l.items.map { normName($0.name) }.filter { !$0.isEmpty } }).count
        let c = buildCatalog(lists)
        XCTAssertEqual(c.items.count, uniqueNames)         // same-named copies merged into one catalog item
        XCTAssertEqual(c.memberships.count, totalCopies)   // one membership per original copy
        XCTAssertEqual(c.templates.count, lists.count)
        XCTAssertTrue(c.templates.allSatisfy { $0.items.isEmpty })   // templates no longer hold inline items
        XCTAssertLessThan(uniqueNames, totalCopies)        // (the fixture really does repeat names)
    }

    // JS: 'buildCatalog: resolving a template reproduces each copy\'s container / phase / conditions'
    func testBuildCatalogResolvingATemplateReproducesEachCopy() throws {
        let lists = miniSeedLists()
        let c = buildCatalog(lists)
        let byId = Dictionary(uniqueKeysWithValues: c.items.map { ($0.id, $0) })
        for orig in lists {
            let tmpl = try XCTUnwrap(c.templates.first { $0.id == orig.id })
            let resolved = resolveTemplateItems(tmpl, byId, c.memberships)
            // match resolved items back to originals by (name, container) — contextual fidelity
            for o in orig.items {
                if jsTrim(o.name).isEmpty { continue }
                let r = try XCTUnwrap(
                    resolved.first { $0.name.lowercased() == o.name.lowercased() && $0.container == o.container && $0.phase == o.phase },
                    "no resolved match for \"\(o.name)\" (\(o.container)/\(o.phase)) in \(orig.name)")
                XCTAssertEqual(r.seasons, o.seasons)
                XCTAssertEqual(r.contexts, o.contexts)
                XCTAssertEqual(r.transports, o.transports)
                XCTAssertEqual(r.weather, o.weather)
            }
        }
    }

    // JS: 'buildCatalog: a trip built from resolved templates matches one built from the originals'
    // (REDUCED — see the note at the bottom: `buildTotalEntries` is the trip section's.)
    func testBuildCatalogResolvedTemplatesCarryWhatATripIsBuiltFrom() throws {
        let lists = miniSeedLists()
        let c = buildCatalog(lists)
        let byId = Dictionary(uniqueKeysWithValues: c.items.map { ($0.id, $0) })
        let resolvedLists = c.templates.map { resolveTemplate($0, byId, c.memberships) }
        func key(_ e: Item) -> String {
            "\(e.name.lowercased())|\(e.container)|\(e.phase)|\(e.itemType)|\(e.seasons)|\(e.contexts)|\(e.transports)|\(e.catering)|\(e.weather)"
        }
        for orig in lists {
            let back = try XCTUnwrap(resolvedLists.first { $0.id == orig.id })
            XCTAssertEqual(back.items.map(key).sorted(), orig.items.filter { !jsTrim($0.name).isEmpty }.map(key).sorted(), orig.name)
            XCTAssertEqual([back.name, back.group, back.role, back.transport], [orig.name, orig.group, orig.role, orig.transport])
        }
    }

    // JS: 'buildCatalog: per-template container override (Socks default vs Travel/RV)'
    func testBuildCatalogPerTemplateContainerOverride() throws {
        let c = buildCatalog(miniSeedLists())
        let socks = try XCTUnwrap(c.items.first { $0.name.lowercased() == "socks" })
        let socksMems = c.memberships.filter { $0.itemId == socks.id }
        XCTAssertGreaterThanOrEqual(socksMems.count, 3)                       // Socks lives in several templates
        XCTAssertTrue(socksMems.contains { $0.container == "" })              // at least one uses the default
        XCTAssertTrue(socksMems.contains { !$0.container.isEmpty && $0.container != socks.container })   // at least one overrides
    }

    // JS: 'buildCatalog: itemType override preserves the Bike "after" reminders'
    func testBuildCatalogItemTypeOverridePreservesTheBikeAfterReminders() throws {
        let c = buildCatalog(miniSeedLists())
        let bike = try XCTUnwrap(c.templates.first { $0.name == "Bike" })
        let swim = try XCTUnwrap(c.templates.first { $0.name == "Swim" })
        let bikeTowel = try XCTUnwrap(resolveTemplateItems(bike, c.items, c.memberships).first { $0.name == "Towel" })
        let swimTowel = try XCTUnwrap(resolveTemplateItems(swim, c.items, c.memberships).first { $0.name == "Towel" })
        XCTAssertEqual(bikeTowel.itemType, "reminder")   // Bike keeps its after-list reminder behavior
        XCTAssertEqual(swimTowel.itemType, "item")       // same catalog item, shown as a packable item in Swim
    }

    // MARK: membershipFromResolved

    // JS: 'membershipFromResolved: stores the per-list exception the editor states'
    func testMembershipFromResolvedStoresThePerListExceptionTheEditorStates() {
        let cat = newItem(name: "Socks", container: "Duffel bag", phase: "week", itemType: "item")
        var resolved = resolveMembership(cat, newMembership(itemId: cat.id, templateId: "t1"))
        resolved.ovContainer = "Checked luggage"   // user sets an exception for THIS list
        resolved.container = "Checked luggage"     // …and the effective value follows
        resolved.seasons = ["Summer"]              // and adds a condition
        let m = membershipFromResolved(cat, "t1", resolved, 3)
        XCTAssertEqual(m.container, "Checked luggage")   // an exception was asked for -> stored
        XCTAssertEqual(m.phase, "")                      // no exception -> follows the item default
        XCTAssertEqual(m.seasons, ["Summer"])
        XCTAssertEqual(m.order, 3)
        // round-trips back to the same resolved values
        let back = resolveMembership(cat, m)
        XCTAssertEqual(back.container, "Checked luggage")
        XCTAssertEqual(back.phase, "week")
        XCTAssertEqual(back.seasons, ["Summer"])
    }

    // JS: 'membershipFromResolved: clearing the exception falls back to the item default'
    func testMembershipFromResolvedClearingTheExceptionFallsBackToTheItemDefault() {
        let cat = newItem(name: "Socks", container: "Duffel bag")
        let m0 = newMembership(itemId: cat.id, templateId: "t1", container: "Checked luggage")
        var resolved = resolveMembership(cat, m0)
        XCTAssertEqual(resolved.container, "Checked luggage")
        resolved.ovContainer = ""                        // "— use the default —"
        let m = membershipFromResolved(cat, "t1", resolved, 0, m0)
        XCTAssertEqual(m.container, "")
        XCTAssertEqual(m.id, m0.id)                      // (the existing membership keeps its id)
        XCTAssertEqual(resolveMembership(cat, m).container, "Duffel bag")
    }

    // JS: 'a freshly built item (no exception channel) still infers its override'
    func testAFreshlyBuiltItemStillInfersItsOverride() {
        // Paths that hand-build an item never went through resolveMembership, so they
        // carry no `_ovContainer`. Those must keep working the old way.
        let cat = newItem(name: "Socks", container: "Duffel bag")
        let raw = newItem(name: "Socks", container: "Checked luggage")
        let m = membershipFromResolved(cat, "t1", raw, 0)
        XCTAssertEqual(m.container, "Checked luggage")
    }

    // JS: 'membership round-trip: section id survives resolve -> save'
    func testMembershipRoundTripSectionIdSurvivesResolveSave() {
        let item = newItem(name: "Head torch")
        let m = newMembership(itemId: item.id, templateId: "t1", section: "s-lights")
        let resolved = resolveMembership(item, m)
        XCTAssertEqual(resolved.section, "s-lights")            // read onto the resolved item
        let back = membershipFromResolved(item, "t1", resolved, 0, nil)
        XCTAssertEqual(back.section, "s-lights")                // written back to the membership
        // No section -> stays empty, and it is NOT an intrinsic item default.
        XCTAssertEqual(resolveMembership(item, newMembership(itemId: item.id, templateId: "t2")).section, "")
        XCTAssertEqual(item.section, "")
    }

    // JS: 'kit is a membership override, not a catalog default'
    func testKitIsAMembershipOverrideNotACatalogDefault() {
        let resolved = newItem(name: "Plug", kit: "Charging kit")
        let cat = catalogItemFromResolved(resolved)
        XCTAssertEqual(cat.kit, "")   // never sticks to the shared item
        let m = membershipFromResolved(cat, "t1", resolved, 0)
        XCTAssertEqual(m.kit, "Charging kit")   // it lives on the membership
    }

    // MARK: applyIntrinsic, catalogItemFromResolved

    // JS: 'applyIntrinsic: shared-item edits propagate; container/phase defaults are left alone'
    func testApplyIntrinsicSharedItemEditsPropagate() {
        var cat = newItem(name: "Jacket", category: "Clothing", container: "Duffel bag", phase: "week", weight: 0)
        var edited = resolveMembership(cat, newMembership(itemId: cat.id, templateId: "t1", container: "Checked luggage"))
        edited.category = "Adventure clothing"   // intrinsic edit
        edited.weight = 620                      // intrinsic edit
        cat = applyIntrinsic(cat, edited)
        XCTAssertEqual(cat.category, "Adventure clothing")   // propagates to the shared item
        XCTAssertEqual(cat.weight, 620)
        XCTAssertEqual(cat.container, "Duffel bag")          // the DEFAULT is untouched by an override edit
        XCTAssertEqual(cat.phase, "week")
    }

    // JS: 'catalogItemFromResolved: a new item takes its own container/phase as defaults'
    func testCatalogItemFromResolvedTakesItsOwnContainerAndPhaseAsDefaults() {
        let it = newItem(name: "New gadget", category: "Electronics", container: "Tech pouch", phase: "daybefore")
        let cat = catalogItemFromResolved(it)
        XCTAssertEqual(cat.container, "Tech pouch")
        XCTAssertEqual(cat.phase, "daybefore")
        XCTAssertEqual(cat.category, "Electronics")
    }

    // JS: 'applyIntrinsic: metadata edits propagate to the shared catalog item'
    func testApplyIntrinsicMetadataEditsPropagate() {
        var cat = newItem(name: "Jacket")
        var edited = resolveMembership(cat, newMembership(itemId: cat.id, templateId: "t1"))
        edited.color = "Navy"; edited.size = "M"; edited.manufacturer = "Patagonia"; edited.model = "Nano Puff"
        edited.ownedBy = "Jonas"; edited.acquired = "2025-12-01"; edited.price = 199.95; edited.currency = "EUR"
        edited.purchaseLink = "https://x.example"; edited.expiry = "2030-01-01"; edited.condition = "good"
        edited.retired = true; edited.retiredReason = "replaced"; edited.serial = "SN-42"; edited.qtyOwned = 2
        edited.warranty = "2027-01-01"
        cat = applyIntrinsic(cat, edited)
        XCTAssertEqual(cat.color, "Navy")
        XCTAssertEqual(cat.manufacturer, "Patagonia")
        XCTAssertEqual(cat.ownedBy, "Jonas")
        XCTAssertEqual(cat.price, 199.95)
        XCTAssertEqual(cat.currency, "EUR")
        XCTAssertEqual(cat.condition, "good")
        XCTAssertEqual(cat.retired, true)
        XCTAssertEqual(cat.retiredReason, "replaced")
        XCTAssertEqual(cat.qtyOwned, 2)
        XCTAssertEqual(cat.warranty, "2027-01-01")
    }

    // JS: 'capacityL + maxKg round-trip through the catalog'
    func testCapacityAndMaxKgRoundTripThroughTheCatalog() {
        let bag = newItem(name: "Osprey 40", capacityL: 40, maxKg: 8)
        XCTAssertEqual(bag.capacityL, 40)
        XCTAssertEqual(bag.maxKg, 8)
        let m = newMembership(itemId: bag.id, templateId: "c1")
        let back = membershipFromResolved(bag, "c1", resolveMembership(bag, m), 0, m)
        let rebuilt = resolveMembership(applyIntrinsic(newItem(name: "Osprey 40"), bag), back)
        XCTAssertEqual(rebuilt.capacityL, 40)
        XCTAssertEqual(rebuilt.maxKg, 8)
    }

    // JS: 'packer is intrinsic: an item default reaches the catalog and every trip built from it'
    func testPackerIsIntrinsic() {
        XCTAssertTrue(INTRINSIC_FIELDS.contains("packer"))
        let cat = catalogItemFromResolved(newItem(name: "Wetsuit", packer: "Anna"))
        XCTAssertEqual(cat.packer, "Anna")
        // A later edit in the item editor pushes the new answer onto the shared item.
        XCTAssertEqual(applyIntrinsic(cat, json: ["packer": "Jonas"]).packer, "Jonas")
        // …and clearing it back to "anyone" must actually clear it ('' , not undefined).
        XCTAssertEqual(applyIntrinsic(cat, json: ["packer": ""]).packer, "")
    }

    // JS: 'a per-list link carries no packer of its own — the shared item stays the answer'
    func testAPerListLinkCarriesNoPackerOfItsOwn() {
        let link = linkFromResolved(newItem(name: "Wetsuit", packer: "Anna"), "item-1")
        // JS: `link.packer === undefined`. Here: blank, and flagged as a link — which is
        // what makes applyIntrinsic pass over it.
        XCTAssertEqual(link.packer, "")
        XCTAssertTrue(link.link)
        XCTAssertEqual(applyIntrinsic(newItem(name: "Wetsuit", packer: "Anna"), link).packer, "Anna")
    }

    // JS: 'thumb + photo ids survive the catalog round-trip (edit propagates everywhere)'
    func testThumbAndPhotoIdsSurviveTheCatalogRoundTrip() {
        let src = newItem(name: "Lamp", photos: ["id-7"], thumb: CATALOGUE_DATA_URL)
        let cat = catalogItemFromResolved(src)
        XCTAssertEqual(cat.photos, ["id-7"])
        XCTAssertEqual(cat.thumb, CATALOGUE_DATA_URL)
        // An edit to the shared item must carry both fields through applyIntrinsic.
        let edited = newItem(name: "Lamp", photos: ["id-7", "id-8"], thumb: "data:image/jpeg;base64,QQ==")
        let back = applyIntrinsic(cat, edited)
        XCTAssertEqual(back.photos, ["id-7", "id-8"])
        XCTAssertEqual(back.thumb, "data:image/jpeg;base64,QQ==")
    }

    // MARK: buildCatalog, item by item

    // JS: 'buildCatalog: item metadata survives the migration round-trip'
    func testBuildCatalogItemMetadataSurvivesTheMigrationRoundTrip() throws {
        let lists = [newList(name: "Travel", items: [
            newItem(name: "Backpack", color: "Black", manufacturer: "Osprey", price: 250, currency: "USD", condition: "good"),
        ])]
        let bag = try XCTUnwrap(buildCatalog(lists).items.first { $0.name == "Backpack" })
        XCTAssertEqual(bag.manufacturer, "Osprey")
        XCTAssertEqual(bag.color, "Black")
        XCTAssertEqual(bag.price, 250)
        XCTAssertEqual(bag.currency, "USD")
        XCTAssertEqual(bag.condition, "good")
    }

    // JS: 'buildCatalog: section survives the migration round-trip'
    func testBuildCatalogSectionSurvivesTheMigrationRoundTrip() throws {
        let light = newSection("Lights")
        let list = coerceList(newList(id: "dive", name: "Diving", sections: [light],
                                      items: [newItem(name: "Head torch", section: light.id)]))
        let c = buildCatalog([list])
        let tmpl = try XCTUnwrap(c.templates.first { $0.id == "dive" })
        XCTAssertEqual(tmpl.sections.map { $0.name }, ["Lights"])
        let resolved = resolveTemplateItems(tmpl, Dictionary(uniqueKeysWithValues: c.items.map { ($0.id, $0) }), c.memberships)
        XCTAssertEqual(resolved[0].section, light.id)        // membership kept the section id
    }

    // Regression: a replace-import and every snapshot restore rebuild the catalog
    // through buildCatalog(). Photos and the care record are intrinsic to the object,
    // so they MUST survive that rebuild — they used to be dropped silently, which
    // quietly stripped every picture and maintenance schedule from a restore.
    // JS: 'buildCatalog keeps photos, thumb and the care record through a restore'
    func testBuildCatalogKeepsPhotosThumbAndTheCareRecordThroughARestore() throws {
        let withPhoto = newItem(
            name: "Dive light", photos: ["pid-1", "pid-2"], thumb: CATALOGUE_DATA_URL,
            maintenance: Maintenance(notes: "rinse in fresh water", intervalDays: 90, lastDone: "2026-06-01", log: []))
        let lists = [newList(name: "Diving", items: [withPhoto])]
        let back = try XCTUnwrap(buildCatalog(lists).items.first { $0.name == "Dive light" })
        XCTAssertEqual(back.photos, ["pid-1", "pid-2"])
        XCTAssertEqual(back.thumb, CATALOGUE_DATA_URL)
        let care = try XCTUnwrap(back.maintenance, "the care record must survive the rebuild")
        XCTAssertEqual(care.intervalDays, 90)
        XCTAssertEqual(care.notes, "rinse in fresh water")
    }

    // JS: 'buildCatalog merges same-named copies without losing the one that has a photo'
    func testBuildCatalogMergesSameNamedCopiesWithoutLosingTheOneThatHasAPhoto() {
        let bare = newItem(name: "Torch")
        let rich = newItem(name: "Torch", photos: ["pid-9"], thumb: CATALOGUE_DATA_URL)
        let c = buildCatalog([
            newList(name: "A", items: [bare]),
            newList(name: "B", items: [rich]),
        ])
        let merged = c.items.filter { $0.name == "Torch" }
        XCTAssertEqual(merged.count, 1, "same-named items merge into one catalog entry")
        XCTAssertEqual(merged[0].photos, ["pid-9"])
        XCTAssertEqual(merged[0].thumb, CATALOGUE_DATA_URL)
    }

    // JS: 'buildCatalog: the owner survives being rebuilt from a backup'
    func testBuildCatalogTheOwnerSurvivesBeingRebuiltFromABackup() throws {
        // Two copies of one item, as a pre-relational backup file holds them: the owner
        // is on one copy only and must not be lost when they are merged back into one.
        let list = coerceList(PackList(id: "l1", name: "Travel", items: [newItem(name: "Jacket", ownedBy: "")]))
        let other = coerceList(PackList(id: "l2", name: "Hiking", items: [newItem(name: "Jacket", ownedBy: "Anna")]))
        let c = buildCatalog([list, other])
        let jacket = try XCTUnwrap(c.items.first { $0.name == "Jacket" })
        XCTAssertEqual(jacket.ownedBy, "Anna")
    }

    // JS: 'buildCatalog: a template default cannot swallow a row that differs from it'
    func testBuildCatalogATemplateDefaultCannotSwallowARowThatDiffersFromIt() {
        // The restore path runs through buildCatalog. Hiking packs into the backpack by
        // default, but these wipes live in the duffel — that must survive a round-trip.
        let lists = [
            coerceList(PackList(id: "hiking", name: "Hiking", defaultContainer: "Hiking backpack",
                                items: [newItem(name: "Hand-sanitizer wipes", container: "Duffel bag")])),
            coerceList(PackList(id: "travel", name: "Travel",
                                items: [newItem(name: "Hand-sanitizer wipes", container: "Carry-on / hand luggage")])),
        ]
        let cat = buildCatalog(lists)
        var rebuilt: [String: String] = [:]
        for t in cat.templates {
            for it in resolveTemplateItems(t, cat.items, cat.memberships) { rebuilt[t.name] = it.container }
        }
        XCTAssertEqual(rebuilt["Hiking"], "Duffel bag", "the row must not be captured by the template default")
        XCTAssertEqual(rebuilt["Travel"], "Carry-on / hand luggage")
    }

    // MARK: v108 — one physical item, shared properly
    // These lock shut the bug where putting an item into a second template wrote a
    // half-filled copy over the SHARED item and erased its photos, care record and
    // purchase details everywhere at once.

    // JS: 'linkFromResolved: joining another template cannot touch the shared item'
    func testLinkFromResolvedJoiningAnotherTemplateCannotTouchTheSharedItem() {
        var cat = catalogueRichItem()
        let before = cat.json
        let link = linkFromResolved(cat, cat.id)
        cat = applyIntrinsic(cat, link)            // exactly what saveList does with the link
        for f in INTRINSIC_FIELDS {
            if f == "name" { continue }            // the link carries the name, unchanged
            XCTAssertEqual(cat.json[f], before[f], "link erased the shared item's \"\(f)\"")
        }
        XCTAssertEqual(cat.json["container"], before["container"], "link erased the container default")
        XCTAssertEqual(cat.json, before)           // (nothing at all moved)
    }

    // JS: 'linkFromResolved: carries the per-list choices and links by id'
    func testLinkFromResolvedCarriesThePerListChoicesAndLinksById() {
        let cat = catalogueRichItem()
        var src = cat
        src.seasons = ["Summer"]; src.note = "in the side pocket"; src.qty = "2"; src.kit = "Camera kit"
        let link = linkFromResolved(src, cat.id)
        XCTAssertEqual(link.itemId, cat.id)
        XCTAssertEqual(link.link, true)
        XCTAssertEqual(link.seasons, ["Summer"])
        XCTAssertEqual(link.note, "in the side pocket")
        XCTAssertEqual(link.qty, "2")
        XCTAssertEqual(link.kit, "Camera kit")
        XCTAssertEqual(link.ovContainer, "", "a new home starts with no exception")
        XCTAssertEqual(link.ovPhase, "")
        // and it carries NONE of the intrinsic detail, so there is nothing to overwrite with.
        // (JS: every such field is `undefined`. Here: each one holds what a BLANK item
        // holds — never the source's value — and `link` says "do not read them".)
        let blank = Item(json: [:]).json
        for f in INTRINSIC_FIELDS {
            if f == "name" { continue }
            XCTAssertEqual(link.json[f], blank[f], "a link must not carry \"\(f)\"")
        }
    }

    // JS: 'applyIntrinsic: an absent field is left alone, an empty one still clears'
    func testApplyIntrinsicAnAbsentFieldIsLeftAloneAnEmptyOneStillClears() {
        var cat = catalogueRichItem()
        cat = applyIntrinsic(cat, json: ["serial": ""])       // deliberate clear
        XCTAssertEqual(cat.serial, "")
        XCTAssertEqual(cat.manufacturer, "Insta360")          // untouched, not wiped
        XCTAssertEqual(cat.photos, ["photo-abc123"])
    }

    // JS: 'editing an item in one template propagates to every other template'
    func testEditingAnItemInOneTemplatePropagatesToEveryOtherTemplate() {
        var cat = catalogueRichItem()
        let mTravel = newMembership(itemId: cat.id, templateId: "travel")
        let mHiking = newMembership(itemId: cat.id, templateId: "hiking")
        // Open it in Travel and change things under "① The item itself".
        var edited = resolveMembership(cat, mTravel)
        edited.storage = "Camera shelf"
        edited.weight = 210
        edited.defContainer = "Carry-on / hand luggage"   // the ① default, not an exception
        cat = applyIntrinsic(cat, edited)
        let hiking = resolveMembership(cat, mHiking)
        XCTAssertEqual(hiking.storage, "Camera shelf")
        XCTAssertEqual(hiking.weight, 210)
        XCTAssertEqual(hiking.container, "Carry-on / hand luggage", "the container default must travel too")
    }

    // JS: 'a per-list exception survives an edit to the shared default'
    func testAPerListExceptionSurvivesAnEditToTheSharedDefault() {
        var cat = newItem(name: "Sunglasses", container: "Duffel bag")
        let mHiking = newMembership(itemId: cat.id, templateId: "hiking", container: "Hiking backpack")
        var edited = resolveMembership(cat, newMembership(itemId: cat.id, templateId: "travel"))
        edited.defContainer = "Carry-on / hand luggage"
        cat = applyIntrinsic(cat, edited)
        XCTAssertEqual(cat.container, "Carry-on / hand luggage")
        XCTAssertEqual(resolveMembership(cat, mHiking).container, "Hiking backpack", "the exception still wins")
    }

    // JS: 'itemFromEntry: promoting a trip one-off keeps its photo and care record'
    func testItemFromEntryKeepsItsPhotoAndCareRecord() {
        let entry = newItem(
            name: "Beach umbrella", container: "Checked luggage", seasons: ["Summer"],
            photos: ["photo-xyz"], thumb: "data:image/jpeg;base64,BBBB",
            maintenance: Maintenance(intervalDays: 365), price: 300)
        let it = itemFromEntry(entry)
        XCTAssertEqual(it.photos, ["photo-xyz"])
        XCTAssertEqual(it.thumb, "data:image/jpeg;base64,BBBB")
        XCTAssertEqual(it.maintenance?.intervalDays, 365)
        XCTAssertEqual(it.price, 300)
        XCTAssertEqual(it.seasons, ["Summer"], "and its conditions come along")
    }

    // MARK: the container repair

    // JS: 'containerDefaultsFrom: the most-used container wins, ties go to first seen'
    func testContainerDefaultsFromTheMostUsedContainerWins() {
        let d = containerDefaultsFrom([
            ContainerRow(itemId: "a", container: "Duffel bag"),
            ContainerRow(itemId: "a", container: "Duffel bag"),
            ContainerRow(itemId: "a", container: "Carry-on / hand luggage"),
            ContainerRow(itemId: "b", container: "Golf bag"),
            ContainerRow(itemId: "b", container: "Checked luggage"),
        ])
        XCTAssertEqual(d.get("a"), "Duffel bag")
        XCTAssertEqual(d.get("b"), "Golf bag")       // 1-1 tie -> the one seen first
        XCTAssertEqual(d.map { $0.itemId }, ["a", "b"])   // (the Map's insertion order)
    }

    // JS: 'the container migration never moves an item on any list'
    func testTheContainerMigrationNeverMovesAnItemOnAnyList() {
        var cat = newItem(name: "Sunglasses", container: "Day pack")   // frozen birth default
        var mems = [
            newMembership(itemId: cat.id, templateId: "golf", container: "Duffel bag"),
            newMembership(itemId: cat.id, templateId: "run", container: "Duffel bag"),
            newMembership(itemId: cat.id, templateId: "hiking", container: "Hiking backpack"),
            newMembership(itemId: cat.id, templateId: "car", container: ""),   // followed the old default
        ]
        let before = mems.map { resolveMembership(cat, $0).container }
        // …the migration, exactly as db.js runs it
        let rows = mems.map { ContainerRow(itemId: $0.itemId, container: !$0.container.isEmpty ? $0.container : cat.container) }
        let defaults = containerDefaultsFrom(rows)
        cat.container = defaults.get(cat.id) ?? ""
        for i in mems.indices {
            let eff = !mems[i].container.isEmpty ? mems[i].container : "Day pack"
            mems[i].container = eff == defaults.get(mems[i].itemId) ? "" : eff
        }
        XCTAssertEqual(cat.container, "Duffel bag", "the container it actually uses most becomes the default")
        let after = mems.map { resolveMembership(cat, $0).container }
        XCTAssertEqual(after, before, "every list must still show exactly what it showed")
    }

    // JS: 'planContainerMigration: reads every row BEFORE rewriting any default'
    func testPlanContainerMigrationReadsEveryRowBeforeRewritingAnyDefault() throws {
        // The trap: "Sunglasses" is born in the Day pack, and the Car list has no
        // override so it simply follows that default. Once the default becomes
        // "Duffel bag", anything that recomputed the Car row's old value by reading the
        // item would get "Duffel bag" — and the row would silently move.
        var cat = newItem(name: "Sunglasses", container: "Day pack")
        var mems = [
            newMembership(itemId: cat.id, templateId: "golf", container: "Duffel bag"),
            newMembership(itemId: cat.id, templateId: "run", container: "Duffel bag"),
            newMembership(itemId: cat.id, templateId: "car", container: ""),   // follows the default
        ]
        let before = mems.map { resolveMembership(cat, $0).container }
        let plan = planContainerMigration([cat], mems)

        XCTAssertEqual(plan.defaults.get(cat.id), "Duffel bag")
        // The Car row must be given "Day pack" as an explicit exception, NOT left empty.
        let carChange = try XCTUnwrap(plan.memChanges.first { $0.id == mems[2].id },
                                      "the row that relied on the old default must be pinned")
        XCTAssertEqual(carChange.container, "Day pack")
        XCTAssertEqual(plan.effective.map { $0.container }, before)   // (the snapshot is what every row showed)

        // Apply the plan and confirm nothing moved.
        for c in plan.itemChanges { cat.container = c.container }
        for c in plan.memChanges {
            let i = try XCTUnwrap(mems.firstIndex { $0.id == c.id })
            mems[i].container = c.container
        }
        XCTAssertEqual(mems.map { resolveMembership(cat, $0).container }, before)
    }

    // JS: 'planContainerMigration: is idempotent and leaves settled data alone'
    func testPlanContainerMigrationIsIdempotentAndLeavesSettledDataAlone() {
        let cat = newItem(name: "Socks", container: "Duffel bag")
        let mems = [
            newMembership(itemId: cat.id, templateId: "a", container: ""),
            newMembership(itemId: cat.id, templateId: "b", container: ""),
            newMembership(itemId: cat.id, templateId: "c", container: "RV storage box"),
        ]
        let p1 = planContainerMigration([cat], mems)
        XCTAssertEqual(p1.itemChanges, [], "the default is already the most-used one")
        XCTAssertEqual(p1.memChanges, [], "and every exception is already correct")
    }

    // JS: 'planContainerMigration: an item with no memberships is left untouched'
    func testPlanContainerMigrationAnItemWithNoMembershipsIsLeftUntouched() {
        let cat = newItem(name: "Orphan", container: "Day pack")
        let plan = planContainerMigration([cat], [])
        XCTAssertEqual(plan.itemChanges, [])
        XCTAssertEqual(plan.memChanges, [])
    }

    // JS: 'containerOverrideFor: an exception is only kept when the fallback misses'
    func testContainerOverrideForAnExceptionIsOnlyKeptWhenTheFallbackMisses() {
        // No template default: compare against the item's own.
        XCTAssertEqual(containerOverrideFor("Duffel bag", "", "Duffel bag"), "")
        XCTAssertEqual(containerOverrideFor("Golf bag", "", "Duffel bag"), "Golf bag")
        // With a template default, THAT is what the row would fall back to.
        XCTAssertEqual(containerOverrideFor("Hiking backpack", "Hiking backpack", "Duffel bag"), "")
        XCTAssertEqual(containerOverrideFor("Duffel bag", "Hiking backpack", "Duffel bag"), "Duffel bag",
                       "must stay an exception — the template default would otherwise capture this row")
    }

    // JS: 'planContainerMigration: respects a template default when re-run after a restore'
    func testPlanContainerMigrationRespectsATemplateDefaultWhenReRunAfterARestore() {
        var cat = newItem(name: "Wipes", container: "Duffel bag")
        var mems = [newMembership(itemId: cat.id, templateId: "hiking", container: "Duffel bag")]
        let tmpls = [PackList(id: "hiking", defaultContainer: "Hiking backpack")]
        let before = "Duffel bag"
        let plan = planContainerMigration([cat], mems, tmpls)
        for c in plan.itemChanges { cat.container = c.container }
        for c in plan.memChanges { mems[0].container = c.container }
        let after = resolveMembership(cat, mems[0], templateDefaults(tmpls[0])).container
        XCTAssertEqual(after, before, "re-running the repair must not move a row onto the template default")
    }

    // MARK: sections travel by name

    // JS: 'a link never carries a foreign section id'
    func testALinkNeverCarriesAForeignSectionId() {
        let src = newItem(name: "Insta360 X4", section: "sec-belonging-to-travel")
        let link = linkFromResolved(src, "item-1")
        XCTAssertEqual(link.section, "", "a section id from another template means nothing here")
    }

    // JS: 'mapSectionAcrossTemplates: the section travels by name, not by id'
    func testMapSectionAcrossTemplatesTheSectionTravelsByName() throws {
        let travel = try XCTUnwrap(coerceList(json: ["id": "travel", "name": "Travel",
            "sections": [["id": "s-tv-1", "name": "Electronics"], ["id": "s-tv-2", "name": "Toiletries"]]]))
        let hiking = try XCTUnwrap(coerceList(json: ["id": "hiking", "name": "Hiking",
            "sections": [["id": "s-hk-9", "name": "electronics"], ["id": "s-hk-8", "name": "Lights"]]]))
        // same name, different id -> lands in the destination's own section
        XCTAssertEqual(mapSectionAcrossTemplates("s-tv-1", travel, hiking), "s-hk-9")
        // no such section over there -> Ungrouped, never invented
        XCTAssertEqual(mapSectionAcrossTemplates("s-tv-2", travel, hiking), "")
        XCTAssertEqual(hiking.sections.count, 2, "the destination must not gain a section")
        // unsectioned stays unsectioned; an unknown id is not carried
        XCTAssertEqual(mapSectionAcrossTemplates("", travel, hiking), "")
        XCTAssertEqual(mapSectionAcrossTemplates("nonsense", travel, hiking), "")
    }

    // JS: 'a mapped section is the one the link actually stores'
    func testAMappedSectionIsTheOneTheLinkActuallyStores() throws {
        let travel = try XCTUnwrap(coerceList(json: ["id": "travel", "name": "Travel", "sections": [["id": "s-tv-1", "name": "Electronics"]]]))
        let hiking = try XCTUnwrap(coerceList(json: ["id": "hiking", "name": "Hiking", "sections": [["id": "s-hk-9", "name": "Electronics"]]]))
        let src = newItem(name: "Insta360 X4", section: "s-tv-1")
        let link = linkFromResolved(src, "item-1", section: mapSectionAcrossTemplates(src.section, travel, hiking))
        XCTAssertEqual(link.section, "s-hk-9")
        // and it survives the decompose into a membership
        let cat = newItem(name: "Insta360 X4")
        let m = membershipFromResolved(cat, "hiking", link, 0)
        XCTAssertEqual(m.section, "s-hk-9")
        XCTAssertEqual(resolveMembership(cat, m).section, "s-hk-9")
    }

    // MARK: --- not in the JS suite ---

    // The precedence rules once more, from the membership's side: what a LINK stores.
    func testALinkStoresNoExceptionWhateverItsBlankFieldsSay() {
        let cat = newItem(name: "Tent", container: "Duffel bag", phase: "daybefore", itemType: "item")
        let link = linkFromResolved(cat, cat.id)
        let m = membershipFromResolved(cat, "hiking", link, 2)
        XCTAssertEqual([m.container, m.phase, m.itemType], ["", "", ""])
        XCTAssertEqual(m.itemId, cat.id)
        XCTAssertEqual(m.order, 2)
        // Even a hand-made link with no `_ov…` channel infers nothing from its blanks.
        var bare = link
        bare.ovContainer = nil; bare.ovPhase = nil
        let m2 = membershipFromResolved(cat, "hiking", bare, 0)
        XCTAssertEqual([m2.container, m2.phase], ["", ""])
        // And resolving it lands on the template default, then the item's own.
        XCTAssertEqual(resolveMembership(cat, m, TemplateDefaults(container: "Hiking backpack")).container, "Hiking backpack")
        XCTAssertEqual(resolveMembership(cat, m).container, "Duffel bag")
        XCTAssertEqual(resolveMembership(cat, m).phase, "daybefore")
    }

    // The "When" precedence: the item's default, one list's exception, and an edit of
    // the default that must not disturb the exception.
    func testPhaseDefaultAndExceptionKeepToTheirOwnScope() {
        var cat = newItem(name: "Charger", phase: "week")
        var inTravel = resolveMembership(cat, newMembership(itemId: cat.id, templateId: "travel"))
        XCTAssertEqual([inTravel.phase, inTravel.ovPhase, inTravel.defPhase], ["week", "", "week"])
        inTravel.ovPhase = "morning"; inTravel.phase = "morning"          // this list's exception
        let mTravel = membershipFromResolved(cat, "travel", inTravel, 0)
        XCTAssertEqual(mTravel.phase, "morning")
        cat = applyIntrinsic(cat, inTravel)
        XCTAssertEqual(cat.phase, "week", "an exception must never leak into the item's default")
        var inHiking = resolveMembership(cat, newMembership(itemId: cat.id, templateId: "hiking"))
        inHiking.defPhase = "daybefore"                                   // the item's own default, edited
        cat = applyIntrinsic(cat, inHiking)
        XCTAssertEqual(cat.phase, "daybefore")
        XCTAssertEqual(resolveMembership(cat, mTravel).phase, "morning")  // the exception still wins
        XCTAssertEqual(membershipFromResolved(cat, "hiking", resolveMembership(cat, newMembership(itemId: cat.id, templateId: "hiking")), 0).phase, "")
    }

    func testApplyIntrinsicJsonFormNullClearsAndUnknownKeysSurvive() {
        let cat = newItem(name: "Stove", weight: 450, photos: ["p1"], extra: ["futureField": 7])
        let out = applyIntrinsic(cat, json: ["weight": nil, "photos": nil, "_defPhase": "door", "seasons": ["Winter"]])
        XCTAssertEqual(out.weight, 0)             // null is DEFINED in JS: it is written, then coerced
        XCTAssertEqual(out.photos, [])
        XCTAssertEqual(out.phase, "door")
        XCTAssertEqual(out.seasons, [])           // contextual: never pushed onto the shared item
        XCTAssertEqual(out.extra["futureField"], 7)
        XCTAssertEqual(out.id, cat.id)
        XCTAssertEqual(applyIntrinsic(cat, json: nil), coerceItem(cat))
    }

    func testCatalogItemFromResolvedTakesADefaultChannelOverTheResolvedValueAndANewId() {
        PackingEnv.freeze()
        let cat = newItem(name: "Buff", container: "Duffel bag", phase: "week")                       // id-1
        let m = newMembership(itemId: cat.id, templateId: "run", container: "Day pack", kit: "Run kit", phase: "door")   // id-2
        let resolved = resolveMembership(cat, m)
        let fresh = catalogItemFromResolved(resolved)                                                // id-3
        XCTAssertEqual(fresh.id, "id-3")
        XCTAssertEqual(fresh.container, "Duffel bag")   // `_defContainer`, not the per-list "Day pack"
        XCTAssertEqual(fresh.phase, "week")             // `_defPhase`, not the per-list "door"
        XCTAssertEqual(fresh.kit, "")
        XCTAssertNil(fresh.ovContainer)
        XCTAssertNil(fresh.itemId)
    }

    func testBuildCatalogMergeRulesAndIdOrder() {
        PackingEnv.freeze()
        let a = newList(id: "a", name: "A", items: [
            newItem(id: "x1", name: "Water  Bottle", swedish: "Flaska", category: "Food & drink", container: "Day pack", sub: ["lid"]),
            newItem(id: "x2", name: "Map"),
        ])
        let b = newList(id: "b", name: "B", items: [
            newItem(id: "x3", name: "water bottle", swedish: "Vattenflaska", container: "Cool box", sub: ["lid", "straw"], weight: 120, liquid: true),
            newItem(id: "x4", name: "Water bottle", swedish: "Flaska ", container: "Cool box", weight: 150),
        ])
        let c = buildCatalog([a, b])
        XCTAssertEqual(c.items.map { $0.name }, ["Water  Bottle", "Map"])       // 1-1-1 tie on the name: first seen
        XCTAssertEqual(c.items[0].swedish, "Flaska")                             // most common wording (trimmed)
        XCTAssertEqual(c.items[0].container, "Cool box")                         // majority
        XCTAssertEqual(c.items[0].weight, 120)                                   // first known value
        XCTAssertEqual(c.items[0].liquid, true)                                  // true if any copy has it
        XCTAssertEqual(c.items[0].sub, ["lid", "straw"])                         // the longest list
        // v188: a thing keeps its identity — the most common id among its copies
        // (a 1-1-1 tie: the first seen). Only the memberships are minted, list by list.
        XCTAssertEqual(c.items.map { $0.id }, ["x1", "x2"])
        XCTAssertEqual(c.memberships.map { $0.id }, ["id-1", "id-2", "id-3", "id-4"])
        XCTAssertEqual(c.memberships.map { $0.order }, [0, 1, 0, 1])
        XCTAssertEqual(c.memberships.map { $0.container }, ["Day pack", "", "", ""])
        XCTAssertEqual(c.memberships.map { $0.templateId }, ["a", "a", "b", "b"])
    }
    // MARK: - web app v188: a rebuild keeps every detail of a thing

    /// JS: 'buildCatalog: every intrinsic field survives a rebuild (the restore path), and so does the id'
    func testEveryIntrinsicFieldSurvivesARebuildAndSoDoesTheId() {
        var it = newItem(name: "Headlamp", swedish: "Pannlampa", category: "Electronics", charging: true, chargeType: "usb-c",
                         shortList: true, sub: ["Spare strap"], weight: 90, liquid: true, restricted: true, perNight: true,
                         consumable: true, packer: "Anna", storage: "Hall closet", photos: ["ph-1"], thumb: "t",
                         maintenance: Maintenance(notes: "Check the seal", link: "", intervalDays: 90, lastDone: "2026-06-01", log: []),
                         color: "Red", size: "M", manufacturer: "Petzl", model: "Actik", ownedBy: "Anna", acquired: "2025-01-02",
                         price: 49, currency: "EUR", purchaseLink: "https://example.invalid/x", expiry: "2027-01-01",
                         condition: "good", retired: true, retiredReason: "sold", serial: "SN1", qtyOwned: 2, warranty: "2027-06-01",
                         capacityL: 1.5, maxKg: 0.5)
        it.stats = ItemStats(packed: 3, used: 2, unused: 1, skipped: 0, lastReviewed: "2026-08-01")
        it.keep = true
        var list = newList(name: "Camp"); list.items = [it]
        let cat = buildCatalog([list])
        let got = cat.items.first { $0.name == "Headlamp" }!
        for f in INTRINSIC_FIELDS {
            XCTAssertEqual(got.json[f], it.json[f], "the catalogue item lost \"\(f)\"")
        }
        XCTAssertEqual(got.id, it.id, "a thing keeps its identity through a rebuild")
        let back = resolveTemplate(cat.templates[0], cat.items, cat.memberships).items[0]
        for f in INTRINSIC_FIELDS {
            XCTAssertEqual(back.json[f], it.json[f], "the resolved item lost \"\(f)\"")
        }
    }

    /// JS: 'buildCatalog: one thing on two templates keeps its kit per template, its packer, and the richest review history — not a sum'
    func testOneThingOnTwoTemplatesKeepsItsKitPerTemplateItsPackerAndTheRichestHistory() {
        var shared = newItem(name: "Power bank", consumable: true, packer: "Anna")
        shared.stats = ItemStats(packed: 4, used: 4, unused: 0, skipped: 0)
        var stale = newItem(id: shared.id, name: "Power bank", kit: "Charging kit")
        stale.stats = ItemStats(packed: 1, used: 1, unused: 0, skipped: 0)
        var a = newList(name: "Camp"); a.items = [shared]
        var b = newList(name: "Travel"); b.items = [stale]
        let cat = buildCatalog([a, b])
        XCTAssertEqual(cat.items.count, 1, "one thing, two templates")
        XCTAssertEqual(cat.items[0].id, shared.id)
        XCTAssertEqual(cat.items[0].packer, "Anna")
        XCTAssertTrue(cat.items[0].consumable)
        XCTAssertEqual(cat.items[0].stats.packed, 4, "the copy with the most history speaks — 4, not 4 + 1")
        XCTAssertEqual(cat.items[0].stats.used, 4)
        let inCamp = resolveTemplate(cat.templates[0], cat.items, cat.memberships).items[0]
        let inTravel = resolveTemplate(cat.templates[1], cat.items, cat.memberships).items[0]
        XCTAssertEqual(inCamp.kit, "", "no kit on the Camp template")
        XCTAssertEqual(inTravel.kit, "Charging kit", "the kit is a per-template answer, and it survives")
        XCTAssertEqual(cat.memberships.first { $0.templateId == b.id }?.kit, "Charging kit")
        XCTAssertEqual(inTravel.packer, "Anna", "the packer is the thing's own, so it is there on both")
    }

    /// JS: '"Keep" on Refine is written to the catalogue item, so the suggestion stays away'
    func testKeepOnRefineReachesTheCatalogueItem() {
        var cat = newItem(name: "Tow rope")
        cat.stats = ItemStats(packed: 3, used: 0, unused: 3, skipped: 0)
        var list = newList(name: "RV")
        func resolved() -> Item { resolveMembership(cat, newMembership(itemId: cat.id, templateId: list.id)) }
        list.items = [resolved()]
        XCTAssertEqual(pruneSuggestions([list]).count, 1, "packed three times, never used: a suggestion")
        var row = resolved()
        row.keep = true
        cat = applyIntrinsic(cat, row)
        XCTAssertTrue(cat.keep, "keep reaches the shared item")
        list.items = [resolved()]
        XCTAssertEqual(pruneSuggestions([list]).count, 0, "and Refine stops suggesting the drop, even after a reload")
    }

    /// JS: 'buildCatalog: two names claiming one id stay two records, and a copy with no id is given one'
    func testTwoNamesClaimingOneIdStayTwoRecords() {
        let a = newItem(id: "same-id", name: "Gloves")
        let b = newItem(id: "same-id", name: "Hat")
        let legacy = Item(json: ["name": "Scarf"])          // a v1 copy: no id at all
        var list = newList(name: "Winter"); list.items = [a, b, legacy]
        let items = buildCatalog([list]).items
        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(items[0].id, "same-id", "the first keeps it")
        XCTAssertNotEqual(items[1].id, "same-id", "the second is given its own")
        XCTAssertFalse(items[2].id.isEmpty, "no id in the file — one is minted")
        XCTAssertEqual(Set(items.map(\.id)).count, 3)
    }
}
