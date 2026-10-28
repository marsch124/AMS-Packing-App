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
///
/// Folded to ONE line by default (0.74, his ask of 12 Oct 2026: the overview "takes too
/// much space"): "Bags", the over badge — a warning, so it stays — and the total; a tap
/// opens it. Open or folded is remembered on this device (`ams.trip.bags`), for every trip.
///
/// "+ Add a bag" at its foot when open (0.83, his report of 14 Oct 2026: he looked for it here) —
/// the Packing Stations' Bags out panel (`AddBagPanel`), the same rules, ids under `bags-addbag`;
/// until the trip is reviewed.
struct BagsCard: View {
    let tripId: String
    @EnvironmentObject var model: LibraryModel
    @AppStorage(BagsCard.openKey) private var unfolded = false
    static let openKey = "ams.trip.bags"
    /// His ask (2026-09-26): "a small information button that explains the colors".
    @State private var showKey = false
    /// The bag whose scale reading is being typed, and what is typed.
    @State private var weighing: String?
    @State private var scaleText = ""
    @FocusState private var typing: Bool
    /// The bag whose Lost bag page is open — "Lost bag?" under a bag (0.80, spec 07 part 18 C).
    @State private var lost: LostBagOpen?
    /// "+ Add a bag" is open (0.83).
    @State private var addingBag = false
    /// The bag whose own page is open from its pen (0.90, "Edit bag when packing").
    @State private var editing: EditBagOpen?

    var body: some View {
        // Every bag that has something in it — weighed or not (the spec pass, 5 Oct
        // 2026): a bag whose things had no weight was left off, and its luggage scale,
        // cabin switch and photos could not be reached from the trip. And (0.81) every bag
        // Packing Stations' "+ Add a bag" put on the trip, empty or not — it is the trip's.
        let bags = model.library.weighedBags(tripId: tripId).filter { $0.load.items > 0 || $0.added }
        // A reviewed trip is history: no bag is added to it or taken off it here.
        let reviewed = model.library.trips.first { $0.id == tripId }.map(Library.isReviewed) ?? true
        // A bag "+ Add a bag" put on the trip with nothing in it yet: "nothing in it yet", and a ✕.
        let empty = bags.filter { $0.load.items == 0 && $0.added }.map(\.load.container)
        if !bags.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    // The fold: its own button, so the over badge and the total stay texts of
                    // their own (the Mac folds a button's texts into the button).
                    Button { unfolded.toggle() } label: {
                        HStack(spacing: 6) {
                            SVGPath.path("M9 6l6 6-6 6")
                                .stroke(style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                                .onGrid(Metrics.glyph)
                                .rotationEffect(.degrees(unfolded ? 90 : 0))
                                .foregroundStyle(Theme.ink)
                            Text("Bags").font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.ink)
                        }
                        // 28 on both until 0.104: 24 on the Mac now (`Metrics.cardLine`), the iPhone's 28 kept.
                        .frame(minHeight: min(Metrics.cardLine, 28)).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("bags-toggle")
                    .accessibilityLabel(unfolded ? "Fold the bags" : "Open the bags")
                    .accessibilityValue(unfolded ? "open" : "folded")
                    if unfolded {
                        Button { showKey.toggle() } label: {
                            ZStack {
                                Circle().stroke(Theme.muted, lineWidth: 1.4).frame(width: 18, height: 18)
                                Text("i").font(.system(.caption, design: .serif, weight: .semibold)).foregroundStyle(Theme.muted)
                            }
                            .frame(width: 32, height: min(Metrics.cardLine, 28)).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).focusEffectDisabled()
                        .accessibilityIdentifier("bags-key-open")
                        .accessibilityLabel("What the colours mean")
                    }
                    let over = bags.filter(\.over).count
                    if over > 0 {
                        Text("\(over) over")
                            .font(.system(.footnote, weight: .semibold)).foregroundStyle(.white)
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .background(Capsule().fill(AppSection.actions.color))
                            .accessibilityIdentifier("bags-over")
                    }
                    Spacer(minLength: 8)
                    Text(BagsCard.kilos(bags.reduce(0) { $0 + $1.grams }))
                        .font(.system(.footnote, weight: .semibold).monospacedDigit()).foregroundStyle(Theme.muted)
                        .accessibilityIdentifier("bags-total")
                }
                // The rest of the line opens and folds it too.
                .contentShape(Rectangle())
                .onTapGesture { unfolded.toggle() }
                .sheet(item: $editing) { open in BagDetail(bagId: open.id).environmentObject(model) }
                if unfolded {
                    if showKey { key }
                    // The Packing day's photo of all the bags (0.79, spec 07 part 17) — here at every
                    // step, for the airline desk when a bag is lost after he has left.
                    GroupPhotoLine(tripId: tripId).environmentObject(model)
                    ForEach(Array(bags.enumerated()), id: \.offset) { n, bag in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top, spacing: 10) {
                                // How the bag looks (0.80), while this trip has no photo of it packed —
                                // beside the row, not in it: a button inside a button never reaches the tree.
                                BagLookThumb(tripId: tripId, bag: bag.load.container, id: "bag-\(n)-look").environmentObject(model)
                                Button { open(bag) } label: { BagWeightRow(bag: bag) }
                                    .buttonStyle(.plain).focusEffectDisabled()
                                    .accessibilityIdentifier("bag-\(n)")
                                    // What the bar shows, in words: the colour cannot be read
                                    // any other way (VoiceOver, and the tests).
                                    .accessibilityValue(BagsCard.gauge(bag))
                                // Beside the row, not in it (a button inside a button never reaches the tree):
                                // the ✕ of an empty bag added — as in Bags out.
                                if !reviewed && empty.contains(bag.load.container) {
                                    Button {
                                        let t = tripId, name = bag.load.container
                                        model.change { _ = $0.removeAddedBag(tripId: t, bag: name) }
                                    } label: {
                                        IconMark(path: StationDrawings.cross, size: Metrics.glyph * 0.8, weight: 2)
                                            .foregroundStyle(Theme.muted)
                                            .frame(width: Metrics.lineButton, height: Metrics.line)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain).focusEffectDisabled()
                                    .accessibilityIdentifier("bag-\(n)-remove")
                                    .accessibilityLabel("Take \(bag.load.container) off this trip")
                                }
                                // Its page, from the trip (0.90): the round pen, last on the line.
                                EditBagPen(bag: bag.load.container, id: "bag-\(n)-edit") { editing = EditBagOpen(id: $0) }
                                    .environmentObject(model)
                            }
                            // Lost bag? (0.80): everything a baggage desk asks about this bag — at every
                            // step, for the airport. Only for a bag a desk can lose (0.83, `hasLostBagPage`:
                            // not "Not in a bag", not "On body"); a quiet link under the row, at the right.
                            if Library.hasLostBagPage(bag.load.container) {
                                HStack {
                                    Spacer(minLength: 0)
                                    LostBagDoor(id: "bag-\(n)-lost") { lost = LostBagOpen(bag: bag.load.container) }
                                }
                                .padding(.top, -8)
                            }
                            if weighing == bag.load.container {
                                scaleEditor(bag, n)
                                BagCabinRow(bag: bag.load.container, n: n).environmentObject(model)
                                // A photo of it packed (his idea 11), to repack from on the way home.
                                BagPhotoRow(tripId: tripId, bag: bag.load.container, n: n).environmentObject(model)
                                // A plane trip's checked bag (0.80, spec 07 part 18 B): the number on its tag from check-in.
                                if model.library.asksBagTag(tripId: tripId, bag: bag.load.container) {
                                    BagTagField(tripId: tripId, bag: bag.load.container, id: "bag-\(n)-tagno")
                                        .environmentObject(model)
                                }
                            }
                        }
                    }
                    if !reviewed {
                        if let first = empty.first {
                            Text("To fill \(first), pick it as Usually packed in on its things\u{2019} pages \u{2014} grouped by Into, the list shows what is in each bag.")
                                .font(.system(.footnote)).foregroundStyle(Theme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("bags-addbag-hint")
                        }
                        addBag.padding(.top, 2)
                    }
                }
            }
            // Folded: one slim line — 4 above and below it (6 until 0.104, his arrows of 28 Oct 2026: "a
            // tad" tighter; 14 at the sides and under an open card then, `Metrics.cardSide`/`cardInset` now).
            .padding(.horizontal, Metrics.cardSide).padding(.vertical, unfolded ? Metrics.cardInset : 4)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(bags.contains(where: \.over) ? AppSection.actions.color : Theme.line, lineWidth: 1))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("bags-card")
            .sheet(item: $lost) { open in LostBagScreen(tripId: tripId, bag: open.bag).environmentObject(model) }
        }
    }

    /// "+ Add a bag" (0.83): the button, or the panel it opens — Bags out's own.
    @ViewBuilder private var addBag: some View {
        if addingBag {
            AddBagPanel(tripId: tripId, prefix: "bags-addbag") { addingBag = false }.environmentObject(model)
        } else {
            Button { addingBag = true } label: { StationAddLabel(title: "Add a bag") }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("bags-addbag")
                .accessibilityLabel("Add a bag")
        }
    }

    /// What the colours mean — the same three words everywhere a bag is weighed.
    private var key: some View {
        VStack(alignment: .leading, spacing: 6) {
            keyLine(AppSection.home.color, "Blue", "well within its max")
            keyLine(AppSection.care.color, "Orange", "nine tenths of its max or more")
            keyLine(AppSection.actions.color, "Red, \u{201C}over\u{201D}", "more than its max")
            Text("No bar: no max set. Set one in Care \u{2192} Bags. Tap a bag for the luggage scale, and a photo of it packed. Lost bag? under a bag: everything a baggage desk asks for.")
                .font(.system(.footnote)).foregroundStyle(Theme.muted)
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
            Text(name).font(.system(.footnote, weight: .semibold)).foregroundStyle(Theme.ink)
            Text(meaning).font(.system(.footnote)).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Type what the scale says, in kg; Save keeps it, Clear takes it away.
    private func scaleEditor(_ bag: WeighedBag, _ n: Int) -> some View {
        HStack(spacing: 8) {
            TextField("kg on the scale", text: $scaleText)
                .textFieldStyle(.plain)
                .font(.system(.body, weight: .semibold).monospacedDigit()).foregroundStyle(Theme.ink)
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
                Text("Save").font(.system(.callout, weight: .semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 12).frame(minHeight: Metrics.compact)
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
                .font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.muted)
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

/// One bag's row: its name, its weight against its max ("6.4 kg weighed / 8 kg", "Tap to weigh",
/// "· no max"), the one bar in its colour when it has a max, and what its things add up to once
/// weighed. ONE view (0.79) for the trip's Bags card and the Packing day's Weigh station, so the
/// two can never say a bag differently.
struct BagWeightRow: View {
    let bag: WeighedBag

    var body: some View {
        let tint = BagsCard.tint(bag)
        let limit = bag.load.limitKg
        let part = limit > 0 ? min(1, bag.grams / 1000 / limit) : 0
        let name = bag.load.container == "Other" ? "Not in a bag" : bag.load.container
        let weight = bag.scaleGrams != nil ? "\(BagsCard.kilos(bag.grams)) weighed" : BagsCard.kilos(bag.grams)
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name).font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                Spacer(minLength: 8)
                // Every bag says its maximum — or that it has none (his ask, 2026-09-26).
                // A bag with nothing weighed says what to do instead of "0 g".
                // A bag with nothing in it at all (one "+ Add a bag" put on the trip) says so (0.83).
                Text(bag.grams == 0 ? (bag.load.items == 0 ? "nothing in it yet" : "Tap to weigh")
                     : limit > 0 ? "\(weight) / \(BagsCard.number(limit)) kg"
                     : bag.load.container == "Other" ? weight : "\(weight) \u{00B7} no max")
                    .font(.system(.footnote, weight: .semibold).monospacedDigit())
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
                    .font(.system(.footnote)).foregroundStyle(Theme.muted)
            }
        }
        .contentShape(Rectangle())
    }
}
