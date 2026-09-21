import XCTest
@testable import PackingCore

// Ported from tests/model.test.mjs — the read path of the relational core:
// resolveMembership, resolveTemplateItems, templateDefaults (+ resolveItemAlone and
// resolveTemplate, which the JS suite only reaches through other tests).
final class ResolveTests: XCTestCase {
    override func tearDown() { PackingEnv.reset(); super.tearDown() }

    // JS: 'resolveMembership: overrides win, blanks fall back to the item default'
    func testResolveMembershipOverridesWinBlanksFallBackToTheItemDefault() {
        let item = newItem(name: "Socks", swedish: "Strumpor", category: "Clothing", container: "Duffel bag", phase: "week")
        let plain = resolveMembership(item, newMembership(itemId: item.id, templateId: "t1"))
        XCTAssertEqual(plain.container, "Duffel bag")   // no override -> item default
        XCTAssertEqual(plain.phase, "week")
        let overridden = resolveMembership(item, newMembership(itemId: item.id, templateId: "t2", seasons: ["Summer"], container: "Checked luggage"))
        XCTAssertEqual(overridden.container, "Checked luggage")   // override wins
        XCTAssertEqual(overridden.category, "Clothing")           // intrinsic still from item
        XCTAssertEqual(overridden.swedish, "Strumpor")
        XCTAssertEqual(overridden.seasons, ["Summer"])            // condition comes from the membership
    }

    // JS: 'resolveTemplateItems: respects membership order'
    func testResolveTemplateItemsRespectsMembershipOrder() {
        let a = newItem(name: "A"), b = newItem(name: "B"), c = newItem(name: "C")
        let tmpl = newList(name: "T")
        let mems = [
            newMembership(itemId: c.id, templateId: tmpl.id, order: 0),
            newMembership(itemId: a.id, templateId: tmpl.id, order: 1),
            newMembership(itemId: b.id, templateId: tmpl.id, order: 2),
        ]
        let items = resolveTemplateItems(tmpl, [a, b, c], mems)
        XCTAssertEqual(items.map { $0.name }, ["C", "A", "B"])
    }

    // JS: 'same item, different section per template'
    func testSameItemDifferentSectionPerTemplate() {
        let item = newItem(name: "Head torch")
        let inDive = resolveMembership(item, newMembership(itemId: item.id, templateId: "dive", section: "lights"))
        let inRun = resolveMembership(item, newMembership(itemId: item.id, templateId: "run", section: "visibility"))
        XCTAssertEqual(inDive.section, "lights")
        XCTAssertEqual(inRun.section, "visibility")   // independent — no cross-contamination
    }

    // JS: 'kit name flows catalog item -> membership -> resolved item'
    func testKitNameFlowsCatalogItemMembershipResolvedItem() {
        let item = newItem(name: "USB-C cable")
        let m = newMembership(itemId: item.id, templateId: "t1", kit: "Charging kit")
        let resolved = resolveMembership(item, m)
        XCTAssertEqual(resolved.kit, "Charging kit")
    }

    // JS: 'container resolves exception → template default → item default'
    func testContainerResolvesExceptionTemplateDefaultItemDefault() {
        let cat = newItem(name: "Socks", container: "Duffel bag")
        let plain = newMembership(itemId: cat.id, templateId: "hiking")
        let withEx = newMembership(itemId: cat.id, templateId: "hiking", container: "RV storage box")
        let tpl = templateDefaults(PackList(defaultContainer: "Hiking backpack"))
        XCTAssertEqual(resolveMembership(cat, plain, nil).container, "Duffel bag")        // item default
        XCTAssertEqual(resolveMembership(cat, plain, tpl).container, "Hiking backpack")   // template beats item
        XCTAssertEqual(resolveMembership(cat, withEx, tpl).container, "RV storage box")   // exception beats both
    }

    // MARK: --- not in the JS suite ---

    func testResolveMembershipHandsBackEveryPartOfTheAnswer() {
        let cat = newItem(name: "Socks", qty: "3", container: "Duffel bag", phase: "week", itemType: "item",
                          seasons: ["Winter"], note: "wool", section: "junk", kit: "junk")
        let m = newMembership(itemId: cat.id, templateId: "hiking", contexts: ["Outdoor"], weather: ["cold", "bogus"],
                              phase: "door", itemType: "reminder")
        let r = resolveMembership(cat, m, TemplateDefaults(container: "Hiking backpack"))
        XCTAssertEqual(r.id, cat.id)                       // a resolved copy keeps the CATALOGUE id
        XCTAssertEqual([r.ovContainer, r.tplContainer, r.defContainer], ["", "Hiking backpack", "Duffel bag"])
        XCTAssertEqual([r.phase, r.ovPhase, r.defPhase], ["door", "door", "week"])
        XCTAssertEqual(r.itemType, "reminder")
        XCTAssertEqual(r.seasons, [])                      // the membership's conditions REPLACE the item's
        XCTAssertEqual(r.contexts, ["Outdoor"])
        XCTAssertEqual(r.weather, ["cold"])
        XCTAssertEqual([r.section, r.kit], ["", ""])       // per-template only: never an item default
        XCTAssertEqual([r.qty, r.note], ["3", "wool"])     // blank on the membership -> the item's own
        XCTAssertNil(r.itemId)                             // (the store stamps `_itemId` / `_memId`, not this)
        XCTAssertNil(r.memId)
    }

    func testResolveItemAloneGivesBlankPerTemplateAnswersAndTheItemsOwn() {
        PackingEnv.freeze()
        let cat = newItem(name: "Tent", container: "Duffel bag", phase: "daybefore", photos: ["p1"])   // id-1
        let it = resolveItemAlone(cat)                                                                  // spends id-2
        XCTAssertEqual(it.itemId, cat.id)
        XCTAssertEqual(it.memId, "")
        XCTAssertEqual([it.container, it.ovContainer, it.tplContainer, it.defContainer], ["Duffel bag", "", "", "Duffel bag"])
        XCTAssertEqual([it.phase, it.ovPhase, it.defPhase], ["daybefore", "", "daybefore"])
        XCTAssertEqual(it.photos, ["p1"])
        XCTAssertEqual(newItem(name: "next").id, "id-3")   // exactly one id went on the empty membership
        // Saving it back touches nothing that was not edited.
        XCTAssertEqual(applyIntrinsic(cat, it), cat)
    }

    func testResolveTemplateItemsSkipsMissingItemsAndKeepsTheSameItemTwice() {
        let cat = newItem(id: "i1", name: "Charger", phase: "week")
        let tmpl = newList(id: "t1", name: "Travel", defaultContainer: "Tech pouch")
        let mems = [
            newMembership(id: "m2", itemId: "i1", templateId: "t1", phase: "morning", order: 1),
            newMembership(id: "m1", itemId: "i1", templateId: "t1", order: 0),
            newMembership(id: "m3", itemId: "gone", templateId: "t1", order: 2),
            newMembership(id: "m4", itemId: "i1", templateId: "other", order: 0),
        ]
        let items = resolveTemplateItems(tmpl, [cat], mems)
        // The same thing twice on one list, with a different "When" — both rows carry
        // the item's id, which is why rows are told apart by membership, not by item.
        XCTAssertEqual(items.map { $0.id }, ["i1", "i1"])
        XCTAssertEqual(items.map { $0.phase }, ["week", "morning"])
        XCTAssertEqual(items.map { $0.container }, ["Tech pouch", "Tech pouch"])
        let list = resolveTemplate(tmpl, [cat], mems)
        XCTAssertEqual(list.items, items)
        XCTAssertEqual([list.id, list.name, list.defaultContainer], ["t1", "Travel", "Tech pouch"])
    }
}
