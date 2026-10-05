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
/// red; one near it is the Care orange; the rest are blue.
///
/// One bar per bag, thick and blue on grey — their choice, 3 Oct 2026 ("we
/// would like one bar"): the grey is what the bag may carry, the blue what is in it.
/// The thin green bar before was easy to miss.
///
/// The luggage scale (his idea 8, 2 Oct 2026): tap a bag and type what the scale
/// says. From then on that is the weight the bag is judged by — the bag itself and
/// everything never weighed included — and the things' sum stays beside it.
struct BagsCard: View {
    let tripId: String
    @EnvironmentObject var model: LibraryModel
    /// His ask (2026-09-26): "a small information button that explains the colors".
    @State private var showKey = false
    /// The bag whose scale reading is being typed, and what is typed.
    @State private var weighing: String?
    @State private var scaleText = ""
    @FocusState private var typing: Bool

    var body: some View {
        // Every bag that has something in it — weighed or not (the spec pass, 5 Oct
        // 2026): a bag whose things had no weight was left off, and its luggage scale,
        // cabin switch and photos could not be reached from the trip.
        let bags = model.library.weighedBags(tripId: tripId).filter { $0.load.items > 0 }
        if !bags.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Text("Bags").font(.system(size: 15, weight: .heavy)).foregroundStyle(Theme.ink)
                    Button { showKey.toggle() } label: {
                        ZStack {
                            Circle().stroke(Theme.muted, lineWidth: 1.4).frame(width: 18, height: 18)
                            Text("i").font(.system(size: 12, weight: .heavy, design: .serif)).foregroundStyle(Theme.muted)      // not text: the letter of the drawn info mark
                        }
                        .frame(width: 32, height: 28).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("bags-key-open")
                    .accessibilityLabel("What the colours mean")
                    let over = bags.filter(\.over).count
                    if over > 0 {
                        Text("\(over) over")
                            .font(.system(size: 15, weight: .heavy)).foregroundStyle(.white)
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .background(Capsule().fill(AppSection.actions.color))
                            .accessibilityIdentifier("bags-over")
                    }
                    Spacer()
                    Text(BagsCard.kilos(bags.reduce(0) { $0 + $1.grams }))
                        .font(.system(size: 15, weight: .heavy).monospacedDigit()).foregroundStyle(Theme.muted)
                        .accessibilityIdentifier("bags-total")
                }
                if showKey { key }
                ForEach(Array(bags.enumerated()), id: \.offset) { n, bag in
                    VStack(alignment: .leading, spacing: 8) {
                        Button { open(bag) } label: { row(bag) }
                            .buttonStyle(.plain).focusEffectDisabled()
                            .accessibilityIdentifier("bag-\(n)")
                            // What the bar shows, in words: the colour cannot be read
                            // any other way (VoiceOver, and the tests).
                            .accessibilityValue(BagsCard.gauge(bag))
                        if weighing == bag.load.container {
                            scaleEditor(bag, n)
                            BagCabinRow(bag: bag.load.container, n: n).environmentObject(model)
                            // A photo of it packed (his idea 11), to repack from on the way home.
                            BagPhotoRow(tripId: tripId, bag: bag.load.container, n: n).environmentObject(model)
                        }
                    }
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
            keyLine(AppSection.home.color, "Blue", "well within its max")
            keyLine(AppSection.care.color, "Orange", "nine tenths of its max or more")
            keyLine(AppSection.actions.color, "Red, \u{201C}over\u{201D}", "more than its max")
            Text("No bar: no max set. Set one in Care \u{2192} Bags. Tap a bag for the luggage scale, and a photo of it packed.")
                .font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.muted)
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
            Text(name).font(.system(size: 15, weight: .heavy)).foregroundStyle(Theme.ink)
            Text(meaning).font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func row(_ bag: WeighedBag) -> some View {
        let tint = BagsCard.tint(bag)
        let limit = bag.load.limitKg
        let part = limit > 0 ? min(1, bag.grams / 1000 / limit) : 0
        let name = bag.load.container == "Other" ? "Not in a bag" : bag.load.container
        let weight = bag.scaleGrams != nil ? "\(BagsCard.kilos(bag.grams)) weighed" : BagsCard.kilos(bag.grams)
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                Spacer(minLength: 8)
                // Every bag says its maximum — or that it has none (his ask, 2026-09-26).
                // A bag with nothing weighed says what to do instead of "0 g".
                Text(bag.grams == 0 ? "Tap to weigh"
                     : limit > 0 ? "\(weight) / \(BagsCard.number(limit)) kg"
                     : bag.load.container == "Other" ? weight : "\(weight) \u{00B7} no max")
                    .font(.system(size: 15, weight: .bold).monospacedDigit())
                    .foregroundStyle(bag.over ? AppSection.actions.color : Theme.muted)
            }
            // Only a bag that HAS a limit gets a bar — a bar with no end says nothing —
            // and something weighed to show on it.
            if limit > 0 && bag.grams > 0 {
                GeometryReader { space in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.line)
                        Capsule().fill(tint).frame(width: max(16, part * space.size.width))
                    }
                }
                .frame(height: 16)
                .padding(.vertical, 2)
            }
            if bag.scaleGrams != nil {
                Text("The things in it add up to \(BagsCard.kilos(bag.load.grams))")
                    .font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.muted)
            }
        }
        .contentShape(Rectangle())
    }

    /// Type what the scale says, in kg; Save keeps it, Clear takes it away.
    private func scaleEditor(_ bag: WeighedBag, _ n: Int) -> some View {
        HStack(spacing: 8) {
            TextField("kg on the scale", text: $scaleText)
                .textFieldStyle(.plain)
                .font(.system(size: 17, weight: .semibold).monospacedDigit()).foregroundStyle(Theme.ink)
                .padding(.horizontal, 10).frame(height: 40)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bg))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 1))
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
                .focused($typing)
                .onSubmit { save(bag) }
                .accessibilityIdentifier("bag-\(n)-scale")
            Button { save(bag) } label: {
                Text("Save").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                    .padding(.horizontal, 14).frame(minHeight: 40)
                    .background(Capsule().fill(AppSection.events.color))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain).focusEffectDisabled()
            .accessibilityIdentifier("bag-\(n)-scale-save")
            if bag.scaleGrams != nil {
                Button("Clear") {
                    let container = bag.load.container
                    model.change { _ = $0.setWeighed(tripId: tripId, bag: container, grams: nil) }
                    weighing = nil
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.muted)
                .accessibilityIdentifier("bag-\(n)-scale-clear")
            }
        }
    }

    private func open(_ bag: WeighedBag) {
        if weighing == bag.load.container { weighing = nil; return }
        weighing = bag.load.container
        scaleText = bag.scaleGrams.map { BagsCard.number(($0 / 100).rounded() / 10) } ?? ""
    }

    private func save(_ bag: WeighedBag) {
        let clean = jsTrim(scaleText).replacingOccurrences(of: ",", with: ".")
        let kg = Double(clean) ?? 0
        let container = bag.load.container
        model.change { _ = $0.setWeighed(tripId: tripId, bag: container, grams: kg > 0 ? kg * 1000 : nil) }
        weighing = nil
        typing = false
    }

    /// Red when over, orange from nine tenths, blue below.
    static func tint(_ bag: WeighedBag) -> Color {
        switch state(bag) {
        case "over": return AppSection.actions.color
        case "close": return AppSection.care.color
        default: return AppSection.home.color
        }
    }

    /// "fine", "close" (nine tenths of its max or more) or "over" — the bar's colour.
    static func state(_ bag: WeighedBag) -> String {
        if bag.over { return "over" }
        if bag.load.limitKg > 0, bag.grams / 1000 >= bag.load.limitKg * 0.9 { return "close" }
        return "fine"
    }

    /// The bar in words: "fine, 25% of its max"; "no max" when it has none.
    static func gauge(_ bag: WeighedBag) -> String {
        let limit = bag.load.limitKg
        guard bag.grams > 0 else { return "not weighed" }
        guard limit > 0 else { return "no max" }
        return "\(state(bag)), \(Int((bag.grams / 10 / limit).rounded()))% of its max"
    }

    static func kilos(_ grams: Double) -> String {
        grams < 1000 ? "\(Int(grams.rounded())) g" : String(format: "%.1f kg", grams / 1000)
    }

    static func number(_ kg: Double) -> String {
        kg == kg.rounded() ? String(Int(kg)) : String(format: "%.1f", kg)
    }
}
