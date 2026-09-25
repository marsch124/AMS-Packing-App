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

            KeyboardAwayScroll {
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

                    ForEach(Array(bags.enumerated()), id: \.element.id) { n, bag in
                        BagRow(bag: bag, n: n).environmentObject(model)
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
        @EnvironmentObject var model: LibraryModel
        @State private var maxKg = ""
        @State private var litres = ""
        @State private var empty = ""

        var body: some View {
            HStack(spacing: 6) {
                Text(bag.name)
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink)
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("bag-\(n)-name")
                field($maxKg, width: 64, id: "bag-\(n)-maxkg") { v in
                    model.change { _ = $0.setBag(id: bag.id, maxKg: v) }
                }
                field($litres, width: 64, id: "bag-\(n)-litres") { v in
                    model.change { _ = $0.setBag(id: bag.id, capacityL: v) }
                }
                field($empty, width: 70, id: "bag-\(n)-empty") { v in
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

        private func field(_ text: Binding<String>, width: CGFloat, id: String,
                           commit: @escaping (Double) -> Void) -> some View {
            TextField("", text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .semibold).monospacedDigit()).foregroundStyle(Theme.ink)
                .multilineTextAlignment(.trailing)
                .padding(.horizontal, 6)
                .frame(width: width, height: 34)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 1))
                .onSubmit {
                    let clean = jsTrim(text.wrappedValue).replacingOccurrences(of: ",", with: ".")
                    commit(clean.isEmpty ? 0 : (Double(clean) ?? 0))
                }
                .accessibilityIdentifier(id)
        }
    }

    static func show(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
    }
}
