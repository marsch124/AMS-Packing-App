import Foundation
import PackingCore
import PackingLibrary

// import-check <backup.json>
//
// Runs the one-time import on a real backup file WITHOUT storing anything, and
// says — in numbers and positions only, never in his words — whether everything
// came across. Exit 0 = faithful. Run it on the fresh backup before the switch.

let args = CommandLine.arguments
guard args.count >= 2, let data = FileManager.default.contents(atPath: args[1]) else {
    FileHandle.standardError.write(Data("usage: import-check <backup.json>\n".utf8))
    exit(2)
}
guard let json = try? JSONValue.parse(data), BackupFile.looksLikeBackup(json) else {
    FileHandle.standardError.write(Data("that is not an AMS Packing backup file\n".utf8))
    exit(2)
}
let backup = BackupFile(json: json)
let (library, report) = Importer.library(from: backup)

func line(_ label: String, _ value: Any) { print(label.padding(toLength: 22, withPad: " ", startingAt: 0) + "\(value)") }
line("templates", report.templates)
line("rows on templates", "\(report.rows)  →  \(report.items) things, \(report.memberships) places on lists")
line("things on no list", report.things)
line("trips", "\(report.trips)  (\(report.lines) lines, \(report.ticks) ticked)")
line("to-dos / kits / photos", "\(report.actions) / \(report.kits) / \(report.photos)")
line("his own \"When\" steps", report.phases)
line("settings list entries", report.sharedRows)
print("\nthe fields the web app's restore loses (rows in the file → rows after the import):")
for f in report.fragile.keys.sorted() {
    let a = report.fragile[f] ?? 0, b = report.fragileAfter[f] ?? 0
    line("  " + f, "\(a) → \(b)" + (a == b ? "" : "   ✗ LOST"))
}

// The store round trip: cut into records, read back, cut again — nothing may move.
let records = library.records()
let back = Library(records: records)
let drift = recordChanges(from: records, to: back.records())
line("\nrecords", "\(records.count)  (drift after a store round trip: \(drift.puts.count + drift.deletes.count))")
var perTable: [String: Int] = [:]
for r in records { perTable[r.table.rawValue, default: 0] += 1 }
line("  by table", perTable.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: " · "))
let biggest = records.map { $0.json.text().utf8.count + ($0.blob?.count ?? 0) }.max() ?? 0
line("  largest record", "\(biggest) bytes")

// Trips: would "regenerate" change them? (It must not drop the lines of a trip
// whose templates are gone — docs/store.md rule 9 — so this is reported, not fixed.)
let resolved = library.resolvedTemplates()
for (n, trip) in library.trips.enumerated() {
    let known = Set(library.templates.map(\.id))
    let found = trip.activities.filter(known.contains).count
    let model = regenerateEntries(trip, resolved).count
    let guarded = library.regenerated(trip).count
    line("  trip \(n + 1)", "\(trip.entries.count) lines · regenerate: the model alone → \(model), the library → \(guarded) · templates found \(found)/\(trip.activities.count)")
}

if report.mismatches.isEmpty && drift.isEmpty && report.fragile == report.fragileAfter {
    print("\nfaithful: every row came back exactly as it is in the file")
    exit(0)
}
print("\nNOT faithful — \(report.mismatches.count) rows differ:")
for m in report.mismatches.prefix(40) { print("  " + m) }
exit(1)
