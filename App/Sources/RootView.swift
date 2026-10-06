import SwiftUI
import Combine
import PackingCore
import PackingLibrary

/// The frame of the app: one screen at a time, and the tab bar under it.
struct RootView: View {
    @State private var section: AppSection = .home
    @EnvironmentObject var model: LibraryModel
    @Environment(\.scenePhase) private var scenePhase
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
        #if os(macOS)
        .background { TitleBarDrag() }             // behind the headers, in front of the colour
        #endif
        .background(Theme.bg.ignoresSafeArea())
        // Packing reminders (his idea 7): a tapped one opens its trip on Home; and
        // whenever the library settles after a change, the waiting ones are put right.
        .onAppear {
            PackingReminders.shared.open = { id in
                section = .home
                model.tripToOpen = id
            }
            PackingReminders.shared.start()
        }
        .onReceive(model.$library.debounce(for: .seconds(2), scheduler: RunLoop.main)) { library in
            Task { await PackingReminders.shared.reschedule(library) }
            // The grab lists Shortcuts offers by name follow his.
            PackingShortcuts.updateAppShortcutParameters()
        }
        // Back from the shop: what was ticked in Reminders is ticked here (field test 8.4).
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await ShopReminders.shared.readBack(into: model) } }
            // Back in front — perhaps from the device's Settings, where reminders were
            // allowed again: put the packing reminders right at once, not at the next
            // change of the library.
            if phase == .active { Task { await PackingReminders.shared.reschedule(model.library) } }
            if phase == .background { wasAway = true }
            if phase == .active, wasAway {
                wasAway = false
                if AMSPackingApp.testing { RootView.playWhatHappenedWhileAway(model) }
            }
        }
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

    /// UI tests only: what reaches the app from outside while it is in the
    /// background, played when it comes back to the front — as a Shortcut or the
    /// Action button would (`-openGrabOnReturn <word>`), a tapped packing reminder
    /// (`-openNextTripOnReturn`), or the other device's later write that no longer
    /// holds his own grab lists (`-dropOwnGrabListsOnReturn`).
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

#if os(macOS)
/// The strip where the title bar was moves the window when dragged, as the title bar
/// did (0.67). It lies BEHIND the page, so a header's buttons take their own clicks:
/// only the strip's empty parts — and the whole strip on a tab with no header — are this.
private struct TitleBarDrag: View {
    @Environment(\.titleBarStrip) private var strip

    var body: some View {
        Color.clear
            .frame(height: strip.height)
            .contentShape(Rectangle())
            .gesture(WindowDragGesture())
            .allowsWindowActivationEvents(true)
            .frame(maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea(.container, edges: .top)
            .accessibilityHidden(true)
    }
}
#endif

private struct TabBar: View {
    @Binding var section: AppSection

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(AppSection.allCases) { s in
                    Button { section = s } label: { TabButtonLabel(section: s, active: s == section) }
                        .buttonStyle(.plain)
                        .focusEffectDisabled()      // no keyboard ring round a tab on the Mac
                        .accessibilityIdentifier("tab-\(s.rawValue)")
                        .accessibilityLabel(s.label)
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

    var body: some View {
        VStack(spacing: 3) {
            SectionMark(section: section, size: 24, weight: active ? 2.2 : 1.9)
                .foregroundStyle(active ? Color.white : section.color)
                .frame(width: 46, height: 30)
                .background(Capsule().fill(active ? section.color : section.color.opacity(0.14)))
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
