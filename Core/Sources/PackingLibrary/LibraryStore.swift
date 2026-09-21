import Foundation
import PackingCore

/// Where records are kept. The app uses iCloud (`CloudStore`, in the app target);
/// tests use `MemoryStore`, so they never touch an account and run the same on
/// the simulator, the Mac and GitHub.
public protocol LibraryStore: AnyObject {
    /// Everything this device holds.
    func loadAll() throws -> [StoredRecord]
    /// Write and delete in one step.
    func apply(_ changes: RecordChanges) throws
    /// Called when records arrived from the other device. The library reloads.
    var onRemoteChange: (() -> Void)? { get set }
}

public final class MemoryStore: LibraryStore {
    private var records: [RecordID: StoredRecord] = [:]
    private var order: [RecordID] = []
    public var onRemoteChange: (() -> Void)?
    /// Every set of changes applied, for tests that ask "what was actually written?".
    public private(set) var log: [RecordChanges] = []

    public init(_ initial: [StoredRecord] = []) {
        for r in initial { put(r) }
    }
    private func put(_ r: StoredRecord) {
        if records[r.id] == nil { order.append(r.id) }
        records[r.id] = r
    }
    public func loadAll() throws -> [StoredRecord] { order.compactMap { records[$0] } }
    public func apply(_ changes: RecordChanges) throws {
        log.append(changes)
        for r in changes.puts { put(r) }
        for id in changes.deletes { records[id] = nil; order.removeAll { $0 == id } }
    }
    /// Pretend the other device wrote something.
    public func simulateRemote(_ changes: RecordChanges) {
        for r in changes.puts { put(r) }
        for id in changes.deletes { records[id] = nil; order.removeAll { $0 == id } }
        onRemoteChange?()
    }
}
