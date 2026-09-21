import XCTest
@testable import PackingCore

// The JS has no tests for these — in JS they are the language itself. Here they are
// code, so each one is pinned to what Node actually answers.
final class JSSemanticsTests: XCTestCase {
    override func tearDown() { PackingEnv.reset(); super.tearDown() }

    func testJsSliceCountsUTF16UnitsAndTakesNegativeIndices() {
        XCTAssertEqual(jsSlice("hello", 0, 3), "hel")
        XCTAssertEqual(jsSlice("hello", 2), "llo")
        XCTAssertEqual(jsSlice("hello", -3), "llo")
        XCTAssertEqual(jsSlice("hello", 0, -1), "hell")
        XCTAssertEqual(jsSlice("hello", 3, 1), "")
        XCTAssertEqual(jsSlice("hello", 0, 99), "hello")
        // "🔌" is ONE Character but TWO UTF-16 units: 'a🔌b'.slice(0, 3) === 'a🔌'
        XCTAssertEqual(jsSlice("a🔌b", 0, 3), "a🔌")
        XCTAssertEqual(jsLength("a🔌b"), 4)
        // A cut through the middle of a pair: JS keeps half a character, which a Swift
        // String cannot hold — the broken half is dropped.
        XCTAssertEqual(jsSlice("a🔌b", 0, 2), "a")
        XCTAssertEqual(jsSlice("a🔌b", 2), "b")
    }

    func testJsTrimUsesTheJSWhitespaceSet() {
        XCTAssertEqual(jsTrim("  a b \n\t"), "a b")
        XCTAssertEqual(jsTrim("\u{FEFF}\u{00A0}x\u{2003}"), "x")   // BOM, NBSP and EM SPACE are whitespace in JS
        XCTAssertEqual(jsTrim("\u{0085}x"), "\u{0085}x")           // NEXT LINE is NOT
        XCTAssertEqual(jsTrim(""), "")
    }

    func testNormNameTrimsLowercasesAndCollapses() {
        XCTAssertEqual(normName("  Rain   Jacket "), "rain jacket")
        XCTAssertEqual(normName("BREATH\t\n work"), "breath work")
        XCTAssertEqual(normName("Våtdräkt"), "våtdräkt")
        XCTAssertEqual(normName(nil), "")
    }

    func testIsYMD() {
        XCTAssertTrue(isYMD("2026-01-15"))
        XCTAssertTrue(isYMD("2026-99-99"))          // the shape only, as in JS
        XCTAssertFalse(isYMD("2026-1-15"))
        XCTAssertFalse(isYMD("2026-01-15T00:00:00Z"))
        XCTAssertFalse(isYMD("2026-01-15\n"))
        XCTAssertFalse(isYMD("２０２６-01-15"))       // \d is ASCII only
        XCTAssertFalse(isYMD(""))
        XCTAssertFalse(isYMD(nil as String?))
    }

    func testTodayYMDAndNowISOGoThroughTheInjectedClock() {
        PackingEnv.freeze(at: "2026-08-20T12:34:56.789Z")
        XCTAssertEqual(nowISO(), "2026-08-20T12:34:56.789Z")
        XCTAssertEqual(todayYMD(), "2026-08-20")
        XCTAssertEqual(todayYMD("2027-02-03T23:59:59.000Z"), "2027-02-03")
        XCTAssertEqual(todayYMD(""), "2026-08-20")            // '' is falsy → now
    }

    func testJsISOStringMatchesToISOString() {
        XCTAssertEqual(jsISOString(Date(timeIntervalSince1970: 0)), "1970-01-01T00:00:00.000Z")
        XCTAssertEqual(jsISOString(Date(timeIntervalSince1970: 951_782_400)), "2000-02-29T00:00:00.000Z")   // leap day
        XCTAssertEqual(jsISOString(Date(timeIntervalSince1970: -1)), "1969-12-31T23:59:59.000Z")
        XCTAssertEqual(jsISOString(Date(timeIntervalSince1970: 1_787_227_200.5)), "2026-08-20T12:00:00.500Z")
    }

    func testIdHasTheJSShapeAndCanBeInjected() {
        let a = id(), b = id()
        XCTAssertNotEqual(a, b)
        let parts = a.split(separator: "-")
        XCTAssertEqual(parts.count, 3)                          // time-seq-random, all base 36
        XCTAssertEqual(parts[2].count, 6)
        XCTAssertTrue(a.allSatisfy { $0 == "-" || $0.isNumber || ($0.isLetter && $0.isLowercase) })
        PackingEnv.freeze()
        XCTAssertEqual(id(), "id-1")
        XCTAssertEqual(id(), "id-2")
        XCTAssertEqual(newItem(name: "Socks").id, "id-3")
    }

    func testJsRoundRoundsAHalfUp() {
        XCTAssertEqual(jsRound(2.5), 3)
        XCTAssertEqual(jsRound(-2.5), -2)      // Swift's .rounded() says -3
        XCTAssertEqual(jsRound(0.5), 1)
        XCTAssertEqual(jsRound(-0.5), 0)
        XCTAssertEqual(jsRound(1.4), 1)
        XCTAssertEqual(jsRound(0.49999999999999994), 0)
        XCTAssertEqual(jsRoundInt(90.7), 91)
        XCTAssertEqual(jsFloorInt(90.7), 90)
        XCTAssertEqual(jsFloorInt(.infinity), 0)   // never traps
    }

    func testStableSortedKeepsTiesInTheirOriginalOrder() {
        let rows = [("b", 1), ("a", 1), ("c", 0), ("d", 1)]
        XCTAssertEqual(rows.stableSorted(by: { $0.1 < $1.1 }).map { $0.0 }, ["c", "b", "a", "d"])
        XCTAssertEqual(rows.stableSorted(compare: { $0.1 - $1.1 }).map { $0.0 }, ["c", "b", "a", "d"])
        // A thousand ties: the order must come back untouched.
        let many = (0..<1000).map { ($0, 7) }
        XCTAssertEqual(many.stableSorted(compare: { $0.1 - $1.1 }).map { $0.0 }, Array(0..<1000))
        XCTAssertEqual(jsOr(0, 5), 5)
        XCTAssertEqual(jsOr(-1, 5), -1)
        XCTAssertEqual(jsSign(.nan), 0)
    }

    // Every row is what Node 25 (en-US) answers for `a.localeCompare(b)` and for
    // `a.localeCompare(b, undefined, { sensitivity: 'base' })`.
    func testJsLocaleCompareMatchesNode() {
        let rows: [(String, String, Int, Int)] = [
            ("a", "B", -1, -1), ("a", "A", -1, 0), ("A", "a", 1, 0), ("Å", "Z", -1, -1), ("ä", "z", -1, -1),
            ("co-op", "coop", -1, -1), ("10", "9", -1, -1), ("a b", "ab", -1, -1), ("a", "á", -1, 0),
            ("résumé", "resume", 1, 0), ("Zebra", "apple", 1, 1), ("_x", "x", -1, -1),
            ("alpha", "zulu", -1, -1), ("worn-2", "worn", 1, 1), ("", "", 0, 0), ("", "a", -1, -1),
            ("ö", "o", 1, 0), ("Ö", "p", -1, -1), ("é", "f", -1, -1), ("-a", "a", -1, -1),
            ("a1", "a10", -1, -1), ("a2", "a10", 1, 1),
        ]
        for (a, b, variant, base) in rows {
            XCTAssertEqual(jsLocaleCompare(a, b), variant, "\(a) vs \(b)")
            XCTAssertEqual(jsLocaleCompare(a, b, sensitivity: .base), base, "\(a) vs \(b) (base)")
        }
    }

    func testJsStringLessComparesUTF16Units() {
        XCTAssertTrue(jsStringLess("0-2026-01-01", "1-03"))
        XCTAssertTrue(jsStringLess("1-03", "9"))
        XCTAssertTrue(jsStringLess("Z", "a"))          // by code unit, NOT by alphabet
        XCTAssertFalse(jsStringLess("a", "a"))
    }

    func testJsNumberParsing() {
        XCTAssertEqual(jsParseNumber(" 12 "), 12)
        XCTAssertEqual(jsParseNumber(""), 0)
        XCTAssertEqual(jsParseNumber("-0.12"), -0.12)
        XCTAssertEqual(jsParseNumber("1e3"), 1000)
        XCTAssertEqual(jsParseNumber("0x10"), 16)
        XCTAssertTrue(jsParseNumber("12px").isNaN)
        XCTAssertTrue(jsParseNumber("nan").isNaN)      // Swift's Double("nan") would accept it
        XCTAssertTrue(jsParseNumber("soon").isNaN)
        XCTAssertEqual(jsNumberToString(2), "2")
        XCTAssertEqual(jsNumberToString(2.5), "2.5")
        XCTAssertEqual(jsNumberToString(-0.0), "0")
    }

    func testHexColorAndSlug() {
        XCTAssertTrue(isHexColor("#3b82f6"))
        XCTAssertTrue(isHexColor("#FFF"))
        XCTAssertTrue(isHexColor("#12345678"))
        XCTAssertFalse(isHexColor("blue"))
        XCTAssertFalse(isHexColor("#12"))
        XCTAssertFalse(isHexColor("#123456789"))
        XCTAssertFalse(isHexColor("#ggg"))
        XCTAssertEqual(jsSlug("  Load the car! "), "load-the-car")
        XCTAssertEqual(jsSlug("!!!"), "")
        XCTAssertEqual(jsSlug("Åka båt"), "ka-b-t")     // only a–z and 0–9 survive, as in the JS regex
    }

    // MARK: JSONValue

    func testJSONValueTruthinessNumberAndString() {
        XCTAssertFalse(JSONValue.string("").truthy)
        XCTAssertTrue(JSONValue.string("0").truthy)
        XCTAssertFalse(JSONValue.number(0).truthy)
        XCTAssertFalse(JSONValue.null.truthy)
        XCTAssertTrue(JSONValue.array([]).truthy)       // [] and {} are TRUE in JS
        XCTAssertTrue(JSONValue.object([:]).truthy)
        XCTAssertEqual(JSONValue.null.jsNumber, 0)      // Number(null) is 0 …
        XCTAssertTrue(jsNumber(nil).isNaN)              // … but Number(undefined) is NaN
        XCTAssertEqual(JSONValue.string("51.5").jsNumber, 51.5)
        XCTAssertEqual(JSONValue.bool(true).jsNumber, 1)
        XCTAssertEqual(JSONValue.number(42).jsString, "42")
        XCTAssertEqual(JSONValue.object([:]).jsString, "[object Object]")
        XCTAssertEqual(jsStringOrEmpty(.number(0)), "")
        XCTAssertEqual(jsStringOrEmpty(.number(7)), "7")
        XCTAssertNil(JSONValue.string("5").finiteNumber)   // Number.isFinite does not coerce
    }

    func testJSONValueRoundTripsThroughCodable() throws {
        let v: JSONValue = ["a": 1, "b": [true, nil, "x", 2.5], "c": ["d": "é🔌"]]
        let back = try JSONValue.parse(v.text())
        XCTAssertEqual(back, v)
        XCTAssertEqual(v.text(), #"{"a":1,"b":[true,null,"x",2.5],"c":{"d":"é🔌"}}"#)   // whole numbers have no ".0"
        XCTAssertEqual(JSONValue.number(.nan).text(), "null")                            // as JSON.stringify
        XCTAssertEqual(v["b"]?[3]?.numberValue, 2.5)
        XCTAssertNil(v["nope"])
    }
}
