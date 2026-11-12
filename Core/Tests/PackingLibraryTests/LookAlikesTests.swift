import XCTest
import PackingCore
@testable import PackingLibrary

/// Look-alikes (0.125): two things that look like one, "Not the same", and merging.
final class LookAlikesTests: XCTestCase {
    override func setUp() { PackingEnv.reset() }
    override func tearDown() { PackingEnv.reset() }

    func testNameLookAlikesAreFoundAndNotSameHidesThem() {
        var lib = Library()
        let a = newItem(name: "Sunglasses"), b = newItem(name: "Sun glasses"), c = newItem(name: "Towel")
        lib.items += [a, b, c]
        let pairs = lib.lookAlikePairs()
        XCTAssertEqual(pairs.count, 1)
        XCTAssertEqual(Set([pairs[0].a.id, pairs[0].b.id]), [a.id, b.id])
        XCTAssertEqual(pairs[0].why, "Same name")
        XCTAssertTrue(lib.markNotSame(a.id, b.id))
        XCTAssertTrue(lib.lookAlikePairs().isEmpty, "never offered again")
    }

    func testSameSerialIsFoundAndBagsAndGoneThingsAreNotOffered() {
        var lib = Library()
        var a = newItem(name: "Camera"), b = newItem(name: "Old camera")
        a.serial = "SN 12345"; b.serial = "12345"
        lib.items += [a, b]
        XCTAssertEqual(lib.lookAlikePairs().map(\.why), ["Same serial number"])
        let bag1 = lib.addBag(name: "Duffel")!
        lib.items.append(newItem(name: "Duffel 2"))
        lib.items.append(newItem(name: "duffel"))   // a thing named like a bag is not a bag, but the bag is skipped
        XCTAssertFalse(lib.lookAlikePairs().contains { $0.a.id == bag1.id || $0.b.id == bag1.id })
        let n = lib.items.firstIndex { $0.id == b.id }!
        Library.setGone(&lib.items[n], GoneMark(on: "2026-01-01", how: .givenAway))
        XCTAssertTrue(lib.lookAlikePairs().filter { $0.why == "Same serial number" }.isEmpty, "a gone thing is not offered")
    }

    func testMergeFillsMovesAndSettlesDoubles() {
        var lib = Library()
        var keep = newItem(name: "Sunglasses"); keep.note = "Mine"
        var from = newItem(name: "Sun glasses"); from.manufacturer = "Ray"; from.serial = "AB1234"; from.note = "Case in drawer"
        let kit = newItem(name: "Beach kit")
        lib.items += [keep, from, kit]
        let k = keep.id, f = from.id

        let t1 = newList(name: "Beach"), t2 = newList(name: "City")
        lib.templates += [t1, t2]
        lib.memberships += [newMembership(itemId: k, templateId: t1.id), newMembership(itemId: f, templateId: t1.id),
                            newMembership(itemId: f, templateId: t2.id)]
        lib.kits.append(newKit(name: "Sun", itemIds: [k, f]))
        let kn = lib.items.firstIndex { $0.id == kit.id }!
        lib.items[kn].extra[KIT_CONTENTS_KEY] = .array([.string(k), .string(f)])

        var l1 = newItem(name: "Sunglasses"); l1.sourceItemId = k
        var l2 = newItem(name: "Sun glasses"); l2.sourceItemId = f; l2.checked = true
        lib.trips.append(newEvent(name: "Rome", entries: [l1, l2]))
        lib.actions.append(newAction(text: "Clean them", itemId: f, itemName: "Sun glasses"))

        XCTAssertFalse(lib.mergeThing(keep: k, from: k))
        XCTAssertTrue(lib.mergeThing(keep: k, from: f))

        XCTAssertFalse(lib.items.contains { $0.id == f }, "the other is gone")
        let kept = lib.items.first { $0.id == k }!
        XCTAssertEqual(kept.name, "Sunglasses")
        XCTAssertEqual(kept.manufacturer, "Ray"); XCTAssertEqual(kept.serial, "AB1234")
        XCTAssertTrue(kept.note.contains("Mine") && kept.note.contains("Case in drawer"), "notes joined")
        XCTAssertEqual(lib.memberships.filter { $0.itemId == k }.count, 2, "one per template, none doubled")
        XCTAssertFalse(lib.memberships.contains { $0.itemId == f })
        XCTAssertEqual(lib.kits[0].itemIds, [k], "once in the kit")
        XCTAssertEqual(Library.listedContents(lib.items.first { $0.id == kit.id }!), [k], "once in the contents")
        let lines = lib.trips[0].entries
        XCTAssertEqual(lines.count, 1, "one line on the trip")
        XCTAssertTrue(lines[0].checked, "ticked if either was")
        XCTAssertEqual(lib.actions[0].itemId, k, "the to-do points to the kept one")
    }
}
