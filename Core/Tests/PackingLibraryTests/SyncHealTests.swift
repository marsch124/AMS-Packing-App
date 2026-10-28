import XCTest
@testable import PackingLibrary

/// A sync that hangs heals itself (0.104 — his "can we harden this?", 28 Oct 2026): when, and when not,
/// the app restarts its connection to iCloud (`SyncHeal`).
final class SyncHealTests: XCTestCase {
    /// His clock: Sweden in October, two hours ahead of world time.
    private var his: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 7_200)!
        return cal
    }
    /// 07:46:04 his time, 28 Oct 2026 — when the send hung on his Mac.
    private let started = isoMoment("2026-10-28T05:46:04.000Z")!
    private func at(_ minutes: Double) -> Date { started.addingTimeInterval(minutes * 60) }

    /// A receive running since `started` with no end, after a good send and receive before it.
    private var hangingReceive: SyncCheck {
        SyncCheck(events: [SyncCheck.Event(type: 1, ok: false, at: started, unfinished: true),
                           SyncCheck.Event(type: 2, ok: true, at: at(-2)), SyncCheck.Event(type: 1, ok: true, at: at(-3))])
    }
    /// 28 Oct: the SEND hung (held back by the system), and the receive behind it never ran.
    private var hangingSend: SyncCheck {
        SyncCheck(events: [SyncCheck.Event(type: 2, ok: false, at: started, unfinished: true),
                           SyncCheck.Event(type: 1, ok: true, at: at(-3))])
    }

    private func decide(_ c: SyncCheck?, _ minutes: Double, inFront: Bool = true, pageOpen: Bool = false,
                        restarts: [SyncHeal.Restart] = [], cameForward: Date? = nil, awake: Date = .distantPast,
                        launched: Date = .distantPast) -> SyncHeal.Decision {
        SyncHeal.decide(c, now: at(minutes), awake: awake, cameForward: cameForward, inFront: inFront,
                        pageOpen: pageOpen, restarts: restarts, launched: launched)
    }

    /// Five minutes with no end: restart. Before that, nothing — a healthy exchange ends in seconds.
    func testAnExchangeRunningFiveMinutesWithNoEndIsRestarted() {
        let receive = SyncCheck.Running(sending: false, since: started)
        XCTAssertEqual(decide(hangingReceive, 4 + 59.0 / 60), .nothing, "restarted before five minutes")
        XCTAssertEqual(decide(hangingReceive, 5), .restart(receive), "a receive with no end for five minutes was not restarted")
        // The send that hung on 28 Oct counts the same: one exchange at a time, so it stops receiving too.
        XCTAssertEqual(decide(hangingSend, 5), .restart(SyncCheck.Running(sending: true, since: started)),
                       "a send with no end for five minutes was not restarted")
        // Nothing running, or nothing read: nothing to do.
        let good = SyncCheck(events: [SyncCheck.Event(type: 2, ok: true, at: at(1)), SyncCheck.Event(type: 1, ok: true, at: at(2))])
        XCTAssertEqual(decide(good, 60), .nothing)
        XCTAssertEqual(decide(nil, 60), .nothing)
        // The iPhone pauses an exchange with the app: its five minutes start when the app came back.
        XCTAssertEqual(decide(hangingReceive, 7, awake: at(3)), .nothing, "counted from before the app came back")
        XCTAssertEqual(decide(hangingReceive, 8, awake: at(3)), .restart(receive))
        // After a restart, the next five minutes count from the restart.
        let one = [SyncHeal.Restart(at: at(5), why: .receiving)]
        XCTAssertEqual(decide(hangingReceive, 9, restarts: one), .nothing, "restarted again before five minutes")
        XCTAssertEqual(decide(hangingReceive, 10, restarts: one), .restart(receive))
    }

    /// Begun while the app was not in front — TestFlight opened 0.103 behind his windows and the system
    /// held its send back — it is restarted one minute after the app comes to the front, not five.
    func testOneBegunBehindIsRestartedAMinuteAfterTheAppCameToTheFront() {
        let front = at(2)
        XCTAssertEqual(decide(hangingSend, 2.5, inFront: false), .nothing)
        XCTAssertEqual(decide(hangingSend, 2.9, cameForward: front), .nothing, "restarted before a minute in front")
        XCTAssertEqual(decide(hangingSend, 3, cameForward: front), .restart(SyncCheck.Running(sending: true, since: started)),
                       "an exchange begun behind was not restarted a minute after the app came to the front")
        // One begun AFTER the app came to the front waits the five minutes.
        XCTAssertEqual(decide(hangingSend, 3, cameForward: at(-1)), .nothing, "begun in front, restarted after a minute")
        // Not in front: it waits — a request made now would be held back again.
        XCTAssertEqual(decide(hangingSend, 30, inFront: false), .wait(.behind, SyncCheck.Running(sending: true, since: started)))
    }

    /// Never with a page holding changes not confirmed with Done, or a save under way: it waits.
    func testItWaitsWhileAPageHoldsChanges() {
        let r = SyncCheck.Running(sending: false, since: started)
        XCTAssertEqual(decide(hangingReceive, 6, pageOpen: true), .wait(.page, r), "restarted with a page holding changes")
        XCTAssertEqual(decide(hangingReceive, 6, pageOpen: false), .restart(r))
        XCTAssertEqual(SyncHeal.words(.page, now: at(6), calendar: his),
                       "Restarts the connection as soon as the open page is closed.")
    }

    /// At most three restarts by itself in an hour — no loops. Restart sync, pressed, is never counted.
    func testAtMostThreeRestartsAnHour() {
        let r = SyncCheck.Running(sending: false, since: started)
        let three = [5.0, 10, 15].map { SyncHeal.Restart(at: at($0), why: .receiving) }
        XCTAssertEqual(decide(hangingReceive, 20, restarts: three), .wait(.tooOften(until: at(65)), r),
                       "a fourth restart within the hour")
        XCTAssertEqual(decide(hangingReceive, 65, restarts: three), .restart(r), "an hour after the first, not allowed again")
        let pressed = three.dropLast() + [SyncHeal.Restart(at: at(15), why: .pressed)]
        XCTAssertEqual(decide(hangingReceive, 20, restarts: Array(pressed)), .restart(r), "a press of Restart sync counted against the app")
        XCTAssertEqual(SyncHeal.words(.tooOften(until: at(65)), now: at(20), calendar: his),
                       "It restarted 3 times in the last hour \u{2014} press Restart sync to try again.")
    }

    /// A restart that did not take stops the restarts of that run; the next launch starts afresh.
    func testARestartThatDidNotTakeIsNotRepeated() {
        let r = SyncCheck.Running(sending: false, since: started)
        let failed = [SyncHeal.Restart(at: at(5), why: .receiving, ok: false)]
        XCTAssertEqual(decide(hangingReceive, 11, restarts: failed, launched: at(-1)), .wait(.didNotHelp, r))
        XCTAssertEqual(decide(hangingReceive, 11, restarts: failed, launched: at(6)), .restart(r),
                       "a restart that failed in the run before stopped this one's")
        // Whether it took: iCloud's setting-up of the new connection, begun after it.
        let restart = SyncHeal.Restart(at: at(5), why: .receiving)
        func setup(_ ok: Bool, _ m: Double, unfinished: Bool = false) -> SyncCheck {
            SyncCheck(events: [], setup: SyncCheck.Event(type: 0, ok: ok, at: at(m), unfinished: unfinished))
        }
        XCTAssertNil(SyncHeal.took(restart, check: setup(true, 1)), "the setting-up from before the restart was taken for its own")
        XCTAssertNil(SyncHeal.took(restart, check: setup(false, 5.1, unfinished: true)))
        XCTAssertEqual(SyncHeal.took(restart, check: setup(true, 5.1)), true)
        XCTAssertEqual(SyncHeal.took(restart, check: setup(false, 5.1)), false)
    }

    /// The words on the card and after Home's line: what happened, today, in his time — no computer talk.
    func testTheWordsSayWhatHappened() {
        let now = at(10)
        XCTAssertEqual(SyncHeal.words(SyncHeal.Restart(at: at(5), why: .receiving), now: now, calendar: his),
                       "Receiving was stuck \u{2014} restarted the connection at 07:51.")
        XCTAssertEqual(SyncHeal.words(SyncHeal.Restart(at: at(5), why: .sending), now: now, calendar: his),
                       "Sending was stuck \u{2014} restarted the connection at 07:51.")
        XCTAssertEqual(SyncHeal.words(SyncHeal.Restart(at: at(5), why: .pressed), now: now, calendar: his),
                       "Restarted the connection at 07:51.")
        XCTAssertEqual(SyncHeal.words(SyncHeal.Restart(at: at(5), why: .receiving, ok: false), now: now, calendar: his),
                       "Restarting the connection at 07:51 did not help \u{2014} quit Packing and open it again.")
        XCTAssertNil(SyncHeal.words(SyncHeal.Restart(at: at(5), why: .receiving), now: at(5 + 24 * 60), calendar: his),
                     "yesterday's restart is still said")
        XCTAssertEqual(SyncHeal.line("In sync \u{00B7} today 07:52", restart: SyncHeal.Restart(at: at(5), why: .receiving),
                                     now: now, calendar: his),
                       "In sync \u{00B7} today 07:52. Receiving was stuck \u{2014} restarted the connection at 07:51.")
        XCTAssertEqual(SyncHeal.line("In sync \u{00B7} today 07:52", restart: nil, now: now, calendar: his), "In sync \u{00B7} today 07:52")
        XCTAssertEqual(SyncHeal.line("Receiving\u{2026}", restart: SyncHeal.Restart(at: at(5), why: .pressed), now: now, calendar: his),
                       "Receiving\u{2026} Restarted the connection at 07:51.", "a full stop after the dots")
        // Kept on the device: the newest twenty, newest first in Copy details.
        var kept: [SyncHeal.Restart] = []
        for n in 0..<25 { kept = SyncHeal.noting(SyncHeal.Restart(at: at(Double(n)), why: .pressed), in: kept) }
        XCTAssertEqual(kept.count, SyncHeal.keep)
        XCTAssertEqual(kept.last?.at, at(24))
        XCTAssertTrue(SyncHeal.details(kept).first?.contains("restarted the connection 2026-10-28T06:10:04Z (Restart sync pressed)") ?? false,
                      SyncHeal.details(kept).first ?? "")
    }

    /// The store's own record says when iCloud last set up a connection (type 0) — read beside, never
    /// among, the sends and receives.
    func testTheSettingUpIsReadOnItsOwn() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("syncheal-\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: file) }
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(file.path, &db), SQLITE_OK)
        for sql in ["CREATE TABLE ANSCKEVENT (Z_PK INTEGER PRIMARY KEY, ZCLOUDKITEVENTTYPE INTEGER, ZSUCCEEDED INTEGER, ZERRORDOMAIN VARCHAR, ZERRORCODE INTEGER, ZSTARTEDAT TIMESTAMP, ZENDEDAT TIMESTAMP)",
                    "CREATE TABLE ZRECORD (Z_PK INTEGER PRIMARY KEY, ZTABLE VARCHAR, ZUPDATEDAT TIMESTAMP)",
                    "CREATE TABLE ANSCKRECORDMETADATA (Z_PK INTEGER PRIMARY KEY, ZENTITYPK INTEGER, ZENTITYID INTEGER, ZNEEDSUPLOAD INTEGER)",
                    "CREATE TABLE Z_PRIMARYKEY (Z_ENT INTEGER PRIMARY KEY, Z_NAME VARCHAR)",
                    "INSERT INTO ANSCKEVENT (ZCLOUDKITEVENTTYPE, ZSUCCEEDED, ZERRORCODE, ZSTARTEDAT, ZENDEDAT) VALUES (0, 1, 0, 100, 101)",
                    "INSERT INTO ANSCKEVENT (ZCLOUDKITEVENTTYPE, ZSUCCEEDED, ZERRORCODE, ZSTARTEDAT, ZENDEDAT) VALUES (0, 0, 0, 500, 502)",
                    "INSERT INTO ANSCKEVENT (ZCLOUDKITEVENTTYPE, ZSUCCEEDED, ZERRORCODE, ZSTARTEDAT, ZENDEDAT) VALUES (1, 1, 0, 300, 301)"] {
            XCTAssertEqual(sqlite3_exec(db, sql, nil, nil, nil), SQLITE_OK)
        }
        sqlite3_close(db)
        let c = try XCTUnwrap(SyncCheck.read(at: file))
        XCTAssertEqual(c.setup, SyncCheck.Event(type: 0, ok: false, at: Date(timeIntervalSinceReferenceDate: 502)),
                       "the newest setting-up was not read")
        XCTAssertEqual(c.attempts.count, 1, "a setting-up was read as a send or receive")
        XCTAssertNil(c.problem, "a setting-up that failed was taken for a failed send or receive")
    }
}

import SQLite3
