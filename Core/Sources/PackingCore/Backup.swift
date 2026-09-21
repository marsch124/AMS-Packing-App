// Backup — the top-level shape of the web app's backup file.
// From `exportJSON` / `inspectBackup` / `applyBackup` in js/db.js (not model.js):
//
//   { app: 'ams-packing-list', version: 2, exportedAt, lists, events, actions, kits,
//     phases, things, photos, prefs }
//
// THE BACKUP FILE IS THE ONLY DATA BRIDGE from the web app to this one, so reading
// it is as forgiving as the web app's own restore: nothing here can fail to decode
// because a field is missing or has the wrong type.
//
// Three things that are easy to get wrong (each one cost the web app a release):
//   • `lists` hold RESOLVED items — every template carries a full copy of each of
//     its items. The catalogue is rebuilt from them (`buildCatalog`, a later section).
//   • `things` are the items on NO template. They appear in no list, so a reader
//     that only walks `lists` silently drops them (found in v178, again in v185).
//   • `photos` are separate records; items refer to them by id.

import Foundation

/// One stored picture: `data` is a `data:image/jpeg;base64,…` URL.
public struct PhotoRecord: JSONModel, Hashable, Sendable {
    public var id: String
    public var data: String
    public var createdAt: String
    public init(id: String = "", data: String = "", createdAt: String = "") {
        self.id = id; self.data = data; self.createdAt = createdAt
    }
    public init(json: JSONValue) {
        self.id = jsStringOr(json["id"])
        self.data = jsStringOr(json["data"])
        self.createdAt = jsStringOr(json["createdAt"])
    }
    public var json: JSONValue { ["id": .string(id), "data": .string(data), "createdAt": .string(createdAt)] }
}

public struct BackupFile: JSONModel, Sendable {
    /// 'ams-packing-list'
    public var app: String
    /// 2 since photos moved into their own array; 1 had them inline on the items.
    public var version: Int
    public var exportedAt: String
    /// Templates WITH their resolved items.
    public var lists: [PackList]
    public var events: [TripEvent]
    public var actions: [ActionItem]
    public var kits: [Kit]
    /// The "When" timeline, each phase coerced at its position; rows with no id or no
    /// label are dropped, as the restore drops them. [] in a backup from before v118 —
    /// which means "leave this device's phases alone", NOT "there are none".
    public var phases: [Phase]
    /// Items on no template (v178). [] in an older backup.
    public var things: [Item]
    /// Only records whose `id` and `data` are both strings, as the restore filters them.
    public var photos: [PhotoRecord]
    /// Device preferences and the Settings lists, carried ONLY where he customised them:
    /// `theme`, `view`, `grab` { items, meta }, `storageLocations` [String], `presets`,
    /// `people`, `owners` [String], `conditions`. nil when the file has none.
    /// Left as JSON: people, presets and grab lists belong to a later section.
    public var prefs: JSONValue?
    /// Any top-level key this package does not know.
    public var extra: [String: JSONValue]

    public init(
        app: String = "ams-packing-list",
        version: Int = 2,
        exportedAt: String = nowISO(),
        lists: [PackList] = [],
        events: [TripEvent] = [],
        actions: [ActionItem] = [],
        kits: [Kit] = [],
        phases: [Phase] = [],
        things: [Item] = [],
        photos: [PhotoRecord] = [],
        prefs: JSONValue? = nil,
        extra: [String: JSONValue] = [:]
    ) {
        self.app = app; self.version = version; self.exportedAt = exportedAt
        self.lists = lists; self.events = events; self.actions = actions; self.kits = kits
        self.phases = phases; self.things = things; self.photos = photos; self.prefs = prefs
        self.extra = extra
    }

    static let knownKeys: Set<String> = [
        "app", "version", "exportedAt", "lists", "events", "actions", "kits",
        "phases", "things", "photos", "prefs",
    ]

    /// Does a parsed object look like one of our backups? (Has lists or events.)
    /// Decoding never fails, so ask this BEFORE trusting what came out.
    public static func looksLikeBackup(_ json: JSONValue) -> Bool {
        json["lists"]?.arrayValue != nil || json["events"]?.arrayValue != nil
    }

    public init(json: JSONValue) {
        let o = json.objectValue ?? [:]
        self.init(
            app: jsStringOr(o["app"]),
            version: jsInt(o["version"]?.finiteNumber ?? 0),
            exportedAt: jsStringOr(o["exportedAt"]),
            lists: asArray(o["lists"]).compactMap { coerceList(json: $0) },
            events: asArray(o["events"]).compactMap { coerceEvent(json: $0) },
            actions: asArray(o["actions"]).compactMap { coerceAction(json: $0) },
            kits: asArray(o["kits"]).compactMap { coerceKit(json: $0) },
            phases: asArray(o["phases"]).enumerated()
                .map { coercePhase(json: $0.element, $0.offset) }
                .filter { !$0.id.isEmpty && !$0.label.isEmpty },
            things: coerceItems(json: o["things"]),
            photos: asArray(o["photos"])
                .filter { $0["id"]?.stringValue != nil && $0["data"]?.stringValue != nil }
                .map { PhotoRecord(json: $0) },
            prefs: o["prefs"]?.objectValue != nil ? o["prefs"] : nil,
            extra: extraKeys(o, known: BackupFile.knownKeys)
        )
    }

    public var json: JSONValue {
        var o = extra
        o["app"] = .string(app); o["version"] = .number(Double(version)); o["exportedAt"] = .string(exportedAt)
        o["lists"] = .array(lists.map { $0.json })
        o["events"] = .array(events.map { $0.json })
        o["actions"] = .array(actions.map { $0.json })
        o["kits"] = .array(kits.map { $0.json })
        o["phases"] = .array(phases.map { $0.json })
        o["things"] = .array(things.map { $0.json })
        o["photos"] = .array(photos.map { $0.json })
        if let p = prefs { o["prefs"] = p }
        return .object(o)
    }

    // The parts of `prefs` whose types already exist. nil = the backup does not carry
    // that list, which means "he never customised it" — NEVER "it is empty".
    public var prefsConditions: [ItemCondition]? {
        prefs?["conditions"]?.arrayValue.map { $0.map { coerceCondition(json: $0) } }
    }
    public var prefsStorageLocations: [String]? {
        prefs?["storageLocations"]?.arrayValue.map { $0.compactMap { $0.stringValue } }
    }
    public var prefsOwners: [String]? {
        prefs?["owners"]?.arrayValue.map { $0.compactMap { $0.stringValue } }
    }
}
