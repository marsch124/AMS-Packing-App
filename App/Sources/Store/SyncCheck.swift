import Foundation
import SQLite3

/// What iCloud has been doing on THIS device — his field test, 3 Oct 2026: the
/// iPhone's new trips, templates and lines never reached the Mac, and only the
/// iPhone could say why. The store keeps its own record of every send and receive
/// (with the error when one failed) and of every record not sent yet; this reads it.
/// Read-only: it opens the store file for reading and changes nothing.
struct SyncCheck {
    struct Attempt {
        let sending: Bool
        let at: Date
        let domain: String
        let code: Int
    }
    var lastSent: Date?
    var lastReceived: Date?
    /// The most recent failed send or receive, if it came after the last good one.
    var problem: Attempt?
    var failedSends: Int = 0
    /// Records on this device that iCloud does not have yet, by kind.
    var notSent: [String: Int] = [:]
    var notSentTotal: Int { notSent.values.reduce(0, +) }
    /// Every attempt, newest first, for "Copy details".
    var attempts: [(type: Int, ok: Bool, at: Date, domain: String, code: Int)] = []

    /// The library's store file on this device.
    static var storeURL: URL { URL.applicationSupportDirectory.appending(path: "Library.store") }

    static func read(at url: URL = storeURL) -> SyncCheck? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { sqlite3_close(db); return nil }
        defer { sqlite3_close(db) }
        var check = SyncCheck()
        let ref = Date(timeIntervalSinceReferenceDate: 0)
        // Every send (2) and receive (1), newest first.
        rows(db, """
            SELECT ZCLOUDKITEVENTTYPE, ZSUCCEEDED, IFNULL(ZERRORDOMAIN,''), IFNULL(ZERRORCODE,0), IFNULL(ZENDEDAT, ZSTARTEDAT)
            FROM ANSCKEVENT WHERE ZCLOUDKITEVENTTYPE IN (1, 2) ORDER BY ZSTARTEDAT DESC LIMIT 300
            """) { r in
            let type = Int(r.int(0)), ok = r.int(1) != 0
            let at = Date(timeInterval: r.double(4), since: ref)
            check.attempts.append((type, ok, at, r.text(2), Int(r.int(3))))
        }
        check.lastSent = check.attempts.first { $0.type == 2 && $0.ok }?.at
        check.lastReceived = check.attempts.first { $0.type == 1 && $0.ok }?.at
        if let bad = check.attempts.first(where: { !$0.ok }) {
            let lastGood = check.attempts.first { $0.type == bad.type && $0.ok }?.at ?? .distantPast
            if bad.at > lastGood { check.problem = Attempt(sending: bad.type == 2, at: bad.at, domain: bad.domain, code: bad.code) }
        }
        let since = check.lastSent ?? .distantPast
        check.failedSends = check.attempts.filter { $0.type == 2 && !$0.ok && $0.at > since }.count
        // Records with no trace in iCloud yet, or marked to be sent again.
        rows(db, """
            SELECT r.ZTABLE, COUNT(*) FROM ZRECORD r
            LEFT JOIN ANSCKRECORDMETADATA m ON m.ZENTITYPK = r.Z_PK
                 AND m.ZENTITYID = (SELECT Z_ENT FROM Z_PRIMARYKEY WHERE Z_NAME = 'Record')
            WHERE m.Z_PK IS NULL OR m.ZNEEDSUPLOAD = 1
            GROUP BY r.ZTABLE
            """) { r in check.notSent[r.text(0)] = Int(r.int(1)) }
        return check
    }

    // MARK: Plain words

    /// Why a send or receive failed, as he would say it.
    static func plain(domain: String, code: Int) -> String {
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

    static let kinds: [String: String] = ["trips": "trips", "entries": "trip lines", "items": "things",
                                         "memberships": "places on templates", "templates": "templates",
                                         "actions": "to-dos", "photos": "photos", "meta": "notes",
                                         "phases": "\u{201C}When\u{201D} steps", "shared": "choices", "kits": "kits"]

    /// "3 trips, 21 trip lines" — what this device has that iCloud does not.
    var notSentWords: String {
        notSent.sorted { $0.value > $1.value }.map { "\($0.value) \(SyncCheck.kinds[$0.key] ?? $0.key)" }.joined(separator: ", ")
    }

    /// Everything, for Claude.
    func details(device: String, version: String) -> String {
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
