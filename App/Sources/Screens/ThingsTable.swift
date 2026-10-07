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
    #if os(macOS)
    @Environment(\.dismissWindow) private var dismissWindow
    #endif
    /// On the Mac the table is a window of its own (his ask, 4 Oct 2026: "I would
    /// like it wider in order to see more columns"), so Done closes the window.
    var inWindow = false
    static let windowId = "things-table"

    /// The columns he has chosen, in his order, as ids. Empty = the sensible start.
    @AppStorage("ams.table.columns") private var chosenColumns = ""
    /// His own column widths, "id=points;…" (0.66, `TableColumns.widths`).
    @AppStorage("ams.table.widths") private var widthsStored = ""
    /// A column whose line is being dragged: drawn at `width` while the drag lasts,
    /// and kept only when it ends — one write, not one per point moved.
    private struct Resize: Equatable { let id: String; let start: CGFloat; var width: CGFloat }
    @State private var resizing: Resize?
    @AppStorage("ams.table.sort") private var sortBy = "name"
    @AppStorage("ams.table.down") private var descending = false
    /// The sort levels under the first ("then by"), and the column filters — kept
    /// while he works, and shown above the grid whenever any is on.
    @AppStorage("ams.table.then") private var thenStored = ""
    @AppStorage("ams.table.filters") private var filtersStored = ""
    @State private var filtering = false
    @State private var sorting = false
    /// The thing opened from its row (his ask, 4 Oct 2026): its own page on top of
    /// the table, and back to the very same spot when it closes — the table is not
    /// rebuilt underneath, so it stays scrolled where it was.
    @State private var opening: String?
    private struct Opening: Identifiable { let id: String }
    @State private var query = ""
    /// "" = everything; otherwise only the things missing that.
    @State private var only = ""
    @State private var picking = false
    /// The things he has ticked, by id.
    @State private var chosen: Set<String> = []
    @State private var changing = false
    /// What the things looked like before the last change to many at once, as that
    /// change left them, and what it was — so one press puts back exactly that.
    @State private var wasBefore: [Item] = []
    @State private var madeAs: [Item] = []
    @State private var didSay = ""
    /// How far the grid has travelled sideways, so the name cells can travel back.
    @State private var across: CGFloat = 0

    private static let filters: [(id: String, label: String)] =
        [("", "All"), ("weight", "No weight"), ("place", "No place")]

    private var startingNameWidth: CGFloat {
        #if os(macOS)
        return 210
        #else
        return 172      // 148 before each row had its open arrow (0.58)
        #endif
    }

    private var nameWidth: CGFloat {
        if let r = resizing, r.id == "name" { return r.width }
        return TableColumns.widths(widthsStored)["name"].map { TableColumns.clamp($0, name: true) } ?? startingNameWidth
    }

    /// His chosen columns at the widths he gave them — the one being dragged at its
    /// width of the moment.
    private func sized(_ columns: [TableColumns.Column]) -> [TableColumns.Column] {
        let widths = TableColumns.widths(widthsStored)
        return columns.map { column in
            var column = column
            if let r = resizing, r.id == column.id { column.width = r.width }
            else if let w = widths[column.id] { column.width = TableColumns.clamp(w) }
            return column
        }
    }

    /// The line at a heading's right edge: drag it to make the column wider or narrower
    /// (the rows follow as it moves); a double tap puts back the column's own width.
    /// Its touch area is 14 wide, inside the column, so the next heading keeps its own.
    private func resizeLine(_ id: String, title: String, width: CGFloat) -> some View {
        let name = id == "name"
        return Color.clear
            .frame(width: 14, height: 26)
            .overlay(alignment: .trailing) {
                Capsule().fill(resizing?.id == id ? AppSection.care.color : Theme.muted.opacity(0.45))
                    .frame(width: 2, height: 12)
                    .padding(.trailing, 3)
            }
            .contentShape(Rectangle())
            #if os(macOS)
            .pointerStyle(.columnResize)
            #endif
            .highPriorityGesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { drag in
                        if resizing?.id != id { resizing = Resize(id: id, start: width, width: width) }
                        resizing?.width = TableColumns.clamp((resizing?.start ?? width) + drag.translation.width, name: name)
                    }
                    .onEnded { _ in
                        guard let r = resizing, r.id == id else { return }
                        var widths = TableColumns.widths(widthsStored)
                        widths[id] = r.width
                        widthsStored = TableColumns.store(widths)
                        resizing = nil
                    }
            )
            .onTapGesture(count: 2) {
                var widths = TableColumns.widths(widthsStored)
                widths[id] = nil
                widthsStored = TableColumns.store(widths)
            }
            .accessibilityElement()
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("Width of \(title)")
            .accessibilityIdentifier("table-resize-\(id)")
            .help("Drag to make \(title) wider or narrower; double-click for its own width")
    }

    var body: some View {
        let columns = sized(TableColumns.chosen(chosenColumns, library: model.library))
        let answers = TableColumns.Answers2(model.library)
        let rows = things()
        let filters = TableKeys.filters(filtersStored, model.library)
        VStack(spacing: 0) {
            top(rows.count, filters)
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
                                },
                                open: { opening = thing.id })
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
            // A scroll view that scrolls both ways centres a grid shorter than itself: with
            // a few things the table floated in the middle of the window (0.65). It starts
            // at the top left, under the tools.
            .defaultScrollAnchor(.topLeading)
            if rows.isEmpty {
                Text(!filters.isEmpty ? "Nothing matches these filters." : only.isEmpty ? "Nothing matches." : "Nothing missing that — all filled in.")
                    .font(.system(.callout)).foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity).padding(.top, 30)
                    .accessibilityIdentifier("table-none")
                Spacer()
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .sheet(isPresented: $picking) {
            ColumnPicker(chosen: $chosenColumns, library: model.library)
        }
        .sheet(item: Binding(get: { opening.map { Opening(id: $0) } }, set: { opening = $0?.id })) { o in
            ThingEditor(itemId: o.id).environmentObject(model)
        }
        .sheet(isPresented: $filtering) {
            FilterSheet(stored: $filtersStored, base: unfiltered()).environmentObject(model)
        }
        .sheet(isPresented: $sorting) {
            SortSheet(sortBy: $sortBy, descending: $descending, thenStored: $thenStored).environmentObject(model)
        }
        .sheet(isPresented: $changing) {
            BulkChange(things: model.library.items.filter { chosen.contains($0.id) },
                       answers: TableColumns.Answers2(model.library)) { what, said in
                changeThemAll(what, said)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("table-detail")
        // A template deleted since (here, or on his other device) takes its filter
        // and its sort level with it.
        .onAppear { forgetWhatIsGone() }
        .onChange(of: model.library.templates.map(\.id)) { _, _ in forgetWhatIsGone() }
        #if os(macOS)
        .frame(minWidth: 760, minHeight: 560)
        #endif
    }

    /// Filters and sort levels naming a template that is gone are dropped from
    /// what is kept: a filter for a deleted template went on filtering with no pill
    /// to say so ("Nothing matches these filters." until Clear), and its sort level
    /// sorted nothing under its raw key (the spec pass, 5 Oct 2026).
    private func forgetWhatIsGone() {
        let library = model.library
        let live = TableKeys.store(TableKeys.filters(filtersStored, library))
        if live != filtersStored { filtersStored = live }
        if !library.tableKnows(sortBy) { sortBy = "name"; descending = false }
        let then = TableKeys.levels(thenStored).filter { library.tableKnows($0.key) }
        let kept = TableKeys.store(then)
        if kept != thenStored { thenStored = kept }
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
                        .font(.system(.caption2, weight: .semibold)).foregroundStyle(AppSection.care.color)
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
                        Text("Thing").font(.system(.caption, weight: .semibold)).foregroundStyle(Theme.muted)
                        if sortBy == "name" {
                            Text(descending ? "▼" : "▲").font(.system(.caption2, weight: .semibold))
                                .foregroundStyle(AppSection.care.color)
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(width: nameWidth - 36, height: 26, alignment: .leading)
                    .background(Theme.bg)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("table-head-name")
                .overlay(alignment: .trailing) { resizeLine("name", title: "Thing", width: nameWidth) }
                .offset(x: across).zIndex(2)

                ForEach(columns) { column in
                    Button { turn(column.id) } label: {
                        HStack(spacing: 3) {
                            Text(column.title)
                                .font(.system(.caption, weight: .semibold)).foregroundStyle(Theme.muted)
                                .lineLimit(1).minimumScaleFactor(0.7)
                            if sortBy == column.id {
                                Text(descending ? "▼" : "▲").font(.system(.caption2, weight: .semibold))
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
                    .overlay(alignment: .trailing) { resizeLine(column.id, title: column.title, width: column.width) }
                }
            }
            Rectangle().fill(Theme.line).frame(height: 1)
        }
        .background(Theme.bg)
    }

    /// While anything is ticked: how many, one press to change them all, and — after
    /// a change — one press to put them back the way they were.
    private func chosenBar(_ rows: [Item]) -> some View {
        // Ticks stay while he searches and filters ("narrow with a chip, then take the
        // lot"), so Change all can reach things not on screen — the bar says how many
        // (the spec pass, 5 Oct 2026), rather than dropping ticks he made on purpose.
        let hidden = chosen.subtracting(rows.map(\.id)).count
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                if !chosen.isEmpty {
                    Text(hidden > 0 ? "\(chosen.count) ticked · \(hidden) not shown" : "\(chosen.count) ticked")
                        .font(.system(.subheadline, weight: .semibold).monospacedDigit())
                        .foregroundStyle(AppSection.care.color)
                        .accessibilityIdentifier("table-chosen-count")

                    Button { changing = true } label: {
                        Text("Change all")
                            .font(.system(.footnote, weight: .semibold)).foregroundStyle(.white)
                            .padding(.horizontal, 12).frame(minHeight: 32)
                            .background(Capsule().fill(AppSection.care.color))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("table-change-all")

                    Button { chosen.removeAll() } label: {
                        Text("Clear").font(.system(.footnote, weight: .semibold)).foregroundStyle(Theme.muted)
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("table-clear-chosen")
                }
                Spacer()
                if !wasBefore.isEmpty {
                    Button { putBack() } label: {
                        Text("Undo")
                            .font(.system(.footnote, weight: .semibold)).foregroundStyle(AppSection.actions.color)
                            .padding(.horizontal, 10).frame(minHeight: 32)
                            .overlay(Capsule().stroke(AppSection.actions.color, lineWidth: 1))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("table-undo")
                }
            }
            // What the change WAS, on a line of its own — "2 changed: Condition → New".
            // It used to say only "2 changed" (the spec pass, 5 Oct 2026).
            if !wasBefore.isEmpty {
                Text(didSay).font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.muted)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("table-said")
            }
        }
        .padding(.horizontal, 16).padding(.bottom, 8)
    }

    /// Change every ticked thing, keeping what they were first and what the change
    /// made of them.
    private func changeThemAll(_ what: @escaping (inout Item) -> Void, _ said: String) {
        let ids = chosen
        wasBefore = model.library.items.filter { ids.contains($0.id) }
        didSay = "\(ids.count) changed: \(said)"
        model.change { library in
            for id in ids { _ = library.updateThing(id: id) { thing in what(&thing) } }
        }
        madeAs = model.library.items.filter { ids.contains($0.id) }
    }

    /// Put back what that change changed — and only that: a cell he edited on those
    /// things since stays as he left it (`undoChange`).
    private func putBack() {
        let old = wasBefore, made = madeAs
        guard !old.isEmpty else { return }
        model.change { _ = $0.undoChange(before: old, after: made) }
        wasBefore = []
        madeAs = []
        didSay = ""
    }

    /// Pressing a heading sorts by it; pressing the same one again turns it over.
    /// The levels under it stay — minus the one that is now on top.
    private func turn(_ key: String) {
        if sortBy == key { descending.toggle() } else { sortBy = key; descending = false }
        let then = TableKeys.levels(thenStored).filter { $0.key != key }
        thenStored = TableKeys.store(then)
    }

    // MARK: - the band above the grid

    private func top(_ count: Int, _ filters: ThingFilters) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text("All your things").font(.system(.title3, weight: .bold))
                    .foregroundStyle(AppSection.care.color)
                Text("\(count)")
                    .font(.system(.subheadline, weight: .semibold).monospacedDigit()).foregroundStyle(Theme.muted)
                    .accessibilityIdentifier("table-count")
                Spacer()
                Button("Done") { close() }
                    .buttonStyle(HeaderButtonStyle(tint: AppSection.care.color, filled: true)).focusEffectDisabled()
                    .font(.system(.body, weight: .semibold)).foregroundStyle(AppSection.care.color)
                    // Escape closes it as a sheet, as Done does (Escape everywhere, 5 Oct 2026) — but
                    // not the Mac's own "All your things" window: a window closes with ⌘W, and
                    // Escape pressed in its search field would close the whole table.
                    .keyboardShortcut(inWindow ? nil : .cancelAction)
                    .accessibilityIdentifier("table-done")
            }

            HStack(spacing: 8) {
                TextField("Search", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(.subheadline)).foregroundStyle(Theme.ink)
                    .clearButton($query, id: "table-search")
                    .padding(.horizontal, 10).frame(minHeight: 34)
                    .background(RoundedRectangle(cornerRadius: 9).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.line, lineWidth: 1))

                Button { filtering = true } label: {
                    chip(filters.isEmpty ? "Filter" : "Filter \(filters.count)", lit: !filters.isEmpty)
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("table-filter")

                let levels = 1 + TableKeys.levels(thenStored).count
                Button { sorting = true } label: { chip(levels > 1 ? "Sort \(levels)" : "Sort", lit: levels > 1) }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("table-sort")

                Button { picking = true } label: { chip("Columns") }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("table-columns")
            }

            HStack(spacing: 6) {
                ForEach(ThingsTable.filters, id: \.id) { filter in
                    Button { only = filter.id } label: {
                        Text(filter.label)
                            .font(.system(.footnote, weight: .semibold))
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
            if !filters.isEmpty { pills(filters) }
            let then = TableKeys.levels(thenStored).filter { model.library.tableKnows($0.key) }
            if !then.isEmpty {
                // The order in words, when it is more than the arrow in a heading says.
                Text("Sorted by " + ([SortLevel(key: sortBy, descending: descending)] + then)
                        .map { TableKeys.title($0.key, model.library) + ($0.descending ? " ▼" : " ▲") }
                        .joined(separator: ", then "))
                    .font(.system(.footnote, weight: .semibold)).foregroundStyle(Theme.muted)
                    .lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("table-sorted-by")
            }
        }
        .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 8)
    }

    private func chip(_ text: String, lit: Bool = false) -> some View {
        Text(text)
            .font(.system(.footnote, weight: .semibold)).foregroundStyle(lit ? .white : Theme.ink)
            .lineLimit(1)
            .padding(.horizontal, 10).frame(minHeight: 34)
            .background(RoundedRectangle(cornerRadius: 9).fill(lit ? AppSection.care.color : Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(lit ? Color.clear : Theme.line, lineWidth: 1))
            .contentShape(Rectangle())
    }

    /// One pill per filtered column — "Owner: Kim, Robin ✕" — and Clear for all.
    private func pills(_ filters: ThingFilters) -> some View {
        let library = model.library
        let keys = TableColumns.all(library).map(\.id).filter { filters[$0] != nil }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(keys, id: \.self) { key in
                    let words = TableKeys.title(key, library) + ": " + library.filterSummary(column: key, kept: filters[key] ?? [])
                    Button {
                        var all = filters
                        all[key] = nil
                        filtersStored = TableKeys.store(all)
                    } label: {
                        HStack(spacing: 6) {
                            Text(words).font(.system(.footnote, weight: .semibold)).lineLimit(1)
                            Text("✕").font(.system(.footnote, weight: .semibold))
                        }
                        .foregroundStyle(AppSection.care.color)
                        .padding(.horizontal, 10).frame(minHeight: 30)
                        .background(Capsule().fill(AppSection.care.color.opacity(0.14)))
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("table-pill-\(TableKeys.safe(key, library))")
                    .accessibilityLabel(words)
                }
                Button { filtersStored = "" } label: {
                    Text("Clear").font(.system(.footnote, weight: .semibold)).foregroundStyle(AppSection.actions.color)
                        .padding(.horizontal, 8).frame(minHeight: 30).contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("table-filters-clear")
            }
        }
    }

    private func close() {
        #if os(macOS)
        if inWindow { dismissWindow(id: ThingsTable.windowId); return }
        #endif
        dismiss()
    }

    // MARK: - which rows, in which order

    /// The things the search and the quick chips keep — before any column filter.
    private func unfiltered() -> [Item] {
        let needle = normName(query)
        return model.library.ownThings().filter { thing in   // not a template's reminders (0.70)
            if !needle.isEmpty, !normName(thing.name).contains(needle) { return false }
            switch only {
            case "weight": return thing.weight <= 0
            case "place": return jsTrim(thing.storage).isEmpty
            default: return true
            }
        }
    }

    private func things() -> [Item] {
        let library = model.library
        let filters = TableKeys.filters(filtersStored, library)
        let byThing = Dictionary(grouping: library.memberships, by: \.itemId)
        let kept = filters.isEmpty ? unfiltered() : unfiltered().filter { library.passes($0, filters, memberships: byThing) }
        let levels = ([SortLevel(key: sortBy, descending: descending)] + TableKeys.levels(thenStored))
            .filter { library.tableKnows($0.key) }
        return library.sortThings(kept, by: levels)
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
        let open: () -> Void
        @EnvironmentObject var model: LibraryModel

        var body: some View {
            HStack(spacing: 0) {
                // Nailed to the left edge by travelling back exactly as far as the
                // grid has travelled forward. It must be opaque: the columns pass
                // underneath it.
                HStack(spacing: 8) {
                    // Filled = ticked. His words: "the check marker looks less good.
                    // We do not need it — the colour is enough."
                    Button { pick(!ticked) } label: {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(ticked ? AppSection.care.color : Color.clear)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(ticked ? AppSection.care.color : Theme.line, lineWidth: 1.5))
                            .frame(width: TableColumns.box, height: TableColumns.box)
                            .frame(width: 30, height: TableColumns.rowHeight)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("table-\(n)-pick")
                    .accessibilityAddTraits(ticked ? .isSelected : [])

                    Text(thing.name)
                        .font(.system(.footnote, weight: .semibold)).foregroundStyle(Theme.ink)
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("table-\(n)-name")
                    // Open the thing itself. Its own button, so the name stays words
                    // a test can read (a button folds its words in on the Mac).
                    Button(action: open) {
                        // The drawing is on a 24-point grid (the chevron spans 9–15 across, 6–18
                        // down), so it is framed at 24 to sit in the middle of its row — in a
                        // 14-point frame it hung 5 points low (his picture, 6 Oct 2026) — and
                        // scaled with the boxes: 0.78 on the Mac, 1 on the iPhone.
                        SVGPath.path("M9 6l6 6-6 6")
                            .stroke(style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                            .foregroundStyle(AppSection.care.color)
                            .frame(width: 24, height: 24)
                            .scaleEffect(TableColumns.box / 18)
                            .frame(width: 26, height: TableColumns.rowHeight)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("table-\(n)-open")
                    .accessibilityLabel("Open \(thing.name)")
                    .help("Open \(thing.name)")
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
