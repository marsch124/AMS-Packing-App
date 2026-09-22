import XCTest
@testable import PackingCore

// Ported from tests/model.test.mjs — every test of coerceItem, newItem, the care
// record, photo references and "whose it is".
//
// HOW THE JS READS HERE. `newItem({ name: 'X', charging: true })` becomes
// `newItem(name: "X", charging: true)`. Where the JS hands `coerceItem` a raw object
// with junk in it (`photos: ['a', '', null, 42]`), the raw form is used instead:
// `coerceItem(json: ["photos": ["a", "", nil, 42]])`, which returns an Optional
// because JS hands a non-object straight back.
final class ItemsTests: XCTestCase {
    override func tearDown() {
        setPhases(DEFAULT_PHASES)
        PackingEnv.reset()
        super.tearDown()
    }

    private let DATA_URL = "data:image/jpeg;base64,/9j/4AAQSkZJRg=="

    // JS: 'newItem: carries the new flags with safe defaults'
    func testNewItemCarriesTheNewFlagsWithSafeDefaults() {
        let r = newItem(name: "Headlamp", swedish: "Pannlampa", itemType: "reminder", charging: true, shortList: true, sub: ["a"])
        XCTAssertEqual(r.charging, true)
        XCTAssertEqual(r.itemType, "reminder")
        XCTAssertEqual(r.shortList, true)
        XCTAssertEqual(r.swedish, "Pannlampa")
        XCTAssertEqual(r.sub, ["a"])
        let d = newItem(name: "Plain")
        XCTAssertEqual(d.charging, false)
        XCTAssertEqual(d.itemType, "item")
    }

    // JS: 'coerceItem: keeps only known weather conditions'
    func testCoerceItemKeepsOnlyKnownWeatherConditions() {
        let it = newItem(name: "Rain suit", weather: ["rain", "sunshine", "cold"])
        XCTAssertEqual(it.weather, ["rain", "cold"])
    }

    // JS: 'normalizeMaintenance: empty record collapses to null'
    func testNormalizeMaintenanceEmptyRecordCollapsesToNull() {
        XCTAssertNil(normalizeMaintenance(json: nil))
        XCTAssertNil(normalizeMaintenance(json: ["notes": "", "link": "", "intervalDays": 0, "lastDone": "", "log": []]))
        XCTAssertNil(normalizeMaintenance(nil))
        XCTAssertNil(normalizeMaintenance(Maintenance()))
    }

    // JS: 'normalizeMaintenance: keeps real content and cleans bad values'
    func testNormalizeMaintenanceKeepsRealContentAndCleansBadValues() {
        let m = normalizeMaintenance(json: [
            "notes": "Rinse in fresh water", "link": "https://x", "intervalDays": 90.7,
            "lastDone": "bad-date", "log": [["date": "2026-01-01", "note": "ok"], ["date": "bad"]],
        ])
        XCTAssertEqual(m?.notes, "Rinse in fresh water")
        XCTAssertEqual(m?.intervalDays, 90)           // floored
        XCTAssertEqual(m?.lastDone, "")               // bad date dropped
        XCTAssertEqual(m?.log.count, 1)               // invalid log entry filtered out
    }

    // JS: 'coerceItem: backfills care fields on legacy items and normalizes maintenance'
    func testCoerceItemBackfillsCareFieldsOnLegacyItems() throws {
        let it = try XCTUnwrap(coerceItem(json: ["name": "Old item"]))
        XCTAssertEqual(it.storage, "")
        XCTAssertEqual(it.photos, [])
        XCTAssertNil(it.json["photo"])             // legacy single field folded away
        XCTAssertNil(it.maintenance)
        // A legacy single `photo` string migrates into the photos array.
        let legacy = try XCTUnwrap(coerceItem(json: ["name": "Wetsuit", "photo": "data:image/jpeg;base64,AAA"]))
        XCTAssertEqual(legacy.photos, ["data:image/jpeg;base64,AAA"])
        XCTAssertNil(legacy.json["photo"])
        let withCare = try XCTUnwrap(coerceItem(json: ["name": "Wetsuit", "maintenance": ["intervalDays": 365]]))
        XCTAssertEqual(withCare.maintenance?.intervalDays, 365)
    }

    // JS: 'coerceItem: photos array is filtered and capped at MAX_PHOTOS'
    func testCoerceItemPhotosArrayIsFilteredAndCapped() throws {
        let dirty = try XCTUnwrap(coerceItem(json: ["name": "Bike", "photos": ["a", "", nil, "b", 42]]))
        XCTAssertEqual(dirty.photos, ["a", "b"])   // non-string / empty entries dropped
        let many = coerceItem(Item(name: "Drone", photos: (0..<(MAX_PHOTOS + 3)).map { "p\($0)" }))
        XCTAssertEqual(many.photos.count, MAX_PHOTOS)
        XCTAssertEqual(many.photos.first, "p0")
        // An explicit photos array wins over a legacy single photo.
        let both = try XCTUnwrap(coerceItem(json: ["name": "Tent", "photo": "legacy", "photos": ["new"]]))
        XCTAssertEqual(both.photos, ["new"])
    }

    // JS: 'coerceItem: defaults and validates the new metadata fields'
    func testCoerceItemDefaultsAndValidatesTheNewMetadataFields() throws {
        let empty = try XCTUnwrap(coerceItem(json: ["name": "Thing"]))
        for f in ["color", "size", "manufacturer", "model", "ownedBy", "acquired", "currency", "purchaseLink", "expiry", "condition", "serial"] {
            XCTAssertEqual(empty.json[f], "", "\(f) should default to ''")
        }
        XCTAssertEqual(empty.price, 0)
        XCTAssertEqual(empty.qtyOwned, 0)
        // Invalid values are rejected; valid ones kept.
        let bad = try XCTUnwrap(coerceItem(json: ["name": "X", "condition": "  sparkly  ", "acquired": "not-a-date", "price": -5, "qtyOwned": -2]))
        // Conditions are editable and live per-device, so an id this device doesn't know
        // is KEPT (trimmed), not dropped — dropping it would erase a rating set elsewhere.
        XCTAssertEqual(bad.condition, "sparkly")
        XCTAssertEqual(bad.acquired, "")        // non-YMD date dropped
        XCTAssertEqual(bad.price, 0)            // negative price clamped
        XCTAssertEqual(bad.qtyOwned, 0)         // negative qty clamped
        let good = try XCTUnwrap(coerceItem(json: ["name": "X", "condition": "worn", "acquired": "2026-01-15", "price": 19.9, "qtyOwned": 3]))
        XCTAssertEqual(good.condition, "worn")
        XCTAssertEqual(good.acquired, "2026-01-15")
        XCTAssertEqual(good.price, 19.9)
        XCTAssertEqual(good.qtyOwned, 3)
        // Lifecycle ("Not in use"): boolean defaults false; reason validated & only kept when valid.
        XCTAssertEqual(empty.retired, false)
        XCTAssertEqual(empty.retiredReason, "")
        let retiredBad = try XCTUnwrap(coerceItem(json: ["name": "X", "retired": 1, "retiredReason": "exploded"]))
        XCTAssertEqual(retiredBad.retired, true)       // any truthy -> true
        XCTAssertEqual(retiredBad.retiredReason, "")   // unknown reason id dropped
        let retiredGood = try XCTUnwrap(coerceItem(json: ["name": "X", "retired": true, "retiredReason": "sold"]))
        XCTAssertEqual(retiredGood.retired, true)
        XCTAssertEqual(retiredGood.retiredReason, "sold")
        // (the same rules through the typed form)
        let typed = coerceItem(Item(name: "X", acquired: "not-a-date", price: -5, condition: "  sparkly  ", retiredReason: "exploded", qtyOwned: -2))
        XCTAssertEqual([typed.condition, typed.acquired, typed.retiredReason], ["sparkly", "", ""])
        XCTAssertEqual(typed.price, 0)
        XCTAssertEqual(typed.qtyOwned, 0)
    }

    // JS: 'consumable flag survives coerceItem/newItem'
    func testConsumableFlagSurvivesCoerceItemAndNewItem() {
        XCTAssertEqual(newItem(name: "Toothpaste", consumable: true).consumable, true)
        XCTAssertEqual(newItem(name: "Phone").consumable, false)
    }

    // JS: 'isPhotoRef: ids are refs, data URLs are not'
    func testIsPhotoRefIdsAreRefsDataURLsAreNot() {
        XCTAssertEqual(isPhotoRef("abc123"), true)
        XCTAssertEqual(isPhotoRef(DATA_URL), false)
        XCTAssertEqual(isPhotoRef(""), false)
        XCTAssertEqual(isPhotoRef(nil), false)
    }

    // JS: 'photoRefs / inlinePhotos split a mixed (mid-migration) item'
    func testPhotoRefsAndInlinePhotosSplitAMixedItem() {
        let it = newItem(name: "Tent", photos: ["id-1", DATA_URL, "id-2"])
        XCTAssertEqual(photoRefs(it), ["id-1", "id-2"])
        XCTAssertEqual(inlinePhotos(it), [DATA_URL])
        XCTAssertEqual(hasInlinePhotos([newItem(name: "A"), it]), true)
        XCTAssertEqual(hasInlinePhotos([newItem(name: "A", photos: ["id-9"])]), false)
    }

    // JS: 'coerceItem keeps both photo shapes and defaults thumb to a string'
    func testCoerceItemKeepsBothPhotoShapesAndDefaultsThumb() {
        let it = coerceItem(newItem(name: "Stove", photos: ["id-1", DATA_URL]))
        XCTAssertEqual(it.photos, ["id-1", DATA_URL])   // migration converts the inline one later
        XCTAssertEqual(it.thumb, "")
        XCTAssertEqual(coerceItem(json: ["name": "X", "thumb": .string(DATA_URL)])?.thumb, DATA_URL)
    }

    // JS: 'looksLikeEmail: tells a sign-in address from a person’s name'
    // (The JS test uses a real address; this repository is public, so an invented one stands in.)
    func testLooksLikeEmailTellsASignInAddressFromAName() {
        XCTAssertEqual(looksLikeEmail("anna.berg@example.com"), true)
        XCTAssertEqual(looksLikeEmail("  a@b.co  "), true)
        XCTAssertEqual(looksLikeEmail("Martin"), false)
        XCTAssertEqual(looksLikeEmail("Anna & Martin"), false)
        XCTAssertEqual(looksLikeEmail("Shared"), false)
        XCTAssertEqual(looksLikeEmail(""), false)
        XCTAssertEqual(looksLikeEmail(nil), false)
        XCTAssertEqual(looksLikeEmail("no-at-sign.com"), false)
        // (edges of the regex, checked against Node)
        XCTAssertEqual(looksLikeEmail("a@b"), false)
        XCTAssertEqual(looksLikeEmail("a@b."), false)
        XCTAssertEqual(looksLikeEmail("a@.b"), false)
        XCTAssertEqual(looksLikeEmail("a@@b.co"), false)
        XCTAssertEqual(looksLikeEmail("a b@c.de"), false)
        XCTAssertEqual(looksLikeEmail("a@b..c"), true)
    }

    // JS: 'ownerNameFromEmail: an address becomes the name a person would use'
    // (Invented addresses of the same shapes as the JS test's.)
    func testOwnerNameFromEmailAnAddressBecomesAName() {
        XCTAssertEqual(ownerNameFromEmail("anna.berg@example.com"), "Anna")
        XCTAssertEqual(ownerNameFromEmail("anna@example.com"), "Anna")
        XCTAssertEqual(ownerNameFromEmail("anna_b+tag@example.com"), "Anna")
        // Too short to be a name on its own — keep the whole local part rather than "A".
        XCTAssertEqual(ownerNameFromEmail("a.berg@example.com"), "A.berg")
        XCTAssertEqual(ownerNameFromEmail(""), "")
    }

    // JS: 'coerceItem: adopts a legacy owner name, but never the address sync stamped there'
    func testCoerceItemAdoptsALegacyOwnerNameButNeverTheSyncAddress() {
        // A real name typed before v117 is carried across.
        XCTAssertEqual(coerceItem(json: ["name": "Tent", "owner": "Anna"])?.ownedBy, "Anna")
        // The sync addon's own stamp is not a name and must not become one here.
        XCTAssertEqual(coerceItem(json: ["name": "Tent", "owner": "anna.berg@example.com"])?.ownedBy, "")
        // Once ownedBy exists it wins, including when deliberately empty.
        XCTAssertEqual(coerceItem(json: ["name": "Tent", "owner": "Anna", "ownedBy": "Martin"])?.ownedBy, "Martin")
        XCTAssertEqual(coerceItem(json: ["name": "Tent", "owner": "Anna", "ownedBy": ""])?.ownedBy, "")
    }

    // JS: 'coerceItem: keeps a phase this device does not know (it syncs, so it is real)'
    func testCoerceItemKeepsAPhaseThisDeviceDoesNotKnow() {
        // The old behaviour reset anything unrecognised to "≥1 week ahead", which with an
        // editable+synced list would silently retag items the other device had just filed.
        XCTAssertEqual(coerceItem(json: ["name": "Tent", "phase": "load-the-car"])?.phase, "load-the-car")
        XCTAssertEqual(coerceItem(json: ["name": "Tent", "phase": "  door  "])?.phase, "door")
        XCTAssertEqual(coerceItem(json: ["name": "Tent"])?.phase, defaultPhaseId())
        XCTAssertEqual(coerceItem(json: ["name": "Tent", "phase": 42])?.phase, defaultPhaseId())
    }

    // --- not in the JS suite: what the Swift shape adds ---

    func testTheReservedSyncKeysAreNeverKeptOrWritten() throws {
        let it = try XCTUnwrap(coerceItem(json: ["name": "Tent", "owner": "anna.berg@example.com", "realmId": "rlm-1", "futureField": 7]))
        XCTAssertNil(it.json["owner"])
        XCTAssertNil(it.json["realmId"])
        XCTAssertEqual(it.extra, ["futureField": 7])       // an unknown key is carried, not lost
        XCTAssertEqual(it.json["futureField"], 7)
    }

    func testAnItemRoundTripsThroughJSONWithEveryEntryAndResolveField() throws {
        let original = newItem(
            id: "i1", name: "Rain jacket", swedish: "Regnjacka", qty: "2", container: "Day pack", phase: "door",
            seasons: ["Summer"], weather: ["rain"], sub: ["Hood"], weight: 320.5,
            maintenance: Maintenance(notes: "Re-proof", intervalDays: 365, log: [MaintenanceLogEntry(date: "2026-03-01", note: "done")]),
            stats: ItemStats(packed: 3, used: 2, unused: 1, skipped: 1, lastReviewed: "2026-05-01T00:00:00.000Z"),
            ownedBy: "Anna", price: 1299, qtyOwned: 2, keep: true,
            sourceListId: "l1", sourceItemId: "src1", custom: true, checked: true, skipped: true, used: false, edited: true,
            itemId: "cat1", memId: "", link: true, ovContainer: "", tplContainer: "Hiking backpack",
            defContainer: "Day pack", ovPhase: "door", defPhase: "week")
        let data = try JSONEncoder().encode(original)
        let back = try JSONDecoder().decode(Item.self, from: data)
        XCTAssertEqual(back, original)
        // The web app's own key names, underscores and all.
        let o = original.json
        XCTAssertEqual(o["_edited"], true)
        XCTAssertEqual(o["_memId"], "")
        XCTAssertEqual(o["_itemId"], "cat1")
        XCTAssertEqual(o["_ovContainer"], "")
        XCTAssertEqual(o["_defPhase"], "week")
        XCTAssertEqual(o["used"], false)
        XCTAssertEqual(o["qtyOwned"], 2)
        // A plain catalogue item writes none of the entry / resolve keys.
        let plain = newItem(name: "Socks").json
        XCTAssertEqual(plain["keep"], false, "v188: keep is intrinsic and always written")
        for k in ["sourceListId", "sourceItemId", "custom", "checked", "skipped", "used", "_edited",
                  "_itemId", "_memId", "_link", "_ovContainer", "_tplContainer", "_defContainer", "_ovPhase", "_defPhase"] {
            XCTAssertNil(plain[k], k)
        }
        XCTAssertEqual(plain["maintenance"], .null)
    }

    func testDecodingIsCoercionAndNeverThrows() throws {
        let junk = Data(#"{"name":"Thing","seasons":"Summer","weight":"5","charging":"yes","qty":2,"stats":{"packed":2.9,"used":-1},"sourceListId":null,"used":"yes","photos":"x","maintenance":"soon"}"#.utf8)
        let it = try JSONDecoder().decode(Item.self, from: junk)
        XCTAssertEqual(it.id, "")                   // JS leaves it undefined; '' is as falsy
        XCTAssertEqual(it.container, "")            // NOT newItem's default — coerceItem never sets it
        XCTAssertEqual(it.seasons, [])              // non-array coerced to []
        XCTAssertEqual(it.weight, 0)                // Number.isFinite('5') is false — no coercion
        XCTAssertEqual(it.charging, true)           // any truthy
        XCTAssertEqual(it.qty, "2")                 // an old numeric qty reads as its text
        XCTAssertEqual(it.stats, ItemStats(packed: 2, used: 0))
        XCTAssertNil(it.sourceListId)
        XCTAssertNil(it.used)                       // only a real boolean counts
        XCTAssertEqual(it.photos, [])
        XCTAssertNil(it.maintenance)
        XCTAssertEqual(it.category, CATEGORY_DEFAULT)
        XCTAssertEqual(it.itemType, "item")
        // Anything that is not an object at all.
        XCTAssertNil(coerceItem(json: nil))
        XCTAssertNil(coerceItem(json: "Tent"))
        XCTAssertEqual(try JSONDecoder().decode(Item.self, from: Data("null".utf8)).name, "")
    }

    func testNewItemFromARawPartialLaysItOverTheDefaultsAsTheJSSpreadDoes() {
        let it = newItem(json: ["name": "Tent", "weather": ["rain", "sunshine"], "owner": "Anna"])
        XCTAssertEqual(it.container, "Carry-on / hand luggage")
        XCTAssertEqual(it.phase, "week")
        XCTAssertEqual(it.weather, ["rain"])
        XCTAssertFalse(it.id.isEmpty)
        // 🪤 As in JS: the default `ownedBy: ''` is already a string, so a legacy
        // `owner` in the partial is NOT adopted by newItem (only by coerceItem alone).
        XCTAssertEqual(it.ownedBy, "")
        // The memberwise init and newItem agree on the defaults.
        XCTAssertEqual(Item(id: "x"), newItem(id: "x"))
    }

    func testCoerceItemFallsBackToTheLivePhaseListsDefault() {
        setPhases(json: [["id": "todo", "label": "To do", "task": true], ["id": "bag", "label": "In the bag"]])
        XCTAssertEqual(coerceItem(Item(name: "Tent", phase: "   ")).phase, "bag")
    }
}
