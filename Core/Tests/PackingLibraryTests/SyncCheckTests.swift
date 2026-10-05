import XCTest
import SQLite3
@testable import PackingLibrary

/// The iCloud sync card's reading of the store (his field test, 3 Oct 2026), held
/// here since the spec pass (2026-10-05): the app runs without iCloud under the UI
/// tests, so none of this had a test. The store file is played by a small SQLite
/// file with the four tables the card reads, laid out the way Core Data keeps them.
final class SyncCheckTests: XCTestCase {

    private var file: URL!
    private let ref = Date(timeIntervalSinceReferenceDate: 0)

    override func setUp() {
        file = FileManager.default.temporaryDirectory.appendingPathComponent("synccheck-\(UUID().uuidString).store")
    }
    override func tearDown() { try? FileManager.default.removeItem(at: file) }

    private func run(_ db: OpaquePointer?, _ sql: String) {
        XCTAssertEqual(sqlite3_exec(db, sql, nil, nil, nil), SQLITE_OK, String(cString: sqlite3_errmsg(db)))
    }

    /// A store: events (type, ok, domain, code, seconds since 2001), records by
    /// table, and which of them iCloud has (nil = no trace; true = to be sent again).
    private func makeStore(events: [(Int, Bool, String, Int, Double)], records: [(String, Bool?)]) {
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(file.path, &db), SQLITE_OK)
        defer { sqlite3_close(db) }
        run(db, """
            CREATE TABLE ANSCKEVENT (Z_PK INTEGER PRIMARY KEY, ZCLOUDKITEVENTTYPE INTEGER, ZSUCCEEDED INTEGER,
                ZERRORDOMAIN VARCHAR, ZERRORCODE INTEGER, ZSTARTEDAT TIMESTAMP, ZENDEDAT TIMESTAMP);
            CREATE TABLE ZRECORD (Z_PK INTEGER PRIMARY KEY, ZTABLE VARCHAR);
            CREATE TABLE ANSCKRECORDMETADATA (Z_PK INTEGER PRIMARY KEY, ZENTITYPK INTEGER, ZENTITYID INTEGER, ZNEEDSUPLOAD INTEGER);
            CREATE TABLE Z_PRIMARYKEY (Z_ENT INTEGER PRIMARY KEY, Z_NAME VARCHAR);
            INSERT INTO Z_PRIMARYKEY VALUES (1, 'Record'), (2, 'Something else');
            """)
        for (type, ok, domain, code, at) in events {
            let d = domain.isEmpty ? "NULL" : "'\(domain)'"
            run(db, "INSERT INTO ANSCKEVENT (ZCLOUDKITEVENTTYPE, ZSUCCEEDED, ZERRORDOMAIN, ZERRORCODE, ZSTARTEDAT, ZENDEDAT) VALUES (\(type), \(ok ? 1 : 0), \(d), \(code), \(at - 1), \(at))")
        }
        // A meta row of ANOTHER entity with the same primary key must not count as the record's.
        run(db, "INSERT INTO ANSCKRECORDMETADATA (ZENTITYPK, ZENTITYID, ZNEEDSUPLOAD) VALUES (1, 2, 0)")
        for (n, (table, inCloud)) in records.enumerated() {
            run(db, "INSERT INTO ZRECORD (Z_PK, ZTABLE) VALUES (\(n + 1), '\(table)')")
            if let again = inCloud {
                run(db, "INSERT INTO ANSCKRECORDMETADATA (ZENTITYPK, ZENTITYID, ZNEEDSUPLOAD) VALUES (\(n + 1), 1, \(again ? 1 : 0))")
            }
        }
    }

    func testTheCardReadsWhatTheStoreKept() throws {
        makeStore(events: [(2, true, "", 0, 1_000), (1, true, "", 0, 1_100), (2, false, "CKErrorDomain", 25, 1_200),
                           (2, false, "CKErrorDomain", 3, 1_300), (1, true, "", 0, 1_400)],
                  records: [("items", nil), ("trips", false), ("entries", true), ("entries", nil), ("photos", false)])
        let c = try XCTUnwrap(SyncCheck.read(at: file))
        XCTAssertEqual(c.lastSent, Date(timeInterval: 1_000, since: ref))
        XCTAssertEqual(c.lastReceived, Date(timeInterval: 1_400, since: ref))
        XCTAssertEqual(c.problem, SyncCheck.Attempt(sending: true, at: Date(timeInterval: 1_300, since: ref),
                                                    domain: "CKErrorDomain", code: 3), "the newest failed send")
        XCTAssertEqual(c.failedSends, 2)
        XCTAssertEqual(c.notSent, ["items": 1, "entries": 2], "records with no trace, or to be sent again")
        XCTAssertEqual(SyncCheck.state(usesICloud: true, check: c), .stuck)
        XCTAssertEqual(c.attempts.count, 5)
        XCTAssertTrue(c.details(device: "iPhone", version: "0.62 (1)").contains("Failed sends since the last good one: 2"))
    }

    /// A failure that a later success of the same kind has put right is no problem.
    func testAFailurePutRightIsNoProblem() throws {
        makeStore(events: [(2, false, "CKErrorDomain", 4, 1_000), (2, true, "", 0, 1_100), (1, false, "", 0, 900)],
                  records: [("items", false)])
        let c = try XCTUnwrap(SyncCheck.read(at: file))
        XCTAssertNil(c.problem)
        XCTAssertEqual(c.failedSends, 0)
        XCTAssertEqual(c.notSentTotal, 0)
        XCTAssertEqual(SyncCheck.state(usesICloud: true, check: c), .working)
    }

    /// iCloud on, and nothing to read: say so — not a green "Working" (item 25).
    func testTheCardSaysItCannotTellWhenItCannotRead() {
        XCTAssertNil(SyncCheck.read(at: file), "a store file that is not there")
        XCTAssertEqual(SyncCheck.state(usesICloud: true, check: nil), .unknown)
        XCTAssertEqual(SyncCheck.state(usesICloud: true, check: nil).word, "Can\u{2019}t tell")
        XCTAssertEqual(SyncCheck.state(usesICloud: false, check: nil), .off)
        XCTAssertEqual(SyncCheck.state(usesICloud: false, check: SyncCheck()), .off)
        XCTAssertEqual(SyncCheck.state(usesICloud: true, check: SyncCheck()), .working)
        XCTAssertEqual([SyncCheck.State.off, .stuck, .working].map(\.word), ["Off", "Stuck", "Working"])
    }

    /// Equal counts keep one order, whatever order the store gave them in (item 20).
    func testNotInICloudYetKeepsItsOrder() {
        var c = SyncCheck()
        c.notSent = ["photos": 2, "trips": 3, "meta": 1, "entries": 3, "items": 2, "kits": 1, "zzz-new": 1]
        let words = "3 trips, 3 trip lines, 2 things, 2 photos, 1 kits, 1 notes, 1 zzz-new"
        XCTAssertEqual(c.notSentWords, words)
        for _ in 0..<20 {
            var again = SyncCheck()
            again.notSent = Dictionary(uniqueKeysWithValues: c.notSent.shuffled().map { ($0.key, $0.value) })
            XCTAssertEqual(again.notSentWords, words)
        }
    }

    func testThePlainWords() {
        XCTAssertEqual(SyncCheck.plain(domain: "CKErrorDomain", code: 25), "Your iCloud storage is full")
        XCTAssertEqual(SyncCheck.plain(domain: "CKErrorDomain", code: 9), "This device is not signed in to iCloud")
        for code in [3, 4, 6, 7, 23] {
            XCTAssertEqual(SyncCheck.plain(domain: "CKErrorDomain", code: code), "iCloud could not be reached \u{2014} it tries again by itself")
        }
        XCTAssertEqual(SyncCheck.plain(domain: "CKErrorDomain", code: 26), "The copy in iCloud was reset")
        XCTAssertEqual(SyncCheck.plain(domain: "CKErrorDomain", code: 99), "iCloud said no (99)")
        XCTAssertEqual(SyncCheck.plain(domain: "", code: 0), "It stopped without saying why")
        XCTAssertEqual(SyncCheck.plain(domain: "NSCocoaErrorDomain", code: 134_400), "Something went wrong (134400)")
    }

    func testWhenIsSaidInTheDevicesOwnTime() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 7_200)!
        let now = isoMoment("2026-10-05T12:00:00.000Z")!
        XCTAssertEqual(SyncCheck.when(nil, now: now, calendar: cal), "never")
        XCTAssertEqual(SyncCheck.when(iso: "2026-10-05T11:52:00.000Z", now: now, calendar: cal), "today 13:52")
        XCTAssertEqual(SyncCheck.when(iso: "2026-10-02T20:10:00Z", now: now, calendar: cal), "2 Oct 22:10")
        XCTAssertEqual(SyncCheck.when(iso: "2026-10-04T22:30:00.000Z", now: now, calendar: cal), "today 00:30",
                       "just after midnight his time is today, though it is still yesterday in world time")
        XCTAssertEqual(SyncCheck.when(iso: "not a time", now: now, calendar: cal), "never")
    }
}
