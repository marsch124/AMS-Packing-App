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

    /// Trips whose forecast is being looked up right now, and what went wrong.
    @Published private(set) var lookingUpWeather: Set<String> = []
    @Published private(set) var weatherTrouble: [String: String] = [:]

    private let store: LibraryStore
    private var held: [StoredRecord] = []
    let usesICloud: Bool
    /// Where a forecast comes from — the invented one under the tests.
    let sky: Forecaster

    init(store: LibraryStore, usesICloud: Bool, sky: Forecaster = OpenMeteo()) {
        self.store = store
        self.usesICloud = usesICloud
        self.sky = sky
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

    /// Look the weather up for a trip and keep it on the trip. Two calls: the place
    /// by name, then the days. Anything that goes wrong is said on the trip, not
    /// thrown away.
    func lookUpWeather(tripId: String, place: String? = nil) async {
        guard let trip = library.trip(tripId) else { return }
        let name = jsTrim(place ?? trip.destination)
        guard !name.isEmpty, !lookingUpWeather.contains(tripId) else { return }
        lookingUpWeather.insert(tripId)
        weatherTrouble[tripId] = nil
        defer { lookingUpWeather.remove(tripId) }
        do {
            let spot = try await sky.place(named: name)
            let days = try await sky.forecast(at: spot, from: trip.startDate, nights: trip.nights, today: Today.local)
            change { _ = $0.setWeather(tripId: tripId, place: name, lat: spot.lat, lon: spot.lon, snapshot: days) }
        } catch {
            weatherTrouble[tripId] = error.localizedDescription
        }
    }

    /// Worth looking up as the trip opens? Only for a trip that is close enough for
    /// a forecast to exist, and only when what we hold is stale.
    func forecastWorthFetching(tripId: String) -> Bool {
        guard let trip = library.trip(tripId), !jsTrim(trip.destination).isEmpty else { return false }
        guard let ahead = OpenMeteo.days(from: Today.local, to: trip.startDate) else { return false }
        guard ahead >= -Int(max(0, trip.nights)), ahead <= OpenMeteo.reachDays else { return false }
        return library.forecastIsStale(tripId: tripId)
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
        if AMSPackingApp.testing {
            RescueCopies.clearForTesting()
            // A test must start from the same screen every time: the columns he has
            // chosen, the sort and the direction are remembered on the device, and
            // one test's choice would otherwise decide the next test's grid.
            for key in ["ams.table.columns", "ams.table.sort", "ams.table.down", "ams.care.view", "ams.view", "ams.trip.folded"] {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        let sky: Forecaster = AMSPackingApp.testing ? InventedForecast() : OpenMeteo()
        if args.contains("-uiTestingEmpty") { return LibraryModel(store: MemoryStore(), usesICloud: false, sky: sky) }
        if args.contains("-uiTestingTwoLibraries") {
            return LibraryModel(store: MemoryStore(SampleLibrary.doubled().records()), usesICloud: false, sky: sky)
        }
        if args.contains("-uiTesting") {
            return LibraryModel(store: MemoryStore(SampleLibrary.make().records()), usesICloud: false, sky: sky)
        }
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
