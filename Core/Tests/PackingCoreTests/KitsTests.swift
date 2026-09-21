import XCTest
@testable import PackingCore

// Ported from tests/model.test.mjs — "Kits". (The three tests of a kit flowing
// through memberships onto a trip belong to the catalogue and trip-building sections.)
final class KitsTests: XCTestCase {
    override func tearDown() { PackingEnv.reset(); super.tearDown() }

    // JS: 'coerceKit: de-dups member ids (order preserved) and normalises fields'
    func testCoerceKitDeDupsMemberIdsAndNormalisesFields() throws {
        let k = try XCTUnwrap(coerceKit(json: ["id": "k1", "name": "Charging kit", "emoji": " 🔌 ", "note": 5, "itemIds": ["a", "b", "a", "", "c", "b"]]))
        XCTAssertEqual(k.itemIds, ["a", "b", "c"])
        XCTAssertEqual(k.emoji, "🔌")
        XCTAssertEqual(k.note, "")   // non-string note coerced away
    }

    // JS: 'newKit: sane defaults + timestamps'
    func testNewKitSaneDefaultsAndTimestamps() {
        let k = newKit(name: "Wash bag")
        XCTAssertEqual(k.name, "Wash bag")
        XCTAssertEqual(k.itemIds, [])
        XCTAssertEqual(k.emoji, "")
        XCTAssertTrue(!k.id.isEmpty && !k.createdAt.isEmpty && !k.updatedAt.isEmpty)
    }

    // JS: 'kitEmoji: own emoji wins, else the default bundle glyph'
    func testKitEmojiOwnEmojiWinsElseTheDefault() {
        XCTAssertEqual(kitEmoji(newKit(emoji: "🩹")), "🩹")
        XCTAssertEqual(kitEmoji(newKit()), KIT_DEFAULT_EMOJI)
    }

    // JS: 'clusterByKit: loose entries stay in place; a kit emits its whole run once'
    func testClusterByKitLooseEntriesStayInPlace() {
        let e = [
            Item(name: "A", kit: "Charging kit"),
            Item(name: "B", kit: ""),
            Item(name: "C", kit: "Charging kit"),
            Item(name: "D", kit: "Wash bag"),
        ]
        let cl = clusterByKit(e)
        XCTAssertEqual(cl.map { $0.kit }, ["Charging kit", "", "Wash bag"])
        XCTAssertEqual(cl.map { $0.entries.count }, [2, 1, 1])
        XCTAssertEqual(cl[0].entries.map { $0.name }, ["A", "C"])
    }

    // --- not in the JS suite ---

    func testAKitRoundTripsThroughJSON() throws {
        let k = newKit(id: "k1", name: "First aid", emoji: "🩹", note: "In the lid", itemIds: ["a", "b"],
                       createdAt: "2026-01-01T00:00:00.000Z", updatedAt: "2026-01-02T00:00:00.000Z")
        XCTAssertEqual(try JSONDecoder().decode(Kit.self, from: JSONEncoder().encode(k)), k)
        // coerceKit alone leaves missing timestamps blank (newKit is what stamps them).
        XCTAssertEqual(coerceKit(json: ["name": "X"])?.createdAt, "")
        XCTAssertNil(coerceKit(json: 5))
    }
}
