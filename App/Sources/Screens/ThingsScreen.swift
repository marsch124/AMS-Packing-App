import SwiftUI
import PackingCore
import PackingLibrary

/// Your things: everything he owns, whether or not it is on a list yet. Tap one
/// to change it — a change here reaches every list it is on.
struct ThingsScreen: View {
    /// Opened from a bar on the Care dashboard: start with this in the search.
    var searching: String = ""
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var noListOnly = false
    @State private var newName = ""
    @State private var editing: String?

    var body: some View {
        let all = model.library.thingRows()
        let homeless = all.filter { $0.templates.isEmpty }.count
        let q = normName(query)
        let shown = all.filter { (!noListOnly || $0.templates.isEmpty) && (q.isEmpty || normName($0.item.name).contains(q)) }
        VStack(spacing: 0) {
            HStack {
                Text("Your things").font(.system(size: 22, weight: .heavy)).foregroundStyle(Theme.ink)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .font(.system(size: 17, weight: .bold)).foregroundStyle(AppSection.care.color)
                    .accessibilityIdentifier("things-done")
            }
            .padding(16)
            TextField("Search your things…", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 17)).foregroundStyle(Theme.ink)
                .padding(.horizontal, 12).frame(minHeight: 40)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                .padding(.horizontal, 16)
                .accessibilityIdentifier("things-search")
            HStack(spacing: 10) {
                Text(shown.count == 1 ? "1 thing" : "\(shown.count) things")
                    .font(.system(size: 15, weight: .bold).monospacedDigit()).foregroundStyle(Theme.muted)
                    .accessibilityIdentifier("things-count")
                Spacer()
                if homeless > 0 {
                    Button { noListOnly.toggle() } label: {
                        Text("On no list \(homeless)").font(.system(size: 14, weight: .bold))
                            .foregroundStyle(noListOnly ? Color.white : AppSection.care.color)
                            .padding(.horizontal, 12).frame(minHeight: 32)
                            .background(Capsule().fill(noListOnly ? AppSection.care.color : Theme.card))
                            .overlay(Capsule().stroke(AppSection.care.color.opacity(0.6), lineWidth: 1))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("things-nolist")
                    .accessibilityAddTraits(noListOnly ? .isSelected : [])
                }
            }
            .padding(.horizontal, 16).padding(.top, 10)
            KeyboardAwayScroll {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(shown.enumerated()), id: \.element.item.id) { n, row in
                        Button { editing = row.item.id } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.item.name).font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.ink)
                                Text([row.templates.isEmpty ? "On no list" : row.templates.joined(separator: ", "),
                                      row.item.storage].filter { !$0.isEmpty }.joined(separator: " · "))
                                    .font(.system(size: 14)).foregroundStyle(row.templates.isEmpty ? AppSection.care.color : Theme.muted)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 10).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
                        .accessibilityIdentifier("thing-row-\(n)")
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
            HStack(spacing: 8) {
                TextField("A new thing", text: $newName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 17, weight: .medium)).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 12).frame(minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                    .onSubmit { add() }
                    .accessibilityIdentifier("thing-new-name")
                Button { add() } label: {
                    Text("New").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 16).frame(minHeight: 44)
                        .background(RoundedRectangle(cornerRadius: 10).fill(jsTrim(newName).isEmpty ? Theme.line : AppSection.care.color))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .disabled(jsTrim(newName).isEmpty)
                .accessibilityIdentifier("thing-new")
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
        .background(Theme.bg.ignoresSafeArea())
        .sheet(item: Binding(get: { editing.map { Editing(id: $0) } }, set: { editing = $0?.id })) { e in
            ThingEditor(itemId: e.id).environmentObject(model)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("things-detail")
        .onAppear { if query.isEmpty, !searching.isEmpty { query = searching } }
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 600)
        #endif
    }

    private func add() {
        let name = newName
        guard !jsTrim(name).isEmpty else { return }
        model.change { _ = $0.addThing(name: name) }
        newName = ""
    }

    private struct Editing: Identifiable { let id: String }
}

/// One thing: what IT knows — its name, where it is kept, what kind of thing it
/// is, its own bag and "When", whose it is, its condition, its weight — and which
/// lists it is on. A change here reaches every list; a list's own exception for
/// the bag stays that list's.
struct ThingEditor: View {
    let itemId: String
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft = Item()
    @State private var onLists: Set<String> = []
    @State private var problem = ""

    var body: some View {
        let templates = model.library.templates.filter { $0.role != CONTAINER_ROLE }
            .stableSorted(compare: { a, b in jsLocaleCompare(a.name, b.name, sensitivity: .base) })
        let owners = ([""] + namesFromRows(model.library.shared, "owners") + model.library.items.map(\.ownedBy))
            .filter { !$0.isEmpty }
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.muted)
                    .accessibilityIdentifier("thing-cancel")
                Spacer()
                Button("Save") { save() }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .font(.system(size: 17, weight: .bold)).foregroundStyle(AppSection.care.color)
                    .accessibilityIdentifier("thing-save")
            }
            .padding(16)
            KeyboardAwayScroll {
                VStack(alignment: .leading, spacing: 14) {
                    label("Name")
                    field($draft.name, "Name", "thing-name")
                    label("Kept at home")
                    field($draft.storage, "e.g. Hall closet", "thing-storage")
                    Pills(title: "Kind of thing", options: CATEGORIES.map { ($0, $0) }, selected: [draft.category],
                          id: "thing-category", tint: AppSection.care.color) { draft.category = $0 }
                    Pills(title: "Usually packed in", options: containerNames(model.library.resolvedTemplates()).map { ($0, $0) },
                          selected: [draft.container], id: "thing-bag", tint: AppSection.care.color) { draft.container = $0 }
                    Pills(title: "When", options: PHASES.map { ($0.id, $0.label) }, selected: [draft.phase],
                          id: "thing-when", tint: AppSection.care.color) { draft.phase = $0 }
                    if !owners.isEmpty {
                        Pills(title: "Whose it is", options: [("", "Nobody's in particular")] + owners.map { ($0, $0) },
                              selected: [draft.ownedBy], id: "thing-owner", tint: AppSection.care.color) { draft.ownedBy = $0 }
                    }
                    Pills(title: "Condition", options: [("", "Not said")] + ITEM_CONDITIONS.map { ($0.id, $0.label) },
                          selected: [draft.condition], id: "thing-condition", tint: AppSection.care.color) { draft.condition = $0 }
                    label("Weight, in grams (0 = not known)")
                    field(Binding(get: { draft.weight == 0 ? "" : String(Int(draft.weight)) },
                                  set: { draft.weight = Double(jsTrim($0)) ?? 0 }), "0", "thing-weight")
                    Pills(title: "On these lists", options: templates.map { ($0.id, $0.name) }, selected: onLists,
                          id: "thing-lists", tint: AppSection.templates.color) { id in
                        if onLists.contains(id) { onLists.remove(id) } else { onLists.insert(id) }
                    }
                    if !problem.isEmpty {
                        Text(problem).font(.system(size: 15, weight: .semibold)).foregroundStyle(AppSection.actions.color)
                            .accessibilityIdentifier("thing-problem")
                    }
                    Text("A change here reaches every list it is on. Past trips keep what they were packed with.")
                        .font(.system(size: 14)).foregroundStyle(Theme.muted)
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .onAppear {
            if let it = model.library.items.first(where: { $0.id == itemId }) { draft = it }
            onLists = Set(model.library.memberships.filter { $0.itemId == itemId }.map(\.templateId))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("thing-detail")
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 600)
        #endif
    }

    private func label(_ text: String) -> some View {
        Text(text).font(.system(size: 14, weight: .heavy)).foregroundStyle(Theme.muted)
    }

    private func field(_ text: Binding<String>, _ prompt: String, _ id: String) -> some View {
        TextField(prompt, text: text)
            .textFieldStyle(.plain)
            .font(.system(size: 18, weight: .medium)).foregroundStyle(Theme.ink)
            .padding(.horizontal, 12).frame(minHeight: 46)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
            .accessibilityIdentifier(id)
    }

    private func save() {
        guard let it = model.library.items.first(where: { $0.id == itemId }) else { dismiss(); return }
        if jsTrim(draft.name) != it.name {
            var ok = false
            model.change { ok = $0.renameThing(id: itemId, to: draft.name) }
            if !ok { problem = jsTrim(draft.name).isEmpty ? "A thing needs a name." : "You already have a thing called that."; return }
        }
        let d = draft
        let lists = onLists
        model.change { lib in
            _ = lib.updateThing(id: itemId) { thing in
                thing.storage = jsTrim(d.storage)
                thing.category = d.category
                thing.container = d.container
                thing.phase = d.phase
                thing.ownedBy = d.ownedBy
                thing.condition = d.condition
                thing.weight = d.weight
            }
            for t in lib.templates where t.role != CONTAINER_ROLE {
                _ = lib.setOnTemplate(itemId: itemId, templateId: t.id, on: lists.contains(t.id))
            }
        }
        dismiss()
    }
}
