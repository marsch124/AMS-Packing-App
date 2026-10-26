import SwiftUI
import Combine
import CoreSpotlight
import PackingCore
import PackingLibrary

/// The frame of the app: one screen at a time, and the tab bar under it.
struct RootView: View {
    @State private var section: AppSection = .home
    @EnvironmentObject var model: LibraryModel
    @Environment(\.scenePhase) private var scenePhase
    #if os(macOS)
    /// For a Dock menu choice made while no window is open (0.86, `GrabQuickActions`).
    @Environment(\.openWindow) private var openWindow
    #endif
    /// The app went to the background since it was last in front (the UI tests play
    /// "something happened while he was away" on its return).
    @State private var wasAway = false

    var body: some View {
        #if os(macOS)
        // The window has no title bar (0.67): its strip holds each tab's header. How tall
        // it is — the window's top safe area — and how far a header steps in to clear the
        // window buttons, from the column's left edge (the column is centred).
        GeometryReader { geo in
            let column = min(geo.size.width, RootView.column)
            page.environment(\.titleBarStrip, TitleBarStrip(
                height: geo.safeAreaInsets.top,
                lead: max(0, Metrics.windowButtons - (geo.size.width - column) / 2 - 16)))
        }
        #else
        page
        #endif
    }

    /// The web app's column, on the Mac.
    static let column: CGFloat = 720

    private var page: some View {
        VStack(spacing: 0) {
            SectionScreen(section: section, go: { section = $0 })
                .frame(maxWidth: RootView.column)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            TabBar(section: $section)
        }
        .background(Theme.bg.ignoresSafeArea())
        // Packing reminders (his idea 7): a tapped one opens its trip on Home; and
        // whenever the library settles after a change, the waiting ones are put right.
        .onAppear {
            PackingReminders.shared.open = { id in
                section = .home
                model.tripToOpen = id
            }
            PackingReminders.shared.start()
            #if os(iOS)
            SaveNote.shared.watchKeyboard()    // a failed save's note sits above the keyboard (0.93)
            #endif
            // A tapped door check (0.69): its trip, on just what is left.
            DoorChecks.shared.open = { id, kind in
                section = .home
                model.tripFocus = LibraryModel.TripFocus(tripId: id, home: kind == .home)
                model.tripToOpen = id
            }
            // A tapped trip message (0.77, spec 07 part 16): its trip — "Welcome home", its review;
            // "Charge tonight" (0.87), its To charge.
            TripMessages.shared.open = { id, kind in
                section = .home
                if kind == .home { model.tripFocus = LibraryModel.TripFocus(tripId: id, home: false, review: true) }
                if kind == .charge { model.tripFocus = LibraryModel.TripFocus(tripId: id, home: false, charge: true) }
                model.tripToOpen = id
            }
            if AMSPackingApp.testing {
                RootView.playTappedDoorCheck(model)
                RootView.playTappedTripMessage(model)
                // A Spotlight result tapped as the app opens (0.92).
                ThingSpotlight.playTapped("-spotlightTap")
            }
            #if os(macOS)
            // The Dock icon's menu (0.86) opens a window first when none is open.
            GrabQuickActions.mainWindows += 1
            GrabQuickActions.openMainWindow = { openWindow(id: AMSPackingApp.mainWindowId) }
            GrabQuickActions.playDockMenu("-dockMenu")
            #endif
        }
        #if os(macOS)
        .onDisappear {
            GrabQuickActions.mainWindows -= 1
            if GrabQuickActions.mainWindows == 0 {
                GrabQuickActions.playDockMenu("-dockMenuWhenClosed")
                ThingSpotlight.playTapped("-spotlightTapWhenClosed")
            }
        }
        #endif
        .onReceive(model.$library.debounce(for: .seconds(2), scheduler: RunLoop.main)) { library in
            Task { await PackingReminders.shared.reschedule(library) }
            Task { await DoorChecks.shared.reschedule(library) }
            Task { await TripMessages.shared.reschedule(library) }
            // The grab lists Shortcuts offers by name follow his — and so do the four under
            // the app icon (0.86): a list added, renamed, removed or moved on Home.
            PackingShortcuts.updateAppShortcutParameters()
            GrabQuickActions.refresh(library)
            // His things in this device's Spotlight (0.92): what changed is handed over again.
            ThingSpotlight.shared.sync(library)
        }
        // Back from the shop: what was ticked in Reminders is ticked here (field test 8.4).
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await ShopReminders.shared.readBack(into: model) } }
            // Back in front — perhaps from the device's Settings, where reminders were
            // allowed again: put the packing reminders right at once, not at the next
            // change of the library.
            if phase == .active { Task { await PackingReminders.shared.reschedule(model.library) } }
            if phase == .active { Task { await DoorChecks.shared.reschedule(model.library) } }
            if phase == .active { Task { await TripMessages.shared.reschedule(model.library) } }
            // The day alone moves a trip under way on — and so where a thing is, in Spotlight.
            if phase == .active { ThingSpotlight.shared.sync(model.library) }
            if phase == .background {
                wasAway = true
                // What he finds under the icon on the Home Screen is right as he gets there.
                GrabQuickActions.refresh(model.library)
            }
            if phase == .active, wasAway {
                wasAway = false
                if AMSPackingApp.testing { RootView.playWhatHappenedWhileAway(model) }
            }
        }
        // This device checks in by itself while it syncs (0.101, `SyncWatch.checkInIfDue`): as the app
        // opens, every minute while it runs (a quarter of an hour apart at most), and back in front.
        .task {
            while !Task.isCancelled {
                SyncWatch.checkInIfDue(model)
                try? await Task.sleep(for: .seconds(60))
            }
        }
        .onChange(of: scenePhase) { _, phase in if phase == .active { SyncWatch.checkInIfDue(model) } }
        // A place's printed code, read by the iPhone's Camera (0.69): it opens on Home.
        .onOpenURL { model.open($0) }
        // A thing's result tapped in Spotlight (0.92) — at a cold start or while the app runs, on
        // the iPhone and the Mac: its page opens on Home.
        .onContinueUserActivity(CSSearchableItemActionType) { ThingSpotlight.open($0) }
        .onChange(of: model.thingToOpen, initial: true) { _, id in if id != nil { section = .home } }
        .onChange(of: model.placeToOpen, initial: true) { _, place in if place != nil { section = .home } }
        // A Shortcut asked for a grab list or a trip: both open on Home.
        .onChange(of: model.grabToOpen, initial: true) { _, id in if id != nil { section = .home } }
        .onChange(of: model.grabMenuOpen, initial: true) { _, open in if open { section = .home } }
        .onChange(of: model.tripToOpen, initial: true) { _, id in if id != nil { section = .home } }
        // A window sent him to a tab (Search → a to-do → To do).
        .onChange(of: model.tabToOpen) { _, tab in
            guard let tab else { return }
            section = tab
            model.tabToOpen = nil
        }
    }

    /// UI tests only (`-tapDoorCheck out|home`): a door check tapped as the app opens —
    /// for the first trip with that time set.
    private static func playTappedDoorCheck(_ model: LibraryModel) {
        let args = ProcessInfo.processInfo.arguments
        guard let n = args.firstIndex(of: "-tapDoorCheck"), n + 1 < args.count else { return }
        let home = args[n + 1] == "home"
        guard let trip = model.library.trips.first(where: { !Library.leaveTime($0, home: home).isEmpty }) else { return }
        DoorChecks.shared.open?(trip.id, home ? .home : .out)
    }

    /// UI tests only (`-tapTripMessage break|onsite|review|charge`): a trip message tapped as the app
    /// opens — for the first trip with lines.
    private static func playTappedTripMessage(_ model: LibraryModel) {
        let args = ProcessInfo.processInfo.arguments
        guard let n = args.firstIndex(of: "-tapTripMessage"), n + 1 < args.count,
              let kind = TripMessage.Kind(rawValue: args[n + 1]),
              let trip = model.library.trips.first(where: { !$0.entries.isEmpty }) else { return }
        TripMessages.shared.open?(trip.id, kind)
    }

    /// UI tests only: what reaches the app from outside while it is in the
    /// background, played when it comes back to the front — as a Shortcut or the
    /// Action button would (`-openGrabOnReturn <word>`), a tapped packing reminder
    /// (`-openNextTripOnReturn`), the other device's later write that no longer
    /// holds his own grab lists (`-dropOwnGrabListsOnReturn`), or (iPhone, 0.86) an entry
    /// under the app icon (`-quickActionOnReturn <title>`), or (iPhone, 0.92) a thing's result
    /// tapped in Spotlight (`-spotlightTapOnReturn <name>`).
    private static func playWhatHappenedWhileAway(_ model: LibraryModel) {
        let args = ProcessInfo.processInfo.arguments
        if let n = args.firstIndex(of: "-openGrabOnReturn"), n + 1 < args.count {
            model.grabToOpen = model.library.allGrabLists().first { $0.label == args[n + 1] || $0.title == args[n + 1] }?.id
        }
        if args.contains("-openNextTripOnReturn"), let next = model.library.nextTrip(today: Today.local) {
            PackingReminders.shared.open?(next.id)
        }
        if args.contains("-dropOwnGrabListsOnReturn") {
            model.change { $0.meta[GRAB_OWN_META] = nil }
        }
        // The other device put a thing in another bag while its page was open here (0.93):
        // `-bagOnReturn <thing> <bag>`.
        if let n = args.firstIndex(of: "-bagOnReturn"), n + 2 < args.count,
           let id = model.library.items.first(where: { $0.name == args[n + 1] })?.id {
            model.change { _ = $0.updateThing(id: id) { $0.container = args[n + 2] } }
        }
        #if os(iOS)
        // An entry under the app icon tapped while the app waited in the background (0.86).
        if let n = args.firstIndex(of: "-quickActionOnReturn"), n + 1 < args.count {
            GrabQuickActions.playWhileRunning(title: args[n + 1])
        }
        ThingSpotlight.playTapped("-spotlightTapOnReturn")
        #endif
    }
}

/// One section's screen. The ones not built yet show their mark and their name.
private struct SectionScreen: View {
    let section: AppSection
    /// A screen that sends him somewhere else (the to-do chip → Actions).
    var go: (AppSection) -> Void = { _ in }
    @EnvironmentObject var model: LibraryModel

    var body: some View {
        Group {
            switch (model.state, section) {
            case (.failed(let why), _):
                Text(why).font(.system(.body, weight: .semibold)).foregroundStyle(Color(hex: 0xdc3d43))
                    .multilineTextAlignment(.center).padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier("library-problem")
            case (.empty, .home): FirstRunView()
            case (.ready, .home): HomeScreen()
            case (.ready, .templates): TemplatesScreen()
            case (.ready, .events): EventsScreen(goToActions: { go(.actions) })
            case (.ready, .actions): ActionsScreen()
            case (.ready, .care): CareScreen()
            case (.ready, .settings), (.empty, .settings): SettingsScreen()
            default: placeholder
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // A named container must say it CONTAINS its children, or it swallows
        // their identifiers and the tests cannot find anything inside it.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screen-\(section.rawValue)")
    }

    private var placeholder: some View {
        VStack(spacing: 18) {
            Spacer()
            SectionMark(section: section, size: 96, weight: 1.6)
                .foregroundStyle(section.color)
            Text(section.label)
                .font(.system(.title, weight: .bold))
                .foregroundStyle(Theme.ink)
                .accessibilityIdentifier("screen-title")
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

private struct TabBar: View {
    @Binding var section: AppSection
    @EnvironmentObject var model: LibraryModel

    var body: some View {
        // What is still open on the To do tab's two sides (0.101, `Library.toDoTabCount`).
        let open = model.library.toDoTabCount()
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(AppSection.allCases) { s in
                    let count = s == .actions ? open : nil
                    Button { section = s } label: { TabButtonLabel(section: s, active: s == section, badge: count?.badge) }
                        .buttonStyle(.plain)
                        .focusEffectDisabled()      // no keyboard ring round a tab on the Mac
                        .accessibilityIdentifier("tab-\(s.rawValue)")
                        .accessibilityLabel(s.label)
                        // The two counts behind the badge, in words: VoiceOver says them, and on the Mac
                        // they are the tab's tooltip (0.101). The tests read the badge's number too.
                        #if DEBUG
                        .accessibilityValue(count.map { c in (c.badge.map { "badge \($0) \u{00B7} " } ?? "no badge \u{00B7} ") + c.words } ?? "")
                        #else
                        .accessibilityValue(count.flatMap { $0.total > 0 ? $0.words : nil } ?? "")
                        #endif
                        #if os(macOS)
                        .help(count.flatMap { $0.total > 0 ? $0.words : nil } ?? "")
                        #endif
                        .accessibilityAddTraits(s == section ? .isSelected : [])
                }
            }
            // A quiet build marker in its own thin row, so it can never sit on
            // top of a tab's label.
            Text(AppInfo.version)
                .font(.system(.caption2, weight: .semibold))
                .foregroundStyle(Theme.muted.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 8)
                .allowsHitTesting(false)
                .accessibilityIdentifier("app-version")
        }
        .frame(maxWidth: 720)
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
        .padding(.bottom, 2)
        .background(Theme.card.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Theme.line.frame(height: 1) }
    }
}

private struct TabButtonLabel: View {
    let section: AppSection
    let active: Bool
    /// The tab's badge (0.101 — his words, 26 Oct 2026: "To-do and to-buy counters on the 'To do'
    /// navigation pill/button"): To do's open to-dos and to-buys together, nil = none.
    var badge: String? = nil

    var body: some View {
        VStack(spacing: 3) {
            SectionMark(section: section, size: 24, weight: active ? 2.2 : 1.9)
                .foregroundStyle(active ? Color.white : section.color)
                .frame(width: 46, height: 30)
                .background(Capsule().fill(active ? section.color : section.color.opacity(0.14)))
                .overlay(alignment: .topTrailing) { if let badge { TabBadge(text: badge).offset(x: 9, y: -6) } }
            Text(section.label)
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(active ? Theme.ink : Theme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 54)
        .contentShape(Rectangle())
    }
}

/// A tab's badge, as Apple draws one on a tab bar (0.101): the number in white on red, a capsule at
/// least as wide as it is tall, at the top right of the tab's mark — ringed in the bar's own colour,
/// so it stands apart from the To do mark's red when that tab is open. Hidden from VoiceOver: the
/// tab says the counts in words.
private struct TabBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(.caption2, weight: .semibold).monospacedDigit())
            .foregroundStyle(.white)
            .lineLimit(1).fixedSize()
            .padding(.horizontal, 5)
            .frame(minWidth: 18, minHeight: 18)
            .background(Capsule().fill(AppSection.actions.color))
            .padding(2)
            .background(Capsule().fill(Theme.card))
            .accessibilityHidden(true)
    }
}

// MARK: - A save that failed (0.93, the outside review of 0.92 — his "fix 1, 2 and 6")
//
// One failed save replaced every tab with the error, and the failed change stayed waiting in the
// store. Now the store rolls it back (`CloudStore.apply`), the library is read again — the screen
// shows what is kept — and this note says so for a few seconds, in plain words, over whatever is
// open. A page is a sheet above the tabs, so the note is a small window of its own: on the iPhone
// above the tab bar — and above the keyboard while it is up — on the Mac at the foot of the window
// in front (a sheet's own window when one is open). A tap puts it away.

@MainActor
final class SaveNote {
    static let shared = SaveNote()
    static let words = "Couldn't save that \u{2014} try again."
    private var hide: DispatchWorkItem?
    #if os(iOS)
    private var window: UIWindow?
    /// The keyboard's top on the screen while it is up — the note sits above it.
    private var keyboardTop: CGFloat?
    private var watching: NSObjectProtocol?

    /// Where the keyboard is, heard from the app's start (RootView): a note shown while it is up
    /// would sit under it.
    func watchKeyboard() {
        guard watching == nil else { return }
        watching = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillChangeFrameNotification, object: nil, queue: .main
        ) { [weak self] note in
            let end = (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
            Task { @MainActor in self?.keyboardMoved(end) }
        }
    }

    private func keyboardMoved(_ end: CGRect?) {
        guard let screen = SaveNote.scene()?.coordinateSpace.bounds else { return }
        if let end, end.height > 0, end.minY < screen.height { keyboardTop = end.minY } else { keyboardTop = nil }
        if let w = window { place(w) }
    }

    private static func scene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
    }

    /// Above the tab bar, and above the keyboard while it is up; across the middle.
    private func place(_ w: UIWindow) {
        guard let scene = w.windowScene else { return }
        let screen = scene.coordinateSpace.bounds
        let size = w.frame.size
        let bottom = scene.windows.first(where: \.isKeyWindow)?.safeAreaInsets.bottom ?? 0
        var y = screen.height - bottom - size.height - 64
        if let top = keyboardTop { y = min(y, top - size.height - 12) }
        w.frame = CGRect(x: (screen.width - size.width) / 2, y: y, width: size.width, height: size.height)
    }
    #else
    private var panel: NSPanel?
    #endif

    func show() {
        close()
        #if os(iOS)
        guard let scene = SaveNote.scene() else { return }
        let host = UIHostingController(rootView: SaveNoteView { [weak self] in self?.close() })
        host.view.backgroundColor = .clear
        host.safeAreaRegions = []
        let screen = scene.coordinateSpace.bounds
        let size = host.sizeThatFits(in: CGSize(width: screen.width - 32, height: 200))
        let w = UIWindow(windowScene: scene)
        w.windowLevel = .alert + 1
        w.backgroundColor = .clear
        w.rootViewController = host
        w.frame = CGRect(origin: .zero, size: size)
        place(w)
        w.isHidden = false                     // shown, never made key: typing stays where it was
        window = w
        #else
        guard let front = NSApp.keyWindow ?? NSApp.mainWindow else { return }
        let host = NSHostingView(rootView: SaveNoteView { [weak self] in self?.close() })
        let size = host.fittingSize
        let p = NSPanel(contentRect: NSRect(x: front.frame.midX - size.width / 2, y: front.frame.minY + 24,
                                            width: size.width, height: size.height),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.contentView = host
        front.addChildWindow(p, ordered: .above)
        panel = p
        #endif
        let work = DispatchWorkItem { [weak self] in self?.close() }
        hide = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: work)
    }

    func close() {
        hide?.cancel()
        hide = nil
        #if os(iOS)
        window?.isHidden = true
        window = nil
        #else
        if let p = panel {
            p.parent?.removeChildWindow(p)
            p.orderOut(nil)
        }
        panel = nil
        #endif
    }
}

/// The note's look: calm, the app's card and ink, a thin line round it.
private struct SaveNoteView: View {
    let close: () -> Void

    var body: some View {
        Text(SaveNote.words)
            .font(.system(.subheadline, weight: .semibold))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Capsule().fill(Theme.card))
            .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
            .fixedSize()
            .padding(4)
            .contentShape(Rectangle())
            .onTapGesture(perform: close)
            .accessibilityIdentifier("save-problem")
    }
}
