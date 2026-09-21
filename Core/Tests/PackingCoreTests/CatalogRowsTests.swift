import XCTest
@testable import PackingCore

// Ported from tests/model.test.mjs — the database overview (catalogRows, dupeKey,
// duplicateGroups / duplicateIds) and the spreadsheet rows (totalListRows).
final class CatalogRowsTests: XCTestCase {
    override func tearDown() {
        PackingEnv.reset()
        setPhases(DEFAULT_PHASES)
        super.tearDown()
    }

    // JS: 'totalListRows: flat rows carry phase, container, item'
    func testTotalListRowsFlatRowsCarryPhaseContainerItem() {
        var ev = newEvent()
        ev.entries = [newItem(name: "Boots", container: "Hiking backpack", phase: "week")]
        let rows = totalListRows(ev, nil)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].Item, "Boots")
        XCTAssertEqual(rows[0].Container, "Hiking backpack")
        XCTAssertFalse(rows[0].Phase.isEmpty)
    }

    // JS: 'catalogRows: one line per catalog item, gathering all its templates'
    func testCatalogRowsOneLinePerCatalogItemGatheringAllItsTemplates() throws {
        // The same catalog item (shared id) resolved into two templates collapses to one row.
        let boots = newItem(name: "Boots")
        let hiking = newList(name: "Hiking", items: [boots, newItem(name: "Poles")])
        let travel = newList(name: "Travel", items: [boots])   // same id, different template
        let rows = catalogRows([hiking, travel])
        XCTAssertEqual(rows.count, 2, "Boots + Poles = 2 unique items")
        let bootRow = try XCTUnwrap(rows.first { $0.name == "Boots" })
        XCTAssertEqual(bootRow.templates.map { $0.name }.sorted(), ["Hiking", "Travel"])
        let poleRow = try XCTUnwrap(rows.first { $0.name == "Poles" })
        XCTAssertEqual(poleRow.templates.map { $0.name }, ["Hiking"])
        // Blank-named items are ignored.
        XCTAssertEqual(catalogRows([newList(items: [newItem(name: "")])]).count, 0)
    }

    // JS: 'dupeKey: collapses spacing and plurals for probable duplicates'
    func testDupeKeyCollapsesSpacingAndPluralsForProbableDuplicates() {
        XCTAssertEqual(dupeKey("Sunglasses"), dupeKey("Sun glasses"))
        XCTAssertEqual(dupeKey("Running shoes"), dupeKey("Running shoe"))
        XCTAssertEqual(dupeKey("Ear plugs"), dupeKey("Earplugs"))
        XCTAssertNotEqual(dupeKey("Cap"), dupeKey("Cape"))   // short words are not over-stripped
        XCTAssertNotEqual(dupeKey("Socks"), dupeKey("Shorts"))
        XCTAssertEqual(dupeKey("   "), "")                    // blank -> empty key
    }

    // JS: 'duplicateGroups / duplicateIds: surface look-alike items'
    func testDuplicateGroupsAndIdsSurfaceLookAlikeItems() throws {
        let rows = catalogRows([newList(name: "A", items: [
            newItem(name: "Sunglasses"),
            newItem(name: "Sun glasses"),
            newItem(name: "Passport"),
            newItem(name: "Head torch"),
            newItem(name: "Head torch"),   // exact duplicate name, distinct catalog item
        ])])
        let groups = duplicateGroups(rows)
        let byKey = Dictionary(uniqueKeysWithValues: groups.map { g in (g.rows.map { $0.name }.sorted().joined(separator: "|"), g) })
        let near = try XCTUnwrap(byKey["Sun glasses|Sunglasses"], "near-duplicate pair grouped")
        XCTAssertEqual(near.exact, false)
        let exactGroup = try XCTUnwrap(groups.first { $0.exact })
        XCTAssertTrue(exactGroup.rows.allSatisfy { $0.name == "Head torch" }, "exact-name duplicates flagged exact")
        // Passport has no partner -> not in any group, and not flagged.
        let ids = duplicateIds(rows)
        let passport = try XCTUnwrap(rows.first { $0.name == "Passport" })
        XCTAssertFalse(ids.contains(passport.id))
        XCTAssertGreaterThanOrEqual(ids.count, 4, "both look-alike pairs are flagged")
    }

    // MARK: --- not in the JS suite ---

    // Answers taken from running the JS `dupeKey` in node.
    func testDupeKeyWorksOnCodePointsAsTheJSRegexDoes() {
        XCTAssertEqual(dupeKey("Café-au-lait  cups"), "caféaulaitcup")
        XCTAssertEqual(dupeKey("T-shirts"), "tshirt")
        XCTAssertEqual(dupeKey("Glass"), "glass")             // -ss is never stripped
        XCTAssertEqual(dupeKey("Åsas"), "åsa")
        XCTAssertEqual(dupeKey("x²³ ①"), "x²³①")             // \p{N} is every kind of number
        // A COMBINING accent is a Mark — neither \p{L} nor \p{N} — so it is dropped and
        // splits the word: "e" + U+0301 does NOT give the key of a precomposed "é".
        XCTAssertEqual(dupeKey("Cafe\u{301} cups"), "cafecup")
        XCTAssertEqual(dupeKey("İstanbul bags"), "istanbulbag")   // 'İ' lowercases to i + U+0307
        XCTAssertEqual(dupeKey("Gas"), "gas")                 // three letters: too short to strip
        XCTAssertEqual(dupeKey("Bags"), "bag")
        XCTAssertEqual(dupeKey(nil), "")
        XCTAssertEqual(dupeKey("—!?"), "")
    }

    func testCatalogRowsFoldsInThingsOnNoListAndSortsByNameIgnoringCase() {
        let boots = newItem(id: "i-boots", name: "boots")
        let axe = newItem(id: "i-axe", name: "Ice axe")
        let anon = newItem(id: "", name: "  Zip  ties ")
        let hiking = newList(id: "hiking", name: "Hiking", role: "", items: [boots, boots, anon])
        let bags = newList(id: "bags", name: "Containers", role: "container", items: [boots])
        let rows = catalogRows([hiking, bags], [axe, boots, newItem(id: "blank", name: " ")])
        // (answers taken from the JS: a leading space sorts BEFORE any letter)
        XCTAssertEqual(rows.map { $0.name }, ["  Zip  ties ", "boots", "Ice axe"])
        XCTAssertEqual(rows.map { $0.id }, ["name:zip ties", "i-boots", "i-axe"])
        XCTAssertEqual(rows[0].templates, [CatalogRowTemplate(id: "hiking", name: "Hiking", role: "")])
        XCTAssertEqual(rows[1].templates, [CatalogRowTemplate(id: "hiking", name: "Hiking", role: ""),
                                           CatalogRowTemplate(id: "bags", name: "Containers", role: "container")])
        XCTAssertEqual(rows[2].templates, [])   // on no list: an ordinary state, not an orphan
    }

    func testDuplicateGroupsAreSortedByTheirFirstRowAndIdsKeepInsertionOrder() {
        let list = newList(name: "A", items: [
            newItem(id: "z1", name: "zip ties"), newItem(id: "b1", name: "Bags"),
            newItem(id: "z2", name: "Zip tie"), newItem(id: "b2", name: "bag"),
        ])
        let rows = catalogRows([list])
        let groups = duplicateGroups(rows)
        XCTAssertEqual(groups.map { $0.key }, ["bag", "ziptie"])
        XCTAssertEqual(groups.map { $0.exact }, [false, false])
        XCTAssertEqual(duplicateIds(rows), ["b2", "b1", "z2", "z1"])   // rows are name-sorted first: bag, Bags, Zip tie, zip ties
    }

    func testTotalListRowsGoTimelineThenContainerOrder() {
        var ev = newEvent()
        ev.entries = [
            newItem(name: "Keys", container: "", phase: "door", checked: true),
            newItem(name: "Wetsuit", qty: "1", container: "Zebra crate", phase: "week", note: "rinse"),
            newItem(name: "Boots", container: "Hiking backpack", phase: "week"),
            newItem(name: "Snacks", container: "Alpha crate", phase: "week"),
            newItem(name: "Mystery", container: "Duffel bag", phase: "made-elsewhere"),
        ]
        let rows = totalListRows(ev)
        XCTAssertEqual(rows.map { $0.Item }, ["Boots", "Snacks", "Wetsuit", "Keys", "Mystery"])
        XCTAssertEqual(rows[2], TotalListRow(Phase: phaseLabel("week"), Container: "Zebra crate", Item: "Wetsuit", Qty: "1", Packed: "", Note: "rinse"))
        XCTAssertEqual(rows[3].Container, "")            // the ROW keeps the entry's own (blank) container
        XCTAssertEqual(rows[3].Packed, "yes")
        XCTAssertEqual(rows[4].Phase, "made-elsewhere")  // an unknown phase keeps its id as the label
        XCTAssertEqual(rows[0].json, ["Phase": .string(phaseLabel("week")), "Container": "Hiking backpack", "Item": "Boots",
                                      "Qty": "", "Packed": "", "Note": ""])
    }
}
