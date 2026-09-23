import SwiftUI
import PackingCore
import PackingLibrary

/// The top of the Care tab: what his kit adds up to, drawn from what his library
/// actually holds — weight, where things live, what is due — with the tips saying
/// only things that are true of HIS library. Every mark here is data: bars and
/// rings, never art.
struct KitDashboard: View {
    let stats: Library.KitStats
    /// Tapping a place or a list opens Your things, already searched.
    var look: (String) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Four numbers, read before anything is read.
            HStack(spacing: 8) {
                figure("\(stats.things)", "things", AppSection.templates.color, "kit-things")
                figure(KitDashboard.kilos(stats.totalGrams), "in total", AppSection.home.color, "kit-weight")
                figure("\(stats.overdue + stats.soon)", stats.overdue > 0 ? "need care" : "due soon",
                       stats.overdue > 0 ? AppSection.actions.color : AppSection.care.color, "kit-due")
                figure("\(stats.withoutPlace)", "no place", Theme.muted, "kit-noplace")
            }

            if !stats.heaviest.isEmpty {
                section("The heavy end", id: "kit-heavy-heading")
                let top = stats.heaviest.first?.grams ?? 1
                ForEach(Array(stats.heaviest.prefix(6).enumerated()), id: \.offset) { n, thing in
                    Button { look(thing.name) } label: {
                        bar(label: thing.name, right: KitDashboard.kilos(thing.grams),
                            part: top > 0 ? thing.grams / top : 0, tint: AppSection.home.color)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("kit-heavy-\(n)")
                }
            }

            if stats.places.count > 1 {
                section("Where it all lives", id: "kit-places-heading")
                let most = stats.places.first?.count ?? 1
                ForEach(Array(stats.places.prefix(6).enumerated()), id: \.offset) { n, place in
                    Button { look(place.label == "Nowhere said" ? "" : place.label) } label: {
                        bar(label: place.label, right: "\(place.count)",
                            part: most > 0 ? Double(place.count) / Double(most) : 0,
                            tint: place.label == "Nowhere said" ? Theme.line : AppSection.templates.color)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("kit-place-\(n)")
                }
            }

            if stats.lists.count > 1 {
                section("What each list weighs", id: "kit-lists-heading")
                let heaviest = stats.lists.first?.grams ?? 1
                ForEach(Array(stats.lists.prefix(5).enumerated()), id: \.offset) { n, list in
                    bar(label: list.label, right: KitDashboard.kilos(list.grams),
                        part: heaviest > 0 ? list.grams / heaviest : 0, tint: AppSection.events.color)
                        .accessibilityIdentifier("kit-list-\(n)")
                }
            }

            if stats.dueByMonth.contains(where: { $0 > 0 }) {
                section("The year ahead", id: "kit-year-heading")
                let tallest = stats.dueByMonth.max() ?? 1
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(Array(stats.dueByMonth.enumerated()), id: \.offset) { n, count in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(count > 0 ? AppSection.care.color : Theme.line)
                                .frame(height: max(3, 44 * (tallest > 0 ? Double(count) / Double(tallest) : 0)))
                            Text(KitDashboard.month(n))
                                .font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.muted)
                        }
                    }
                }
                .frame(height: 62)
                .accessibilityIdentifier("kit-year")
                .accessibilityLabel("Care due over the next twelve months")
            }

            if !stats.tips.isEmpty {
                section("Worth knowing", id: "kit-tips-heading")
                ForEach(Array(stats.tips.prefix(4).enumerated()), id: \.offset) { n, tip in
                    HStack(alignment: .top, spacing: 8) {
                        Circle().fill(AppSection.care.color).frame(width: 6, height: 6).padding(.top, 7)
                        Text(tip).font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityIdentifier("kit-tip-\(n)")
                }
            }
        }
    }

    private func section(_ title: String, id: String) -> some View {
        Text(title).font(.system(size: 15, weight: .heavy)).foregroundStyle(Theme.muted)
            .padding(.top, 6)
            .accessibilityIdentifier(id)
    }

    /// One big number with its word under it.
    private func figure(_ number: String, _ word: String, _ tint: Color, _ id: String) -> some View {
        VStack(spacing: 2) {
            Text(number).font(.system(size: 22, weight: .heavy).monospacedDigit()).foregroundStyle(tint)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(word).font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.muted).lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 58)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(id)
    }

    /// A row whose BAR is the number: length carries the comparison, the figure
    /// beside it carries the fact.
    private func bar(label: String, right: String, part: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                Spacer(minLength: 8)
                Text(right).font(.system(size: 14, weight: .bold).monospacedDigit()).foregroundStyle(Theme.muted)
            }
            GeometryReader { space in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.line).frame(height: 6)
                    Capsule().fill(tint)
                        .frame(width: max(4, min(1, part) * space.size.width), height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    /// "2.4 kg", or "240 g" when that reads better.
    static func kilos(_ grams: Double) -> String {
        guard grams > 0 else { return "—" }
        if grams < 1000 { return "\(Int(grams.rounded())) g" }
        return String(format: "%.1f kg", grams / 1000)
    }

    /// The month n months from now, as three letters.
    static func month(_ ahead: Int) -> String {
        let now = Calendar(identifier: .gregorian).date(byAdding: .month, value: ahead, to: Date()) ?? Date()
        let f = DateFormatter(); f.setLocalizedDateFormatFromTemplate("MMM")
        return String(f.string(from: now).prefix(3))
    }
}
