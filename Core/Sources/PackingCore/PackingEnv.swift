// PackingEnv — the clock, the id maker and the sorting locale, all injectable.
//
// `id()` and "now" are the two things in model.js that are different on every call,
// so nothing built with them could ever be compared between the two models. Tests
// and the parity checker replace them; the app leaves the defaults alone.

import Foundation

public enum PackingEnv {
    /// "Now". Default: the real clock.
    public static var now: () -> Date = { Date() }

    /// A new id. Default: the JS format (see `defaultMakeId`).
    public static var makeId: () -> String = { PackingEnv.defaultMakeId() }

    /// The locale `jsLocaleCompare` sorts in. JS uses the runtime's own; "en" is the
    /// plain ICU order Node and an English-language Safari both give. To be tuned
    /// ONCE, here, when the parity checker has run over his Swedish names.
    public static var collationLocale = Locale(identifier: "en")

    /// Put everything back (call from a test's `tearDown`).
    public static func reset() {
        now = { Date() }
        makeId = { PackingEnv.defaultMakeId() }
        collationLocale = Locale(identifier: "en")
    }

    /// Fixed clock and counting ids ("id-1", "id-2"…) — for tests and the parity checker.
    public static func freeze(at iso: String = "2026-01-01T00:00:00.000Z", idPrefix: String = "id-") {
        let date = ISO8601DateFormatterBox.date(from: iso) ?? Date(timeIntervalSince1970: 0)
        var n = 0
        now = { date }
        makeId = { n += 1; return "\(idPrefix)\(n)" }
    }

    // `${Date.now().toString(36)}-${(_seq++).toString(36)}-${Math.random().toString(36).slice(2, 8)}`
    // Sortable-ish, collision-resistant enough for a personal on-device app.
    private static var seq: Int64 = 0
    private static let seqLock = NSLock()
    public static func defaultMakeId() -> String {
        seqLock.lock()
        let s = seq
        seq += 1
        seqLock.unlock()
        let ms = Int64((now().timeIntervalSince1970 * 1000).rounded(.down))
        let alphabet = Array("0123456789abcdefghijklmnopqrstuvwxyz")
        var tail = ""
        for _ in 0..<6 { tail.append(alphabet[Int.random(in: 0..<36)]) }
        return "\(jsBase36(ms))-\(jsBase36(s))-\(tail)"
    }
}

/// `id()` — a new unique id, through `PackingEnv.makeId`.
/// (Inside a type that has its own `id` property, write `PackingEnv.makeId()`.)
public func id() -> String { PackingEnv.makeId() }

/// `nowISO()` — `new Date().toISOString()`, through `PackingEnv.now`.
public func nowISO() -> String { jsISOString(PackingEnv.now()) }

/// `Date.now()` in milliseconds, through `PackingEnv.now`.
public func jsDateNow() -> Int64 { Int64((PackingEnv.now().timeIntervalSince1970 * 1000).rounded(.down)) }

enum ISO8601DateFormatterBox {
    /// Reads "2026-08-20T12:00:00.000Z" and "2026-08-20T12:00:00Z".
    static func date(from iso: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: iso) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: iso)
    }
}
