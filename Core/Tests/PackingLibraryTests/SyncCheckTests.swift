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
    /// `unfinished`: events (type, started at) with NO end, as the store keeps one still running
    /// (0.92); `written`: each record's last write, seconds since 2001 (nil = none).
    private func makeStore(events: [(Int, Bool, String, Int, Double)], records: [(String, Bool?)],
                           unfinished: [(Int, Double)] = [], written: [Double?] = []) {
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(file.path, &db), SQLITE_OK)
        defer { sqlite3_close(db) }
        run(db, """
            CREATE TABLE ANSCKEVENT (Z_PK INTEGER PRIMARY KEY, ZCLOUDKITEVENTTYPE INTEGER, ZSUCCEEDED INTEGER,
                ZERRORDOMAIN VARCHAR, ZERRORCODE INTEGER, ZSTARTEDAT TIMESTAMP, ZENDEDAT TIMESTAMP);
            CREATE TABLE ZRECORD (Z_PK INTEGER PRIMARY KEY, ZTABLE VARCHAR, ZUPDATEDAT TIMESTAMP);
            CREATE TABLE ANSCKRECORDMETADATA (Z_PK INTEGER PRIMARY KEY, ZENTITYPK INTEGER, ZENTITYID INTEGER, ZNEEDSUPLOAD INTEGER);
            CREATE TABLE Z_PRIMARYKEY (Z_ENT INTEGER PRIMARY KEY, Z_NAME VARCHAR);
            INSERT INTO Z_PRIMARYKEY VALUES (1, 'Record'), (2, 'Something else');
            """)
        for (type, ok, domain, code, at) in events {
            let d = domain.isEmpty ? "NULL" : "'\(domain)'"
            run(db, "INSERT INTO ANSCKEVENT (ZCLOUDKITEVENTTYPE, ZSUCCEEDED, ZERRORDOMAIN, ZERRORCODE, ZSTARTEDAT, ZENDEDAT) VALUES (\(type), \(ok ? 1 : 0), \(d), \(code), \(at - 1), \(at))")
        }
        for (type, started) in unfinished {
            run(db, "INSERT INTO ANSCKEVENT (ZCLOUDKITEVENTTYPE, ZSUCCEEDED, ZERRORCODE, ZSTARTEDAT, ZENDEDAT) VALUES (\(type), 0, 0, \(started), NULL)")
        }
        // A meta row of ANOTHER entity with the same primary key must not count as the record's.
        run(db, "INSERT INTO ANSCKRECORDMETADATA (ZENTITYPK, ZENTITYID, ZNEEDSUPLOAD) VALUES (1, 2, 0)")
        for (n, (table, inCloud)) in records.enumerated() {
            let at = n < written.count ? written[n].map { "\($0)" } ?? "NULL" : "NULL"
            run(db, "INSERT INTO ZRECORD (Z_PK, ZTABLE, ZUPDATEDAT) VALUES (\(n + 1), '\(table)', \(at))")
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
        XCTAssertEqual(SyncCheck.light(usesICloud: true, check: c, now: Date(timeInterval: 1_400, since: ref)), .stuck)
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
        XCTAssertEqual(SyncCheck.light(usesICloud: true, check: c, now: Date(timeInterval: 1_200, since: ref)), .inSync)
    }

    /// iCloud on, and nothing to read: say so — not a green "Working" (item 25). Since 0.92 also
    /// when the record holds no send or receive that ever went well: nothing says the devices are in step.
    func testTheCardSaysItCannotTellWhenItCannotRead() {
        let now = Date()
        XCTAssertNil(SyncCheck.read(at: file), "a store file that is not there")
        XCTAssertEqual(SyncCheck.light(usesICloud: true, check: nil, now: now), .unknown)
        XCTAssertEqual(SyncCheck.light(usesICloud: true, check: nil, now: now).word, "Can\u{2019}t tell")
        XCTAssertEqual(SyncCheck.light(usesICloud: false, check: nil, now: now), .off)
        XCTAssertEqual(SyncCheck.light(usesICloud: false, check: SyncCheck(), now: now), .off)
        XCTAssertEqual(SyncCheck.light(usesICloud: true, check: SyncCheck(), now: now), .unknown,
                       "no send or receive on record is no proof of being in step")
    }

    /// Equal counts keep one order, whatever order the store gave them in (item 20).
    func testNotInICloudYetKeepsItsOrder() {
        var c = SyncCheck()
        c.notSent = ["photos": 2, "trips": 3, "meta": 1, "entries": 3, "items": 2, "kits": 1, "zzz-new": 1]
        let words = "3 trips, 3 trip lines, 2 things, 2 photos, 1 kit, 1 note, 1 zzz-new"   // one of a kind since 0.92
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

    // MARK: The sync light (0.92 — his yes of 19 Oct 2026)

    /// His clock: Sweden in October, two hours ahead of world time.
    private var his: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 7_200)!
        return cal
    }

    /// His field report (16 Oct 2026): a receive that never ended showed as "FAILED 0 — It stopped
    /// without saying why". With no end it is RUNNING when it is the newest receive, and left behind
    /// when a later one started (the app went away while it ran) — never a failure.
    func testAReceiveWithNoEndIsRunningNotFailed() throws {
        makeStore(events: [(1, true, "", 0, 1_000), (2, true, "", 0, 1_100)], records: [("items", false)],
                  unfinished: [(1, 900), (1, 1_200)])
        let c = try XCTUnwrap(SyncCheck.read(at: file))
        XCTAssertNil(c.problem, "a receive still running was read as a failure")
        XCTAssertEqual(c.receiving, SyncCheck.Running(sending: false, since: Date(timeInterval: 1_200, since: ref)),
                       "the newest receive, with no end, is not running")
        XCTAssertNil(c.sending)
        XCTAssertEqual(c.lastReceived, Date(timeInterval: 1_000, since: ref))
        XCTAssertEqual(c.attempts.filter(\.unfinished).count, 2)
        let started = Date(timeInterval: 1_200, since: ref)
        XCTAssertEqual(SyncCheck.light(usesICloud: true, check: c, now: started.addingTimeInterval(120)), .receiving)
        XCTAssertEqual(SyncCheck.light(usesICloud: true, check: c, now: started.addingTimeInterval(599)), .receiving,
                       "running for less than ten minutes is fine")
        XCTAssertEqual(SyncCheck.light(usesICloud: true, check: c, now: started.addingTimeInterval(600)), .stuck,
                       "running ten minutes with no end is hung")
        let details = c.details(device: "Mac", version: "0.92 (1)")
        XCTAssertTrue(details.contains("receive running since"), details)
        XCTAssertTrue(details.contains("receive never ended, started"), details)
        XCTAssertFalse(details.contains("FAILED"), details)
    }

    /// Ten minutes with no end = hung, in his words; counted from when the app came to the front
    /// when that was later (the iPhone pauses a receive in the background with the app).
    func testARunningExchangeHangsAfterTenMinutes() {
        let started = isoMoment("2026-10-16T05:57:00.000Z")!
        let c = SyncCheck(events: [SyncCheck.Event(type: 1, ok: false, at: started, unfinished: true),
                                   SyncCheck.Event(type: 2, ok: true, at: started.addingTimeInterval(-60)),
                                   SyncCheck.Event(type: 1, ok: true, at: started.addingTimeInterval(-120))])
        let almost = started.addingTimeInterval(9 * 60 + 59), ten = started.addingTimeInterval(10 * 60)
        XCTAssertEqual(SyncCheck.light(usesICloud: true, check: c, now: almost), .receiving)
        XCTAssertEqual(c.runningWords(now: almost, calendar: his)?.words, "Receiving from iCloud since 07:57.")
        XCTAssertEqual(c.runningWords(now: almost, calendar: his)?.hung, false)
        XCTAssertEqual(SyncCheck.light(usesICloud: true, check: c, now: ten), .stuck)
        XCTAssertEqual(c.runningWords(now: ten, calendar: his)?.words,
                       "Receiving from iCloud has hung since 07:57 \u{2014} quit Packing and open it again.")
        XCTAssertEqual(c.runningWords(now: ten, calendar: his)?.hung, true)
        XCTAssertEqual(SyncCheck.line(.stuck, check: c, now: ten, calendar: his), "Stuck \u{2014} Receiving has hung since 07:57")
        // Back in front at 08:05: its ten minutes start again there.
        let back = started.addingTimeInterval(8 * 60)
        XCTAssertEqual(SyncCheck.light(usesICloud: true, check: c, now: ten, awake: back), .receiving)
        XCTAssertEqual(SyncCheck.light(usesICloud: true, check: c, now: back.addingTimeInterval(600), awake: back), .stuck)
        // Another day says the day; a send says so.
        let send = SyncCheck(events: [SyncCheck.Event(type: 2, ok: false, at: started, unfinished: true)])
        let nextDay = started.addingTimeInterval(86_400)
        XCTAssertEqual(send.runningWords(now: nextDay, calendar: his)?.words,
                       "Sending to iCloud has hung since 16 Oct 07:57 \u{2014} quit Packing and open it again.")
        XCTAssertEqual(SyncCheck.light(usesICloud: true, check: send, now: started.addingTimeInterval(30)), .sending)
    }

    /// Changes not in iCloud: "Sending…" at first; Stuck once the oldest has waited half an hour
    /// with no good send in that half hour. How long it waited is read from the store: its record's
    /// last write — the records iCloud has do not count.
    func testChangesThatWaitHalfAnHourAreStuck() throws {
        makeStore(events: [(2, true, "", 0, 1_100), (1, true, "", 0, 1_150)],
                  records: [("items", nil), ("trips", false), ("entries", true)],
                  written: [3_000, 1_000, 2_000])
        let c = try XCTUnwrap(SyncCheck.read(at: file))
        XCTAssertEqual(c.waitingSince, Date(timeInterval: 2_000, since: ref), "the oldest WAITING change")
        let waited = Date(timeInterval: 2_000, since: ref)
        XCTAssertEqual(SyncCheck.light(usesICloud: true, check: c, now: waited.addingTimeInterval(29 * 60 + 59)), .sending)
        XCTAssertNil(c.waitedWords(now: waited.addingTimeInterval(29 * 60 + 59)))
        let half = waited.addingTimeInterval(30 * 60)
        XCTAssertEqual(SyncCheck.light(usesICloud: true, check: c, now: half), .stuck, "half an hour waiting, nothing sent")
        XCTAssertEqual(c.waitedWords(now: half, calendar: his)?.hasPrefix("Waiting since "), true)
        XCTAssertEqual(c.waitedWords(now: half, calendar: his)?.hasSuffix(" \u{2014} nothing has reached iCloud for half an hour."), true)
        // A good send in that half hour: still on its way.
        let moving = SyncCheck(events: [SyncCheck.Event(type: 2, ok: true, at: half.addingTimeInterval(-600))],
                               notSent: ["items": 2], waitingSince: waited)
        XCTAssertEqual(SyncCheck.light(usesICloud: true, check: moving, now: half), .sending)
        XCTAssertEqual(SyncCheck.line(.sending, check: moving, now: half), "Sending 2 changes\u{2026}")
        XCTAssertEqual(SyncCheck.line(.stuck, check: c, now: half, calendar: his).hasPrefix("Stuck \u{2014} 2 changes waiting since "), true,
                       SyncCheck.line(.stuck, check: c, now: half, calendar: his))
        // Nothing waiting: no waiting time, whatever is handed in.
        XCTAssertNil(SyncCheck(events: [], notSent: [:], waitingSince: waited).waitingSince)
    }

    /// The light's words and colours, and which rule wins.
    func testTheLightsWordsAndColours() {
        XCTAssertEqual(SyncCheck.Light.allCases.map(\.word),
                       ["iCloud off", "Can\u{2019}t tell", "In sync", "Sending\u{2026}", "Receiving\u{2026}", "Stuck"])
        XCTAssertEqual(SyncCheck.Light.allCases.map(\.colour), [.grey, .grey, .green, .orange, .orange, .red])
        let now = isoMoment("2026-10-19T10:00:00.000Z")!
        let good = [SyncCheck.Event(type: 2, ok: true, at: now.addingTimeInterval(-300)),
                    SyncCheck.Event(type: 1, ok: true, at: now.addingTimeInterval(-200))]
        XCTAssertEqual(SyncCheck.light(usesICloud: true, check: SyncCheck(events: good), now: now), .inSync)
        // The bubble's line (0.92): In sync with the newest good exchange's time; one change or several.
        XCTAssertEqual(SyncCheck.line(.inSync, check: SyncCheck(events: good), now: now, calendar: his), "In sync \u{00B7} today 11:56")
        XCTAssertEqual(SyncCheck.line(.sending, check: SyncCheck(events: good, notSent: ["trips": 1]), now: now), "Sending 1 change\u{2026}")
        XCTAssertEqual(SyncCheck.line(.sending, check: SyncCheck(events: good), now: now), "Sending\u{2026}")
        XCTAssertEqual(SyncCheck.line(.receiving, check: nil, now: now), "Receiving\u{2026}")
        XCTAssertEqual(SyncCheck.line(.unknown, check: nil, now: now), "Can\u{2019}t tell how the sync is going")
        // A failure after the last good one beats a receive running.
        let failed = SyncCheck(events: [SyncCheck.Event(type: 1, ok: false, at: now.addingTimeInterval(-30), unfinished: true),
                                        SyncCheck.Event(type: 2, ok: false, at: now.addingTimeInterval(-60), domain: "CKErrorDomain", code: 3)] + good)
        XCTAssertEqual(SyncCheck.light(usesICloud: true, check: failed, now: now), .stuck)
        XCTAssertEqual(SyncCheck.line(.stuck, check: failed, now: now, calendar: his),
                       "Stuck \u{2014} the last send failed: iCloud could not be reached \u{2014} it tries again by itself")
        // Changes waiting beat a receive running: both orange, the words say Sending.
        let both = SyncCheck(events: [SyncCheck.Event(type: 1, ok: false, at: now.addingTimeInterval(-30), unfinished: true)] + good,
                             notSent: ["trips": 1], waitingSince: now.addingTimeInterval(-20))
        XCTAssertEqual(SyncCheck.light(usesICloud: true, check: both, now: now), .sending)
        XCTAssertEqual(SyncCheck.since(now, now: now, calendar: his), "12:00")
    }
}
