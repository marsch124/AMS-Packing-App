import XCTest
@testable import PackingCore

// Ported from tests/model.test.mjs — "Editable conditions (v113)".
// Every test restores the factory list afterwards: setItemConditions replaces the
// module's live list, so leaking a custom one would poison later tests.
final class ItemConditionsTests: XCTestCase {
    override func tearDown() {
        setItemConditions(DEFAULT_ITEM_CONDITIONS)
        PackingEnv.reset()
        super.tearDown()
    }

    // JS: 'itemConditionLabel: every condition has a label, unrated has none'
    func testItemConditionLabelEveryConditionHasALabelUnratedHasNone() {
        for c in ITEM_CONDITIONS { XCTAssertEqual(itemConditionLabel(c.id), c.label) }
        XCTAssertEqual(itemConditionLabel(""), "")
        // An id this device has no name for shows AS ITSELF rather than vanishing — it
        // belongs to a condition set on another device, or one since removed.
        XCTAssertEqual(itemConditionLabel("nonsense"), "nonsense")
    }

    // JS: 'coerceCondition: trims, bounds and rejects an unknown tone'
    func testCoerceConditionTrimsBoundsAndRejectsAnUnknownTone() {
        let c = coerceCondition(json: ["id": "  worn  ", "label": "  Worn  ", "tone": "purple", "replace": 1])
        XCTAssertEqual(c.id, "worn")
        XCTAssertEqual(c.label, "Worn")
        XCTAssertEqual(c.tone, "")            // not one of the three tones
        XCTAssertEqual(c.replace, true)       // coerced to a real boolean
        XCTAssertEqual(coerceCondition(json: nil).id, "")
        XCTAssertEqual(coerceCondition(json: ["id": .string(String(repeating: "x", count: 80))]).id.count, 40)
    }

    // JS: 'newCondition: makes a readable id and never collides'
    func testNewConditionMakesAReadableIdAndNeverCollides() {
        XCTAssertEqual(newCondition("Being repaired").id, "being-repaired")
        XCTAssertEqual(newCondition("Worn", ["worn"]).id, "worn-2")
        XCTAssertEqual(newCondition("Worn", ["worn", "worn-2"]).id, "worn-3")
        XCTAssertTrue(newCondition("!!!").id.hasPrefix("cond-"))   // nothing usable in the name
        XCTAssertEqual(newCondition("Failing").label, "Failing")
    }

    // JS: 'setItemConditions: mutates the shared arrays in place, so importers stay live'
    // (The "same array identity" assertions are a JS module-binding concern with no
    // Swift counterpart: here ITEM_CONDITIONS is one module variable everyone reads.)
    func testSetItemConditionsReplacesTheLiveListAndItsIds() {
        setItemConditions(json: [["id": "fine", "label": "Fine"],
                                 ["id": "failing", "label": "Failing", "tone": "danger", "replace": true]])
        XCTAssertEqual(ITEM_CONDITION_IDS, ["fine", "failing"])
        XCTAssertEqual(ITEM_CONDITIONS.count, 2)
        setItemConditions(DEFAULT_ITEM_CONDITIONS)
        XCTAssertEqual(ITEM_CONDITION_IDS, DEFAULT_ITEM_CONDITIONS.map { $0.id })
    }

    // JS: 'setItemConditions: drops unusable rows and never leaves the app with none'
    func testSetItemConditionsDropsUnusableRowsAndNeverLeavesTheAppWithNone() {
        setItemConditions(json: [["id": "", "label": "No id"], ["id": "a", "label": ""],
                                 ["id": "ok", "label": "Ok"], ["id": "ok", "label": "Dupe"]])
        XCTAssertEqual(ITEM_CONDITION_IDS, ["ok"])
        setItemConditions(json: [])
        // An empty list falls back to the factory four rather than leaving nothing.
        XCTAssertEqual(ITEM_CONDITION_IDS, DEFAULT_ITEM_CONDITIONS.map { $0.id })
    }

    // JS: 'conditionReplaces / conditionTone: behaviour follows the flag, not the id'
    func testConditionReplacesAndToneFollowTheFlagNotTheId() {
        XCTAssertEqual(conditionReplaces("retire"), true)     // the built-in one
        XCTAssertEqual(conditionReplaces("worn"), false)
        XCTAssertEqual(conditionTone("worn"), "warn")
        XCTAssertEqual(conditionTone("good"), "")
        setItemConditions([ItemCondition(id: "failing", label: "Failing", tone: "danger", replace: true)])
        XCTAssertEqual(conditionReplaces("failing"), true)    // a condition you invented does the job
        XCTAssertEqual(conditionReplaces("retire"), false)    // ...and the old id no longer does
        XCTAssertNil(itemCondition("retire"))
    }
}
