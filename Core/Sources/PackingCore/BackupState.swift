// BackupState — what a backup holds (the restore preview and the "would this shrink
// my data?" guard) and the backup reminders.
// Ported from js/model.js (`backupCounts`, `backupShrinks`, "Backup reminders (#13)").

import Foundation

// MARK: - Counts + shrink guard

/// `{ items, templates, events, actions }`.
public struct BackupCounts: Equatable, Hashable, Sendable {
    /// UNIQUE catalog items (merged by name), i.e. real things, not per-template copies.
    public var items: Int
    public var templates: Int
    public var events: Int
    public var actions: Int
    public init(items: Int = 0, templates: Int = 0, events: Int = 0, actions: Int = 0) {
        self.items = items; self.templates = templates; self.events = events; self.actions = actions
    }
    public var json: JSONValue {
        ["items": .number(Double(items)), "templates": .number(Double(templates)),
         "events": .number(Double(events)), "actions": .number(Double(actions))]
    }
}

/// Count the meaningful contents of a backup / snapshot payload ({ lists, events,
/// actions }). Powers the restore preview ("383 items · 14 templates · 5 trips")
/// and the "would this shrink my data?" guard. `items` is the count of UNIQUE
/// catalog items (merged by name), i.e. real things, not per-template copies.
public func backupCounts(lists: [PackList] = [], events: [TripEvent] = [], actions: [ActionItem] = []) -> BackupCounts {
    // Through `buildCatalog` itself, as the JS does — it is the definition of "one
    // real thing", and it spends the same ids the JS call spends.
    BackupCounts(items: buildCatalog(lists).items.count, templates: lists.count, events: events.count, actions: actions.count)
}

/// `backupCounts(file)` for a decoded backup. 🪤 As in the JS, `things` (items on no
/// template) are NOT counted: only the lists are walked.
public func backupCounts(_ backup: BackupFile) -> BackupCounts {
    backupCounts(lists: backup.lists, events: backup.events, actions: backup.actions)
}

/// `backupCounts(payload)` for a raw, un-coerced payload (the web app counts a file
/// BEFORE restoring it). The three counts are the raw array lengths, junk entries
/// included; `items` is 0 when walking the lists would have thrown in JS (a null
/// list, or a null item in one) — the `try { … } catch { items = 0 }`.
public func backupCounts(json payload: JSONValue?) -> BackupCounts {
    let lists = asArray(payload?["lists"])
    let wouldThrow = lists.contains { l in l.isNull || asArray(l["items"]).contains { $0.isNull } }
    return BackupCounts(
        items: wouldThrow ? 0 : buildCatalog(lists.compactMap { coerceList(json: $0) }).items.count,
        templates: lists.count,
        events: asArray(payload?["events"]).count,
        actions: asArray(payload?["actions"]).count
    )
}

/// Is `next` meaningfully smaller than `prev`? Used to warn before a REPLACE that
/// would wipe most of the data, and to protect the richest snapshot from eviction.
/// True when next drops to under half of prev's items, or empties a non-empty set.
public func backupShrinks(_ prev: BackupCounts = BackupCounts(), _ next: BackupCounts = BackupCounts()) -> Bool {
    let p = prev.items, n = next.items
    if p == 0 { return false }                  // nothing to lose
    if n == 0 { return true }                   // going to empty
    return Double(n) < Double(p) * 0.5          // lost more than half the catalog
}

// MARK: - Backup reminders (#13)
//
// Safari has no File System Access API, so the web app CANNOT silently write a backup
// file into a folder on the Mac. The honest answer is to make the reminder do the
// work instead: it escalates until you save, and saving is one tap from wherever you
// happen to see it.
//
// The signal is deliberately "have you changed anything since your last backup?",
// not the calendar alone. A quiet month with nothing edited is not a risk and
// should stay silent; a busy fortnight with no saved file is, and should not.

/// amber: worth saving a fresh file
public let BACKUP_DUE_DAYS = 14
/// red: this is now a real risk
public let BACKUP_URGENT_DAYS = 45

/// How long the dismiss (x) buys, in days — deliberately shorter the more overdue
/// you are, so a badly-out-of-date backup can't be waved away week after week.
public func backupSnoozeDays(_ level: String?) -> Int {
    level == "urgent" ? 1 : 7
}

/// A row that carries the two stamps the reminders read. (JS reads `row.createdAt` /
/// `row.updatedAt` off whatever it is handed: trips, templates, to-dos, kits.)
public protocol ChangeStamped {
    var createdAt: String { get }
    var updatedAt: String { get }
}
extension TripEvent: ChangeStamped {}
extension PackList: ChangeStamped {}
extension ActionItem: ChangeStamped {}
extension Kit: ChangeStamped {}

/// The oldest `createdAt` across the same groups — how long this device has been
/// in real use. Matters for someone who has NEVER saved a backup: without it, the
/// reminder would start counting from the day this version was installed and give
/// a years-old unprotected catalogue a clean bill of health for a fortnight.
public func oldestCreatedAt(_ groups: [any ChangeStamped]...) -> String {
    var oldest = ""
    for group in groups {
        for row in group {
            let v = row.createdAt
            if !v.isEmpty && (oldest.isEmpty || jsStringLess(v, oldest)) { oldest = v }
        }
    }
    return oldest
}
/// `oldestCreatedAt(...groups)` for raw rows: a group that is not an array, a row that
/// is not an object and a stamp that is not a string all contribute nothing.
public func oldestCreatedAt(json groups: [JSONValue?]) -> String {
    var oldest = ""
    for group in groups {
        for row in asArray(group) {
            let v = jsStringOr(row["createdAt"])
            if !v.isEmpty && (oldest.isEmpty || jsStringLess(v, oldest)) { oldest = v }
        }
    }
    return oldest
}

/// The newest timestamp across everything the user can change, from any number of
/// row groups (events, templates, to-dos, kits). Lets the reminder tell "nothing
/// has happened since the backup" from "a fortnight of work is unsaved".
public func newestChangeAt(_ groups: [any ChangeStamped]...) -> String {
    var newest = ""
    for group in groups {
        for row in group {
            for v in [row.updatedAt, row.createdAt] where jsStringLess(newest, v) { newest = v }
        }
    }
    return newest
}
/// `newestChangeAt(...groups)` for raw rows.
public func newestChangeAt(json groups: [JSONValue?]) -> String {
    var newest = ""
    for group in groups {
        for row in asArray(group) {
            for key in ["updatedAt", "createdAt"] {
                let v = jsStringOr(row[key])
                if jsStringLess(newest, v) { newest = v }
            }
        }
    }
    return newest
}

/// Where the user stands on backups.
public struct BackupState: Equatable, Hashable, Sendable {
    /// 'ok'      nothing to nag about (no data, or nothing changed since)
    /// 'due'     unsaved changes and no fresh file for a while
    /// 'urgent'  unsaved changes and badly overdue
    public var level: String
    /// Whole days since the last backup — or since first use, when there has never
    /// been one, so "never backed up" escalates too. nil (JS null) when there is no data.
    public var days: Int?
    /// No backup file has ever been saved.
    public var never: Bool
    /// Something changed after the last backup was taken.
    public var unsaved: Bool
    public init(level: String = "ok", days: Int? = nil, never: Bool = true, unsaved: Bool = false) {
        self.level = level; self.days = days; self.never = never; self.unsaved = unsaved
    }
    public var json: JSONValue {
        ["level": .string(level), "days": days.map { .number(Double($0)) } ?? .null,
         "never": .bool(never), "unsaved": .bool(unsaved)]
    }
}

public func backupState(lastBackupAt: String = "", changedAt: String = "", firstUseAt: String = "",
                        hasData: Bool = false, now: String = "") -> BackupState {
    let today = todayYMD(now)
    let never = lastBackupAt.isEmpty
    if !hasData { return BackupState(level: "ok", days: nil, never: never, unsaved: false) }
    // A backup timestamp may be a legacy date-only string; comparing ISO text still
    // orders correctly, and same-day edits read as unsaved — the safe direction.
    let unsaved = never || changedAt.isEmpty || jsStringLess(lastBackupAt, changedAt)
    let since = !lastBackupAt.isEmpty ? lastBackupAt : (!firstUseAt.isEmpty ? firstUseAt : (!changedAt.isEmpty ? changedAt : today))
    let raw = daysBetween(jsSlice(since, 0, 10), today)
    let days = max(0, raw ?? 0)
    if !unsaved { return BackupState(level: "ok", days: days, never: never, unsaved: false) }
    let level = days >= BACKUP_URGENT_DAYS ? "urgent" : (days >= BACKUP_DUE_DAYS ? "due" : "ok")
    return BackupState(level: level, days: days, never: never, unsaved: true)
}

// TEMP-DUP(owner: care) — BEGIN. `daysBetween` belongs to the care slice (model.js
// ~2583). Delete this block at merge.
//
// `Date.parse(`${ymd}T00:00:00Z`)` on both sides, then `Math.round((b - a) / 86400000)`;
// null when either is not a date. As V8 reads it: exactly YYYY-MM-DD, month 01–12,
// day 01–31 — and a day the month does not have ROLLS OVER (02-30 is 2 March).
fileprivate func daysBetween(_ fromYMD: String, _ toYMD: String) -> Int? {
    func dayNumber(_ s: String) -> Int? {
        guard isYMD(s) else { return nil }
        let u = Array(s.utf8).map { Int($0) - 0x30 }
        let y = u[0] * 1000 + u[1] * 100 + u[2] * 10 + u[3]
        let m = u[5] * 10 + u[6]
        let d = u[8] * 10 + u[9]
        guard (1...12).contains(m), (1...31).contains(d) else { return nil }
        // Days from the civil date y-m-01 (Howard Hinnant), plus the day — so an
        // overflowing day rolls into the next month exactly as `Date.UTC` does.
        let yy = m <= 2 ? y - 1 : y
        let era = (yy >= 0 ? yy : yy - 399) / 400
        let yoe = yy - era * 400
        let mp = (m + 9) % 12
        let doy = (153 * mp + 2) / 5
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468 + (d - 1)
    }
    guard let a = dayNumber(fromYMD), let b = dayNumber(toYMD) else { return nil }
    return b - a
}
// TEMP-DUP(owner: care) — END.
