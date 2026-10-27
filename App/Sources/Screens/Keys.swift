import SwiftUI
import PackingCore
import PackingLibrary
#if os(macOS)
import AppKit
#endif

// Keyboard shortcuts (0.103) — his asks of 27 Oct 2026: "when I am in a trip and want to press
// Command-S, it does not work", and "I would also like keyboard shortcuts to change tabs. Home,
// Trips, Templates, Care, To do and Settings."
//
// The rule (spec 06 §20a): ⌘S = Save, or Done; Escape = Cancel, or close; ⌘Q quits; ⌘1 … ⌘6 are the
// six tabs, as Apple's own apps number theirs (the Mac's Go menu, ⌘, for Settings).
//
// Why ⌘S did nothing on a trip: a SwiftUI button carries ONE keyboard shortcut, and Done on a page that
// only shows something (a trip, How it works, Search, a list of things …) carries Escape — 0.92 gave ⌘S
// only to the pages that change something. So ⌘S went to the Thing menu's Save, which is switched off
// unless a thing's page is open. `commandS` is the second key of such a Done.

extension View {
    /// ⌘S as this button's second key: it does what the button does. A button carries one shortcut and
    /// Done already carries Escape (`.cancelAction`), so a hidden button behind it holds ⌘S — no size of its
    /// own, out of VoiceOver's way, never in the way of a tap (as How it works' ⌘F, 0.90).
    func commandS(when on: Bool = true, _ action: @escaping () -> Void) -> some View {
        background {
            if on {
                Button("Save") { action() }
                    .keyboardShortcut("s", modifiers: .command)
                    .buttonStyle(.plain)
                    .opacity(0).allowsHitTesting(false).accessibilityHidden(true)
            }
        }
    }

    /// A page with nothing to save (the icon picker, Restore, a choice made by a tap): ⌘S does nothing —
    /// and, on an iPhone with a keyboard, does not reach the page under it either (a presented page's
    /// responder chain continues into the one that presented it, and that one's ⌘S would close it).
    func swallowsCommandS() -> some View { commandS {} }
}

/// Is a page (a sheet) open? The tab keys are off while one is — the Apple modal rule: tabs do not change
/// underneath a page with changes not confirmed yet.
final class PageWatch: ObservableObject {
    static let shared = PageWatch()

    #if os(macOS)
    /// A sheet is on one of the app's windows. Said to the Go menu, which greys its items.
    @Published private(set) var open = false
    private var watching: [Any] = []

    private init() {
        let names: [Notification.Name] = [NSWindow.willBeginSheetNotification, NSWindow.didEndSheetNotification,
                                          NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification,
                                          NSWindow.willCloseNotification]
        for name in names {
            watching.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                // "Will begin": the sheet is attached a moment later (as `QuitGuard.start`); "did end": it is
                // still on its way out, so look again once it has gone.
                DispatchQueue.main.async { self?.refresh() }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self?.refresh() }
            })
        }
        refresh()
    }

    func refresh() {
        let now = NSApplication.shared.windows.contains { $0.sheetParent != nil || $0.attachedSheet != nil }
        if now != open { open = now }
    }

    /// Right now, for a key that asks as it is pressed.
    static var openNow: Bool {
        NSApplication.shared.windows.contains { $0.sheetParent != nil || $0.attachedSheet != nil }
    }
    #else
    private init() {}

    /// Right now: a page is presented over the tabs (or a list of drop-down choices over a page).
    static var openNow: Bool {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .contains { scene in scene.windows.contains { $0.rootViewController?.presentedViewController != nil } }
    }
    #endif
}

/// What the Go menu needs of the window in front: which tab it shows, and how to change it. Given by
/// `RootView` to its scene (`focusedSceneValue`), so the menu acts on the window in front and is off
/// when none of the app's tab windows is.
struct SectionSwitch {
    let current: AppSection
    let go: (AppSection) -> Void
}

private struct SectionSwitchKey: FocusedValueKey {
    typealias Value = SectionSwitch
}

extension FocusedValues {
    var sectionSwitch: SectionSwitch? {
        get { self[SectionSwitchKey.self] }
        set { self[SectionSwitchKey.self] = newValue }
    }
}

#if os(macOS)
/// The Go menu: the six tabs, ⌘1 to ⌘6 in the tab bar's order, the tab showing ticked. Off while a page is open.
struct GoCommands: Commands {
    @FocusedValue(\.sectionSwitch) private var window
    @ObservedObject private var pages = PageWatch.shared

    var body: some Commands {
        CommandMenu("Go") {
            ForEach(Array(AppSection.allCases.enumerated()), id: \.element) { n, section in
                Toggle(section.label, isOn: Binding(get: { window?.current == section }, set: { _ in window?.go(section) }))
                    .keyboardShortcut(KeyEquivalent(Character(String(n + 1))), modifiers: .command)
                    .disabled(window == nil || pages.open)
            }
        }
    }
}

/// ⌘, opens the Settings tab (the Mac's convention, in the app menu), and Help ▸ Keyboard Shortcuts opens
/// How it works at its Keyboard shortcuts topic. Both off while a page is open.
struct SettingsAndHelpCommands: Commands {
    @FocusedValue(\.sectionSwitch) private var window
    @ObservedObject private var pages = PageWatch.shared

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("Settings\u{2026}") { window?.go(.settings) }
                .keyboardShortcut(",", modifiers: .command)
                .disabled(window == nil || pages.open)
        }
        CommandGroup(replacing: .help) {
            Button("Keyboard Shortcuts") {
                LibraryModel.shared.keysToOpen = true
                window?.go(.settings)
            }
            .disabled(window == nil || pages.open)
        }
    }
}

extension ThingKeys {
    /// The Go menu's items, ⌘, and Help's Keyboard Shortcuts, named for the tests (SwiftUI hands a menu item
    /// no identifier; `nameMenuItems` calls this): `go-home`, `go-events`, `go-templates`, `go-care`,
    /// `go-actions`, `go-settings`, `go-settings-comma`, `help-keys`.
    static func nameGoMenuItems(_ bar: NSMenu) {
        let tabs = Dictionary(uniqueKeysWithValues: AppSection.allCases.map { ($0.label, "go-\($0.rawValue)") })
        func name(_ item: NSMenuItem, _ id: String) {
            guard item.identifier?.rawValue != id else { return }
            item.identifier = NSUserInterfaceItemIdentifier(id)
        }
        for top in bar.items {
            switch top.title {
            case "Go":
                for item in top.submenu?.items ?? [] { if let id = tabs[item.title] { name(item, id) } }
            case "Help":
                for item in top.submenu?.items ?? [] where item.title == "Keyboard Shortcuts" { name(item, "help-keys") }
            default:
                for item in top.submenu?.items ?? [] where item.keyEquivalent == "," { name(item, "go-settings-comma") }
            }
        }
    }
}
#else
/// ⌘1 … ⌘6 and ⌘, on a keyboard attached to an iPhone or iPad (the Mac has the Go menu). Hidden buttons
/// behind the frame, as How it works' ⌘F; they do nothing while a page is open.
struct TabKeys: View {
    @Binding var section: AppSection

    var body: some View {
        ZStack {
            ForEach(Array(AppSection.allCases.enumerated()), id: \.element) { n, s in
                Button(s.label) { go(s) }
                    .keyboardShortcut(KeyEquivalent(Character(String(n + 1))), modifiers: .command)
            }
            Button("Settings") { go(.settings) }
                .keyboardShortcut(",", modifiers: .command)
        }
        .buttonStyle(.plain)
        .opacity(0).allowsHitTesting(false).accessibilityHidden(true)
    }

    private func go(_ s: AppSection) {
        guard !PageWatch.openNow else { return }
        section = s
    }
}
#endif
