import XCTest
@testable import PackingCore

// Ported from tests/model.test.mjs — base64url, the LZW coder, packShare / unpackShare —
// plus the byte-for-byte checks against strings the real web app produced (ShareRef).
final class ShareEncodingTests: XCTestCase {
    override func tearDown() { PackingEnv.reset(); super.tearDown() }

    private func utf8(_ s: String) -> [UInt8] { Array(s.utf8) }
    private func text(_ b: [UInt8]) -> String { String(decoding: b, as: UTF8.self) }
    private func roundTrip(_ s: String) throws -> String { try unpackShare(packShare(s)) }
    /// FNV-1a, 32 bit — the hash the parity contract uses for bytes too long to print.
    private func fnv(_ bytes: [UInt8]) -> UInt32 {
        var h: UInt32 = 2_166_136_261
        for b in bytes { h = (h ^ UInt32(b)) &* 16_777_619 }
        return h
    }
    /// The JS test's generator, in doubles exactly as JS computes it (the product
    /// passes 2^53, so an integer version would NOT give the same text).
    private struct JSRandom {
        var seed: Double = 12345
        mutating func next() -> Double {
            seed = (seed * 1_103_515_245 + 12345).truncatingRemainder(dividingBy: 2_147_483_648)
            return seed / 2_147_483_648
        }
    }
    private let alphabet = Array("abcdefghijklmnopqrstuvwxyz0123456789 {}[]\":,".utf8)

    // JS: 'base64url: round-trips unicode and stays URL-safe'
    func testBase64UrlRoundTripsUnicodeAndStaysURLSafe() throws {
        let s = "Vandersteg järn — åäö & spår/plus+slash"
        let enc = toBase64Url(s)
        XCTAssertEqual(try fromBase64Url(enc), s)
        XCTAssertFalse(enc.contains(where: { "+/=".contains($0) }), "no +, / or = in a URL-safe payload")
    }

    // JS: 'lzwCompress/lzwDecompress: bytes survive the round trip'
    func testLzwBytesSurviveTheRoundTrip() throws {
        for s in ["", "a", "ab", "aaaaaaaaaaaaaaaaaaaa", "ababababababab", "{\"a\":1,\"b\":2}", "ä ö ü € 😀"] {
            XCTAssertEqual(text(try lzwDecompress(lzwCompress(utf8(s)))), s, "round trip of \(s)")
        }
    }

    // JS: 'lzwCompress: survives inputs that cross the code-width boundaries'
    func testLzwSurvivesInputsThatCrossTheCodeWidthBoundaries() throws {
        // The dictionary widens from 9 to 16 bits as it fills; the decoder has to
        // widen in lock-step, one entry early. Long varied input crosses every step.
        var rnd = JSRandom()
        for len in [300, 1000, 5000, 20000, 60000] {
            var s: [UInt8] = []
            for _ in 0..<len { s.append(alphabet[Int((rnd.next() * Double(alphabet.count)).rounded(.down))]) }
            XCTAssertEqual(try lzwDecompress(lzwCompress(s)), s, "round trip at \(len) characters")
        }
    }

    // JS: 'packShare/unpackShare: repetitive JSON gets much shorter, and comes back whole'
    func testPackShareRepetitiveJSONGetsMuchShorter() throws {
        let row = "{\"id\":\"x\",\"name\":\"Thing\",\"category\":\"Clothing\",\"phase\":\"week\",\"packed\":false},"
        let json = "[" + String(repeating: row, count: 400) + "]"
        let code = packShare(json)
        XCTAssertTrue(code.hasPrefix(SHARE_ZIP_PREFIX), "a repetitive payload is worth squeezing")
        XCTAssertLessThan(code.utf16.count, json.utf16.count / 4, "squeezed to \(code.count) from \(json.count)")
        XCTAssertEqual(try unpackShare(code), json)
        // Byte for byte what the web app makes of the same text.
        XCTAssertEqual(code.utf16.count, ShareRef.packedRepetitive.length)
        XCTAssertEqual(fnv(utf8(code)), ShareRef.packedRepetitive.hash)
        XCTAssertTrue(code.hasPrefix(ShareRef.packedRepetitive.head))
    }

    // JS: 'packShare: a tiny payload is left as plain base64'
    func testPackShareATinyPayloadIsLeftAsPlainBase64() throws {
        let code = packShare("{\"k\":\"grab\"}")
        XCTAssertFalse(code.hasPrefix(SHARE_ZIP_PREFIX), "squeezing a short code would only make it longer")
        XCTAssertEqual(try unpackShare(code), "{\"k\":\"grab\"}")
        XCTAssertEqual(code, ShareRef.packedTiny)
    }

    // JS: 'unpackShare: still reads a plain code sent before squeezing existed'
    func testUnpackShareStillReadsAPlainCode() throws {
        let json = "{\"app\":\"ams-packing-list\",\"kind\":\"trip\"}"
        XCTAssertEqual(try unpackShare(toBase64Url(json)), json, "old links keep working")
    }

    // JS: 'unpackShare: a full stop at the end of a sentence is not part of the code'
    func testUnpackShareAFullStopIsNotPartOfTheCode() throws {
        let json = "{\"a\":\"" + String(repeating: "long and repetitive ", count: 60) + "\"}"
        let code = packShare(json)
        XCTAssertTrue(code.hasPrefix(SHARE_ZIP_PREFIX))
        XCTAssertEqual(try unpackShare(code + "."), json)
    }

    // JS: 'packShare/unpackShare: unicode survives'
    func testPackShareUnicodeSurvives() throws {
        let s = OrderedJSON.object([.init("name", .string("Terrängskor ä ö ü")),
                                    .init("note", .string("åka skidor 😀 — 100 %"))]).text()
        XCTAssertEqual(try roundTrip(s), s)
        XCTAssertEqual(packShare(s), ShareRef.packedUnicode)
    }

    // JS: 'base64UrlToBytes/bytesToBase64Url: raw bytes survive, URL-safe and unpadded'
    func testRawBytesSurviveURLSafeAndUnpadded() throws {
        let bytes = (0..<300).map { UInt8(($0 * 7) % 256) }
        let b64 = bytesToBase64Url(bytes)
        XCTAssertTrue(b64.utf8.allSatisfy { ($0 >= 0x41 && $0 <= 0x5A) || ($0 >= 0x61 && $0 <= 0x7A) || ($0 >= 0x30 && $0 <= 0x39) || $0 == 0x5F || $0 == 0x2D })
        XCTAssertEqual(try base64UrlToBytes(b64), bytes)
        XCTAssertEqual(b64, ShareRef.bytes300)
    }

    // --- not in the JS suite: byte for byte against the web app ---

    func testBase64UrlIsByteForByteTheWebApps() throws {
        XCTAssertEqual(toBase64Url("Vandersteg järn — åäö & spår/plus+slash"), ShareRef.b64)
        XCTAssertEqual(try fromBase64Url(ShareRef.b64), "Vandersteg järn — åäö & spår/plus+slash")
    }

    func testLzwIsByteForByteTheWebApps() throws {
        for (s, zipped) in ShareRef.lzwSmall {
            XCTAssertEqual(bytesToBase64Url(lzwCompress(utf8(s))), zipped, "compressing \(s)")
            XCTAssertEqual(text(try lzwDecompress(try base64UrlToBytes(zipped))), s, "reading the web app's \(s)")
        }
        XCTAssertEqual(lzwCompress([]), [])
        XCTAssertEqual(try lzwDecompress([]), [])
    }

    func testLzwMatchesTheWebAppAcrossEveryWidthAndWithAFullDictionary() throws {
        // The last text (400 000 characters) takes all 65 536 codes, after which the
        // encoder stops learning — a branch no name and no single trip ever reaches.
        var rnd = JSRandom()
        for ref in ShareRef.lzwRandom {
            var s: [UInt8] = []
            s.reserveCapacity(ref.len)
            for _ in 0..<ref.len { s.append(alphabet[Int((rnd.next() * Double(alphabet.count)).rounded(.down))]) }
            XCTAssertEqual(fnv(s), ref.textHash, "the same text as the JS made, at \(ref.len)")
            let z = lzwCompress(s)
            XCTAssertEqual(z.count, ref.zipBytes, "compressed size at \(ref.len)")
            XCTAssertEqual(fnv(z), ref.zipHash, "compressed bytes at \(ref.len)")
            XCTAssertEqual(try lzwDecompress(z), s, "round trip at \(ref.len)")
        }
    }

    func testNumbersAreWrittenAsJSONStringifyWritesThem() {
        let numbers: [Double] = [620, 0.5, 1e21, 1e-7, 1.5e-7, 0.000001, 0.00001, 1.2345678901234568e20, 58.41,
                                 0.30000000000000004, -2.5, 1e300, 5e-324, 100, -0.0, 12345.678]
        XCTAssertEqual(numbers.map { OrderedJSON.number($0).text() }, ShareRef.numbers)
        XCTAssertEqual(OrderedJSON.number(.nan).text(), "null")
        XCTAssertEqual(OrderedJSON.number(-.infinity).text(), "null")
    }

    func testStringsAreEscapedAsJSONStringifyEscapesThem() {
        // A slash, quotes, a backslash, control characters, DEL, U+2028, accents, an emoji.
        let nasty: [String] = ["a/b", "q\"uo\\te", "\u{1}\u{1F}\u{8}\u{C}\n\r\t", "\u{7F}\u{2028} åäö 😀"]
        XCTAssertEqual(OrderedJSON.array(nasty.map { .string($0) }).text(), ShareRef.strings)
        // Half an emoji — what `slice` leaves when it cuts through one — is written as JS writes it.
        XCTAssertEqual(OrderedJSON.js(Array("ab😀".utf16.prefix(3))).text(), "\"ab\\ud83d\"")
        XCTAssertEqual(OrderedJSON.js(Array("ab😀".utf16)), .string("ab😀"))
    }

    func testOrderedJSONKeepsItsOrderPrettyOrNot() {
        let v = OrderedJSON.object([
            .init("z", .number(1)), .init("a", .array([.bool(true), .null, .object([])])),
            .init("m", .object([.init("k", .string("v"))])), .init("e", .array([])),
        ])
        XCTAssertEqual(v.text(), "{\"z\":1,\"a\":[true,null,{}],\"m\":{\"k\":\"v\"},\"e\":[]}")
        XCTAssertEqual(v.text(pretty: true), """
        {
          "z": 1,
          "a": [
            true,
            null,
            {}
          ],
          "m": {
            "k": "v"
          },
          "e": []
        }
        """)
        XCTAssertEqual(v["m"]?["k"]?.stringValue, "v")
        XCTAssertEqual(v.value, ["z": 1, "a": [true, nil, [:]], "m": ["k": "v"], "e": []])
        // Sorted = UTF-16 code-unit order, at every level.
        XCTAssertEqual(OrderedJSON(sorted: ["b": ["y": 1, "x": 2], "a": 1, "B": 0, "10": 0, "9": 0]).text(),
                       "{\"10\":0,\"9\":0,\"B\":0,\"a\":1,\"b\":{\"x\":2,\"y\":1}}")
    }

    func testAtobIsForgivingAndDamageThrows() throws {
        XCTAssertEqual(try fromBase64Url("YQ"), "a")
        XCTAssertEqual(try fromBase64Url("YQ=="), "a")
        XCTAssertEqual(try fromBase64Url(" Y Q\n"), "a", "ASCII whitespace is ignored")
        XCTAssertEqual(try fromBase64Url("YR"), "a", "left-over bits are thrown away")
        XCTAssertEqual(try fromBase64Url(""), "")
        XCTAssertThrowsError(try fromBase64Url("z"), "one character is never base64")
        XCTAssertThrowsError(try fromBase64Url("Y=Q"))
        XCTAssertThrowsError(try fromBase64Url("_w"), "0xFF is not UTF-8 — JS throws a URIError")
        XCTAssertThrowsError(try fromBase64Url("YQ€"))
        XCTAssertEqual(try base64UrlToBytes("_w"), [0xFF], "bytes are bytes")
        XCTAssertEqual(try base64UrlToBytes(nil), [])
        XCTAssertThrowsError(try base64UrlToBytes("a"))
        XCTAssertEqual(jsBtoa([0x61]), "YQ==")
        XCTAssertEqual(jsBtoa([0xFB, 0xFF]), "+/8=")
        XCTAssertEqual(bytesToBase64Url([0xFB, 0xFF]), "-_8")
    }

    func testUnpackShareDamagedCodes() throws {
        XCTAssertThrowsError(try unpackShare("z.")) { XCTAssertEqual($0 as? ShareError, .damaged) }
        XCTAssertThrowsError(try unpackShare("z.!!!!"))
        // A first code that is not a byte: nothing in the dictionary yet.
        XCTAssertThrowsError(try lzwDecompress([0xFF, 0xFF])) { XCTAssertEqual(($0 as? ShareError)?.message, "This code is damaged.") }
        // A later code that skips ahead of the dictionary.
        XCTAssertThrowsError(try lzwDecompress([0x30, 0xFF, 0xFF]))
        XCTAssertEqual(try unpackShare(nil), "")
        XCTAssertEqual(try unpackShare("  " + packShare("plain") + "...\n"), "plain")
        // TextDecoder: a byte-order mark is swallowed, broken UTF-8 becomes U+FFFD.
        XCTAssertEqual(try unpackShare("z." + bytesToBase64Url(lzwCompress([0xEF, 0xBB, 0xBF, 0x61]))), "a")
        XCTAssertEqual(try unpackShare("z." + bytesToBase64Url(lzwCompress([0x61, 0xFF]))), "a\u{FFFD}")
        XCTAssertEqual(packShare(nil), "")
    }

    func testShareSafeOwnerIsTheWebApps() {
        for (given, safe) in ShareRef.safeOwner { XCTAssertEqual(shareSafeOwner(given), safe, "shareSafeOwner(\(given))") }
        XCTAssertEqual(shareSafeOwner("Anna Berg", max: 4), "Anna")
        XCTAssertEqual(shareSafeOwner(nil), "")
        XCTAssertEqual(SYNC_RESERVED_KEYS, ["owner", "realmId"])
        XCTAssertEqual(Set(SYNC_RESERVED_KEYS), RESERVED_SYNC_KEYS, "the foundation's set holds the same two keys")
    }

    func testHalfAnEmojiFromJSIsReadNotRefused() throws {
        // `JSON.parse` takes a lone `\ud83d`; Foundation does not. A whole pair is left alone.
        let v = try shareParseJSON("{\"n\":\"Swim \\ud83c\",\"whole\":\"\\ud83d\\ude00\",\"slash\":\"a\\\\ud83d\"}")
        XCTAssertEqual(v["n"]?.stringValue, "Swim ", "the half is dropped — the jsSlice rule")
        XCTAssertEqual(v["whole"]?.stringValue, "😀")
        XCTAssertEqual(v["slash"]?.stringValue, "a\\ud83d", "an escaped backslash is not an escape")
        // Numbers stay numbers and booleans stay booleans (decodeListShare tests `t === 1`).
        let w = try shareParseJSON("{\"t\":1,\"b\":true}")
        XCTAssertEqual(w["t"], .number(1))
        XCTAssertEqual(w["b"], .bool(true))
    }

    func testSharePayloadFindsTheCodeInsideALink() {
        XCTAssertEqual(sharePayload(in: "see https://example.invalid/#/g/abc-_.9. thanks", marker: "#/g/"), "abc-_.9.")
        XCTAssertEqual(sharePayload(in: "#/g/ #/g/second", marker: "#/g/"), "second", "a marker with no code after it is stepped over")
        XCTAssertNil(sharePayload(in: "#/l/abc", marker: "#/g/"))
        XCTAssertNil(sharePayload(in: "#/g/", marker: "#/g/"))
    }
}

// Every JS test of this section is ported above.
