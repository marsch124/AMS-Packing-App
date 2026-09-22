import Foundation
import PackingCore

// The library as a backup FILE — the same JSON the web app writes, so either app
// can read the other's file during the change-over (docs/store.md, rule 10).

extension Library {
    /// Everything, as `db.exportJSON()` writes it: templates resolved with their
    /// items (each row carrying its item and membership ids, as the web app's rows
    /// do), trips with their lines, and the Settings lists — only the ones that are
    /// his own, never the factory defaults (a backup must never plant defaults on
    /// another device as data).
    public func backupFile(exportedAt: String = nowISO()) -> BackupFile {
        var o: [String: JSONValue] = [
            "app": "ams-packing-list",
            "version": 2,
            "exportedAt": .string(exportedAt),
            "lists": .array(resolvedTemplates().map { $0.json }),
            "events": .array(trips.map { $0.json }),
            "actions": .array(actions.map { $0.json }),
            "kits": .array(kits.map { $0.json }),
            "phases": .array(phases.map { $0.json }),
            "things": .array(thingsOnNoList().map { $0.json }),
            "photos": .array(photos.map { $0.json }),
        ]
        var prefs: [String: JSONValue] = [:]
        let conditions = conditionsFromRows(shared)
        if !conditions.isEmpty { prefs["conditions"] = .array(conditions.map { $0.json }) }
        let people = peopleFromRows(shared)
        if !people.isEmpty { prefs["people"] = .array(people.map { $0.json }) }
        let owners = namesFromRows(shared, "owners")
        if !owners.isEmpty { prefs["owners"] = JSONValue(owners) }
        let places = orderedNamesFromRows(shared, "places")
        if !places.isEmpty { prefs["storageLocations"] = JSONValue(places) }
        let presets = presetsFromRows(shared)
        if !presets.isEmpty {
            prefs["presets"] = .array(presets.map { ["name": .string($0.name), "createdAt": .string($0.createdAt), "config": $0.config] })
        }
        let grab = grabFromRows(shared)
        if !grab.isEmpty {
            var items: [String: JSONValue] = [:], meta: [String: JSONValue] = [:]
            for g in grab {
                items[g.id] = JSONValue(g.items)
                meta[g.id] = ["label": .string(g.label), "icon": .string(g.icon), "tone": .string(g.tone)]
            }
            prefs["grab"] = ["items": .object(items), "meta": .object(meta)]
        }
        if !prefs.isEmpty { o["prefs"] = .object(prefs) }
        return BackupFile(json: .object(o))
    }

    /// The file's bytes, laid out the way the web app lays them out.
    public func backupData(exportedAt: String = nowISO()) -> Data {
        Data(backupFile(exportedAt: exportedAt).json.text(pretty: true).utf8)
    }

    /// The web app's file name: ams-packing-list-backup-YYYY-MM-DD.json
    public static func backupFileName(on day: String) -> String { "ams-packing-list-backup-\(day).json" }

    /// Set a line aside for THIS trip ("not this time"): greyed, struck through,
    /// and out of the counts. On the trip's line only, never the template.
    @discardableResult
    public mutating func setAside(_ aside: Bool, tripId: String, entryId: String) -> Bool {
        guard let t = trips.firstIndex(where: { $0.id == tripId }),
              let e = trips[t].entries.firstIndex(where: { $0.id == entryId }) else { return false }
        trips[t].entries[e].skipped = aside
        return true
    }

    /// What this device holds, table by table — so two devices can be compared by eye.
    public var counts: [(table: Table, count: Int)] {
        let r = records()
        return Table.allCases.map { t in (t, r.filter { $0.table == t }.count) }
    }
}
