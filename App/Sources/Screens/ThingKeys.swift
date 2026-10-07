import SwiftUI
#if os(macOS)
import AppKit
#endif

// A thing's page from the keyboard alone, on the Mac (0.68). His priority, decided 7 Oct
// 2026 on the concept page "Fill in a thing without touching the mouse": Tab walks every
// field top to bottom; each kind of field answers the same few keys (type to pick, Space
// to open or switch, Return to save); ⌘N saves and starts the next thing with this one's
// choices, ⌘↓ ⌘↑ go through the list the page came from, ⌘J jumps to a field by name, and
// a Thing menu lists it all. His three answers: Return saves from any field but Notes and
// an open list; ⌘N carries Kind of thing, Whose it is, Kept at home, Usually packed in,
// When and the templates; Mac only — the iPhone stays as it is. Every key works on a
// Swedish keyboard: none needs ⌥, [ or ].
//
// How: the page keeps its OWN idea of the field in focus (`ThingField`) and reads the
// keys itself, before the window does (`KeyMonitor`), so the order and the keys are the
// same whatever the Mac's "Keyboard navigation" setting says — with it off, the Mac's own
// Tab skips every drop-down, pill and switch. A text field in focus is ALSO the window's
// first responder, so typing in it is the Mac's own; a drop-down, the templates and a
// switch are reached by the page alone and drawn with its ring.

/// A field of a thing's page, in his reading order.
enum ThingField: Hashable {
    case name, notes, category, owner, templates, section(String), storage, bag, when
    case weight, brand, colour, condition, care, careNotes, liquid, restricted, expiry
    /// The ⌘J box's own field — never in the Tab order.
    case jump

    /// Typed into: the window's own text field has the keys.
    var isText: Bool {
        switch self {
        case .name, .notes, .weight, .brand, .colour, .careNotes, .expiry, .jump: return true
        default: return false
        }
    }

    /// A drop-down.
    var isList: Bool {
        switch self {
        case .category, .owner, .section, .storage, .bag, .when, .condition, .care: return true
        default: return false
        }
    }
}

#if os(macOS)
/// What the page's keys ask of one of its drop-downs.
enum DropDownKey: Equatable {
    case letters(String), open, up, down, choose, close, back, space
    /// Tab (1) or Shift-Tab (−1) in the open list: on to the lit row's tools (a Section's
    /// pen, arrows, Remove); answered false when there is no tool left — the page goes on.
    case tab(Int)
}

/// The page's line to its drop-downs (`DropDown`, Mac): each one, while it is on screen,
/// hands in how it answers a key, under its field's id; the page asks the one in focus.
/// Given to the drop-downs in the environment (`dropDownKeys`); a drop-down without it —
/// on every other screen — has no keys of its own, as before.
final class DropDownKeys {
    var answer: [String: (DropDownKey) -> Bool] = [:]
    /// The drop-down whose list is open (its field's id), and whether the keys opened it.
    private(set) var open: String?
    private(set) var openedByKeys = false
    /// A Section's new name clicked into: every key is that field's but Esc. Said by the
    /// drop-down itself — the window a key arrives in does not tell (GitHub's Mac, 7 Oct
    /// 2026: the letters for a popover's field were taken for the list while ⌘A reached it).
    var typingInList = false
    /// A list opened or closed — for the line at the page's foot.
    var changed: ((String?) -> Void)?
    /// A drop-down's field clicked: the page's focus goes there.
    var clicked: ((String) -> Void)?

    func opened(_ id: String?, byKeys: Bool) {
        if id == nil { typingInList = false }
        guard open != id || openedByKeys != byKeys else { return }
        open = id
        openedByKeys = id != nil && byKeys
        changed?(id)
    }
}

private struct DropDownKeysKey: EnvironmentKey {
    static let defaultValue: DropDownKeys? = nil
}

extension EnvironmentValues {
    var dropDownKeys: DropDownKeys? {
        get { self[DropDownKeysKey.self] }
        set { self[DropDownKeysKey.self] = newValue }
    }
}

/// Hands a drop-down's answer to the page each time the drop-down is drawn — so the
/// answer always knows the choices and the choice of the moment — and takes it back
/// when the drop-down goes (a Section whose template was unticked).
struct DropDownKeyAnswer: NSViewRepresentable {
    let keys: DropDownKeys
    let id: String
    let answer: (DropDownKey) -> Bool

    final class Coordinator { var keys: DropDownKeys?; var id = "" }
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        update(context.coordinator)
        return NSView()
    }
    func updateNSView(_ nsView: NSView, context: Context) { update(context.coordinator) }

    private func update(_ c: Coordinator) {
        if let old = c.keys, c.id != id { old.answer[c.id] = nil }
        c.keys = keys; c.id = id
        keys.answer[id] = answer
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.keys?.answer[coordinator.id] = nil
    }
}

/// The window a view is in — the page's keys are read only when they are meant for it.
struct WindowReader: NSViewRepresentable {
    let found: (NSWindow?) -> Void
    final class Probe: NSView {
        var found: ((NSWindow?) -> Void)?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            found?(window)
        }
    }
    func makeNSView(context: Context) -> Probe {
        let p = Probe()
        p.found = found
        return p
    }
    func updateNSView(_ nsView: Probe, context: Context) { nsView.found = found }
}

/// Reads the keys before the window does, while a thing's page is open.
final class KeyMonitor {
    private var token: Any?
    func start(_ handle: @escaping (NSEvent) -> NSEvent?) {
        stop()
        token = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: handle)
    }
    func stop() {
        if let token { NSEvent.removeMonitor(token) }
        token = nil
    }
    deinit { stop() }
}

/// The thing pages open now, for the Thing menu: it acts on the page in the window in
/// front, and is switched off while no page is open.
final class ThingKeys: ObservableObject {
    static let shared = ThingKeys()

    final class Page {
        weak var window: NSWindow?
        var save: () -> Void = {}
        var saveAndNew: () -> Void = {}
        var step: (Int) -> Void = { _ in }
        var canStep = false
        var jump: () -> Void = {}
    }

    @Published private(set) var pages: [Page] = []
    private var watching: [Any] = []

    private init() {
        // The page in front changes with the window in front.
        for name in [NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification] {
            watching.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                guard let self, !self.pages.isEmpty else { return }
                self.objectWillChange.send()
            })
        }
        // The Thing menu's items named for the tests, whenever the menu is (re)built.
        for name in [NSMenu.didAddItemNotification, NSApplication.didFinishLaunchingNotification,
                     NSApplication.didBecomeActiveNotification, NSWindow.didBecomeKeyNotification] {
            watching.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
                ThingKeys.nameMenuItems()
            })
        }
    }

    /// SwiftUI does not hand a menu item's `accessibilityIdentifier` to the menu (GitHub's
    /// Mac, 7 Oct 2026: the Thing menu's items had titles and no ids), so the app names its
    /// own items by their keys — `thing-menu-save`, `-new`, `-next`, `-previous`, `-jump` —
    /// for the tests, which find controls by id, never by words.
    static func nameMenuItems() {
        guard let bar = NSApp?.mainMenu else { return }
        let names: [String: String] = [
            "s": "thing-menu-save", "n": "thing-menu-new", "j": "thing-menu-jump",
            String(UnicodeScalar(UInt16(NSDownArrowFunctionKey))!): "thing-menu-next",
            String(UnicodeScalar(UInt16(NSUpArrowFunctionKey))!): "thing-menu-previous",
        ]
        for top in bar.items where top.title == "Thing" {
            for (n, item) in (top.submenu?.items ?? []).enumerated() {
                // Save and New has no key while no page is open: it is the second item.
                let id = names[item.keyEquivalent] ?? (n == 1 ? "thing-menu-new" : nil)
                guard let id, item.identifier?.rawValue != id else { continue }
                item.identifier = NSUserInterfaceItemIdentifier(id)
            }
        }
    }

    /// The page the menu acts on: the one in the window in front, else the last opened.
    var active: Page? {
        pages.last { $0.window?.isKeyWindow == true } ?? pages.last
    }

    func add(_ page: Page) {
        guard !pages.contains(where: { $0 === page }) else { return }
        pages.append(page)
        DispatchQueue.main.async { ThingKeys.nameMenuItems() }
    }
    func remove(_ page: Page) {
        pages.removeAll { $0 === page }
        DispatchQueue.main.async { ThingKeys.nameMenuItems() }
    }
    /// What the page can do changed (a list to go through, or none).
    func refresh() { objectWillChange.send() }
}

/// The Thing menu in the Mac's menu bar — every key of a thing's page, the Apple way:
/// nothing hidden, nothing to remember. Switched off while no thing's page is open, so
/// ⌘N is File ▸ New Window everywhere else (the page reads its keys before the menu
/// does, so its ⌘N wins only while it is open — and the UI tests' launch keeps opening
/// a window with ⌘N).
struct ThingCommands: Commands {
    @ObservedObject var keys = ThingKeys.shared
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        // ⌘N belongs to ONE item at a time — two items with the same key and the Mac shows
        // it on neither (GitHub's Mac, 7 Oct 2026: Save and New came without its ⌘N). So
        // File ▸ New Window has it while no thing's page is open, Save and New while one is.
        CommandGroup(replacing: .newItem) {
            if keys.pages.isEmpty {
                Button("New Window") { openWindow(id: AMSPackingApp.mainWindowId) }
                    .keyboardShortcut("n")
            } else {
                Button("New Window") { openWindow(id: AMSPackingApp.mainWindowId) }
            }
        }
        CommandMenu("Thing") {
            let page = keys.active
            Button("Save") { page?.save() }
                .keyboardShortcut("s")
                .disabled(page == nil)
            if page != nil {
                Button("Save and New") { page?.saveAndNew() }
                    .keyboardShortcut("n")
            } else {
                Button("Save and New") {}
                    .disabled(true)
            }
            Divider()
            Button("Next Thing") { page?.step(1) }
                .keyboardShortcut(.downArrow)
                .disabled(!(page?.canStep ?? false))
            Button("Previous Thing") { page?.step(-1) }
                .keyboardShortcut(.upArrow)
                .disabled(!(page?.canStep ?? false))
            Divider()
            Button("Jump to Field…") { page?.jump() }
                .keyboardShortcut("j")
                .disabled(page == nil)
        }
    }
}

extension NSEvent {
    /// ⌘, ⌥, ⌃ and ⇧ only — the arrows also carry "function" and "number pad".
    var keyModifiers: NSEvent.ModifierFlags {
        modifierFlags.intersection([.command, .option, .control, .shift])
    }

    /// Words typed (a letter, a digit, a sign) rather than a key that moves or edits.
    var typedWords: String? {
        guard let s = characters, !s.isEmpty else { return nil }
        let ok = s.unicodeScalars.allSatisfy { u in
            !CharacterSet.controlCharacters.contains(u) && !(0xF700...0xF8FF).contains(u.value) && u.value != 0x7F
        }
        return ok ? s : nil
    }
}

/// Mac key codes the page answers (the same on a Swedish keyboard: they are places, not
/// letters).
enum KeyCode {
    static let tab: UInt16 = 48, space: UInt16 = 49, delete: UInt16 = 51, escape: UInt16 = 53
    static let returnKey: UInt16 = 36, enter: UInt16 = 76
    static let left: UInt16 = 123, right: UInt16 = 124, down: UInt16 = 125, up: UInt16 = 126
}
#endif

extension View {
    /// The 2-point ring round the field in focus (Mac): drawn just outside the control,
    /// so nothing moves. Nothing on the iPhone.
    @ViewBuilder func focusRing(_ on: Bool, tint: Color = AppSection.care.color, radius: CGFloat = 8, gap: CGFloat = 3) -> some View {
        #if os(macOS)
        overlay(RoundedRectangle(cornerRadius: radius + gap).stroke(tint, lineWidth: 2).padding(-gap).opacity(on ? 1 : 0))
        #else
        self
        #endif
    }
}
