import XCTest
@testable import PackingCore

// Ported from tests/model.test.mjs — "People (who packs what)" and "groupByPacker".
final class PeopleTests: XCTestCase {
    override func tearDown() {
        PackingEnv.reset()
        super.tearDown()
    }

    // JS: 'coercePerson: trims name, validates colour, ensures id'
    func testCoercePersonTrimsNameValidatesColourEnsuresId() throws {
        let p = try XCTUnwrap(coercePerson(json: ["name": "  Robin ", "color": "nope"]))
        XCTAssertEqual(p.name, "Robin")
        XCTAssertEqual(p.color, PERSON_COLORS[0])
        XCTAssertFalse(p.id.isEmpty)
        XCTAssertEqual(coercePerson(json: ["name": "X", "color": "#a855f7"])?.color, "#a855f7")
    }

    // JS: 'personColor: roster colour when known, stable hash otherwise, blank for empty'
    func testPersonColorRosterColourWhenKnownStableHashOtherwiseBlankForEmpty() {
        let people = [newPerson(name: "Kim", color: "#3b82f6"), newPerson(name: "Robin", color: "#a855f7")]
        XCTAssertEqual(personColor("kim", people), "#3b82f6") // case-insensitive
        XCTAssertEqual(personColor("", people), "")
        let emil = personColor("Emil", people)
        XCTAssertTrue(PERSON_COLORS.contains(emil))
        XCTAssertEqual(personColor("Emil", people), emil) // deterministic
    }

    // JS: 'assignedPeople: distinct packer names, first-seen order, case-folded'
    func testAssignedPeopleDistinctPackerNamesFirstSeenOrderCaseFolded() {
        let entries = [Item(packer: "Robin"), Item(packer: ""), Item(packer: "Kim"), Item(packer: "robin"), Item(packer: "  ")]
        XCTAssertEqual(assignedPeople(entries), ["Robin", "Kim"])
    }

    // JS: 'groupByPacker: roster order first, strays A–Z, unassigned always last'
    func testGroupByPackerRosterOrderFirstStraysAZUnassignedAlwaysLast() {
        func e(_ name: String, _ packer: String) -> Item { Item(name: name, packer: packer) }
        let out = groupByPacker(
            [e("Tent", "Robin"), e("Map", ""), e("Boots", "Zoe"), e("Fins", "Kim"), e("Rope", "Bo"), e("Torch", "robin")],
            ["Kim", "Robin"]
        )
        XCTAssertEqual(out.map { $0.packer }, ["Kim", "Robin", "Bo", "Zoe", ""])
        // Case-folded into one block, keeping the spelling of the first entry seen.
        XCTAssertEqual(out[1].entries.map { $0.name }, ["Tent", "Torch"])
        XCTAssertEqual(out[4].entries.map { $0.name }, ["Map"])
    }

    // JS: 'groupByPacker: entry order is preserved inside a block'
    func testGroupByPackerEntryOrderIsPreservedInsideABlock() {
        let out = groupByPacker([Item(name: "C", packer: "A"), Item(name: "A", packer: "A"), Item(name: "B", packer: "A")], ["A"])
        XCTAssertEqual(out[0].entries.map { $0.name }, ["C", "A", "B"])
    }

    // JS: 'groupByPacker: nobody assigned is one unassigned block, and nothing is dropped'
    func testGroupByPackerNobodyAssignedIsOneUnassignedBlockAndNothingIsDropped() {
        let rows = [Item(name: "A"), Item(name: "B", packer: "  ")]
        let out = groupByPacker(rows, ["Kim"])
        XCTAssertEqual(out.count, 1)
        XCTAssertEqual(out[0].packer, "")
        XCTAssertEqual(out[0].entries.count, 2)
        XCTAssertEqual(groupByPacker([], ["Kim"]), [])
        // Every entry lands in exactly one block, whatever the roster says.
        let many = [Item(packer: "X"), Item(packer: ""), Item(packer: "Kim")]
        XCTAssertEqual(groupByPacker(many, []).reduce(0) { $0 + $1.entries.count }, many.count)
    }

    // --- not in the JS suite: the conventions every model type follows, and the
    // --- hash, pinned to the answers Node gives

    func testPersonColorHashMatchesTheJSAnswer() {
        // node: personColor('Emil') → '#f59e0b', personColor('Zoë') → '#ec4899',
        //       personColor('  BO  ') === personColor('bo') → '#06b6d4'
        XCTAssertEqual(personColor("Emil"), "#f59e0b")
        XCTAssertEqual(personColor("Zoë"), "#ec4899")
        XCTAssertEqual(personColor("  BO  "), "#06b6d4")
        XCTAssertEqual(personColor("bo"), "#06b6d4")
        XCTAssertEqual(personColor(nil), "")
        // On the roster but with no colour → the hash, not ''.
        XCTAssertEqual(personColor("Emil", [Person(name: "emil", color: "")]), "#f59e0b")
    }

    func testNewPersonThreeFormsAndTheJSONRoundTrip() throws {
        PackingEnv.freeze()
        let a = newPerson(name: "  Bo ", color: "red")
        XCTAssertEqual(a, Person(id: "id-1", name: "Bo", color: PERSON_COLORS[0]))
        XCTAssertEqual(newPerson(Person(id: "", name: "Zoe")).id, "id-2")     // an empty id is made up
        let c = newPerson(json: ["name": "Emil", "color": "#22c55e", "nickname": "E", "owner": "x@example.com"])
        XCTAssertEqual(c.name, "Emil")
        XCTAssertEqual(c.color, "#22c55e")
        XCTAssertEqual(c.extra, ["nickname": "E"])                             // unknown keys kept, `owner` never
        XCTAssertEqual(Person(json: c.json), c)
        XCTAssertNil(coercePerson(json: "Robin"))                               // not an object: JS hands it back
        XCTAssertNil(coercePerson(json: nil))
        // A name that is not a string reads as ''; an id that is not a string is replaced.
        let d = Person(json: ["id": 7, "name": 42])
        XCTAssertEqual(d.name, "")
        XCTAssertTrue(d.id.hasPrefix("id-"))
        let data = try JSONEncoder().encode(c)
        XCTAssertEqual(try JSONDecoder().decode(Person.self, from: data), c)
    }
}

// JS tests in the "People" section that belong to OTHER slices (not ported here):
//  • 'packer flows onto a trip entry and survives the share bundle'            → sharing
//  • 'packer is intrinsic: an item default reaches the catalog and every trip…' → catalogue
//  • 'an item default packer lands on the trip line buildTotalEntries makes'    → trip
//  • 'a per-list link carries no packer of its own…'                            → catalogue
//  • 'referencedListValues sees a packer set on a catalog item…'                → DeviceAuditTests
