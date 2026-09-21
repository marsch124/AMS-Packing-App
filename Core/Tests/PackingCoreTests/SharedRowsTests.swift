import XCTest
@testable import PackingCore

// Ported from tests/model.test.mjs — "The five shared Settings lists (v120)",
// "v125: list ordering in Settings" and "v163: the grab lists join the account".
final class SharedRowsTests: XCTestCase {
    override func tearDown() {
        setItemConditions(DEFAULT_ITEM_CONDITIONS)
        PackingEnv.reset()
        super.tearDown()
    }

    // JS: 'sharedRowId: two devices adding the same name land on the same key'
    func testSharedRowIdTwoDevicesAddingTheSameNameLandOnTheSameKey() {
        // The whole reason ids are built from the name rather than generated: this is
        // what makes two devices MERGE a list instead of doubling it.
        XCTAssertEqual(sharedRowId("places", "Garage shelf"), sharedRowId("places", "  garage   SHELF "))
        XCTAssertEqual(sharedRowId("places", "Garage shelf"), "places:garage shelf")
        XCTAssertNotEqual(sharedRowId("places", "Garage"), sharedRowId("owners", "Garage"))
    }

    // JS: 'conditions: a round trip keeps the id items are stamped with, verbatim'
    func testConditionsARoundTripKeepsTheIdItemsAreStampedWithVerbatim() {
        let list = [
            ItemCondition(id: "good", label: "Good", tone: "", replace: false),
            ItemCondition(id: "borrowed-from-anna", label: "Borrowed", tone: "warn", replace: false),
            ItemCondition(id: "failing", label: "Failing", tone: "danger", replace: true),
        ]
        let back = conditionsFromRows(conditionsToRows(list))
        XCTAssertEqual(back, list)
        // The id survives even when the key had to be normalised to build the row.
        let odd = conditionsFromRows(conditionsToRows(json: [["id": "Mixed Case", "label": "Odd"]]))
        XCTAssertEqual(odd[0].id, "Mixed Case")
    }

    // JS: 'conditions: order survives, and a tie on order is broken deterministically'
    func testConditionsOrderSurvivesAndATieOnOrderIsBrokenDeterministically() {
        let list: JSONValue = [["id": "c", "label": "C"], ["id": "a", "label": "A"], ["id": "b", "label": "B"]]
        XCTAssertEqual(conditionsFromRows(conditionsToRows(json: list)).map { $0.label }, ["C", "A", "B"])
        // Both devices appended, so both rows claim the same order. Without the id
        // tiebreak each device would settle it differently and then fight.
        let tied: [JSONValue] = [
            ["kind": "conditions", "key": "zulu", "name": "Z", "order": 4, "data": ["cid": "zulu"]],
            ["kind": "conditions", "key": "alpha", "name": "A", "order": 4, "data": ["cid": "alpha"]],
        ]
        XCTAssertEqual(conditionsFromRows(json: .array(tied)).map { $0.id }, ["alpha", "zulu"])
        XCTAssertEqual(conditionsFromRows(json: .array(tied.reversed())).map { $0.id }, ["alpha", "zulu"])
    }

    // JS: 'people: a round trip keeps the colour, and the id is the same on both devices'
    func testPeopleARoundTripKeepsTheColourAndTheIdIsTheSameOnBothDevices() {
        let people = [Person(id: "whatever-local-id", name: "Anna", color: "#a855f7")]
        let back = peopleFromRows(peopleToRows(people))
        XCTAssertEqual(back[0].name, "Anna")
        XCTAssertEqual(back[0].color, "#a855f7")
        XCTAssertEqual(back[0].id, "people:anna")   // derived from the name, not generated
    }

    // JS: 'people: the same name twice collapses to one row rather than doubling'
    func testPeopleTheSameNameTwiceCollapsesToOneRowRatherThanDoubling() {
        let rows = peopleToRows(json: [["name": "Anna", "color": "#a855f7"], ["name": " anna ", "color": "#22c55e"]])
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].data["color"], "#a855f7")   // first spelling and first colour win
    }

    // JS: 'owners & places: names round-trip, de-duplicate case-insensitively, sort A–Z'
    func testOwnersAndPlacesNamesRoundTripDeDuplicateCaseInsensitivelySortAZ() {
        let rows = namesToRows("places", ["Garage", "garage", "Attic", "  ", "RV / camper"])
        XCTAssertEqual(rows.count, 3)
        XCTAssertEqual(namesFromRows(rows, "places"), ["Attic", "Garage", "RV / camper"])
        // Rows of another kind are never picked up by mistake.
        XCTAssertEqual(namesFromRows(rows + namesToRows("owners", ["Martin"]), "owners"), ["Martin"])
    }

    // JS: 'presets: re-saving under a name you already used replaces it, never doubles it'
    func testPresetsReSavingUnderANameYouAlreadyUsedReplacesItNeverDoublesIt() {
        let a = presetsToRows(json: [["name": "Golf weekend", "config": ["mode": "trip", "season": "Summer"]]])
        let b = presetsToRows(json: [["name": "golf  Weekend", "config": ["mode": "quick"]]])
        XCTAssertEqual(a[0].id, b[0].id)
        let back = presetsFromRows(b)
        XCTAssertEqual(back[0].name, "golf  Weekend")
        XCTAssertEqual(back[0].config, ["mode": "quick"])
        // A preset with no config is not a preset — it is dropped rather than shown empty.
        XCTAssertEqual(presetsFromRows(presetsToRows(json: [["name": "Broken"]])), [])
    }

    // JS: 'sharedRowsOfKind: rows of other lists are never mixed in'
    func testSharedRowsOfKindRowsOfOtherListsAreNeverMixedIn() {
        let rows = namesToRows("places", ["Attic"]) + namesToRows("owners", ["Martin"])
            + peopleToRows(json: [["name": "Anna"]])
        XCTAssertEqual(sharedRowsOfKind(rows, "places").map { $0.name }, ["Attic"])
        XCTAssertEqual(sharedRowsOfKind(rows, "people").map { $0.name }, ["Anna"])
        XCTAssertEqual(sharedRowsOfKind(rows, "presets"), [])
    }

    // JS: 'coerceSharedRow: a row from an unknown list, or with junk in it, is dropped'
    func testCoerceSharedRowARowFromAnUnknownListOrWithJunkInItIsDropped() {
        XCTAssertEqual(coerceSharedRow(json: ["kind": "nonsense", "key": "x", "name": "X"]).kind, "")
        XCTAssertEqual(coerceSharedRow(json: ["kind": "places", "key": "a", "name": "A", "data": "not an object"]).data, [:])
        XCTAssertEqual(sharedRowsOfKind(json: [["kind": "places", "key": "", "name": ""]], "places").count, 0)
    }

    // JS: 'isFactoryList: the defaults are recognised so they are never written as data'
    func testIsFactoryListTheDefaultsAreRecognisedSoTheyAreNeverWrittenAsData() {
        // This is the guard that keeps v118 from happening again: a list that is still
        // exactly what the app ships is not data, and must never reach shared storage.
        for kind in ["conditions", "people", "places"] {
            XCTAssertEqual(isFactoryList(kind, defaultListFor(kind)), true, kind)
        }
        XCTAssertEqual(isFactoryList("places", json: JSONValue(DEFAULT_STORAGE_LOCATIONS + ["Boat locker"])), false)
        XCTAssertEqual(isFactoryList("people", DEFAULT_PEOPLE.map { ["name": .string($0.name), "color": "#123456"] }), false)
        XCTAssertEqual(isFactoryList("people", json: [["name": "Martin"], ["name": "Bengt"]]), false)
        XCTAssertEqual(isFactoryList("conditions", DEFAULT_ITEM_CONDITIONS.map { c -> JSONValue in
            var o = c.json
            o["label"] = .string(c.label.uppercased())
            return o
        }), false)
        // Presets and owners have no factory version, so nothing is ever "just default".
        XCTAssertEqual(isFactoryList("presets", json: []), false)
        XCTAssertEqual(isFactoryList("owners", json: ["Martin"]), false)
    }

    // JS: 'sharedRowsFrom: every kind builds rows, and an unknown kind builds none'
    func testSharedRowsFromEveryKindBuildsRowsAndAnUnknownKindBuildsNone() {
        for kind in SHARED_KINDS {
            // Each kind has its own row shape; a bare name only suits the name-keyed ones.
            let sample: JSONValue = kind == "presets" ? [["name": "P", "config": [:]]]
                : kind == "grab" ? [["id": "bike", "items": ["Helmet"], "label": "Bike", "icon": "bike", "tone": "yellow"]]
                : ["Someone"]
            let def = defaultListFor(kind)
            let rows = sharedRowsFrom(kind, json: def.isEmpty ? sample : .array(def))
            XCTAssertFalse(rows.isEmpty, kind)
            XCTAssertTrue(rows.allSatisfy { $0.kind == kind && $0.id.hasPrefix("\(kind):") }, kind)
        }
        XCTAssertEqual(sharedRowsFrom("phases", json: [["id": "x", "label": "X"]]), [])
    }

    // JS: 'orderedNamesFromRows: storage places keep the order they are stored in'
    func testOrderedNamesFromRowsStoragePlacesKeepTheOrderTheyAreStoredIn() {
        let rows = namesToRows("places", ["Garage", "Bedroom wardrobe", "Loft / attic"])
        // The A–Z reader is unchanged — the Owner dropdowns still rely on it.
        XCTAssertEqual(namesFromRows(rows, "places"), ["Bedroom wardrobe", "Garage", "Loft / attic"])
        // The ordered reader hands back what was written, which is what the ▲▼ set.
        XCTAssertEqual(orderedNamesFromRows(rows, "places"), ["Garage", "Bedroom wardrobe", "Loft / attic"])
        XCTAssertEqual(orderedNamesFromRows(rows, "owners"), [])
    }

    // JS: 'orderedNamesFromRows: two devices appending at the same order still agree'
    func testOrderedNamesFromRowsTwoDevicesAppendingAtTheSameOrderStillAgree() {
        // Both devices append, so two rows genuinely can share an `order`; the id
        // tiebreak in sharedRowsOfKind is what stops them being sorted differently on
        // each device and then written back at each other.
        let rows: [JSONValue] = [
            ["kind": "places", "key": "shed", "name": "Shed", "order": 3],
            ["kind": "places", "key": "boat locker", "name": "Boat locker", "order": 3],
            ["kind": "places", "key": "garage", "name": "Garage", "order": 1],
        ]
        XCTAssertEqual(orderedNamesFromRows(json: .array(rows), "places"), ["Garage", "Boat locker", "Shed"])
        XCTAssertEqual(orderedNamesFromRows(json: .array(rows.reversed()), "places"), ["Garage", "Boat locker", "Shed"])
        // The same rows built in memory give the same answer.
        let typed = [
            SharedRow(kind: "places", key: "shed", name: "Shed", order: 3),
            SharedRow(kind: "places", key: "boat locker", name: "Boat locker", order: 3),
            SharedRow(kind: "places", key: "garage", name: "Garage", order: 1),
        ]
        XCTAssertEqual(orderedNamesFromRows(typed, "places"), ["Garage", "Boat locker", "Shed"])
    }

    // JS: 'ownersByUsage: the biggest owner comes first, ties settle A–Z'
    func testOwnersByUsageTheBiggestOwnerComesFirstTiesSettleAZ() {
        let counts = ["martin": 300, "anna": 120, "shared": 120, "the kids": 0]
        XCTAssertEqual(
            ownersByUsage(["The kids", "Shared", "Anna", "Martin"], counts),
            ["Martin", "Anna", "Shared", "The kids"]
        )
        // A name nobody owns anything under still appears — it just sinks.
        XCTAssertEqual(ownersByUsage(["Bengt", "Martin"], counts), ["Martin", "Bengt"])
        // Counts are matched case-insensitively, the same way the roster de-duplicates.
        XCTAssertEqual(ownersByUsage(["anna", "MARTIN"], counts), ["MARTIN", "anna"])
        // No counts at all is simply A–Z, so an empty catalogue reads sensibly.
        XCTAssertEqual(ownersByUsage(["Shared", "Anna"], [:]), ["Anna", "Shared"])
        XCTAssertEqual(ownersByUsage([], counts), [])
        // A plain object works as well as a Map — the helper shouldn't care.
        // (Both are the same dictionary here.)
        XCTAssertEqual(ownersByUsage(["Anna", "Martin"], ["martin": 5, "anna": 1]), ["Martin", "Anna"])
    }

    // JS: 'grabToRows/grabFromRows: a list survives the round trip, hyphen and all'
    func testGrabToRowsGrabFromRowsAListSurvivesTheRoundTripHyphenAndAll() {
        let back = grabFromRows(grabToRows(json: [
            ["id": "run-out", "items": ["Cap", "Sunglasses", "Gels"], "label": "Trail", "icon": "mountain", "tone": "green"],
            ["id": "bike", "items": ["Helmet"]],
        ]))
        XCTAssertEqual(back[0], GrabList(id: "run-out", items: ["Cap", "Sunglasses", "Gels"], label: "Trail", icon: "mountain", tone: "green"))
        XCTAssertEqual(back[0].json, ["id": "run-out", "items": ["Cap", "Sunglasses", "Gels"], "label": "Trail", "icon": "mountain", "tone": "green"])
        XCTAssertEqual(back[1].id, "bike")
        XCTAssertEqual(back[1].items, ["Helmet"])
    }

    // JS: 'grabToRows: the row id is stable, so two devices merge instead of doubling'
    func testGrabToRowsTheRowIdIsStableSoTwoDevicesMergeInsteadOfDoubling() {
        // The 880-item lesson. Both devices editing the Bike button must land on one row.
        let a = grabToRows([GrabList(id: "bike", items: ["Helmet"])])[0]
        let b = grabToRows([GrabList(id: "bike", items: ["Bidon", "Gilet"])])[0]
        XCTAssertEqual(a.id, b.id)
        XCTAssertEqual(a.id, "grab:bike")
    }

    // JS: 'grabToRows: the code id survives normalising, verbatim, in data.gid'
    func testGrabToRowsTheCodeIdSurvivesNormalisingVerbatimInDataGid() {
        let row = grabToRows([GrabList(id: "swim-out", items: ["Goggles"])])[0]
        XCTAssertEqual(row.data["gid"], "swim-out", "the key is normalised; gid must not be")
        XCTAssertEqual(grabFromRows([row])[0].id, "swim-out")
    }

    // JS: 'grabToRows: nothing is invented — junk and duplicates build no rows'
    func testGrabToRowsNothingIsInventedJunkAndDuplicatesBuildNoRows() {
        XCTAssertEqual(grabToRows(json: []), [])
        XCTAssertEqual(grabToRows(json: ["Someone"]), [], "a bare string is not a grab list")
        XCTAssertEqual(grabToRows(json: [["items": ["x"]]]), [], "no id, no row")
        XCTAssertEqual(grabToRows(json: [["id": "bike", "items": ["a"]], ["id": "bike", "items": ["b"]]]).count, 1)
        XCTAssertEqual(grabToRows(json: [["id": "bike", "items": ["  ", "", "Helmet "]]])[0].data["items"], ["Helmet"])
    }

    // JS: 'grab is a kind of the EXISTING shared table, not a new table'
    func testGrabIsAKindOfTheExistingSharedTableNotANewTable() {
        // Why this assertion earns its place: a synced table of its own would have walked
        // back into the v120 fault, where a device already syncing records a new table's
        // empty first download as "done" and only ever receives changes afterwards.
        XCTAssertTrue(SHARED_KINDS.contains("grab"))
        XCTAssertEqual(SHARED_KINDS.count, 6)
    }

    // --- not in the JS suite: answers taken from Node, pinning the odd corners ---

    func testCoerceSharedRowTypeRulesMatchTheJSAnswers() {
        // node: coerceSharedRow({ kind:'places', key:5, name:7, order:null, data:[1] }, 3)
        XCTAssertEqual(coerceSharedRow(json: ["kind": "places", "key": 5, "name": 7, "order": nil, "data": [1]], 3),
                       SharedRow(id: "places:5", kind: "places", key: "5", name: "7", order: 0, data: [:]))
        // A numeric string is an order; junk falls back to the position.
        XCTAssertEqual(coerceSharedRow(json: ["kind": "places", "key": "  Garage   SHELF ", "name": "  Garage shelf ", "order": "2.5"], 3),
                       SharedRow(id: "places:garage shelf", kind: "places", key: "garage shelf", name: "Garage shelf", order: 2.5))
        XCTAssertEqual(coerceSharedRow(json: nil, 4), SharedRow(id: ":", kind: "", key: "", name: "", order: 4))
        // The key is cut at 60 AFTER normalising (so it can end in a space), while the
        // id normalises it once more (so it cannot). The name is cut at 80.
        let long = coerceSharedRow(json: ["kind": "owners", "key": .string(String(repeating: "x", count: 59) + " yz"),
                                          "name": .string(String(repeating: "n", count: 90)), "order": "abc"], 9)
        XCTAssertEqual(long.key, String(repeating: "x", count: 59) + " ")
        XCTAssertEqual(long.id, "owners:" + String(repeating: "x", count: 59))
        XCTAssertEqual(long.name.count, 80)
        XCTAssertEqual(long.order, 9)
        // A row with no order takes its position in the array.
        XCTAssertEqual(sharedRowsOfKind(json: [["kind": "places", "key": "b", "name": "B"],
                                               ["kind": "places", "key": "a", "name": "A", "order": 1],
                                               ["kind": "places", "key": "c", "name": "C", "order": 1]], "places").map { $0.id },
                       ["places:b", "places:a", "places:c"])
        // 🪤 Coercing a coerced row normalises the key AGAIN, so that trailing space goes
        // the second time round (as in JS, where every reader re-coerces) — the id stays.
        XCTAssertEqual(coerceSharedRow(long, 9).key, String(repeating: "x", count: 59))
        XCTAssertEqual(coerceSharedRow(long, 9).id, long.id)
        // Round trip through JSON, and through Codable.
        let row = namesToRows("places", ["Garage shelf"])[0]
        XCTAssertEqual(SharedRow(json: row.json), row)
        XCTAssertEqual(row.json, ["id": "places:garage shelf", "kind": "places", "key": "garage shelf",
                                  "name": "Garage shelf", "order": 0, "data": [:]])
        let data = try? JSONEncoder().encode(row)
        XCTAssertEqual(data.flatMap { try? JSONDecoder().decode(SharedRow.self, from: $0) }, row)
    }

    func testNamesToRowsReadsStringsAndNamedObjectsAndNothingElse() {
        // node: namesToRows('places', ['Garage', {name:'Attic'}, {name:0}, 5, null, ['x'], ' garage '])
        let rows = namesToRows("places", json: ["Garage", ["name": "Attic"], ["name": 0], 5, nil, ["x"], " garage "])
        XCTAssertEqual(rows.map { $0.id }, ["places:garage", "places:attic"])
        XCTAssertEqual(rows.map { $0.order }, [0, 1])
        // An unknown kind still builds a row — with no kind, which every reader then drops.
        XCTAssertEqual(namesToRows("nonsense", ["A"]), [SharedRow(id: ":a", kind: "", key: "a", name: "A", order: 0)])
    }

    func testPeopleToRowsStepsOverJunkAndFillsAMissingColour() {
        // node: peopleToRows([{name:'Anna'}, null, 'Bo', {name:' '}, {name:'Bo', color:'#fff'}])
        let rows = peopleToRows(json: [["name": "Anna"], nil, "Bo", ["name": " "], ["name": "Bo", "color": "#fff"]])
        XCTAssertEqual(rows.map { $0.id }, ["people:anna", "people:bo"])
        XCTAssertEqual(rows.map { $0.order }, [0, 1])
        XCTAssertEqual(rows.map { $0.data }, [["color": "#3b82f6"], ["color": "#fff"]])
    }

    func testGrabToRowsKeepsTheJSQuirkOfTwoSpellingsOnOneRowId() {
        // node: 'Bike' and 'bike' are two rows with ONE id — `seen` holds the id as written.
        let rows = grabToRows([GrabList(id: "Bike", items: ["a"]),
                               GrabList(id: "bike", items: ["b"], label: "  A very long label that goes past twenty-four ")])
        XCTAssertEqual(rows.map { $0.id }, ["grab:bike", "grab:bike"])
        XCTAssertEqual(rows.map { $0.name }, ["Bike", "A very long label that g"])
        XCTAssertEqual(rows[1].data["label"], "A very long label that g")
        XCTAssertEqual(grabFromRows(rows).map { $0.id }, ["Bike", "bike"])
    }

    func testPresetsAnEmptyConfigIsAPresetAFalsyOneIsNot() {
        // node: presetsFromRows(presetsToRows([{name:'P',config:{}}, {name:'Q',config:0}, {name:'R',config:[],createdAt:5}]))
        let back = presetsFromRows(presetsToRows(json: [["name": "P", "config": [:]], ["name": "Q", "config": 0],
                                                        ["name": "R", "config": [], "createdAt": 5]]))
        XCTAssertEqual(back, [TripPreset(id: "presets:p", name: "P", createdAt: "", config: [:]),
                              TripPreset(id: "presets:r", name: "R", createdAt: "5", config: [])])
        XCTAssertEqual(TripPreset(json: back[1].json), back[1])
    }

    func testIsFactoryListComparesTheSpellingAndFillsAMissingColour() {
        // node: a lower-case 'martin' is NOT the factory roster; a missing colour IS
        // (coercePerson fills in the first palette colour, which is the factory one).
        XCTAssertEqual(isFactoryList("people", json: [["name": "martin", "color": "#3b82f6"], ["name": "Anna", "color": "#a855f7"]]), false)
        XCTAssertEqual(isFactoryList("people", json: [["name": "Martin"], ["name": "Anna", "color": "#a855f7"]]), true)
        XCTAssertEqual(isFactoryList("places", DEFAULT_STORAGE_LOCATIONS.map { ["name": .string($0)] }), true)
        // The typed lists get there through `.json`.
        XCTAssertEqual(isFactoryList("conditions", DEFAULT_ITEM_CONDITIONS.map { $0.json }), true)
        XCTAssertEqual(isFactoryList("people", DEFAULT_PEOPLE.map { $0.json }), true)
    }

    func testNameSortingMatchesNodeOnSwedishLetters() {
        // node (ICU, 'en'): ["anna","Anna B","ärlig","Åsa","Bo","Örjan","Zoe"]
        let rows = namesToRows("owners", ["Örjan", "anna", "Zoe", "Åsa", "Bo", "Anna B", "ärlig"])
        XCTAssertEqual(namesFromRows(rows, "owners"), ["anna", "Anna B", "ärlig", "Åsa", "Bo", "Örjan", "Zoe"])
        // node: ownersByUsage(['b','A','a','B'], {}) → ["a","A","b","B"]
        XCTAssertEqual(ownersByUsage(["b", "A", "a", "B"]), ["a", "A", "b", "B"])
    }
}

// JS tests of this section NOT ported as written: none — all 19 are above. Adapted:
//  • 'ownersByUsage…' passes counts once as a Map and once as a plain object; both are
//    the same `[String: Int]` here.
//  • `assert.deepEqual(back[0], { id, items, label, icon, tone })` compares against a
//    `GrabList` value AND against its `json`.
