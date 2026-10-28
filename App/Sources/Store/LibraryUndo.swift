import SwiftUI
import Combine
import PackingCore
import PackingLibrary
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// ⌘Z undo everywhere (0.105) — his "2. ⌘Z - yes please", 28 Oct 2026, to "⌘Z undo everywhere (Mac): undo
// and redo the last change, whatever page it was on." The steps and the rule with the other device are
// in Core (PackingLibrary/Undo.swift, `UndoBook`); `LibraryModel` keeps the book. This file is how the
// two devices reach it, the Apple way:
//
// - Mac: Edit ▸ Undo / Redo (⌘Z / ⇧⌘Z), named for the step — "Undo Tick Passport". The app's own items
//   take the place of the system's (`UndoCommands`), and hand the keys to the TEXT whenever they belong
//   to it: on a page with its own fields — a thing's, a template's, a bag's, Trip settings, Your choices —
//   ⌘Z is the fields' typing, as anywhere on the Mac, and never his library; a field elsewhere with typing
//   to take back takes it back first. The menu then shows the system's own words ("Undo Typing").
// - iPhone: shake to undo, three fingers — UIKit's undo manager of the window
//   (SwiftUI's environment `undoManager`), which this file keeps holding the same steps (`SystemUndo`),
//   and empties while a page with fields is open, so there too undo is the typing's.
// - The 6-second Undo under a trip, To do's and To buy's, and the table's Change all take back the step
//   they were shown for through the same book (`LibraryModel.undoStep`): ⌘Z and a banner never undo
//   one change twice, and a banner whose step ⌘Z took back goes.

/// What happened to the book, for the iPhone's undo manager (the Mac's menu reads the book itself).
enum UndoEvent {
    case recorded(UndoStep)
    /// The same press made another change: still one step, perhaps with another name.
    case joined(UndoStep)
    /// Taken back; the step that would put it back (nil: nothing was taken back).
    case undone(UndoStep?)
    case redone(UndoStep?)
    /// Anything else — forgotten, trimmed, a banner's undo of an older step: mirrored afresh.
    case reset
}

@MainActor
enum UndoEvents {
    static func changed(_ event: UndoEvent, _ model: LibraryModel) {
        #if os(iOS)
        SystemUndo.shared.changed(event, model)
        #else
        UndoMenu.shared.refreshSoon()
        #endif
    }
}

// MARK: - Pages with their own fields

/// The pages open now that keep what is typed until Done (the pages that ask before discarding — spec 06
/// §20a): while one is, undo is the typing's, never the library's.
@MainActor
enum EditingPages {
    private static var open: Set<UUID> = []
    static var anyOpen: Bool { !open.isEmpty }

    static func shows(_ id: UUID, page: Bool) {
        let was = open
        if page { open.insert(id) } else { open.remove(id) }
        if open != was { changed() }
    }

    static func gone(_ id: UUID) {
        if open.remove(id) != nil { changed() }
    }

    private static func changed() {
        #if os(iOS)
        SystemUndo.shared.rebuildSoon()
        #else
        UndoMenu.shared.refreshSoon()
        #endif
    }
}

// MARK: - The shop's reminders follow an undo

extension ShopReminders {
    /// An undo or a redo changed the buy list as a tap would: a line ticked or unticked ticks or unticks
    /// its reminder, a line gone takes its reminder with it — as To buy's own buttons do. (A line brought
    /// back comes without its old reminder, `Library.reverting`, and is sent again like a new one.)
    @MainActor
    static func follow(from before: Library, to after: Library) {
        var now: [String: ActionItem] = [:]
        for a in after.actions { now[a.id] = a }
        for was in before.actions {
            guard let rid = before.reminderOf(actionId: was.id) else { continue }
            if let a = now[was.id] {
                if a.done != was.done, after.reminderOf(actionId: a.id) == rid {
                    Task { await ShopReminders.shared.setDone(rid, a.done) }
                }
            } else {
                Task { await ShopReminders.shared.remove(rid) }
            }
        }
    }
}

#if os(macOS)
// MARK: - Mac: Edit ▸ Undo and Redo

/// Edit ▸ Undo and Redo in place of the system's: the step's name, ⌘Z and ⇧⌘Z.
struct UndoCommands: Commands {
    @ObservedObject private var menu = UndoMenu.shared

    var body: some Commands {
        CommandGroup(replacing: .undoRedo) {
            Button(menu.undo.title) { menu.performUndo() }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!menu.undo.on)
            Button(menu.redo.title) { menu.performRedo() }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!menu.redo.on)
        }
    }
}

/// What the two items say and do now — the library's step, or the text's typing.
@MainActor
final class UndoMenu: ObservableObject {
    static let shared = UndoMenu()

    struct Item: Equatable {
        var title: String
        var on: Bool
    }

    @Published private(set) var undo = Item(title: "Undo", on: false)
    @Published private(set) var redo = Item(title: "Redo", on: false)
    private var watching: [Any] = []
    private var bookWatch: AnyCancellable?
    private var queued = false

    private init() {
        // After every event (a key typed, a click, a window in front) and as a menu opens: cheap reads,
        // published only when something differs.
        for name in [NSApplication.didUpdateNotification, NSMenu.didBeginTrackingNotification] {
            watching.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { UndoMenu.shared.refresh() }
            })
        }
        // Not now: this can be made while `LibraryModel.shared` itself is being made (an import at launch
        // forgets the steps) — reaching for it here would wait on itself.
        DispatchQueue.main.async {
            UndoMenu.shared.bookWatch = LibraryModel.shared.$book.sink { _ in
                DispatchQueue.main.async { UndoMenu.shared.refresh() }
            }
        }
    }

    func refreshSoon() {
        guard !queued else { return }
        queued = true
        DispatchQueue.main.async { [weak self] in
            self?.queued = false
            self?.refresh()
        }
    }

    /// The window in front, what has the keys in it, and that one's undo manager.
    private func textSide() -> (page: Bool, typing: Bool, manager: UndoManager?) {
        let key = NSApp.keyWindow
        let responder = key?.firstResponder
        let manager = responder?.undoManager ?? key?.undoManager
        let typing = (responder as? NSTextView)?.isEditable == true
        return (EditingPages.anyOpen, typing, manager)
    }

    /// The text's turn: a page with its own fields is open, or a field has typing to take back.
    private func textUndoes() -> UndoManager?? {
        let side = textSide()
        if side.page || (side.typing && side.manager?.canUndo == true) { return .some(side.manager) }
        return nil
    }

    private func textRedoes() -> UndoManager?? {
        let side = textSide()
        if side.page || (side.typing && side.manager?.canRedo == true) { return .some(side.manager) }
        return nil
    }

    func refresh() {
        let book = LibraryModel.shared.book
        let u: Item, r: Item
        if let text = textUndoes() {
            u = Item(title: text?.canUndo == true ? text!.undoMenuItemTitle : "Undo", on: text?.canUndo == true)
        } else {
            u = Item(title: book.undoName.map { "Undo \($0)" } ?? "Undo", on: book.canUndo)
        }
        if let text = textRedoes() {
            r = Item(title: text?.canRedo == true ? text!.redoMenuItemTitle : "Redo", on: text?.canRedo == true)
        } else {
            r = Item(title: book.redoName.map { "Redo \($0)" } ?? "Redo", on: book.canRedo)
        }
        if u != undo { undo = u }
        if r != redo { redo = r }
    }

    func performUndo() {
        if textUndoes() != nil {
            NSApp.sendAction(Selector(("undo:")), to: nil, from: nil)   // the system's own Undo, for the text
        } else {
            LibraryModel.shared.undo()
        }
        refresh()
    }

    func performRedo() {
        if textRedoes() != nil {
            NSApp.sendAction(Selector(("redo:")), to: nil, from: nil)
        } else {
            LibraryModel.shared.redo()
        }
        refresh()
    }

    /// SwiftUI hands a menu item no identifier (ThingKeys.nameMenuItems): Edit's ⌘Z and ⇧⌘Z are named
    /// `edit-undo` and `edit-redo` for the tests, which find controls by id, never by words.
    nonisolated static func nameItems(_ bar: NSMenu) {
        for top in bar.items {
            for item in top.submenu?.items ?? [] where item.keyEquivalent.lowercased() == "z"
                && item.keyEquivalentModifierMask.contains(.command) {
                let id = item.keyEquivalentModifierMask.contains(.shift) || item.keyEquivalent == "Z" ? "edit-redo" : "edit-undo"
                if item.identifier?.rawValue != id { item.identifier = NSUserInterfaceItemIdentifier(id) }
            }
        }
    }
}
#endif

#if os(iOS)
// MARK: - iPhone: the window's undo manager holds the same steps

/// Shake to undo, three fingers: UIKit asks the window's undo manager. It is kept
/// holding the book's steps, newest last, each its own group under its own name ("Undo Tick Passport"),
/// and emptied of them while a page with its own fields is open. An undo it starts takes back the step
/// through the book (`LibraryModel.undo`) — the same move as the banners and the Mac's ⌘Z.
@MainActor
final class SystemUndo {
    static let shared = SystemUndo()
    private weak var manager: UndoManager?
    private weak var model: LibraryModel?
    /// The book's steps are in the manager (no page with fields is open).
    private var mirrored = false
    /// The manager is running one of ours: what the book does next goes onto its other stack.
    private var performing = false
    private var queued = false

    /// SwiftUI's undo manager for the app's window (RootView).
    func use(_ manager: UndoManager?, _ model: LibraryModel) {
        guard manager !== self.manager || self.model !== model else { return }
        self.manager?.removeAllActions(withTarget: self)
        self.manager = manager
        self.model = model
        rebuildSoon()
    }

    /// The undo manager the tests reach (`UndoTestHook`) — the one shake asks.
    var managerForTests: UndoManager? { manager }

    func changed(_ event: UndoEvent, _ model: LibraryModel) {
        guard model === self.model, let um = manager else { return }
        switch event {
        case .recorded(let step):
            if mirrored && !performing && !EditingPages.anyOpen { register(step, in: um, redo: false) } else { rebuildSoon() }
        case .joined(let step):
            if mirrored && um.groupingLevel > 0 { um.setActionName(step.name) } else { rebuildSoon() }
        case .undone(let back):
            if performing { if let back { register(back, in: um, redo: true) } } else { rebuildSoon() }
        case .redone(let again):
            if performing { if let again { register(again, in: um, redo: false) } } else { rebuildSoon() }
        case .reset:
            rebuildSoon()
        }
    }

    private func register(_ step: UndoStep, in um: UndoManager, redo: Bool) {
        let id = step.id
        um.registerUndo(withTarget: self) { me in
            MainActor.assumeIsolated { redo ? me.systemRedo(id) : me.systemUndo(id) }
        }
        um.setActionName(step.name)
    }

    /// The manager's Undo: the book's last step, if it is the one the manager holds.
    private func systemUndo(_ id: UndoStep.ID) {
        guard let model, model.book.undos.last?.id == id else { rebuildSoon(); return }
        performing = true
        defer { performing = false }
        if !model.undo() { rebuildSoon() }
    }

    private func systemRedo(_ id: UndoStep.ID) {
        guard let model, model.book.redos.last?.id == id else { rebuildSoon(); return }
        performing = true
        defer { performing = false }
        if !model.redo() { rebuildSoon() }
    }

    /// The manager emptied of our steps and filled again from the book — never while it is busy.
    func rebuildSoon() {
        guard !queued else { return }
        queued = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.queued = false
            self.rebuild()
        }
    }

    private func rebuild() {
        guard let um = manager, let model else { return }
        if um.isUndoing || um.isRedoing || um.groupingLevel > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in self?.rebuildSoon() }
            return
        }
        um.removeAllActions(withTarget: self)
        mirrored = !EditingPages.anyOpen
        guard mirrored, !model.book.undos.isEmpty else { return }
        let byEvent = um.groupsByEvent
        um.groupsByEvent = false
        for step in model.book.undos {
            um.beginUndoGrouping()
            register(step, in: um, redo: false)
            um.endUndoGrouping()
        }
        um.groupsByEvent = byEvent
    }
}
#endif

#if DEBUG
// MARK: - For the UI tests

extension OtherDeviceForTests {
    /// `-otherDeviceNoteAfterStep <words>` (0.105): once, half a second after the first step that changed a
    /// thing, the other device writes these words into that thing's notes — as iCloud brings it, with its
    /// check-in — so an undo finds a field changed since (the partial undo and its note).
    static func afterStep(_ step: UndoStep, _ model: LibraryModel) {
        let args = ProcessInfo.processInfo.arguments
        guard AMSPackingApp.testing, let n = args.firstIndex(of: "-otherDeviceNoteAfterStep"), n + 1 < args.count,
              !playedAfterStep,
              let thing = step.touched.first(where: { $0.table == .items && step.before[$0] != nil && step.after[$0] != nil })
        else { return }
        playedAfterStep = true
        let words = args[n + 1], id = thing.key
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            model.arriveFromTheOtherDevice { _ = $0.updateThing(id: id) { $0.note = words } }
        }
    }
    private static var playedAfterStep = false
}

#if os(iOS)
/// `-undoHookForTests` (0.105): XCUITest cannot shake the phone, so two small buttons in a window of their
/// own, above everything, do what a shake's Undo and Redo do — ask the WINDOW's undo manager (the one
/// shake asks) to undo or redo. Their value is the name it holds: "Tick Passport".
@MainActor
enum UndoTestHook {
    private static var window: UIWindow?

    static func install() {
        guard AMSPackingApp.testing, ProcessInfo.processInfo.arguments.contains("-undoHookForTests"), window == nil,
              let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return }
        let host = UIHostingController(rootView: UndoTestButtons())
        host.view.backgroundColor = .clear
        host.safeAreaRegions = []               // near the top: no safe area pushing the buttons out of the window
        let w = UIWindow(windowScene: scene)
        w.windowLevel = .alert + 2
        w.backgroundColor = .clear
        w.rootViewController = host
        w.frame = CGRect(x: 8, y: 60, width: 170, height: 48)
        w.isHidden = false                      // shown, never made key
        window = w
    }

    /// The app's window's own undo manager — what shake-to-undo asks. Not "the key window's": a tap on
    /// these buttons can make their own window key.
    static var shaken: UndoManager? {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows).first { $0 !== window && $0.windowLevel == .normal && !$0.isHidden }?.undoManager
    }
}

private struct UndoTestButtons: View {
    @State private var tick = 0
    var body: some View {
        // Read afresh on every tick (the manager is not observed).
        let undoName = tick >= 0 ? (UndoTestHook.shaken?.undoActionName ?? "") : ""
        let redoName = tick >= 0 ? (UndoTestHook.shaken?.redoActionName ?? "") : ""
        HStack(spacing: 6) {
            Button("Undo") { UndoTestHook.shaken?.undo(); tick += 1 }
                .accessibilityIdentifier("test-undo")
                .accessibilityValue(undoName)
            Button("Redo") { UndoTestHook.shaken?.redo(); tick += 1 }
                .accessibilityIdentifier("test-redo")
                .accessibilityValue(redoName)
        }
        .font(.caption)
        .buttonStyle(.bordered)
        .padding(4)
        .background(Color.yellow.opacity(0.6))
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in tick += 1 }
    }
}
#endif
#endif
