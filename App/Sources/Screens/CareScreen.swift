import SwiftUI
import PackingCore
import PackingLibrary

/// Care: everything with a care schedule or care notes, what needs doing first
/// at the top. "Overdue" and "Due soon" stay open — that is what you act on; a
/// service eight months out folds away. "Done today" logs a service on the thing.
struct CareScreen: View {
    @EnvironmentObject var model: LibraryModel
    @State private var open: Set<String> = []

    var body: some View {
        let today = Today.local
        let rows = model.library.careRows(today: today)
        let sections = careSections(rows).filter { !$0.rows.isEmpty }
        let order = sections.flatMap(\.rows).map(\.item.id)
        let overdue = rows.filter { $0.status.state == "overdue" }.count
        let soon = rows.filter { $0.status.state == "soon" }.count
        KeyboardAwayScroll {
            LazyVStack(alignment: .leading, spacing: 6) {
                Text(CareScreen.summary(rows: rows.count, overdue: overdue, soon: soon))
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(overdue > 0 ? AppSection.actions.color : (soon > 0 ? AppSection.care.color : AppSection.events.color))
                    .padding(.top, 14)
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
            }
            .padding(.horizontal, 16).padding(.bottom, 24)
        }
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
