import XCTest
@testable import PackingCore

// Ported from tests/model.test.mjs — "Sharing a template (#/l/<code>)", "A share code
// never carries an e-mail address (v186)", and the big-template test of "Squeezing a
// share code".
final class ListSharingTests: XCTestCase {
    override func tearDown() { PackingEnv.reset(); super.tearDown() }

    private func message(_ body: @autoclosure () throws -> Any) -> String {
        do { _ = try body(); return "(did not throw)" } catch { return (error as? ShareError)?.message ?? "\(error)" }
    }
    private func fnv(_ s: String) -> UInt32 {
        var h: UInt32 = 2_166_136_261
        for b in s.utf8 { h = (h ^ UInt32(b)) &* 16_777_619 }
        return h
    }

    // (The JS names the packer after the app's owner; the repository is public, so: Alex.)
    private func sharableList() -> PackList {
        let sections = [TemplateSection(id: "sec-a", name: "On me"), TemplateSection(id: "sec-b", name: "In the bag")]
        return newList(
            name: "Trail run", emoji: "🏃", color: "#2e7d32", sections: sections, group: "GA", defaultContainer: "Duffel",
            items: [
                newItem(name: "Trail shoes", swedish: "Terrängskor", qty: "1 pair", category: "Clothing", phase: "week",
                        shortList: true, seasons: ["summer"], contexts: ["outdoor"], weather: ["rain"], sub: ["Spare laces"],
                        note: "The grippy ones", weight: 620, liquid: false, perNight: false,
                        section: "sec-a", kit: "Run kit", packer: "Alex", storage: "Hall cupboard"),
                newItem(name: "Head torch", category: "Tech", charging: true, chargeType: "usb-c", restricted: true, section: "sec-b"),
                newItem(name: "Gels", perNight: true, consumable: true, section: "sec-b"),
            ])
    }

    // JS: 'encodeListShare/decodeListShare: a template survives the round trip'
    func testATemplateSurvivesTheRoundTrip() throws {
        let list = sharableList()
        let shared = try decodeListShare(encodeListShare(list))
        XCTAssertEqual(shared.name, "Trail run")
        XCTAssertEqual(shared.emoji, "🏃")
        XCTAssertEqual(shared.color, "#2e7d32")
        XCTAssertEqual(shared.group, "GA")
        XCTAssertEqual(shared.defaultContainer, "Duffel")
        XCTAssertEqual(shared.sections, ["On me", "In the bag"])
        XCTAssertEqual(shared.items.map { $0.name }, ["Trail shoes", "Head torch", "Gels"])
        let shoes = shared.items[0]
        XCTAssertEqual(shoes.swedish, "Terrängskor")
        XCTAssertEqual(shoes.qty, "1 pair")
        XCTAssertEqual(shoes.category, "Clothing")
        XCTAssertEqual(shoes.seasons, ["summer"])
        XCTAssertEqual(shoes.weather, ["rain"])
        XCTAssertEqual(shoes.sub, ["Spare laces"])
        XCTAssertEqual(shoes.kit, "Run kit")
        XCTAssertEqual(shoes.storage, "Hall cupboard")
        XCTAssertEqual(shoes.packer, "Alex")
        XCTAssertEqual(shoes.note, "The grippy ones")
        XCTAssertEqual(shoes.weight, 620)
        XCTAssertEqual(shoes.shortList, true)
        XCTAssertEqual(shoes.liquid, false)
        // sections travel by NAME, so the receiving device can rebuild its own ids
        XCTAssertEqual(shoes.section, "On me")
        XCTAssertEqual(shared.items[1].charging, true)
        XCTAssertEqual(shared.items[1].chargeType, "usb-c")
        XCTAssertEqual(shared.items[1].restricted, true)
        XCTAssertEqual(shared.items[2].consumable, true)
        XCTAssertEqual(shared.items[2].perNight, true)
    }

    // JS: 'decodeListShare: accepts a whole link, a bare code, or a link inside a message'
    func testAcceptsAWholeLinkABareCodeOrALinkInsideAMessage() throws {
        let code = try encodeListShare(sharableList())
        let link = "https://example.invalid/AMS-Packing/#/l/\(code)"
        XCTAssertEqual(try decodeListShare(code).name, "Trail run")
        XCTAssertEqual(try decodeListShare(link).name, "Trail run")
        XCTAssertEqual(try decodeListShare("Here you go: \(link) — see you Sunday").name, "Trail run")
    }

    // JS: 'decodeListShare: rejects anything that is not a shared template'
    func testRejectsAnythingThatIsNotASharedTemplate() throws {
        XCTAssertTrue(message(try decodeListShare("not a code")).contains("template link or code"))
        XCTAssertTrue(message(try decodeListShare("")).contains("template link or code"))
        // a grab-list code is a different kind and must not be mistaken for a template
        let grab = try encodeGrabShare(name: "Swim", items: ["Goggles"])
        XCTAssertTrue(message(try decodeListShare(grab)).contains("template link or code"))
        // and the other way round
        let tpl = try encodeListShare(sharableList())
        XCTAssertTrue(message(try decodeGrabShare(tpl)).contains("grab-list link or code"))
    }

    // JS: 'encodeListShare: an empty template has nothing to share'
    func testAnEmptyTemplateHasNothingToShare() {
        XCTAssertTrue(message(try encodeListShare(newList(name: "Empty"))).contains("nothing on it to share"))
    }

    // JS: 'listFromShare: rebuilds a real template with fresh ids and its sections joined up'
    func testListFromShareRebuildsARealTemplate() throws {
        let original = sharableList()
        let rebuilt = listFromShare(try decodeListShare(encodeListShare(original)))
        XCTAssertEqual(rebuilt.name, "Trail run")
        XCTAssertEqual(rebuilt.builtin, false)
        XCTAssertNotEqual(rebuilt.id, original.id)
        XCTAssertEqual(rebuilt.sections.count, 2)
        XCTAssertEqual(rebuilt.sections.map { $0.name }, ["On me", "In the bag"])
        // every item points at a section id that exists in THIS template
        let ids = Set(rebuilt.sections.map { $0.id })
        XCTAssertEqual(rebuilt.items[0].section, rebuilt.sections[0].id)
        XCTAssertTrue(rebuilt.items.allSatisfy { $0.section.isEmpty || ids.contains($0.section) })
        XCTAssertTrue(rebuilt.items.allSatisfy { !$0.id.isEmpty })
        XCTAssertEqual(Set(rebuilt.items.map { $0.id }).count, 3)
        // and the conditions came along
        XCTAssertEqual(rebuilt.items[0].seasons, ["summer"])
        XCTAssertEqual(rebuilt.items[1].chargeType, "usb-c")
    }

    // JS: 'listFromShare: the two system bins can never arrive as themselves'
    func testTheTwoSystemBinsCanNeverArriveAsThemselves() {
        for role in ["loose", "container"] {
            let src = SharedList(name: "Sneaky", role: role, items: [SharedListItem(name: "Thing")])
            XCTAssertEqual(listFromShare(src).role, "", "\(role) must become an ordinary template")
        }
        XCTAssertEqual(listFromShare(SharedList(name: "Core", role: "base", items: [SharedListItem(name: "Thing")])).role, "base")
    }

    // JS: 'listFromShare: a partial overrides identity, for replacing a template in place'
    func testAPartialOverridesIdentity() throws {
        let shared = try decodeListShare(encodeListShare(sharableList()))
        let fresh = listFromShare(shared, partial: ["id": "keep-me", "createdAt": "2020-01-01T00:00:00.000Z"])
        XCTAssertEqual(fresh.id, "keep-me")
        XCTAssertEqual(fresh.createdAt, "2020-01-01T00:00:00.000Z")
    }

    // --- A share code never carries an e-mail address (v186) -------------------
    // `owner` belongs to the sync addon, which stamps the signed-in account's ADDRESS
    // on every synced row. Until v186 the template share read that field, so a code
    // handed to a stranger carried the sender's sign-in address on every item.
    // (Here an item can only hold that key in `extra`, built in memory.)

    private func ownedList(_ items: [Item]) -> PackList { newList(name: "Camping", items: items) }

    // JS: 'encodeListShare: whose-it-is comes from ownedBy, and the sync address stays home'
    func testWhoseItIsComesFromOwnedByAndTheSyncAddressStaysHome() throws {
        var tent = newItem(name: "Tent", ownedBy: "Anna")
        tent.extra["owner"] = "someone@example.com"
        let code = try encodeListShare(ownedList([tent]))
        let text = try unpackShare(code)
        XCTAssertFalse(text.contains("@"), "no address anywhere in the shared text")
        XCTAssertFalse(text.contains("example.com"))
        XCTAssertEqual(try decodeListShare(code).items[0].ownedBy, "Anna")
    }

    // JS: 'encodeListShare: an item with only a sync-stamped address shares with no owner at all'
    func testAnItemWithOnlyASyncStampedAddressSharesWithNoOwnerAtAll() throws {
        var stove = newItem(name: "Stove")
        stove.extra["owner"] = "someone@example.com"
        let code = try encodeListShare(ownedList([stove]))
        let text = try unpackShare(code)
        XCTAssertFalse(text.contains("@"), "no address anywhere in the shared text")
        XCTAssertNil(try JSONValue.parse(text)["x"]?[0]?["u"], "the owner key is not written at all")
        XCTAssertEqual(try decodeListShare(code).items[0].ownedBy, "")
    }

    // JS: 'encodeListShare: an address that reached ownedBy is refused too — whole, cut short, or inside other words'
    func testAnAddressThatReachedOwnedByIsRefusedToo() throws {
        let long = String(repeating: "a", count: 38) + "@example.com"   // cut at 40 characters it no longer LOOKS like an address
        for bad in ["someone@example.com", "  someone@example.com ", long, "Anna <someone@example.com>"] {
            let it = newItem(name: "Lamp", ownedBy: bad)
            let text = try unpackShare(encodeListShare(ownedList([it])))
            XCTAssertFalse(text.contains("@"), "refused: \(bad)")
            XCTAssertFalse(text.contains("aaaaaaaa"), "nothing of it left behind: \(bad)")
        }
    }

    // JS: 'decodeListShare: an OLD code carrying an address in `u` cannot plant it'
    func testAnOldCodeCarryingAnAddressInUCannotPlantIt() throws {
        // exactly what a pre-v186 app wrote
        let old = packShare("{\"k\":\"tpl\",\"v\":1,\"n\":\"Camping\",\"x\":[{\"n\":\"Tent\",\"u\":\"someone@example.com\"},{\"n\":\"Mat\",\"u\":\"Anna\"}]}")
        let shared = try decodeListShare(old)
        XCTAssertEqual(shared.items[0].ownedBy, "")
        XCTAssertEqual(shared.items[1].ownedBy, "Anna")
        XCTAssertTrue(shared.items.allSatisfy { $0.json["owner"] == nil }, "the reserved field is never written")
        let rebuilt = listFromShare(shared)
        XCTAssertFalse(rebuilt.json.text().contains("@"), "nothing of the address survives into the saved template")
        XCTAssertTrue(rebuilt.items.allSatisfy { $0.json["owner"] == nil && $0.json["realmId"] == nil })
    }

    // JS: 'encodeListShare → listFromShare: a real owner name survives the round trip'
    func testARealOwnerNameSurvivesTheRoundTrip() throws {
        let original = ownedList([newItem(name: "Tent", ownedBy: "Anna"), newItem(name: "Stove")])
        let rebuilt = listFromShare(try decodeListShare(encodeListShare(original)))
        XCTAssertEqual(rebuilt.items[0].ownedBy, "Anna")
        XCTAssertEqual(rebuilt.items[1].ownedBy, "")
    }

    // JS: 'encodeListShare: a big template travels far smaller than it used to'
    func testABigTemplateTravelsFarSmallerThanItUsedTo() throws {
        let list = newList(name: "Everything", items: (0..<150).map { i in
            newItem(name: "Thing \(i)", category: "Clothing", phase: "week", seasons: ["summer"], contexts: ["outdoor"])
        })
        let code = try encodeListShare(list)
        XCTAssertTrue(code.hasPrefix(SHARE_ZIP_PREFIX), "a 150-item template is worth squeezing")
        let back = try decodeListShare(code)
        XCTAssertEqual(back.items.count, 150)
        XCTAssertEqual(back.items[99].name, "Thing 99")
        XCTAssertEqual(back.items[0].seasons, ["summer"])
    }

    // --- not in the JS suite: byte for byte against the web app ---

    /// The list `ShareReferenceFixtures.list1` was made from.
    private func referenceList() -> PackList {
        var list = sharableList()
        list.id = "L1"
        list.items[0].ownedBy = "Robin"
        list.items[1].weight = 86.5
        list.items[1].ownedBy = "Robin <someone@example.com>"
        list.items[2].itemType = "reminder"
        list.items[2].weight = 0.4
        list.items.append(newItem(name: "   "))
        return list
    }

    func testTheCodeIsByteForByteTheWebApps() throws {
        XCTAssertEqual(try encodeListShare(referenceList()), ShareRef.list1)
        // Key order `k v n x i c g …` and, per item, `n f w q c p b o y e k s a u t g se cx tr ca we sb`;
        // a weight under half a gram still writes `"g":0`; the blank-named item is left out.
        XCTAssertEqual(try unpackShare(ShareRef.list1), "{\"k\":\"tpl\",\"v\":1,\"n\":\"Trail run\",\"x\":["
            + "{\"n\":\"Trail shoes\",\"f\":1,\"w\":\"Terrängskor\",\"q\":\"1 pair\",\"c\":\"Clothing\",\"p\":\"week\",\"b\":\"Carry-on / hand luggage\",\"o\":\"The grippy ones\",\"e\":\"On me\",\"k\":\"Run kit\",\"s\":\"Hall cupboard\",\"a\":\"Alex\",\"u\":\"Robin\",\"g\":620,\"se\":[\"summer\"],\"cx\":[\"outdoor\"],\"we\":[\"rain\"],\"sb\":[\"Spare laces\"]},"
            + "{\"n\":\"Head torch\",\"f\":10,\"c\":\"Tech\",\"p\":\"week\",\"b\":\"Carry-on / hand luggage\",\"y\":\"usb-c\",\"e\":\"In the bag\",\"g\":87},"
            + "{\"n\":\"Gels\",\"f\":48,\"c\":\"Comfort & misc\",\"p\":\"week\",\"b\":\"Carry-on / hand luggage\",\"e\":\"In the bag\",\"t\":1,\"g\":0}"
            + "],\"i\":\"🏃\",\"c\":\"#2e7d32\",\"g\":\"GA\",\"d\":\"Duffel\",\"s\":[\"On me\",\"In the bag\"]}")
        let big = newList(name: "Everything", role: "transport", transport: "Plane", items: (0..<150).map { i in
            newItem(name: "Thing \(i)", category: "Clothing", phase: "week", seasons: ["summer"], contexts: ["outdoor"])
        })
        let code = try encodeListShare(big)
        XCTAssertEqual(code.utf16.count, ShareRef.listBig.length)
        XCTAssertEqual(fnv(code), ShareRef.listBig.hash)
        XCTAssertTrue(code.hasPrefix(ShareRef.listBig.head))
    }

    func testACodeMadeByTheWebAppOpensHere() throws {
        let shared = try decodeListShare("https://example.invalid/app/#/l/" + ShareRef.list1)
        XCTAssertEqual(shared.name, "Trail run")
        XCTAssertEqual(shared.emoji, "🏃")
        XCTAssertEqual(shared.sections, ["On me", "In the bag"])
        XCTAssertEqual(shared.items.count, 3)
        XCTAssertEqual(shared.items[0], SharedListItem(
            name: "Trail shoes", swedish: "Terrängskor", qty: "1 pair", category: "Clothing", phase: "week",
            container: "Carry-on / hand luggage", note: "The grippy ones", section: "On me", kit: "Run kit",
            storage: "Hall cupboard", packer: "Alex", ownedBy: "Robin", weight: 620,
            seasons: ["summer"], contexts: ["outdoor"], weather: ["rain"], sub: ["Spare laces"], shortList: true))
        XCTAssertEqual(shared.items[1].weight, 87, "Math.round(86.5)")
        XCTAssertEqual(shared.items[1].ownedBy, "", "an address inside other words never left the sender")
        XCTAssertEqual([shared.items[1].charging, shared.items[1].restricted, shared.items[1].shortList], [true, true, false])
        XCTAssertEqual(shared.items[2].itemType, "reminder")
        XCTAssertEqual(shared.items[2].weight, 0)
        XCTAssertEqual([shared.items[2].perNight, shared.items[2].consumable], [true, true])
    }

    func testListFromShareDrawsItsIdsInTheJSOrder() throws {
        let shared = try decodeListShare(ShareRef.list1)
        PackingEnv.freeze(at: "2026-09-22T08:00:00.000Z")
        let list = listFromShare(shared)
        XCTAssertEqual(list.sections.map { $0.id }, ["id-1", "id-2"], "sections first")
        XCTAssertEqual(list.items.map { $0.id }, ["id-3", "id-4", "id-5"], "then the items")
        XCTAssertEqual(list.id, "id-6", "the list's own id last")
        XCTAssertEqual(list.items.map { $0.section }, ["id-1", "id-2", "id-2"])
        XCTAssertEqual(list.createdAt, "2026-09-22T08:00:00.000Z")
        // The list's own id is drawn even when the partial brings one.
        PackingEnv.freeze()
        let kept = listFromShare(shared, partial: ["id": "keep-me"])
        XCTAssertEqual(kept.id, "keep-me")
        XCTAssertEqual(id(), "id-7")
        // A share with nothing in it still makes a template.
        XCTAssertEqual(listFromShare(nil).name, "Shared template")
        XCTAssertEqual(listFromShare(SharedList(name: "   ")).name, "Shared template")
    }

    func testJunkInsideACode() throws {
        let code = packShare("{\"k\":\"tpl\",\"n\":7,\"i\":\"🏃🏃🏃\",\"s\":[\"A\",5,\"  \"],\"x\":[null,5,[1],{\"n\":\"  \"},"
            + "{\"n\":\"Thing\",\"f\":4294967297.9,\"g\":2.5,\"t\":true,\"w\":5,\"c\":9,\"se\":[\"summer\",3,\" \"]}]}")
        let shared = try decodeListShare(code)
        XCTAssertEqual(shared.name, "7")
        XCTAssertEqual(shared.emoji, "🏃🏃", "cut at four UTF-16 units")
        XCTAssertEqual(shared.sections, ["A"])
        XCTAssertEqual(shared.items.count, 1)
        let it = shared.items[0]
        XCTAssertEqual(it.shortList, true, "flags & bit works on the 32-bit integer JS makes of the number")
        XCTAssertEqual(it.charging, false)
        XCTAssertEqual(it.weight, 3, "Math.round(2.5)")
        XCTAssertEqual(it.itemType, "item", "only the NUMBER 1 means a reminder")
        XCTAssertEqual(it.swedish, "5")
        XCTAssertEqual(it.category, "")
        XCTAssertEqual(it.seasons, ["summer"])
        XCTAssertTrue(message(try decodeListShare(packShare("{\"k\":\"tpl\",\"x\":[{\"n\":\"\"}]}"))).contains("shared template is empty"))
        XCTAssertTrue(message(try encodeListShare(nil)).contains("no template to share"))
        XCTAssertEqual([LIST_SHARE_KIND], ["tpl"])
        XCTAssertEqual([LIST_SHARE_NAME_MAX, LIST_SHARE_ITEMS_MAX], [60, 400])
    }
}

// Every JS test of this section is ported above. Changes of DATA only: the packer's
// name (the JS uses the app owner's first name; here "Alex"), and the example link's
// host (example.invalid instead of the project's GitHub Pages address). Where the JS
// puts a sync-stamped `owner` on an item with an object spread, the Swift item gets it
// in `extra` — the only place a value built in memory can hold that key.
