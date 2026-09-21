// JSONValue — free-form JSON, and the bridge every model type decodes through.
//
// WHY IT EXISTS. The web app's data is plain JavaScript objects, and its `coerceX`
// functions decide what a wrong or missing value turns into. To give the same
// answers, every model type here is built from a JSONValue by exactly those rules
// (`Item(json:)`, `PackList(json:)`…), and `Decodable` simply goes through that.
// It is also the type for anything not worth typing (a preset's `config`, `prefs`).

import Foundation

public enum JSONValue: Equatable, Hashable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])
}

// MARK: - Literals (so tests can be written the way the JS tests are)

extension JSONValue: ExpressibleByNilLiteral, ExpressibleByBooleanLiteral,
    ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral, ExpressibleByStringLiteral,
    ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral {
    public init(nilLiteral: ()) { self = .null }
    public init(booleanLiteral value: Bool) { self = .bool(value) }
    public init(integerLiteral value: Int) { self = .number(Double(value)) }
    public init(floatLiteral value: Double) { self = .number(value) }
    public init(stringLiteral value: String) { self = .string(value) }
    public init(arrayLiteral elements: JSONValue...) { self = .array(elements) }
    public init(dictionaryLiteral elements: (String, JSONValue)...) {
        var o: [String: JSONValue] = [:]
        for (k, v) in elements { o[k] = v }   // a repeated key: the last one wins, as in JS
        self = .object(o)
    }
}

// MARK: - Convenience constructors

extension JSONValue {
    public init(_ value: String) { self = .string(value) }
    public init(_ value: Bool) { self = .bool(value) }
    public init(_ value: Double) { self = .number(value) }
    public init(_ value: Int) { self = .number(Double(value)) }
    public init(_ value: [String]) { self = .array(value.map { .string($0) }) }
    public init(_ value: [JSONValue]) { self = .array(value) }
    public init(_ value: [String: JSONValue]) { self = .object(value) }
    /// nil → `.null`
    public init(_ value: String?) { self = value.map { .string($0) } ?? .null }
    public init(_ value: Double?) { self = value.map { .number($0) } ?? .null }
}

// MARK: - Strict accessors (typeof checks — NO coercion)

extension JSONValue {
    public var isNull: Bool { if case .null = self { return true }; return false }
    /// `typeof v === 'string'`
    public var stringValue: String? { if case .string(let s) = self { return s }; return nil }
    /// `typeof v === 'number'` (may be non-finite only if built in memory; JSON has no NaN)
    public var numberValue: Double? { if case .number(let n) = self { return n }; return nil }
    /// `typeof v === 'boolean'`
    public var boolValue: Bool? { if case .bool(let b) = self { return b }; return nil }
    /// `Array.isArray(v)`
    public var arrayValue: [JSONValue]? { if case .array(let a) = self { return a }; return nil }
    /// A plain object (NOT an array, NOT null).
    public var objectValue: [String: JSONValue]? { if case .object(let o) = self { return o }; return nil }
    /// `Number.isFinite(v)` — a real number, no coercion from strings.
    public var finiteNumber: Double? {
        if case .number(let n) = self, n.isFinite { return n }
        return nil
    }

    /// `obj[key]` — nil stands for JS `undefined` (also when `self` is not an object).
    public subscript(key: String) -> JSONValue? {
        get { objectValue?[key] }
        set {
            guard case .object(var o) = self else { return }
            o[key] = newValue
            self = .object(o)
        }
    }
    /// `arr[i]` — nil when out of range or not an array.
    public subscript(index: Int) -> JSONValue? {
        guard case .array(let a) = self, a.indices.contains(index) else { return nil }
        return a[index]
    }
}

// MARK: - JavaScript coercions

extension JSONValue {
    /// `!!v` — '' / 0 / NaN / null are false; every object and array is TRUE, even empty.
    public var truthy: Bool {
        switch self {
        case .null: return false
        case .bool(let b): return b
        case .number(let n): return !(n == 0 || n.isNaN)
        case .string(let s): return !s.isEmpty
        case .array, .object: return true
        }
    }

    /// `Number(v)` — NaN when it cannot be read as a number. Note `Number(null)` is 0
    /// and `Number('')` is 0, while `Number(undefined)` is NaN (see `jsNumber(_:)`).
    public var jsNumber: Double {
        switch self {
        case .null: return 0
        case .bool(let b): return b ? 1 : 0
        case .number(let n): return n
        case .string(let s): return jsParseNumber(s)
        case .array(let a):
            // Number([]) is 0, Number([x]) is Number(String(x)); anything longer is NaN.
            if a.isEmpty { return 0 }
            if a.count == 1 { return jsParseNumber(a[0].jsString) }
            return .nan
        case .object: return .nan
        }
    }

    /// `String(v)`.
    public var jsString: String {
        switch self {
        case .null: return "null"
        case .bool(let b): return b ? "true" : "false"
        case .number(let n): return jsNumberToString(n)
        case .string(let s): return s
        case .array(let a): return a.map { $0.isNull ? "" : $0.jsString }.joined(separator: ",")
        case .object: return "[object Object]"
        }
    }
}

/// `Number(v)` where `v` may be `undefined` (nil) — which is NaN, unlike null.
public func jsNumber(_ v: JSONValue?) -> Double { v?.jsNumber ?? .nan }
/// `!!v` where `v` may be `undefined`.
public func jsTruthy(_ v: JSONValue?) -> Bool { v?.truthy ?? false }
/// `asArray(v)` — the array, or [] for anything that is not one.
public func asArray(_ v: JSONValue?) -> [JSONValue] { v?.arrayValue ?? [] }
/// `typeof v === 'string' ? v : fallback`
public func jsStringOr(_ v: JSONValue?, _ fallback: String = "") -> String { v?.stringValue ?? fallback }
/// `String(v || '')` — a falsy value (undefined, null, 0, '', false) reads as ''.
public func jsStringOrEmpty(_ v: JSONValue?) -> String {
    guard let v = v, v.truthy else { return "" }
    return v.jsString
}
/// `String(v ?? '')` — only undefined and null read as ''.
public func jsStringNullish(_ v: JSONValue?) -> String {
    guard let v = v, !v.isNull else { return "" }
    return v.jsString
}
/// An array that the JS never filters by type (`asArray(it.seasons)`), read into
/// `[String]`. A non-string element is kept as `String(v)` rather than dropped, so an
/// array of junk still counts as "has a constraint" exactly as it does in JS.
public func asStringArray(_ v: JSONValue?) -> [String] { asArray(v).map { $0.jsString } }

// MARK: - Codable

extension JSONValue: Codable {
    public init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer() {
            if single.decodeNil() { self = .null; return }
            if let b = try? single.decode(Bool.self) { self = .bool(b); return }
            if let n = try? single.decode(Double.self) { self = .number(n); return }
            if let s = try? single.decode(String.self) { self = .string(s); return }
        }
        if var list = try? decoder.unkeyedContainer() {
            var out: [JSONValue] = []
            if let n = list.count { out.reserveCapacity(n) }
            while !list.isAtEnd { out.append(try list.decode(JSONValue.self)) }
            self = .array(out)
            return
        }
        let keyed = try decoder.container(keyedBy: JSONKey.self)
        var out: [String: JSONValue] = [:]
        for k in keyed.allKeys { out[k.stringValue] = try keyed.decode(JSONValue.self, forKey: k) }
        self = .object(out)
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .null:
            var c = encoder.singleValueContainer(); try c.encodeNil()
        case .bool(let b):
            var c = encoder.singleValueContainer(); try c.encode(b)
        case .number(let n):
            var c = encoder.singleValueContainer()
            // JSON.stringify: NaN and ±Infinity become null; a whole number has no ".0".
            if !n.isFinite { try c.encodeNil() }
            else if n == n.rounded(), abs(n) < 9_007_199_254_740_992 { try c.encode(Int64(n)) }
            else { try c.encode(n) }
        case .string(let s):
            var c = encoder.singleValueContainer(); try c.encode(s)
        case .array(let a):
            var c = encoder.unkeyedContainer()
            for v in a { try c.encode(v) }
        case .object(let o):
            var c = encoder.container(keyedBy: JSONKey.self)
            for (k, v) in o { try c.encode(v, forKey: JSONKey(k)) }
        }
    }

    /// `JSON.parse` — JSON text or bytes. Throws on invalid JSON only.
    ///
    /// It reads what `JSON.parse` reads, INCLUDING half an emoji written as a lone
    /// `\ud83d` escape, which Foundation's parser refuses. A Swift String cannot hold
    /// the half, so it is dropped from the value (see "Reading JSON that JS wrote" below).
    public static func parse(_ data: Data) throws -> JSONValue { try parse(data, keepParked: false) }
    public static func parse(_ text: String) throws -> JSONValue { try parse(Data(text.utf8), keepParked: false) }

    /// With `keepParked`, each lone half stays in the value as its private-use stand-in
    /// (`jsonUnparkedUnits` turns a string back into UTF-16 units) — for the one caller
    /// that can put two halves back together: `subName`, reading an old trip bundle.
    static func parse(_ text: String, keepParked: Bool) throws -> JSONValue {
        try parse(Data(text.utf8), keepParked: keepParked)
    }
    static func parse(_ data: Data, keepParked: Bool) throws -> JSONValue {
        guard jsonMayHoldSurrogateEscape(data) else { return try JSONDecoder().decode(JSONValue.self, from: data) }
        let text = String(decoding: data, as: UTF8.self)
        let parked = jsonParkLoneSurrogates(text)
        let v = try JSONDecoder().decode(JSONValue.self, from: Data(parked.utf8))
        return (keepParked || parked == text) ? v : jsonDropParked(v)
    }

    /// JSON text. Keys are sorted so the same value always gives the same text.
    public func text(pretty: Bool = false) -> String {
        let enc = JSONEncoder()
        enc.outputFormatting = pretty ? [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
                                      : [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? enc.encode(self) else { return "null" }
        return String(decoding: data, as: UTF8.self)
    }
}

struct JSONKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init(_ s: String) { stringValue = s }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}

// MARK: - Reading JSON that JS wrote

/// Is there a `\ud…` / `\uD…` escape anywhere? (Only then can the text hold a lone
/// surrogate; a whole backup file is scanned once, as bytes, and parsed as it is.)
private func jsonMayHoldSurrogateEscape(_ data: Data) -> Bool {
    var prev2: UInt8 = 0, prev1: UInt8 = 0
    for b in data {
        if prev2 == 0x5C, prev1 == 0x75, b == 0x64 || b == 0x44 { return true }
        prev2 = prev1; prev1 = b
    }
    return false
}

// Half an emoji, written `\ud83d`, is legal to `JSON.parse` and an error to
// Foundation. It arrives two ways: a name cut through the middle of an emoji by
// `slice`, and — far more often — the sub-items of a trip shared by a web app from
// before v186, which spelled them out one UTF-16 unit at a time (see `subName`).
// Each lone half is parked on a private-use code point on the way in, so the text
// parses; `subName` (TripSharing.swift) puts the two halves of a sub-item's emoji back
// together, and everywhere else the half is dropped — the rule `jsSlice` set: a Swift
// String cannot hold half a character.
private let jsonLoneBase: UInt32 = 0xF0000   // U+F0000…U+F07FF stand for U+D800…U+DFFF

func jsonParkLoneSurrogates(_ text: String) -> String {
    guard text.contains("\\ud") || text.contains("\\uD") else { return text }
    let u = Array(text.utf16)
    var out: [UInt16] = []
    out.reserveCapacity(u.count)
    func escape(at i: Int) -> UInt32? {       // the value of a `\uXXXX` starting at i
        guard i + 5 < u.count, u[i] == 0x5C, u[i + 1] == 0x75 else { return nil }
        var v: UInt32 = 0
        for j in (i + 2)...(i + 5) {
            guard let s = Unicode.Scalar(UInt32(u[j])), let h = Character(s).hexDigitValue, u[j] < 0x80 else { return nil }
            v = v * 16 + UInt32(h)
        }
        return v
    }
    func park(_ v: UInt32) {
        if let s = Unicode.Scalar(jsonLoneBase + (v - 0xD800)) { out.append(contentsOf: Array(String(s).utf16)) }
    }
    var i = 0
    while i < u.count {
        guard u[i] == 0x5C else { out.append(u[i]); i += 1; continue }
        if let v = escape(at: i) {
            if (0xD800...0xDBFF).contains(v) {
                if let w = escape(at: i + 6), (0xDC00...0xDFFF).contains(w) {
                    out.append(contentsOf: u[i..<(i + 12)]); i += 12          // a whole pair: leave it
                } else { park(v); i += 6 }
            } else if (0xDC00...0xDFFF).contains(v) {
                park(v); i += 6
            } else {
                out.append(contentsOf: u[i..<(i + 6)]); i += 6
            }
        } else {
            // Any other escape (`\\`, `\"`, `\n`…): copy both units, so an escaped
            // backslash is never mistaken for the start of the next escape.
            out.append(u[i]); i += 1
            if i < u.count { out.append(u[i]); i += 1 }
        }
    }
    return String(decoding: out, as: UTF16.self)
}

/// The UTF-16 units of a parsed string, parked halves turned back into surrogates.
func jsonUnparkedUnits(_ s: String) -> [UInt16] {
    var out: [UInt16] = []
    for sc in s.unicodeScalars {
        if sc.value >= jsonLoneBase && sc.value <= jsonLoneBase + 0x7FF {
            out.append(UInt16(0xD800 + (sc.value - jsonLoneBase)))
        } else {
            out.append(contentsOf: Array(String(sc).utf16))
        }
    }
    return out
}

private func jsonHasParked(_ s: String) -> Bool {
    s.unicodeScalars.contains { $0.value >= jsonLoneBase && $0.value <= jsonLoneBase + 0x7FF }
}

/// Every parked half dropped, all the way down.
func jsonDropParked(_ v: JSONValue) -> JSONValue {
    switch v {
    case .string(let s):
        return jsonHasParked(s) ? .string(shareStringDroppingLoneSurrogates(jsonUnparkedUnits(s))) : v
    case .array(let a): return .array(a.map { jsonDropParked($0) })
    case .object(let o):
        var out: [String: JSONValue] = [:]
        for (k, x) in o { out[k] = jsonDropParked(x) }
        return .object(out)
    default: return v
    }
}

// MARK: - The bridge every model type uses

/// A model type that is built from JSON by the web app's own coercion rules and
/// written back with the web app's own keys. `Codable` comes for free and NEVER
/// throws for a missing or mistyped field: decoding IS coercion.
public protocol JSONModel: Codable, Equatable {
    /// Build from anything at all. A non-object reads as `{}`.
    init(json: JSONValue)
    /// The same keys the web app's backup uses.
    var json: JSONValue { get }
}

extension JSONModel {
    public init(from decoder: Decoder) throws { self.init(json: try JSONValue(from: decoder)) }
    public func encode(to encoder: Encoder) throws { try json.encode(to: encoder) }
}

/// Keys the sync layer reserves on every synced row. The web app lost 422 item owners
/// to `owner`; they are never read (except the legacy rule in `coerceItem`), never
/// kept in `extra`, never written.
let RESERVED_SYNC_KEYS: Set<String> = ["owner", "realmId"]

/// Whatever an object carries beyond the keys a type knows — kept so a round trip
/// through this package never silently loses a field a later web version added.
func extraKeys(_ o: [String: JSONValue], known: Set<String>) -> [String: JSONValue] {
    var out: [String: JSONValue] = [:]
    for (k, v) in o where !known.contains(k) && !RESERVED_SYNC_KEYS.contains(k) { out[k] = v }
    return out
}
