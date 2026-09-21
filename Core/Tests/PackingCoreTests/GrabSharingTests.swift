import XCTest
@testable import PackingCore

// Ported from tests/model.test.mjs — "Sharing a grab list (QR / link / paste)".
final class GrabSharingTests: XCTestCase {
    override func tearDown() { PackingEnv.reset(); super.tearDown() }

    private func message(_ body: @autoclosure () throws -> Any) -> String {
        do { _ = try body(); return "(did not throw)" } catch { return (error as? ShareError)?.message ?? "\(error)" }
    }

    // JS: 'encodeGrabShare / decodeGrabShare: round-trip of name, look and items'
    func testRoundTripOfNameLookAndItems() throws {
        let code = try encodeGrabShare(name: "Biz trip", icon: "briefcase", tone: "purple", items: ["Laptop", "Charger", "Badge"])
        // Since v159 a code may be squeezed, which marks it with a leading "z." —
        // still URL-safe, still unpadded.
        let body = code.hasPrefix("z.") ? String(code.dropFirst(2)) : code
        XCTAssertFalse(body.isEmpty)
        XCTAssertTrue(body.utf8.allSatisfy { ($0 >= 0x41 && $0 <= 0x5A) || ($0 >= 0x61 && $0 <= 0x7A) || ($0 >= 0x30 && $0 <= 0x39) || $0 == 0x5F || $0 == 0x2D },
                      "the code is URL-safe with no padding")
        let got = try decodeGrabShare(code)
        XCTAssertEqual(got, GrabShare(name: "Biz trip", icon: "briefcase", tone: "purple", items: ["Laptop", "Charger", "Badge"]))
    }

    // JS: 'decodeGrabShare: accepts a whole link, or text with the link pasted inside it'
    func testAcceptsAWholeLinkOrTextWithTheLinkPastedInsideIt() throws {
        let code = try encodeGrabShare(name: "Swim", items: ["Goggles", "Towel"])
        let link = "https://example.invalid/AMS-Packing/#/g/\(code)"
        XCTAssertEqual(try decodeGrabShare(link).items, ["Goggles", "Towel"])
        XCTAssertEqual(try decodeGrabShare("Here is my list: \(link) — enjoy").items, ["Goggles", "Towel"])
        XCTAssertEqual(try decodeGrabShare("  \(code)\n").items, ["Goggles", "Towel"])
        let got = try decodeGrabShare(code)
        XCTAssertEqual(got.icon, "", "no icon shared → empty, the app falls back to the button’s factory look")
        XCTAssertEqual(got.tone, "")
    }

    // JS: 'encodeGrabShare: tidies the items — trims, drops blanks and duplicates, caps lengths'
    func testTidiesTheItems() throws {
        let long = String(repeating: "x", count: GRAB_SHARE_ITEM_MAX + 20)
        let code = try encodeGrabShare(json: ["name": "  A very long list name indeed  ",
                                              "items": ["  Towel ", "", "towel", "TOWEL", 42, nil, .string(long)]])
        let got = try decodeGrabShare(code)
        XCTAssertEqual(got.name, jsSlice("A very long list name indeed", 0, GRAB_SHARE_NAME_MAX))
        XCTAssertEqual(got.items, ["Towel", String(repeating: "x", count: GRAB_SHARE_ITEM_MAX)])
        let many = (0..<(GRAB_SHARE_ITEMS_MAX + 10)).map { "Thing \($0)" }
        XCTAssertEqual(try decodeGrabShare(encodeGrabShare(items: many)).items.count, GRAB_SHARE_ITEMS_MAX)
    }

    // JS: 'encodeGrabShare / decodeGrabShare: refuse an empty list and anything that is not a grab list'
    func testRefuseAnEmptyListAndAnythingThatIsNotAGrabList() throws {
        XCTAssertTrue(message(try encodeGrabShare(name: "Empty", items: [])).contains("nothing on it"))
        XCTAssertTrue(message(try decodeGrabShare("not a code at all!")).contains("not an AMS Packing grab-list"))
        XCTAssertTrue(message(try decodeGrabShare("")).contains("not an AMS Packing grab-list"))
        // A trip link is valid base64 JSON, but not a grab list.
        let trip = "#/t/" + toBase64Url("{\"kind\":\"trip\",\"event\":{}}")
        XCTAssertTrue(message(try decodeGrabShare(trip)).contains("not an AMS Packing grab-list"))
        // Right kind, but no usable items.
        let blank = toBase64Url("{\"k\":\"grab\",\"v\":1,\"n\":\"X\",\"x\":[\"\",\"  \"]}")
        XCTAssertTrue(message(try decodeGrabShare(blank)).contains("empty"))
    }

    // JS: 'decodeGrabShare: survives names with accents and emoji through the base64 layer'
    func testSurvivesNamesWithAccentsAndEmoji() throws {
        let got = try decodeGrabShare(encodeGrabShare(name: "Löprunda 🏃", items: ["Vattenflaska", "Mössa & handskar"]))
        XCTAssertEqual(got.name, "Löprunda 🏃")
        XCTAssertEqual(got.items, ["Vattenflaska", "Mössa & handskar"])
    }

    // --- not in the JS suite: byte for byte against the web app ---

    func testTheCodesAreByteForByteTheWebApps() throws {
        XCTAssertEqual(try encodeGrabShare(name: "Biz trip", icon: "briefcase", tone: "purple", items: ["Laptop", "Charger", "Badge"]),
                       ShareRef.grab1)
        XCTAssertEqual(try encodeGrabShare(name: "Löprunda 🏃", items: ["Vattenflaska", "Mössa & handskar"]), ShareRef.grab2)
        XCTAssertEqual(try encodeGrabShare(GrabShare(name: "Many", icon: "bag", items: (0..<40).map { "Thing number \($0)" })),
                       ShareRef.grabMany)
        // The 14-unit cut lands INSIDE the swimmer: JS keeps the lone half and writes it
        // `\ud83c`, so the code must carry exactly that — and a slash is never escaped.
        let junk: JSONValue = ["name": "Morning swim 🏊 laps",
                               "items": ["  Towel ", "", "towel", "TOWEL", 42, nil, "Path a/b \"quoted\""]]
        XCTAssertEqual(try encodeGrabShare(json: junk), ShareRef.grab3)
        XCTAssertEqual(try unpackShare(ShareRef.grab3),
                       "{\"k\":\"grab\",\"v\":1,\"n\":\"Morning swim \\ud83c\",\"x\":[\"Towel\",\"Path a/b \\\"quoted\\\"\"]}")
    }

    func testCodesMadeByTheWebAppOpenHere() throws {
        XCTAssertEqual(try decodeGrabShare(ShareRef.grab1),
                       GrabShare(name: "Biz trip", icon: "briefcase", tone: "purple", items: ["Laptop", "Charger", "Badge"]))
        XCTAssertEqual(try decodeGrabShare("Try this: https://example.invalid/#/g/\(ShareRef.grab2)."),
                       GrabShare(name: "Löprunda 🏃", items: ["Vattenflaska", "Mössa & handskar"]))
        XCTAssertEqual(try decodeGrabShare(ShareRef.grabMany).items.count, 40)
        // Half an emoji cannot live in a Swift String: it is dropped, and the space before it with it.
        XCTAssertEqual(try decodeGrabShare(ShareRef.grab3), GrabShare(name: "Morning swim", items: ["Towel", "Path a/b \"quoted\""]))
    }

    func testJunkInsideACode() throws {
        // A name that is a number is its text; an icon that is not a string is ''.
        let code = toBase64Url("{\"k\":\"grab\",\"n\":5,\"i\":7,\"c\":null,\"x\":[\"A\",3,\"a\",\"B\"]}")
        XCTAssertEqual(try decodeGrabShare(code), GrabShare(name: "5", icon: "", tone: "", items: ["A", "B"]))
        XCTAssertTrue(message(try decodeGrabShare(toBase64Url("[1,2]"))).contains("not an AMS Packing grab-list"))
        XCTAssertTrue(message(try decodeGrabShare(toBase64Url("\"grab\""))).contains("not an AMS Packing grab-list"))
        XCTAssertTrue(message(try encodeGrabShare(json: nil)).contains("nothing on it"))
        XCTAssertEqual(GrabShare(name: "N", items: ["a"]).json, ["name": "N", "icon": "", "tone": "", "items": ["a"]])
        XCTAssertEqual([GRAB_SHARE_KIND], ["grab"])
        XCTAssertEqual([GRAB_SHARE_NAME_MAX, GRAB_SHARE_ITEM_MAX, GRAB_SHARE_ITEMS_MAX], [14, 60, 100])
    }
}

// Every JS test of this section is ported above. One change of DATA: the JS builds its
// example link on the project's real GitHub Pages address; here it is example.invalid.
