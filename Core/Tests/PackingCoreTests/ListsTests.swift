import XCTest
@testable import PackingCore

// Ported from tests/model.test.mjs — coerceList / newList, sections, template covers,
// orderActivities and containerNames.
final class ListsTests: XCTestCase {
    override func tearDown() { PackingEnv.reset(); super.tearDown() }

    // JS: 'coerceList: keeps the loose role'
    func testCoerceListKeepsTheLooseRole() {
        XCTAssertEqual(coerceList(newList(name: "Loose items", role: "loose")).role, "loose")
        XCTAssertEqual(coerceList(newList(name: "X", role: "bogus")).role, "")   // unknown roles blanked
    }

    // JS: 'newList / coerceList: group is a valid GROUP id or empty'
    func testNewListGroupIsAValidGroupIdOrEmpty() {
        XCTAssertEqual(newList(name: "X", group: "GA").group, "GA")
        XCTAssertEqual(newList(name: "X").group, "")
        XCTAssertEqual(newList(name: "X", group: "nonsense").group, "", "invalid group falls back to ungrouped")
    }

    // JS: 'normalizeSections: drops blank names, keeps ids, dedups'
    func testNormalizeSectionsDropsBlankNamesKeepsIdsDedups() {
        let a = newSection("Lights")
        let out = normalizeSections(json: [a.json, ["id": "", "name": "  Rig  "], ["name": ""], a.json])
        XCTAssertEqual(out.count, 2)
        XCTAssertEqual(out[0].id, a.id)
        XCTAssertEqual(out[0].name, "Lights")
        XCTAssertEqual(out[1].name, "Rig")        // trimmed
        XCTAssertFalse(out[1].id.isEmpty)         // generated an id
        // (the typed form gives the same)
        let typed = normalizeSections([a, TemplateSection(id: "", name: "  Rig  "), TemplateSection(id: "", name: ""), a])
        XCTAssertEqual(typed.map { $0.name }, ["Lights", "Rig"])
    }

    // JS: 'coerceList / newList: sections normalize and default to empty'
    func testCoerceListSectionsNormalizeAndDefaultToEmpty() throws {
        XCTAssertEqual(newList(name: "X").sections, [])
        let l = try XCTUnwrap(coerceList(json: ["id": "t1", "name": "Dive", "sections": [["id": "s1", "name": "Rig"], ["name": ""]]]))
        XCTAssertEqual(l.sections.count, 1)
        XCTAssertEqual(l.sections[0].name, "Rig")
    }

    // JS: 'coerceList: cleans cover emoji and colour, drops junk'
    func testCoerceListCleansCoverEmojiAndColour() {
        let l = coerceList(newList(name: "Golf", emoji: "  ⛳ ", color: "#3b82f6"))
        XCTAssertEqual(l.emoji, "⛳")
        XCTAssertEqual(l.color, "#3b82f6")
        let bad = coerceList(newList(json: ["name": "X", "emoji": 42, "color": "blue"]))
        XCTAssertEqual(bad.emoji, "")
        XCTAssertEqual(bad.color, "")
    }

    // JS: 'listEmoji: custom emoji else the default glyph'
    func testListEmojiCustomEmojiElseTheDefaultGlyph() {
        XCTAssertEqual(listEmoji(newList(name: "Dive", emoji: "🤿")), "🤿")
        XCTAssertEqual(listEmoji(newList(name: "Plain")), TEMPLATE_DEFAULT_EMOJI)
        XCTAssertEqual(listEmoji(newList(name: "Blankish", emoji: "   ")), TEMPLATE_DEFAULT_EMOJI)
    }

    // JS: 'listColor: custom colour wins, else a stable palette pick from the id'
    func testListColorCustomColourWinsElseAStablePalettePick() {
        XCTAssertEqual(listColor(newList(name: "Run", color: "#ef4444")), "#ef4444")
        let l = newList(id: "fixed-id", name: "Auto")
        let c1 = listColor(l)
        let c2 = listColor(l)
        XCTAssertEqual(c1, c2)                          // stable
        XCTAssertTrue(TEMPLATE_COLORS.contains(c1))     // from the palette
        // (not in the JS test) the very colours Node picks — the hash walks UTF-16
        // units and wraps at 32 bits, so a long or non-ASCII key must still agree.
        XCTAssertEqual(c1, "#8b5cf6")
        XCTAssertEqual(listColor(newList(id: "", name: "Vinterbad 🧊 och en väldigt lång rubrik")), "#ef4444")
        XCTAssertEqual(listColor(nil), TEMPLATE_COLORS[0])
    }

    // JS: 'coerceList: a template can carry its own default container'
    func testCoerceListATemplateCanCarryItsOwnDefaultContainer() {
        XCTAssertEqual(coerceList(json: ["name": "Hiking"])?.defaultContainer, "")
        XCTAssertEqual(coerceList(json: ["name": "Hiking", "defaultContainer": "Hiking backpack"])?.defaultContainer, "Hiking backpack")
        XCTAssertEqual(coerceList(json: ["name": "Hiking", "defaultContainer": 42])?.defaultContainer, "")
    }

    // JS: 'orderActivities: WET follows the deliberate order, not the alphabet'
    func testOrderActivitiesWETFollowsTheDeliberateOrder() {
        let names = ["Breath work", "Mobility", "Run", "Strength", "Swim", "Bike"]   // alphabetical-ish input
        let out = orderActivities("WET", names.map { PackList(id: $0, name: $0) })
        XCTAssertEqual(out.map { $0.name }, ["Swim", "Bike", "Run", "Strength", "Mobility", "Breath work"])
    }

    // JS: 'orderActivities: an activity of your own lands after the known ones, A–Z'
    func testOrderActivitiesAnActivityOfYourOwnLandsAfterTheKnownOnes() {
        let lists = ["Padel", "Swim", "Breath work", "Aerial hoop"].map { PackList(id: $0, name: $0) }
        let out = orderActivities("WET", lists).map { $0.name }
        XCTAssertEqual(out, ["Swim", "Breath work", "Aerial hoop", "Padel"])
        XCTAssertEqual(out.count, 4, "nothing may be dropped")
    }

    // JS: 'orderActivities: a group with no set order keeps what it was given'
    func testOrderActivitiesAGroupWithNoSetOrderKeepsWhatItWasGiven() {
        let lists = [PackList(id: "b", name: "Golf"), PackList(id: "a", name: "Diving")]
        XCTAssertEqual(orderActivities("GA", lists).map { $0.name }, ["Golf", "Diving"])
        XCTAssertEqual(orderActivities("", lists).map { $0.name }, ["Golf", "Diving"])
    }

    // JS: 'orderActivities: matches names case- and spacing-insensitively'
    func testOrderActivitiesMatchesNamesCaseAndSpacingInsensitively() {
        let out = orderActivities("WET", [PackList(name: "breath  work"), PackList(name: "SWIM")])
        XCTAssertEqual(out.map { $0.name }, ["SWIM", "breath  work"])
    }

    // JS: 'containerNames: merges built-in names with the user container records'
    func testContainerNamesMergesBuiltInNamesWithTheUserContainerRecords() throws {
        let cl = newList(name: "Containers", role: "container", items: [newItem(name: "Osprey 40")])
        let names = containerNames([cl])
        XCTAssertTrue(names.contains("Checked luggage"))   // built-in default
        XCTAssertTrue(names.contains("Osprey 40"))         // user record appended
        let a = try XCTUnwrap(names.firstIndex(of: "Checked luggage"))
        let b = try XCTUnwrap(names.firstIndex(of: "Osprey 40"))
        XCTAssertLessThan(a, b)                             // defaults first
    }

    // --- not in the JS suite ---

    func testAListRoundTripsThroughJSONAndCarriesUnknownKeys() throws {
        let raw = Data(#"{"id":"t1","name":"Hiking","group":"GA","role":"","builtin":1,"realmId":"r","owner":"x@y.zz","someday":{"a":1},"sections":[{"id":"s1","name":"Rig"}],"items":[{"id":"i1","name":"Tent","section":"s1"},null,"junk"]}"#.utf8)
        let l = try JSONDecoder().decode(PackList.self, from: raw)
        XCTAssertEqual(l.items.map { $0.name }, ["Tent"])          // non-objects in `items` are dropped
        XCTAssertEqual(l.builtin, true)
        XCTAssertEqual(l.extra, ["someday": ["a": 1]])
        XCTAssertNil(l.json["owner"])
        XCTAssertNil(l.json["realmId"])
        let back = try JSONDecoder().decode(PackList.self, from: JSONEncoder().encode(l))
        XCTAssertEqual(back, l)
    }

    func testTheSmallLookups() {
        XCTAssertEqual(groupLabel("WET"), "Workout, Exercise & Training")
        XCTAssertEqual(groupLabel("nope"), "")
        XCTAssertNil(group(""))
        XCTAssertEqual(cateringLabel("mixed"), "A mix of both")
        XCTAssertEqual(cateringLabel("x"), "")
        XCTAssertEqual(chargeTypeShort("micro-usb"), "Micro")
        XCTAssertEqual(chargeTypeLabel("nope"), "Unspecified")     // unknown → the first entry
        XCTAssertEqual(retireReasonLabel("sold"), "Sold")
        XCTAssertEqual(retireReasonLabel(""), "")
        XCTAssertEqual(CONTAINER_LIMITS_KG["Checked luggage"], 23)
        XCTAssertEqual(WEATHER_CONDITION_IDS, ["rain", "cold", "hot", "wind", "snow"])
    }
}
