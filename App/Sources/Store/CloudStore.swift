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
    /// The name this app's own saves carry in the store's history (0.91, `onlyOurOwnSinceLastLook`).
    static let author = "AMSPacking.app"
    /// Authors whose changes bring nothing into the library: this app's own saves, and iCloud SENDING
    /// them out (its export only notes what it sent). iCloud bringing the other device's changes in
    /// ("NSCloudKitMirroringDelegate.import"), or any author not named here, is read.
    static let bringNothingIn: Set<String> = [author, "NSCloudKitMirroringDelegate.export"]

    private let container: ModelContainer
    private let context: ModelContext
    private var observer: NSObjectProtocol?
    var onRemoteChange: (() -> Void)?
    /// The newest change in the store's history already looked at (0.91).
    private var seen: DefaultHistoryToken?

    /// `file`: a store in that file instead of the app's own (the measuring library, `EditTiming`).
    init(cloud: Bool, inMemory: Bool = false, file: URL? = nil) throws {
        let schema = Schema([Record.self])
        let config = file.map { ModelConfiguration("Library", schema: schema, url: $0, cloudKitDatabase: .none) }
            ?? ModelConfiguration(
                "Library", schema: schema, isStoredInMemoryOnly: inMemory,
                cloudKitDatabase: cloud ? .private(CloudStore.containerId) : .none)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
        context.autosaveEnabled = false
        context.author = CloudStore.author
        seen = newestInHistory()
        // Records that arrived from the other device land in the store behind our
        // back; this is how we hear about it. Heard on the main queue: the model then
        // reloads the whole store there (see LibraryModel.init for what that costs).
        // 🪤 The store also says so after every save of OUR OWN (0.91, measured: on a library of
        // his size every change was followed, a few seconds later, by a whole reload of 1.4 s on
        // the main thread — the wait he felt after typing). So the history is asked first, and
        // when everything since the last look is this app's own saving, nothing is read again.
        // Anything else — iCloud bringing the other device's changes, a history that cannot be
        // read — reloads exactly as before.
        observer = NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            if self.onlyOurOwnSinceLastLook() { return }
            self.onRemoteChange?()
        }
    }

    /// True only when the store's history holds new changes and every one of them was saved by this
    /// app's own context (or is iCloud sending those out). False for anything else — another author,
    /// no author, no new change at all, or a history that cannot be read (a store without one) — so a
    /// doubt always reloads.
    private func onlyOurOwnSinceLastLook() -> Bool {
        var asked = HistoryDescriptor<DefaultHistoryTransaction>()
        if let seen { asked.predicate = #Predicate { $0.token > seen } }
        guard let changes = try? context.fetchHistory(asked) else { seen = nil; return false }
        if let newest = changes.map(\.token).max() { seen = newest }
        return !changes.isEmpty && changes.allSatisfy { $0.author.map(CloudStore.bringNothingIn.contains) ?? false }
    }

    /// Under the UI tests (`-uiTestingOnDisk`): records written into the store by ANOTHER hand, as
    /// iCloud writes what the other device changed — a context of its own, under another name.
    func writeAsTheOtherDevice(_ records: [StoredRecord]) {
        let other = ModelContext(container)
        other.author = "the other device"
        for r in records { other.insert(Record(r)) }
        try? other.save()
    }

    private func newestInHistory() -> DefaultHistoryToken? {
        (try? context.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>()))?.map(\.token).max()
    }

    deinit { if let o = observer { NotificationCenter.default.removeObserver(o) } }

    func loadAll() throws -> [StoredRecord] {
        try context.fetch(FetchDescriptor<Record>()).compactMap(\.stored)
    }

    func apply(_ changes: RecordChanges) throws {
        guard !changes.isEmpty else { return }
        // Nothing is unique in a CloudKit store, so a key can have twins. Every
        // twin is updated or deleted together; `settleDuplicates` tidies on load.
        // ⚠️ To find them, EVERY record is fetched — for one tick as for a restore —
        // because only a full fetch is sure to see every twin of a key. Quick at a few
        // thousand records; fetching only the keys that change is the cure if a tick
        // ever feels slow (the spec pass, 5 Oct 2026; spec 01 item 15).
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
