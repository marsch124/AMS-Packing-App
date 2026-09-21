// ShareEncoding — what every share code is made of: ordered JSON text, base64url,
// LZW, and `packShare` / `unpackShare` on top of them.
// Ported from js/model.js ("Trip sharing" → `toBase64Url`…, "Squeezing a share code").
//
// BYTE-EXACT ON PURPOSE. A code made by the web app has to open here and the other
// way round, and the parity checker compares the encoded STRINGS. Three things make
// that possible, and all three live in this file:
//   • `OrderedJSON` — JSON whose keys keep the order the JS code builds them in, written
//     exactly as `JSON.stringify` writes it (it never escapes `/`, and a whole number
//     has no ".0"). The package's `JSONValue` keeps its keys in a dictionary, and
//     `JSONEncoder` cannot be trusted on order or escaping, so this is written by hand.
//   • base64 as `btoa` / `atob` do it (forgiving on the way in, no padding on the way out).
//   • the LZW coder, bit for bit.

import Foundation

// MARK: - Errors

/// What JS throws as `new Error(message)`. The message is the one the web app shows.
public struct ShareError: Error, Equatable, LocalizedError, CustomStringConvertible, Sendable {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
    public var description: String { message }

    /// `lzwDecompress`'s own wording. Also used where JS throws an engine-made error
    /// with engine-made words (`atob`'s DOMException, `decodeURIComponent`'s URIError).
    public static let damaged = ShareError("This code is damaged.")
}

// MARK: - OrderedJSON

/// JSON with its keys IN ORDER — what `JSON.stringify` sees when it walks a JS object.
public enum OrderedJSON: Equatable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    /// A JS string that holds HALF an emoji (a lone surrogate) — which `slice(0, n)`
    /// leaves behind when the cut lands inside one, and which a Swift String cannot
    /// hold. `JSON.stringify` writes the half as `\ud83d`; so does `text()`.
    case units([UInt16])
    case array([OrderedJSON])
    case object([Member])

    public struct Member: Equatable, Sendable {
        public var key: String
        public var value: OrderedJSON
        public init(_ key: String, _ value: OrderedJSON) { self.key = key; self.value = value }
    }

    /// A JS string from its UTF-16 units: `.string` when they are well formed.
    public static func js(_ units: [UInt16]) -> OrderedJSON {
        shareHasLoneSurrogate(units) ? .units(units) : .string(String(decoding: units, as: UTF16.self))
    }

    /// Any JSON value, every object's keys in UTF-16 code-unit order (the parity
    /// contract's canonical text `CJ` is exactly `OrderedJSON(sorted: v).text()`).
    public init(sorted v: JSONValue) { self.init(v, order: nil) }

    /// `obj[key]` — nil when there is no such key, or `self` is not an object.
    public subscript(key: String) -> OrderedJSON? {
        guard case .object(let ms) = self else { return nil }
        return ms.last(where: { $0.key == key })?.value
    }
    public var stringValue: String? {
        switch self {
        case .string(let s): return s
        case .units(let u): return shareStringDroppingLoneSurrogates(u)
        default: return nil
        }
    }
    public var numberValue: Double? { if case .number(let n) = self { return n }; return nil }
    public var boolValue: Bool? { if case .bool(let b) = self { return b }; return nil }
    public var arrayValue: [OrderedJSON]? { if case .array(let a) = self { return a }; return nil }
    public var members: [Member]? { if case .object(let m) = self { return m }; return nil }

    /// The same value without the order. (Half an emoji is dropped, as `jsSlice` drops it.)
    public var value: JSONValue {
        switch self {
        case .null: return .null
        case .bool(let b): return .bool(b)
        case .number(let n): return .number(n)
        case .string(let s): return .string(s)
        case .units(let u): return .string(shareStringDroppingLoneSurrogates(u))
        case .array(let a): return .array(a.map { $0.value })
        case .object(let ms):
            var o: [String: JSONValue] = [:]
            for m in ms { o[m.key] = m.value.value }
            return .object(o)
        }
    }

    /// `JSON.stringify(v)`, or `JSON.stringify(v, null, 2)` when `pretty`.
    public func text(pretty: Bool = false) -> String {
        var out = ""
        write(to: &out, pretty: pretty, depth: 0)
        return out
    }

    private func write(to out: inout String, pretty: Bool, depth: Int) {
        func newline(_ d: Int) {
            guard pretty else { return }
            out.append("\n")
            out.append(String(repeating: "  ", count: d))
        }
        switch self {
        case .null: out.append("null")
        case .bool(let b): out.append(b ? "true" : "false")
        case .number(let n): out.append(shareNumberText(n))
        case .string(let s): shareAppendQuoted(s, to: &out)
        case .units(let u): shareAppendQuoted(units: u, to: &out)
        case .array(let a):
            if a.isEmpty { out.append("[]"); return }
            out.append("[")
            for (i, v) in a.enumerated() {
                if i > 0 { out.append(",") }
                newline(depth + 1)
                v.write(to: &out, pretty: pretty, depth: depth + 1)
            }
            newline(depth)
            out.append("]")
        case .object(let ms):
            if ms.isEmpty { out.append("{}"); return }
            out.append("{")
            for (i, m) in ms.enumerated() {
                if i > 0 { out.append(",") }
                newline(depth + 1)
                shareAppendQuoted(m.key, to: &out)
                out.append(pretty ? ": " : ":")
                m.value.write(to: &out, pretty: pretty, depth: depth + 1)
            }
            newline(depth)
            out.append("}")
        }
    }
}

/// The order a JS object of a known shape holds its keys in, and the shapes nested
/// inside it (a child order applies to an object value AND to each element of an
/// array value). Keys the order does not name follow in UTF-16 order.
struct ShareKeyOrder {
    var keys: [String]
    var children: [String: ShareKeyOrder] = [:]
}

extension OrderedJSON {
    init(_ v: JSONValue, order: ShareKeyOrder?) {
        switch v {
        case .null: self = .null
        case .bool(let b): self = .bool(b)
        case .number(let n): self = .number(n)
        case .string(let s): self = .string(s)
        case .array(let a): self = .array(a.map { OrderedJSON($0, order: order) })
        case .object(let o):
            self = .object(shareOrderedKeys(o, order: order).map { k in
                Member(k, OrderedJSON(o[k] ?? .null, order: order?.children[k]))
            })
        }
    }
}

/// The named keys first, in their order; then everything else in UTF-16 order.
func shareOrderedKeys(_ o: [String: JSONValue], order: ShareKeyOrder?) -> [String] {
    let named = (order?.keys ?? []).filter { o[$0] != nil }
    let namedSet = Set(named)
    let rest = o.keys.filter { !namedSet.contains($0) }.sorted { jsStringLess($0, $1) }
    return named + rest
}

// MARK: - JSON.stringify's strings and numbers

/// `"` → `\"`, `\` → `\\`, \b \f \n \r \t, any other unit below U+0020 → `\u00xx`
/// (lowercase hex). NOTHING else is escaped: not `/`, not U+007F, not U+2028, not
/// non-ASCII.
private func shareAppendEscaped(_ u: Unicode.Scalar, to out: inout String) {
    switch u.value {
    case 0x22: out.append("\\\"")
    case 0x5C: out.append("\\\\")
    case 0x08: out.append("\\b")
    case 0x0C: out.append("\\f")
    case 0x0A: out.append("\\n")
    case 0x0D: out.append("\\r")
    case 0x09: out.append("\\t")
    case 0..<0x20:
        let hex = String(u.value, radix: 16)
        out.append("\\u" + String(repeating: "0", count: 4 - hex.count) + hex)
    default:
        out.unicodeScalars.append(u)
    }
}
private func shareAppendQuoted(_ s: String, to out: inout String) {
    out.append("\"")
    for u in s.unicodeScalars { shareAppendEscaped(u, to: &out) }
    out.append("\"")
}
/// The same for raw UTF-16 units: half an emoji is written `\ud83d`, as
/// `JSON.stringify` has written a lone surrogate since ES2019.
private func shareAppendQuoted(units: [UInt16], to out: inout String) {
    out.append("\"")
    var i = 0
    while i < units.count {
        let u = units[i]
        if UTF16.isLeadSurrogate(u), i + 1 < units.count, UTF16.isTrailSurrogate(units[i + 1]) {
            let v = 0x10000 + ((UInt32(u) - 0xD800) << 10) + (UInt32(units[i + 1]) - 0xDC00)
            if let s = Unicode.Scalar(v) { out.unicodeScalars.append(s) }
            i += 2
        } else if UTF16.isLeadSurrogate(u) || UTF16.isTrailSurrogate(u) {
            out.append("\\u" + String(u, radix: 16))   // always four digits: d800…dfff
            i += 1
        } else {
            if let s = Unicode.Scalar(UInt32(u)) { shareAppendEscaped(s, to: &out) }
            i += 1
        }
    }
    out.append("\"")
}

func shareHasLoneSurrogate(_ units: [UInt16]) -> Bool {
    var i = 0
    while i < units.count {
        let u = units[i]
        if UTF16.isLeadSurrogate(u) {
            guard i + 1 < units.count, UTF16.isTrailSurrogate(units[i + 1]) else { return true }
            i += 2
        } else if UTF16.isTrailSurrogate(u) {
            return true
        } else {
            i += 1
        }
    }
    return false
}

/// UTF-16 units as a Swift String; half an emoji is DROPPED, the rule `jsSlice` set.
func shareStringDroppingLoneSurrogates(_ units: [UInt16]) -> String {
    guard shareHasLoneSurrogate(units) else { return String(decoding: units, as: UTF16.self) }
    var kept: [UInt16] = []
    kept.reserveCapacity(units.count)
    var i = 0
    while i < units.count {
        let u = units[i]
        if UTF16.isLeadSurrogate(u) {
            if i + 1 < units.count, UTF16.isTrailSurrogate(units[i + 1]) {
                kept.append(u); kept.append(units[i + 1]); i += 2
            } else { i += 1 }
        } else if UTF16.isTrailSurrogate(u) {
            i += 1
        } else {
            kept.append(u); i += 1
        }
    }
    return String(decoding: kept, as: UTF16.self)
}

/// A number exactly as `JSON.stringify` writes it: `jsNumberToString` (the package's
/// one number writer, in JSSemantics.swift) — except that NaN and ±Infinity, which
/// JSON cannot hold, are `null`.
func shareNumberText(_ n: Double) -> String { n.isFinite ? jsNumberToString(n) : "null" }

// (Reading JSON that JS wrote — half an emoji written `\ud83d` — is `JSONValue.parse`'s
// job: see "Reading JSON that JS wrote" in JSONValue.swift.)

// MARK: - base64 as btoa / atob do it

private let shareB64: [UInt8] = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".utf8)
private let shareB64Url: [UInt8] = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_".utf8)

/// `atob(s)` — the forgiving decode: ASCII whitespace is ignored, padding is optional,
/// left-over bits are thrown away; anything else that is not base64 throws.
func jsAtob(_ s: String) throws -> [UInt8] {
    var chars: [UInt8] = []
    chars.reserveCapacity(s.utf8.count)
    for sc in s.unicodeScalars {
        switch sc.value {
        case 0x09, 0x0A, 0x0C, 0x0D, 0x20: continue
        case 0..<0x80: chars.append(UInt8(sc.value))
        default: throw ShareError.damaged
        }
    }
    if chars.count % 4 == 0 {
        if chars.last == 0x3D { chars.removeLast() }
        if chars.last == 0x3D { chars.removeLast() }
    }
    if chars.count % 4 == 1 { throw ShareError.damaged }
    var out: [UInt8] = []
    out.reserveCapacity(chars.count * 3 / 4)
    var acc: UInt32 = 0
    var bits = 0
    for c in chars {
        let v: UInt32
        switch c {
        case 0x41...0x5A: v = UInt32(c) - 0x41
        case 0x61...0x7A: v = UInt32(c) - 0x61 + 26
        case 0x30...0x39: v = UInt32(c) - 0x30 + 52
        case 0x2B: v = 62
        case 0x2F: v = 63
        default: throw ShareError.damaged
        }
        acc = (acc << 6) | v
        bits += 6
        if bits >= 8 {
            bits -= 8
            out.append(UInt8((acc >> UInt32(bits)) & 255))
            acc &= (1 << UInt32(bits)) - 1
        }
    }
    return out
}

/// `btoa(bin)` — standard alphabet, padded.
func jsBtoa(_ bytes: [UInt8]) -> String {
    String(decoding: shareBase64(bytes, alphabet: shareB64, pad: true), as: UTF8.self)
}

private func shareBase64(_ bytes: [UInt8], alphabet: [UInt8], pad: Bool) -> [UInt8] {
    var out: [UInt8] = []
    out.reserveCapacity((bytes.count + 2) / 3 * 4)
    var i = 0
    while i + 2 < bytes.count {
        let n = (UInt32(bytes[i]) << 16) | (UInt32(bytes[i + 1]) << 8) | UInt32(bytes[i + 2])
        out.append(alphabet[Int(n >> 18)]); out.append(alphabet[Int((n >> 12) & 63)])
        out.append(alphabet[Int((n >> 6) & 63)]); out.append(alphabet[Int(n & 63)])
        i += 3
    }
    let left = bytes.count - i
    if left == 1 {
        let n = UInt32(bytes[i]) << 16
        out.append(alphabet[Int(n >> 18)]); out.append(alphabet[Int((n >> 12) & 63)])
        if pad { out.append(0x3D); out.append(0x3D) }
    } else if left == 2 {
        let n = (UInt32(bytes[i]) << 16) | (UInt32(bytes[i + 1]) << 8)
        out.append(alphabet[Int(n >> 18)]); out.append(alphabet[Int((n >> 12) & 63)])
        out.append(alphabet[Int((n >> 6) & 63)])
        if pad { out.append(0x3D) }
    }
    return out
}

/// URL-safe base64 (RFC 4648 §5) of a UTF-8 string, no padding.
/// JS: `btoa(unescape(encodeURIComponent(str)))` — that pair of calls IS "to UTF-8".
public func toBase64Url(_ str: String) -> String {
    bytesToBase64Url(Array(str.utf8))
}

/// JS: `decodeURIComponent(escape(atob(…)))` — base64, then STRICT UTF-8: bytes that
/// are not UTF-8 throw (URIError in JS) instead of turning into U+FFFD.
public func fromBase64Url(_ b64url: String) throws -> String {
    let b64 = b64url.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
    let bytes = try jsAtob(b64)
    let s = String(decoding: bytes, as: UTF8.self)
    // A repaired string no longer spells the same bytes — that is how invalid UTF-8 shows.
    guard s.utf8.elementsEqual(bytes) else { throw ShareError.damaged }
    return s
}

/// base64url of raw bytes (no UTF-8 step — these are bytes, not text).
public func bytesToBase64Url(_ bytes: [UInt8]) -> String {
    String(decoding: shareBase64(bytes, alphabet: shareB64Url, pad: false), as: UTF8.self)
}

public func base64UrlToBytes(_ b64url: String?) throws -> [UInt8] {
    var b64 = (b64url ?? "").replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
    while b64.utf16.count % 4 != 0 { b64 += "=" }
    return try jsAtob(b64)
}

// MARK: - Squeezing a share code

// A trip carries its whole packing list: a week away with three activities is
// some 250 lines and 50 kB of JSON, which as plain base64 is a 65 kB link — far
// past what any messaging app will carry in one piece. The text is enormously
// repetitive (the same two dozen field names on every line), so LZW compression
// takes roughly four fifths of it away and turns most trips back into a link
// you can actually send.
//
// A compressed payload is marked with a "z." in front. A plain one is always
// base64 of JSON, which always begins "eyJ", so the two can never be confused,
// and links sent before this existed keep working exactly as they did.
public let SHARE_ZIP_PREFIX = "z."

// Codes start 9 bits wide and grow as the dictionary fills, up to 16 bits.
private let LZW_MAX = 65536
private func lzwWidth(_ next: Int) -> Int {
    var w = 9
    while next > (1 << w) - 1 && w < 16 { w += 1 }
    return w
}

public func lzwCompress(_ bytes: [UInt8]) -> [UInt8] {
    guard let first = bytes.first else { return [] }
    // JS keys its dictionary by the string so far; (code of the string, next byte)
    // names the same entry, because every string in the dictionary has ONE code.
    var dict: [UInt32: UInt32] = [:]
    dict.reserveCapacity(min(bytes.count, LZW_MAX))
    var next = 256
    var width = 9
    var out: [UInt8] = []
    out.reserveCapacity(bytes.count / 2 + 8)
    var acc: UInt32 = 0
    var bits = 0
    func emit(_ code: UInt32) {
        acc = (acc << UInt32(width)) | code
        bits += width
        while bits >= 8 {
            bits -= 8
            out.append(UInt8((acc >> UInt32(bits)) & 255))
            acc &= (1 << UInt32(bits)) - 1
        }
    }
    var w = UInt32(first)
    for c in bytes.dropFirst() {
        let key = (w << 8) | UInt32(c)
        if let known = dict[key] { w = known; continue }
        emit(w)
        // Once all 65 536 codes are taken the encoder simply stops learning.
        if next < LZW_MAX { dict[key] = UInt32(next); next += 1; width = lzwWidth(next) }
        w = UInt32(c)
    }
    emit(w)
    if bits > 0 { out.append(UInt8((acc << UInt32(8 - bits)) & 255)) }
    return out
}

public func lzwDecompress(_ bytes: [UInt8]) throws -> [UInt8] {
    if bytes.isEmpty { return [] }
    var dict: [[UInt8]] = []          // dict[code - 256]
    var next = 256
    // The decoder learns each entry one step after the encoder wrote it, so it
    // must widen one step early to stay in lock-step.
    var width = 9
    var acc: UInt32 = 0
    var bits = 0
    var pos = 0
    func read() -> Int {
        while bits < width {
            if pos >= bytes.count { return -1 }
            acc = (acc << 8) | UInt32(bytes[pos]); pos += 1
            bits += 8
        }
        bits -= width
        let code = Int(acc >> UInt32(bits))
        acc &= (1 << UInt32(bits)) - 1
        return code
    }
    func entryFor(_ code: Int) -> [UInt8]? {
        if code < 256 { return [UInt8(code)] }
        return code - 256 < dict.count ? dict[code - 256] : nil
    }
    let code = read()
    if code < 0 { return [] }
    guard var w = entryFor(code) else { throw ShareError.damaged }
    var out = w
    while true {
        let k = read()
        if k < 0 { break }
        var entry: [UInt8]
        if let e = entryFor(k) {
            entry = e
        } else {
            if k != next { throw ShareError.damaged }
            entry = w; entry.append(w[0])
        }
        out.append(contentsOf: entry)
        if next < LZW_MAX {
            var learned = w; learned.append(entry[0])
            dict.append(learned); next += 1
            width = lzwWidth(next + 1)
        }
        w = entry
    }
    return out
}

/// Pack a string into the shortest share code available: compressed when that
/// helps (most things), plain base64 when it does not (very short codes).
public func packShare(_ str: String?) -> String {
    let text = str ?? ""
    let plain = toBase64Url(text)
    let zipped = SHARE_ZIP_PREFIX + bytesToBase64Url(lzwCompress(Array(text.utf8)))
    return zipped.utf16.count < plain.utf16.count ? zipped : plain
}

/// Unpack either flavour back into the original string.
public func unpackShare(_ payload: String?) throws -> String {
    var code = jsTrim(payload ?? "")
    while code.hasSuffix(".") { code.removeLast() }   // a sentence's full stop is not part of the code
    if code.hasPrefix(SHARE_ZIP_PREFIX) {
        var raw = try lzwDecompress(try base64UrlToBytes(String(code.dropFirst(SHARE_ZIP_PREFIX.count))))
        // `new TextDecoder().decode(…)`: a leading byte-order mark is swallowed, and
        // bytes that are not UTF-8 become U+FFFD instead of throwing.
        if raw.count >= 3, raw[0] == 0xEF, raw[1] == 0xBB, raw[2] == 0xBF { raw.removeFirst(3) }
        return String(decoding: raw, as: UTF8.self)
    }
    return try fromBase64Url(code)
}

// MARK: - What may leave this device (v186)

// The two properties the sync addon keeps for itself on every synced row — both
// hold the signed-in account's ADDRESS. Nothing that leaves the device (a shared
// trip, a shared template) may carry them, and nothing that ARRIVES may bring
// them in: a row claiming to belong to the sender's account is one the receiver's
// own sync would refuse to carry to their other device.
// (The JS name. The foundation's `RESERVED_SYNC_KEYS` is the same two keys as a Set.)
public let SYNC_RESERVED_KEYS: [String] = ["owner", "realmId"]

/// `/[^\s@<>]+@[^\s@<>]+\.[^\s@<>]+/` — is there an address ANYWHERE in here?
private func shareHasAddressInside(_ s: String) -> Bool {
    let u = Array(s.unicodeScalars)
    func plain(_ c: Unicode.Scalar) -> Bool { !(jsIsWhitespace(c) || c == "@" || c == "<" || c == ">") }
    for at in u.indices where u[at] == "@" && at > 0 && plain(u[at - 1]) {
        var end = at + 1
        while end < u.count, plain(u[end]) { end += 1 }
        // a dot with at least one character on each side of it, inside that run
        if end - (at + 1) >= 3, u[(at + 2)..<(end - 1)].contains(".") { return true }
    }
    return false
}

/// "Whose it is", fit to LEAVE this device in a share code: a name somebody typed,
/// never an address. Wider than `looksLikeEmail` on purpose — that one asks "is this
/// whole value an address?", which is the right question for display; at the door
/// the question is "is there an address anywhere in here?". And it is asked BEFORE
/// the value is cut to length: an address cut off at 40 characters no longer looks
/// like one, and would walk straight out.
public func shareSafeOwner(_ v: String?, max: Int = 40) -> String { shareText(cleaned: shareSafeOwnerUnits(v, max: max)) }

/// The same as UTF-16 units, for the ENCODED text (see `cleanShareUnits`).
func shareSafeOwnerUnits(_ v: String?, max: Int = 40) -> [UInt16] {
    let s = jsTrim(jsCollapseWhitespace(v ?? ""))
    if s.isEmpty || shareHasAddressInside(s) { return [] }
    return Array(s.utf16.prefix(Swift.max(0, max)))
}

// MARK: - Shared by the grab-list and template codes

/// `String(v ?? '').replace(/\s+/g, ' ').trim().slice(0, max)` as UTF-16 units — a cut
/// through the middle of an emoji keeps the half JS keeps (the ENCODED text must match).
///
/// `parked`: `v` came out of `JSONValue.parse(_, keepParked: true)`, so half an emoji
/// is still IN it (as its stand-in) and takes part in the trim and the cut exactly as
/// it does in JS — a name that arrives as "brim " + half an emoji keeps its space,
/// because in JS that space is not at the end. (Parity checker, invented backup.)
func cleanShareUnits(_ v: String, _ max: Int, parked: Bool = false) -> [UInt16] {
    guard parked else { return Array(jsTrim(jsCollapseWhitespace(v)).utf16.prefix(Swift.max(0, max))) }
    var out: [UInt16] = []
    var inRun = false
    for u in jsonUnparkedUnits(v) {
        // every JS whitespace character is one unit; half an emoji is never one
        if let s = Unicode.Scalar(UInt32(u)), jsIsWhitespace(s) {
            if !inRun { out.append(0x20); inRun = true }
        } else {
            out.append(u); inRun = false
        }
    }
    if out.first == 0x20 { out.removeFirst() }
    if out.last == 0x20 { out.removeLast() }
    return Array(out.prefix(Swift.max(0, max)))
}

/// The same as a Swift String, for what is handed back to the app: half an emoji is
/// dropped (the `jsSlice` rule) — and nothing else: no second trim, JS does none.
func cleanShareText(_ v: String, _ max: Int, parked: Bool = false) -> String {
    shareText(cleaned: cleanShareUnits(v, max, parked: parked))
}
func shareText(cleaned u: [UInt16]) -> String { shareStringDroppingLoneSurrogates(u) }

/// `text.match(/#\/g\/([A-Za-z0-9_.-]+)/)` — the code after the first `marker` that is
/// followed by at least one code character. nil when there is none.
func sharePayload(in text: String, marker: String) -> String? {
    let u = Array(text.utf8)
    let m = Array(marker.utf8)
    guard !m.isEmpty, u.count > m.count else { return nil }
    func isCode(_ c: UInt8) -> Bool {
        (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A) || (c >= 0x30 && c <= 0x39)
            || c == 0x5F || c == 0x2E || c == 0x2D
    }
    var i = 0
    while i + m.count < u.count {
        if u[i] == m[0], Array(u[i..<(i + m.count)]) == m {
            var j = i + m.count
            while j < u.count, isCode(u[j]) { j += 1 }
            if j > i + m.count { return String(decoding: u[(i + m.count)..<j], as: UTF8.self) }
        }
        i += 1
    }
    return nil
}
