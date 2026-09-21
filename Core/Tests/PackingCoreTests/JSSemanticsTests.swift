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

    // Caught by the parity checker on the invented backup: an owner typed once with a space
    // and once with a pasted NO-BREAK space. ICU orders the two (the plain one first);
    // Foundation called it a tie. Every row is what Node (en-US) answers.
    func testJsLocaleCompareOrdersAPlainCharacterBeforeItsCompatibilityVariant() {
        let rows: [(String, String, Int)] = [
            ("Blake B", "Blake\u{00A0}B", -1),       // space · no-break space
            ("a b", "a\u{2009}b", -1),               // space · thin space
            ("co-op", "co\u{2011}op", -1),           // hyphen · non-breaking hyphen
            ("abc", "\u{FF41}\u{FF42}\u{FF43}", -1), // full-width letters
            ("m2", "m\u{00B2}", -1),                 // superscript two
            ("12", "\u{0661}\u{0662}", 0),           // another script's digits: a tie in ICU too
            ("softhyphen", "soft\u{00AD}hyphen", 0), // ICU ignores a soft hyphen completely
            ("Blake\u{00A0}B", "Blake C", -1),       // and a real difference still decides first
        ]
        for (a, b, want) in rows {
            XCTAssertEqual(jsLocaleCompare(a, b), want, "\(a) vs \(b)")
            XCTAssertEqual(jsLocaleCompare(b, a), -want, "\(b) vs \(a)")
        }
        XCTAssertEqual(["Blake\u{00A0}B", "Blake B"].stableSorted(compare: { jsLocaleCompare($0, $1) }), ["Blake B", "Blake\u{00A0}B"])
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

    // Found by the parity checker's review of the foundation: the first writer laid small
    // numbers out the C way ("1e-05"), where JS writes "0.00001". ONE writer now serves
    // `String(n)`, `JSON.stringify` and the share codes; every line is what Node answers.
    func testJsNumberToStringIsNumberPrototypeToString() {
        XCTAssertEqual(jsNumberToString(0.00001), "0.00001")          // was "1e-05"
        XCTAssertEqual(jsNumberToString(0.000001), "0.000001")        // the last plain decimal
        XCTAssertEqual(jsNumberToString(1e-7), "1e-7")                // below 1e-6: exponent, no padding
        XCTAssertEqual(jsNumberToString(1.5e-7), "1.5e-7")            // was "1.5e-07"
        XCTAssertEqual(jsNumberToString(-1e-7), "-1e-7")
        XCTAssertEqual(jsNumberToString(0.000123), "0.000123")
        XCTAssertEqual(jsNumberToString(5e-324), "5e-324")
        XCTAssertEqual(jsNumberToString(100), "100")
        XCTAssertEqual(jsNumberToString(-2.5), "-2.5")
        XCTAssertEqual(jsNumberToString(4.35), "4.35")
        XCTAssertEqual(jsNumberToString(123456.789), "123456.789")
        XCTAssertEqual(jsNumberToString(0.1 + 0.2), "0.30000000000000004")
        XCTAssertEqual(jsNumberToString(1e20), "100000000000000000000")
        XCTAssertEqual(jsNumberToString(1.2345678901234568e20), "123456789012345680000")
        XCTAssertEqual(jsNumberToString(1.2345678901234567e19), "12345678901234567000")   // shortest digits, then zeros
        XCTAssertEqual(jsNumberToString(1e21), "1e+21")               // from 1e21: exponent, with its plus sign
        XCTAssertEqual(jsNumberToString(1.5e300), "1.5e+300")
        XCTAssertEqual(jsNumberToString(1.7976931348623157e308), "1.7976931348623157e+308")
        XCTAssertEqual(jsNumberToString(.nan), "NaN")
        XCTAssertEqual(jsNumberToString(-.infinity), "-Infinity")
        // …and the same digits wherever a number becomes text:
        XCTAssertEqual(JSONValue.number(0.00001).jsString, "0.00001")                         // String(v)
        XCTAssertEqual(OrderedJSON(sorted: ["n": 0.00001, "big": 1e21]).text(), #"{"big":1e+21,"n":0.00001}"#)   // JSON.stringify
        XCTAssertEqual(OrderedJSON.number(.infinity).text(), "null")                          // JSON has no Infinity
    }

    // THE ONE date parser (`JSDay`): `Date.parse(`${s}T00:00:00Z`)` as Node/V8 reads it.
    // Care and the trip dates used to carry a copy each; both read through this one now.
    func testJSDayReadsADayTheWayV8Does() {
        XCTAssertEqual(JSDay.number("1970-01-01"), 0)
        XCTAssertEqual(JSDay.number("1969-12-31"), -1)
        XCTAssertEqual(JSDay.number("2024-02-29"), 19782)
        XCTAssertEqual(JSDay.number("0000-01-01"), -719528)
        // A day the month does not have ROLLS OVER (V8; Safari says NaN — contract N5).
        XCTAssertEqual(JSDay.number("2026-02-30"), JSDay.number("2026-03-02"))
        XCTAssertEqual(JSDay.number("2026-04-31"), 20574)
        XCTAssertEqual(JSDay.number("2025-02-29"), 20148)
        // The shorter ISO forms are dates too: the 1st.
        XCTAssertEqual(JSDay.number("2026"), 20454)
        XCTAssertEqual(JSDay.number("2026-07"), 20635)
        // A signed six-digit year — but never minus zero; and the ends of JS time.
        XCTAssertEqual(JSDay.number("+002026-07-30"), 20664)
        XCTAssertEqual(JSDay.number("-000001-01-01"), -719893)
        XCTAssertNil(JSDay.number("-000000-01-01"))
        XCTAssertEqual(JSDay.number("+275760-09-13"), 100_000_000)
        XCTAssertNil(JSDay.number("+275760-09-14"))
        // Everything else is NaN.
        for junk in ["", "2026-7-3", "2026-13-01", "2026-00-10", "2026-07-32", "2026-07-00", "2026-07-30 ",
                     "2026-07-30T10:00", "२०२६-०७-३०", "not-a-date"] {
            XCTAssertNil(JSDay.number(junk), junk)
        }
        XCTAssertEqual(JSDay.ymd(20514), "2026-03-02")
        XCTAssertEqual(JSDay.ymd(-1), "1969-12-31")
        XCTAssertEqual(JSDay.weekday(0), 4)                           // 1970-01-01 was a Thursday
        XCTAssertEqual(jsISOString(Date(timeIntervalSince1970: -86_400)), "1969-12-31T00:00:00.000Z")
    }

    // One parser means care and the trip dates cannot disagree about a day — on the
    // impossible day, the short forms and the ends of time alike.
    func testCareAndTripDatesReadTheSameDay() {
        XCTAssertEqual(addDays("2026-02-30", 0), "2026-03-02")
        XCTAssertEqual(daysBetween("2026-02-30", "2026-03-02"), 0)
        XCTAssertEqual(daysUntil("2026-02-30", "2026-03-02"), 0)
        XCTAssertEqual(nightsBetween("2026-02-28", "2026-02-30"), 2)
        XCTAssertEqual(endFromNights("2026-02-30", 1), "2026-03-03")
        XCTAssertEqual(monthKey("2026-02-30"), "2026-02")             // the text's own month, as in JS
        XCTAssertEqual(addDays("2026", 1), "2026-01-02")
        XCTAssertEqual(daysUntil("2026-07", "2026-06-30"), 1)
        // The trip functions cut the text at ten characters FIRST, so a six-digit year is
        // read as its short form `+275760-09` (the 1st) — the same in JS.
        XCTAssertEqual(daysUntil("+275760-09-14", "2026-01-01"), 99_979_534)
        XCTAssertEqual(nightsBetween("2026-01-01", "+275760-09-14"), 99_979_534)
        XCTAssertEqual(endFromNights("+275760-09-14", 1), "+275760-09")
        XCTAssertEqual(endFromNights("+275760-09-01", 40), "")        // past the end of JS time (JS throws a RangeError)
    }

    // `JSON.parse` accepts half an emoji written as a lone surrogate escape; Foundation's
    // parser throws on it. `JSONValue.parse` reads it and drops the half, as `jsSlice` does.
    // (The escapes are put together here so that no tool can "tidy" them into characters.)
    func testJSONValueParseReadsALoneSurrogateEscape() throws {
        let bs = "\\"
        let lead = bs + "ud83c", trail = bs + "udf0a", smileLead = bs + "ud83d", smileTrail = bs + "ude00"
        let text = "{\"n\":\"Swim \(lead)\",\"w\":\"\(smileLead)\(smileTrail)\",\"s\":\"a\(bs)\(bs)ud83d\","
            + "\"t\":\"\(trail)x\(lead)\",\"k\":[1,true]}"
        let v = try JSONValue.parse(text)
        XCTAssertEqual(v["n"], "Swim ")                               // the half is dropped
        XCTAssertEqual(v["w"], "😀")                                  // a whole pair is untouched
        XCTAssertEqual(v["s"], .string("a" + bs + "ud83d"))           // an escaped backslash is not an escape
        XCTAssertEqual(v["t"], "x")
        XCTAssertEqual(v["k"], [1, true])
        XCTAssertEqual(try JSONValue.parse(Data("[\"\(bs)uD83D\"]".utf8)), [""])       // bytes too, capital hex too
        XCTAssertThrowsError(try JSONValue.parse("{\"n\":\"Swim \(lead)\""))           // still throws on invalid JSON
        // A model type decoded from such text does not throw either.
        let item = coerceItem(json: try JSONValue.parse("{\"id\":\"i\",\"name\":\"Towel \(lead)\",\"sub\":[\"Peg \(trail)\"]}"))
        XCTAssertEqual(item?.name, "Towel ")
        XCTAssertEqual(item?.sub, ["Peg "])
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
