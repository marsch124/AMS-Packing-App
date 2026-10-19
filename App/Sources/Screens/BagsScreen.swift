import SwiftUI
import PackingCore
import PackingLibrary

/// His bags, and the three numbers each one has: what it may carry, its size, and
/// what it weighs empty. A bag given a max weight here shows how full it is on
/// every trip it goes on.
///
/// A bag's name opens its own page (BagDetail), where it is renamed or deleted —
/// things are packed into a bag by its NAME, so both carry through every thing,
/// list and trip (see Bags.swift). The app says "Bags" everywhere (his ask, 2026-09-27).
///
/// 0.91 (his test sheet on 0.90, 19 Oct 2026): the name opens the bag and its arrow sits right
/// after the name ("the arrow is not nice" — it hung against MAX KG); under Own order each row has
/// the grip ≡ (on the Mac also ▲ ▼) and he arranges his bags here ("I can't order the bags myself,
/// but that would be a good function"); and a number typed into a row waits in the row until the
/// list is left, a bag's page opens, the sort changes or a bag is added (`EditDraft`) — moving from
/// field to field writes nothing, as on a bag's page.
struct BagsScreen: View {
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    @State private var newName = ""
    /// What Add was missing, said under the field (never a grey button).
    @State private var addNeeds = ""
    /// The bag whose own page is open.
    @State private var openBag: OpenBag?
    struct OpenBag: Identifiable { let id: String }
    /// How the bags are sorted (0.90, his ask of 19 Oct 2026) — remembered on this device.
    @AppStorage(BagsScreen.sortKey) private var sort = BagSort.own.rawValue
    static let sortKey = "ams.bags.sort"
    /// The order the rows stand in (bag ids), sorted when the list opens, the sort is chosen, a bag
    /// comes or goes, or a bag's page closes — never while he types a number into a row: under Last
    /// edited the row would jump away from his finger at the first key.
    @State private var order: [String] = []
    /// The numbers typed into the rows and not written yet (0.91).
    @State private var draft = EditDraft()
    /// The bag being carried by its grip, and each row's height — one place (0.91).
    @State private var carried: ReorderDrag?
    @State private var heights: [String: CGFloat] = [:]
    /// Where the carried bag stood in his order when it was picked up (its id → index).
    @State private var pickedUp: (id: String, from: Int)?

    private var sorting: BagSort { BagSort(rawValue: sort) ?? .own }
    /// Arranged by hand only in his own order (0.91).
    private var arranging: Bool { sorting == .own }

    /// His bags as the rows stand: in `order`, then any not sorted yet (one arriving from the other
    /// device), in the sort's own place for them.
    private var shown: [Item] {
        let all = model.library.sortedBags(sorting)
        let place = Dictionary(order.enumerated().map { ($1, $0) }, uniquingKeysWith: { a, _ in a })
        return all.stableSorted(compare: { a, b in
            switch (place[a.id], place[b.id]) {
            case let (x?, y?): return x < y ? -1 : (x > y ? 1 : 0)
            case (_?, nil): return -1
            case (nil, _?): return 1
            default: return 0
            }
        })
    }

    private func resort() { order = model.library.sortedBags(sorting).map(\.id) }

    var body: some View {
        let bags = shown
        VStack(spacing: 0) {
            HStack {
                Text("Your bags").font(.system(.title3, weight: .bold)).foregroundStyle(AppSection.care.color)
                Text("\(bags.count)").font(.system(.subheadline, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Theme.muted)
                    .accessibilityIdentifier("yourbags-count")
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(HeaderButtonStyle(tint: AppSection.care.color, filled: true)).focusEffectDisabled()
                    .font(.system(.body, weight: .semibold)).foregroundStyle(AppSection.care.color)
                    .keyboardShortcut(.cancelAction)            // Escape closes it, as Done does (Escape everywhere, 5 Oct 2026)
                    .accessibilityIdentifier("yourbags-done")
            }
            .padding(16)

            // The line and the column names stay put while the bags scroll under
            // them — his ask (2026-09-26): "keep the header row visible".
            VStack(alignment: .leading, spacing: 0) {
                Text("Give a bag its max weight and every trip shows how full it is.")
                    .font(.system(.footnote)).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 8)

                // Sort (0.90): Own order (as arranged in Usually packed in's list), A–Z, Last used
                // (newest trip), Last added, Last edited — BagSorting.swift. Ties keep his order.
                DropDown(title: "Sort", heading: .beside, options: BagSort.allCases.map { ($0.rawValue, $0.label) },
                         selected: BagSort(rawValue: sort)?.rawValue ?? BagSort.own.rawValue,
                         id: "yourbags-sort", tint: AppSection.care.color) { sort = $0 }
                    .padding(.bottom, 4)
                // How to arrange them (0.91): by hand in his own order, which a thing's Usually
                // packed in shows too; under any other sort, where to go for that.
                Text(arranging ? (ReorderArrows.shown ? "Hold \u{2261} and drag, or use the arrows, to put your bags in your order."
                                                      : "Hold \u{2261} and drag to put your bags in your order.")
                               : "Choose Own order to arrange your bags.")
                    .font(.system(.footnote)).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 8)
                    .accessibilityIdentifier("yourbags-order-hint")

                HStack(spacing: 6) {
                    Spacer()
                    Text("MAX KG").frame(width: BagsScreen.numberWidth)
                    Text("LITRES").frame(width: BagsScreen.numberWidth)
                    Text("EMPTY G").frame(width: BagsScreen.gramsWidth)
                    // Over the Mac's ▲ ▼ (0.91): nothing, so the names stay over their fields.
                    if arranging && ReorderArrows.shown && bags.count > 1 {
                        Color.clear.frame(width: Metrics.compact * 2 + 6, height: 1)
                    }
                }
                .font(.system(.caption2, weight: .semibold)).foregroundStyle(Theme.muted).kerning(0.4)
                .padding(.bottom, 4)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("yourbags-columns")
            }
            .padding(.horizontal, 16)
            .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }

            KeyboardAwayScroll {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(bags.enumerated()), id: \.element.id) { n, bag in
                        BagRow(bag: bag, n: n, count: bags.count, draft: draft, arranging: arranging,
                               open: {
                                   // What is typed in the rows first: the page shows the same numbers.
                                   draft.flush(model)
                                   openBag = OpenBag(id: bag.id)
                               },
                               grip: { grip(bag, n: n) },
                               canMove: { canMove(bag.id, $0) }, move: { step(bag.id, by: $0, now: true) })
                            .environmentObject(model)
                            .reorderStep(bag.id, into: $heights)
                            .reorderLift(carried, key: bag.id, tint: AppSection.care.color)
                    }
                    if bags.isEmpty {
                        Text("No bags yet.").font(.system(.subheadline))
                            .foregroundStyle(Theme.muted).padding(.vertical, 20)
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 16)
            }

            // Add at the BOTTOM — his rule.
            HStack(spacing: 8) {
                TextField("A new bag", text: $newName)
                    .textFieldStyle(.plain)
                    .font(.system(.body)).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 12).frame(minHeight: Metrics.tap)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                    .onSubmit { add() }
                    .accessibilityIdentifier("bag-new-name")
                Button { add() } label: { FieldButtonLabel(title: "Add", tint: AppSection.care.color) }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("bag-new")
            }
            .needsLine($addNeeds, typed: newName, id: "bag-new-needs")
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
        .background(Theme.bg.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("yourbags-detail")
        .sheet(item: $openBag, onDismiss: resort) { b in BagDetail(bagId: b.id).environmentObject(model) }
        .onAppear(perform: resort)
        // A sort chosen sorts by what is typed too (Last edited).
        .onChange(of: sort) { _, _ in draft.flush(model); resort() }
        .onChange(of: model.library.bags().map(\.id).sorted()) { _, _ in resort() }
        // A drag let go: the bag's new place written, in one change (0.91).
        .onChange(of: carried) { _, now in if now == nil { dropped() } }
        // Left — Done, a swipe down, Escape: what is typed in the rows is written.
        .onDisappear { draft.flush(model) }
        .writesDraftWhenAway(draft, model)
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 560)
        #endif
    }

    private var canAdd: Bool {
        let wanted = normName(newName)
        return !wanted.isEmpty && !model.library.bags().contains { normName($0.name) == wanted }
    }

    private func add() {
        guard canAdd else {
            addNeeds = normName(newName).isEmpty ? "Type a name first." : "You already have a bag called that."
            return
        }
        let name = newName
        model.change { lib in
            draft.apply(to: &lib)
            _ = lib.addBag(name: name)
        }
        newName = ""
    }

    // MARK: His own order (0.91)

    /// The row's grip, under Own order: hold and drag; each place passed moves the row on the
    /// screen, and the bag's new place is written once, when it is let go.
    private func grip(_ bag: Item, n: Int) -> some View {
        ReorderGrip(id: "bag-\(n)-grip", label: "Move \(bag.name)", key: bag.id, step: heights[bag.id] ?? Metrics.tap,
                    drag: $carried, canMove: { canMove(bag.id, $0) }, move: { step(bag.id, by: $0, now: false) },
                    tint: AppSection.care.color)
            .padding(.leading, -6)
    }

    private func canMove(_ id: String, _ by: Int) -> Bool {
        guard arranging, let at = order.firstIndex(of: id) else { return false }
        return order.indices.contains(at + by)
    }

    /// One place up (−1) or down (1). `now`: written at once (the Mac's ▲ ▼). Otherwise the row only
    /// moves on the screen while the grip is held, and the bag's new place is written when it is let go
    /// (`dropped`) — or, when no hand holds it (VoiceOver's Move up / Move down; the Mac's first step of
    /// a drag comes before the grip says it is held), a moment later, once it is clear none does.
    private func step(_ id: String, by: Int, now: Bool) {
        guard canMove(id, by), let at = order.firstIndex(of: id) else { return }
        if now {
            guard let name = model.library.bags().first(where: { $0.id == id })?.name else { return }
            var moved = false
            model.change { lib in
                draft.apply(to: &lib)
                moved = lib.moveBag(named: name, by: by)
            }
            if moved { resort() }
            return
        }
        if pickedUp?.id != id { pickedUp = (id, at) }
        order.swapAt(at, at + by)
        DispatchQueue.main.async { if carried == nil { dropped() } }
    }

    /// The grip let go: the bag from where it was picked up to where it now stands, written in one
    /// change — one place at a time through the bag list's own move (`moveBag`), as Usually packed
    /// in's list moves it.
    private func dropped() {
        guard let picked = pickedUp else { return }
        pickedUp = nil
        guard let to = order.firstIndex(of: picked.id), to != picked.from,
              let name = model.library.bags().first(where: { $0.id == picked.id })?.name else { return }
        let by = to > picked.from ? 1 : -1, times = abs(to - picked.from)
        model.change { lib in
            draft.apply(to: &lib)
            for _ in 0..<times { guard lib.moveBag(named: name, by: by) else { break } }
        }
        resort()
    }

    /// One bag: its name, and its three numbers, each changed where it stands.
    private struct BagRow<Grip: View>: View {
        let bag: Item
        let n: Int
        let count: Int
        let draft: EditDraft
        /// Own order: the grip ≡ before the name (and on the Mac ▲ ▼ after the numbers).
        let arranging: Bool
        /// Open the bag's own page (rename, delete, what it knows).
        let open: () -> Void
        @ViewBuilder let grip: () -> Grip
        let canMove: (Int) -> Bool
        let move: (Int) -> Void
        @EnvironmentObject var model: LibraryModel

        var body: some View {
            HStack(spacing: 6) {
                if arranging && count > 1 { grip() }
                // The name opens the bag's page; under it, what it knows at a glance.
                let facts = model.library.bagFacts(name: bag.name)
                let line = BagRow.glance(facts)
                Button(action: open) {
                    VStack(alignment: .leading, spacing: 1) {
                        // The arrow right after the name, centred on its line (0.91 — his "the arrow
                        // is not nice": it stood at the row's far end, 12 points wide for a drawing
                        // on a 24-point grid, so it hung low and against MAX KG).
                        HStack(spacing: 3) {
                            // Two lines for a long name, in the size every name has (it was shrunk
                            // to fit one line, and still cut off, once the grip came).
                            Text(bag.name)
                                .font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.ink)
                                .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                            SVGPath.path("M9 6l6 6-6 6").stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                                .foregroundStyle(Theme.muted)
                                .onGrid(13)
                                .accessibilityHidden(true)
                        }
                        if !line.isEmpty {
                            Text(line).font(.system(.caption)).foregroundStyle(Theme.muted)
                                .lineLimit(1).minimumScaleFactor(0.85)
                        }
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("bag-\(n)-name")
                .accessibilityValue(line)
                // Clear room between the name and the first number.
                Spacer(minLength: 12)
                let id = bag.id
                field("maxKg", now: bag.maxKg, shown: bag.maxKg > 0 ? BagsScreen.show(bag.maxKg) : "", width: BagsScreen.numberWidth,
                      id: "bag-\(n)-maxkg") { v, lib in _ = lib.setBag(id: id, maxKg: v) }
                field("litres", now: bag.capacityL, shown: bag.capacityL > 0 ? BagsScreen.show(bag.capacityL) : "", width: BagsScreen.numberWidth,
                      id: "bag-\(n)-litres") { v, lib in _ = lib.setBag(id: id, capacityL: v) }
                field("empty", now: bag.weight, shown: bag.weight > 0 ? String(Int(bag.weight.rounded())) : "", width: BagsScreen.gramsWidth,
                      id: "bag-\(n)-empty") { v, lib in _ = lib.setBag(id: id, emptyGrams: v) }
                // ▲ ▼ on the Mac only, as every list he orders (0.72): the iPhone drags the grip.
                if arranging && ReorderArrows.shown && count > 1 {
                    arrow("M6 15l6-6 6 6", by: -1, id: "bag-\(n)-up", label: "Move \(bag.name) up")
                    arrow("M6 9l6 6 6-6", by: 1, id: "bag-\(n)-down", label: "Move \(bag.name) down")
                }
            }
            .frame(minHeight: Metrics.tap)
            .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
        }

        private func arrow(_ d: String, by: Int, id: String, label: String) -> some View {
            Button { move(by) } label: {
                SVGPath.path(d).stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(canMove(by) ? AppSection.care.color : Theme.faint)
                    .onGrid(16)
                    .frame(width: Metrics.compact, height: Metrics.tap)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain).focusEffectDisabled()
            .accessibilityLabel(label)
            .accessibilityIdentifier(id)
        }

        /// 🪤 Kept AS TYPED: it used to save only on Return, so numbers typed and left (Done, or a
        /// tap elsewhere) looked set and were lost — his max weights of 2026-09-26 morning (Swim
        /// bag 5, Duffel bag 20…) never reached the trips. Since 0.91 the row keeps what is typed
        /// and Your bags writes it when it is left (or a bag's page opens, the sort changes, a bag
        /// is added, the app goes away) — never lost, and no write at every key.
        /// "176 things · last trip 5.1 kg" — or less, when there is less to say.
        static func glance(_ facts: Library.BagFacts) -> String {
            var parts: [String] = []
            if !facts.things.isEmpty { parts.append("\(facts.things.count) thing\(facts.things.count == 1 ? "" : "s")") }
            if let last = facts.trips.first { parts.append("last trip \(BagsCard.kilos(last.grams))") }
            return parts.joined(separator: " · ")
        }

        private func field(_ key: String, now: Double, shown: String, width: CGFloat, id: String,
                           write: @escaping (Double, inout Library) -> Void) -> some View {
            DraftedField(key: "\(bag.id)/\(key)", kept: shown, draft: draft, differs: { TypedNumber.differs($0, from: now) },
                         write: { words, lib in if let v = TypedNumber.read(words) { write(v, &lib) } }) { text in
                TextField("", text: text)
                    .textFieldStyle(.plain)
                    .font(.system(.subheadline, weight: .semibold).monospacedDigit()).foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.trailing)
                    .padding(.horizontal, 6)
                    .frame(width: width, height: 34)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 1))
                    .accessibilityIdentifier(id)
            }
        }
    }

    /// The numbers' widths (0.91: 54 and 62, from 64 and 70 — room for the grip, and four digits
    /// and five still fit; the column names stand over them at the same widths).
    static let numberWidth: CGFloat = 54
    static let gramsWidth: CGFloat = 62

    static func show(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
    }
}
