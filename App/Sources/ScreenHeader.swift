import SwiftUI

/// The first line of a tab: its title at the left and its buttons at the right, ALL
/// on one centre line — and, under it, the short line about what is on the tab.
///
/// His note on 0.63 (6 Oct 2026), "Overall, icons are not aligned": until 0.67 every
/// tab built this row itself and lined it up on the TITLE'S BASELINE, so a 36-pt
/// icon button stood up from the baseline and sat about 10 pt higher than the words
/// beside it (Trips' map pin and search, Templates' search and + New, Care's search,
/// Home's search and Grab Lists) — and left an empty band above the title. One view
/// for every tab now (Home, Trips, Templates, Care), centred; checked on each tab by
/// `testEveryTabsHeaderIsOnOneCentreLine`. To do's first line (To do · To buy ·
/// search) was centred already and starts at the same height; Settings has none.
///
/// On the Mac the header is pinned in the window's title bar strip instead (see
/// `TitleBarStrip`, `headerOnTheMac`); on the iPhone it scrolls with the page.
struct ScreenHeader<Trailing: View>: View {
    let title: String
    let tint: Color
    /// The title's name for the tests ("events-heading").
    let id: String
    /// A tab's title is Title 2. Home leads with a section heading instead, Grab and go,
    /// in Title 3 like Create new trip under it.
    var font: Font = .system(.title2, weight: .bold)
    /// The line under the title ("5 trips · 1 ready to go"), and its name.
    var line: String? = nil
    var lineId: String = ""
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                Text(title).font(font).foregroundStyle(tint)
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .accessibilityIdentifier(id)
                Spacer(minLength: 8)
                trailing()
            }
            .headerLine()
            if let line {
                Text(line)
                    .font(.system(.subheadline)).foregroundStyle(Theme.muted)
                    .accessibilityIdentifier(lineId)
            }
        }
    }
}

/// The Mac's main window has no title bar of its own (0.67, `.hiddenTitleBar`; his note
/// on 0.63: the strip at the top was "underused" — his boxes covered the title bar too).
/// The strip where it was — the traffic lights' line — holds the tab's header. RootView
/// measures it: how tall it is (the window's top safe area: 32 on macOS 26) and how far
/// a header must step in so its title starts just after the three window buttons
/// (`Metrics.windowButtons` from the window's left edge, less the column's own margin).
struct TitleBarStrip: Equatable {
    var height: CGFloat = 0
    var lead: CGFloat = 0
}

private struct TitleBarStripKey: EnvironmentKey {
    static let defaultValue = TitleBarStrip()
}

extension EnvironmentValues {
    var titleBarStrip: TitleBarStrip {
        get { self[TitleBarStripKey.self] }
        set { self[TitleBarStripKey.self] = newValue }
    }
}

extension View {
    /// A page and its header. On the iPhone the header is the page's first line and
    /// scrolls with it — the page puts it there itself, and this does nothing. On the Mac
    /// it is pinned in the window's title bar strip, on the traffic lights' line, and the
    /// page scrolls under it: nothing ever slides beneath the window buttons.
    @ViewBuilder
    func headerOnTheMac<Header: View>(@ViewBuilder _ header: () -> Header) -> some View {
        #if os(macOS)
        VStack(spacing: 0) {
            // 6 under the header, so the page's scroll view never touches the strip:
            // 🪤 where it did (Home and To do, whose header is one line), a click on a
            // header button in the strip never arrived (GitHub's Mac run, 6 Oct 2026),
            // while Trips and Templates — a summary line under the title — were fine.
            header().padding(.horizontal, 16).padding(.bottom, 6)
            self.titleBarSafeScroll()
        }
        .ignoresSafeArea(.container, edges: .top)
        #else
        self
        #endif
    }

    /// The Mac: no edge effect at the top of this page's scroll views (macOS 26 draws
    /// one where a scroll view meets the title bar region; the header sits there now).
    @ViewBuilder
    func titleBarSafeScroll() -> some View {
        #if os(macOS)
        if #available(macOS 26.0, *) {
            self.scrollEdgeEffectHidden(true, for: .top)
        } else {
            self
        }
        #else
        self
        #endif
    }

    /// A tab's first line: on the iPhone `Metrics.tap` tall, `Metrics.screenTop` under the
    /// status bar; on the Mac as tall as the title bar strip, so it is centred on the
    /// traffic lights' line, and stepped in past the window buttons.
    func headerLine() -> some View { modifier(HeaderLine()) }
}

private struct HeaderLine: ViewModifier {
    @Environment(\.titleBarStrip) private var strip

    func body(content: Content) -> some View {
        #if os(macOS)
        content
            .padding(.leading, strip.lead)
            .frame(minHeight: max(strip.height, Metrics.tap))
        #else
        content
            .frame(minHeight: Metrics.tap)
            .padding(.top, Metrics.screenTop)
        #endif
    }
}
