import Foundation
import SQLite3

/// What iCloud has been doing on THIS device — his field test, 3 Oct 2026: the
/// iPhone's new trips, templates and lines never reached the Mac, and only the
/// iPhone could say why. The store keeps its own record of every send and receive
/// (with the error when one failed) and of every record not sent yet; this reads it.
/// Read-only: it opens the store file for reading and changes nothing.
///
/// In the model package since the spec pass (2026-10-05), so the reading, the plain
/// words and the card's verdict are held by model tests — the app has no iCloud
/// under the tests, and none of it had a test.
public struct SyncCheck: Equatable {
    public struct Attempt: Equatable {
        public let sending: Bool
        public let at: Date
        public let domain: String
        public let code: Int
        public init(sending: Bool, at: Date, domain: String, code: Int) {
            self.sending = sending; self.at = at; self.domain = domain; self.code = code
        }
    }
    /// One send (type 2) or receive (type 1), as the store kept it.
    public struct Event: Equatable {
        public let type: Int
        public let ok: Bool
        /// When it ended — or, for one with no end, when it started.
        public let at: Date
        public let domain: String
        public let code: Int
        /// No end in the store (0.92): still RUNNING when it is the newest of its kind, else
        /// left behind (the app went away while it ran, and a later one of its kind started).
        /// Never a failure — his field report of 16 Oct 2026: a receive that never ended
        /// (`ZENDEDAT` empty, `ZSUCCEEDED` 0) showed as "FAILED 0", "It stopped without saying why".
        public let unfinished: Bool
        public init(type: Int, ok: Bool, at: Date, domain: String = "", code: Int = 0, unfinished: Bool = false) {
            self.type = type; self.ok = ok; self.at = at; self.domain = domain; self.code = code
            self.unfinished = unfinished
        }
    }
    /// A send or receive running now: the newest of its kind, with no end yet (0.92).
    public struct Running: Equatable {
        public let sending: Bool
        public let since: Date
        public init(sending: Bool, since: Date) { self.sending = sending; self.since = since }
    }
    public var lastSent: Date?
    public var lastReceived: Date?
    /// The most recent failed send or receive, if it came after the last good one.
    public var problem: Attempt?
    public var failedSends: Int = 0
    /// Records on this device that iCloud does not have yet, by kind.
    public var notSent: [String: Int] = [:]
    public var notSentTotal: Int { notSent.values.reduce(0, +) }
    /// When the oldest of those was written on this device (0.92) — how long changes have
    /// waited. nil when nothing waits, or the store does not say.
    public var waitingSince: Date?
    /// The send and the receive running now, if any (0.92).
    public var sending: Running?
    public var receiving: Running?
    /// Every attempt, newest first, for "Copy details".
    public var attempts: [Event] = []

    public init() {}

    /// What the events say, newest first (by when each started).
    public init(events newestFirst: [Event], notSent: [String: Int] = [:], waitingSince: Date? = nil) {
        attempts = newestFirst
        self.notSent = notSent
        self.waitingSince = notSent.values.contains { $0 > 0 } ? waitingSince : nil
        // Only what has ENDED went well or failed (0.92); one with no end is running or left behind.
        let ended = attempts.filter { !$0.unfinished }
        lastSent = ended.first { $0.type == 2 && $0.ok }?.at
        lastReceived = ended.first { $0.type == 1 && $0.ok }?.at
        if let bad = ended.first(where: { !$0.ok }) {
            let lastGood = ended.first { $0.type == bad.type && $0.ok }?.at ?? .distantPast
            if bad.at > lastGood { problem = Attempt(sending: bad.type == 2, at: bad.at, domain: bad.domain, code: bad.code) }
        }
        let since = lastSent ?? .distantPast
        failedSends = ended.filter { $0.type == 2 && !$0.ok && $0.at > since }.count
        // Running: the newest of its kind, and it has no end.
        func running(_ type: Int) -> Running? {
            guard let newest = attempts.first(where: { $0.type == type }), newest.unfinished else { return nil }
            return Running(sending: type == 2, since: newest.at)
        }
        sending = running(2)
        receiving = running(1)
    }

    /// Is this attempt the one running now (the newest of its kind)? Else, with no end, it was left behind.
    private func isRunning(_ e: Event) -> Bool {
        e.unfinished && attempts.first { $0.type == e.type } == e
    }

    /// The library's store file on this device.
    public static var storeURL: URL { URL.applicationSupportDirectory.appending(path: "Library.store") }

    /// nil when the file is not there, or SQLite will not open it.
    public static func read(at url: URL = storeURL) -> SyncCheck? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { sqlite3_close(db); return nil }
        defer { sqlite3_close(db) }
        let ref = Date(timeIntervalSinceReferenceDate: 0)
        // Every send (2) and receive (1), newest first.
        // One with no end (0.92) is said by its start, and marked: it is running or was left behind.
        var events: [Event] = []
        rows(db, """
            SELECT ZCLOUDKITEVENTTYPE, ZSUCCEEDED, IFNULL(ZERRORDOMAIN,''), IFNULL(ZERRORCODE,0), IFNULL(ZENDEDAT, ZSTARTEDAT),
                   ZENDEDAT IS NULL
            FROM ANSCKEVENT WHERE ZCLOUDKITEVENTTYPE IN (1, 2) ORDER BY ZSTARTEDAT DESC LIMIT 300
            """) { r in
            events.append(Event(type: Int(r.int(0)), ok: r.int(1) != 0, at: Date(timeInterval: r.double(4), since: ref),
                                domain: r.text(2), code: Int(r.int(3)), unfinished: r.int(5) != 0))
        }
        // Records with no trace in iCloud yet, or marked to be sent again.
        let waiting = """
            FROM ZRECORD r
            LEFT JOIN ANSCKRECORDMETADATA m ON m.ZENTITYPK = r.Z_PK
                 AND m.ZENTITYID = (SELECT Z_ENT FROM Z_PRIMARYKEY WHERE Z_NAME = 'Record')
            WHERE m.Z_PK IS NULL OR m.ZNEEDSUPLOAD = 1
            """
        var notSent: [String: Int] = [:]
        rows(db, "SELECT r.ZTABLE, COUNT(*) \(waiting) GROUP BY r.ZTABLE") { r in notSent[r.text(0)] = Int(r.int(1)) }
        // Since when the oldest of them has waited: its record's last write on this device (0.92). Asked on
        // its own, so a store without the column still says what waits.
        var since: Date?
        rows(db, "SELECT MIN(r.ZUPDATEDAT) \(waiting) AND r.ZUPDATEDAT IS NOT NULL") { r in
            if sqlite3_column_type(r.s, 0) != SQLITE_NULL { since = Date(timeInterval: r.double(0), since: ref) }
        }
        return SyncCheck(events: events, notSent: notSent, waitingSince: since)
    }

    // MARK: The light — on Home, and the card's pill

    /// The sync light (0.92 — his yes of 19 Oct 2026 to "a small dot — green when both devices
    /// are in step, orange while changes are waiting. A tap opens Sync details, so you see
    /// problems like last week's without digging.") and the pill on the card, which says the
    /// same. Until 0.92 the pill was Off / Can't tell / Stuck / Working, and "Stuck" the moment
    /// anything waited — even the second between a change and its send.
    public enum Light: String, Equatable, CaseIterable {
        case off, unknown, inSync, sending, receiving, stuck

        public enum Colour: String { case green, orange, red, grey }

        public var colour: Colour {
            switch self {
            case .inSync: return .green
            case .sending, .receiving: return .orange
            case .stuck: return .red
            case .off, .unknown: return .grey
            }
        }

        /// The one or two words beside the dot.
        public var word: String {
            switch self {
            case .off: return "iCloud off"
            case .unknown: return "Can\u{2019}t tell"
            case .inSync: return "In sync"
            case .sending: return "Sending\u{2026}"
            case .receiving: return "Receiving\u{2026}"
            case .stuck: return "Stuck"
            }
        }
    }

    /// A send or receive with no end is called hung after this long (0.92).
    public static let hangsAfter: TimeInterval = 10 * 60
    /// Changes not in iCloud are stuck after waiting this long with no good send (0.92).
    public static let waitsTooLongAfter: TimeInterval = 30 * 60

    /// What the light says, in this order:
    /// - **iCloud off** (grey): this build keeps the library on the device;
    /// - **Can't tell** (grey): iCloud on, and the store's record cannot be read;
    /// - **Stuck** (red): a send or receive failed after the last good one of its kind; or one
    ///   has run without an end for ten minutes (`hung`); or changes have waited half an hour
    ///   with no good send in that half hour (`waitedTooLong`);
    /// - **Sending…** (orange): changes not in iCloud yet, or a send running;
    /// - **Receiving…** (orange): a receive running;
    /// - **Can't tell** (grey) again when no send or receive ever went well on this device;
    /// - **In sync** (green) otherwise.
    ///
    /// `awake`: when the app last came to the front. The iPhone pauses the app in the background,
    /// and a receive it was in the middle of waits with it; its ten minutes count from here.
    public static func light(usesICloud: Bool, check: SyncCheck?, now: Date, awake: Date = .distantPast) -> Light {
        guard usesICloud else { return .off }
        guard let c = check else { return .unknown }
        if c.problem != nil || c.hung(now: now, awake: awake) != nil || c.waitedTooLong(now: now) { return .stuck }
        if c.notSentTotal > 0 || c.sending != nil { return .sending }
        if c.receiving != nil { return .receiving }
        if c.lastSent == nil && c.lastReceived == nil { return .unknown }
        return .inSync
    }

    /// The send or receive that has run ten minutes or more with no end — counted from its start,
    /// or from `awake` when the app came to the front later. The one running longest.
    public func hung(now: Date, awake: Date = .distantPast) -> Running? {
        [receiving, sending].compactMap { $0 }
            .filter { now.timeIntervalSince(max($0.since, awake)) >= SyncCheck.hangsAfter }
            .min { $0.since < $1.since }
    }

    /// Changes have waited half an hour or more, and nothing reached iCloud in that half hour.
    public func waitedTooLong(now: Date) -> Bool {
        guard notSentTotal > 0, let waitingSince else { return false }
        let halfAnHourAgo = now.addingTimeInterval(-SyncCheck.waitsTooLongAfter)
        return waitingSince <= halfAnHourAgo && (lastSent ?? .distantPast) <= halfAnHourAgo
    }

    /// The card's line about a send or receive running now (0.92): quiet while it runs, LOUD once
    /// it has hung. "Receiving from iCloud has hung since 07:57 — quit Packing and open it again."
    public func runningWords(now: Date, awake: Date = .distantPast, calendar: Calendar = .current) -> (words: String, hung: Bool)? {
        if let h = hung(now: now, awake: awake) {
            return ("\(SyncCheck.doing(h)) has hung since \(SyncCheck.since(h.since, now: now, calendar: calendar)) \u{2014} quit Packing and open it again.", true)
        }
        guard let r = receiving ?? sending else { return nil }
        return ("\(SyncCheck.doing(r)) since \(SyncCheck.since(r.since, now: now, calendar: calendar)).", false)
    }

    /// The card's line when changes have waited too long (0.92).
    public func waitedWords(now: Date, calendar: Calendar = .current) -> String? {
        guard waitedTooLong(now: now), let waitingSince else { return nil }
        return "Waiting since \(SyncCheck.since(waitingSince, now: now, calendar: calendar)) \u{2014} nothing has reached iCloud for half an hour."
    }

    /// The light in words, for VoiceOver: its word, and what it means.
    public static func spoken(_ light: Light, check: SyncCheck?, now: Date, awake: Date = .distantPast,
                              calendar: Calendar = .current) -> String {
        switch light {
        case .off: return "iCloud off \u{2014} this copy keeps its library on this device only"
        case .unknown: return "Can\u{2019}t tell how the sync is going"
        case .inSync: return "In sync"
        case .receiving: return "Receiving from iCloud"
        case .sending:
            guard let c = check, c.notSentTotal > 0 else { return "Sending to iCloud" }
            return "Sending to iCloud: \(c.notSentWords)"
        case .stuck:
            guard let c = check else { return "Stuck" }
            if let p = c.problem {
                return "Stuck: the last \(p.sending ? "send" : "receive") failed \(when(p.at, now: now, calendar: calendar)): \(plain(domain: p.domain, code: p.code))"
            }
            if let r = c.runningWords(now: now, awake: awake, calendar: calendar), r.hung { return "Stuck: " + r.words }
            return "Stuck: " + (c.waitedWords(now: now, calendar: calendar) ?? "")
        }
    }

    /// "Receiving from iCloud", "Sending to iCloud".
    private static func doing(_ r: Running) -> String { r.sending ? "Sending to iCloud" : "Receiving from iCloud" }

    /// "07:57" today, "16 Oct 07:57" another day — after "since".
    public static func since(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let w = when(date, now: now, calendar: calendar)
        return w.hasPrefix("today ") ? String(w.dropFirst(6)) : w
    }

    // MARK: Plain words

    /// Why a send or receive failed, as he would say it.
    public static func plain(domain: String, code: Int) -> String {
        if domain == "CKErrorDomain" {
            switch code {
            case 25: return "Your iCloud storage is full"
            case 9: return "This device is not signed in to iCloud"
            case 3, 4, 6, 7, 23: return "iCloud could not be reached \u{2014} it tries again by itself"
            case 27: return "A change was too big for iCloud"
            case 14: return "A change crossed a newer one"
            case 26, 28: return "The copy in iCloud was reset"
            case 2: return "iCloud refused some of the changes"
            case 36: return "iCloud is busy with this account \u{2014} it tries again by itself"
            default: return "iCloud said no (\(code))"
            }
        }
        if domain.isEmpty { return "It stopped without saying why" }
        return "Something went wrong (\(code))"
    }

    public static let kinds: [String: String] = ["trips": "trips", "entries": "trip lines", "items": "things",
                                                "memberships": "places on templates", "templates": "templates",
                                                "actions": "to-dos", "photos": "photos", "meta": "notes",
                                                "phases": "\u{201C}When\u{201D} steps", "shared": "choices", "kits": "kits"]

    /// One of each (0.92 — the light put "1 trips" in front of him).
    public static let kind: [String: String] = ["trips": "trip", "entries": "trip line", "items": "thing",
                                               "memberships": "place on a template", "templates": "template",
                                               "actions": "to-do", "photos": "photo", "meta": "note",
                                               "phases": "\u{201C}When\u{201D} step", "shared": "choice", "kits": "kit"]

    /// "3 trips, 21 trip lines", "1 trip" — what this device has that iCloud does not. Most
    /// first; on equal counts in the order of the tables (the spec pass, 2026-10-05:
    /// equal counts swapped places from one drawing of the card to the next).
    public var notSentWords: String {
        func rank(_ kind: String) -> Int { Table.allCases.firstIndex { $0.rawValue == kind } ?? Table.allCases.count }
        return notSent.sorted { a, b in
            a.value != b.value ? a.value > b.value
                : rank(a.key) != rank(b.key) ? rank(a.key) < rank(b.key) : a.key < b.key
        }
        .map { "\($0.value) \(($0.value == 1 ? SyncCheck.kind : SyncCheck.kinds)[$0.key] ?? $0.key)" }.joined(separator: ", ")
    }

    /// Everything, for Claude.
    public func details(device: String, version: String) -> String {
        let f = ISO8601DateFormatter()
        var out = ["Sync details · \(device) · \(version)",
                   "Last sent: \(lastSent.map(f.string) ?? "never") · last received: \(lastReceived.map(f.string) ?? "never")",
                   "Not in iCloud yet: \(notSent.isEmpty ? "nothing" : notSentWords)"
                       + (waitingSince.map { " (waiting since \(f.string(from: $0)))" } ?? ""),
                   "Failed sends since the last good one: \(failedSends)"]
        for a in attempts.prefix(30) {
            // One with no end (0.92): running since it started, or left behind — never "FAILED".
            let how = a.unfinished ? (isRunning(a) ? "running since" : "never ended, started")
                : a.ok ? "ok" : "FAILED \(a.domain) \(a.code)"
            out.append("  \(a.type == 2 ? "send" : "receive") \(how) \(f.string(from: a.at))")
        }
        return out.joined(separator: "\n")
    }

    /// "today 13:52", "2 Oct 22:10", "never" — in the device's own time.
    public static func when(_ date: Date?, now: Date = Date(), calendar: Calendar = .current) -> String {
        guard let date else { return "never" }
        let hm = String(format: "%02d:%02d", calendar.component(.hour, from: date), calendar.component(.minute, from: date))
        if calendar.isDate(date, inSameDayAs: now) { return "today \(hm)" }
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return "\(calendar.component(.day, from: date)) \(months[calendar.component(.month, from: date) - 1]) \(hm)"
    }

    /// The same, for an ISO time written with or without its milliseconds.
    public static func when(iso: String, now: Date = Date(), calendar: Calendar = .current) -> String {
        when(isoMoment(iso), now: now, calendar: calendar)
    }

    // MARK: SQLite, the little that is needed

    private struct Row {
        let s: OpaquePointer?
        func int(_ i: Int32) -> Int64 { sqlite3_column_int64(s, i) }
        func double(_ i: Int32) -> Double { sqlite3_column_double(s, i) }
        func text(_ i: Int32) -> String { sqlite3_column_text(s, i).map { String(cString: $0) } ?? "" }
    }

    private static func rows(_ db: OpaquePointer?, _ sql: String, _ each: (Row) -> Void) {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { sqlite3_finalize(stmt); return }
        defer { sqlite3_finalize(stmt) }
        while sqlite3_step(stmt) == SQLITE_ROW { each(Row(s: stmt)) }
    }
}
