import Foundation
import PackingCore

/// The one-time import of a web-app backup file. See docs/store.md, rules 3 and 4.
///
/// 🚨 It does NOT go through `buildCatalog`. The web app's rebuild drops consumable,
/// packer, review history, "not in use" and kit membership (found by this port,
/// 2026-09-21). Instead every template is taken apart the way the web app's
/// everyday SAVE does it — which carries everything — and then the import CHECKS
/// ITSELF: each template is put back together and compared, row by row, with the
/// file it came from.
///
/// A file THIS app wrote also holds its things and their places on templates as
/// stored (`Library.backupFile`); those are taken as they are instead — a row cannot
/// say whether a note is the thing's or its place's — and the same row-by-row check
/// then holds them to the file's templates. Either way it is the same import: the
/// first-run door, Restore from a file, and the copy kept before a restore.
public enum Importer {

    /// What came across, in numbers — and what did not come back the same.
    public struct Report: Equatable, Sendable {
        public var templates = 0, rows = 0, items = 0, memberships = 0, things = 0
        public var trips = 0, lines = 0, ticks = 0
        public var actions = 0, kits = 0, photos = 0, phases = 0, sharedRows = 0
        /// The fields the web app's restore loses, counted over the file's rows and
        /// again over the rows rebuilt from the import. Each pair must match.
        public var fragile: [String: Int] = [:]
        public var fragileAfter: [String: Int] = [:]
        /// "template 3, row 17: container, phase" — positions and field names only,
        /// never his words, so a report can be shown anywhere.
        public var mismatches: [String] = []
        /// The file was written by this app and carried its things and their places
        /// on templates as stored, so they were taken as they are (not rebuilt).
        public var asStored = false
        public var isFaithful: Bool { mismatches.isEmpty && fragile == fragileAfter }
        public init() {}
    }

    static let fragileFields = ["consumable", "packer", "retired", "retiredReason", "reviewed", "kit", "keep"]

    static func countFragile(_ rows: [Item]) -> [String: Int] {
        var n: [String: Int] = [:]
        for f in fragileFields { n[f] = 0 }
        for r in rows {
            if r.consumable { n["consumable", default: 0] += 1 }
            if !r.packer.isEmpty { n["packer", default: 0] += 1 }
            if r.retired { n["retired", default: 0] += 1 }
            if !r.retiredReason.isEmpty { n["retiredReason", default: 0] += 1 }
            if r.stats.packed > 0 || !r.stats.lastReviewed.isEmpty { n["reviewed", default: 0] += 1 }
            if !r.kit.isEmpty { n["kit", default: 0] += 1 }
            if r.keep { n["keep", default: 0] += 1 }
        }
        return n
    }

    /// The things and their places on templates as THIS app stored them — only in a
    /// file this app wrote (`Library.backupItemsKey` / `backupPlacesKey`). nil for the
    /// web app's file, and for ours from before the two keys existed.
    static func asStored(_ backup: BackupFile) -> (items: [Item], places: [Membership])? {
        guard let items = backup.extra[Library.backupItemsKey]?.arrayValue,
              let places = backup.extra[Library.backupPlacesKey]?.arrayValue else { return nil }
        return (items.compactMap { coerceItem(json: $0) }, places.compactMap { coerceMembership(json: $0) })
    }

    /// Take the templates, the things and their places as they are. Only what can be
    /// shown comes in: a thing needs an id, a place needs its template and its thing
    /// (a place on a gone template is what Worth a look complains about — a restore
    /// is its cure, so it does not bring it back). A repeated id is taken once.
    static func take(_ stored: (items: [Item], places: [Membership]), lists: [PackList], into lib: inout Library) {
        var listIds = Set<String>()
        for list in lists where listIds.insert(list.id).inserted {
            var t = list
            t.items = []
            lib.templates.append(coerceList(t))
        }
        var thingIds = Set<String>()
        for item in stored.items where !item.id.isEmpty && thingIds.insert(item.id).inserted {
            lib.items.append(item)
        }
        var placeIds = Set<String>()
        for m in stored.places where !m.id.isEmpty && listIds.contains(m.templateId) && thingIds.contains(m.itemId)
            && placeIds.insert(m.id).inserted {
            lib.memberships.append(m)
        }
    }

    /// A row carries its thing's `extra` — the answers only this app keeps (a bag's
    /// cabin answer) and the keys the web app knows and this build does not. The
    /// everyday save leaves a row's `extra` behind (`catalogItemFromResolved` copies
    /// only the named fields), so the check below said "did not come back the same"
    /// and refused the WHOLE file — the copy kept before a restore too — once any bag
    /// had a cabin answer (the spec pass, 2026-10-05). Carried here, onto the thing
    /// each row was saved into (rows and the template's places run in the same order).
    static func carryRowExtras(_ lists: [PackList], into lib: inout Library) {
        for list in lists {
            let wanted = list.items.filter { !jsTrim($0.name).isEmpty }
            guard wanted.contains(where: { !$0.extra.isEmpty }),
                  let got = lib.resolvedTemplate(id: list.id)?.items, got.count == wanted.count else { continue }
            for (row, made) in zip(wanted, got) where !row.link && !row.extra.isEmpty {
                guard let id = made.itemId, let n = lib.items.firstIndex(where: { $0.id == id }) else { continue }
                lib.items[n].extra.merge(row.extra) { _, inFile in inFile }
            }
        }
    }

    /// A resolved row shows a place's own note OR the thing's, never which — so a file
    /// rebuilt from its rows (the web app's, or one of ours from before 0.61: the
    /// copies kept before a restore on his devices) put a thing's own note and qty on
    /// EACH of its places and left the thing's empty. A later change to the note in
    /// Your things then no longer reached those templates (the spec pass, 2026-10-05).
    /// So: when every place of a rebuilt thing carries the same note, it was the
    /// thing's — it goes back onto the thing and the places hold none; the same for
    /// qty. Places that differ keep their own. The templates read exactly the same
    /// either way (an empty place falls back to the thing), so the check below holds.
    static func settleOwnNotes(_ lib: inout Library) {
        var placesOf: [String: [Int]] = [:]
        for (n, m) in lib.memberships.enumerated() { placesOf[m.itemId, default: []].append(n) }
        for t in lib.items.indices {
            guard let mine = placesOf[lib.items[t].id], let first = mine.first else { continue }
            let note = lib.memberships[first].note
            if lib.items[t].note.isEmpty, !note.isEmpty, mine.allSatisfy({ lib.memberships[$0].note == note }) {
                lib.items[t].note = note
                for n in mine { lib.memberships[n].note = "" }
            }
            let qty = lib.memberships[first].qty
            if lib.items[t].qty.isEmpty, !qty.isEmpty, mine.allSatisfy({ lib.memberships[$0].qty == qty }) {
                lib.items[t].qty = qty
                for n in mine { lib.memberships[n].qty = "" }
            }
        }
    }

    public static func library(from backup: BackupFile, now: Date = PackingEnv.now()) -> (Library, Report) {
        var lib = Library()
        var report = Report()

        // Reading a file changes nothing that is live (the spec pass, 2026-10-05): the
        // restore preview — of a rescue copy too — reads the file through here, and the
        // file's "When" steps and conditions stayed installed after Cancel, until the
        // next reload. They are installed below only for the reading itself, then put
        // back; whoever STORES the result installs it (`Library.installLiveChoices`).
        let livePhases = PHASES, liveConditions = ITEM_CONDITIONS
        defer {
            _ = setPhases(livePhases)
            _ = setItemConditions(liveConditions)
        }

        // The "When" timeline FIRST, so everything below has a "When" to point at.
        // Stored only when it is his own: the factory seven live in the code.
        if !backup.phases.isEmpty {
            let cleaned = setPhases(backup.phases)
            if phasesCustomised(cleaned) { lib.phases = cleaned }
        }
        report.phases = lib.phases.count

        // The Settings lists. A list still exactly as shipped is NOT written: a kind
        // with no rows means "use the defaults" — never seed (rule 1).
        let prefs = backup.prefs
        for (kind, key) in [("conditions", "conditions"), ("people", "people"), ("owners", "owners"),
                            ("places", "storageLocations"), ("presets", "presets")] {
            guard let list = prefs?[key], list.arrayValue?.isEmpty == false else { continue }
            if isFactoryList(kind, json: list) { continue }
            lib.shared.append(contentsOf: sharedRowsFrom(kind, json: list))
        }
        // Which owner is him (0.70).
        if let me = prefs?[Library.meKey]?.stringValue, !me.isEmpty { lib.meta[Library.meKey] = .string(me) }
        if let grab = prefs?["grab"]?.objectValue {
            let items = grab["items"]?.objectValue ?? [:]
            let looks = grab["meta"]?.objectValue ?? [:]
            let ids = Set(items.keys).union(looks.keys).sorted()
            let lists: [JSONValue] = ids.map { gid in
                ["id": .string(gid), "items": items[gid] ?? .array([]),
                 "label": looks[gid]?["label"] ?? "", "icon": looks[gid]?["icon"] ?? "", "tone": looks[gid]?["tone"] ?? ""]
            }
            lib.shared.append(contentsOf: grabToRows(json: .array(lists)))
            // …and what he takes only sometimes, which rides beside them.
            var marks: [String: [String]] = [:]
            for (gid, names) in grab["sometimes"]?.objectValue ?? [:] {
                let clean = (names.arrayValue ?? []).compactMap { $0.stringValue }
                if !clean.isEmpty { marks[gid] = clean }
            }
            lib.setSometimesByList(marks)
            // …and his own lists, with the eight he keeps on Home.
            if let own = grab["own"]?.arrayValue, !own.isEmpty { lib.meta[GRAB_OWN_META] = .array(own) }
            let home = (grab["home"]?.arrayValue ?? []).compactMap { $0.stringValue }
            if !home.isEmpty { lib.meta[GRAB_HOME_META] = JSONValue(home) }
            // …and the ones he sent off Home, which stay off.
            let off = (grab["off"]?.arrayValue ?? []).compactMap { $0.stringValue }
            if !off.isEmpty { lib.meta[GRAB_OFF_META] = JSONValue(off) }
        }
        if let conditions = backup.prefsConditions, !conditions.isEmpty { _ = setItemConditions(conditions) }
        report.sharedRows = lib.shared.count

        if let stored = asStored(backup) {
            // A file THIS app wrote: its things and their places on templates are
            // taken exactly as they were stored. The rows below still check them.
            report.asStored = true
            take(stored, lists: backup.lists, into: &lib)
        } else {
            // The web app's file (or an older one of ours): each template
            // taken apart as a SAVE would…
            for list in backup.lists {
                lib.saveTemplate(list)
                // …keeping the moment it was last changed: a restore is not an edit.
                if !list.updatedAt.isEmpty, let n = lib.templates.firstIndex(where: { $0.id == list.id }) {
                    lib.templates[n].updatedAt = list.updatedAt
                }
            }
            carryRowExtras(backup.lists, into: &lib)
            settleOwnNotes(&lib)
        }
        // Things on no list have no other home (missing from backups until web v178).
        for thing in backup.things where !jsTrim(thing.name).isEmpty {
            let id = thing.itemId ?? thing.id
            if lib.items.contains(where: { $0.id == id }) {
                if report.asStored { report.things += 1 }   // it came across with the others
                continue
            }
            var cat = catalogItemFromResolved(thing)
            if !id.isEmpty { cat.id = id }
            // `catalogItemFromResolved` is written for a row on a template, whose note
            // and qty belong to its PLACE. A thing on no list was resolved against no
            // place at all, so these are its own — and its own answers in `extra` too
            // (a bag's cabin answer, a key the web app knows and this build does not).
            cat.note = thing.note
            cat.qty = thing.qty
            cat.extra.merge(thing.extra) { _, inFile in inFile }
            lib.items.append(cat)
            report.things += 1
        }

        // Trips stand on their own. A line needs an id of its own, unique in its trip.
        for var trip in backup.events {
            var seen = Set<String>()
            for n in trip.entries.indices {
                if trip.entries[n].id.isEmpty || !seen.insert(trip.entries[n].id).inserted {
                    trip.entries[n].id = PackingEnv.makeId()
                    seen.insert(trip.entries[n].id)
                }
            }
            lib.trips.append(trip)
        }
        lib.actions = backup.actions
        lib.kits = backup.kits
        lib.photos = backup.photos

        // The numbers.
        let fileRows = backup.lists.flatMap(\.items).filter { !jsTrim($0.name).isEmpty }
        report.templates = lib.templates.count
        report.rows = fileRows.count
        report.items = lib.items.count
        report.memberships = lib.memberships.count
        report.trips = lib.trips.count
        report.lines = lib.trips.reduce(0) { $0 + $1.entries.count }
        report.ticks = lib.trips.reduce(0) { $0 + $1.entries.filter(\.checked).count }
        report.actions = lib.actions.count
        report.kits = lib.kits.count
        report.photos = lib.photos.count

        // The check: put every template back together and compare it with the file.
        report.fragile = countFragile(fileRows)
        var rebuilt: [Item] = []
        for (t, list) in backup.lists.enumerated() {
            let wanted = list.items.filter { !jsTrim($0.name).isEmpty }
            let got = lib.resolvedTemplate(id: list.id)?.items ?? []
            rebuilt.append(contentsOf: got)
            if got.count != wanted.count {
                report.mismatches.append("template \(t + 1): \(wanted.count) rows in the file, \(got.count) after the import")
                continue
            }
            for (r, (a, b)) in zip(wanted, got).enumerated() where a.json != b.json {
                let x = a.json.objectValue ?? [:], y = b.json.objectValue ?? [:]
                let fields = Set(x.keys).union(y.keys).filter { x[$0] != y[$0] }.sorted()
                report.mismatches.append("template \(t + 1), row \(r + 1): \(fields.joined(separator: ", "))")
            }
        }
        report.fragileAfter = countFragile(rebuilt)

        // The marker that says: this account has been imported into. A second import
        // is refused unless he says "replace everything", out loud (rule 3).
        lib.meta["import"] = [
            "at": .string(jsISOString(now)),
            "exportedAt": .string(backup.exportedAt),
            "templates": .number(Double(report.templates)), "items": .number(Double(report.items)),
            "memberships": .number(Double(report.memberships)), "trips": .number(Double(report.trips)),
            "lines": .number(Double(report.lines)),
        ]
        return (lib, report)
    }
}

// The doors a backup file comes in through — the first-run import, the restore
// preview, and what a restore stores. Here rather than in the app so the model tests
// reach them (the spec pass, 2026-10-05: the import door's refusals had no test).

extension Importer {
    /// Why a file is not taken. The words are shown to him as they are.
    public enum Refusal: LocalizedError, Equatable {
        case notABackup, alreadyImported, notFaithful(Int)
        public var errorDescription: String? {
            switch self {
            case .notABackup: return "That is not an AMS Packing backup file."
            case .alreadyImported: return "This library has already been imported into."
            case .notFaithful(let n): return "The import did not come back the same (\(n) rows differ), so nothing was stored."
            }
        }
    }

    static func backup(in data: Data) throws -> BackupFile {
        guard let json = try? JSONValue.parse(data), BackupFile.looksLikeBackup(json) else { throw Refusal.notABackup }
        return BackupFile(json: json)
    }

    static func faithful(_ backup: BackupFile, now: Date) throws -> (library: Library, report: Report) {
        let (lib, report) = library(from: backup, now: now)
        // It checks itself. If a row did not come back the same, NOTHING is taken.
        guard report.isFaithful else { throw Refusal.notFaithful(report.mismatches.count) }
        return (lib, report)
    }

    /// Read a file and change NOTHING: what it holds, so a restore can be looked at
    /// before it replaces the lot. A file that does not come back the same is refused
    /// here, before he is ever offered the button.
    public static func read(_ data: Data, now: Date = PackingEnv.now()) throws -> (library: Library, report: Report) {
        try faithful(try backup(in: data), now: now)
    }

    /// The one-time import of a backup into a library that holds nothing of his
    /// (docs/store.md, rules 3 and 4) — the devices' check-ins carried across.
    public static func firstImport(_ data: Data, onto current: Library,
                                   now: Date = PackingEnv.now()) throws -> (library: Library, report: Report) {
        let file = try backup(in: data)
        guard current.isEmpty else { throw Refusal.alreadyImported }
        let (lib, report) = try faithful(file, now: now)
        return (lib.keepingDeviceNotes(of: current), report)
    }

    /// What a restore stores: exactly what the file holds — and the devices' check-ins
    /// of the library it replaces, which are about the devices, not about his things.
    public static func restoring(_ file: Library, over current: Library) -> Library {
        file.keepingDeviceNotes(of: current)
    }
}

extension Library {
    /// Install this library's own "When" steps and conditions as the live ones (none =
    /// the factory ones). Whoever STORES a library does this; reading one never does.
    public func installLiveChoices() {
        _ = setPhases(phases)                            // [] → the factory timeline
        let conditions = conditionsFromRows(shared)
        _ = setItemConditions(conditions.isEmpty ? DEFAULT_ITEM_CONDITIONS : conditions)
    }
}
