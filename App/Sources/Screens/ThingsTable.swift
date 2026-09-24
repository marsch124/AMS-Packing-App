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
    /// The things he has ticked, by id.
    @State private var chosen: Set<String> = []
    @State private var changing = false
    /// What the things looked like before the last change to many at once, and what
    /// that change was — so one press puts them all back.
    @State private var wasBefore: [Item] = []
    @State private var didSay = ""
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
        let answers = TableColumns.Answers2(model.library)
        let rows = things()
        VStack(spacing: 0) {
            top(rows.count)
            if !chosen.isEmpty || !wasBefore.isEmpty { chosenBar(rows) }
            Divider()
            // 🪤 The width is spelled out. A scroll view that goes BOTH ways asks its
            // content how wide it is, and a lazy stack answers that by building every
            // row — all 431 of them, with every cell — which is laziness undone: two
            // UI tests went from ~20 seconds to ~150. Given the width, it builds only
            // the rows on screen.
            let gridWidth = nameWidth + columns.reduce(0) { $0 + $1.width }
            ScrollView([.horizontal, .vertical]) {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { n, thing in
                            Row(thing: thing, n: n, columns: columns, answers: answers,
                                nameWidth: nameWidth, across: across,
                                ticked: chosen.contains(thing.id),
                                pick: { on in
                                    if on { chosen.insert(thing.id) } else { chosen.remove(thing.id) }
                                })
                                .environmentObject(model)
                        }
                    } header: {
                        heading(columns, rows)
                    }
                }
                .frame(width: gridWidth, alignment: .leading)
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
        .sheet(isPresented: $changing) {
            BulkChange(things: model.library.items.filter { chosen.contains($0.id) },
                       answers: TableColumns.Answers2(model.library)) { what, said in
                changeThemAll(what, said)
            }
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
    private func heading(_ columns: [TableColumns.Column], _ rowsNow: [Item]) -> some View {
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
                // Narrow with a chip, then take the lot: the whole reason the chips
                // and the ticks are on the same screen.
                Button {
                    let shown = Set(rowsNow.map(\.id))
                    if shown.isSubset(of: chosen) { chosen.subtract(shown) } else { chosen.formUnion(shown) }
                } label: {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.clear)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.muted, lineWidth: 1.5))
                        .overlay {
                            Rectangle().fill(Theme.muted).frame(width: 9, height: 2)
                        }
                        .frame(width: 18, height: 18)
                        .frame(width: 30, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .padding(.leading, 6)
                .accessibilityIdentifier("table-pick-all")
                .accessibilityLabel("Tick everything shown")

                Button { turn("name") } label: {
                    HStack(spacing: 4) {
                        Text("Thing").font(.system(size: 12, weight: .heavy)).foregroundStyle(Theme.muted)
                        if sortBy == "name" {
                            Text(descending ? "▼" : "▲").font(.system(size: 9, weight: .black))
                                .foregroundStyle(AppSection.care.color)
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(width: nameWidth - 36, height: 26, alignment: .leading)
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

    /// While anything is ticked: how many, one press to change them all, and — after
    /// a change — one press to put them back the way they were.
    private func chosenBar(_ rows: [Item]) -> some View {
        HStack(spacing: 8) {
            if !chosen.isEmpty {
                Text("\(chosen.count) ticked")
                    .font(.system(size: 15, weight: .heavy).monospacedDigit())
                    .foregroundStyle(AppSection.care.color)
                    .accessibilityIdentifier("table-chosen-count")

                Button { changing = true } label: {
                    Text("Change all")
                        .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 12).frame(minHeight: 32)
                        .background(Capsule().fill(AppSection.care.color))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("table-change-all")

                Button { chosen.removeAll() } label: {
                    Text("Clear").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.muted)
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("table-clear-chosen")
            }
            Spacer()
            if !wasBefore.isEmpty {
                Text(didSay).font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.muted)
                    .lineLimit(1)
                    .accessibilityIdentifier("table-said")
                    .accessibilityLabel(didSay)
                Button { putBack() } label: {
                    Text("Undo")
                        .font(.system(size: 14, weight: .bold)).foregroundStyle(AppSection.actions.color)
                        .padding(.horizontal, 10).frame(minHeight: 32)
                        .overlay(Capsule().stroke(AppSection.actions.color, lineWidth: 1))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("table-undo")
            }
        }
        .padding(.horizontal, 16).padding(.bottom, 8)
    }

    /// Change every ticked thing, keeping what they were first.
    private func changeThemAll(_ what: @escaping (inout Item) -> Void, _ said: String) {
        let ids = chosen
        wasBefore = model.library.items.filter { ids.contains($0.id) }
        didSay = "\(ids.count) changed"
        model.change { library in
            for id in ids { _ = library.updateThing(id: id) { thing in what(&thing) } }
        }
    }

    /// Put every one of them back exactly as it was.
    private func putBack() {
        let old = wasBefore
        guard !old.isEmpty else { return }
        model.change { library in
            for thing in old { _ = library.updateThing(id: thing.id) { $0 = thing } }
        }
        wasBefore = []
        didSay = ""
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
        let answers: TableColumns.Answers2
        let nameWidth: CGFloat
        let across: CGFloat
        let ticked: Bool
        let pick: (Bool) -> Void
        @EnvironmentObject var model: LibraryModel

        var body: some View {
            HStack(spacing: 0) {
                // Nailed to the left edge by travelling back exactly as far as the
                // grid has travelled forward. It must be opaque: the columns pass
                // underneath it.
                HStack(spacing: 8) {
                    Button { pick(!ticked) } label: {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(ticked ? AppSection.care.color : Color.clear)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(ticked ? AppSection.care.color : Theme.line, lineWidth: 1.5))
                            .overlay {
                                if ticked {
                                    SVGPath.path("M5 13l4 4L19 7")
                                        .stroke(style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                                        .frame(width: 14, height: 14).foregroundStyle(.white)
                                }
                            }
                            .frame(width: 18, height: 18)
                            .frame(width: 30, height: TableColumns.rowHeight)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("table-\(n)-pick")
                    .accessibilityAddTraits(ticked ? .isSelected : [])

                    Text(thing.name)
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.ink)
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("table-\(n)-name")
                }
                .padding(.leading, 6)
                .frame(width: nameWidth, height: TableColumns.rowHeight, alignment: .leading)
                .background(n.isMultiple(of: 2) ? Theme.bg : Theme.card)
                .overlay(alignment: .trailing) { Theme.line.frame(width: 1) }
                .offset(x: across)
                .zIndex(2)

                ForEach(columns) { column in
                    Cell(thing: thing, n: n, column: column, answers: answers)
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
