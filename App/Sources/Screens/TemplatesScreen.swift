import SwiftUI
import PackingCore
import PackingLibrary

/// The Templates tab: every template, grouped the way he organises his life —
/// always packed, by transport, then his activity groups.
struct TemplatesScreen: View {
    @EnvironmentObject var model: LibraryModel
    @State private var open: PackList?

    struct Shelf: Identifiable { let id: String; let title: String; let lists: [PackList] }

    static func shelves(_ all: [PackList]) -> [Shelf] {
        var out: [Shelf] = []
        func add(_ id: String, _ title: String, _ lists: [PackList]) { if !lists.isEmpty { out.append(Shelf(id: id, title: title, lists: lists)) } }
        add("base", "Always packed", all.filter { $0.role == "base" })
        add("transport", "By transport", all.filter { $0.role == "transport" })
        for g in GROUPS { add(g.id, g.label, orderActivities(g.id, all.filter { $0.role.isEmpty && $0.group == g.id })) }
        add("other", "Other lists", all.filter { $0.role.isEmpty && $0.group.isEmpty })
        add("containers", "Containers", all.filter { $0.role == CONTAINER_ROLE })
        return out
    }

    /// "GA · GOAL ACTIVITY" — his code, then the words, as he wrote them.
    static func shelfHeading(_ shelf: Shelf) -> String {
        let code = GROUPS.first { $0.id == shelf.id }?.id ?? ""
        return code.isEmpty ? shelf.title.uppercased() : "\(code) · \(shelf.title.uppercased())"
    }

    /// "15 lists · 431 things · 4 trips packed from them"
    static func summary(_ lists: [PackList], _ library: Library) -> String {
        let things = library.items.count
        let trips = library.trips.count
        var parts = ["\(lists.count) list\(lists.count == 1 ? "" : "s")",
                     "\(things) thing\(things == 1 ? "" : "s")"]
        if trips > 0 { parts.append("\(trips) trip\(trips == 1 ? "" : "s") packed from them") }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        let shelves = TemplatesScreen.shelves(model.library.resolvedTemplates())
        let flat = shelves.flatMap(\.lists)
        let use = model.library.templateUse()
        KeyboardAwayScroll {
            LazyVStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your lists").font(.system(size: 28, weight: .heavy)).foregroundStyle(AppSection.templates.color)
                        .accessibilityIdentifier("templates-heading")
                    Text(TemplatesScreen.summary(flat, model.library))
                        .font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.muted)
                        .accessibilityIdentifier("templates-summary")
                }
                .padding(.top, 14).padding(.bottom, 4)
                ForEach(shelves) { shelf in
                    // His own code beside the name, as the web app has it:
                    // "GA · GOAL ACTIVITY".
                    Text(TemplatesScreen.shelfHeading(shelf))
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(Theme.muted)
                        .kerning(0.6)
                        .padding(.top, 16)
                        .accessibilityIdentifier("templates-shelf-\(shelf.id)")
                    // Two across: more of his lists at a glance, as the web app shows them.
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                              spacing: 8) {
                        ForEach(shelf.lists, id: \.id) { list in
                            Button { open = list } label: { TemplateCard(list: list, use: use[list.id]) }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("template-row-\(flat.firstIndex { $0.id == list.id } ?? 0)")
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .sheet(item: $open) { list in TemplateDetail(listId: list.id).environmentObject(model) }
    }
}

extension PackList: Identifiable {}

/// A list as a card: its cover, its name, how many things, and when it was last
/// taken — two across, the way the web app shows them.
struct TemplateCard: View {
    let list: PackList
    var use: Library.TemplateUse?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Cover(list: list, size: 34)
                Spacer(minLength: 0)
                Text("\(list.items.count)")
                    .font(.system(size: 15, weight: .heavy).monospacedDigit())
                    .foregroundStyle(Theme.muted)
            }
            Text(list.name)
                .font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.ink)
                .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            Text(TemplateCard.lastTaken(use))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(use == nil ? Theme.line : Theme.muted)
                .lineLimit(1)
                .accessibilityIdentifier("template-used")
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
        .contentShape(Rectangle())
    }
}

extension TemplateCard {
    /// "Last taken: Göteborg, 2 days ago" — or the plain truth that it has never
    /// been out.
    static func lastTaken(_ use: Library.TemplateUse?) -> String {
        guard let use, use.trips > 0 else { return "Never taken along" }
        guard !use.lastTrip.isEmpty else { return "Taken on \(use.trips) trip\(use.trips == 1 ? "" : "s")" }
        // The WHEN first: it is the part that is always worth reading, and the part
        // that still shows when a long trip name is cut off.
        let ago = use.lastDate.isEmpty ? "" : countdownLabel(daysUntil(use.lastDate, Today.local))
        return ago.isEmpty ? "Last: \(use.lastTrip)" : "\(ago) · \(use.lastTrip)"
    }
}

/// A template's face: ITS colour, and the cover HE chose if he chose one —
/// otherwise its initial. (His covers are his data; the app adds no art of its own.)
struct Cover: View {
    let list: PackList
    var size: Double = 40

    var body: some View {
        let glyph = list.emoji.isEmpty ? String(list.name.prefix(1)).uppercased() : list.emoji
        Text(glyph)
            .font(.system(size: size * (list.emoji.isEmpty ? 0.46 : 0.52), weight: .heavy))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: size * 0.28).fill(Color(hexString: listColor(list))))
            .accessibilityHidden(true)
    }
}

/// One template: its things under his "When" headings; a thing can be added
/// at the foot and taken off with ✕ (the thing itself survives).
struct TemplateDetail: View {
    let listId: String
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    @State private var newName = ""
    @State private var editingRow: String?

    var body: some View {
        let list = model.library.resolvedTemplate(id: listId) ?? newList()
        // His lists are built in SECTIONS (511 of his 538 rows sit in one), so that
        // is how a list reads here. A list with no sections falls back to "When".
        let sectioned = list.items.contains { !$0.section.isEmpty }
        let groups: [(title: String, colour: Color?, items: [Item])] = sectioned
            ? groupItemsBySection(list.items, list.sections)
                .filter { !$0.items.isEmpty }
                .map { (($0.section?.name ?? "Everything else"), nil, $0.items) }
            : entriesByPhase(list.items)
                .filter { !$0.entries.isEmpty }
                .map { ($0.phase.label, Color(hexString: $0.phase.color), $0.entries) }
        // Numbered as they are READ, top to bottom — what you see first is the first.
        let index: [String: Int] = Dictionary(groups.flatMap(\.items).enumerated().map { ($1.memId ?? "\($0)", $0) },
                                              uniquingKeysWith: { a, _ in a })
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Cover(list: list, size: 36)
                Text(list.name).font(.system(size: 22, weight: .heavy)).foregroundStyle(Theme.ink)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.plain)
                    .focusEffectDisabled()
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppSection.templates.color)
                    .accessibilityIdentifier("template-detail-done")
            }
            .padding(16)
            KeyboardAwayScroll {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                        Text(group.title)
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundStyle(group.colour ?? AppSection.templates.color)
                            .padding(.top, 12)
                        ForEach(group.items, id: \.memId) { item in
                            let n = index[item.memId ?? ""] ?? 0
                            HStack(spacing: 4) {
                                Button { editingRow = item.memId } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.name).font(.system(size: 17, weight: .medium)).foregroundStyle(Theme.ink)
                                            if !item.qty.isEmpty || !item.note.isEmpty {
                                                Text([item.qty.isEmpty ? "" : "×\(item.qty)", item.note]
                                                        .filter { !$0.isEmpty }.joined(separator: " · "))
                                                    .font(.system(size: 13)).foregroundStyle(Theme.muted).lineLimit(1)
                                            }
                                        }
                                        Spacer(minLength: 8)
                                        Text(item.container).font(.system(size: 15)).foregroundStyle(Theme.muted).lineLimit(1)
                                    }
                                    .padding(.vertical, 6).contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("template-item-\(n)")
                                Button {
                                    if let mid = item.memId { model.change { _ = $0.removeFromTemplate(templateId: listId, memId: mid) } }
                                } label: {
                                    SVGPath.path("M6 6L18 18M18 6L6 18")
                                        .stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                                        .frame(width: 22, height: 22).foregroundStyle(Theme.muted)
                                        .frame(width: 40, height: 36).contentShape(Rectangle())
                                }
                                .buttonStyle(.plain).focusEffectDisabled()
                                .accessibilityIdentifier("template-item-\(n)-remove")
                                .accessibilityLabel("Take \(item.name) off this list")
                            }
                            .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            HStack(spacing: 8) {
                TextField("Add a thing to this list", text: $newName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 17, weight: .medium)).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 12).frame(minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                    .onSubmit { add() }
                    .accessibilityIdentifier("template-add-name")
                Button { add() } label: {
                    Text("Add").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 16).frame(minHeight: 44)
                        .background(RoundedRectangle(cornerRadius: 10).fill(jsTrim(newName).isEmpty ? Theme.line : AppSection.templates.color))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .disabled(jsTrim(newName).isEmpty)
                .accessibilityIdentifier("template-add")
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
        .background(Theme.bg.ignoresSafeArea())
        .sheet(item: Binding(get: { editingRow.map { Editing(id: $0) } }, set: { editingRow = $0?.id })) { e in
            RowEditor(templateId: listId, memId: e.id).environmentObject(model)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("template-detail")
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 600)
        #endif
    }

    private func add() {
        let name = newName
        guard !jsTrim(name).isEmpty else { return }
        model.change { _ = $0.addToTemplate(templateId: listId, name: name) }
        newName = ""
    }

    private struct Editing: Identifiable { let id: String }
}

/// One row of a list: what THIS list says about the thing — its bag and "When"
/// here, how many, a note, which section it sits in. Blank means "the same as
/// the thing itself", so a change to the thing still reaches this list.
struct RowEditor: View {
    let templateId: String
    let memId: String
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    @State private var bag = ""
    @State private var when = ""
    @State private var qty = ""
    @State private var note = ""
    @State private var section = ""
    @State private var newSectionName = ""

    var body: some View {
        let found = model.library.row(templateId: templateId, memId: memId)
        let thing = found?.thing ?? Item()
        let list = model.library.templates.first { $0.id == templateId } ?? newList()
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.muted)
                    .accessibilityIdentifier("row-cancel")
                Spacer()
                Button("Save") { save() }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .font(.system(size: 17, weight: .bold)).foregroundStyle(AppSection.templates.color)
                    .accessibilityIdentifier("row-save")
            }
            .padding(16)
            KeyboardAwayScroll {
                VStack(alignment: .leading, spacing: 14) {
                    Text(thing.name).font(.system(size: 22, weight: .heavy)).foregroundStyle(Theme.ink)
                    Text("On \(list.name)").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.muted)
                    Pills(title: "Bag on this list", options: [("", "Same as the thing (\(thing.container))")]
                            + containerNames(model.library.resolvedTemplates()).map { ($0, $0) },
                          selected: [bag], id: "row-bag", tint: AppSection.templates.color) { bag = $0 }
                    Pills(title: "When, on this list", options: [("", "Same as the thing (\(phaseLabel(thing.phase)))")]
                            + PHASES.map { ($0.id, $0.label) },
                          selected: [when], id: "row-when", tint: AppSection.templates.color) { when = $0 }
                    if !list.sections.isEmpty {
                        Pills(title: "Section of this list", options: [("", "No section")] + list.sections.map { ($0.id, $0.name) },
                              selected: [section], id: "row-section", tint: AppSection.templates.color) { section = $0 }
                    }
                    Text("A new section").font(.system(size: 14, weight: .heavy)).foregroundStyle(Theme.muted)
                    HStack(spacing: 8) {
                        field($newSectionName, "e.g. Lights", "row-section-new")
                        Button { addSection() } label: {
                            Text("Add").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                                .padding(.horizontal, 16).frame(minHeight: 44)
                                .background(RoundedRectangle(cornerRadius: 10).fill(jsTrim(newSectionName).isEmpty ? Theme.line : AppSection.templates.color))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).focusEffectDisabled()
                        .disabled(jsTrim(newSectionName).isEmpty)
                        .accessibilityIdentifier("row-section-add")
                    }
                    Text("How many").font(.system(size: 14, weight: .heavy)).foregroundStyle(Theme.muted)
                    field($qty, "e.g. 2, or 2 pairs", "row-qty")
                    Text("Note").font(.system(size: 14, weight: .heavy)).foregroundStyle(Theme.muted)
                    field($note, "e.g. with the red filter", "row-note")
                    Text("Blank means the same as the thing itself, so a change to the thing still reaches this list.")
                        .font(.system(size: 14)).foregroundStyle(Theme.muted)
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .onAppear {
            guard let f = model.library.row(templateId: templateId, memId: memId) else { return }
            bag = f.membership.container; when = f.membership.phase
            qty = f.membership.qty; note = f.membership.note; section = f.membership.section
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("row-detail")
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 600)
        #endif
    }

    private func field(_ text: Binding<String>, _ prompt: String, _ id: String) -> some View {
        TextField(prompt, text: text)
            .textFieldStyle(.plain)
            .font(.system(size: 17, weight: .medium)).foregroundStyle(Theme.ink)
            .padding(.horizontal, 12).frame(minHeight: 44)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
            .accessibilityIdentifier(id)
    }

    private func addSection() {
        let name = newSectionName
        guard !jsTrim(name).isEmpty else { return }
        var made: TemplateSection?
        model.change { made = $0.addSection(templateId: templateId, name: name) }
        if let made = made { section = made.id }
        newSectionName = ""
    }

    private func save() {
        let (b, w, q, n, s) = (bag, when, qty, note, section)
        model.change {
            _ = $0.updateMembership(memId: memId) { m in
                m.container = b; m.phase = w; m.qty = jsTrim(q); m.note = jsTrim(n); m.section = s
            }
        }
        dismiss()
    }
}

extension Color {
    /// "#7c5cd6" → a colour. Anything unreadable → slate.
    init(hexString: String) {
        var s = hexString.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        self.init(hex: UInt32(s.prefix(6), radix: 16) ?? 0x64748b)
    }
}
