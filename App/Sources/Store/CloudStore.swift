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
    /// The name this app's own saves carry in the store's history (0.91, `StoreHistory`).
    static let author = "AMSPacking.app"
    /// Authors whose changes bring nothing into the library: this app's own saves, and iCloud SENDING
    /// them out (its export only notes what it sent). iCloud bringing the other device's changes in
    /// ("NSCloudKitMirroringDelegate.import"), or any author not named here, is read.
    static let bringNothingIn: Set<String> = [author, "NSCloudKitMirroringDelegate.export"]

    private let container: ModelContainer
    private let context: ModelContext
    private var observer: NSObjectProtocol?
    var onRemoteChange: (() -> Void)?
    /// What changed since the last look (0.91) — read only on `looking`, never on the main thread,
    /// and never the whole history (0.94, `StoreHistory`).
    private let history: StoreHistory
    /// One queue, one look at a time: the launch's look first, then one per notification, in order.
    private let looking: OperationQueue = {
        let q = OperationQueue()
        q.name = "AMSPacking.history"
        q.maxConcurrentOperationCount = 1
        q.qualityOfService = .utility
        return q
    }()

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
        let history = StoreHistory(container, quiet: CloudStore.bringNothingIn)
        self.history = history
        // Where the history stands at launch: its newest transaction alone, off the main thread
        // (0.94 — until then the WHOLE history, which grows with every change, was read here, on the
        // main thread, at every launch). Queued first, so every notification is looked at after it.
        looking.addOperation { history.lookAtLaunch() }
        // Records that arrived from the other device land in the store behind our
        // back; this is how we hear about it. The model then reloads the whole store
        // on the main thread (see LibraryModel.init for what that costs).
        // 🪤 The store also says so after every save of OUR OWN (0.91, measured: on a library of
        // his size every change was followed, a few seconds later, by a whole reload of 1.4 s on
        // the main thread — the wait he felt after typing). So the history is asked first — on
        // `looking`, not the main thread (0.94) — and when everything since the last look is this
        // app's own saving, nothing is read again. Anything else — iCloud bringing the other
        // device's changes, a history that cannot be read — reloads exactly as before.
        observer = NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange, object: nil, queue: looking
        ) { [weak self] _ in
            if history.onlyQuietSinceLastLook() { return }
            DispatchQueue.main.async { self?.onRemoteChange?() }
        }
    }

    /// Under the UI tests (`-uiTestingOnDisk`): records written into the store by ANOTHER hand, as
    /// iCloud writes what the other device changed — a context of its own, under another name.
    func writeAsTheOtherDevice(_ records: [StoredRecord]) {
        let other = ModelContext(container)
        other.author = "the other device"
        for r in records { other.insert(Record(r)) }
        try? other.save()
    }

    deinit { if let o = observer { NotificationCenter.default.removeObserver(o) } }

    func loadAll() throws -> [StoredRecord] {
        try context.fetch(FetchDescriptor<Record>()).compactMap(\.stored)
    }

    func apply(_ changes: RecordChanges) throws {
        guard !changes.isEmpty else { return }
        // Nothing is unique in a CloudKit store, so a key can have twins. `planTwins`
        // (PackingLibrary, 0.94) says which twins take a put and which are deleted —
        // by what they hold, never by the order this fetch returns them in, so both
        // devices keep the SAME row (until 0.94 the FIRST twin took the put and the
        // others were deleted: each device kept its own, and after the sync neither).
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
            guard let twins = held[put.id], !twins.isEmpty else { context.insert(Record(put)); continue }
            let plan = planTwins(twins.map(\.stored), storing: put)
            for n in plan.write {
                twins[n].parent = put.parent
                twins[n].json = Data(put.json.text().utf8)
                twins[n].blob = put.blob
                twins[n].updatedAt = put.updatedAt
            }
            for n in plan.delete { context.delete(twins[n]) }
        }
        for id in changes.deletes { for r in held[id] ?? [] { context.delete(r) } }
        do {
            #if DEBUG
            // Under the UI tests (`-uiTestingSaveFails`): this save fails, as a full disk would (0.93).
            if failNextSave { failNextSave = false; throw SaveRefusedForTests() }
            #endif
            try context.save()
        } catch {
            // A save that fails leaves nothing waiting (0.93, the outside review of 0.92): the failed
            // change stayed in the context — the next save stored it, or failed on it again, and a
            // reload read it back as if it were kept. Rolled back, the store holds what it held; the
            // model reads it again and says the change was not saved (`LibraryModel.couldNotSave`).
            context.rollback()
            throw error
        }
    }

    #if DEBUG
    /// The next save fails (0.93, the outside review of 0.92): `-uiTestingSaveFails` sets it.
    var failNextSave = false
    struct SaveRefusedForTests: Error {}
    #endif
}
