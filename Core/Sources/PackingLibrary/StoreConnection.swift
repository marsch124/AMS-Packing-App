#if canImport(SwiftData)
import Foundation
import SwiftData
import CoreData

/// The library's store, open — and able to be closed and opened again IN THE SAME RUN of the app, the
/// way quitting Packing and opening it again does (0.104, his "can we harden this?" of 28 Oct 2026).
///
/// Why (his Mac, 21 and 28 Oct 2026): right after a launch, one exchange with iCloud never finished, and
/// iCloud's side of the store does one exchange at a time — so nothing came in again until he quit the
/// app. The log of 28 Oct says why that send never finished: TestFlight had opened the new build BEHIND
/// his other windows, the system took the app for one in the background and held its request back
/// ("discretionary"), and it never sent a byte in 387 seconds. Opened again in front, it fetched in 2 s.
///
/// How it closes — Core Data's own way to stop iCloud for a store: the store is REMOVED from the
/// coordinator it was opened on. That tears the old iCloud connection down ("Told to tear down with
/// reason: Store Removed") — the old one gone before the new one opens. SwiftData does not show its
/// coordinator, so it is caught as SwiftData adds the store (`NSPersistentStoreCoordinatorStoresDidChange`,
/// a public notification, posted while the store is added).
///
/// Never two at once: an `exclusive` store file (the iCloud one) cannot be opened while it is open
/// already — not by a second connection, not again before `close` removed it.
///
/// Here, not in the app, so a model test can reach it on a real store file.
@available(iOS 18, macOS 15, *)
public final class StoreConnection {
    public let schema: Schema
    public let configuration: ModelConfiguration
    /// Only one open connection to this store file at a time (the iCloud store).
    public let exclusive: Bool
    /// The container while open.
    public private(set) var container: ModelContainer?
    /// The Core Data side, caught as the store was added: what `close` removes the store from.
    private var coordinator: NSPersistentStoreCoordinator?
    private var store: NSPersistentStore?

    /// Store files open right now, exclusive ones only.
    private static var openFiles: Set<String> = []
    private static let lock = NSLock()

    public struct AlreadyOpen: Error {}
    public struct NotOpen: Error {}

    public init(schema: Schema, configuration: ModelConfiguration, exclusive: Bool) {
        self.schema = schema
        self.configuration = configuration
        self.exclusive = exclusive
    }

    /// The file, as one name whatever path led to it (/var or /private/var).
    private var fileKey: String { configuration.url.resolvingSymlinksInPath().standardizedFileURL.path }

    /// Can `close` take this store away cleanly? Only when its coordinator was caught.
    public var canClose: Bool { container != nil && coordinator != nil && store != nil }

    /// Open the store. Throws `AlreadyOpen` for an exclusive file that is open already.
    @discardableResult
    public func open() throws -> ModelContainer {
        if let container { return container }
        let key = fileKey
        if exclusive {
            Self.lock.lock()
            defer { Self.lock.unlock() }
            guard !Self.openFiles.contains(key) else { throw AlreadyOpen() }
            Self.openFiles.insert(key)
        }
        let caught = Caught()
        let watch = NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreCoordinatorStoresDidChange, object: nil, queue: nil
        ) { note in
            guard let psc = note.object as? NSPersistentStoreCoordinator,
                  let added = note.userInfo?[NSAddedPersistentStoresKey] as? [NSPersistentStore] else { return }
            for s in added where s.url?.resolvingSymlinksInPath().standardizedFileURL.path == key { caught.set(psc, s) }
        }
        defer { NotificationCenter.default.removeObserver(watch) }
        do {
            let made = try ModelContainer(for: schema, configurations: [configuration])
            container = made
            (coordinator, store) = caught.get()
            return made
        } catch {
            if exclusive { Self.forget(key) }
            throw error
        }
    }

    /// How a close went.
    public struct Closed: Equatable {
        /// The store was taken off its coordinator — its iCloud connection torn down.
        public var removed: Bool
        /// Nothing in this run holds the old container any more.
        public var released: Bool
        public init(removed: Bool, released: Bool) { self.removed = removed; self.released = released }
    }

    /// Take the store off its coordinator — Core Data's own teardown of its iCloud connection — and let
    /// the container go. Everything that used it (its contexts) must be let go BEFORE: `released` says
    /// whether anything still held the container. Refuses (`NotOpen`, nothing changed) when the store
    /// cannot be removed — then nothing is closed, and the store works on as it was.
    public func close() throws -> Closed {
        try detach()
        return Closed(removed: true, released: release())
    }

    /// Step one of `close`: the store taken off its coordinator — its iCloud connection torn down. A
    /// refusal changes nothing. (No strong hold on the coordinator outlives this call.)
    public func detach() throws {
        guard container != nil, let coordinator, let store else { throw NotOpen() }
        try coordinator.remove(store)
        self.store = nil
    }

    /// Step two: the container let go; true when nothing in this run holds it or its coordinator any
    /// more. After it the file can be opened again.
    @discardableResult
    public func release() -> Bool {
        weak var oldContainer: ModelContainer?
        weak var oldCoordinator: NSPersistentStoreCoordinator?
        autoreleasepool {
            oldContainer = container
            oldCoordinator = coordinator
            store = nil
            coordinator = nil
            container = nil
        }
        if exclusive { Self.forget(fileKey) }
        return oldContainer == nil && oldCoordinator == nil
    }

    /// Is this store file open right now (exclusive files only)?
    public static func isOpen(_ url: URL) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return openFiles.contains(url.resolvingSymlinksInPath().standardizedFileURL.path)
    }

    private static func forget(_ key: String) {
        lock.lock()
        openFiles.remove(key)
        lock.unlock()
    }

    /// The coordinator and store caught during `open` (the notification may come on any thread).
    private final class Caught: @unchecked Sendable {
        private let lock = NSLock()
        private var psc: NSPersistentStoreCoordinator?
        private var store: NSPersistentStore?
        func set(_ c: NSPersistentStoreCoordinator, _ s: NSPersistentStore) { lock.lock(); psc = c; store = s; lock.unlock() }
        func get() -> (NSPersistentStoreCoordinator?, NSPersistentStore?) { lock.lock(); defer { lock.unlock() }; return (psc, store) }
    }
}
#endif
