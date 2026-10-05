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
        VStack(spacing: 0) {
            SectionScreen(section: section, go: { section = $0 })
                .frame(maxWidth: 720)                 // the web app's column, on the Mac
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
                Text(why).font(.system(size: 17, weight: .semibold)).foregroundStyle(Color(hex: 0xdc3d43))
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
                .font(.system(size: 34, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .accessibilityIdentifier("screen-title")
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

private struct TabBar: View {
    @Binding var section: AppSection

    var body: some View {
        VStack(spacing: 0) {
            TabRow {
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
                .font(.system(size: 15, weight: .semibold))
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
            // 15 like every word in the app (his floor: nothing under 15), and never
            // shrunk to fit — `TabRow` gives a long label the room it needs instead.
            Text(section.label)
                .font(.system(size: 15, weight: active ? .heavy : .semibold))
                .foregroundStyle(active ? Theme.ink : Theme.muted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 54)
        .contentShape(Rectangle())
    }
}

/// The six tabs side by side, each label whole at 15 pt. Equal widths wherever they
/// fit; a tab whose label needs more ("Templates" on an iPhone, at 12.5 pt it fitted
/// by shrinking) gets exactly what it needs and the others share what is left. At
/// equal widths an iPhone gives each tab 67 points, and "Templates" at 15 heavy needs 79.
private struct TabRow: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let widths = widths(proposal.width, subviews)
        let height = zip(subviews, widths)
            .map { $0.sizeThatFits(ProposedViewSize(width: $1, height: proposal.height)).height }
            .max() ?? 0
        return CGSize(width: widths.reduce(0, +), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        for (tab, width) in zip(subviews, widths(bounds.width, subviews)) {
            tab.place(at: CGPoint(x: x, y: bounds.minY), proposal: ProposedViewSize(width: width, height: bounds.height))
            x += width
        }
    }

    /// What each tab needs; the room left over is shared evenly by the tabs that need
    /// less than an even share.
    private func widths(_ total: CGFloat?, _ subviews: Subviews) -> [CGFloat] {
        let needs = subviews.map { ceil($0.sizeThatFits(.unspecified).width) }
        guard let total, !needs.isEmpty else { return needs }
        var wide = Set<Int>()           // the tabs given exactly what they need
        while true {
            let left = total - wide.reduce(0) { $0 + needs[$1] }
            let share = left / CGFloat(needs.count - wide.count)
            let more = needs.indices.filter { !wide.contains($0) && needs[$0] > share }
            if more.isEmpty || wide.count + more.count == needs.count {
                wide.formUnion(more)
                return needs.indices.map { wide.contains($0) ? needs[$0] : share }
            }
            wide.formUnion(more)
        }
    }
}
