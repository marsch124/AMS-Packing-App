import XCTest
@testable import PackingCore

// Ported from tests/model.test.mjs — "Shopping list (pre-trip restock & replace)",
// the shoppingReason test of "Editable conditions (v113)", and "v163: gear that runs
// out before you get home".
// ('action kind: …' and 'consumable flag survives …' from the same JS section are
// already in ActionsTests / ItemsTests.)
final class ShoppingTests: XCTestCase {
    override func tearDown() {
        setItemConditions(DEFAULT_ITEM_CONDITIONS)
        PackingEnv.reset()
        super.tearDown()
    }

    let SHOP_TODAY = "2026-08-18T00:00:00Z"

    // JS: 'shoppingReason: most-urgent reason wins'
    func testShoppingReasonMostUrgentReasonWins() {
        XCTAssertEqual(shoppingReason(newItem(consumable: true, condition: "retire"), SHOP_TODAY), "Needs replacing")
        XCTAssertEqual(shoppingReason(newItem(expiry: "2026-01-01"), SHOP_TODAY), "Expired")
        XCTAssertEqual(shoppingReason(newItem(expiry: "2026-09-01"), SHOP_TODAY), "Replace soon") // within 30d
        XCTAssertEqual(shoppingReason(newItem(consumable: true), SHOP_TODAY), "Restock")
        XCTAssertEqual(shoppingReason(newItem(expiry: "2027-01-01"), SHOP_TODAY), "") // far future, nothing
        XCTAssertEqual(shoppingReason(newItem(name: "Phone"), SHOP_TODAY), "")
    }

    // JS: 'shoppingSuggestions: skips retired + already-listed, sorts by urgency'
    func testShoppingSuggestionsSkipsRetiredAndAlreadyListedSortsByUrgency() {
        let items = [
            newItem(id: "a", name: "Sunscreen", expiry: "2026-01-01"),
            newItem(id: "b", name: "Energy gels", consumable: true),
            newItem(id: "c", name: "Running shoes", condition: "retire"),
            newItem(id: "d", name: "Rope", expiry: "2026-09-01"),
            newItem(id: "e", name: "Phone"),
            newItem(id: "f", name: "Old tent", consumable: true, retired: true),
        ]
        // gels already on the list
        let actions = [coerceAction(json: ["kind": "shopping", "done": false, "itemId": "b"])].compactMap { $0 }
        XCTAssertEqual(actions.count, 1)
        let sug = shoppingSuggestions(items, actions, SHOP_TODAY)
        XCTAssertEqual(sug.map { [$0.item.name, $0.reason] }, [
            ["Running shoes", "Needs replacing"],
            ["Sunscreen", "Expired"],
            ["Rope", "Replace soon"],
        ])
    }

    // JS: 'openShoppingCount counts only open shopping-kind actions'
    func testOpenShoppingCountCountsOnlyOpenShoppingKindActions() {
        let actions = [
            coerceAction(json: ["kind": "shopping", "done": false]),
            coerceAction(json: ["kind": "shopping", "done": true]),
            coerceAction(json: ["kind": "todo", "done": false]),
        ].compactMap { $0 }
        XCTAssertEqual(actions.count, 3)
        XCTAssertEqual(openShoppingCount(actions), 1)
        XCTAssertTrue(EXPIRY_SOON_DAYS > 0)
    }

    // JS: 'shoppingReason: any "needs replacing" condition feeds the buy list'
    func testShoppingReasonAnyNeedsReplacingConditionFeedsTheBuyList() {
        let today = "2026-08-24T00:00:00Z"
        XCTAssertEqual(shoppingReason(newItem(name: "Shoes", condition: "retire"), today), "Needs replacing")
        XCTAssertEqual(shoppingReason(newItem(name: "Shoes", condition: "worn"), today), "")
        setItemConditions(json: [["id": "failing", "label": "Failing", "tone": "danger", "replace": true],
                                 ["id": "ok", "label": "Ok"]])
        XCTAssertEqual(shoppingReason(newItem(name: "Shoes", condition: "failing"), today), "Needs replacing")
        XCTAssertEqual(shoppingReason(newItem(name: "Shoes", condition: "ok"), today), "")
    }

    // JS: 'expiringOnTrip: judged against the TRIP’s end, not today plus a month'
    func testExpiringOnTripJudgedAgainstTheTripsEndNotTodayPlusAMonth() {
        let entries = [
            Item(id: "a", name: "Sunscreen", expiry: "2026-10-15"),
            Item(id: "b", name: "Gas canister", expiry: "2026-08-01"),
            Item(id: "c", name: "Boots", expiry: ""),
            Item(id: "d", name: "Paracetamol", expiry: "2027-05-01"),
        ]
        let r = expiringOnTrip(entries, "2026-10-20", "2026-09-10")
        XCTAssertEqual(r.map { $0.entry.name }, ["Gas canister", "Sunscreen"], "soonest first")
        XCTAssertEqual(r[0].alreadyOut, true)
        XCTAssertEqual(r[1].alreadyOut, false)
        // 35 days out is beyond shoppingReason's fixed 30-day window, so only the trip
        // itself could ever have caught this one.
        XCTAssertEqual(r[1].daysLeft, 35)
    }

    // JS: 'expiringOnTrip: nothing without an end date, and nothing that outlasts the trip'
    func testExpiringOnTripNothingWithoutAnEndDateAndNothingThatOutlastsTheTrip() {
        let entries = [Item(id: "a", name: "Sunscreen", expiry: "2026-10-15")]
        XCTAssertEqual(expiringOnTrip(entries, "", "2026-09-10"), [])
        XCTAssertEqual(expiringOnTrip(entries, "2026-09-20", "2026-09-10"), [], "still good when you get home")
        XCTAssertEqual(expiringOnTrip(entries, "2026-10-15", "2026-09-10").count, 1, "the day itself counts")
    }

    // JS: 'expiringOnTrip: one line per thing, and reminders are not gear'
    func testExpiringOnTripOneLinePerThingAndRemindersAreNotGear() {
        let entries = [
            Item(id: "1", name: "Sunscreen", expiry: "2026-10-01", sourceItemId: "item-x"),
            Item(id: "2", name: "Sunscreen", expiry: "2026-10-01", sourceItemId: "item-x"), // same item, two templates
            Item(id: "3", name: "Renew passport", itemType: "reminder", expiry: "2026-10-01"),
            Item(id: "4", name: "Old stove", expiry: "2026-10-01", retired: true),
        ]
        let r = expiringOnTrip(entries, "2026-10-20", "2026-09-10")
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r[0].entry.sourceItemId, "item-x")
    }

    // --- not in the JS suite: the edges of this slice that JS only reaches through
    // --- `daysUntil` (owned by the trip slice; a stand-in here until the merge)

    func testShoppingReasonAnUnreadableDateRaisesNothingButStillRestocks() {
        // `Date.parse('2026-13-40T00:00:00Z')` is NaN → daysUntil null → no date reason.
        XCTAssertEqual(shoppingReason(Item(expiry: "2026-13-40"), SHOP_TODAY), "")
        XCTAssertEqual(shoppingReason(Item(consumable: true, expiry: "2026-13-40"), SHOP_TODAY), "Restock")
        XCTAssertEqual(shoppingReason(nil, SHOP_TODAY), "")
        // Exactly 30 days out still counts as soon; 31 does not.
        XCTAssertEqual(shoppingReason(Item(expiry: "2026-09-17"), SHOP_TODAY), "Replace soon")
        XCTAssertEqual(shoppingReason(Item(expiry: "2026-09-18"), SHOP_TODAY), "")
        // The day itself is not yet "Expired".
        XCTAssertEqual(shoppingReason(Item(expiry: "2026-08-18"), SHOP_TODAY), "Replace soon")
        XCTAssertEqual(shoppingReason(Item(expiry: "2026-08-17"), SHOP_TODAY), "Expired")
    }

    func testExpiringOnTripFallsBackToTheEntryIdAndReadsALongEndDate() {
        let entries = [
            Item(id: "x", name: "Gels", expiry: "2026-10-01", sourceItemId: ""),   // '' is falsy → the id
            Item(id: "x", name: "Gels again", expiry: "2026-09-01"),
        ]
        let r = expiringOnTrip(entries, "2026-10-20T18:00:00Z", "2026-09-10T07:00:00Z")
        XCTAssertEqual(r.map { $0.entry.name }, ["Gels"])
        XCTAssertEqual(r[0].daysLeft, 21)
        XCTAssertEqual(r[0].json["daysLeft"], 21)
    }
}

// JS tests of this section NOT ported here: 'action kind: defaults to todo…' and
// 'consumable flag survives coerceItem/newItem' were already ported by the foundation
// slice (ActionsTests, ItemsTests). Everything else is above.
