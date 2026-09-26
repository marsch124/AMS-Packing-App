import SwiftUI
import PackingCore
import PackingLibrary

/// How heavy each bag on this trip is, against what it may carry.
///
/// The web app's "Bags & weight", from the same arithmetic (`bagLoads`, parity-
/// checked). Weight is the only honest measure: the web app records a bag's
/// capacity in litres but nothing is ever measured against it, and the things
/// have no volume of their own.
///
/// Colour is the message, as he asked of every indicator: a bag over its limit is
/// red; one near it is the Care orange; the rest are the trip's green.
struct BagsCard: View {
    let tripId: String
    @EnvironmentObject var model: LibraryModel
    /// His ask (2026-09-26): "a small information button that explains the colors".
    @State private var showKey = false

    var body: some View {
        let trip = model.library.trips.first { $0.id == tripId } ?? newEvent()
        let bags = bagLoads(trip.entries, qtyNights(trip), model.library.bagLimits())
            .filter { $0.items > 0 && $0.grams > 0 }
        if !bags.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Text("Bags").font(.system(size: 15, weight: .heavy)).foregroundStyle(Theme.ink)
                    Button { showKey.toggle() } label: {
                        ZStack {
                            Circle().stroke(Theme.muted, lineWidth: 1.4).frame(width: 18, height: 18)
                            Text("i").font(.system(size: 12, weight: .heavy, design: .serif)).foregroundStyle(Theme.muted)
                        }
                        .frame(width: 32, height: 28).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("bags-key-open")
                    .accessibilityLabel("What the colours mean")
                    let over = bags.filter(\.over).count
                    if over > 0 {
                        Text("\(over) over")
                            .font(.system(size: 13, weight: .heavy)).foregroundStyle(.white)
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .background(Capsule().fill(AppSection.actions.color))
                            .accessibilityIdentifier("bags-over")
                    }
                    Spacer()
                    Text(BagsCard.kilos(bags.reduce(0) { $0 + $1.grams }))
                        .font(.system(size: 14, weight: .heavy).monospacedDigit()).foregroundStyle(Theme.muted)
                        .accessibilityIdentifier("bags-total")
                }
                if showKey { key }
                ForEach(Array(bags.enumerated()), id: \.offset) { n, bag in
                    row(bag).accessibilityIdentifier("bag-\(n)")
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(bags.contains(where: \.over) ? AppSection.actions.color : Theme.line, lineWidth: 1))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("bags-card")
        }
    }

    /// What the colours mean — the same three words everywhere a bag is weighed.
    private var key: some View {
        VStack(alignment: .leading, spacing: 6) {
            keyLine(AppSection.events.color, "Green", "well within its max")
            keyLine(AppSection.care.color, "Orange", "nine tenths of its max or more")
            keyLine(AppSection.actions.color, "Red, \u{201C}over\u{201D}", "more than its max")
            Text("No bar: no max set. Set one in Care → Containers.")
                .font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bg))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("bags-key")
    }

    private func keyLine(_ tint: Color, _ name: String, _ meaning: String) -> some View {
        HStack(spacing: 8) {
            Capsule().fill(tint).frame(width: 22, height: 8)
            Text(name).font(.system(size: 13, weight: .heavy)).foregroundStyle(Theme.ink)
            Text(meaning).font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func row(_ bag: BagLoad) -> some View {
        let tint = BagsCard.tint(bag)
        let part = bag.limitKg > 0 ? min(1, bag.grams / 1000 / bag.limitKg) : 0
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(bag.container == "Other" ? "Not in a bag" : bag.container)
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                Spacer(minLength: 8)
                // Every bag says its maximum — or that it has none (his ask, 2026-09-26).
                Text(bag.limitKg > 0 ? "\(BagsCard.kilos(bag.grams)) / \(BagsCard.number(bag.limitKg)) kg"
                                     : bag.container == "Other" ? BagsCard.kilos(bag.grams)
                                     : "\(BagsCard.kilos(bag.grams)) · no max")
                    .font(.system(size: 14, weight: .bold).monospacedDigit())
                    .foregroundStyle(bag.over ? AppSection.actions.color : Theme.muted)
            }
            // Only a bag that HAS a limit gets a bar — a bar with no end says nothing.
            if bag.limitKg > 0 {
                GeometryReader { space in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.line)
                        Capsule().fill(tint).frame(width: max(6, part * space.size.width))
                    }
                }
                .frame(height: 8)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// Red when over, orange from nine tenths, green below.
    static func tint(_ bag: BagLoad) -> Color {
        if bag.over { return AppSection.actions.color }
        if bag.limitKg > 0, bag.grams / 1000 >= bag.limitKg * 0.9 { return AppSection.care.color }
        return AppSection.events.color
    }

    static func kilos(_ grams: Double) -> String {
        grams < 1000 ? "\(Int(grams.rounded())) g" : String(format: "%.1f kg", grams / 1000)
    }

    static func number(_ kg: Double) -> String {
        kg == kg.rounded() ? String(Int(kg)) : String(format: "%.1f", kg)
    }
}
