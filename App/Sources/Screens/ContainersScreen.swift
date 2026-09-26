import SwiftUI
import PackingCore
import PackingLibrary

/// His bags, and the three numbers each one has: what it may carry, its size, and
/// what it weighs empty. A bag given a max weight here shows how full it is on
/// every trip it goes on.
///
/// The name is not editable here, on purpose: things are packed into a bag by its
/// NAME, so renaming it would leave everything in it bag-less (see Containers.swift).
struct ContainersScreen: View {
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    @State private var newName = ""
    /// The bag whose own page is open.
    @State private var openBag: OpenBag?
    struct OpenBag: Identifiable { let id: String }

    var body: some View {
        let bags = model.library.bags()
        VStack(spacing: 0) {
            HStack {
                Text("Your bags").font(.system(size: 22, weight: .heavy)).foregroundStyle(AppSection.care.color)
                Text("\(bags.count)").font(.system(size: 15, weight: .heavy).monospacedDigit())
                    .foregroundStyle(Theme.muted)
                    .accessibilityIdentifier("containers-count")
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .font(.system(size: 17, weight: .bold)).foregroundStyle(AppSection.care.color)
                    .accessibilityIdentifier("containers-done")
            }
            .padding(16)

            // The line and the column names stay put while the bags scroll under
            // them — his ask (2026-09-26): "keep the header row visible".
            VStack(alignment: .leading, spacing: 0) {
                Text("Give a bag its max weight and every trip shows how full it is.")
                    .font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 10)

                HStack(spacing: 6) {
                    Spacer()
                    Text("MAX KG").frame(width: 64)
                    Text("LITRES").frame(width: 64)
                    Text("EMPTY G").frame(width: 70)
                }
                .font(.system(size: 10, weight: .heavy)).foregroundStyle(Theme.muted).kerning(0.4)
                .padding(.bottom, 4)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("containers-columns")
            }
            .padding(.horizontal, 16)
            .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }

            KeyboardAwayScroll {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(bags.enumerated()), id: \.element.id) { n, bag in
                        BagRow(bag: bag, n: n, open: { openBag = OpenBag(id: bag.id) }).environmentObject(model)
                    }
                    if bags.isEmpty {
                        Text("No bags yet.").font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Theme.muted).padding(.vertical, 20)
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 16)
            }

            // Add at the BOTTOM — his rule.
            HStack(spacing: 8) {
                TextField("A new bag", text: $newName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 17, weight: .medium)).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 12).frame(minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                    .onSubmit { add() }
                    .accessibilityIdentifier("bag-new-name")
                Button { add() } label: {
                    Text("Add").font(.system(size: 16, weight: .bold))
                        .foregroundStyle(canAdd ? Color.white : Theme.muted)
                        .padding(.horizontal, 16).frame(minHeight: 44)
                        .background(RoundedRectangle(cornerRadius: 10)
                            .fill(canAdd ? AppSection.care.color : Theme.line))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .disabled(!canAdd)
                .accessibilityIdentifier("bag-new")
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
        .background(Theme.bg.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("containers-detail")
        .sheet(item: $openBag) { b in BagDetail(bagId: b.id).environmentObject(model) }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 560)
        #endif
    }

    private var canAdd: Bool {
        let wanted = normName(newName)
        return !wanted.isEmpty && !model.library.bags().contains { normName($0.name) == wanted }
    }

    private func add() {
        guard canAdd else { return }
        let name = newName
        model.change { _ = $0.addBag(name: name) }
        newName = ""
    }

    /// One bag: its name, and its three numbers, each changed where it stands.
    private struct BagRow: View {
        let bag: Item
        let n: Int
        /// Open the bag's own page (rename, delete, what it knows).
        let open: () -> Void
        @EnvironmentObject var model: LibraryModel
        @State private var maxKg = ""
        @State private var litres = ""
        @State private var empty = ""

        var body: some View {
            HStack(spacing: 6) {
                // The name opens the bag's page; under it, what it knows at a glance.
                let facts = model.library.bagFacts(name: bag.name)
                let line = BagRow.glance(facts)
                Button(action: open) {
                    HStack(spacing: 4) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(bag.name)
                                .font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink)
                                .lineLimit(1).minimumScaleFactor(0.8)
                            if !line.isEmpty {
                                Text(line).font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.muted)
                                    .lineLimit(1).minimumScaleFactor(0.85)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        SVGPath.path("M9 6l6 6-6 6").stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                            .frame(width: 12, height: 12).foregroundStyle(Theme.muted)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("bag-\(n)-name")
                .accessibilityValue(line)
                field($maxKg, now: bag.maxKg, width: 64, id: "bag-\(n)-maxkg") { v in
                    model.change { _ = $0.setBag(id: bag.id, maxKg: v) }
                }
                field($litres, now: bag.capacityL, width: 64, id: "bag-\(n)-litres") { v in
                    model.change { _ = $0.setBag(id: bag.id, capacityL: v) }
                }
                field($empty, now: bag.weight, width: 70, id: "bag-\(n)-empty") { v in
                    model.change { _ = $0.setBag(id: bag.id, emptyGrams: v) }
                }
            }
            .frame(minHeight: 46)
            .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
            .onAppear {
                maxKg = bag.maxKg > 0 ? ContainersScreen.show(bag.maxKg) : ""
                litres = bag.capacityL > 0 ? ContainersScreen.show(bag.capacityL) : ""
                empty = bag.weight > 0 ? String(Int(bag.weight.rounded())) : ""
            }
        }

        /// 🪤 Saved AS HE TYPES. It used to save only on Return, so numbers typed and
        /// left (Done, or a tap elsewhere) looked set and were lost — his max weights
        /// of 2026-09-26 morning (Swim bag 5, Duffel bag 20…) never reached the trips.
        /// "176 things · last trip 5.1 kg" — or less, when there is less to say.
        static func glance(_ facts: Library.BagFacts) -> String {
            var parts: [String] = []
            if !facts.things.isEmpty { parts.append("\(facts.things.count) thing\(facts.things.count == 1 ? "" : "s")") }
            if let last = facts.trips.first { parts.append("last trip \(BagsCard.kilos(last.grams))") }
            return parts.joined(separator: " · ")
        }

        private func field(_ text: Binding<String>, now: Double, width: CGFloat, id: String,
                           commit: @escaping (Double) -> Void) -> some View {
            TextField("", text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .semibold).monospacedDigit()).foregroundStyle(Theme.ink)
                .multilineTextAlignment(.trailing)
                .padding(.horizontal, 6)
                .frame(width: width, height: 34)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 1))
                .onChange(of: text.wrappedValue) { _, typed in
                    let clean = jsTrim(typed).replacingOccurrences(of: ",", with: ".")
                    let value = clean.isEmpty ? 0 : (Double(clean) ?? now)
                    if value != now { commit(value) }
                }
                .accessibilityIdentifier(id)
        }
    }

    static func show(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
    }
}
