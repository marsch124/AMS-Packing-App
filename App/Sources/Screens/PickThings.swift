import SwiftUI
import PackingCore
import PackingLibrary

/// Choose things for a template — his test H.9 (2026-09-28, the one red box): "How
/// do we add things to a template? We need the list of things. We need to be able to
/// choose from existing ones and also define new ones … order, sort and group the
/// things to pick from in a variety of ways, the same as when packing."
///
/// Every thing he owns, grouped the way he chooses (Kind, From where, Into, When,
/// A–Z), searchable; tick as many as he likes and put them on in one press. What is
/// already on the template shows as such and cannot be ticked twice. A name that
/// matches nothing can be made into a new thing, straight onto the template.
///
/// Every group folds — their field test (3 Oct 2026): "It is an extremely
/// long list when adding, so we need toggles everywhere. We need the list to be
/// collapsible and expandable. Also, an alternative: Collapse All or Expand All."
struct PickThingsScreen: View {
    let templateId: String
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    /// What he ticked, in the order he ticked it — the order they land on the
    /// template (a set put them on in no particular order; the spec pass, 5 Oct 2026).
    @State private var picked: [String] = []
    /// What Add was missing, said under the title (never a grey button).
    @State private var addNeeds = ""
    @AppStorage("ams.pick.grouping") private var groupingRaw = ThingGrouping.kind.rawValue
    /// The groups folded away, remembered on this device as the trip's are — per way
    /// of grouping ("Kind", "From where"…), one "grouping|heading" per line, so a fold
    /// made under From where does not fold a group of the same name under Into.
    @AppStorage("ams.pick.folded") private var foldedRaw = ""

    private static let ways: [ThingGrouping] = [.kind, .fromWhere, .into, .when, .name]

    var body: some View {
        let list = model.library.resolvedTemplate(id: templateId)
        let already = model.library.thingIds(onTemplate: templateId)
        let q = normName(query)
        let things = model.library.items.filter { q.isEmpty || normName($0.name).contains(q) }
        let grouping = ThingGrouping(rawValue: groupingRaw).flatMap { PickThingsScreen.ways.contains($0) ? $0 : nil } ?? .kind
        let groups = grouping.groups(things)
        let exact = model.library.items.contains { normName($0.name) == q }
        let numbered = PickThingsScreen.numbered(groups)
        let violet = AppSection.templates.color
        // A search opens every group: what he typed for must never sit in a folded
        // one. The folds come back as they were when the search is emptied.
        let searching = !q.isEmpty
        let allFolded = !groups.isEmpty && groups.allSatisfy { isFolded($0.title, grouping) }
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button("Cancel") { dismiss() }
                    .buttonStyle(HeaderButtonStyle(tint: Theme.muted, filled: false)).focusEffectDisabled()
                    .accessibilityIdentifier("pick-cancel")
                Spacer(minLength: 4)
                Text(list.map { "Add to \($0.name)" } ?? "Add things")
                    .font(.system(.body, weight: .semibold)).foregroundStyle(Theme.ink)
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .accessibilityIdentifier("pick-title")
                Spacer(minLength: 4)
                // Always in full colour (his rule for a main button); with nothing
                // ticked it says so under the title instead of doing nothing silently.
                Button(picked.isEmpty ? "Add" : "Add \(picked.count)") { putOn() }
                    .buttonStyle(HeaderButtonStyle(tint: violet, filled: true)).focusEffectDisabled()
                    .accessibilityIdentifier("pick-add")
            }
            .needsLine($addNeeds, typed: picked, id: "pick-add-needs")
            .padding(16)
            VStack(alignment: .leading, spacing: 10) {
                TextField("Search your things, or type a new one", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(.body)).foregroundStyle(Theme.ink)
                    .clearButton($query, id: "pick-search")
                    .padding(.horizontal, 12).frame(minHeight: Metrics.tap)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                FlowRow(spacing: 6) {
                    Text("Group").font(.system(.footnote, weight: .semibold)).foregroundStyle(Theme.muted)
                        .frame(minHeight: 32)
                            ForEach(PickThingsScreen.ways, id: \.self) { way in
                                let on = way == grouping
                                Button { groupingRaw = way.rawValue } label: {
                                    Text(way.label).font(.system(.footnote, weight: .semibold))
                                        .foregroundStyle(on ? Color.white : Theme.ink)
                                        .padding(.horizontal, 12).frame(minHeight: 32)
                                        .background(Capsule().fill(on ? violet : Theme.card))
                                        .overlay(Capsule().stroke(on ? violet : Theme.line, lineWidth: 1))
                                        .contentShape(Capsule())
                                }
                                .buttonStyle(.plain).focusEffectDisabled()
                                .accessibilityIdentifier("pick-group-\(way.rawValue)")
                                .accessibilityAddTraits(on ? .isSelected : [])
                            }
                }
                // How many there are, and one press to fold every group away or open
                // them all again. Not while searching: a search opens every group.
                HStack(spacing: 10) {
                    Text(things.count == 1 ? "1 thing" : "\(things.count) things")
                        .font(.system(.subheadline, weight: .semibold).monospacedDigit()).foregroundStyle(Theme.muted)
                        .accessibilityIdentifier("pick-count")
                    Spacer()
                    if !searching && !groups.isEmpty {
                        Button { setFolded(!allFolded, groups.map(\.title), grouping) } label: {
                            HStack(spacing: 6) {
                                FoldAllMark(folding: !allFolded).frame(width: 24, height: 24)
                                Text(allFolded ? "Unfold all" : "Fold all").font(.system(.subheadline, weight: .semibold))
                            }
                            .foregroundStyle(violet)
                            .padding(.leading, 8).padding(.trailing, 12).frame(minHeight: 34)
                            .background(Capsule().fill(violet.opacity(0.10)))
                            .overlay(Capsule().stroke(violet, lineWidth: 1.2))
                            .contentShape(Capsule())
                        }
                        .buttonStyle(.plain).focusEffectDisabled()
                        .accessibilityIdentifier("pick-fold-all")
                    }
                }
                .frame(minHeight: 34)
            }
            .padding(.horizontal, 16).padding(.bottom, 8)
            KeyboardAwayScroll {
                VStack(alignment: .leading, spacing: 4) {
                    // A name he owns nothing by: make it, straight onto this template.
                    if !q.isEmpty && !exact {
                        Button { makeNew() } label: {
                            HStack(spacing: 10) {
                                Text("+").font(.system(.title3, weight: .bold)).foregroundStyle(violet).frame(width: 26)
                                Text("A new thing: \u{201C}\(jsTrim(query))\u{201D}")
                                    .font(.system(.body, weight: .semibold)).foregroundStyle(violet)
                                Spacer()
                            }
                            .padding(.vertical, 10).padding(.horizontal, 12)
                            .background(RoundedRectangle(cornerRadius: 10).fill(violet.opacity(0.10)))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(violet, lineWidth: 1.2))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).focusEffectDisabled()
                        .accessibilityIdentifier("pick-new")
                    }
                    ForEach(Array(numbered.enumerated()), id: \.offset) { g, group in
                        let folded = !searching && isFolded(group.title, grouping)
                        heading(group, g: g, folded: folded, searching: searching, grouping: grouping)
                        if !folded {
                            ForEach(group.rows, id: \.1.id) { n, thing in
                                row(thing, n: n, on: already.contains(thing.id), grouping: grouping)
                            }
                        }
                    }
                    if things.isEmpty && q.isEmpty {
                        Text("You have no things yet. Type a name above to make one.")
                            .font(.system(.callout)).foregroundStyle(Theme.muted)
                            .padding(.top, 20)
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pick-screen")
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 620)
        #endif
    }

    /// A group's heading: the arrow that folds it, its name, and how many things it
    /// holds and how many of them are ticked — so a folded group loses nothing. The
    /// arrow is its own button and the name a text of its own (the Mac folds a
    /// button's texts into the button); the name folds too, as on a trip.
    private func heading(_ group: (title: String, rows: [(Int, Item)]), g: Int, folded: Bool,
                         searching: Bool, grouping: ThingGrouping) -> some View {
        let violet = AppSection.templates.color
        let total = group.rows.count
        let ticked = group.rows.filter { picked.contains($0.1.id) }.count
        let count = Text(total == 1 ? "1 thing" : "\(total) things")
        return HStack(spacing: 6) {
            if searching {
                // Nothing to fold while searching; the name keeps its place.
                Color.clear.frame(width: 30, height: 36)
            } else {
                Button { toggleFold(group.title, grouping) } label: {
                    SVGPath.path("M9 6l6 6-6 6")
                        .stroke(style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                        .frame(width: 24, height: 24)
                        .rotationEffect(.degrees(folded ? 0 : 90))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 30, height: 36).contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("pick-group-\(g)-fold")
                .accessibilityLabel(folded ? "Open \(group.title)" : "Fold \(group.title)")
            }
            Text(group.title)
                .font(.headline).foregroundStyle(violet)
                .lineLimit(1)
                .accessibilityIdentifier("pick-heading-\(g)")
                .onTapGesture { if !searching { toggleFold(group.title, grouping) } }
            (ticked == 0 ? count : count + Text(" \u{00B7} \(ticked) ticked").foregroundStyle(violet))
                .font(.system(.footnote, weight: .semibold).monospacedDigit()).foregroundStyle(Theme.muted)
                .lineLimit(1)
                .accessibilityIdentifier("pick-heading-\(g)-count")
            Spacer(minLength: 0)
        }
        .padding(.top, 10)
    }

    private func foldKey(_ title: String, _ grouping: ThingGrouping) -> String { "\(grouping.rawValue)|\(title)" }
    private func isFolded(_ title: String, _ grouping: ThingGrouping) -> Bool {
        foldedRaw.split(separator: "\n").contains { String($0) == foldKey(title, grouping) }
    }
    private func toggleFold(_ title: String, _ grouping: ThingGrouping) {
        setFolded(!isFolded(title, grouping), [title], grouping)
    }
    /// Fold (or open) these groups of this grouping — one, or all of them at once.
    private func setFolded(_ fold: Bool, _ titles: [String], _ grouping: ThingGrouping) {
        var keys = foldedRaw.split(separator: "\n").map(String.init)
        for title in titles {
            let k = foldKey(title, grouping)
            keys.removeAll { $0 == k }
            if fold { keys.append(k) }
        }
        foldedRaw = keys.joined(separator: "\n")
    }

    private func row(_ thing: Item, n: Int, on: Bool, grouping: ThingGrouping) -> some View {
        let ticked = picked.contains(thing.id)
        let violet = AppSection.templates.color
        // What the row says beside the name: grouped by From where, its bag; grouped
        // any other way, where it is kept at home — or its bag when no place is set
        // (under Into that is the bag it is grouped by: better than saying nothing).
        let aside = grouping == .fromWhere ? thing.container
            : (jsTrim(thing.storage).isEmpty ? thing.container : thing.storage)
        return Button {
            guard !on else { return }
            if ticked { picked.removeAll { $0 == thing.id } } else { picked.append(thing.id) }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().stroke(on ? Theme.line : violet, lineWidth: 2).frame(width: 24, height: 24)
                    if ticked || on {
                        Circle().fill(on ? Theme.line : violet).frame(width: 24, height: 24)
                        Tick().stroke(Color.white, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                            .frame(width: 24, height: 24)
                    }
                }
                Text(thing.name).font(.system(.body))
                    .foregroundStyle(on ? Theme.muted : Theme.ink).lineLimit(1)
                Spacer(minLength: 8)
                Text(on ? "already on it" : aside)
                    .font(.system(.footnote, weight: on ? .semibold : .regular)).foregroundStyle(Theme.muted).lineLimit(1)
            }
            .padding(.vertical, 9).contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
        .accessibilityIdentifier("pick-row-\(n)")
        .accessibilityAddTraits(ticked || on ? .isSelected : [])
        .accessibilityValue(on ? "already on it" : "")
    }

    /// Rows numbered as they are READ, top to bottom, across the groups.
    static func numbered(_ groups: [(title: String, items: [Item])]) -> [(title: String, rows: [(Int, Item)])] {
        var n = 0
        return groups.map { g in
            (g.title, g.items.map { it -> (Int, Item) in n += 1; return (n - 1, it) })
        }
    }

    private func putOn() {
        guard !picked.isEmpty else { addNeeds = "Tick the things to put on first."; return }
        let ids = picked
        model.change { _ = $0.putOnTemplate(templateId: templateId, itemIds: ids) }
        dismiss()
    }

    private func makeNew() {
        let name = jsTrim(query)
        guard !name.isEmpty else { return }
        model.change { _ = $0.addToTemplate(templateId: templateId, name: name) }
        query = ""
    }
}

/// Fold all / Unfold all, drawn: the groups' own arrow, as the groups will be after
/// the press — pointing on (folded) or down (open). Two arrows meeting read as an ✕
/// beside the search's ✕ (seen on the screen, 3 Oct 2026).
struct FoldAllMark: View {
    /// true = the press folds; false = it opens.
    let folding: Bool
    var body: some View {
        SVGPath.path("M9 6l6 6-6 6")
            .stroke(style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
            .rotationEffect(.degrees(folding ? 0 : 90))
            .accessibilityHidden(true)
    }
}

/// "Choose from your things" at the foot of a template — owns its sheet, so the
/// template screen keeps the one sheet it has (several sheets on one view is a
/// trap met in Search).
struct PickThingsDoor: View {
    let templateId: String
    @EnvironmentObject var model: LibraryModel
    @State private var open = false

    var body: some View {
        Button { open = true } label: {
            WideButtonLabel(title: "Choose from your things", tint: AppSection.templates.color) {
                SVGPath.path("M4 6.5h2M9 6.5h11M4 12h2M9 12h11M4 17.5h2M9 17.5h11")
                    .stroke(style: StrokeStyle(lineWidth: 1.9, lineCap: .round))
            }
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier("template-pick")
        .sheet(isPresented: $open) { PickThingsScreen(templateId: templateId).environmentObject(model) }
    }
}
