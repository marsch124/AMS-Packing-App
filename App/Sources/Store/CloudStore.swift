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

    var stored: StoredRecord? { read().record }

    /// What this record holds — nil when it cannot be read: a table this build does not know, JSON it
    /// cannot parse, or (`fileGone`) a photo whose bytes are kept in a file of their own that is not
    /// there as they are read. 🪤 That last one THROWS an Objective-C exception, which no Swift code
    /// can catch (24 Oct 2026, crash A: iCloud had just brought a change in on his Mac; the throw ran
    /// out through the app's reading of the store and left it broken, and the next click shut it). So
    /// the bytes are read through `AMSCatchException`, and such a photo is left out of this read.
    func read() -> (record: StoredRecord?, fileGone: Bool) {
        guard let t = Table(rawValue: table), let value = try? JSONValue.parse(json) else { return (nil, false) }
        var bytes: Data?
        if AMSCatchException({ bytes = self.blob }) != nil { return (nil, true) }
        return (StoredRecord(table: t, key: key, parent: parent, json: value, blob: bytes, updatedAt: updatedAt), false)
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

    /// A photo whose file is not there as it is read (crash A, `Record.read`) is LEFT OUT, not read as
    /// a photo without a picture: left out, nothing this read leads to can write it — no settling of
    /// twins, no difference stored — so the store keeps it exactly as iCloud left it. And the store is
    /// read again a few seconds later, when iCloud has usually finished, a few times at most.
    func loadAll() throws -> [StoredRecord] {
        let all = try context.fetch(FetchDescriptor<Record>())
        #if DEBUG
        afterFetchForTests?()
        #endif
        var out: [StoredRecord] = []
        var gone = 0
        for r in all {
            let (record, fileGone) = r.read()
            if let record { out.append(record) } else if fileGone { gone += 1 }
        }
        readAgainSoon(gone > 0)
        return out
    }

    /// Reads again in a row because a photo's file was missing (at most `readsAgainAtMost`).
    private var readsAgain = 0
    private static let readsAgainAtMost = 3
    private func readAgainSoon(_ needed: Bool) {
        guard needed else { readsAgain = 0; return }
        guard readsAgain < CloudStore.readsAgainAtMost else { return }
        readsAgain += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in self?.onRemoteChange?() }
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
    /// Run between a read's fetch and the records' contents being read (`-uiTestingPhotoGone`).
    var afterFetchForTests: (() -> Void)?

    /// Under the UI tests (`-uiTestingPhotoGone`): records written into the store FILE through a
    /// store of their own — another hand, which the app's store has never seen hold them.
    static func writeThroughAnotherStore(_ records: [StoredRecord], file: URL) {
        guard let other = try? CloudStore(cloud: false, file: file) else { return }
        other.writeAsTheOtherDevice(records)
    }

    /// Under the UI tests (`-uiTestingPhotoGone`): the files a store file keeps photos' bytes in
    /// (`.externalStorage`, beside the store in `.<name>_SUPPORT/_EXTERNAL_DATA`) deleted — as on his
    /// Mac on 24 Oct 2026, when a photo's file was not there as the app read it (crash A).
    /// The store's second names for such files (`.LINKS/<a folder per open store>`, beside the store
    /// file) go too, so the bytes are found nowhere.
    static func removeExternalFiles(of store: URL) {
        let fm = FileManager.default
        let base = store.deletingPathExtension().lastPathComponent
        let folder = store.deletingLastPathComponent()
        var dirs = [folder.appendingPathComponent(".\(base)_SUPPORT/_EXTERNAL_DATA")]
        let links = folder.appendingPathComponent(".LINKS")
        for name in (try? fm.contentsOfDirectory(atPath: links.path)) ?? [] { dirs.append(links.appendingPathComponent(name)) }
        for dir in dirs {
            for name in (try? fm.contentsOfDirectory(atPath: dir.path)) ?? [] {
                try? fm.removeItem(at: dir.appendingPathComponent(name))
            }
        }
    }
    #endif
}
