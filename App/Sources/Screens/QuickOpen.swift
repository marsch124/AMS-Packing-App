import SwiftUI
import PackingCore
import PackingLibrary
#if os(macOS)
import AppKit
#endif

// New Thing and Quick open (0.105) — his words of 28 Oct 2026: "⌘N opens a new, empty thing's page from anywhere in
// the app. That's what ⌘N means in Apple's own apps, like a new note in Notes or a new reminder in Reminders. ⌘N
// currently opens a new window. That would move to ⌥⌘N, Apple's usual alternative. On the iPhone: "New thing" also goes
// into the menu when you hold the app icon." — and "1. ⌘K - yes please", to "⌘K quick open (Mac): type a few letters to
// jump to any thing, trip or template, or run a command like 'Group by Whose'".
//
// ⌘N — File ▸ New Thing (`ThingCommands`): the window's own page over the tab it shows (`RootPage.newThing`, presented by
// `RootView`), so the tab stays as it was. Off while a page is open (`PageWatch`, 0.103), except two pages that answer ⌘N
// themselves, before the menu: Your things (`commandN`, its own new thing's page, which then stands under Just added) and
// a thing's page (Save and New, `ThingEditor.key` — the page reads its keys before the menu bar does). The iPhone has it
// under the app icon, the Mac's Dock menu too (`GrabQuickActions`): both through `LibraryModel.newThingToOpen`, on Home.
//
// ⌘K — Go ▸ Quick Open (`GoCommands`, Mac): a panel of its own centred over the window in front, as Spotlight is
// (`QuickOpenPanel`): a search field, and what it finds grouped Things · Trips · Templates · Commands (`QuickOpen` in the
// library decides what is found and in what order). ↑ ↓ light a row, Return opens or runs it, Esc — or a click
// elsewhere — closes it. A thing, a trip or a template opens as the window's own page (`RootPage`); a command does what
// its menu item does. With no page open: the six tabs, New thing, Keyboard shortcuts, Sync details. With a trip's page
// in front (`PageWatch.tripInFront`): that trip's commands only — Group by (each choice) and Fold all / Unfold all —
// the Apple modal rule: nothing changes underneath a page.

/// A page opened over the tabs by ⌘N or Quick open (0.105), by the window's `RootView` — the tab under it stays.
enum RootPage: Identifiable, Equatable {
    case newThing, thing(String), trip(String), template(String), syncDetails

    var id: String {
        switch self {
        case .newThing: return "new-thing"
        case .thing(let id): return "thing:" + id
        case .trip(let id): return "trip:" + id
        case .template(let id): return "template:" + id
        case .syncDetails: return "sync-details"
        }
    }
}

/// The page itself.
struct RootPageView: View {
    let page: RootPage
    @EnvironmentObject var model: LibraryModel

    var body: some View {
        switch page {
        case .newThing: ThingEditor(itemId: ThingEditor.newThing).environmentObject(model)
        case .thing(let id): ThingEditor(itemId: id).environmentObject(model)
        case .trip(let id): TripScreen(tripId: id).environmentObject(model)
        case .template(let id): TemplateDetail(listId: id).environmentObject(model)
        case .syncDetails: SyncDetailsSheet().environmentObject(model)
        }
    }
}

/// What File ▸ New Thing and Go ▸ Quick Open need of the window in front (`focusedSceneValue`): how to open a page over
/// it, and — the app's main windows only — Quick open over it.
struct PageOpener {
    let open: (RootPage) -> Void
    var quickOpen: (() -> Void)? = nil
}

private struct PageOpenerKey: FocusedValueKey {
    typealias Value = PageOpener
}

extension FocusedValues {
    var pageOpener: PageOpener? {
        get { self[PageOpenerKey.self] }
        set { self[PageOpenerKey.self] = newValue }
    }
}

/// The pages the windows' `RootView`s have open, for a request from outside (a Spotlight result, the Dock menu, a tapped
/// reminder): Home makes way for it as for its own pages — they close first, and the asked-for page opens once they
/// have gone (`HomeScreen.whenFree`).
@MainActor
enum RootPages {
    private static var closers: [UUID: () -> Void] = [:]
    static var anyOpen: Bool { !closers.isEmpty }
    static func opened(_ window: UUID, close: @escaping () -> Void) { closers[window] = close }
    static func closed(_ window: UUID) { closers[window] = nil }
    static func closeAll() { for close in Array(closers.values) { close() } }
}

extension View {
    /// ⌘N on a page that makes things (0.105, Your things): its own new thing's page. A hidden button, as `commandS`;
    /// the menu's New Thing is off while a page is open, and the page's window has its keys first. Mac only.
    @ViewBuilder
    func commandN(_ action: @escaping () -> Void) -> some View {
        #if os(macOS)
        background {
            Button("New Thing") { action() }
                .keyboardShortcut("n", modifiers: .command)
                .buttonStyle(.plain)
                .opacity(0).allowsHitTesting(false).accessibilityHidden(true)
        }
        #else
        self
        #endif
    }
}

#if os(macOS)
// MARK: - Quick open (Mac)

/// A trip's page, marked with its window (0.105): while it is in front with nothing over it, Quick open offers its
/// commands (`PageWatch.tripInFront`). `TripScreen` wears it (Mac).
struct TripPageMark: NSViewRepresentable {
    let tripId: String

    final class Probe: NSView {
        var tripId = ""
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            DispatchQueue.main.async { PageWatch.shared.refresh() }
        }
    }

    func makeNSView(context: Context) -> Probe {
        let p = Probe()
        p.tripId = tripId
        TripPages.probes.add(p)
        return p
    }

    func updateNSView(_ p: Probe, context: Context) {
        guard p.tripId != tripId else { return }
        p.tripId = tripId                                   // Start a new trip from this one: the page shows that one
        DispatchQueue.main.async { PageWatch.shared.refresh() }
    }

    static func dismantleNSView(_ p: Probe, coordinator: ()) {
        TripPages.probes.remove(p)
        DispatchQueue.main.async { PageWatch.shared.refresh() }
    }
}

/// The trip pages open now.
@MainActor
enum TripPages {
    static let probes = NSHashTable<TripPageMark.Probe>.weakObjects()

    /// The trip whose page is the window with the keys, nothing over it; nil = none.
    static func inFront() -> String? {
        probes.allObjects.first { $0.window?.isKeyWindow == true && $0.window?.attachedSheet == nil }?.tripId
    }
}

/// What the panel acts on: the window it was opened over.
struct QuickOpenTarget {
    let opener: PageOpener
    let sections: SectionSwitch?
    /// The trip whose page was in front, nil = no page open.
    let trip: String?
}

/// The panel's state: what is typed, what it finds, the row lit.
@MainActor
final class QuickOpenState: ObservableObject {
    @Published var query = ""
    @Published private(set) var groups: [QuickOpen.Group] = []
    /// The lit row, counted through every group top to bottom.
    @Published var lit = 0
    private(set) var trip: String?
    private var entries: [QuickOpen.Entry] = []

    var hits: [QuickOpen.Hit] { groups.flatMap(\.hits) }

    func start(_ entries: [QuickOpen.Entry], trip: String?) {
        self.entries = entries
        self.trip = trip
        query = ""
        groups = []
        lit = 0
    }

    func find() {
        groups = QuickOpen.find(query, in: entries)
        lit = 0
    }

    func move(_ by: Int) {
        guard !hits.isEmpty else { return }
        lit = min(max(lit + by, 0), hits.count - 1)
    }
}

/// The commands Quick open offers (`QuickOpen.Entry`, kind command): with no page open, the Go menu's six tabs, New
/// thing, Keyboard shortcuts and Sync details; on a trip's page, its Group by choices and Fold all (Unfold all once all
/// are folded) — what the trip's own drop-down and button do. Their ids: `go:<tab>`, `new-thing`, `keys`, `sync`,
/// `group:<choice>`, `fold`.
@MainActor
enum QuickCommands {
    static func entries(trip: String?, tab: AppSection?, library: Library) -> [QuickOpen.Entry] {
        guard let trip else {
            var out = AppSection.allCases.enumerated().map { n, s in
                QuickOpen.Entry(id: "go:\(s.rawValue)", kind: .command, title: "Go to \(s.label)", also: otherWords(s),
                                keys: "\u{2318}\(n + 1)", current: s == tab)
            }
            out.append(QuickOpen.Entry(id: "new-thing", kind: .command, title: "New thing", also: ["Add a thing", "Make a thing"],
                                       keys: "\u{2318}N"))
            out.append(QuickOpen.Entry(id: "keys", kind: .command, title: "Keyboard shortcuts", also: ["Keys", "Help"]))
            out.append(QuickOpen.Entry(id: "sync", kind: .command, title: "Sync details", also: ["iCloud", "Sync now"]))
            return out
        }
        let view = UserDefaults.standard.string(forKey: viewKey) ?? "when"
        var out = TripScreen.views.map { v in
            QuickOpen.Entry(id: "group:\(v.id)", kind: .command, title: "Group by \(v.label)", also: ["Sort by \(v.label)"],
                            current: v.id == view)
        }
        let all = allFolded(trip: trip, library: library)
        out.append(QuickOpen.Entry(id: "fold", kind: .command, title: all ? "Unfold all" : "Fold all",
                                   also: all ? ["Open all", "Expand all"] : ["Collapse all", "Close all"]))
        return out
    }

    /// A tab's other words: To do is also "to-dos" and "buy"; Care is where the things and bags are.
    private static func otherWords(_ s: AppSection) -> [String] {
        switch s {
        case .events: return ["Events"]
        case .care: return ["Things", "Bags"]
        case .actions: return ["To-dos", "Buy list", "Actions"]
        case .settings: return ["Preferences", "How it works"]
        default: return []
        }
    }

    /// The trip page's own settings, remembered on this device (`TripScreen`'s `@AppStorage`).
    static let viewKey = "ams.view", foldedKey = "ams.trip.folded"

    /// The trip's headings under its Group by of the moment — every line, as the page shows them unfiltered.
    private static func headings(trip: String, view: String, library: Library) -> [String] {
        guard let t = library.trips.first(where: { $0.id == trip }) else { return [] }
        return library.linesGrouped(tripId: trip, sorting: view, lines: t.entries).filter { !$0.entries.isEmpty }.map(\.label)
    }

    private static func allFolded(trip: String, library: Library) -> Bool {
        let d = UserDefaults.standard
        let view = d.string(forKey: viewKey) ?? "when"
        return TripFolds.allFolded(d.string(forKey: foldedKey) ?? "", trip: trip, view: view,
                                   headings: headings(trip: trip, view: view, library: library))
    }

    /// Runs a command on the window Quick open was opened over.
    static func run(_ id: String, on target: QuickOpenTarget, model: LibraryModel) {
        let d = UserDefaults.standard
        if id.hasPrefix("go:"), let s = AppSection(rawValue: String(id.dropFirst(3))) { target.sections?.go(s); return }
        if id.hasPrefix("group:") { d.set(String(id.dropFirst(6)), forKey: viewKey); return }
        switch id {
        case "new-thing": target.opener.open(.newThing)
        case "keys":
            model.keysToOpen = true
            target.sections?.go(.settings)
        case "sync": target.opener.open(.syncDetails)
        case "fold":
            guard let trip = target.trip else { return }
            let view = d.string(forKey: viewKey) ?? "when"
            let heads = headings(trip: trip, view: view, library: model.library)
            let raw = d.string(forKey: foldedKey) ?? ""
            let all = TripFolds.allFolded(raw, trip: trip, view: view, headings: heads)
            d.set(TripFolds.settingAll(raw, trip: trip, view: view, headings: heads, folded: !all,
                                       trips: Set(model.library.trips.map(\.id))), forKey: foldedKey)
        default: break
        }
    }
}

/// The panel, as Spotlight's: a window of its own with no title bar, centred over the window in front a fifth of the way
/// down, a child of it (it moves with it). It is the key window while it is up, so the window under it keeps its keys
/// for later; its own keys are read before the field gets them (`KeyMonitor`, as a thing's page does): ↑ ↓ Return Esc,
/// and ⌘K again closes it. Losing the keys — a click anywhere else — closes it too.
@MainActor
final class QuickOpenPanel: NSObject, NSWindowDelegate {
    static let shared = QuickOpenPanel()

    /// A window with no title bar can only take the keys when it says it can.
    final class Panel: NSPanel {
        override var canBecomeKey: Bool { true }
        override var canBecomeMain: Bool { false }
    }

    static let width: CGFloat = 560
    private var panel: Panel?
    private var target: QuickOpenTarget?
    private let monitor = KeyMonitor()
    let state = QuickOpenState()

    var isOpen: Bool { panel != nil }

    /// ⌘K: opens the panel over `window` — or closes it when it is up.
    func toggle(over window: NSWindow?, target: QuickOpenTarget, tab: AppSection?) {
        if isOpen { close(); return }
        guard let parent = window else { return }
        let model = LibraryModel.shared
        let things = target.trip == nil ? model.library.quickOpenEntries(today: Today.local) : []
        state.start(things + QuickCommands.entries(trip: target.trip, tab: tab, library: model.library), trip: target.trip)
        self.target = target

        let width = min(QuickOpenPanel.width, max(320, parent.frame.width - 40))
        let p = Panel(contentRect: NSRect(x: 0, y: 0, width: width, height: 60), styleMask: [.borderless], backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.isReleasedWhenClosed = false
        p.isRestorable = false                            // never brought back at the next launch
        p.isMovable = false
        p.hidesOnDeactivate = true
        p.delegate = self
        p.setAccessibilityIdentifier("quick-open-panel")
        let host = NSHostingView(rootView: QuickOpenView(state: state, width: width,
                                                         choose: { [weak self] in self?.choose($0) },
                                                         fit: { [weak self] in self?.fit($0) })
            .environmentObject(model))
        host.sizingOptions = []
        p.contentView = host
        let f = parent.frame
        let top = f.maxY - max(60, f.height * 0.18)
        p.setFrame(NSRect(x: f.midX - width / 2, y: top - 60, width: width, height: 60), display: false)
        parent.addChildWindow(p, ordered: .above)
        p.makeKeyAndOrderFront(nil)
        panel = p
        monitor.start { [weak self] e in self?.key(e) ?? e }
    }

    func close() {
        guard let p = panel else { return }
        panel = nil
        monitor.stop()
        p.delegate = nil
        p.parent?.removeChildWindow(p)
        p.orderOut(nil)
        target = nil
    }

    /// A click elsewhere: the panel goes, as Spotlight does.
    func windowDidResignKey(_ notification: Notification) { close() }

    /// The panel as tall as what it shows, its top where it is — after the layout that measured it.
    private func fit(_ height: CGFloat) {
        DispatchQueue.main.async { [weak self] in
            guard let p = self?.panel, height > 0, abs(p.frame.height - height) > 0.5 else { return }
            let f = p.frame
            p.setFrame(NSRect(x: f.minX, y: f.maxY - height, width: f.width, height: height), display: true)
            p.invalidateShadow()
        }
    }

    private func key(_ e: NSEvent) -> NSEvent? {
        guard let p = panel, e.window === p else { return e }
        switch e.keyCode {
        case KeyCode.escape: close()
        case KeyCode.returnKey, KeyCode.enter:
            let hits = state.hits
            if hits.indices.contains(state.lit) { choose(hits[state.lit]) }
        case KeyCode.down: state.move(1)
        case KeyCode.up: state.move(-1)
        default:
            if e.keyModifiers == .command, e.charactersIgnoringModifiers?.lowercased() == "k" { close(); return nil }
            return e
        }
        return nil
    }

    /// A row chosen: the panel goes, then the window under it opens the page or runs the command — once it has its
    /// keys back, so a page opens on it.
    private func choose(_ hit: QuickOpen.Hit) {
        guard let target else { return }
        close()
        let model = LibraryModel.shared
        DispatchQueue.main.async {
            switch hit.entry.kind {
            case .thing: target.opener.open(.thing(hit.entry.id))
            case .trip: target.opener.open(.trip(hit.entry.id))
            case .template: target.opener.open(.template(hit.entry.id))
            case .command: QuickCommands.run(hit.entry.id, on: target, model: model)
            }
        }
    }
}

/// What the panel shows: the field, then the groups — or a line saying what it finds, or that nothing is called that.
/// Ids: `quick-open` (the panel), `quick-open-field`, `quick-open-<kind>` (a group's heading: thing, trip, template,
/// command), `quick-open-<kind>-<n>` (its rows, n from 0; the lit one selected), `quick-open-hint`, `quick-open-none`.
struct QuickOpenView: View {
    @ObservedObject var state: QuickOpenState
    let width: CGFloat
    let choose: (QuickOpen.Hit) -> Void
    let fit: (CGFloat) -> Void
    @FocusState private var typing: Bool
    @State private var listHeight: CGFloat = 0
    /// The list scrolls past this.
    static let mostList: CGFloat = 380

    var body: some View {
        let hits = state.hits
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(.title3, weight: .medium)).foregroundStyle(Theme.muted)
                    .accessibilityHidden(true)
                TextField(state.trip == nil ? "Things, trips, templates, commands" : "Commands for this trip", text: $state.query)
                    .textFieldStyle(.plain)
                    .font(.system(.title3)).foregroundStyle(Theme.ink)
                    .focused($typing)
                    .onChange(of: state.query) { _, _ in state.find() }
                    .accessibilityIdentifier("quick-open-field")
            }
            .padding(.horizontal, 16)
            .frame(height: 50)
            Theme.line.frame(height: 1)
            if hits.isEmpty {
                Text(state.query.trimmingCharacters(in: .whitespaces).isEmpty ? hint : "Nothing is called that.")
                    .font(.system(.footnote)).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .accessibilityIdentifier(state.query.trimmingCharacters(in: .whitespaces).isEmpty ? "quick-open-hint" : "quick-open-none")
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        list
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { listHeight = $0 }
                    }
                    .frame(height: min(max(listHeight, 1), QuickOpenView.mostList))
                    .onChange(of: state.lit) { _, n in proxy.scrollTo(n) }
                }
            }
        }
        .frame(width: width)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { fit($0) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("quick-open")
        .onAppear { DispatchQueue.main.async { typing = true } }
    }

    private var hint: String {
        state.trip == nil
            ? "Type a few letters of a thing, a trip or a template \u{2014} a Swedish name too \u{2014} or of a command: Go to Care, New thing, Sync details \u{2026}"
            : "Type a few letters of a command for this trip: Group by Whose it is, Fold all \u{2026}"
    }

    private var list: some View {
        let groups = state.groups
        // Where each group's rows start in the count through every group.
        let starts = groups.indices.map { g in groups[..<g].reduce(0) { $0 + $1.hits.count } }
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(groups.enumerated()), id: \.element.kind) { g, group in
                Text(group.kind.title)
                    .font(.system(.caption, weight: .semibold)).foregroundStyle(Theme.muted)
                    .padding(.horizontal, 10).padding(.top, g == 0 ? 2 : 8).padding(.bottom, 2)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("quick-open-\(group.kind.rawValue)")
                ForEach(Array(group.hits.enumerated()), id: \.offset) { m, hit in
                    row(hit, id: "quick-open-\(group.kind.rawValue)-\(m)", lit: starts[g] + m == state.lit)
                        .id(starts[g] + m)
                }
            }
        }
        .padding(8)
    }

    private func row(_ hit: QuickOpen.Hit, id: String, lit: Bool) -> some View {
        let tint = QuickOpenView.tint(hit.entry)
        return Button { choose(hit) } label: {
            HStack(spacing: 10) {
                QuickOpenView.mark(hit.entry)
                    .foregroundStyle(tint)
                    .frame(width: 22, height: 22)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(hit.entry.title).font(.system(.body)).foregroundStyle(Theme.ink).lineLimit(1)
                    if !hit.under.isEmpty {
                        Text(hit.under).font(.system(.footnote)).foregroundStyle(Theme.muted).lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                if hit.entry.current {
                    Image(systemName: "checkmark").font(.system(.footnote, weight: .semibold)).foregroundStyle(tint)
                        .accessibilityLabel("now")
                }
                if !hit.entry.keys.isEmpty {
                    Text(hit.entry.keys).font(.system(.callout)).foregroundStyle(Theme.muted)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(lit ? tint.opacity(0.18) : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier(id)
        .accessibilityAddTraits(lit ? .isSelected : [])
    }

    /// A row's colour: a thing Care's, a trip Trips', a template Templates', a tab's command its tab's, another
    /// command Settings' slate.
    static func tint(_ e: QuickOpen.Entry) -> Color {
        switch e.kind {
        case .thing: return AppSection.care.color
        case .trip: return AppSection.events.color
        case .template: return AppSection.templates.color
        case .command:
            if e.id.hasPrefix("go:"), let s = AppSection(rawValue: String(e.id.dropFirst(3))) { return s.color }
            if e.id.hasPrefix("group:") || e.id == "fold" { return AppSection.events.color }
            return AppSection.settings.color
        }
    }

    /// A row's mark: the tab's own drawing for a thing (Care), a trip, a template and a tab; a symbol for the rest.
    @ViewBuilder static func mark(_ e: QuickOpen.Entry) -> some View {
        switch e.kind {
        case .thing: SectionMark(section: .care, size: 18)
        case .trip: SectionMark(section: .events, size: 18)
        case .template: SectionMark(section: .templates, size: 18)
        case .command:
            if e.id.hasPrefix("go:"), let s = AppSection(rawValue: String(e.id.dropFirst(3))) {
                SectionMark(section: s, size: 18)
            } else {
                Image(systemName: symbol(e.id)).font(.system(.body, weight: .medium))
            }
        }
    }

    private static func symbol(_ id: String) -> String {
        switch id {
        case "new-thing": return "plus"
        case "keys": return "command"
        case "sync": return "icloud"
        case "fold": return "chevron.up.chevron.down"
        default: return "list.bullet.indent"
        }
    }
}
#endif
