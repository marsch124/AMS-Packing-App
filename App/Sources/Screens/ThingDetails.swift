import SwiftUI
import PackingCore
import PackingLibrary

/// A thing's Details (0.115 — inventory step 1, his plan and answers of 11 Nov 2026): right under
/// Photos, in Care's orange, folded to one "Add details" button while the thing has none. Everything
/// is written into the page's draft and kept only on Save, as every other part of the page.
struct ThingDetailsCard: View {
    @EnvironmentObject var model: LibraryModel
    @Binding var draft: Item
    @State private var open = false
    @State private var priceText = ""
    @State private var valueText = ""
    @State private var countText = ""
    @State private var loaded = false

    private var tint: Color { AppSection.care.color }

    static func isEmpty(_ it: Item) -> Bool {
        jsTrim(it.manufacturer).isEmpty && jsTrim(it.model).isEmpty && jsTrim(it.serial).isEmpty
            && !isYMD(it.acquired) && Library.shop(it).isEmpty && it.price <= 0 && Library.valueSet(it) == nil
            && !isYMD(it.warranty) && it.qtyOwned <= 1 && !Library.staysHome(it)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HeadingBand(title: "Details", id: "thing-heading-details")
            if open || !ThingDetailsCard.isEmpty(draft) {
                card
            } else {
                Button { withAnimation(.easeInOut(duration: 0.2)) { open = true } } label: {
                    HStack(spacing: 6) {
                        SVGPath.path("M12 5v14M5 12h14")
                            .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round)).onGrid(Metrics.glyph * 0.8)
                        Text("Add details").font(.system(.body, weight: .semibold))
                        Text("brand, bought, price, warranty").font(.system(.subheadline)).foregroundStyle(Theme.muted)
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(tint)
                    .padding(.horizontal, 12).frame(minHeight: Metrics.tap).contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .bCard()
                .accessibilityIdentifier("thing-details-open")
            }
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            priceText = amountText(draft.price)
            valueText = Library.valueSet(draft).map(amountText) ?? ""
            countText = draft.qtyOwned > 1 ? String(draft.qtyOwned) : ""
        }
    }

    private var card: some View {
        let today = Today.local
        let estimate = Library.valueSet(draft) == nil ? Library.valueToday(draft, today: today) : nil
        return VStack(alignment: .leading, spacing: 0) {
            line("Brand") { text($draft.manufacturer, "e.g. Sony", "thing-brand") }
            line("Model") { text($draft.model, "e.g. WH-1000XM5", "thing-model") }
            line("Serial") { text($draft.serial, "Number on the label", "thing-serial") }
            line("Bought on") { boughtOn }
            line("Bought at") {
                VStack(alignment: .leading, spacing: 4) {
                    text(Binding(get: { Library.shop(draft) }, set: { Library.setShop(&draft, $0) }), "e.g. Elgiganten", "thing-bought-at")
                    let shops = model.library.shopSuggestions(typed: Library.shop(draft))
                    if !shops.isEmpty {
                        chips(shops, id: "thing-shop-suggest") { Library.setShop(&draft, $0) }
                    }
                }
            }
            line("Price") {
                HStack(spacing: 6) {
                    text(Binding(get: { priceText }, set: { priceText = $0; if let v = readAmount($0) { draft.price = v } }),
                         "per piece", "thing-price")
                    TextField("SEK", text: $draft.currency)
                        .textFieldStyle(.plain).font(.system(.body)).foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.trailing).frame(width: 48)
                        .accessibilityIdentifier("thing-currency")
                }
            }
            line("Value today") {
                text(Binding(get: { valueText }, set: { valueText = $0
                    let t = jsTrim($0)
                    Library.setValue(&draft, t.isEmpty ? nil : readAmount(t)) }),
                     estimate.map { "about \(amountText($0))" } ?? "what it's worth now", "thing-value")
            }
            line("Warranty") { warranty(today: today) }
            line("How many") {
                text(Binding(get: { countText }, set: { countText = $0
                    draft.qtyOwned = max(1, Int(jsTrim($0)) ?? 1) }), "1", "thing-owned-count")
            }
            line("Stays at home", last: true) {
                Toggle("", isOn: Binding(get: { Library.staysHome(draft) }, set: { Library.setStaysHome(&draft, $0) }))
                    .labelsHidden().tint(tint)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .accessibilityLabel("Stays at home \u{2014} never offered on trips")
                    .accessibilityIdentifier("thing-stays-home")
            }
        }
        .bCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("thing-details")
    }

    // MARK: Parts

    @ViewBuilder private var boughtOn: some View {
        if let date = Library.ymdDay(draft.acquired) {
            HStack(spacing: 6) {
                DatePicker("", selection: Binding(get: { date }, set: { draft.acquired = Library.ymd($0) }),
                           displayedComponents: .date)
                    .labelsHidden().tint(tint)
                    .accessibilityIdentifier("thing-bought-on")
                Spacer(minLength: 0)
                Button { draft.acquired = ""; draft.warranty = "" } label: {
                    SVGPath.path("M6 6L18 18M18 6L6 18").stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                        .onGrid(Metrics.glyph).foregroundStyle(Theme.muted).frame(width: Metrics.lineButton)
                }
                .buttonStyle(.plain).accessibilityLabel("Clear the bought date")
                .accessibilityIdentifier("thing-bought-on-clear")
            }
        } else {
            Button { draft.acquired = Today.local } label: {
                Text("Set date").font(.system(.body, weight: .semibold)).foregroundStyle(tint)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain).accessibilityIdentifier("thing-bought-on")
        }
    }

    private func warranty(today: String) -> some View {
        let lit = isYMD(draft.warranty) ? Library.warrantyYears(draft) : 0
        let complaint = Library.complaintRightUntil(draft)
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                ForEach([0] + WARRANTY_YEARS, id: \.self) { y in
                    Button {
                        draft.warranty = y == 0 ? "" : Library.warrantyEnd(bought: draft.acquired.isEmpty ? today : draft.acquired, years: y)
                        if y > 0, draft.acquired.isEmpty { draft.acquired = today }
                    } label: {
                        Text(y == 0 ? "None" : "\(y) y").font(.system(.subheadline, weight: .semibold))
                            .lineLimit(1).fixedSize()
                            .foregroundStyle(lit == y ? .white : tint)
                            .padding(.horizontal, 8).frame(minHeight: Metrics.chip)
                            .background(Capsule().fill(lit == y ? tint : tint.opacity(0.10)))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityLabel(y == 0 ? "No warranty" : "\(y) year warranty")
                    .accessibilityAddTraits(lit == y ? .isSelected : [])
                    .accessibilityIdentifier("thing-warranty-\(y)")
                }
            }
            if isYMD(draft.warranty) {
                Text("Until \(Library.dayWords(draft.warranty)) \u{00B7} \(Library.timeLeft(until: draft.warranty, today: today))")
                    .font(.system(.subheadline)).foregroundStyle(Theme.muted)
                    .accessibilityIdentifier("thing-warranty-says")
            } else if !complaint.isEmpty {
                Text("Complaint right until \(Library.dayWords(complaint))")
                    .font(.system(.subheadline)).foregroundStyle(Theme.muted)
                    .accessibilityIdentifier("thing-complaint")
            }
        }
        .padding(.vertical, 4)
    }

    private func line<Content: View>(_ label: String, last: Bool = false, @ViewBuilder _ content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text(label).font(.system(.body)).foregroundStyle(Theme.ink)
                .lineLimit(1).minimumScaleFactor(0.8)
                .frame(width: 112, alignment: .leading)
            content().frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12).frame(minHeight: Metrics.tap)
        .overlay(alignment: .bottom) { if !last { Theme.line.frame(height: 1).padding(.leading, 12) } }
    }

    private func text(_ binding: Binding<String>, _ prompt: String, _ id: String) -> some View {
        TextField(prompt, text: binding)
            .textFieldStyle(.plain).font(.system(.body)).foregroundStyle(Theme.ink)
            .accessibilityIdentifier(id)
    }

    private func chips(_ words: [String], id: String, pick: @escaping (String) -> Void) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(words.enumerated()), id: \.offset) { n, w in
                    Button { pick(w) } label: {
                        Text(w).font(.system(.subheadline, weight: .semibold)).lineLimit(1)
                            .foregroundStyle(tint)
                            .padding(.horizontal, 10).frame(minHeight: Metrics.chip)
                            .background(Capsule().fill(tint.opacity(0.10)))
                            .overlay(Capsule().stroke(tint, lineWidth: 1))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("\(id)-\(n)")
                }
            }
        }
        .padding(.bottom, 4)
    }
}

/// Spot inside the room (0.115): typed, with spots used before in that room as chips.
struct ThingSpotField: View {
    @EnvironmentObject var model: LibraryModel
    @Binding var draft: Item

    var body: some View {
        let tint = AppSection.care.color
        let spot = Library.spot(draft)
        let found = jsTrim(draft.storage).isEmpty ? [] : model.library.spotSuggestions(room: draft.storage, typed: spot)
        VStack(alignment: .leading, spacing: 4) {
            TextField("Spot, e.g. Top shelf", text: Binding(get: { spot }, set: { Library.setSpot(&draft, $0) }))
                .textFieldStyle(.plain).font(.system(.body)).foregroundStyle(Theme.ink)
                .padding(.horizontal, 12).frame(minHeight: Metrics.tap)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                .accessibilityIdentifier("thing-spot")
            if !found.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(found.enumerated()), id: \.offset) { n, w in
                            Button { Library.setSpot(&draft, w) } label: {
                                Text(w).font(.system(.subheadline, weight: .semibold)).lineLimit(1)
                                    .foregroundStyle(tint)
                                    .padding(.horizontal, 10).frame(minHeight: Metrics.chip)
                                    .background(Capsule().fill(tint.opacity(0.10)))
                                    .overlay(Capsule().stroke(tint, lineWidth: 1))
                                    .contentShape(Capsule())
                            }
                            .buttonStyle(.plain).focusEffectDisabled()
                            .accessibilityIdentifier("thing-spot-suggest-\(n)")
                        }
                    }
                }
            }
        }
    }
}
