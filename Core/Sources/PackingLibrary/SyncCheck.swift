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
        public let at: Date
        public let domain: String
        public let code: Int
        public init(type: Int, ok: Bool, at: Date, domain: String = "", code: Int = 0) {
            self.type = type; self.ok = ok; self.at = at; self.domain = domain; self.code = code
        }
    }
    public var lastSent: Date?
    public var lastReceived: Date?
    /// The most recent failed send or receive, if it came after the last good one.
    public var problem: Attempt?
    public var failedSends: Int = 0
    /// Records on this device that iCloud does not have yet, by kind.
    public var notSent: [String: Int] = [:]
    public var notSentTotal: Int { notSent.values.reduce(0, +) }
    /// Every attempt, newest first, for "Copy details".
    public var attempts: [Event] = []

    public init() {}

    /// What the events say, newest first.
    public init(events newestFirst: [Event], notSent: [String: Int] = [:]) {
        attempts = newestFirst
        self.notSent = notSent
        lastSent = attempts.first { $0.type == 2 && $0.ok }?.at
        lastReceived = attempts.first { $0.type == 1 && $0.ok }?.at
        if let bad = attempts.first(where: { !$0.ok }) {
            let lastGood = attempts.first { $0.type == bad.type && $0.ok }?.at ?? .distantPast
            if bad.at > lastGood { problem = Attempt(sending: bad.type == 2, at: bad.at, domain: bad.domain, code: bad.code) }
        }
        let since = lastSent ?? .distantPast
        failedSends = attempts.filter { $0.type == 2 && !$0.ok && $0.at > since }.count
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
        var events: [Event] = []
        rows(db, """
            SELECT ZCLOUDKITEVENTTYPE, ZSUCCEEDED, IFNULL(ZERRORDOMAIN,''), IFNULL(ZERRORCODE,0), IFNULL(ZENDEDAT, ZSTARTEDAT)
            FROM ANSCKEVENT WHERE ZCLOUDKITEVENTTYPE IN (1, 2) ORDER BY ZSTARTEDAT DESC LIMIT 300
            """) { r in
            events.append(Event(type: Int(r.int(0)), ok: r.int(1) != 0, at: Date(timeInterval: r.double(4), since: ref),
                                domain: r.text(2), code: Int(r.int(3))))
        }
        // Records with no trace in iCloud yet, or marked to be sent again.
        var notSent: [String: Int] = [:]
        rows(db, """
            SELECT r.ZTABLE, COUNT(*) FROM ZRECORD r
            LEFT JOIN ANSCKRECORDMETADATA m ON m.ZENTITYPK = r.Z_PK
                 AND m.ZENTITYID = (SELECT Z_ENT FROM Z_PRIMARYKEY WHERE Z_NAME = 'Record')
            WHERE m.Z_PK IS NULL OR m.ZNEEDSUPLOAD = 1
            GROUP BY r.ZTABLE
            """) { r in notSent[r.text(0)] = Int(r.int(1)) }
        return SyncCheck(events: events, notSent: notSent)
    }

    // MARK: The card's verdict

    /// The pill on the card. "Can't tell" when iCloud is on and this device cannot
    /// read its own record of it (the spec pass, 2026-10-05): a green "Working" there
    /// reassured when nothing was known.
    public enum State: Equatable {
        case off, unknown, stuck, working
        public var word: String {
            switch self {
            case .off: return "Off"
            case .unknown: return "Can\u{2019}t tell"
            case .stuck: return "Stuck"
            case .working: return "Working"
            }
        }
    }

    public static func state(usesICloud: Bool, check: SyncCheck?) -> State {
        guard usesICloud else { return .off }
        guard let check else { return .unknown }
        return check.notSentTotal > 0 || check.problem != nil ? .stuck : .working
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

    /// "3 trips, 21 trip lines" — what this device has that iCloud does not. Most
    /// first; on equal counts in the order of the tables (the spec pass, 2026-10-05:
    /// equal counts swapped places from one drawing of the card to the next).
    public var notSentWords: String {
        func rank(_ kind: String) -> Int { Table.allCases.firstIndex { $0.rawValue == kind } ?? Table.allCases.count }
        return notSent.sorted { a, b in
            a.value != b.value ? a.value > b.value
                : rank(a.key) != rank(b.key) ? rank(a.key) < rank(b.key) : a.key < b.key
        }
        .map { "\($0.value) \(SyncCheck.kinds[$0.key] ?? $0.key)" }.joined(separator: ", ")
    }

    /// Everything, for Claude.
    public func details(device: String, version: String) -> String {
        let f = ISO8601DateFormatter()
        var out = ["Sync details · \(device) · \(version)",
                   "Last sent: \(lastSent.map(f.string) ?? "never") · last received: \(lastReceived.map(f.string) ?? "never")",
                   "Not in iCloud yet: \(notSent.isEmpty ? "nothing" : notSentWords)",
                   "Failed sends since the last good one: \(failedSends)"]
        for a in attempts.prefix(30) {
            out.append("  \(a.type == 2 ? "send" : "receive") \(a.ok ? "ok" : "FAILED \(a.domain) \(a.code)") \(f.string(from: a.at))")
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
