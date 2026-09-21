import XCTest
@testable import PackingCore

// Not in the JS suite — the backup file's shape comes from js/db.js (`exportJSON`,
// `inspectBackup`, `applyBackup`), which the JS tests through the browser. Invented data.
final class BackupTests: XCTestCase {
    override func tearDown() {
        setPhases(DEFAULT_PHASES)
        PackingEnv.reset()
        super.tearDown()
    }

    private let sample = #"""
    {
      "app": "ams-packing-list", "version": 2, "exportedAt": "2026-09-01T08:00:00.000Z",
      "lists": [
        { "id": "t1", "name": "Hiking", "group": "GA", "role": "", "defaultContainer": "Hiking backpack",
          "owner": "someone@example.com", "realmId": "rlm-x",
          "sections": [{ "id": "s1", "name": "Shelter" }],
          "items": [
            { "id": "i1", "name": "Tent", "category": "Sport gear", "container": "Hiking backpack", "phase": "week",
              "section": "s1", "photos": ["p1"], "ownedBy": "Anna", "owner": "someone@example.com",
              "_itemId": "i1", "_memId": "m1", "_ovContainer": "", "_tplContainer": "Hiking backpack",
              "_defContainer": "Duffel bag", "_ovPhase": "", "_defPhase": "week" }
          ] }
      ],
      "events": [
        { "id": "e1", "name": "Kebnekaise", "activities": ["t1"], "transport": "Car", "season": "Summer",
          "startDate": "2026-07-01", "endDate": "2026-07-05", "nights": 4,
          "entries": [
            { "id": "en1", "name": "Tent", "phase": "week", "container": "Hiking backpack", "checked": true,
              "custom": false, "sourceListId": "t1", "sourceItemId": "i1", "used": true },
            { "id": "en2", "name": "Spare laces", "phase": "packed-on-the-mac", "custom": true,
              "sourceListId": null, "sourceItemId": null, "skipped": true }
          ] }
      ],
      "actions": [{ "id": "a1", "text": "Re-proof the tent", "itemId": "i1", "itemName": "Tent", "whenPhase": "prep" }],
      "kits": [{ "id": "k1", "name": "Repair kit", "itemIds": ["i1", "i1"] }],
      "phases": [
        { "id": "prep", "label": "Preparations", "task": true, "leadDays": 30, "order": 0 },
        { "id": "", "label": "Broken row" },
        { "id": "packed-on-the-mac", "label": "Packed on the Mac", "order": 1 }
      ],
      "things": [{ "id": "i9", "name": "Spare stove" }, "junk"],
      "photos": [{ "id": "p1", "data": "data:image/jpeg;base64,AAAA", "createdAt": "2026-08-01T00:00:00.000Z" }, { "id": 5 }],
      "prefs": { "theme": "dark", "storageLocations": ["Loft", "Boat locker"],
                 "conditions": [{ "id": "fine", "label": "Fine" }], "grab": { "items": {} } },
      "madeUpLater": true
    }
    """#

    func testABackupFileDecodesIntoTheModelTypes() throws {
        let b = try JSONDecoder().decode(BackupFile.self, from: Data(sample.utf8))
        XCTAssertEqual(b.app, "ams-packing-list")
        XCTAssertEqual(b.version, 2)
        XCTAssertEqual(b.exportedAt, "2026-09-01T08:00:00.000Z")

        // Lists carry RESOLVED items, with the hidden links and the container parts.
        let tent = try XCTUnwrap(b.lists.first?.items.first)
        XCTAssertEqual(b.lists[0].defaultContainer, "Hiking backpack")
        XCTAssertEqual(tent.itemId, "i1")
        XCTAssertEqual(tent.memId, "m1")
        XCTAssertEqual(tent.ovContainer, "")
        XCTAssertEqual(tent.tplContainer, "Hiking backpack")
        XCTAssertEqual(tent.defContainer, "Duffel bag")
        XCTAssertEqual(tent.defPhase, "week")
        XCTAssertEqual(tent.ownedBy, "Anna")                  // the sync stamp in `owner` never wins
        XCTAssertNil(b.lists[0].json["owner"])
        XCTAssertNil(tent.json["owner"])

        // Trip entries keep their state, and a phase this device has never heard of.
        let entries = b.events[0].entries
        XCTAssertEqual(entries[0].checked, true)
        XCTAssertEqual(entries[0].used, true)
        XCTAssertEqual(entries[0].sourceItemId, "i1")
        XCTAssertEqual(entries[1].custom, true)
        XCTAssertEqual(entries[1].skipped, true)
        XCTAssertNil(entries[1].sourceListId)                 // null
        XCTAssertNil(entries[1].used)
        XCTAssertEqual(entries[1].phase, "packed-on-the-mac")
        XCTAssertEqual(b.events[0].nights, 4)

        XCTAssertEqual(b.actions[0].whenPhase, "prep")
        XCTAssertEqual(b.kits[0].itemIds, ["i1"])

        // Phases: coerced at their position, the unusable row dropped.
        XCTAssertEqual(b.phases.map { $0.id }, ["prep", "packed-on-the-mac"])
        // 🚨 Things on NO template — a reader that only walks `lists` loses these.
        XCTAssertEqual(b.things.map { $0.name }, ["Spare stove"])
        XCTAssertEqual(b.photos, [PhotoRecord(id: "p1", data: "data:image/jpeg;base64,AAAA", createdAt: "2026-08-01T00:00:00.000Z")])

        XCTAssertEqual(b.prefs?["theme"], "dark")
        XCTAssertEqual(b.prefsStorageLocations, ["Loft", "Boat locker"])
        XCTAssertEqual(b.prefsConditions, [ItemCondition(id: "fine", label: "Fine")])
        XCTAssertNil(b.prefsOwners)                           // not carried = never customised
        XCTAssertEqual(b.extra, ["madeUpLater": true])
    }

    func testABackupRoundTripsThroughJSON() throws {
        let b = try JSONDecoder().decode(BackupFile.self, from: Data(sample.utf8))
        let again = try JSONDecoder().decode(BackupFile.self, from: JSONEncoder().encode(b))
        XCTAssertEqual(again, b)
        // Installing the file's phases is the caller's job — decoding must not touch the live list.
        XCTAssertEqual(PHASE_IDS, DEFAULT_PHASES.map { $0.id })
    }

    func testAnOldOrBrokenFileStillDecodes() throws {
        // A version-1 backup: no phases, no things, no photos array, no prefs.
        let old = try JSONDecoder().decode(BackupFile.self, from: Data(#"{"lists":[{"name":"Run","items":[{"name":"Shoes","photo":"data:image/jpeg;base64,BBBB"}]}],"events":[]}"#.utf8))
        XCTAssertEqual(old.lists[0].items[0].photos, ["data:image/jpeg;base64,BBBB"])
        XCTAssertTrue(hasInlinePhotos(old.lists[0].items))
        XCTAssertEqual(old.phases, [])
        XCTAssertEqual(old.things, [])
        XCTAssertNil(old.prefs)
        XCTAssertEqual(old.version, 0)
        // Not a backup at all: decoding still does not throw — ask `looksLikeBackup` first.
        for text in ["null", "[]", "42", #"{"lists":"nope","prefs":[1]}"#] {
            let json = try JSONValue.parse(text)
            XCTAssertFalse(BackupFile.looksLikeBackup(json), text)
            let b = BackupFile(json: json)
            XCTAssertEqual(b.lists, [])
            XCTAssertNil(b.prefs)
        }
        XCTAssertTrue(BackupFile.looksLikeBackup(["events": []]))
    }
}
