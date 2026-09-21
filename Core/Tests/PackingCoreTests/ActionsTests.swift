import XCTest
@testable import PackingCore

// Ported from tests/model.test.mjs — the one test of coerceAction / newAction in
// this slice. (The shopping-list tests belong to a later section.)
final class ActionsTests: XCTestCase {
    override func tearDown() {
        setPhases(DEFAULT_PHASES)
        PackingEnv.reset()
        super.tearDown()
    }

    // JS: 'action kind: defaults to todo, keeps a valid shopping kind'
    func testActionKindDefaultsToTodoKeepsAValidShoppingKind() {
        XCTAssertEqual(newAction().kind, "todo")
        XCTAssertEqual(coerceAction(json: ["kind": "shopping"])?.kind, "shopping")
        XCTAssertEqual(coerceAction(json: ["kind": "nonsense"])?.kind, "todo")
    }

    // --- not in the JS suite (compareActions has no JS test; the order is Node's) ---

    func testCompareActionsOpenFirstHighFirstSoonerFirstNewestFirst() {
        func mk(_ id: String, priority: String = "normal", whenPhase: String = "", whenDate: String = "",
                done: Bool = false, createdAt: String) -> ActionItem {
            newAction(id: id, priority: priority, whenPhase: whenPhase, whenDate: whenDate, done: done, createdAt: createdAt)
        }
        let list = [
            mk("done", priority: "high", done: true, createdAt: "2026-01-05"),
            mk("norm-new", createdAt: "2026-01-04"),
            mk("norm-old", createdAt: "2026-01-02"),
            mk("high-phase", priority: "high", whenPhase: "door", createdAt: "2026-01-01"),
            mk("high-date", priority: "high", whenDate: "2026-09-01", createdAt: "2026-01-01"),
            mk("high-unknown", priority: "high", whenPhase: "from-the-mac", createdAt: "2026-01-01"),
            mk("high-untimed", priority: "high", createdAt: "2026-01-03"),
        ]
        XCTAssertEqual(list.stableSorted(compare: compareActions).map { $0.id },
                       ["high-date", "high-phase", "high-unknown", "high-untimed", "norm-new", "norm-old", "done"])
    }

    func testCoerceActionRules() throws {
        PackingEnv.freeze(at: "2026-08-20T12:00:00.000Z")
        let a = try XCTUnwrap(coerceAction(json: ["text": 5, "priority": "urgent", "whenPhase": "  from-the-mac  ", "whenDate": "soon", "done": 1]))
        XCTAssertEqual(a.text, "")
        XCTAssertEqual(a.priority, "normal")
        XCTAssertEqual(a.whenPhase, "from-the-mac")             // an unknown phase is KEPT, trimmed
        XCTAssertEqual(a.whenDate, "")
        XCTAssertEqual(a.done, true)
        XCTAssertEqual(a.createdAt, "2026-08-20T12:00:00.000Z")  // a missing createdAt becomes now
        XCTAssertEqual(a.updatedAt, a.createdAt)                 // …and a missing updatedAt follows it
        XCTAssertEqual(actionPriorityLabel("high"), "High")
        XCTAssertEqual(actionPriorityLabel("nope"), "Normal")
        XCTAssertNil(coerceAction(json: nil))
        let back = try JSONDecoder().decode(ActionItem.self, from: JSONEncoder().encode(a))
        XCTAssertEqual(back, a)
        XCTAssertNil(a.json["phase"])
        // 🪤 The key `referencedListValues` reads (see ActionItem.phase).
        XCTAssertEqual(coerceAction(json: ["phase": "prep"])?.phase, "prep")
    }
}
