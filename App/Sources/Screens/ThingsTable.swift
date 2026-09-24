import SwiftUI
import PackingCore
import PackingLibrary

/// All his things as a SPREADSHEET, the way the web app's "All items · table"
/// works and the way he asked for it: the name column stays put while the rest
/// travels sideways, the heading stays put while the rows travel down, every cell
/// is changed where it stands, and he says which columns he sees, in which order,
/// sorted by whichever one he likes.
///
/// (The first attempt was three fixed columns in a list. His words: "It is not at
/// all what it should be. You should be able to quickly update items — like Excel.")
///
/// How it holds together: ONE scroll view that goes both ways, holding a lazy
/// stack whose section header is the heading — so the heading pins itself as the
/// rows go down and travels sideways with its columns for nothing. The name cell
/// of each row counter-scrolls by however far the grid has travelled, which makes
/// it look nailed to the left edge while only the rows on screen ever redraw.
///
/// 🪤 The first build kept the names in a column of their own and moved it with
/// the scroll offset. It looked right and was a trap: every one of his 431 name
/// rows was laid out again on every scroll tick, so on a slower machine the app
/// never went idle — GitHub's runner sat in "Wait for AMSPacking to idle" until
/// the tap timed out. Counter-scrolling only the visible rows costs nothing.
struct ThingsTable: View {
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss

    /// The columns he has chosen, in his order, as ids. Empty = the sensible start.
    @AppStorage("ams.table.columns") private var chosenColumns = ""
    @AppStorage("ams.table.sort") private var sortBy = "name"
    @AppStorage("ams.table.down") private var descending = false
    @State private var query = ""
    /// "" = everything; otherwise only the things missing that.
    @State private var only = ""
    @State private var picking = false
    /// How far the grid has travelled sideways, so the name cells can travel back.
    @State private var across: CGFloat = 0

    private static let filters: [(id: String, label: String)] =
        [("", "All"), ("weight", "No weight"), ("place", "No place")]

    private var nameWidth: CGFloat {
        #if os(macOS)
        return 210
        #else
        return 148
        #endif
    }
    private var headHeight: CGFloat { 46 }

    var body: some View {
        let columns = TableColumns.chosen(chosenColumns, library: model.library)
        let rows = things()
        VStack(spacing: 0) {
            top(rows.count)
            Divider()
            ScrollView([.horizontal, .vertical]) {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { n, thing in
                            Row(thing: thing, n: n, columns: columns,
                                nameWidth: nameWidth, across: across)
                                .environmentObject(model)
                        }
                    } header: {
                        heading(columns)
                    }
                }
            }
            .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.x } action: { _, x in
                across = max(0, x)
            }
            if rows.isEmpty {
                Text(only.isEmpty ? "Nothing matches." : "Nothing missing that — all filled in.")
                    .font(.system(size: 16, weight: .medium)).foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity).padding(.top, 30)
                    .accessibilityIdentifier("table-none")
                Spacer()
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .sheet(isPresented: $picking) {
            ColumnPicker(chosen: $chosenColumns, library: model.library)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("table-detail")
        #if os(macOS)
        .frame(minWidth: 760, minHeight: 560)
        #endif
    }

    /// The heading: the band saying which group a run of columns belongs to, then
    /// the column names. It pins itself to the top, and its own name cell stays at
    /// the left the same way a row's does.
    private func heading(_ columns: [TableColumns.Column]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Color.clear.frame(width: nameWidth, height: 20)
                ForEach(TableColumns.bands(columns)) { band in
                    // The title holds still inside its own run of columns instead of
                    // sliding away, so it still says which group you are looking at.
                    Text(band.title)
                        .font(.system(size: 11, weight: .heavy)).foregroundStyle(AppSection.care.color)
                        .kerning(0.4).lineLimit(1)
                        .padding(.horizontal, 7)
                        .frame(width: band.width, height: 20, alignment: .leading)
                        .offset(x: min(max(0, across - band.start), max(0, band.width - 130)))
                        .accessibilityIdentifier("table-band-\(band.id)")
                }
            }
            HStack(spacing: 0) {
                Button { turn("name") } label: {
                    HStack(spacing: 4) {
                        Text("Thing").font(.system(size: 12, weight: .heavy)).foregroundStyle(Theme.muted)
                        if sortBy == "name" {
                            Text(descending ? "▼" : "▲").font(.system(size: 9, weight: .black))
                                .foregroundStyle(AppSection.care.color)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.leading, 12)
                    .frame(width: nameWidth, height: 26, alignment: .leading)
                    .background(Theme.bg)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .offset(x: across).zIndex(2)
                .accessibilityIdentifier("table-head-name")

                ForEach(columns) { column in
                    Button { turn(column.id) } label: {
                        HStack(spacing: 3) {
                            Text(column.title)
                                .font(.system(size: 12, weight: .heavy)).foregroundStyle(Theme.muted)
                                .lineLimit(1).minimumScaleFactor(0.7)
                            if sortBy == column.id {
                                Text(descending ? "▼" : "▲").font(.system(size: 9, weight: .black))
                                    .foregroundStyle(AppSection.care.color)
                            }
                        }
                        .padding(.horizontal, 6)
                        .frame(width: column.width, height: 26, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .overlay(alignment: .trailing) { Theme.line.frame(width: 1) }
                    .accessibilityIdentifier("table-head-\(column.id)")
                }
            }
            Rectangle().fill(Theme.line).frame(height: 1)
        }
        .background(Theme.bg)
    }

    /// Pressing a heading sorts by it; pressing the same one again turns it over.
    private func turn(_ key: String) {
        if sortBy == key { descending.toggle() } else { sortBy = key; descending = false }
    }

    // MARK: - the band above the grid

    private func top(_ count: Int) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text("All your things").font(.system(size: 21, weight: .heavy))
                    .foregroundStyle(AppSection.care.color)
                Text("\(count)")
                    .font(.system(size: 15, weight: .heavy).monospacedDigit()).foregroundStyle(Theme.muted)
                    .accessibilityIdentifier("table-count")
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .font(.system(size: 17, weight: .bold)).foregroundStyle(AppSection.care.color)
                    .accessibilityIdentifier("table-done")
            }

            HStack(spacing: 8) {
                TextField("Search", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 10).frame(minHeight: 34)
                    .background(RoundedRectangle(cornerRadius: 9).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.line, lineWidth: 1))
                    .accessibilityIdentifier("table-search")

                Menu {
                    Button("Name") { sortBy = "name"; descending = false }
                    ForEach(TableColumns.chosen(chosenColumns, library: model.library)) { column in
                        Button(column.title) { sortBy = column.id; descending = false }
                    }
                } label: {
                    chip("Sort: " + TableColumns.sortName(sortBy, model.library))
                }
                .menuStyle(.borderlessButton)
                .accessibilityIdentifier("table-sort")

                Button { descending.toggle() } label: { chip(descending ? "▼" : "▲") }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("table-direction")

                Button { picking = true } label: { chip("Columns") }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("table-columns")
            }

            HStack(spacing: 6) {
                ForEach(ThingsTable.filters, id: \.id) { filter in
                    Button { only = filter.id } label: {
                        Text(filter.label)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(only == filter.id ? .white : Theme.muted)
                            .padding(.horizontal, 12).frame(minHeight: 30)
                            .background(Capsule().fill(only == filter.id ? AppSection.care.color : Theme.card))
                            .overlay(Capsule().stroke(Theme.line, lineWidth: only == filter.id ? 0 : 1))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("table-filter-\(filter.id.isEmpty ? "all" : filter.id)")
                    .accessibilityAddTraits(only == filter.id ? .isSelected : [])
                }
                Spacer()
            }
        }
        .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 8)
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.ink)
            .lineLimit(1)
            .padding(.horizontal, 10).frame(minHeight: 34)
            .background(RoundedRectangle(cornerRadius: 9).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.line, lineWidth: 1))
            .contentShape(Rectangle())
    }

    // MARK: - which rows, in which order

    private func things() -> [Item] {
        let needle = normName(query)
        let kept = model.library.items.filter { thing in
            if !needle.isEmpty, !normName(thing.name).contains(needle) { return false }
            switch only {
            case "weight": return thing.weight <= 0
            case "place": return jsTrim(thing.storage).isEmpty
            default: return true
            }
        }
        let library = model.library
        let sorted = kept.sorted { a, b in
            let left = TableColumns.sortValue(a, key: sortBy, library: library)
            let right = TableColumns.sortValue(b, key: sortBy, library: library)
            if left == right { return normName(a.name) < normName(b.name) }
            return left < right
        }
        return descending ? sorted.reversed() : sorted
    }

    // MARK: - one row

    private struct Row: View {
        let thing: Item
        let n: Int
        let columns: [TableColumns.Column]
        let nameWidth: CGFloat
        let across: CGFloat
        @EnvironmentObject var model: LibraryModel

        var body: some View {
            HStack(spacing: 0) {
                // Nailed to the left edge by travelling back exactly as far as the
                // grid has travelled forward. It must be opaque: the columns pass
                // underneath it.
                Text(thing.name)
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.ink)
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .padding(.leading, 12)
                    .frame(width: nameWidth, height: TableColumns.rowHeight, alignment: .leading)
                    .background(n.isMultiple(of: 2) ? Theme.bg : Theme.card)
                    .overlay(alignment: .trailing) { Theme.line.frame(width: 1) }
                    .offset(x: across)
                    .zIndex(2)
                    .accessibilityIdentifier("table-\(n)-name")

                ForEach(columns) { column in
                    Cell(thing: thing, n: n, column: column)
                        .environmentObject(model)
                }
            }
            .frame(height: TableColumns.rowHeight)
            .background(n.isMultiple(of: 2) ? Color.clear : Theme.card.opacity(0.55))
            .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("table-row-\(n)")
        }
    }
}
