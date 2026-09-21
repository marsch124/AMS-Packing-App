import XCTest
@testable import PackingCore

// Ported from tests/model.test.mjs — backup counts + the shrink guard, and the
// backup reminders (#13).
final class BackupStateTests: XCTestCase {
    override func tearDown() { PackingEnv.reset(); super.tearDown() }

    let NOW = "2026-08-20T12:00:00.000Z"

    // ---- Backup counts + shrink guard (data-safety hardening) ----

    // JS: 'backupCounts: empty payload is all zeros'
    func testBackupCountsEmptyPayloadIsAllZeros() {
        XCTAssertEqual(backupCounts(json: [:]), BackupCounts(items: 0, templates: 0, events: 0, actions: 0))
        XCTAssertEqual(backupCounts(), BackupCounts(items: 0, templates: 0, events: 0, actions: 0))
    }

    // JS: 'backupCounts: counts unique catalog items, templates, events, actions'
    // (over the invented mini-seed — see the note at the bottom of CatalogueTests.swift)
    func testBackupCountsCountsUniqueCatalogItemsTemplatesEventsActions() {
        let lists = miniSeedLists()
        let c = backupCounts(lists: lists, events: [newEvent(name: "A"), newEvent(name: "B")], actions: [ActionItem(id: "x")])
        XCTAssertEqual(c.templates, lists.count)
        XCTAssertEqual(c.events, 2)
        XCTAssertEqual(c.actions, 1)
        XCTAssertGreaterThan(c.items, 0, "seed has catalog items")
        // Unique items <= total per-template copies (merge-by-name collapses duplicates).
        let totalCopies = lists.reduce(0) { $0 + $1.items.count }
        XCTAssertLessThanOrEqual(c.items, totalCopies)
        // (the raw form gives the same answer for the same payload)
        let raw: JSONValue = ["lists": .array(lists.map { $0.json }), "events": [["name": "A"], ["name": "B"]], "actions": [["id": "x"]]]
        XCTAssertEqual(backupCounts(json: raw), c)
    }

    // JS: 'backupShrinks: flags a replace that loses more than half the catalog'
    func testBackupShrinksFlagsAReplaceThatLosesMoreThanHalfTheCatalog() {
        XCTAssertEqual(backupShrinks(BackupCounts(items: 383), BackupCounts(items: 380)), false)   // small drop is fine
        XCTAssertEqual(backupShrinks(BackupCounts(items: 383), BackupCounts(items: 100)), true)    // lost most of it
        XCTAssertEqual(backupShrinks(BackupCounts(items: 383), BackupCounts(items: 0)), true)      // going to empty
        XCTAssertEqual(backupShrinks(BackupCounts(items: 0), BackupCounts(items: 0)), false)       // nothing to lose
        XCTAssertEqual(backupShrinks(BackupCounts(items: 0), BackupCounts(items: 5)), false)       // growing is fine
    }

    // --- Backup reminders (#13) ---------------------------------------------------

    // JS: 'newestChangeAt: picks the latest stamp across every group'
    func testNewestChangeAtPicksTheLatestStampAcrossEveryGroup() {
        let events: JSONValue = [["updatedAt": "2026-08-01T09:00:00.000Z"], ["createdAt": "2026-08-03T09:00:00.000Z"]]
        let lists: JSONValue = [["updatedAt": "2026-08-11T09:00:00.000Z"]]
        let actions: JSONValue = [["updatedAt": "2026-08-05T09:00:00.000Z"]]
        XCTAssertEqual(newestChangeAt(json: [events, lists, actions]), "2026-08-11T09:00:00.000Z")
        XCTAssertEqual(newestChangeAt(), "", "nothing at all reads as no change")
        XCTAssertEqual(newestChangeAt(json: [[], nil, [[:], nil]]), "", "rows without stamps are skipped")
    }

    // JS: 'backupState: an empty install is never nagged'
    func testBackupStateAnEmptyInstallIsNeverNagged() {
        let s = backupState(lastBackupAt: "", hasData: false, now: NOW)
        XCTAssertEqual(s.level, "ok")
        XCTAssertEqual(s.unsaved, false)
    }

    // JS: 'backupState: stays silent when nothing changed since the backup, however long ago'
    func testBackupStateStaysSilentWhenNothingChangedSinceTheBackup() throws {
        let s = backupState(
            lastBackupAt: "2026-01-01T10:00:00.000Z",   // 200+ days ago
            changedAt: "2025-12-30T10:00:00.000Z",      // but nothing touched since
            hasData: true,
            now: NOW
        )
        XCTAssertEqual(s.level, "ok", "a quiet year is not a risk")
        XCTAssertEqual(s.unsaved, false)
        XCTAssertGreaterThan(try XCTUnwrap(s.days), BACKUP_URGENT_DAYS, "the age is still reported, it just does not nag")
    }

    // JS: 'backupState: escalates amber then red once there are unsaved changes'
    func testBackupStateEscalatesAmberThenRedOnceThereAreUnsavedChanges() throws {
        let nowDate = try XCTUnwrap(ISO8601DateFormatterBox.date(from: NOW))
        func at(_ days: Int) -> String { jsISOString(nowDate.addingTimeInterval(-Double(days) * 86_400)) }
        func stateAfter(_ days: Int) -> BackupState {
            backupState(lastBackupAt: at(days), changedAt: NOW, hasData: true, now: NOW)
        }
        XCTAssertEqual(stateAfter(3).level, "ok", "a few days with changes is fine")
        XCTAssertEqual(stateAfter(BACKUP_DUE_DAYS).level, "due")
        XCTAssertEqual(stateAfter(BACKUP_URGENT_DAYS - 1).level, "due")
        XCTAssertEqual(stateAfter(BACKUP_URGENT_DAYS).level, "urgent")
        XCTAssertEqual(stateAfter(BACKUP_DUE_DAYS).days, BACKUP_DUE_DAYS)
    }

    // JS: 'backupState: a same-day edit after a same-day backup still counts as unsaved'
    func testBackupStateASameDayEditAfterASameDayBackupStillCountsAsUnsaved() {
        let s = backupState(
            lastBackupAt: "2026-08-20T08:00:00.000Z",
            changedAt: "2026-08-20T11:00:00.000Z",
            hasData: true,
            now: NOW
        )
        XCTAssertEqual(s.unsaved, true, "the timestamp, not the date, decides")
        XCTAssertEqual(s.level, "ok", "but it is not overdue yet, so no nag")
    }

    // JS: 'backupState: a legacy date-only backup stamp errs towards nagging'
    func testBackupStateALegacyDateOnlyBackupStampErrsTowardsNagging() {
        let s = backupState(
            lastBackupAt: "2026-08-20",                 // old date-only key
            changedAt: "2026-08-20T11:00:00.000Z",
            hasData: true,
            now: NOW
        )
        XCTAssertEqual(s.unsaved, true)
    }

    // JS: 'backupState: never backed up escalates from first use'
    func testBackupStateNeverBackedUpEscalatesFromFirstUse() throws {
        let fresh = backupState(lastBackupAt: "", firstUseAt: "2026-08-18", hasData: true, now: NOW)
        XCTAssertEqual(fresh.never, true)
        XCTAssertEqual(fresh.unsaved, true)
        XCTAssertEqual(fresh.level, "ok", "two days in, do not pounce on a new user")

        let old = backupState(lastBackupAt: "", firstUseAt: "2026-01-01", hasData: true, now: NOW)
        XCTAssertEqual(old.level, "urgent", "months of use and no file ever saved is the worst case")
        XCTAssertGreaterThan(try XCTUnwrap(old.days), BACKUP_URGENT_DAYS)
    }

    // JS: 'backupSnoozeDays: dismissing buys less time the more overdue you are'
    func testBackupSnoozeDaysDismissingBuysLessTimeTheMoreOverdueYouAre() {
        XCTAssertEqual(backupSnoozeDays("due"), 7)
        XCTAssertEqual(backupSnoozeDays("urgent"), 1)
    }

    // JS: 'oldestCreatedAt: dates a device from its earliest trip, not the newest'
    func testOldestCreatedAtDatesADeviceFromItsEarliestTrip() {
        let events: JSONValue = [["createdAt": "2026-03-01T00:00:00.000Z"], ["createdAt": "2025-07-14T00:00:00.000Z"]]
        let lists: JSONValue = [["createdAt": "2026-01-05T00:00:00.000Z"]]
        XCTAssertEqual(oldestCreatedAt(json: [events, lists]), "2025-07-14T00:00:00.000Z")
        XCTAssertEqual(oldestCreatedAt(json: [[], [[:]]]), "", "rows with no stamp contribute nothing")
    }

    // MARK: --- not in the JS suite ---

    func testTheStampsAreReadOffRealRowsOfEveryKind() {
        let events = [newEvent(name: "A", createdAt: "2026-03-01T00:00:00.000Z", updatedAt: "2026-08-01T09:00:00.000Z"),
                      newEvent(name: "B", createdAt: "2025-07-14T00:00:00.000Z", updatedAt: "2025-07-14T00:00:00.000Z")]
        let lists = [newList(name: "L", createdAt: "2026-01-05T00:00:00.000Z", updatedAt: "2026-08-11T09:00:00.000Z")]
        let actions = [newAction(text: "Buy gas", createdAt: "2026-08-05T09:00:00.000Z", updatedAt: "2026-08-05T09:00:00.000Z")]
        let kits = [newKit(name: "Wash bag", createdAt: "2026-08-12T07:00:00.000Z", updatedAt: "2026-08-12T07:00:00.000Z")]
        XCTAssertEqual(newestChangeAt(events, lists, actions, kits), "2026-08-12T07:00:00.000Z")
        XCTAssertEqual(oldestCreatedAt(events, lists), "2025-07-14T00:00:00.000Z")
        XCTAssertEqual(oldestCreatedAt(), "")
        XCTAssertEqual(oldestCreatedAt([TripEvent](), [newList(name: "no stamp", createdAt: "")]), "")
    }

    func testBackupStateCornersDaysAndJson() {
        // No data: `days` is null, and `never` still tells the truth.
        XCTAssertEqual(backupState(lastBackupAt: "2026-08-01", hasData: false, now: NOW),
                       BackupState(level: "ok", days: nil, never: false, unsaved: false))
        XCTAssertEqual(backupState(now: NOW).json, ["level": "ok", "days": nil, "never": true, "unsaved": false])
        // Nothing to date it from at all: counts from today.
        XCTAssertEqual(backupState(hasData: true, now: NOW), BackupState(level: "ok", days: 0, never: true, unsaved: true))
        // A backup stamped in the future never gives negative days; junk reads as 0 days.
        XCTAssertEqual(backupState(lastBackupAt: "2026-09-01T00:00:00.000Z", changedAt: "2026-08-01", hasData: true, now: NOW).days, 0)
        XCTAssertEqual(backupState(lastBackupAt: "yesterday", changedAt: "zzz", hasData: true, now: NOW),
                       BackupState(level: "ok", days: 0, never: false, unsaved: true))
        // No changedAt at all reads as unsaved — the safe direction.
        XCTAssertEqual(backupState(lastBackupAt: "2026-06-01", hasData: true, now: NOW),
                       BackupState(level: "urgent", days: 80, never: false, unsaved: true))
        // `now` defaults to the (injectable) clock.
        PackingEnv.freeze(at: "2026-08-20T12:00:00.000Z")
        XCTAssertEqual(backupState(lastBackupAt: "2026-08-01", changedAt: "2026-08-02", hasData: true).days, 19)
    }

    func testBackupCountsRawPayloadCountsJunkEntriesAndSurvivesWhatWouldThrow() {
        let ok: JSONValue = ["lists": [["name": "A", "items": [["name": "Tent"], ["name": "tent "], ["name": "  "], 5]], "junk"],
                             "events": [nil, 1], "actions": "nope"]
        XCTAssertEqual(backupCounts(json: ok), BackupCounts(items: 1, templates: 2, events: 2, actions: 0))
        // A null list, or a null item, throws inside the JS walk: `items` falls to 0.
        XCTAssertEqual(backupCounts(json: ["lists": [["items": [["name": "Tent"]]], nil]]).items, 0)
        XCTAssertEqual(backupCounts(json: ["lists": [["items": [["name": "Tent"], nil]]]]).items, 0)
        XCTAssertEqual(backupCounts(json: nil), BackupCounts())
        // A decoded backup: only the lists are walked — `things` are not counted (as in the JS).
        let file = BackupFile(lists: [newList(name: "A", items: [newItem(name: "Tent")])], things: [newItem(name: "Loose thing")])
        XCTAssertEqual(backupCounts(file).items, 1)
    }
}
