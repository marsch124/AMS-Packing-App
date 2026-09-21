import XCTest
@testable import PackingCore

// Ported from tests/model.test.mjs — 'The "is this device missing anything?"
// self-check (v129)', plus the one referencedListValues test that sits in the JS
// "People" section.
//
// The shape being detected is the real one: an iPhone that held 2 storage places
// out of 17 and 1 item condition out of 6, while every item that pointed at the
// other 15 and the other 5 had synced down perfectly. See the write-up in DeviceAudit.swift.
final class DeviceAuditTests: XCTestCase {
    override func tearDown() {
        PackingEnv.reset()
        super.tearDown()
    }

    /// JS: `const auditItem = (over = {}) => ({ storage: '', ownedBy: '', condition: '', phase: '', ...over })`
    /// Raw JSON on purpose: these are NOT coerced items (a blank phase stays blank).
    private func auditItem(_ over: [String: JSONValue] = [:]) -> JSONValue {
        var o: [String: JSONValue] = ["storage": "", "ownedBy": "", "condition": "", "phase": ""]
        for (k, v) in over { o[k] = v }
        return .object(o)
    }
    private func lists(_ items: [JSONValue]) -> JSONValue { ["lists": [["items": .array(items)]]] }

    // JS: 'referencedListValues sees a packer set on a catalog item, not only on a trip'
    func testReferencedListValuesSeesAPackerSetOnACatalogItemNotOnlyOnATrip() {
        let lists = [newList(name: "Dive", items: [newItem(name: "Wetsuit", packer: "Anna")])]
        XCTAssertTrue(referencedListValues(lists: lists).has("people", "anna"))
        XCTAssertTrue(referencedListValues(lists: lists).people.contains("anna"))
    }

    // JS: 'referencedListValues: gathers what the device data points at, normalised'
    func testReferencedListValuesGathersWhatTheDeviceDataPointsAtNormalised() {
        let arg: JSONValue = [
            "lists": [[
                "items": [
                    auditItem(["storage": "Loft", "ownedBy": "Anna", "condition": "worn", "phase": "week"]),
                    auditItem(["storage": "  loft  ", "ownedBy": "anna", "condition": "worn", "phase": "door"]),
                    auditItem(["storage": "Boat locker", "ownedBy": "", "condition": "", "phase": "week"]),
                ],
            ]],
            "events": [["entries": [["storage": "Garage", "packer": "Martin", "phase": "after"]]]],
            "actions": [["phase": "prep"]],
        ]
        let r = referencedListValues(json: arg)
        // Case and spacing collapse, so "Loft" and "  loft  " are one place.
        XCTAssertEqual(r.places.sorted(), ["boat locker", "garage", "loft"])
        XCTAssertEqual(r.owners.sorted(), ["anna"])
        XCTAssertEqual(r.conditions.sorted(), ["worn"])
        XCTAssertEqual(r.people.sorted(), ["martin"])
        XCTAssertEqual(r.phases.sorted(), ["after", "door", "prep", "week"])
        // Blanks are never referenced values.
        XCTAssertFalse(r.owners.contains(""))
        // The spelling as written is kept alongside, so what he is shown reads like his
        // own data — "Loft", not the "loft" the comparison runs on. First seen wins.
        XCTAssertEqual(r.shown("places", "loft"), "Loft")
        XCTAssertEqual(r.shown("places", "boat locker"), "Boat locker")
        XCTAssertEqual(r.shown("people", "martin"), "Martin")

        // The same data as typed values gives the same answer. (`Item(…)` does not
        // coerce, so a blank stays blank; the to-do carries the `phase` key the JS reads.)
        func it(_ storage: String, _ ownedBy: String, _ condition: String, _ phase: String) -> Item {
            Item(phase: phase, storage: storage, ownedBy: ownedBy, condition: condition)
        }
        let typed = referencedListValues(
            lists: [PackList(items: [it("Loft", "Anna", "worn", "week"), it("  loft  ", "anna", "worn", "door"),
                                     it("Boat locker", "", "", "week")])],
            events: [TripEvent(entries: [Item(phase: "after", packer: "Martin", storage: "Garage")])],
            actions: [ActionItem(phase: "prep")]
        )
        XCTAssertEqual(typed, r)
    }

    // JS: 'referencedListValues: survives junk without throwing'
    func testReferencedListValuesSurvivesJunkWithoutThrowing() {
        let r = referencedListValues(json: ["lists": [nil, ["items": nil], ["items": [nil]]], "events": [nil], "actions": [nil]])
        for k in AUDITABLE_KINDS { XCTAssertEqual(r[k].count, 0) }
        // JS: Object.keys(referencedListValues()) is the five kinds plus 'display'.
        // Here `display` is a property of its own, holding the same five kinds.
        XCTAssertEqual(referencedListValues().values.keys.sorted(), AUDITABLE_KINDS.sorted())
        XCTAssertEqual(referencedListValues().display.keys.sorted(), AUDITABLE_KINDS.sorted())
        XCTAssertEqual(referencedListValues(json: nil), referencedListValues())
    }

    // JS: 'auditList: names what the list has never heard of'
    func testAuditListNamesWhatTheListHasNeverHeardOf() {
        let referenced = ReferencedListValues(["places": ["loft", "garage", "boat locker"]])
        let r = auditList("places", referenced, json: ["Loft", "Garage"])
        XCTAssertEqual(r.listed, 2)
        XCTAssertEqual(r.used, 3)
        XCTAssertEqual(r.missing, ["boat locker"])
        // With no spellings supplied it falls back to the key rather than showing blanks.
        XCTAssertEqual(r.missingLabels, ["boat locker"])
        let spelled = auditList("places",
                                ReferencedListValues(["places": ["boat locker"]],
                                                     display: ["places": [ReferencedSpelling(key: "boat locker", shown: "Boat locker")]]),
                                json: [])
        XCTAssertEqual(spelled.missingLabels, ["Boat locker"])
        // Nothing missing when the list covers everything, whatever the spelling.
        XCTAssertEqual(auditList("places", referenced, json: ["LOFT", " garage ", "Boat Locker"]).missing, [])
        // A list holding more than is in use is not a fault — that is the normal case.
        XCTAssertEqual(auditList("places", ReferencedListValues(["places": ["loft"]]), json: ["Loft", "Shed", "Attic"]).missing, [])
    }

    // JS: 'auditList: conditions and phases are matched by ID, people and places by name'
    func testAuditListConditionsAndPhasesAreMatchedByIDPeopleAndPlacesByName() {
        // Items store a condition's slug, not its label — so the comparison must too.
        let byId = auditList("conditions", ReferencedListValues(["conditions": ["worn-out", "new"]]),
                             json: [["id": "new", "label": "New"]])
        XCTAssertEqual(byId.missing, ["worn-out"])
        // Matching on the LABEL instead would wrongly report "new" as missing here.
        XCTAssertEqual(auditList("conditions", ReferencedListValues(["conditions": ["new"]]),
                                 json: [["id": "new", "label": "Brand new"]]).missing, [])
        XCTAssertEqual(auditList("phases", ReferencedListValues(["phases": ["week", "custom-1"]]),
                                 json: [["id": "week", "label": "The week before"]]).missing, ["custom-1"])
        XCTAssertEqual(auditList("people", ReferencedListValues(["people": ["anna"]]), json: [["name": "Anna"]]).missing, [])
        // A kind nothing points at (trip presets) is never audited.
        XCTAssertFalse(AUDITABLE_KINDS.contains("presets"))
        XCTAssertEqual(auditList("presets", ReferencedListValues(["presets": ["x"]]), json: []).missing, [])
    }

    // JS: 'auditDeviceLists: the real iPhone — 2 places of 17, 1 condition of 6 — reads as broken'
    func testAuditDeviceListsTheRealIPhoneReadsAsBroken() {
        let places = (0..<17).map { "Place \($0 + 1)" }
        let conds = (0..<6).map { ItemCondition(id: "c\($0 + 1)", label: "C\($0 + 1)") }
        let arg = lists(places.enumerated().map { i, p in
            auditItem(["storage": .string(p), "condition": .string(conds[i % 6].id)])
        })
        let a = auditDeviceLists(
            referenced: referencedListValues(json: arg),
            json: ["places": JSONValue(Array(places.prefix(2))), "owners": [],
                   "conditions": .array(conds.prefix(1).map { ["id": .string($0.id), "label": .string($0.label)] }),
                   "people": [], "phases": []],
            signedIn: true,
            hasCatalogue: true
        )
        XCTAssertEqual(a.level, "broken")
        let byKind = Dictionary(uniqueKeysWithValues: a.lists.map { ($0.kind, $0) })
        XCTAssertEqual(byKind["places"]?.missing.count, 15)
        XCTAssertEqual(byKind["conditions"]?.missing.count, 5)
        XCTAssertEqual(a.missingTotal, 20)
        XCTAssertEqual(a.broken.map { $0.kind }.sorted(), ["conditions", "places"])
        // The typed `inForce` gives the same verdict.
        let typed = auditDeviceLists(
            referenced: referencedListValues(json: arg),
            inForce: ListsInForce(places: Array(places.prefix(2)), conditions: Array(conds.prefix(1))),
            signedIn: true, hasCatalogue: true
        )
        XCTAssertEqual(typed, a)
    }

    // JS: 'auditDeviceLists: the healthy Mac holding all seventeen says ok'
    func testAuditDeviceListsTheHealthyMacHoldingAllSeventeenSaysOk() {
        let places = (0..<17).map { "Place \($0 + 1)" }
        let a = auditDeviceLists(
            referenced: referencedListValues(json: lists(places.map { auditItem(["storage": .string($0)]) })),
            json: ["places": JSONValue(places), "owners": [], "conditions": [], "people": [], "phases": []],
            signedIn: true,
            hasCatalogue: true
        )
        XCTAssertEqual(a.level, "ok")
        XCTAssertEqual(a.missingTotal, 0)
        XCTAssertEqual(a.gappy, [])
    }

    // JS: 'auditDeviceLists: a stray or two never raises an alarm'
    func testAuditDeviceListsAStrayOrTwoNeverRaisesAnAlarm() {
        // Deleting a place you no longer keep anything in leaves the items pointing at
        // it on purpose — the app goes on offering it. That must read as ok, not broken.
        let kept = ["Loft", "Garage", "Shed", "Attic", "Cellar"]
        let items = (kept + ["Old boat locker", "Sold caravan"]).map { auditItem(["storage": .string($0)]) }
        let inForce: JSONValue = ["places": JSONValue(kept), "owners": [], "conditions": [], "people": [], "phases": []]
        let a = auditDeviceLists(referenced: referencedListValues(json: lists(items)), json: inForce,
                                 signedIn: true, hasCatalogue: true)
        XCTAssertEqual(AUDIT_STRAY_TOLERANCE, 2)
        XCTAssertEqual(a.level, "ok")
        // One more stray and it is worth a mention — but only as "suspect", because the
        // list still remembers far more than it has forgotten.
        let b = auditDeviceLists(
            referenced: referencedListValues(json: lists(items + [auditItem(["storage": "Gone too"])])),
            json: inForce, signedIn: true, hasCatalogue: true
        )
        XCTAssertEqual(b.level, "suspect")
        XCTAssertEqual(b.broken, [])
        XCTAssertEqual(b.gappy.count, 1)
    }

    // JS: 'auditDeviceLists: nothing to compare against is "off", never a warning'
    func testAuditDeviceListsNothingToCompareAgainstIsOffNeverAWarning() {
        let referenced = referencedListValues(json: lists([auditItem(["storage": "Loft"])]))
        let inForce: JSONValue = ["places": [], "owners": [], "conditions": [], "people": [], "phases": []]
        // Signed out: a short list means nothing — there is no account to be short of.
        let out = auditDeviceLists(referenced: referenced, json: inForce, signedIn: false, hasCatalogue: true)
        XCTAssertEqual(out.level, "off")
        XCTAssertEqual(out.gappy, [])
        XCTAssertEqual(out.missingTotal, 0)
        // Empty device (mid "Replace this device"): nothing has arrived yet, so nothing
        // is missing. This is the v118 mistake in miniature — never judge an empty table.
        XCTAssertEqual(auditDeviceLists(referenced: referenced, json: inForce, signedIn: true, hasCatalogue: false).level, "off")
        XCTAssertEqual(auditDeviceLists().level, "off")
        // ...but the per-list detail is still computed, so Settings can show it.
        XCTAssertEqual(out.lists.count, AUDITABLE_KINDS.count)
    }

    // JS: 'AUDIT_LABELS: every audited kind has a name to show'
    func testAuditLabelsEveryAuditedKindHasANameToShow() {
        for k in AUDITABLE_KINDS { XCTAssertNotNil(AUDIT_LABELS[k]) }
        for k in AUDITABLE_KINDS { XCTAssertTrue((AUDIT_LABELS[k] ?? "").count > 0) }
    }

    // --- not in the JS suite: answers taken from Node, pinning the odd corners ---

    func testAuditListKeyRulesMatchTheJSAnswers() {
        // node: auditList('people', { people: new Set(['anna','5','true']) }, [{name:'Anna'}, 5, true, null, ['x']])
        //       → used 3, listed 3, missing []  (a bare number or `true` stands for itself)
        let p = auditList("people", ReferencedListValues(["people": ["anna", "5", "true"]]),
                          json: [["name": "Anna"], 5, true, nil, ["x"]])
        XCTAssertEqual(p, ListAudit(kind: "people", used: 3, listed: 3))
        // node: auditList('places', { places: new Set(['b','a','B','ä','Z']) }, [{name:'A'}, 5])
        //       → listed 1, missing ["B","Z","b","ä"]  (plain `.sort()`: by UTF-16 unit, not A–Z)
        let q = auditList("places", ReferencedListValues(["places": ["b", "a", "B", "ä", "Z"]]), json: [["name": "A"], 5])
        XCTAssertEqual(q.listed, 1)
        XCTAssertEqual(q.missing, ["B", "Z", "b", "ä"])
        XCTAssertEqual(q.missingLabels, ["B", "Z", "b", "ä"])
    }

    func testAToDosWhenPhaseIsNotReferencedOnlyThePhaseKeyTheJSReads() {
        // 🪤 JS reads `a.phase`; the app writes `whenPhase`. A real to-do therefore never
        // counts as referring to a phase — kept for parity.
        let real = newAction(text: "Charge lamps", whenPhase: "custom-when")
        XCTAssertEqual(referencedListValues(actions: [real]).phases, [])
        XCTAssertEqual(referencedListValues(actions: [newAction(phase: "prep")]).phases, ["prep"])
        XCTAssertEqual(referencedListValues(json: ["actions": [["whenPhase": "custom-when"]]]).phases, [])
    }
}

// JS tests of this section NOT ported as written: none — all 10 are above. Two were adapted:
//  • 'referencedListValues: survives junk…' asserts `Object.keys(result)` is the five kinds
//    plus 'display'. Here `display` is a property of the struct, so the test checks that
//    `values` and `display` each hold exactly the five kinds.
//  • `new Set([...])` / `new Map([...])` arguments are `ReferencedListValues([kind: [...]],
//    display: [kind: [ReferencedSpelling]])` — arrays in first-seen order stand for both.
