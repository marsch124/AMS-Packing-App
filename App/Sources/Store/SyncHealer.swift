import Foundation
import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif
import PackingCore
import PackingLibrary

/// A sync that hangs heals itself (0.104 — his "can we harden this?", 28 Oct 2026): does what
/// `SyncHeal` decides. Every 30 s, and as the app comes to the front, it looks at the store's own record
/// of iCloud (`SyncWatch.look`); when an exchange has run with no end for five minutes — or, begun while
/// the app was not in front, still runs a minute after it came to the front — it restarts the connection
/// (`LibraryModel.restartSync`): the store closed and opened again in place, as quitting Packing and
/// opening it again does. Only in front, never while a page holds changes not confirmed with Done or a
/// save is under way, three times an hour at most. Each restart is noted on this device (`restarts`) —
/// the sync card and Home's sync dot say it ("Receiving was stuck — restarted the connection at 07:51").
/// Restart sync on the card does the same at once (or once the open page is closed).
@MainActor
final class SyncHealer: ObservableObject {
    static let shared = SyncHealer()

    /// The restarts this device made, the newest last — kept on this device only (never synced).
    @Published private(set) var restarts: [SyncHeal.Restart]
    /// Why a restart that is due waits (nil: none is due, or it is not waiting).
    @Published private(set) var waiting: SyncHeal.Wait?
    /// Restart sync was pressed while a page held changes: it restarts once the page is closed.
    @Published private(set) var pressedWaiting = false

    static let key = "ams.sync.restarts"
    /// When this run of the app began.
    let launched = Date()
    private var looking: Task<Void, Never>?

    private init() {
        let kept = UserDefaults.standard.data(forKey: SyncHealer.key)
        restarts = kept.flatMap { try? JSONDecoder().decode([SyncHeal.Restart].self, from: $0) } ?? []
    }

    /// Five minutes — under the tests' invented hang, `-selfHealAfter` seconds, and without it never by
    /// itself (Restart sync only); never under the tests' fixed records (`-syncLight`), which must stay
    /// as invented.
    private var after: TimeInterval? {
        if TestHang.asked { return TestHang.healAfter }
        return SyncWatch.invented == nil ? SyncHeal.restartAfter : nil
    }
    /// How often it looks (a second under the tests' invented hang).
    private var every: Duration { TestHang.asked ? .seconds(1) : .seconds(30) }

    /// Is the app the one in front? (A request made while it is not is held back by the system.)
    static var inFront: Bool {
        #if os(iOS)
        UIApplication.shared.applicationState == .active
        #else
        NSApp.isActive
        #endif
    }

    /// Starts looking (once per run — the Mac's second window does not start a second look).
    func start(_ model: LibraryModel) {
        guard looking == nil else { return }
        SyncWatch.watchFront()
        looking = Task { [weak self] in
            while !Task.isCancelled {
                await self?.look(model)
                try? await Task.sleep(for: self?.every ?? .seconds(30))
            }
        }
    }

    /// One look and what follows from it.
    func look(_ model: LibraryModel) async {
        tick(model, seen: await SyncWatch.look(model))
    }

    private func tick(_ model: LibraryModel, seen: SyncWatch.Seen) {
        guard seen.on, !model.isDraft, model.state == .ready else { waiting = nil; return }
        // The last restart's new connection was refused by iCloud: said, and no more restarts by itself
        // in this run (quitting Packing and opening it again is what helps then).
        if let last = restarts.last, last.ok, SyncHeal.took(last, check: seen.check) == false {
            restarts[restarts.count - 1].ok = false
            keep()
        }
        let busy = OpenPages.anyChanged || model.saving
        if pressedWaiting {
            guard !busy else { return }
            pressedWaiting = false
            restart(model, why: .pressed)
            return
        }
        guard let after else { waiting = nil; return }
        switch SyncHeal.decide(seen.check, now: seen.now, awake: SyncWatch.awake, cameForward: SyncWatch.cameForward,
                               inFront: SyncHealer.inFront, pageOpen: busy, restarts: restarts, launched: launched,
                               after: after) {
        case .nothing: waiting = nil
        case .wait(let why, _): waiting = why
        case .restart(let r): waiting = nil; restart(model, why: r.sending ? .sending : .receiving)
        }
    }

    /// Restart sync, pressed: now — or, while a page holds changes, as soon as it is closed.
    func press(_ model: LibraryModel) {
        if OpenPages.anyChanged || model.saving {
            pressedWaiting = true
            return
        }
        restart(model, why: .pressed)
    }

    /// A page with changes has closed: a restart waiting for it goes now (not at the next look).
    func pageClosed() {
        guard pressedWaiting || waiting == .page else { return }
        Task { await look(LibraryModel.shared) }
    }

    private func restart(_ model: LibraryModel, why: SyncHeal.Restart.Why) {
        let outcome = model.restartSync()
        guard outcome != .refused else { return }                // nothing changed: asked again at the next look
        let at = Date()
        restarts = SyncHeal.noting(SyncHeal.Restart(at: at, why: why, ok: outcome == .done), in: restarts)
        keep()
        waiting = nil
        // The exchange that hung began before the restart: its minutes count from here (`SyncCheck.hung`),
        // as from the app coming to the front.
        SyncWatch.awake = max(SyncWatch.awake, at)
        TestHang.healed(at: at)
        Task { _ = await SyncWatch.look(model); SyncWatch.restarted.send() }
    }

    private func keep() {
        if let data = try? JSONEncoder().encode(restarts) { UserDefaults.standard.set(data, forKey: SyncHealer.key) }
    }
}

/// UI tests only (0.104, with `-uiTesting`): `-importHangs <minutes>` — an invented record of iCloud
/// with a receive that has had no end since that many minutes before launch (`page`: from the moment a
/// page first holds a change), the library in a store FILE (`LibraryModel.forThisLaunch`) so a restart
/// closes and opens a real store; after a restart, the record says In sync. `-selfHealAfter <seconds>`:
/// the app restarts by itself after that long — without it, only Restart sync restarts.
enum TestHang {
    private static let args = ProcessInfo.processInfo.arguments

    /// The hook is on.
    static let asked: Bool = AMSPackingApp.testing && args.contains("-importHangs")

    /// From when a page first holds a change (`page`), not from launch.
    static let fromPage: Bool = asked && value("-importHangs") == "page"

    /// `-selfHealAfter` seconds.
    static let healAfter: TimeInterval? = value("-selfHealAfter").flatMap(Double.init)

    private static func value(_ name: String) -> String? {
        guard let n = args.firstIndex(of: name), n + 1 < args.count else { return nil }
        return args[n + 1]
    }

    /// Set once, then only read — off the main thread too (`SyncWatch.read`).
    private static let lock = NSLock()
    private static var hungAt: Date? = {
        guard asked, !fromPage, let minutes = value("-importHangs").flatMap(Double.init) else { return nil }
        return Date().addingTimeInterval(-minutes * 60)
    }()
    private static var healedAt: Date?

    /// When the receive began that never ends (nil: not yet — `page`).
    static var since: Date? { lock.lock(); defer { lock.unlock() }; return hungAt }

    /// A page holds a change: with `page`, the receive hangs from now.
    static func pageChanged() {
        guard fromPage else { return }
        lock.lock(); defer { lock.unlock() }
        if hungAt == nil { hungAt = Date() }
    }

    static func healed(at: Date) {
        guard asked else { return }
        lock.lock(); defer { lock.unlock() }
        healedAt = at
    }

    /// The invented record: good exchanges before; the receive with no end; after a restart a new
    /// connection set up and a good send and receive.
    static var check: SyncCheck? {
        guard asked else { return nil }
        lock.lock(); defer { lock.unlock() }
        let start = hungAt ?? Date()
        let good = [SyncCheck.Event(type: 2, ok: true, at: start.addingTimeInterval(-120)),
                    SyncCheck.Event(type: 1, ok: true, at: start.addingTimeInterval(-60))]
        guard let hungAt else { return SyncCheck(events: good) }
        let hung = SyncCheck.Event(type: 1, ok: false, at: hungAt, unfinished: true)
        guard let healedAt else { return SyncCheck(events: [hung] + good) }
        return SyncCheck(events: [SyncCheck.Event(type: 1, ok: true, at: healedAt.addingTimeInterval(1)),
                                  SyncCheck.Event(type: 2, ok: true, at: healedAt.addingTimeInterval(1)), hung] + good,
                         setup: SyncCheck.Event(type: 0, ok: true, at: healedAt.addingTimeInterval(0.5)))
    }
}
