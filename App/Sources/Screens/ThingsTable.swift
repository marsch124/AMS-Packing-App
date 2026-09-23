import SwiftUI
import PackingCore
import PackingLibrary

/// Every thing as a row: name, what it weighs, where it lives — filled in on the
/// spot. The web app's "All items · table", and the answer to the two gaps the
/// Care dashboard names (things with no weight, things with no place): fixing
/// them one editor at a time is what stops him doing it at all.
struct ThingsTable: View {
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    /// "" = everything; otherwise only the things missing that.
    @State private var only = ""
    @State private var query = ""

    private static let filters: [(id: String, label: String)] =
        [("", "All"), ("weight", "No weight"), ("place", "No place")]

    var body: some View {
        let rows = things()
        VStack(spacing: 0) {
            HStack {
                Text("All your things").font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(AppSection.care.color)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .font(.system(size: 17, weight: .bold)).foregroundStyle(AppSection.care.color)
                    .accessibilityIdentifier("table-done")
            }
            .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 8)

            HStack(spacing: 8) {
                TextField("Search", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16, weight: .medium)).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 12).frame(minHeight: 38)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                    .accessibilityIdentifier("table-search")
            }
            .padding(.horizontal, 16)

            HStack(spacing: 6) {
                ForEach(ThingsTable.filters, id: \.id) { filter in
                    Button { only = filter.id } label: {
                        Text(filter.label)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(only == filter.id ? .white : Theme.muted)
                            .padding(.horizontal, 12).frame(minHeight: 32)
                            .background(Capsule().fill(only == filter.id ? AppSection.care.color : Theme.card))
                            .overlay(Capsule().stroke(Theme.line, lineWidth: only == filter.id ? 0 : 1))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("table-filter-\(filter.id.isEmpty ? "all" : filter.id)")
                    .accessibilityAddTraits(only == filter.id ? .isSelected : [])
                }
                Spacer()
                Text("\(rows.count)")
                    .font(.system(size: 15, weight: .heavy).monospacedDigit()).foregroundStyle(Theme.muted)
                    .accessibilityIdentifier("table-count")
            }
            .padding(.horizontal, 16).padding(.vertical, 8)

            KeyboardAwayScroll {
                LazyVStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { n, thing in
                        Row(thing: thing, n: n) { grams, place in
                            model.change {
                                _ = $0.updateThing(id: thing.id) { it in
                                    if let grams { it.weight = grams }
                                    if let place { it.storage = place }
                                }
                            }
                        }
                        .environmentObject(model)
                    }
                    if rows.isEmpty {
                        Text(only.isEmpty ? "Nothing matches." : "Nothing missing that — all filled in.")
                            .font(.system(size: 16, weight: .medium)).foregroundStyle(Theme.muted)
                            .padding(.top, 30)
                            .accessibilityIdentifier("table-none")
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("table-detail")
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 560)
        #endif
    }

    private func things() -> [Item] {
        let needle = normName(query)
        return model.library.items.filter { thing in
            if !needle.isEmpty, !normName(thing.name).contains(needle) { return false }
            switch only {
            case "weight": return thing.weight <= 0
            case "place": return jsTrim(thing.storage).isEmpty
            default: return true
            }
        }.sorted { normName($0.name) < normName($1.name) }
    }

    /// One thing: its name, a box for grams, and its place chosen from his own list.
    private struct Row: View {
        let thing: Item
        let n: Int
        let change: (Double?, String?) -> Void
        @EnvironmentObject var model: LibraryModel
        @State private var grams = ""

        var body: some View {
            HStack(spacing: 8) {
                Text(thing.name)
                    .font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("table-\(n)-name")

                TextField("g", text: $grams)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15, weight: .semibold).monospacedDigit())
                    .foregroundStyle(thing.weight > 0 ? Theme.ink : Theme.muted)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 62, height: 34)
                    .padding(.horizontal, 6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 8)
                        .stroke(thing.weight > 0 ? Theme.line : AppSection.care.color.opacity(0.5), lineWidth: 1))
                    .onSubmit { commitWeight() }
                    .accessibilityIdentifier("table-\(n)-grams")

                Menu {
                    ForEach(model.library.storagePlaces(), id: \.self) { place in
                        Button(place) { change(nil, place) }
                    }
                    Button("Nowhere") { change(nil, "") }
                } label: {
                    Text(jsTrim(thing.storage).isEmpty ? "Where?" : thing.storage)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(jsTrim(thing.storage).isEmpty ? AppSection.care.color : Theme.muted)
                        .lineLimit(1)
                        .frame(width: 104, height: 34)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.card))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 1))
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .accessibilityIdentifier("table-\(n)-place")
                .accessibilityLabel("Where \(thing.name) lives")
            }
            .padding(.vertical, 5)
            .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
            .onAppear { grams = thing.weight > 0 ? String(Int(thing.weight.rounded())) : "" }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("table-row-\(n)")
        }

        private func commitWeight() {
            let clean = jsTrim(grams).replacingOccurrences(of: ",", with: ".")
            guard let value = Double(clean), value >= 0 else { return }
            change(value, nil)
        }
    }
}
