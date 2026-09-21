// Tools — the small helpers of the parity tool (§4 of js-answers.mjs).
//
// The Swift half of the AMS Packing PARITY CHECKER. It answers the questions of
// tools/parity/QUESTIONS.md through PackingCore's PUBLIC API only, and is laid out
// like tools/parity/js-answers.mjs — one function per question group — so the two
// can be read side by side.
//
// 🚨 PRIVACY. The backup is the owner's real data and this repository is public.
// Nothing in this target names a real thing; its output belongs in private/ only.

import Foundation
import PackingCore

typealias J = JSONValue

let ALL = "*"
let ID = "<id>"
let NOWMARK = "<now>"

// MARK: - Reading loose JSON the way the JS reads it

/// `asArr(v)` — the array, or [] for anything that is not one.
func asArr(_ v: J?) -> [J] { v?.arrayValue ?? [] }
/// `nonEmptyArr(v)`
func nonEmptyArr(_ v: J?) -> Bool { !(v?.arrayValue ?? []).isEmpty }
/// `str(v)` — the contract's string rule: a string as it is; absent or null → "";
/// anything else → `String(v)`.
func str(_ v: J?) -> String { jsStringNullish(v) }
/// `typeof v === 'string' && v` — a non-empty string, else nil.
func nonEmptyString(_ v: J?) -> String? {
    guard let s = v?.stringValue, !s.isEmpty else { return nil }
    return s
}

/// `[...new Set(arr)]` — first appearance wins, order kept.
func distinct(_ xs: [String]) -> [String] {
    var seen = Set<String>()
    var out: [String] = []
    for x in xs where !seen.contains(x) { seen.insert(x); out.append(x) }
    return out
}
/// `.sort(cmpCodeUnit)` — UTF-16 code-unit order, NOT Swift's `String <`.
func sortedByCodeUnit(_ xs: [String]) -> [String] { xs.stableSorted(by: { a, b in jsStringLess(a, b) }) }

// MARK: - Building canonical values

/// An object from pairs; a nil value is JS `undefined` and the key is dropped.
func obj(_ pairs: KeyValuePairs<String, J?>) -> J {
    var o: [String: J] = [:]
    for (k, v) in pairs { if let v = v { o[k] = v } }
    return .object(o)
}
/// Only these keys of an object, each only when present.
func pick(_ v: J?, _ keys: [String]) -> J {
    var o: [String: J] = [:]
    for k in keys { if let x = v?[k] { o[k] = x } }
    return .object(o)
}
func jint(_ n: Int) -> J { .number(Double(n)) }
/// A JS `null` where Swift holds nil.
func jint(_ n: Int?) -> J { n.map { .number(Double($0)) } ?? .null }
func jstrings(_ xs: [String]) -> J { .array(xs.map { .string($0) }) }
/// A JS `Set` of strings: an array sorted by UTF-16 code unit.
func jset(_ xs: [String]) -> J { jstrings(sortedByCodeUnit(distinct(xs))) }

/// Canonical JSON TEXT (the contract's `CJ`): keys in UTF-16 code-unit order, no
/// whitespace, strings and numbers exactly as `JSON.stringify` writes them.
func CJ(_ v: J) -> String { OrderedJSON(sorted: v).text() }

/// FNV-1a, 32 bit.
func fnv1a(_ bytes: [UInt8]) -> UInt32 {
    var h: UInt32 = 2_166_136_261
    for b in bytes { h = (h ^ UInt32(b)) &* 16_777_619 }
    return h
}

/// `/[^\s@<>]+@[^\s@<>]+\.[^\s@<>]+/.test(text)` — is there an e-mail address anywhere
/// inside? (`\s` is the JS class: `jsIsWhitespace`.)
func addressInside(_ text: String) -> Bool {
    let u = Array(text.unicodeScalars)
    func ok(_ s: Unicode.Scalar) -> Bool { !(jsIsWhitespace(s) || s == "@" || s == "<" || s == ">") }
    for i in u.indices where u[i] == "@" {
        guard i > 0, ok(u[i - 1]) else { continue }
        var run: [Unicode.Scalar] = []
        var j = i + 1
        while j < u.count, ok(u[j]) { run.append(u[j]); j += 1 }
        // one or more, a dot, one or more
        if run.count >= 3, run[1..<(run.count - 1)].contains(".") { return true }
    }
    return false
}

/// The message of whatever a model function threw (D7). The model's own errors are
/// `ShareError`s carrying the web app's user-facing words.
func errorMessage(_ error: Error) -> String {
    if let e = error as? ShareError { return e.message }
    return String(describing: error)
}
