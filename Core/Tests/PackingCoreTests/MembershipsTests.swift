import XCTest
@testable import PackingCore

// Ported from tests/model.test.mjs — the two tests of the membership TYPE and its
// field lists. (resolveMembership, buildCatalog, applyIntrinsic, linkFromResolved…
// belong to the catalogue section.)
final class MembershipsTests: XCTestCase {
    override func tearDown() { PackingEnv.reset(); super.tearDown() }

    // JS: 'coerceMembership: normalizes conditions and keeps override sentinels'
    func testCoerceMembershipNormalizesConditionsAndKeepsOverrideSentinels() throws {
        let m = try XCTUnwrap(coerceMembership(json: ["id": "m1", "itemId": "i1", "templateId": "t1", "seasons": "Summer", "phase": "bogus", "itemType": "nope", "container": 42]))
        XCTAssertEqual(m.seasons, [])          // non-array coerced to []
        // Since v118 phases are editable AND synced, so an id this device doesn't know is
        // KEPT, not blanked: it is almost certainly a phase added on the other device, and
        // discarding it would move the item to a different place on the packing list.
        XCTAssertEqual(m.phase, "bogus")
        XCTAssertEqual(coerceMembership(json: ["id": "m2", "itemId": "i1", "templateId": "t1", "phase": 42])?.phase, "")   // non-string -> use the item default
        XCTAssertEqual(m.itemType, "")             // invalid itemType -> '' (use item default)
        XCTAssertEqual(m.container, "")            // non-string -> '' (use item default)
    }

    // JS: 'INTRINSIC_FIELDS carries ownedBy and no longer the reserved owner'
    // Parity review: `String(m.qty)` for a numeric qty is JS's number text — a small
    // fraction is "0.00001", never the C layout "1e-05" the first number writer gave.
    func testANumericQtyBecomesTextTheWayJSWritesNumbers() throws {
        func qty(_ n: JSONValue) -> String? { coerceMembership(json: ["id": "m", "itemId": "i", "templateId": "t", "qty": n])?.qty }
        XCTAssertEqual(qty(3), "3")
        XCTAssertEqual(qty(0.5), "0.5")
        XCTAssertEqual(qty(0.00001), "0.00001")
        XCTAssertEqual(qty(1.5e-7), "1.5e-7")
        XCTAssertEqual(qty(1e21), "1e+21")
        XCTAssertEqual(qty(0), "")                                    // `m.qty ? String(m.qty) : ''`
    }

    func testIntrinsicFieldsCarriesOwnedByAndNoLongerTheReservedOwner() {
        XCTAssertTrue(INTRINSIC_FIELDS.contains("ownedBy"))
        XCTAssertFalse(INTRINSIC_FIELDS.contains("owner"))
    }

    // --- not in the JS suite ---

    func testNewMembershipDefaultsAndRoundTrip() throws {
        PackingEnv.freeze()
        let m = newMembership(itemId: "i1", templateId: "t1", weather: ["rain", "fog"], itemType: "reminder", order: 3)
        XCTAssertEqual(m.id, "id-1")
        XCTAssertEqual(m.weather, ["rain"])
        XCTAssertEqual(m.itemType, "reminder")
        XCTAssertEqual([m.container, m.section, m.kit, m.phase, m.qty, m.note], ["", "", "", "", "", ""])
        XCTAssertEqual(try JSONDecoder().decode(Membership.self, from: JSONEncoder().encode(m)), m)
        // An old numeric qty reads as its text; 0 and junk as ''.
        XCTAssertEqual(coerceMembership(json: ["qty": 2])?.qty, "2")
        XCTAssertEqual(coerceMembership(json: ["qty": 0])?.qty, "")
        XCTAssertEqual(coerceMembership(json: ["order": "3"])?.order, 0)   // Number.isFinite('3') is false
        XCTAssertNil(coerceMembership(json: nil))
    }

    func testEveryFieldListNamesARealItemKey() {
        // The three lists are JSON KEYS. Each must be a key an Item really writes (or,
        // for the two channels, really reads) — so a later section can walk them.
        let keys = Set((newItem(name: "Tent", ovContainer: "", defContainer: "Day pack", ovPhase: "", defPhase: "week").json.objectValue ?? [:]).keys)
        for f in INTRINSIC_FIELDS + CONTEXTUAL_FIELDS { XCTAssertTrue(keys.contains(f), f) }
        for d in DEFAULT_FIELDS {
            XCTAssertTrue(keys.contains(d.field), d.field)
            XCTAssertTrue(keys.contains(d.channel), d.channel)
        }
        XCTAssertEqual(DEFAULT_FIELDS.map { $0.field }, ["container", "phase"])
        XCTAssertFalse(CONTEXTUAL_FIELDS.contains("section"))   // a section travels by NAME, never by id
    }
}
