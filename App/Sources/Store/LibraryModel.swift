import Foundation
import SwiftUI
import PackingCore
import PackingLibrary

/// The library as the screens see it: the values in memory, and the one way to
/// change them — change the library, store the difference.
@MainActor
final class LibraryModel: ObservableObject {
    enum State: Equatable {
        case loading
        /// Nothing on this device. NOT a verdict: a new device cannot tell "nothing
        /// has arrived yet" from "there is nothing" — so it asks (docs/store.md, rule 2).
        case empty
        case ready
        case failed(String)
    }

    @Published private(set) var library = Library()
    @Published private(set) var state: State = .loading
    @Published private(set) var lastImport: Importer.Report?

    private let store: LibraryStore
    private var held: [StoredRecord] = []
    let usesICloud: Bool

    init(store: LibraryStore, usesICloud: Bool) {
        self.store = store
        self.usesICloud = usesICloud
        store.onRemoteChange = { [weak self] in
            Task { @MainActor in self?.reload() }
        }
        reload()
    }

    /// Read everything the store holds. Duplicate keys are settled by rule, and the
    /// losers are deleted so both devices end up holding the same records.
    func reload() {
        do {
            let all = try store.loadAll()
            let settled = settleDuplicates(all)
            if !settled.dropped.isEmpty {
                // Re-write the survivors; twins of a key go together in the store.
                try store.apply(RecordChanges(puts: settled.kept.filter { k in settled.dropped.contains { $0.id == k.id } }))
            }
            let fresh = Library(records: settled.kept)
            held = fresh.records()
            if fresh != library { library = fresh }
            _ = setPhases(fresh.phases)                      // [] → the factory timeline
            let conditions = conditionsFromRows(fresh.shared)
            _ = setItemConditions(conditions.isEmpty ? DEFAULT_ITEM_CONDITIONS : conditions)
            state = fresh.isEmpty ? .empty : .ready
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// The only way anything changes.
    func change(_ body: (inout Library) -> Void) {
        var next = library
        body(&next)
        commit(next)
    }

    private func commit(_ next: Library) {
        let records = next.records()
        let changes = recordChanges(from: held, to: records)
        guard !changes.isEmpty else { return }
        do {
            try store.apply(changes)
            held = records
            library = next
            state = next.isEmpty ? .empty : .ready
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// The one-time import of a web-app backup file (docs/store.md, rules 3 and 4).
    /// Refused when this account has been imported into already.
    enum ImportError: LocalizedError {
        case notABackup, alreadyImported, notFaithful(Int)
        var errorDescription: String? {
            switch self {
            case .notABackup: return "That is not an AMS Packing backup file."
            case .alreadyImported: return "This library has already been imported into."
            case .notFaithful(let n): return "The import did not come back the same (\(n) rows differ), so nothing was stored."
            }
        }
    }

    @discardableResult
    func importBackup(_ data: Data) throws -> Importer.Report {
        guard let json = try? JSONValue.parse(data), BackupFile.looksLikeBackup(json) else { throw ImportError.notABackup }
        guard library.isEmpty else { throw ImportError.alreadyImported }
        let (imported, report) = Importer.library(from: BackupFile(json: json))
        // It checks itself. If a row did not come back the same, store NOTHING.
        guard report.isFaithful else { throw ImportError.notFaithful(report.mismatches.count) }
        commit(imported)
        _ = setPhases(imported.phases)
        lastImport = report
        return report
    }

    /// Read a backup file and change NOTHING: what it holds, so a restore can be
    /// looked at before it replaces the lot. A file that does not come back the
    /// same is refused here, before he is ever offered the button.
    func inspectBackup(_ data: Data) throws -> (library: Library, report: Importer.Report) {
        guard let json = try? JSONValue.parse(data), BackupFile.looksLikeBackup(json) else { throw ImportError.notABackup }
        let (imported, report) = Importer.library(from: BackupFile(json: json))
        guard report.isFaithful else { throw ImportError.notFaithful(report.mismatches.count) }
        return (imported, report)
    }

    /// Replace everything on this device with what the file held. What was here is
    /// written to a rescue copy FIRST — the write that destroys comes last.
    func restore(_ imported: Library) throws {
        try RescueCopies.write(library)
        commit(imported)
        reload()
    }
}

extension LibraryModel {
    /// Which store this launch uses.
    ///  -uiTesting            → memory, holding the invented sample library
    ///  -uiTestingEmpty       → memory, holding nothing (the first-run screen)
    ///  PackingUsesICloud=YES → SwiftData + iCloud (TestFlight and release builds)
    ///  otherwise             → SwiftData on this device only (a plain debug build)
    static func forThisLaunch() -> LibraryModel {
        let args = ProcessInfo.processInfo.arguments
        if AMSPackingApp.testing { RescueCopies.clearForTesting() }
        if args.contains("-uiTestingEmpty") { return LibraryModel(store: MemoryStore(), usesICloud: false) }
        if args.contains("-uiTesting") { return LibraryModel(store: MemoryStore(SampleLibrary.make().records()), usesICloud: false) }
        let cloud = (Bundle.main.object(forInfoDictionaryKey: "PackingUsesICloud") as? String) == "YES"
        do {
            let model = LibraryModel(store: try CloudStore(cloud: cloud), usesICloud: cloud)
            #if DEBUG
            // Debug builds only: `-importFile <path>` brings a backup into an EMPTY
            // library at launch, so a build can be looked at with real data on the
            // simulator without any of it entering this (public) repository.
            if model.state == .empty, let n = args.firstIndex(of: "-importFile"), n + 1 < args.count,
               let data = FileManager.default.contents(atPath: args[n + 1]) {
                _ = try? model.importBackup(data)
            }
            #endif
            return model
        } catch {
            let model = LibraryModel(store: MemoryStore(), usesICloud: false)
            model.state = .failed("The library could not be opened: \(error.localizedDescription)")
            return model
        }
    }
}
