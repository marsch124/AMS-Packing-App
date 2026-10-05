import SwiftUI
import PackingCore
import PackingLibrary

/// Filters and sort levels for the things table — his asks, 4 Oct 2026: "all
/// existing columns to be able to be used as filter criteria", and "a nested
/// sorting functionality … sorting on travel as a top sort criterion and then
/// sorting on section as an under criterion". The rules live in PackingLibrary
/// (`ThingFilters`, `ThingSorting`); this is how he reaches them.
enum TableKeys {
    /// A key as an accessibility id: a template's key holds its id, which a test
    /// cannot know, so it is named by its place among his templates instead.
    static func safe(_ key: String, _ library: Library) -> String {
        for (prefix, word) in [("list:", "list"), ("section:", "section")] where key.hasPrefix(prefix) {
            let id = String(key.dropFirst(prefix.count))
            if let n = library.templates.firstIndex(where: { $0.id == id }) { return "\(word)-\(n)" }
        }
        return key
    }

    /// What a key is called: "Owner", "Travel", "Travel · section".
    static func title(_ key: String, _ library: Library) -> String {
        if key == "name" { return "Name" }
        if key.hasPrefix("section:"), let list = library.templates.first(where: { "section:\($0.id)" == key }) {
            return "\(library.shownName(list)) · section"
        }
        return TableColumns.all(library).first { $0.id == key }?.title ?? key
    }

    /// Everything the rows can be sorted by, in groups: the name and the thing
    /// itself; its place on its one template; being on each template; and each
    /// template's sections in its own order.
    static func sortGroups(_ library: Library) -> [(title: String, keys: [String])] {
        let all = TableColumns.all(library)
        var out: [(String, [String])] = [("The thing itself", ["name"] + TableColumns.intrinsic.map(\.id))]
        out.append(("On this template", TableColumns.perListColumns.map(\.id)))
        out.append(("On these templates", all.filter { $0.id.hasPrefix("list:") }.map(\.id)))
        let sectioned = library.templatesForThings().filter { !$0.sections.isEmpty }.map { "section:\($0.id)" }
        if !sectioned.isEmpty { out.append(("By a template's sections", sectioned)) }
        return out
    }

    // MARK: kept in AppStorage as JSON, so they stay while he works

    static func filters(_ stored: String) -> ThingFilters {
        guard let data = stored.data(using: .utf8),
              let raw = try? JSONDecoder().decode([String: [String]].self, from: data) else { return [:] }
        return raw.mapValues(Set.init).filter { !$0.value.isEmpty }
    }

    /// The kept filters that still mean something — never one for a template that
    /// is gone (`Library.liveFilters`).
    static func filters(_ stored: String, _ library: Library) -> ThingFilters {
        library.liveFilters(filters(stored))
    }

    static func store(_ filters: ThingFilters) -> String {
        let raw = filters.filter { !$0.value.isEmpty }.mapValues { $0.sorted() }
        guard !raw.isEmpty, let data = try? JSONEncoder().encode(raw) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    static func levels(_ stored: String) -> [SortLevel] {
        guard let data = stored.data(using: .utf8),
              let levels = try? JSONDecoder().decode([SortLevel].self, from: data) else { return [] }
        return levels
    }

    static func store(_ levels: [SortLevel]) -> String {
        guard !levels.isEmpty, let data = try? JSONEncoder().encode(levels) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }
}

/// A row-sized box: filled in the Care colour when ticked — the table's own ticks,
/// so a ticked answer looks like a ticked thing.
private struct TickBox: View {
    let on: Bool
    var body: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(on ? AppSection.care.color : Color.clear)
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(on ? AppSection.care.color : Theme.muted, lineWidth: 1.5))
            .frame(width: 22, height: 22)
    }
}

// MARK: - Filter

/// Every column, and under the one he opens, the answers his things give to it,
/// each with how many give it. Ticks in one column mean "any of these"; filtered
/// columns must all hold.
struct FilterSheet: View {
    @EnvironmentObject var model: LibraryModel
    @Binding var stored: String
    /// The things before any column filter (after the search and the quick chips).
    let base: [Item]
    @Environment(\.dismiss) private var dismiss
    @State private var open: String?
    @State private var narrow = ""

    var body: some View {
        let library = model.library
        let filters = TableKeys.filters(stored, library)
        let byThing = Dictionary(grouping: library.memberships, by: \.itemId)
        let shown = base.filter { library.passes($0, filters, memberships: byThing) }.count
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("Filter").font(.system(.title3, weight: .bold)).foregroundStyle(AppSection.care.color)
                Text("\(shown) of \(base.count)")
                    .font(.system(.subheadline, weight: .semibold).monospacedDigit()).foregroundStyle(Theme.muted)
                    .accessibilityIdentifier("filter-count")
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(HeaderButtonStyle(tint: AppSection.care.color, filled: true)).focusEffectDisabled()
                    .font(.system(.body, weight: .semibold)).foregroundStyle(AppSection.care.color)
                    .accessibilityIdentifier("filter-done")
            }
            .padding(16)
            if !filters.isEmpty {
                Button { stored = "" } label: {
                    Text("Clear all filters").font(.system(.subheadline, weight: .semibold)).foregroundStyle(AppSection.actions.color)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .padding(.horizontal, 16).padding(.bottom, 8)
                .accessibilityIdentifier("filter-clear-all")
            }
            KeyboardAwayScroll {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(groups(library), id: \.title) { group in
                        HeadingTitle(title: group.title, tint: AppSection.care.color)
                            .padding(.top, 18).padding(.bottom, 4)
                        ForEach(group.columns, id: \.self) { key in
                            column(key, filters: filters, byThing: byThing)
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("filter-sheet")
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 560)
        #endif
    }

    private func groups(_ library: Library) -> [(title: String, columns: [String])] {
        let all = TableColumns.all(library)
        return [("The thing itself", TableColumns.intrinsic.map(\.id)),
                ("On this template", TableColumns.perListColumns.map(\.id)),
                ("On these templates", all.filter { $0.id.hasPrefix("list:") }.map(\.id))]
            .filter { !$0.1.isEmpty }
    }

    @ViewBuilder
    private func column(_ key: String, filters: ThingFilters, byThing: [String: [Membership]]) -> some View {
        let library = model.library
        let safe = TableKeys.safe(key, library)
        let kept = filters[key] ?? []
        let isOpen = open == key
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeOut(duration: 0.15)) { open = isOpen ? nil : key }
                narrow = ""
            } label: {
                HStack(spacing: 10) {
                    Text(TableKeys.title(key, library))
                        .font(.system(.body, weight: .semibold)).foregroundStyle(Theme.ink)
                    Spacer(minLength: 8)
                    Text(kept.isEmpty ? "Any" : library.filterSummary(column: key, kept: kept))
                        .font(.system(.subheadline, weight: kept.isEmpty ? .regular : .semibold))
                        .foregroundStyle(kept.isEmpty ? Theme.muted : AppSection.care.color)
                        .lineLimit(1)
                    Text(isOpen ? "▴" : "▾").font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.muted)
                }
                .frame(minHeight: Metrics.tap)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain).focusEffectDisabled()
            .accessibilityIdentifier("filter-col-\(safe)")
            .accessibilityValue(kept.isEmpty ? "" : library.filterSummary(column: key, kept: kept))
            if isOpen { answers(key, safe: safe, kept: kept, filters: filters, byThing: byThing) }
        }
        .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
    }

    /// The answers, counted among the things the OTHER filters keep — so each count
    /// says what ticking it would leave.
    @ViewBuilder
    private func answers(_ key: String, safe: String, kept: Set<String>, filters: ThingFilters,
                         byThing: [String: [Membership]]) -> some View {
        let library = model.library
        var others = filters
        let _ = others.removeValue(forKey: key)
        let pool = base.filter { library.passes($0, others, memberships: byThing) }
        let offered = library.filterAnswers(column: key, among: pool)
        // A ticked answer stays in sight even when nothing has it any more.
        let gone = kept.subtracting(offered.map(\.value)).sorted().map { FilterAnswer(value: $0, label: $0.isEmpty ? "Blank" : $0, count: 0) }
        let all = offered + gone
        let needle = normName(narrow)
        VStack(alignment: .leading, spacing: 2) {
            if all.count > 12 {
                TextField("Narrow the answers", text: $narrow)
                    .textFieldStyle(.plain)
                    .font(.system(.callout)).foregroundStyle(Theme.ink)
                    .clearButton($narrow, id: "filter-narrow")
                    .padding(.horizontal, 10).frame(minHeight: 38)
                    .background(RoundedRectangle(cornerRadius: 9).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.line, lineWidth: 1))
                    .padding(.bottom, 4)
            }
            if all.isEmpty {
                Text("None of the things in view has an answer here.")
                    .font(.system(.subheadline)).foregroundStyle(Theme.muted)
                    .padding(.vertical, 4)
            }
            ForEach(Array(all.enumerated()), id: \.element.value) { n, answer in
                if needle.isEmpty || normName(answer.label).contains(needle) {
                    let on = kept.contains(answer.value)
                    Button { toggle(key, answer.value) } label: {
                        HStack(spacing: 12) {
                            TickBox(on: on)
                            Text(answer.label)
                                .font(.system(.callout, weight: on ? .semibold : .regular)).foregroundStyle(Theme.ink)
                                .lineLimit(2)
                            Spacer(minLength: 8)
                            Text("\(answer.count)")
                                .font(.system(.subheadline, weight: .semibold).monospacedDigit()).foregroundStyle(Theme.muted)
                        }
                        .frame(minHeight: Metrics.compact)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("filter-\(safe)-\(n)")
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            if !kept.isEmpty {
                Button { set(key, []) } label: {
                    Text("Any — clear this one").font(.system(.subheadline, weight: .semibold)).foregroundStyle(AppSection.care.color)
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .padding(.vertical, 4)
                .accessibilityIdentifier("filter-\(safe)-clear")
            }
        }
        .padding(.leading, 6).padding(.bottom, 10)
    }

    private func toggle(_ key: String, _ value: String) {
        var kept = TableKeys.filters(stored, model.library)[key] ?? []
        if kept.contains(value) { kept.remove(value) } else { kept.insert(value) }
        set(key, kept)
    }

    private func set(_ key: String, _ kept: Set<String>) {
        var all = TableKeys.filters(stored, model.library)
        all[key] = kept.isEmpty ? nil : kept
        stored = TableKeys.store(all)
    }
}

// MARK: - Sort

/// Up to three levels: Sort by, then by, then by — each with its own way round.
struct SortSheet: View {
    @EnvironmentObject var model: LibraryModel
    @Binding var sortBy: String
    @Binding var descending: Bool
    @Binding var thenStored: String
    @Environment(\.dismiss) private var dismiss
    /// Which level's list of columns is open.
    @State private var choosing: Int?

    private var levels: [SortLevel] {
        [SortLevel(key: sortBy, descending: descending)] + TableKeys.levels(thenStored)
    }

    var body: some View {
        let library = model.library
        let now = levels
        VStack(spacing: 0) {
            HStack {
                Text("Sort").font(.system(.title3, weight: .bold)).foregroundStyle(AppSection.care.color)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(HeaderButtonStyle(tint: AppSection.care.color, filled: true)).focusEffectDisabled()
                    .font(.system(.body, weight: .semibold)).foregroundStyle(AppSection.care.color)
                    .accessibilityIdentifier("sort-done")
            }
            .padding(16)
            KeyboardAwayScroll {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(now.enumerated()), id: \.offset) { n, level in
                        levelRow(n, level, library)
                        if choosing == n { keyList(n, library) }
                    }
                    if now.count < SORT_LEVELS_MAX {
                        Button { add() } label: {
                            Text("+ Then by").font(.system(.body, weight: .semibold)).foregroundStyle(.white)
                                .padding(.horizontal, 18).frame(minHeight: Metrics.tap)
                                .background(Capsule().fill(AppSection.care.color))
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain).focusEffectDisabled()
                        .padding(.top, 16)
                        .accessibilityIdentifier("sort-add")
                    }
                    Text("Each level only orders the things the levels above it find equal. A blank always goes last.")
                        .font(.system(.subheadline)).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 14)
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sort-sheet")
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 560)
        #endif
    }

    private func levelRow(_ n: Int, _ level: SortLevel, _ library: Library) -> some View {
        HStack(spacing: 12) {
            Text(n == 0 ? "Sort by" : "then by")
                .font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.muted)
                .frame(width: 64, alignment: .leading)
            Button { choosing = choosing == n ? nil : n } label: {
                HStack {
                    Text(TableKeys.title(level.key, library))
                        .font(.system(.body, weight: .semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                    Spacer(minLength: 6)
                    Text(choosing == n ? "▴" : "▾").font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.muted)
                }
                .padding(.horizontal, 12).frame(minHeight: Metrics.tap)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(choosing == n ? AppSection.care.color : Theme.line, lineWidth: 1))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain).focusEffectDisabled()
            .accessibilityIdentifier("sort-level-\(n)")
            .accessibilityValue(TableKeys.title(level.key, library))
            Button { turn(n) } label: {
                Text(level.descending ? "▼" : "▲")
                    .font(.system(.title3, weight: .bold)).foregroundStyle(AppSection.care.color)
                    .frame(width: Metrics.tap, height: Metrics.tap)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain).focusEffectDisabled()
            .accessibilityIdentifier("sort-dir-\(n)")
            .accessibilityValue(level.descending ? "down" : "up")
            if n > 0 {
                Button { remove(n) } label: {
                    Text("✕").font(.system(.body, weight: .semibold)).foregroundStyle(Theme.muted)
                        .frame(width: 36, height: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("sort-remove-\(n)")
                .accessibilityLabel("Remove this level")
            }
        }
        .padding(.top, 10)
    }

    private func keyList(_ n: Int, _ library: Library) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(TableKeys.sortGroups(library), id: \.title) { group in
                Text(group.title.uppercased())
                    .font(.system(.footnote, weight: .semibold)).kerning(0.5).foregroundStyle(AppSection.care.color)
                    .padding(.top, 12).padding(.bottom, 2)
                ForEach(group.keys, id: \.self) { key in
                    let on = levels[n].key == key
                    Button { pick(n, key) } label: {
                        HStack {
                            Text(TableKeys.title(key, library))
                                .font(.system(.callout, weight: on ? .semibold : .regular))
                                .foregroundStyle(on ? AppSection.care.color : Theme.ink)
                            Spacer()
                        }
                        .frame(minHeight: Metrics.compact).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
                    .accessibilityIdentifier("sort-key-\(TableKeys.safe(key, library))")
                }
            }
        }
        .padding(.leading, 76).padding(.bottom, 6)
    }

    private func write(_ all: [SortLevel]) {
        let first = all.first ?? SortLevel(key: "name")
        sortBy = first.key
        descending = first.descending
        thenStored = TableKeys.store(Array(all.dropFirst().prefix(SORT_LEVELS_MAX - 1)))
    }

    private func pick(_ n: Int, _ key: String) {
        var all = levels
        all[n].key = key
        write(all)
        choosing = nil
    }

    private func turn(_ n: Int) {
        var all = levels
        all[n].descending.toggle()
        write(all)
    }

    private func add() {
        var all = levels
        all.append(SortLevel(key: "name"))
        write(all)
        choosing = all.count - 1
    }

    private func remove(_ n: Int) {
        var all = levels
        all.remove(at: n)
        write(all)
        choosing = nil
    }
}
