import Foundation
import CoreSpotlight
import UniformTypeIdentifiers
import PackingCore
import PackingLibrary
#if os(iOS)
import UIKit
#else
import AppKit
#endif

// Find your things in Spotlight (0.92 — his yes of 19 Oct 2026: "type 'headlamp' in Spotlight on
// the iPhone or Mac and see the thing and where it is, without opening the app").
//
// Every thing of his is one result in the device's own Spotlight: its name, where it is now (the
// words are the model's — `Library.spotlightThings`, PackingLibrary/SpotlightThings.swift), its
// first photo (else Spotlight shows the app's icon). Tapping a result opens the app on that thing's
// page — at a cold start and while it runs (`ThingSpotlight.open`, RootView, Home).
//
// KEPT CURRENT, CHEAPLY. After every settled change of the library (RootView's 2-second wait, the
// one that puts the reminders right), and whenever the app comes to the front (the day alone moves
// a trip under way on), the words are worked out off the main thread, and only the things whose
// fingerprint changed are handed over; things that went are taken out. The fingerprints handed over
// are remembered on the device (`indexedKey`) — and the index itself remembers which hand-over it
// last took (Spotlight's "client state", `generationKey`): an index that was lost, rebuilt, or not
// brought along to a new iPhone says another, and then everything is handed over again.
//
// PER DEVICE. Settings → "Show my things in Spotlight" (on unless he switches it off). Off takes
// every thing out of this device's Spotlight at once. Never synced: each device has its own
// Spotlight, as it has its own reminders switch.
//
// PRIVATE. On the iPhone the index is kept locked while the iPhone is locked
// (`NSFileProtectionComplete`): Search on a locked iPhone shows none of his things. What is handed
// over, and what never is: SpotlightThings.swift.

/// Where the results go: the device's own Spotlight — or, under the UI tests, a list in memory. The
/// tests run on his Mac too, and the sample's invented things must never reach his Spotlight.
protocol SpotlightShelf: AnyObject {
    /// Can this device's Spotlight take anything?
    var available: Bool { get }
    /// Which hand-over the index last took; nil = none (a new or lost index). Throws when it cannot
    /// say (the iPhone locked).
    func lastHandOver() async throws -> String?
    /// Hand these over (new or changed) with their small pictures (by thing id; none = the app's
    /// icon), and mark the index with this hand-over.
    func put(_ things: [SpotlightThing], pictures: [String: Data], handOver: String) async throws
    /// Take these things (by id) out.
    func remove(_ ids: [String], handOver: String) async throws
    /// Take every thing out.
    func removeAll() async throws
    /// How many things the shelf itself knows it holds — only a shelf that can count (the tests').
    var heldCount: Int? { get }
}

/// The device's own Spotlight.
final class DeviceSpotlight: NSObject, SpotlightShelf, CSSearchableIndexDelegate {
    /// Every result's group in the index: a later kind (a trip) gets its own.
    static let domain = "things"
    private let index: CSSearchableIndex

    override init() {
        #if os(iOS)
        index = CSSearchableIndex(name: "things", protectionClass: .complete)
        #else
        index = CSSearchableIndex(name: "things")
        #endif
        super.init()
        index.indexDelegate = self
    }

    var available: Bool { CSSearchableIndex.isIndexingAvailable() }
    var heldCount: Int? { nil }

    func lastHandOver() async throws -> String? {
        try await withCheckedThrowingContinuation { (go: CheckedContinuation<String?, Error>) in
            index.fetchLastClientState { data, error in
                if let error { go.resume(throwing: error) } else { go.resume(returning: data.flatMap { String(data: $0, encoding: .utf8) }) }
            }
        }
    }

    func put(_ things: [SpotlightThing], pictures: [String: Data], handOver: String) async throws {
        let items = things.map { t -> CSSearchableItem in
            let a = CSSearchableItemAttributeSet(contentType: .content)
            a.title = t.title
            a.displayName = t.title
            a.contentDescription = t.place
            a.keywords = t.keywords
            a.thumbnailData = pictures[t.id]
            let item = CSSearchableItem(uniqueIdentifier: t.identifier, domainIdentifier: DeviceSpotlight.domain, attributeSet: a)
            // A result stays until the app takes it out (the default is a month).
            item.expirationDate = .distantFuture
            return item
        }
        try await batch(handOver) { done in self.index.indexSearchableItems(items, completionHandler: done) }
    }

    func remove(_ ids: [String], handOver: String) async throws {
        let gone = ids.map { SpotlightThing.prefix + $0 }
        try await batch(handOver) { done in self.index.deleteSearchableItems(withIdentifiers: gone, completionHandler: done) }
    }

    func removeAll() async throws {
        try await withCheckedThrowingContinuation { (go: CheckedContinuation<Void, Error>) in
            index.deleteSearchableItems(withDomainIdentifiers: [DeviceSpotlight.domain]) { error in
                if let error { go.resume(throwing: error) } else { go.resume() }
            }
        }
    }

    /// One change in a batch that leaves the index marked with this hand-over. Never two at once:
    /// `ThingSpotlight` runs one job at a time.
    private func batch(_ handOver: String, _ body: (@escaping (Error?) -> Void) -> Void) async throws {
        index.beginBatch()
        var failed: Error?
        body { error in if let error { failed = error } }
        try await withCheckedThrowingContinuation { (go: CheckedContinuation<Void, Error>) in
            index.endBatch(withClientState: Data(handOver.utf8)) { error in
                if let error = error ?? failed { go.resume(throwing: error) } else { go.resume() }
            }
        }
    }

    // The system lost the index (or some of it) and asks for it again while the app runs.
    func searchableIndex(_ searchableIndex: CSSearchableIndex,
                         reindexAllSearchableItemsWithAcknowledgementHandler acknowledgementHandler: @escaping () -> Void) {
        Task { @MainActor in
            ThingSpotlight.shared.handOverAgain(nil)
            acknowledgementHandler()
        }
    }

    func searchableIndex(_ searchableIndex: CSSearchableIndex, reindexSearchableItemsWithIdentifiers identifiers: [String],
                         acknowledgementHandler: @escaping () -> Void) {
        Task { @MainActor in
            ThingSpotlight.shared.handOverAgain(identifiers.compactMap(SpotlightThing.thingId))
            acknowledgementHandler()
        }
    }
}

/// The UI tests' Spotlight: what was handed over, in memory, gone at every launch — as a new
/// device's index is empty.
final class MemorySpotlight: SpotlightShelf {
    private(set) var held: [String: SpotlightThing] = [:]
    private(set) var pictured: Set<String> = []
    private var mark: String?
    var available: Bool { true }
    var heldCount: Int? { held.count }

    func lastHandOver() async throws -> String? { mark }

    func put(_ things: [SpotlightThing], pictures: [String: Data], handOver: String) async throws {
        for t in things {
            held[t.id] = t
            if pictures[t.id] != nil { pictured.insert(t.id) } else { pictured.remove(t.id) }
        }
        mark = handOver
    }

    func remove(_ ids: [String], handOver: String) async throws {
        for id in ids { held[id] = nil; pictured.remove(id) }
        mark = handOver
    }

    func removeAll() async throws {
        held = [:]
        pictured = []
    }
}

/// Keeps this device's Spotlight holding his things, as they are now — and opens a tapped one.
@MainActor
final class ThingSpotlight: ObservableObject {
    static let shared = ThingSpotlight()

    /// Settings' switch, per device (on unless he switched it off).
    static let onKey = "ams.spotlight.on"
    /// The fingerprint of each thing handed over, by thing id.
    static let indexedKey = "ams.spotlight.indexed"
    /// The mark of the last hand-over, kept here and in the index itself.
    static let generationKey = "ams.spotlight.generation"

    /// Show my things in Spotlight.
    @Published private(set) var on: Bool
    /// How many things are in Spotlight on this device.
    @Published private(set) var count = 0
    /// This device's Spotlight takes nothing.
    @Published private(set) var unavailable = false

    let shelf: SpotlightShelf
    private var indexed: [String: String]
    private var generation: String
    /// Has the index been asked, since launch, whether it still holds the last hand-over?
    private var askedIndex = false

    /// One job at a time, in order: hand-overs and the switch's clearing never overlap.
    private var chain: Task<Void, Never>?
    /// The newest library waiting to be handed over (only the newest counts).
    private var waiting: Library?
    private var handOverQueued = false

    private init() {
        let d = UserDefaults.standard
        let tests = AMSPackingApp.testing
        // Under the tests: a memory shelf, the switch on — and (`-spotlightForReal`, a debug build
        // only) the device's own, to look at real results on a simulator.
        #if DEBUG
        let real = !tests || ProcessInfo.processInfo.arguments.contains("-spotlightForReal")
        #else
        let real = !tests
        #endif
        shelf = real ? DeviceSpotlight() : MemorySpotlight()
        if tests { d.removeObject(forKey: ThingSpotlight.onKey) }
        on = d.object(forKey: ThingSpotlight.onKey) as? Bool ?? true
        indexed = d.dictionary(forKey: ThingSpotlight.indexedKey) as? [String: String] ?? [:]
        generation = d.string(forKey: ThingSpotlight.generationKey) ?? ""
        count = shelf.heldCount ?? indexed.count
    }

    // MARK: Keeping it current

    /// The library settled after a change, or the app came to the front: hand over what changed.
    func sync(_ library: Library) {
        guard on else { return }
        waiting = library
        guard !handOverQueued else { return }
        handOverQueued = true
        enqueue { [self] in
            handOverQueued = false
            guard let lib = waiting else { return }
            waiting = nil
            await handOver(lib)
        }
    }

    /// The system asked for these things again (nil = all of them).
    func handOverAgain(_ ids: [String]?) {
        if let ids { for id in ids { indexed[id] = nil } } else { indexed = [:] }
        save()
        sync(LibraryModel.shared.library)
    }

    /// Settings' switch. Off takes every thing out of this device's Spotlight; on hands them all over.
    func set(on want: Bool, library: Library) {
        on = want
        UserDefaults.standard.set(want, forKey: ThingSpotlight.onKey)
        if want {
            sync(library)
        } else {
            waiting = nil
            enqueue { [self] in await takeAllOut() }
        }
    }

    private func enqueue(_ job: @escaping @MainActor () async -> Void) {
        let before = chain
        chain = Task { @MainActor in
            await before?.value
            await job()
        }
    }

    private func handOver(_ library: Library) async {
        guard on else { return }
        guard shelf.available else { unavailable = true; return }
        unavailable = false
        // Once a launch: does the index still hold the last hand-over? If not (lost, rebuilt, a new
        // iPhone restored from a backup), what it holds is unknown: everything is handed over again.
        if !askedIndex {
            let mark: String?
            do { mark = try await shelf.lastHandOver() } catch { return }       // cannot say (locked): next time
            askedIndex = true
            if mark != generation || generation.isEmpty {
                indexed = [:]
                generation = UUID().uuidString
                try? await shelf.removeAll()
                save()
            }
        }
        let today = Today.local
        let held = indexed
        let work = await Task.detached(priority: .utility) { () -> (put: [SpotlightThing], drop: [String], pictures: [String: Data]) in
            let now = library.spotlightThings(today: today)
            let c = SpotlightWords.changes(now, indexed: held)
            var pictures: [String: Data] = [:]
            for t in c.put where !t.photoId.isEmpty {
                if let p = library.photos.first(where: { $0.id == t.photoId }), let small = ThingSpotlight.picture(p) {
                    pictures[t.id] = small
                }
            }
            return (c.put, c.drop, pictures)
        }.value
        do {
            if !work.drop.isEmpty {
                try await shelf.remove(work.drop, handOver: generation)
                for id in work.drop { indexed[id] = nil }
                save()
            }
            // In batches, each remembered as it lands: a hand-over cut short resumes where it stopped.
            var from = 0
            while from < work.put.count {
                guard on else { return }                        // switched off meanwhile: the clearing follows
                let batch = Array(work.put[from..<min(from + 100, work.put.count)])
                try await shelf.put(batch, pictures: work.pictures.filter { p in batch.contains { $0.id == p.key } },
                                    handOver: generation)
                for t in batch { indexed[t.id] = t.fingerprint }
                save()
                from += batch.count
            }
        } catch {
            // Left as it is: what did not land has no fingerprint here, so the next settled change
            // (or the next time the app comes to the front) hands it over again.
        }
        count = shelf.heldCount ?? indexed.count
    }

    private func takeAllOut() async {
        try? await shelf.removeAll()
        indexed = [:]
        save()
        count = shelf.heldCount ?? 0
    }

    private func save() {
        let d = UserDefaults.standard
        d.set(indexed, forKey: ThingSpotlight.indexedKey)
        d.set(generation, forKey: ThingSpotlight.generationKey)
    }

    /// A thing's photo as Spotlight shows it beside the result: small (at most 240 pixels).
    nonisolated static func picture(_ photo: PhotoRecord) -> Data? {
        guard let comma = photo.data.firstIndex(of: ","),
              let data = Data(base64Encoded: String(photo.data[photo.data.index(after: comma)...])) else { return nil }
        return JPEG.make(from: data, maxSide: 240)
    }

    // MARK: Opening a tapped result

    /// A result tapped in Spotlight — on the iPhone or the Mac, starting the app or while it runs:
    /// the app opens on that thing's page (Home, over whatever was up). A thing gone since it was
    /// handed over opens nothing (its result is taken out at the next hand-over).
    @discardableResult
    static func open(_ activity: NSUserActivity) -> Bool {
        guard activity.activityType == CSSearchableItemActionType,
              let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
              let id = SpotlightThing.thingId(identifier) else { return false }
        let model = LibraryModel.shared
        guard model.library.items.contains(where: { $0.id == id }) else { return false }
        #if os(macOS)
        // With no window of the app open, one opens for the page (as the Dock menu does).
        NSApp.activate()
        if GrabQuickActions.mainWindows == 0 { GrabQuickActions.openMainWindow?() }
        #endif
        model.thingToOpen = id
        return true
    }

    // MARK: The tests

    /// The activity Spotlight hands the app for a tapped result.
    static func tapped(_ identifier: String) -> NSUserActivity {
        let activity = NSUserActivity(activityType: CSSearchableItemActionType)
        activity.userInfo = [CSSearchableItemActivityIdentifier: identifier]
        return activity
    }

    /// UI tests only: the result titled so, tapped — taken from what the app handed over (so a thing
    /// not in Spotlight cannot be opened this way either), once it has been, and handed to the app
    /// the way the system hands it (the scene's delegate on the iPhone, the app's delegate on the Mac).
    /// `-spotlightTap <name>`: as the app opens; `-spotlightTapOnReturn <name>` (iPhone): as it comes
    /// back to the front; `-spotlightTapWhenClosed <name>` (Mac): once its last window has closed.
    static func playTapped(_ flag: String) {
        let args = ProcessInfo.processInfo.arguments
        guard AMSPackingApp.testing, let n = args.firstIndex(of: flag), n + 1 < args.count else { return }
        let title = args[n + 1]
        Task { @MainActor in
            var found: SpotlightThing?
            for _ in 0..<40 {
                found = (shared.shelf as? MemorySpotlight)?.held.values.first { $0.title == title }
                if found != nil { break }
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
            guard let thing = found else { return }
            deliver(tapped(thing.identifier))
        }
    }

    /// Hand an activity to the app as the system does.
    static func deliver(_ activity: NSUserActivity) {
        #if os(iOS)
        guard let scene = UIApplication.shared.connectedScenes.first(where: { $0 is UIWindowScene }) else { return }
        scene.delegate?.scene?(scene, continue: activity)
        #else
        _ = NSApp.delegate?.application?(NSApp, continue: activity, restorationHandler: { _ in })
        #endif
    }
}
