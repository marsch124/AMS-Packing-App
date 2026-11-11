import SwiftUI
import PackingCore
import PackingLibrary

/// Care: everything with a care schedule or care notes, what needs doing first
/// at the top. "Overdue" and "Due soon" stay open — that is what you act on; a
/// service eight months out folds away. "Done today" logs a service on the thing.
struct CareScreen: View {
    @EnvironmentObject var model: LibraryModel
    @State private var open: Set<String> = []
    /// Your things, and what it opens searched for when he taps a bar. Carried as
    /// ONE value: a `sheet(isPresented:)` builds its content before a second piece
    /// of state has changed, and the search arrived empty.
    @State private var opening: ThingsRequest?

    struct ThingsRequest: Identifiable { let id = UUID(); let search: String }
    @State private var table = false
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif

    /// The table: a window of its own on the Mac, a sheet on the iPhone.
    private func openTable() {
        #if os(macOS)
        openWindow(id: ThingsTable.windowId)
        #else
        table = true
        #endif
    }
    @State private var searching = false
    @State private var bagsOpen = false
    /// "list" or "calendar", remembered on this device.
    @AppStorage("ams.care.view") private var careView = "list"

    /// "Care", with the search beside it on ONE centre line (ScreenHeader; his note on
    /// 0.63): the tab's first line on the iPhone, pinned in the window's title bar strip on
    /// the Mac.
    private func header(_ stats: Library.KitStats) -> some View {
        ScreenHeader(title: "Care", tint: AppSection.care.color, id: "care-heading",
                     line: CareScreen.line(stats), lineId: "care-line") {
            SearchButton { searching = true }
        }
        .padding(.bottom, 2)
    }

    var body: some View {
        let today = Today.local
        let rows = model.library.careRows(today: today)
        let sections = careSections(rows).filter { !$0.rows.isEmpty }
        let order = sections.flatMap(\.rows).map(\.item.id)
        let overdue = rows.filter { $0.status.state == "overdue" }.count
        let soon = rows.filter { $0.status.state == "soon" }.count
        let stats = model.library.kitStats(today: today)
        KeyboardAwayScroll {
            LazyVStack(alignment: .leading, spacing: 6) {
                // On the Mac the header is pinned in the window's title bar strip
                // instead (`headerOnTheMac`, below).
                #if !os(macOS)
                header(stats)
                #endif

                // B (0.112, stage 3 of the redesign he picked on 11 Nov 2026): Your things, Bags and the
                // table as rows of ONE grouped list, as Apple's Settings — three cards of their own until 0.111.
                GroupedRows(rows: [
                    ("things", AnyView(Button { opening = ThingsRequest(search: "") } label: {
                        BRow(title: "Your things", count: "\(model.library.ownThings().count)")
                    }.buttonStyle(.plain).focusEffectDisabled().accessibilityIdentifier("care-things"))),
                    ("bags", AnyView(Button { bagsOpen = true } label: {
                        BRow(title: "Bags", detail: "How much each may carry, and what goes in it",
                             count: "\(model.library.bags().count)")
                    }.buttonStyle(.plain).focusEffectDisabled().accessibilityIdentifier("care-bags"))),
                    ("table", AnyView(Button { openTable() } label: {
                        BRow(title: "All your things · table", detail: "Weight and where each one lives, filled in row by row")
                    }.buttonStyle(.plain).focusEffectDisabled().accessibilityIdentifier("care-table")))
                ], id: "care-group")
                .padding(.top, 10)

                Text(CareScreen.summary(rows: rows.count, overdue: overdue, soon: soon))
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(overdue > 0 ? AppSection.actions.color : (soon > 0 ? AppSection.care.color : AppSection.events.color))
                    .padding(.top, 10)
                    .accessibilityIdentifier("care-summary")

                // List or Calendar — the web app's two views of the same services; Apple's segmented
                // control since 0.112 (two pills until then).
                BSegmented(options: [("list", "List", "care-view-list"), ("calendar", "Calendar", "care-view-calendar")],
                           chosen: careView, tint: AppSection.care.color) { careView = $0 }
                    .padding(.top, 6)

                if careView == "calendar" {
                    CareCalendarView(today: today, showList: { careView = "list" }).environmentObject(model)
                        .padding(.top, 8)
                } else {
                ForEach(sections, id: \.key) { section in
                    let shown = !section.fold || open.contains(section.key)
                    Button {
                        if section.fold { if open.contains(section.key) { open.remove(section.key) } else { open.insert(section.key) } }
                    } label: {
                        HStack {
                            Text(section.label).font(.headline)
                                .foregroundStyle(CareScreen.tone(section.state))
                            Text("\(section.rows.count)").font(.system(.body, weight: .semibold).monospacedDigit()).foregroundStyle(Theme.muted)
                            Spacer()
                            if section.fold {
                                SVGPath.path(shown ? "M6 9l6 6 6-6" : "M9 6l6 6-6 6")
                                    .stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                                    .frame(width: 24, height: 24).foregroundStyle(Theme.muted)
                            }
                        }
                        .padding(.top, 14).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    // Not `.disabled`: a switched-off button is drawn faded, and Overdue (which never folds)
                    // looked grey-red (his note, 11 Nov 2026). It just takes no taps now — full colour (0.113).
                    .allowsHitTesting(section.fold)
                    .accessibilityIdentifier("care-section-\(section.key)")
                    if shown {
                        // In one rounded card per part (B, 0.112), a hairline between the rows.
                        let last = section.rows.last?.item.id
                        VStack(spacing: 0) {
                            ForEach(section.rows, id: \.item.id) { row in
                                CareRow(row: row, n: order.firstIndex(of: row.item.id) ?? 0, last: row.item.id == last) {
                                    let id = row.item.itemId ?? row.item.id
                                    model.change { _ = $0.logCare(itemId: id, on: today) }
                                }
                            }
                        }
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1).allowsHitTesting(false))
                    }
                }

                }

                // What the kit adds up to, LAST: what needs doing comes first, and
                // the dashboard is what he browses afterwards. (It also kept the
                // things above it from being built at all on the Mac's shorter
                // window — a lazy list only builds what is near the screen.)
                KitDashboard(stats: stats) { search in opening = ThingsRequest(search: search) }
                    .padding(.top, 18)
            }
            .padding(.horizontal, 16).padding(.bottom, 24)
        }
        .headerOnTheMac { header(stats) }
        .sheet(item: $opening) { ask in ThingsScreen(searching: ask.search).environmentObject(model) }
        .sheet(isPresented: $table) { ThingsTable().environmentObject(model) }
        .sheet(isPresented: $searching) { SearchScreen().environmentObject(model) }
        .sheet(isPresented: $bagsOpen) { BagsScreen().environmentObject(model) }
    }

    /// "431 things · 12.4 kg · 2 looked after" — the state of the kit in one line.
    static func line(_ s: Library.KitStats) -> String {
        var parts = ["\(s.things) thing\(s.things == 1 ? "" : "s")"]
        if s.totalGrams > 0 { parts.append(KitDashboard.kilos(s.totalGrams)) }
        parts.append("\(s.withCare) looked after")
        return parts.joined(separator: " · ")
    }

    static func summary(rows: Int, overdue: Int, soon: Int) -> String {
        if rows == 0 { return "Nothing has a care schedule yet." }
        if overdue == 0 && soon == 0 { return "All up to date" }
        return [overdue > 0 ? "\(overdue) overdue" : "", soon > 0 ? "\(soon) due soon" : ""]
            .filter { !$0.isEmpty }.joined(separator: " · ")
    }

    static func tone(_ state: String) -> Color {
        switch state {
        case "overdue": return AppSection.actions.color
        case "soon": return AppSection.care.color
        default: return Theme.muted
        }
    }
}

struct CareRow: View {
    let row: MaintenanceRow
    let n: Int
    var last = false
    let done: () -> Void

    var body: some View {
        let s = row.status
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(row.item.name).font(.system(.body, weight: .semibold)).foregroundStyle(Theme.ink)
                Text(CareRow.when(s, notes: row.item.maintenance?.notes ?? ""))
                    .font(.system(.subheadline)).foregroundStyle(CareScreen.tone(s.state))
                    .lineLimit(2)
                if !row.listName.isEmpty {
                    Text(row.listName).font(.system(.footnote)).foregroundStyle(Theme.muted).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if s.scheduled {
                Button(action: done) {
                    Text("Done today").font(.system(.subheadline, weight: .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 12).frame(minHeight: Metrics.chip)
                        .background(Capsule().fill(AppSection.care.color))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("care-row-\(n)-done")
                .accessibilityLabel("\(row.item.name) done today")
            }
        }
        .padding(.vertical, 5).padding(.horizontal, 12)
        .overlay(alignment: .bottom) { if !last { Theme.line.frame(height: 1).padding(.leading, 12) } }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("care-row-\(n)")
    }

    /// "Overdue by 12 days · every 90 days", "Due in 5 days", "Never done — due now".
    static func when(_ s: MaintenanceStatus, notes: String) -> String {
        if !s.scheduled { return notes.split(separator: "\n").first.map(String.init) ?? "Care notes" }
        let every = "every \(s.intervalDays) days"
        if s.neverDone { return "Never done — due now · \(every)" }
        guard let d = s.days else { return "Due \(s.nextDue) · \(every)" }
        let plural = abs(d) == 1 ? "day" : "days"
        if d < 0 { return "Overdue by \(-d) \(plural) · \(every)" }
        if d == 0 { return "Due today · \(every)" }
        return "Due in \(d) \(plural) · \(every)"
    }
}
