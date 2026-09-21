import Foundation
import SwiftData
import PackingCore
import PackingLibrary

/// The ONE stored model. See docs/store.md: a single generic shape means the
/// CloudKit schema never has to change — a new field on an item is a change to
/// PackingCore, not a schema deployment.
///
/// CloudKit's rules for a synced model: every attribute has a default or is
/// optional, and nothing is unique (so duplicates are settled by rule on load).
@Model
final class Record {
    var table: String = ""
    var key: String = ""
    var parent: String = ""
    var json: Data = Data()
    @Attribute(.externalStorage) var blob: Data?
    var updatedAt: Date = Date.distantPast

    init(_ r: StoredRecord) {
        table = r.table.rawValue
        key = r.key
        parent = r.parent
        json = Data(r.json.text().utf8)
        blob = r.blob
        updatedAt = r.updatedAt
    }

    var stored: StoredRecord? {
        guard let t = Table(rawValue: table), let value = try? JSONValue.parse(json) else { return nil }
        return StoredRecord(table: t, key: key, parent: parent, json: value, blob: blob, updatedAt: updatedAt)
    }
}

/// Records kept by SwiftData — on this device, and (when `cloud`) in his iCloud.
final class CloudStore: LibraryStore {
    static let containerId = "iCloud.com.schabbauer.AMSPacking"

    private let container: ModelContainer
    private let context: ModelContext
    private var observer: NSObjectProtocol?
    var onRemoteChange: (() -> Void)?

    init(cloud: Bool, inMemory: Bool = false) throws {
        let schema = Schema([Record.self])
        let config = ModelConfiguration(
            "Library", schema: schema, isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: cloud ? .private(CloudStore.containerId) : .none)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
        context.autosaveEnabled = false
        // Records that arrived from the other device land in the store behind our
        // back; this is how we hear about it.
        observer = NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange, object: nil, queue: .main
        ) { [weak self] _ in self?.onRemoteChange?() }
    }

    deinit { if let o = observer { NotificationCenter.default.removeObserver(o) } }

    func loadAll() throws -> [StoredRecord] {
        try context.fetch(FetchDescriptor<Record>()).compactMap(\.stored)
    }

    func apply(_ changes: RecordChanges) throws {
        guard !changes.isEmpty else { return }
        // Nothing is unique in a CloudKit store, so a key can have twins. Every
        // twin is updated or deleted together; `settleDuplicates` tidies on load.
        var held: [RecordID: [Record]] = [:]
        for r in try context.fetch(FetchDescriptor<Record>()) {
            guard let t = Table(rawValue: r.table) else { continue }
            held[RecordID(t, r.key), default: []].append(r)
        }
        for put in changes.puts {
            if let twins = held[put.id], let first = twins.first {
                first.parent = put.parent
                first.json = Data(put.json.text().utf8)
                first.blob = put.blob
                first.updatedAt = put.updatedAt
                for extra in twins.dropFirst() { context.delete(extra) }
            } else {
                context.insert(Record(put))
            }
        }
        for id in changes.deletes { for r in held[id] ?? [] { context.delete(r) } }
        try context.save()
    }
}
