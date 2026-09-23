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
                VStack(alignment: .leading, spacing: 2) {
                    Text("Care").font(.system(size: 28, weight: .heavy)).foregroundStyle(AppSection.care.color)
                        .accessibilityIdentifier("care-heading")
                    Text(CareScreen.line(stats))
                        .font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.muted)
                        .accessibilityIdentifier("care-line")
                }
                .padding(.top, 14).padding(.bottom, 2)

                // Everything he owns, on a list or not — the web app's "Your things".
                Button { opening = ThingsRequest(search: "") } label: {
                    HStack {
                        Text("Your things").font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.ink)
                        Text("\(model.library.items.count)").font(.system(size: 16, weight: .bold).monospacedDigit()).foregroundStyle(Theme.muted)
                        Spacer()
                        SVGPath.path("M9 6l6 6-6 6").stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                            .frame(width: 24, height: 24).foregroundStyle(Theme.muted)
                    }
                    .padding(.horizontal, 14).frame(minHeight: 52)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .padding(.top, 14)
                .accessibilityIdentifier("care-things")

                Button { table = true } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("All your things · table").font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.ink)
                            Text("Weight and where each one lives, filled in row by row")
                                .font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.muted).lineLimit(1)
                        }
                        Spacer()
                        SVGPath.path("M9 6l6 6-6 6").stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                            .frame(width: 24, height: 24).foregroundStyle(Theme.muted)
                    }
                    .padding(.horizontal, 14).frame(minHeight: 52)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .padding(.top, 8)
                .accessibilityIdentifier("care-table")

                Text(CareScreen.summary(rows: rows.count, overdue: overdue, soon: soon))
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(overdue > 0 ? AppSection.actions.color : (soon > 0 ? AppSection.care.color : AppSection.events.color))
                    .padding(.top, 10)
                    .accessibilityIdentifier("care-summary")
                ForEach(sections, id: \.key) { section in
                    let shown = !section.fold || open.contains(section.key)
                    Button {
                        if section.fold { if open.contains(section.key) { open.remove(section.key) } else { open.insert(section.key) } }
                    } label: {
                        HStack {
                            Text(section.label).font(.system(size: 15, weight: .heavy)).foregroundStyle(CareScreen.tone(section.state))
                            Text("\(section.rows.count)").font(.system(size: 15, weight: .bold).monospacedDigit()).foregroundStyle(Theme.muted)
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
                    .disabled(!section.fold)
                    .accessibilityIdentifier("care-section-\(section.key)")
                    if shown {
                        ForEach(section.rows, id: \.item.id) { row in
                            CareRow(row: row, n: order.firstIndex(of: row.item.id) ?? 0) {
                                let id = row.item.itemId ?? row.item.id
                                model.change { _ = $0.logCare(itemId: id, on: today) }
                            }
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
        .sheet(item: $opening) { ask in ThingsScreen(searching: ask.search).environmentObject(model) }
        .sheet(isPresented: $table) { ThingsTable().environmentObject(model) }
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
    let done: () -> Void

    var body: some View {
        let s = row.status
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(row.item.name).font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.ink)
                Text(CareRow.when(s, notes: row.item.maintenance?.notes ?? ""))
                    .font(.system(size: 15, weight: .medium)).foregroundStyle(CareScreen.tone(s.state))
                    .lineLimit(2)
                if !row.listName.isEmpty {
                    Text(row.listName).font(.system(size: 14)).foregroundStyle(Theme.muted).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if s.scheduled {
                Button(action: done) {
                    Text("Done today").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 12).frame(minHeight: 36)
                        .background(Capsule().fill(AppSection.care.color))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("care-row-\(n)-done")
                .accessibilityLabel("\(row.item.name) done today")
            }
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
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
