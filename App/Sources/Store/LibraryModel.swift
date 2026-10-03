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
    /// The map's "Find N places" is looking.
    @Published private(set) var findingPlaces = false
    /// A trip asked to open from outside the screens — a tapped packing reminder, a
    /// Shortcut. Home opens it and clears it.
    @Published var tripToOpen: String?
    /// A grab list asked to open from a Shortcut (the Action button). Home opens it.
    @Published var grabToOpen: String?
    /// The Action button's "Choose a grab list": Home shows the menu of grab lists.
    @Published var grabMenuOpen = false

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
            // The MAP needs only the place, so it is kept the moment it is found —
            // even when no forecast exists for the dates (his test G.6, 2026-09-28: a
            // trip already over, with no forecast, never reached the map).
            keepPlace(tripId: tripId, name: name, spot: spot)
            let days = try await sky.forecast(at: spot, from: trip.startDate, nights: trip.nights, today: Today.local)
            change { _ = $0.setWeather(tripId: tripId, place: name, lat: spot.lat, lon: spot.lon, snapshot: days) }
        } catch {
            weatherTrouble[tripId] = error.localizedDescription
        }
    }

    /// Put a trip on the map without asking for weather: its place is looked up
    /// and kept. For a new place typed in Trip settings when no forecast can exist.
    func placeOnMap(tripId: String) async {
        guard let trip = library.trip(tripId) else { return }
        let name = jsTrim(trip.destination)
        guard !name.isEmpty, let spot = try? await sky.place(named: name) else { return }
        keepPlace(tripId: tripId, name: name, spot: spot)
    }

    private func keepPlace(tripId: String, name: String, spot: Place) {
        change { lib in
            if let n = lib.trips.firstIndex(where: { $0.id == tripId }) { lib.trips[n].destination = name }
            _ = lib.setPlace(tripId: tripId, lat: spot.lat, lon: spot.lon, label: spot.name)
        }
    }

    /// The map's "Find N places": look up every trip that names a place but has no
    /// spot yet, one at a time, and keep what is found. Returns the names not found.
    func findPlaces() async -> [String] {
        guard !findingPlaces else { return [] }
        findingPlaces = true
        defer { findingPlaces = false }
        var missed: [String] = []
        for trip in library.placesToFind() {
            do {
                let spot = try await sky.place(named: jsTrim(trip.destination))
                change { _ = $0.setPlace(tripId: trip.id, lat: spot.lat, lon: spot.lon, label: spot.name) }
            } catch {
                missed.append(trip.destination)
            }
        }
        return missed
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
    /// The one model of this run — the screens and the Shortcuts share it.
    static let shared: LibraryModel = {
        let model = LibraryModel.forThisLaunch()
        // Under the tests, a Shortcut is played by a launch argument: what the
        // Shortcut does is set the same request the argument sets.
        let args = ProcessInfo.processInfo.arguments
        if AMSPackingApp.testing, let n = args.firstIndex(of: "-openGrab"), n + 1 < args.count {
            model.grabToOpen = model.library.allGrabLists().first { $0.label == args[n + 1] || $0.title == args[n + 1] }?.id
        }
        if AMSPackingApp.testing, args.contains("-openGrabMenu") { model.grabMenuOpen = true }
        if AMSPackingApp.testing, args.contains("-openNextTrip"),
           let next = model.library.nextTrip(today: Today.local) {
            model.tripToOpen = next.id
        }
        return model
    }()

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
            for key in ["ams.table.columns", "ams.table.sort", "ams.table.down", "ams.care.view", "ams.view", "ams.trip.folded", "ams.template.grouping", "ams.pick.grouping", "ams.pick.folded", PackingReminders.onKey] {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        let sky: Forecaster = AMSPackingApp.testing ? InventedForecast() : OpenMeteo()
        if args.contains("-uiTestingEmpty") { return LibraryModel(store: MemoryStore(), usesICloud: false, sky: sky) }
        if args.contains("-uiTestingChecks") {
            return LibraryModel(store: MemoryStore(SampleLibrary.checks().records()), usesICloud: false, sky: sky)
        }
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
