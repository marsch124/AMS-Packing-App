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
            .frame(minHeight: Metrics.tap)
            if let line {
                Text(line)
                    .font(.system(.subheadline)).foregroundStyle(Theme.muted)
                    .accessibilityIdentifier(lineId)
            }
        }
        .padding(.top, Metrics.screenTop)
    }
}
