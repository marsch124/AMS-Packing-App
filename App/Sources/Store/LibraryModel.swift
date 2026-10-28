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

    @Published private(set) var library = Library() {
        // The Mac writes the trip pages the library is waiting for (0.70, spec 07 part 8) — never
        // from a page's copy (0.92), which is not his library until its Save.
        didSet { if !isDraft { VaultShelf.shared.libraryChanged(self) } }
    }
    /// A page's copy of the library (0.92, `PageDraft`): its changes stay in memory — never
    /// stored, never synced — until the page's Save hands them to the real library.
    let isDraft: Bool
    @Published private(set) var state: State = .loading

    /// Trips whose forecast is being looked up right now, and what went wrong.
    @Published private(set) var lookingUpWeather: Set<String> = []
    @Published private(set) var weatherTrouble: [String: String] = [:]
    /// The map's "Find N places" is looking.
    @Published private(set) var findingPlaces = false
    /// A trip asked to open from outside the screens — a tapped packing reminder, a
    /// Shortcut. Home opens it and clears it.
    @Published var tripToOpen: String?
    /// How that trip opens when a door check was tapped (0.69): on just its unticked
    /// lines, or (`home`) at Pack to go home on just what is not in a bag yet. The trip
    /// takes it as it opens, and clears it.
    @Published var tripFocus: TripFocus?
    /// `review`: a tapped "Welcome home — review …" (0.77, spec 07 part 16) — the trip opens
    /// on its review. `charge`: a tapped "Charge tonight" (0.87) — the trip opens at its To charge.
    struct TripFocus: Equatable { let tripId: String; let home: Bool; var review = false; var charge = false }
    /// A grab list asked to open from a Shortcut (the Action button). Home opens it.
    @Published var grabToOpen: String?
    /// The Action button's "Choose a grab list": Home shows the menu of grab lists.
    @Published var grabMenuOpen = false
    /// A place's code, from its printed label read by the iPhone's Camera
    /// (AMSPACKING://P/<code>, 0.69). Home opens what it leads to and clears it.
    @Published var placeToOpen: String?
    /// A tab asked for from inside a window — a to-do found by Search lives on To do.
    /// The frame switches to it and clears it.
    @Published var tabToOpen: AppSection?
    /// Help ▸ Keyboard Shortcuts (0.103, Mac): Settings opens How it works at its Keyboard shortcuts topic and clears it.
    /// Help ▸ Keyboard Shortcuts (0.103) opens How it works at that topic. In debug builds the launch
    /// argument `-openKeysTopic` asks the same, so a UI test reaches the guide's last topic without
    /// scrolling the whole guide (0.103's release run: the scroll outlasted 5 minutes on a busy Mac).
    #if DEBUG
    @Published var keysToOpen = ProcessInfo.processInfo.arguments.contains("-openKeysTopic")
    #else
    @Published var keysToOpen = false
    #endif
    /// A thing whose result was tapped in Spotlight (0.92, Store/Spotlight.swift): Home opens its
    /// page and clears it.
    @Published var thingToOpen: String?

    private let store: LibraryStore
    private var held: [StoredRecord] = []
    /// What this device saved lately of each block iCloud keeps whole (0.102, `RecentSaves`): the other
    /// device's save of the same block arriving later without our change in it is told, once.
    private var recent = RecentSaves()
    let usesICloud: Bool
    /// Where a forecast comes from — the invented one under the tests.
    let sky: Forecaster

    init(store: LibraryStore, usesICloud: Bool, sky: Forecaster = OpenMeteo()) {
        self.store = store
        self.usesICloud = usesICloud
        self.sky = sky
        self.isDraft = false
        // ⚠️ Every iCloud notification reloads the WHOLE store — every record read,
        // settled and turned back into a library — on the main thread, so the screen
        // waits while it runs, and a sync that arrives in bursts reloads once per
        // notification. Kept simple on purpose: one full read can never miss a record,
        // and it is quick at a few thousand. If the app ever stutters while the other
        // device syncs, look here first (the spec pass, 5 Oct 2026; spec 01 item 15).
        // Read straight away, never in a Swift Task (24 Oct 2026, crash A): the store calls this on the
        // main thread, and an Objective-C exception thrown inside a Task — one a framework throws while
        // the store is read — breaks Swift's own bookkeeping for the rest of the app's life (his Mac,
        // 0.99: a click six minutes later shut the app). Outside a Task it costs the one read.
        store.onRemoteChange = { [weak self] in
            MainActor.assumeIsolated { self?.reload() }
        }
        reload()
    }

    /// A copy of `live` for a page that holds its changes until Save (0.92, `PageDraft`). It
    /// reads nothing and writes nothing: no store, no iCloud, no trip pages.
    init(copyOf live: LibraryModel) {
        self.store = MemoryStore()
        self.usesICloud = live.usesICloud
        self.sky = live.sky
        self.isDraft = true
        self.library = live.library
        self.state = live.state
    }

    /// Read everything the store holds. Duplicate keys are settled by rule, and the
    /// losers are deleted so both devices end up holding the same records
    /// (`StoreSession.load`, where the model tests reach it). `keepingScreens` (0.93): read
    /// after a failed save — a store that cannot be read then leaves the screens as they are.
    func reload(keepingScreens: Bool = false) {
        guard !isDraft else { return }                  // a page's copy has no store to read
        let started = EditTiming.now
        defer { EditTiming.reloaded(EditTiming.now - started) }
        do {
            let (fresh, records) = try StoreSession.load(store)
            held = records
            // A save of ours the other device's crossing save wrote over (0.102): said once, quietly.
            let lost = recent.arrived(fresh)
            if !lost.isEmpty {
                SaveNote.shared.show(fresh.crossedNote(lost, thisDevice: SyncCard.device), id: "save-crossed", seconds: 8)
            }
            if fresh != library { library = fresh }
            fresh.installLiveChoices()
            state = fresh.isEmpty ? .empty : .ready
            // Things whose condition the table stored as its LABEL (before 0.62) get
            // the condition's id, which everything else reads. Written once; the
            // same answer on every device, so two devices doing it at once agree.
            change { _ = $0.repairConditionLabels() }
        } catch {
            if !keepingScreens { state = .failed(error.localizedDescription) }
        }
    }

    /// The only way anything changes. `stamping` false (0.92): a bag put back as it was — a bag
    /// page's Cancel — keeps the Last edited it is given instead of being stamped now. false (0.94):
    /// the store refused it and nothing of it was kept — a page then keeps holding what it wrote.
    @discardableResult
    func change(stamping: Bool = true, _ body: (inout Library) -> Void) -> Bool {
        let started = EditTiming.now
        var next = library
        body(&next)
        // A bag changed by any screen says when (0.90: Your bags' Last edited — BagSorting.swift).
        if stamping { next.stampEditedBags(since: library) }
        let changed = EditTiming.now
        let kept = commit(next)
        if EditTiming.on { EditTiming.change(model: changed - started, store: EditTiming.now - changed) }
        return kept
    }

    /// ⚠️ What one change costs: `StoreSession.save` builds EVERY record of the
    /// library again — base64-decoding every photo — and compares them all with what
    /// is held, then the store fetches all it holds to apply the few that differ
    /// (`CloudStore.apply`). So one tick costs as much as the whole library and its
    /// photos. Kept because a full comparison can never forget a change; a rewrite
    /// would remember what changed instead (the spec pass, 5 Oct 2026; spec 01 item 15).
    /// false: the store refused the change, and nothing of it was kept (0.93).
    @discardableResult
    private func commit(_ next: Library) -> Bool {
        // A page's copy keeps its changes in memory (0.92): the page's Save stores them.
        if isDraft {
            if next != library { library = next }
            state = next.isEmpty ? .empty : .ready
            return true
        }
        do {
            guard let records = try StoreSession.save(next, held: held, to: store) else { return true }
            held = records
            recent.note(before: library, after: next)
            library = next
            state = next.isEmpty ? .empty : .ready
            return true
        } catch {
            couldNotSave()
            return false
        }
    }

    /// One failed save no longer shuts the app (0.93, the outside review of 0.92 — his "fix 1, 2
    /// and 6"): every tab was replaced by the error. Now the screens stay, a small note says
    /// "Couldn't save that — try again" (`SaveNote`, plain words), and the library is read again
    /// — the store rolled the change back (`CloudStore.apply`) — so the screen shows what is kept.
    private func couldNotSave() {
        SaveNote.shared.show()
        // A reload's own small repair can save, and fail, too: read once, never round and round.
        guard !recovering else { return }
        recovering = true
        defer { recovering = false }
        reload(keepingScreens: true)
    }
    private var recovering = false

    /// A replacing write the store refused (0.93), in his words: said where he asked for it.
    struct NotSaved: LocalizedError {
        let words: String
        var errorDescription: String? { words }
    }

    /// The one-time import of a web-app backup file (docs/store.md, rules 3 and 4).
    /// Refused when this library holds anything of his already (`Importer.firstImport`).
    typealias ImportError = Importer.Refusal

    @discardableResult
    func importBackup(_ data: Data) throws -> Importer.Report {
        let (imported, report) = try Importer.firstImport(data, onto: library)
        guard commit(imported) else {
            throw NotSaved(words: "Nothing was brought in \u{2014} it couldn't be saved. Try again.")
        }
        recent.forget()                                   // a whole library, not an edit to watch
        imported.installLiveChoices()
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
            // A trip that starts past the forecast's reach (0.75) is NOT asked: the service
            // would answer with its own days — this week — shown as the trip's. The card says
            // when its forecast comes (`WeatherCard.notYet`); one held can only be of other days.
            if ForecastAsk.comesFrom(startDate: trip.startDate, today: Today.local, utcToday: todayYMD()) != nil {
                if library.trip(tripId)?.weather != nil { change { _ = $0.dropWeather(tripId: tripId) } }
                return
            }
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
        guard ForecastAsk.inReach(startDate: trip.startDate, nights: trip.nights,
                                  today: Today.local, utcToday: todayYMD()) else { return false }
        return library.forecastIsStale(tripId: tripId)
    }

    /// A link that came from outside — a place's printed label, read by the Camera
    /// (AMSPACKING://P/<code>, 0.69). Anything else is left alone.
    func open(_ url: URL) {
        if let code = PlaceLink.code(in: url) { placeToOpen = code }
    }

    /// Read a backup file and change NOTHING — not even the live "When" steps and
    /// conditions (`Importer.read`): what it holds, so a restore can be looked at before
    /// it replaces the lot. A file that does not come back the same is refused here,
    /// before he is ever offered the button.
    func inspectBackup(_ data: Data) throws -> (library: Library, report: Importer.Report) {
        try Importer.read(data)
    }

    /// Replace everything on this device with what the file held. What was here is
    /// written to a rescue copy FIRST — the write that destroys comes last. The
    /// devices' check-ins stay (`Importer.restoring`).
    #if DEBUG
    /// UI tests only (0.102, `OtherDeviceForTests`): the other device's save, arriving through the store
    /// as iCloud brings it, with its check-in.
    func arriveFromTheOtherDevice(_ body: (inout Library) -> Void) {
        guard !isDraft, let memory = store as? MemoryStore else { return }
        var next = library
        body(&next)
        next.checkIn(device: SyncCard.device == "Mac" ? "iPhone" : "Mac")
        memory.simulateRemote(recordChanges(from: library.records(), to: next.records()))
    }
    #endif

    /// How a restart of the connection to iCloud went (0.104, `restartSync`).
    enum RestartOutcome: Equatable {
        /// Restarted, and the store read again.
        case done
        /// Not now — a save under way. Nothing has changed; asked again later.
        case refused
        /// Not done: the store cannot be restarted in place (nothing changed, it works on), or it was closed
        /// and would not open again. Either way only quitting and opening Packing helps.
        case failed
    }

    /// Restart the connection to iCloud (0.104, `SyncHealer`): the store closed and opened again in place
    /// (`CloudStore.reconnect`) — what quitting Packing and opening it again does — then read again, as at
    /// launch. The library in memory and every page's copy of it are not touched; a store with no iCloud
    /// (the tests' memory) is only read again.
    func restartSync() -> RestartOutcome {
        guard !isDraft else { return .refused }
        guard let cloud = store as? CloudStore else { reload(); return .done }
        do {
            guard try cloud.reconnect() != nil else { return .refused }
        } catch is CloudStore.CannotRestart {
            return .failed                                // nothing changed: the store works on as it was
        } catch {
            state = .failed("Restarting the iCloud connection did not work \u{2014} quit Packing and open it again.")
            return .failed
        }
        reload()
        return .done
    }

    /// A save is under way (0.104: the restart waits for it).
    var saving: Bool { (store as? CloudStore)?.saving ?? false }

    func restore(_ imported: Library) throws {
        try RescueCopies.write(library)
        // A restore the store refused said "Restored" (0.93, the outside review): it says so now.
        guard commit(Importer.restoring(imported, over: library)) else {
            throw NotSaved(words: "Nothing was replaced \u{2014} it couldn't be saved. Try again.")
        }
        recent.forget()                                   // a whole library, not an edit to watch
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
        // A place's code, read by the Camera, as the link arrives (0.69).
        if AMSPackingApp.testing, let n = args.firstIndex(of: "-uiTestingOpen"), n + 1 < args.count,
           let url = URL(string: args[n + 1]) {
            model.open(url)
        }
        #if os(iOS)
        // The same link handed to the RUNNING app, each time it comes back to the front after
        // being put away — as the Camera hands it over while a trip is open (0.73;
        // `XCUIApplication.open` launches the app afresh instead, so it cannot play that). Not
        // at launch: the first coming-to-the-front is the launch itself.
        if AMSPackingApp.testing, let n = args.firstIndex(of: "-uiTestingOpenOnReturn"), n + 1 < args.count,
           let url = URL(string: args[n + 1]) {
            let center = NotificationCenter.default
            center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { _ in
                var back: NSObjectProtocol?
                back = center.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { _ in
                    if let back { center.removeObserver(back) }
                    Task { @MainActor in model.open(url) }
                }
            }
        }
        #endif
        if AMSPackingApp.testing, args.contains("-openNextTrip"),
           let next = model.library.nextTrip(today: Today.local) {
            model.tripToOpen = next.id
        }
        return model
    }()

    /// A store file for the tests, emptied first (with its journal files).
    static func freshTestFile(_ name: String) -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name)-library.store")
        for tail in ["", "-wal", "-shm"] { try? FileManager.default.removeItem(atPath: url.path + tail) }
        return url
    }

    /// Which store this launch uses — the first that matches, in this order:
    ///  -uiTestingEmpty        → memory, holding nothing (the first-run screen)
    ///  -uiTestingChecks       → memory, the sample + a carry-on bag, a knife, sun cream
    ///                           and a passport running out, and a plane trip (the checks)
    ///  -uiTestingOnSite       → memory, the sample with its trip under way (On site)
    ///  -uiTestingLeaving      → memory, the sample with its trip leaving today at 08:00
    ///                           ("I leave at"; with -clockAt, when it sets off, 0.75)
    ///  -uiTestingKits         → memory, the sample + a Camp pouch and a Wash bag with things
    ///                           inside them (kits, 0.70); + -kitsUnderWay: its trip under
    ///                           way, the pouch usually in a Day pack's Front pocket (Where
    ///                           is my …?, 0.73)
    ///  -uiTestingBattery      → memory, the kits sample with its trip starting tomorrow, a
    ///                           Power bank in the Camp pouch and the Toothbrush with a battery
    ///                           (To charge, 0.75); + -batteryByPlane: the trip by plane,
    ///                           the Camp pouch in the Checked luggage (a battery in the
    ///                           hold, 0.76); + -batteryToDo: Hiking's reminder a week
    ///                           ahead, due (Before you go, all three parts, 0.77)
    ///  -uiTestingBigBase      → memory, the sample + a big always-packed "Long trips" and a
    ///                           Camp pouch kit (a small core, 0.71)
    ///  -uiTestingOldPhoto     → memory, the sample + a photo nothing shows, from January
    ///                           and one with no date (Worth a look)
    ///  -uiTestingTwoLibraries → memory, every template of the sample twice (Worth a look)
    ///  -uiTestingSections     → memory, the sample with Hiking under two headings (Arrange)
    ///  -uiTestingWhose        → memory, the sample with owners Anna and Ben on Your choices, a
    ///                           thing of Cleo's (on no list), three things of no one (Group by
    ///                           Whose it is, 0.103)
    ///  -uiTestingWorkouts     → memory, the sample + a Run workout and things for one
    ///                           context only (Context per workout, 0.67)
    ///  -uiTestingPlaces <when> → memory, the sample with the Garage's code G4R and its
    ///                           trip moved (0.69): "soon" = it starts in 2 days (being
    ///                           packed); "home" = it began 3 days ago, ends today, all
    ///                           ticked; anything else = a month ahead, as the sample
    ///  -uiTestingSoon         → memory, the sample with its trip 10 days ahead, inside the
    ///                           forecast's reach (the weather card, 0.75)
    ///  -uiTestingNotes        → memory, the sample + notes to search (0.69)
    ///  -uiTestingPockets      → memory, the sample under way + a Backpack with three pockets,
    ///                           the charger usually in its front pocket, and the times
    ///                           he leaves (the pockets and the door check, 0.69)
    ///  -uiTestingHealth       → memory, the sample + Swim, Run and Bike and a trip of
    ///                           them six to two days ago; with invented Apple Health
    ///                           workouts (`AppleHealth.source`, 0.70)
    ///  -uiTestingReviewed     → memory, the sample with its trip been and reviewed: a
    ///                           photo, a scale reading, a thing bought, a note, a missed
    ///                           thing — and no page asked for yet (Obsidian, 0.70)
    ///  -uiTestingReviewedUndated → memory, the -uiTestingReviewed sample with its trip's
    ///                           dates taken away (a reviewed trip goes to Done, 0.73)
    ///  -uiTestingThingReminders → memory, a Camera with two reminders and two things going with it (0.101)
    ///  -uiTestingReminders    → memory, the sample + two reminders on Hiking, its trip
    ///                           three days ahead (reminders on a template, 0.70)
    ///  -uiTestingBeforeStart  → memory, the sample with things to buy, reminders to prepare and a
    ///                           battery, its trip ten days ahead, nothing ticked (Before you start, 0.82)
    ///  -uiTestingPackingDay   → memory, the sample + a Day pack with an AirTag holding the boots
    ///                           and the jacket: a trip with two bags (the Packing day, 0.79); +
    ///                           -packingDayAlmost: every station done but the Map unticked; +
    ///                           -packingDayByPlane: the trip by Plane (bag-tag numbers, 0.80); +
    ///                           -packingDayInner: a Toiletry bag with an AirTag, packed in the
    ///                           carry-on, the Toothbrush in it (no tags inside another bag, 0.86)
    ///  -uiTestingLostBag      → memory, the Packing day's sample as a plane trip with flights
    ///                           and a stay, the Day pack's details and photo, and half of his
    ///                           details for the desk (the Lost bag page, 0.80)
    ///  -uiTestingGrabHeadings → memory, the sample with Outdoor bike under three headings of
    ///                           his own (a grab list's headings, 0.85)
    ///  -uiTestingBigLibrary   → a store FILE holding an invented library of his size (`SampleLibrary.big`,
    ///                           for measuring with -timeEdits, 0.91)
    ///  -uiTestingLostSection  → memory, the sample after two saves of Hiking crossed: its section Lights
    ///                           given back from the Headlamp's line, and Swim's Goggles naming a section
    ///                           whose name is stored nowhere (0.97, his check 6)
    ///  -uiTestingOnDisk       → a store FILE holding the sample; 15 s after launch "the other device"
    ///                           writes a thing called Sunglasses into it (0.91: the app's own saves are
    ///                           not read back, the other device's still are)
    ///  -uiTestingSaveFails    → (debug builds) a store FILE holding the sample; its first save after
    ///                           launch fails (0.93: a note, the screens kept, the store and screen agree);
    ///                           + -saveFailsBags: the sample with bags (0.94: a bag page's failed save)
    ///  -uiTestingKept         → (debug builds) a store FILE kept from one launch to the next, holding the
    ///                           sample with bags; + -keptStart: made afresh (0.98: what a page held when
    ///                           the app was ended without Done is looked for at the next launch)
    ///  -uiTestingPhotoGone    → (debug builds) a store FILE holding the sample; 6 s after launch "the other
    ///                           device" writes a photo and a thing called Sunglasses into it, and the
    ///                           photo's file goes as the app reads them (24 Oct 2026, crash A)
    ///  -uiTesting -importHangs <minutes>|page → a store FILE holding the sample, and an invented record of
    ///                           iCloud with a receive that never ends (0.104, `TestHang`): since that many
    ///                           minutes before launch, or from the moment a page first holds a change;
    ///                           + -selfHealAfter <seconds>: the app restarts by itself after that long
    ///                           (without it, only Restart sync restarts)
    ///  -uiTesting             → memory, holding the invented sample library
    ///  PackingUsesICloud=YES  → SwiftData + iCloud (TestFlight and release builds)
    ///  otherwise              → SwiftData on this device only (a plain debug build)
    /// Under any `-uiTesting…` the library is in memory, but the copies kept before a
    /// restore are real files — so they are deleted at launch, with the remembered
    /// screen choices below.
    static func forThisLaunch() -> LibraryModel {
        let args = ProcessInfo.processInfo.arguments
        if AMSPackingApp.testing {
            // The tests' clock (`-clockAt`) starts now, as the app opens.
            _ = Today.now
            RescueCopies.clearForTesting()
            // A test must start from the same screen every time: the columns he has
            // chosen, the sort and the direction are remembered on the device, and
            // one test's choice would otherwise decide the next test's grid.
            for key in ["ams.table.columns", "ams.table.widths", "ams.table.sort", "ams.table.down", "ams.table.then", "ams.table.filters", ThingsTable.batteryArrivedKey, "ams.care.view", BagsScreen.sortKey, "ams.view", "ams.trip.folded", BagsCard.openKey, HomeScreen.moreKey, "ams.template.grouping", "ams.pick.grouping", "ams.pick.folded", PackingReminders.onKey, TripMessages.onKey, SettingsScreen.savedKey, GrabQuickActions.openedKey, StationPicks.storageKey, SyncHealer.key] {
                UserDefaults.standard.removeObject(forKey: key)
            }
            // -tableChosenBefore (0.86): columns he chose before the Battery column came —
            // Weight, Liquid and How many — so the table's first opening puts Battery among them.
            if args.contains("-tableChosenBefore") {
                UserDefaults.standard.set("weight,liquid,listQty", forKey: "ams.table.columns")
            }
        }
        let sky: Forecaster = AMSPackingApp.testing ? InventedForecast() : OpenMeteo()
        EditTiming.watch()
        if args.contains("-uiTestingEmpty") { return LibraryModel(store: MemoryStore(), usesICloud: false, sky: sky) }
        // The sample in a store FILE (0.91): a change saved here is not read back, and one the other
        // device writes into the store 15 s after launch — a thing called Sunglasses — still arrives.
        if args.contains("-uiTestingOnDisk"), let store = try? CloudStore(cloud: false, file: LibraryModel.freshTestFile("disk")) {
            let sample = SampleLibrary.make()
            try? store.apply(RecordChanges(puts: sample.records()))
            var later = sample
            later.addThing(name: "Sunglasses")
            let theirs = recordChanges(from: sample.records(), to: later.records()).puts
            DispatchQueue.main.asyncAfter(deadline: .now() + 15) { store.writeAsTheOtherDevice(theirs) }
            return LibraryModel(store: store, usesICloud: false, sky: sky)
        }
        #if DEBUG
        // The sample in a store FILE whose first save fails (0.93, the outside review of 0.92): the
        // app keeps its screens, says so in a note, and holds what the store holds.
        if args.contains("-uiTestingSaveFails"), let store = try? CloudStore(cloud: false, file: LibraryModel.freshTestFile("fails")) {
            // `-saveFailsBags` (0.94): the sample with his bags, so the failed save can be a bag page's.
            let sample = args.contains("-saveFailsBags") ? SampleLibrary.bags() : SampleLibrary.make()
            try? store.apply(RecordChanges(puts: sample.records()))
            store.failNextSave = true
            return LibraryModel(store: store, usesICloud: false, sky: sky)
        }
        // A photo whose bytes are in a file of their own that is not there when the app reads the
        // store (24 Oct 2026, crash A — his Mac, 0.99: iCloud had just brought a change in, the photo's
        // file was not there, and reading it threw; the app went on with its insides broken and
        // fell over at a click six minutes later). Written as the other device writes, then a thing
        // called Sunglasses: the Sunglasses must still arrive, and the app keep running.
        if args.contains("-uiTestingPhotoGone") {
            let url = LibraryModel.freshTestFile("gone")
            CloudStore.removeExternalFiles(of: url)
            if let store = try? CloudStore(cloud: false, file: url) {
                let sample = SampleLibrary.make()
                try? store.apply(RecordChanges(puts: sample.records()))
                var later = sample
                later.addThing(name: "Sunglasses")
                let photo = StoredRecord(table: .photos, key: "photo-gone",
                                         json: ["id": .string("photo-gone"), "createdAt": .string("2026-10-24T09:06:23.000Z"),
                                                "mime": .string("image/jpeg")],
                                         blob: Data(repeating: 0xA5, count: 1_000_000))
                // Both written through a store of their own on the same file, as iCloud's import writes;
                // the app's next read finds the photo with its file there, and the file goes between
                // that and the photo's bytes being read — as on his Mac, where iCloud was still busy.
                DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                    store.afterFetchForTests = { [weak store] in
                        CloudStore.removeExternalFiles(of: url)
                        store?.afterFetchForTests = nil
                    }
                    CloudStore.writeThroughAnotherStore(recordChanges(from: sample.records(), to: later.records()).puts + [photo], file: url)
                }
                return LibraryModel(store: store, usesICloud: false, sky: sky)
            }
        }
        // The sample with bags in a store FILE that outlives the app (0.98, the Apple way): a test ends
        // the app with a page open and changed, launches it again WITHOUT -keptStart, and finds what the
        // store kept. -keptStart (the first launch) makes the file afresh.
        if args.contains("-uiTestingKept") {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("kept-library.store")
            let fresh = args.contains("-keptStart") || !FileManager.default.fileExists(atPath: url.path)
            if fresh { for tail in ["", "-wal", "-shm"] { try? FileManager.default.removeItem(atPath: url.path + tail) } }
            if let store = try? CloudStore(cloud: false, file: url) {
                if fresh { try? store.apply(RecordChanges(puts: SampleLibrary.bags().records())) }
                return LibraryModel(store: store, usesICloud: false, sky: sky)
            }
        }
        #endif
        // A hung exchange with iCloud, invented (0.104, `TestHang`): the sample in a store FILE, so a
        // restart of the connection closes and opens a real store, as the app does with his.
        if TestHang.asked, let store = try? CloudStore(cloud: false, file: LibraryModel.freshTestFile("hangs")) {
            _ = TestHang.since                            // its minutes count back from now, the launch
            try? store.apply(RecordChanges(puts: SampleLibrary.make().records()))
            return LibraryModel(store: store, usesICloud: false, sky: sky)
        }
        // A library of his size, kept by SwiftData in a file as his is — every change pays what his
        // pays: all records built, compared, the store's whole fetch, and what the store says after
        // a save (`EditTiming`, 0.91). A fresh file each launch, in the app's temporary folder.
        if args.contains("-uiTestingBigLibrary"), let store = try? CloudStore(cloud: false, file: LibraryModel.freshTestFile("big")) {
            try? store.apply(RecordChanges(puts: SampleLibrary.big().records()))
            return LibraryModel(store: store, usesICloud: false, sky: sky)
        }
        if args.contains("-uiTestingChecks") {
            return LibraryModel(store: MemoryStore(SampleLibrary.checks().records()), usesICloud: false, sky: sky)
        }
        if args.contains("-uiTestingOnSite") {
            return LibraryModel(store: MemoryStore(SampleLibrary.underWay().records()), usesICloud: false, sky: sky)
        }
        if args.contains("-uiTestingLeaving") {
            return LibraryModel(store: MemoryStore(SampleLibrary.leaving().records()), usesICloud: false, sky: sky)
        }
        if args.contains("-uiTestingBigBase") {
            return LibraryModel(store: MemoryStore(SampleLibrary.bigBase().records()), usesICloud: false, sky: sky)
        }
        if args.contains("-uiTestingBattery") {
            let byPlane = args.contains("-batteryByPlane"), toDo = args.contains("-batteryToDo")
            return LibraryModel(store: MemoryStore(SampleLibrary.battery(byPlane: byPlane, toDo: toDo).records()), usesICloud: false, sky: sky)
        }
        if args.contains("-uiTestingKits") {
            let underWay = args.contains("-kitsUnderWay")
            return LibraryModel(store: MemoryStore(SampleLibrary.kits(underWay: underWay).records()), usesICloud: false, sky: sky)
        }
        if args.contains("-uiTestingOldConditions") {
            return LibraryModel(store: MemoryStore(SampleLibrary.oldConditions().records()), usesICloud: false, sky: sky)
        }
        if args.contains("-uiTestingLostSection") {
            return LibraryModel(store: MemoryStore(SampleLibrary.lostSection()), usesICloud: false, sky: sky)
        }
        if args.contains("-uiTestingOldPhoto") {
            return LibraryModel(store: MemoryStore(SampleLibrary.oldPhoto().records()), usesICloud: false, sky: sky)
        }
        if args.contains("-uiTestingTwoLibraries") {
            return LibraryModel(store: MemoryStore(SampleLibrary.doubled().records()), usesICloud: false, sky: sky)
        }
        if args.contains("-uiTestingSections") {
            return LibraryModel(store: MemoryStore(SampleLibrary.sectioned().records()), usesICloud: false, sky: sky)
        }
        if args.contains("-uiTestingWhose") {
            return LibraryModel(store: MemoryStore(SampleLibrary.whose().records()), usesICloud: false, sky: sky)
        }
        if args.contains("-uiTestingBeforeStart") {
            return LibraryModel(store: MemoryStore(SampleLibrary.beforeStart().records()), usesICloud: false, sky: sky)
        }
        if args.contains("-uiTestingThingReminders") {
            return LibraryModel(store: MemoryStore(SampleLibrary.thingReminders().records()), usesICloud: false, sky: sky)
        }
        if args.contains("-uiTestingReminders") {
            return LibraryModel(store: MemoryStore(SampleLibrary.reminders().records()), usesICloud: false, sky: sky)
        }
        if args.contains("-uiTestingWorkouts") {
            return LibraryModel(store: MemoryStore(SampleLibrary.workouts().records()), usesICloud: false, sky: sky)
        }
        if args.contains("-uiTestingTravel") {
            return LibraryModel(store: MemoryStore(SampleLibrary.travel().records()), usesICloud: false, sky: sky)
        }
        if args.contains("-uiTestingGrabHeadings") {
            return LibraryModel(store: MemoryStore(SampleLibrary.grabHeadings().records()), usesICloud: false, sky: sky)
        }
        if let n = args.firstIndex(of: "-uiTestingPlaces") {
            let when = n + 1 < args.count ? args[n + 1] : ""
            return LibraryModel(store: MemoryStore(SampleLibrary.places(when).records()), usesICloud: false, sky: sky)
        }
        if args.contains("-uiTestingSoon") {
            return LibraryModel(store: MemoryStore(SampleLibrary.soon().records()), usesICloud: false, sky: sky)
        }
        if args.contains("-uiTestingNotes") {
            return LibraryModel(store: MemoryStore(SampleLibrary.notes().records()), usesICloud: false, sky: sky)
        }
        if args.contains("-uiTestingPockets") {
            return LibraryModel(store: MemoryStore(SampleLibrary.pockets().records()), usesICloud: false, sky: sky)
        }
        if args.contains("-uiTestingHealth") {
            return LibraryModel(store: MemoryStore(SampleLibrary.health().records()), usesICloud: false, sky: sky)
        }
        if args.contains("-uiTestingLostBag") {
            return LibraryModel(store: MemoryStore(SampleLibrary.lostBag().records()), usesICloud: false, sky: sky)
        }
        if args.contains("-uiTestingBags") {
            return LibraryModel(store: MemoryStore(SampleLibrary.bags().records()), usesICloud: false, sky: sky)
        }
        if args.contains("-uiTestingPackingDay") {
            let almost = args.contains("-packingDayAlmost"), byPlane = args.contains("-packingDayByPlane")
            let inner = args.contains("-packingDayInner")
            return LibraryModel(store: MemoryStore(SampleLibrary.packingDay(almost: almost, byPlane: byPlane, inner: inner).records()),
                                usesICloud: false, sky: sky)
        }
        if args.contains("-uiTestingReviewedUndated") {
            return LibraryModel(store: MemoryStore(SampleLibrary.reviewedUndated().records()), usesICloud: false, sky: sky)
        }
        if args.contains("-uiTestingReviewed") {
            return LibraryModel(store: MemoryStore(SampleLibrary.reviewed().records()), usesICloud: false, sky: sky)
        }
        if args.contains("-uiTesting") {
            return LibraryModel(store: MemoryStore(SampleLibrary.make().records()), usesICloud: false, sky: sky)
        }
        // Under the tests, never his store (0.104): an argument starting with -uiTesting that no line above
        // knows used to fall through to the app's own store file — on his Mac, a test build shares the
        // app's folder, so that is HIS library. The sample in memory instead.
        if AMSPackingApp.testing {
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
