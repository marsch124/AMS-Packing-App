import SwiftUI
import PackingCore
import PackingLibrary

/// The maintenance calendar, as in the web app he loves: Monday first, each service
/// on the day it falls due, the day coloured by the worst thing on it, and a tap on
/// a day to see — and tick off — what is due that day.
struct CareCalendarView: View {
    let today: String
    /// Back to the List — where overdue services, which sit in months gone by, are.
    var showList: () -> Void = {}
    @EnvironmentObject var model: LibraryModel
    @State private var month: String = ""
    @State private var chosen: String = ""

    private static let weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    private static let monthNames = ["January", "February", "March", "April", "May", "June", "July",
                                     "August", "September", "October", "November", "December"]

    var body: some View {
        let showing = month.isEmpty ? String(today.prefix(7)) : month
        let cal = model.library.careMonth(showing, today: today)
        let picked = chosen.isEmpty ? firstDay(cal) : chosen
        let due = picked.isEmpty ? [] : model.library.careDue(on: picked, today: today)

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                step(-1, "M15 6l-6 6 6 6", "care-cal-prev")
                Spacer()
                Text(CareCalendarView.title(showing))
                    .font(.system(size: 17, weight: .heavy)).foregroundStyle(Theme.ink)
                    .accessibilityIdentifier("care-cal-title")
                Spacer()
                step(1, "M9 6l6 6-6 6", "care-cal-next")
            }

            if cal.overdue > 0 {
                Button(action: showList) {
                    Text("\(cal.overdue) overdue · show in List ›")
                        .font(.system(size: 15, weight: .bold)).foregroundStyle(AppSection.actions.color)
                        .frame(minHeight: 32).contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("care-cal-overdue")
            }

            // 🪤 NOT a LazyVGrid: a lazy grid builds only the weeks on screen, and on the
            // Mac's shorter window the last weeks of the month never existed (0.18, CI).
            // A month is at most 42 cells — build them all.
            let cells: [Library.CareDay?] = Array(repeating: nil, count: cal.lead) + cal.days.map { $0 }
            let weeks = stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<min($0 + 7, cells.count)]) }
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    ForEach(CareCalendarView.weekdays, id: \.self) { d in
                        Text(d).font(.system(size: 11, weight: .heavy)).foregroundStyle(Theme.muted)
                            .frame(maxWidth: .infinity)
                    }
                }
                ForEach(weeks.indices, id: \.self) { w in
                    HStack(spacing: 4) {
                        ForEach(0..<7, id: \.self) { i in
                            if i < weeks[w].count, let day = weeks[w][i] {
                                Button { chosen = day.ymd } label: { cell(day, picked: picked) }
                                    .buttonStyle(.plain).focusEffectDisabled()
                                    .accessibilityIdentifier("care-cal-\(day.day)")
                                    .accessibilityValue(day.count > 0 ? "\(day.count) due" : "")
                            } else {
                                Color.clear.frame(maxWidth: .infinity, minHeight: 40)
                            }
                        }
                    }
                }
            }

            if !picked.isEmpty {
                Text("\(CareCalendarView.pretty(picked)) · \(due.count)")
                    .font(.system(size: 15, weight: .heavy)).foregroundStyle(Theme.muted)
                    .padding(.top, 4)
                    .accessibilityIdentifier("care-cal-day")
                ForEach(Array(due.enumerated()), id: \.element.item.id) { n, row in
                    CareRow(row: row, n: 900 + n) {
                        let id = row.item.itemId ?? row.item.id
                        model.change { _ = $0.logCare(itemId: id, on: today) }
                    }
                }
                if due.isEmpty {
                    Text("Nothing due that day.").font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.muted)
                }
            } else {
                Text("Nothing due this month. A thing shows here once it has a service interval.")
                    .font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
                    .accessibilityIdentifier("care-cal-empty")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("care-calendar")
    }

    /// A day: its number, and — when something is due — a count on its colour.
    private func cell(_ day: Library.CareDay, picked: String) -> some View {
        let tint: Color = day.state == "overdue" ? AppSection.actions.color
            : day.state == "soon" ? AppSection.care.color
            : day.state == "ok" ? AppSection.events.color : .clear
        return VStack(spacing: 2) {
            Text("\(day.day)")
                .font(.system(size: 14, weight: day.ymd == today ? .heavy : .medium).monospacedDigit())
                .foregroundStyle(day.count > 0 ? .white : Theme.ink)
            if day.count > 0 {
                Text("\(day.count)").font(.system(size: 10, weight: .heavy).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 40)
        .background(RoundedRectangle(cornerRadius: 8).fill(day.count > 0 ? tint : Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 8)
            .stroke(day.ymd == picked ? Theme.ink : (day.ymd == today ? AppSection.care.color : Theme.line),
                    lineWidth: day.ymd == picked || day.ymd == today ? 2 : 1))
        .contentShape(Rectangle())
    }

    private func step(_ by: Int, _ path: String, _ id: String) -> some View {
        Button {
            let base = month.isEmpty ? String(today.prefix(7)) : month
            month = Library.shiftMonth(base, by: by)
            chosen = ""
        } label: {
            SVGPath.path(path)
                .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .frame(width: 22, height: 22).foregroundStyle(Theme.ink)
                .frame(width: 40, height: 36).contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier(id)
    }

    /// Today if something is due today, else the first day that has something.
    private func firstDay(_ cal: Library.CareMonth) -> String {
        if let t = cal.days.first(where: { $0.ymd == today && $0.count > 0 }) { return t.ymd }
        return cal.days.first { $0.count > 0 }?.ymd ?? ""
    }

    static func title(_ ym: String) -> String {
        let m = Int(ym.dropFirst(5).prefix(2)) ?? 1
        return "\(monthNames[max(0, min(11, m - 1))]) \(ym.prefix(4))"
    }

    static func pretty(_ ymd: String) -> String {
        let d = Int(ymd.suffix(2)) ?? 0
        let m = Int(ymd.dropFirst(5).prefix(2)) ?? 1
        return "\(d) \(monthNames[max(0, min(11, m - 1))])"
    }
}
