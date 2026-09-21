import XCTest
@testable import PackingCore

// Ported from tests/model.test.mjs — "The editable, synced "When" timeline (v118)".
// PHASES is a live list shared by the whole module, so every test restores the
// factory seven afterwards (the JS `withPhases` helper; here it is `tearDown`).
final class PhasesTests: XCTestCase {
    override func tearDown() {
        setPhases(DEFAULT_PHASES)
        PackingEnv.reset()
        super.tearDown()
    }

    // JS: 'setPhases: sorts by order, renumbers, and drops the unusable'
    func testSetPhasesSortsByOrderRenumbersAndDropsTheUnusable() {
        setPhases(json: [
            ["id": "b", "label": "Second", "order": 5],
            ["id": "a", "label": "First", "order": 1],
            ["id": "", "label": "No id", "order": 2],          // dropped
            ["id": "c", "label": "", "order": 3],              // dropped
            ["id": "a", "label": "Duplicate id", "order": 4],  // dropped
        ])
        XCTAssertEqual(PHASES.map { $0.id }, ["a", "b"])
        XCTAssertEqual(PHASES.map { $0.order }, [0, 1])   // renumbered, so two devices agree
        XCTAssertEqual(PHASE_IDS, ["a", "b"])             // the ids list is kept in step
    }

    // JS: 'setPhases: an empty list falls back to the factory seven, never to nothing'
    func testSetPhasesAnEmptyListFallsBackToTheFactorySeven() {
        setPhases(json: [])
        XCTAssertEqual(PHASES.count, DEFAULT_PHASES.count)
        XCTAssertEqual(PHASES.map { $0.id }, DEFAULT_PHASES.map { $0.id })
        // (the typed form too)
        setPhases([Phase]())
        XCTAssertEqual(PHASES.map { $0.id }, DEFAULT_PHASES.map { $0.id })
    }

    // JS: 'coercePhase: fills in an emoji, a colour and a sane lead time'
    func testCoercePhaseFillsInAnEmojiAColourAndASaneLeadTime() {
        let p = coercePhase(json: ["id": "x", "label": "X"], 0)
        XCTAssertFalse(p.emoji.isEmpty)
        XCTAssertTrue(isHexColor(p.color))
        XCTAssertEqual(p.leadDays, 0)
        XCTAssertEqual(p.task, false)
        XCTAssertEqual(coercePhase(json: ["id": "x", "label": "X", "leadDays": 9999]).leadDays, 365)   // clamped
        XCTAssertEqual(coercePhase(json: ["id": "x", "label": "X", "leadDays": -50]).leadDays, -1)     // clamped
        XCTAssertEqual(coercePhase(json: ["id": "x", "label": "X", "leadDays": "soon"]).leadDays, 0)
    }

    // JS: 'newPhase: earns a readable id and never collides'
    func testNewPhaseEarnsAReadableIdAndNeverCollides() {
        XCTAssertEqual(newPhase("Load the car", []).id, "load-the-car")
        XCTAssertEqual(newPhase("Load the car", ["load-the-car"]).id, "load-the-car-2")
        XCTAssertTrue(newPhase("!!!", []).id.hasPrefix("phase-"))
    }

    // JS: 'the built-in phase ids are stable — two devices seeding must not double up'
    func testTheBuiltInPhaseIdsAreStable() {
        // If these ever change, a device that seeds independently writes DIFFERENT
        // primary keys and the two lists merge into fourteen phases instead of seven.
        XCTAssertEqual(DEFAULT_PHASES.map { $0.id },
                       ["prep", "week", "daybefore", "morning", "door", "wear", "after"])
    }

    // JS: 'phaseOrFallback: an unknown id is shown, never swapped for a real phase'
    func testPhaseOrFallbackAnUnknownIdIsShown() {
        let p = phaseOrFallback("a-phase-from-the-other-device")
        XCTAssertEqual(p.id, "a-phase-from-the-other-device")
        XCTAssertEqual(p.label, "a-phase-from-the-other-device")   // reads as itself rather than vanishing
        XCTAssertFalse(p.emoji.isEmpty)
        XCTAssertEqual(phaseLeadDays("nonsense"), 0)
        XCTAssertFalse(phaseEmoji("nonsense").isEmpty)
    }

    // JS: 'phaseOrder: an unknown phase sorts to the END, not into the middle'
    func testPhaseOrderAnUnknownPhaseSortsToTheEnd() {
        XCTAssertEqual(phaseOrder("prep"), 0)
        XCTAssertEqual(phaseOrder("unknown"), PHASE_IDS.count)
    }

    // JS: 'defaultPhaseId: a new item lands on the first phase you actually pack in'
    func testDefaultPhaseIdLandsOnTheFirstPhaseYouActuallyPackIn() {
        XCTAssertEqual(defaultPhaseId(), "week")           // 'prep' is a to-do phase, so it is skipped
        setPhases(json: [["id": "only", "label": "Only", "task": true, "order": 0]])
        XCTAssertEqual(defaultPhaseId(), "only")           // ...unless there is nothing else
    }

    // JS: 'phasesCustomised: true only once the list really differs from the standard seven'
    func testPhasesCustomisedOnlyOnceTheListReallyDiffers() {
        XCTAssertEqual(phasesCustomised(), false)
        setPhases(DEFAULT_PHASES.enumerated().map { (i, p) -> Phase in
            var q = p
            if i == 3 { q.label = "The morning of" }
            return q
        })
        XCTAssertEqual(phasesCustomised(), true)
        setPhases(DEFAULT_PHASES.map { p -> Phase in var q = p; q.emoji = "🧳"; return q })
        XCTAssertEqual(phasesCustomised(), true)
        setPhases(DEFAULT_PHASES)
        XCTAssertEqual(phasesCustomised(), false)
    }

    // JS: 'setPhases: a tie on order is broken deterministically, so two devices agree'
    func testSetPhasesATieOnOrderIsBrokenDeterministically() {
        // Two phases sharing an order is not hypothetical — an added phase is appended
        // at the end, and both devices may append. Without a stable second key each
        // device would renumber them in whatever order it read them, then write that
        // back and fight the other one.
        let a: JSONValue = [["id": "zulu", "label": "Z", "order": 6], ["id": "alpha", "label": "A", "order": 6]]
        let b: JSONValue = [["id": "alpha", "label": "A", "order": 6], ["id": "zulu", "label": "Z", "order": 6]]
        func orderOf(_ list: JSONValue) -> [String] { setPhases(json: list); return PHASES.map { $0.id } }
        XCTAssertEqual(orderOf(a), orderOf(b))
        XCTAssertEqual(orderOf(a), ["alpha", "zulu"])
    }

    // --- not in the JS suite: the Swift-only surfaces ---

    func testPhaseLookupsAndTheTypedAndJSONFormsAgree() {
        XCTAssertNil(phase("nope"))
        XCTAssertEqual(phase("door")?.label, "At the front door")
        XCTAssertEqual(phaseLabel(""), "Unsorted")
        XCTAssertEqual(phaseColor("week"), "#3b82f6")
        XCTAssertEqual(phaseLeadDays("after"), -1)
        // A missing order falls to the position; a missing colour to the palette at that position.
        let p = coercePhase(json: ["id": "x", "label": "X"], 3)
        XCTAssertEqual(p.order, 3)
        XCTAssertEqual(p.color, TEMPLATE_COLORS[3])
        XCTAssertEqual(p.emoji, PHASE_DEFAULT_EMOJI)
        // newPhase lays the partial over { id, label }, as the app does with { order }.
        XCTAssertEqual(newPhase("Load the car", ["a", "b"], ["order": 7]).order, 7)
        XCTAssertEqual(newPhase("Load the car", ["a", "b"]).order, 2)
        // Codable goes through the same rules.
        let data = Data(#"{"id":"  x ","label":"X","leadDays":"12.5","task":1}"#.utf8)
        let decoded = try? JSONDecoder().decode(Phase.self, from: data)
        XCTAssertEqual(decoded?.id, "x")
        XCTAssertEqual(decoded?.leadDays, 13)      // Math.round(12.5)
        XCTAssertEqual(decoded?.task, true)
    }

    func testNewPhaseTimestampIdUsesTheInjectedClock() {
        PackingEnv.freeze(at: "2026-01-01T00:00:00.000Z")
        XCTAssertEqual(newPhase("!!!").id, "phase-\(String(Int64(1_767_225_600_000), radix: 36))")
    }
}
