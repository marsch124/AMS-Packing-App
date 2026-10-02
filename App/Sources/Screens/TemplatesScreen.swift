import SwiftUI
import PackingCore
import PackingLibrary

/// The Templates tab: every template, grouped the way he organises his life —
/// always packed, by transport, then his activity groups.
struct TemplatesScreen: View {
    @EnvironmentObject var model: LibraryModel
    @State private var open: PackList?
    @State private var making = false
    @State private var searching = false

    struct Shelf: Identifiable { let id: String; let title: String; let lists: [PackList] }

    static func shelves(_ all: [PackList]) -> [Shelf] {
        var out: [Shelf] = []
        func add(_ id: String, _ title: String, _ lists: [PackList]) { if !lists.isEmpty { out.append(Shelf(id: id, title: title, lists: lists)) } }
        add("base", "Always packed", all.filter { $0.role == "base" })
        add("transport", "By transport", all.filter { $0.role == "transport" })
        for g in GROUPS { add(g.id, g.label, orderActivities(g.id, all.filter { $0.role.isEmpty && $0.group == g.id })) }
        add("other", "Other templates", all.filter { $0.role.isEmpty && $0.group.isEmpty })
        // Bags are not an activity: they have their own screen, on Care (as in the
        // web app), where each gets a weight limit.
        return out
    }

    /// "GA · GOAL ACTIVITY" — his code, then the words, as he wrote them.
    static func shelfHeading(_ shelf: Shelf) -> String {
        let code = GROUPS.first { $0.id == shelf.id }?.id ?? ""
        return groupHeading(code, shelf.title)
    }

    /// "15 lists · 431 things · 4 trips packed from them"
    static func summary(_ lists: [PackList], _ library: Library) -> String {
        let things = library.items.count
        let trips = library.trips.count
        var parts = ["\(lists.count) template\(lists.count == 1 ? "" : "s")",
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
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Your templates").font(.system(size: 28, weight: .heavy))
                            .foregroundStyle(AppSection.templates.color)
                            .accessibilityIdentifier("templates-heading")
                        Text(TemplatesScreen.summary(flat, model.library))
                            .font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.muted)
                            .accessibilityIdentifier("templates-summary")
                    }
                    Spacer(minLength: 8)
                    SearchButton { searching = true }
                    Button { making = true } label: {
                        Text("+ New")
                            .font(.system(size: 15, weight: .heavy)).foregroundStyle(.white)
                            .padding(.horizontal, 14).frame(minHeight: 36)
                            .background(Capsule().fill(AppSection.templates.color))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("templates-new")
                }
                .padding(.top, 14).padding(.bottom, 4)
                // What his trip reviews say a list carries for nothing (roadmap stop E).
                RefineDoor().environmentObject(model)
                    .padding(.bottom, 4)
                ForEach(shelves) { shelf in
                    // His own code beside the name, as the web app has it:
                    // "GA · GOAL ACTIVITY".
                    Text(TemplatesScreen.shelfHeading(shelf))
                        .font(.system(size: 18, weight: .heavy))       // "Much larger headings" (H.13)
                        .foregroundStyle(Theme.ink)
                        .kerning(0.8)
                        .padding(.top, 20)
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
        .sheet(isPresented: $searching) { SearchScreen().environmentObject(model) }
        .sheet(isPresented: $making) {
            NewList(made: { list in
                model.change { $0.saveTemplate(list) }
                // Straight into it: a list he cannot see the inside of is not made yet.
                open = list
            }, library: model.library)
        }
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
                // Quiet, not invisible: the divider colour could not be read on
                // either a white or a black background.
                .foregroundStyle(use == nil ? Theme.muted.opacity(0.65) : Theme.muted)
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
        // His icon, or the one suggested for its name (approved 2 Oct 2026); else
        // the first letter, as before. White on the template's own colour.
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28).fill(Color(hexString: listColor(list)))
            if let icon = TemplateIcons.icon(Library.icon(of: list)) {
                IconMark(path: icon.path, size: size * 0.66).foregroundStyle(.white)
            } else {
                let glyph = list.emoji.isEmpty ? String(list.name.prefix(1)).uppercased() : list.emoji
                Text(glyph)
                    .font(.system(size: size * (list.emoji.isEmpty ? 0.46 : 0.52), weight: .heavy))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// One of the template icons, drawn at any size from its 24-point path.
struct IconMark: View {
    let path: String
    var size: Double = 24
    var weight: Double = 1.9

    var body: some View {
        let k = size / 24
        SVGPath.path(path)
            .applying(CGAffineTransform(scaleX: k, y: k))
            .stroke(style: StrokeStyle(lineWidth: weight * k, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
    }
}

/// The template's cover on its own page: a tap chooses its icon (his H.1). Owns
/// its sheet — the page keeps the one sheet it has.
struct CoverDoor: View {
    let list: PackList
    @EnvironmentObject var model: LibraryModel
    @State private var open = false

    var body: some View {
        Button { open = true } label: { Cover(list: list, size: 40) }
            .buttonStyle(.plain).focusEffectDisabled()
            .accessibilityIdentifier("template-cover")
            .accessibilityLabel("Icon of \(list.name)")
            .accessibilityValue(Library.icon(of: list) ?? Library.letterIcon)
            .sheet(isPresented: $open) { IconPickerScreen(templateId: list.id).environmentObject(model) }
    }
}

/// Choose a template's icon: the 50 drawn icons in rows, the one it has now
/// ringed; "Suggested" goes back to the icon its name suggests, "Letter" shows
/// the first letter instead.
struct IconPickerScreen: View {
    let templateId: String
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    private let columns = 5

    var body: some View {
        let list = model.library.resolvedTemplate(id: templateId) ?? newList()
        let now = Library.icon(of: list)
        let chosen = model.library.chosenIcon(templateId: templateId)
        let tint = Color(hexString: listColor(list))
        let rows = stride(from: 0, to: TemplateIcons.all.count, by: columns).map {
            Array(TemplateIcons.all[$0..<min($0 + columns, TemplateIcons.all.count)])
        }
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Cover(list: list, size: 40)
                Text(list.name).font(.system(size: 20, weight: .heavy)).foregroundStyle(Theme.ink)
                    .lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                Button("Cancel") { dismiss() }
                    .buttonStyle(HeaderButtonStyle(tint: Theme.muted, filled: false)).focusEffectDisabled()
                    .accessibilityIdentifier("icon-cancel")
            }
            .padding(16)
            KeyboardAwayScroll {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        choice(title: "Suggested", on: chosen == nil, id: "icon-suggested", tint: tint) {
                            if let s = Library.suggestedIcon(for: list), let icon = TemplateIcons.icon(s) {
                                IconMark(path: icon.path, size: 30)
                            } else { Text(String(list.name.prefix(1)).uppercased()).font(.system(size: 22, weight: .heavy)) }
                        } pick: { pick(nil) }
                        choice(title: "Letter", on: chosen == Library.letterIcon, id: "icon-letter", tint: tint) {
                            Text(String(list.name.prefix(1)).uppercased()).font(.system(size: 22, weight: .heavy))
                        } pick: { pick(Library.letterIcon) }
                    }
                    SectionTitle(title: "All icons")
                    // Plain rows, not a lazy grid (the Mac builds only what is on screen).
                    ForEach(rows.indices, id: \.self) { r in
                        HStack(spacing: 10) {
                            ForEach(rows[r]) { icon in
                                choice(title: icon.label, on: chosen != nil && now == icon.key, id: "icon-\(icon.key)", tint: tint) {
                                    IconMark(path: icon.path, size: 30)
                                } pick: { pick(icon.key) }
                            }
                            if rows[r].count < columns { Spacer(minLength: 0) }
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("icon-picker")
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 620)
        #endif
    }

    private func choice<Mark: View>(title: String, on: Bool, id: String, tint: Color,
                                    @ViewBuilder mark: () -> Mark, pick: @escaping () -> Void) -> some View {
        Button(action: pick) {
            VStack(spacing: 6) {
                mark().foregroundStyle(on ? Color.white : Theme.ink).frame(height: 32)
                Text(title).font(.system(size: 12, weight: .bold))
                    .foregroundStyle(on ? Color.white : Theme.muted)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 74)
            .background(RoundedRectangle(cornerRadius: 12).fill(on ? tint : Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(on ? tint : Theme.line, lineWidth: on ? 2 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier(id)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func pick(_ key: String?) {
        model.change { _ = $0.setTemplateIcon(id: templateId, key: key) }
        dismiss()
    }
}

/// One template: its things under his "When" headings; a thing can be added
/// at the foot and taken off with ✕ (the thing itself survives).
struct TemplateDetail: View {
    let listId: String
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    /// His "When" colours, made readable for this screen (2026-09-26).
    @Environment(\.colorScheme) private var scheme
    @State private var newName = ""
    @State private var editingRow: String?
    /// What he is typing over the name, while he is typing it.
    @State private var renaming: String?
    @FocusState private var writingName: Bool
    @State private var askingToDelete = false
    /// The row whose ✕ was pressed — it asks first (his test H.5).
    @State private var takingOff: TakingOff?
    /// How the things are grouped (his test H.3: "group and sort the items in a
    /// template in the same way as when you pack"). "" = the template's own way:
    /// its sections, or When when it has none. Remembered on this device.
    @AppStorage("ams.template.grouping") private var groupingRaw = ""

    struct TakingOff: Equatable { let memId: String; let name: String }

    var body: some View {
        let list = model.library.resolvedTemplate(id: listId) ?? newList()
        // His lists are built in SECTIONS (511 of his 538 rows sit in one), so that
        // is how a list reads here. A list with no sections falls back to "When".
        let sectioned = list.items.contains { !$0.section.isEmpty }
        let ways: [ThingGrouping] = (sectioned ? [.section] : []) + [.when, .into, .fromWhere, .kind, .name]
        let grouping = ThingGrouping(rawValue: groupingRaw).flatMap { ways.contains($0) ? $0 : nil } ?? ways[0]
        let groups: [(title: String, colour: Color?, items: [Item])] = grouping == .when
            ? entriesByPhase(list.items)
                .filter { !$0.entries.isEmpty }
                .map { ($0.phase.label, Color(hexString: readableHex($0.phase.color, dark: scheme == .dark)), $0.entries) }
            : grouping.groups(list.items, sections: list.sections)
                .filter { !$0.items.isEmpty }
                .map { ($0.title, nil, $0.items) }
        // Numbered as they are READ, top to bottom — what you see first is the first.
        let index: [String: Int] = Dictionary(groups.flatMap(\.items).enumerated().map { ($1.memId ?? "\($0)", $0) },
                                              uniquingKeysWith: { a, _ in a })
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                CoverDoor(list: list).environmentObject(model)
                // The name is the field. Press it, type, and it is renamed — no
                // second screen for one word.
                TextField("", text: Binding(
                    get: { renaming ?? list.name },
                    set: { renaming = $0 }))
                    .textFieldStyle(.plain)
                    .font(.system(size: 22, weight: .heavy)).foregroundStyle(Theme.ink)
                    .focused($writingName)
                    .onSubmit { saveName(list) }
                    .accessibilityIdentifier("template-name")
                if let wanted = renaming, jsTrim(wanted) != jsTrim(list.name) {
                    Button { saveName(list) } label: {
                        Text("Rename").font(.system(size: 15, weight: .bold))
                            .foregroundStyle(nameFree(wanted, list) ? AppSection.templates.color : Theme.muted)
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .disabled(!nameFree(wanted, list))
                    .accessibilityIdentifier("template-rename")
                }
                Spacer()
                ShareDoor(id: "template-share", tint: AppSection.templates.color) {
                    ShareOffer(title: "Share \u{201C}\(list.name)\u{201D}", link: model.library.shareLink(templateId: list.id))
                }
                Button("Done") { dismiss() }
                    .buttonStyle(HeaderButtonStyle(tint: AppSection.templates.color, filled: true))
                    .focusEffectDisabled()
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppSection.templates.color)
                    .accessibilityIdentifier("template-detail-done")
            }
            .padding(16)
            // Group the things the ways a trip sorts (his H.3), in sight above the list.
            FlowRow(spacing: 6) {
                Text("Group").font(.system(size: 14, weight: .heavy)).foregroundStyle(Theme.muted)
                    .frame(minHeight: 32)
                        ForEach(ways, id: \.self) { way in
                            let on = way == grouping
                            Button { groupingRaw = way.rawValue } label: {
                                Text(way.label).font(.system(size: 14, weight: on ? .heavy : .semibold))
                                    .foregroundStyle(on ? Color.white : Theme.ink)
                                    .padding(.horizontal, 12).frame(minHeight: 32)
                                    .background(Capsule().fill(on ? AppSection.templates.color : Theme.card))
                                    .overlay(Capsule().stroke(on ? AppSection.templates.color : Theme.line, lineWidth: 1))
                                    .contentShape(Capsule())
                            }
                            .buttonStyle(.plain).focusEffectDisabled()
                            .accessibilityIdentifier("template-grouping-\(way.rawValue)")
                            .accessibilityAddTraits(on ? .isSelected : [])
                        }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16).padding(.bottom, 4)
            KeyboardAwayScroll {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(groups.enumerated()), id: \.offset) { g, group in
                        Text(group.title.uppercased())
                            .font(.system(size: 18, weight: .heavy)).kerning(0.8)   // "Much larger headings" (H.13)
                            .foregroundStyle(group.colour ?? AppSection.templates.color)
                            .padding(.top, 16)
                            .accessibilityIdentifier("template-group-\(g)")
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
                                    if let mid = item.memId { withAnimation(.easeOut(duration: 0.15)) { takingOff = TakingOff(memId: mid, name: item.name) } }
                                } label: {
                                    SVGPath.path("M6 6L18 18M18 6L6 18")
                                        .stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                                        .frame(width: 22, height: 22).foregroundStyle(Theme.muted)
                                        .frame(width: 40, height: 36).contentShape(Rectangle())
                                }
                                .buttonStyle(.plain).focusEffectDisabled()
                                .accessibilityIdentifier("template-item-\(n)-remove")
                                .accessibilityLabel("Take \(item.name) off this template")
                            }
                            .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            // Things he already owns, picked from the whole list (his H.9 — the one red
            // box of the test); or a new one typed beside it.
            PickThingsDoor(templateId: listId).environmentObject(model)
                .padding(.horizontal, 16).padding(.top, 10)
            HStack(spacing: 8) {
                TextField("Or type a new thing", text: $newName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 17, weight: .medium)).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 12).frame(minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                    .onSubmit { add() }
                    .accessibilityIdentifier("template-add-name")
                Button { add() } label: {
                    Text("Add").font(.system(size: 16, weight: .bold))
                        .foregroundStyle(jsTrim(newName).isEmpty ? Theme.muted : Color.white)
                        .padding(.horizontal, 16).frame(minHeight: 44)
                        .background(RoundedRectangle(cornerRadius: 10).fill(jsTrim(newName).isEmpty ? Theme.line : AppSection.templates.color))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .disabled(jsTrim(newName).isEmpty)
                .accessibilityIdentifier("template-add")
            }
            .padding(.horizontal, 16).padding(.vertical, 10)

            if askingToDelete {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Delete “\(list.name)”?")
                        .font(.system(size: 16, weight: .heavy)).foregroundStyle(Theme.ink)
                    Text("The template and its \(list.items.count) row\(list.items.count == 1 ? "" : "s") go. The THINGS stay — they are still in Your things and on any other template.")
                        .font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 10) {
                        Button("Keep it") { askingToDelete = false }
                            .buttonStyle(.plain).focusEffectDisabled()
                            .font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.ink)
                            .accessibilityIdentifier("template-delete-no")
                        Spacer()
                        Button {
                            model.change { _ = $0.deleteTemplate(id: listId) }
                            dismiss()
                        } label: {
                            Text("Delete the template")
                                .font(.system(size: 16, weight: .heavy)).foregroundStyle(.white)
                                .padding(.horizontal, 14).frame(minHeight: 40)
                                .background(Capsule().fill(AppSection.actions.color))
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain).focusEffectDisabled()
                        .accessibilityIdentifier("template-delete-yes")
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppSection.actions.color, lineWidth: 1))
                .padding(.horizontal, 16).padding(.bottom, 10)
            } else {
                SmallDeleteButton(title: "Delete template", id: "template-delete") { askingToDelete = true }
                    .padding(.horizontal, 16).padding(.bottom, 8)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .overlay { if let t = takingOff { takeOffCard(t, list: list) } }
        .sheet(item: Binding(get: { editingRow.map { Editing(id: $0) } }, set: { editingRow = $0?.id })) { e in
            RowEditor(templateId: listId, memId: e.id).environmentObject(model)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("template-detail")
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 600)
        #endif
    }

    /// Is this name free — nobody else's, and not blank?
    private func nameFree(_ wanted: String, _ list: PackList) -> Bool {
        let clean = normName(wanted)
        guard !clean.isEmpty else { return false }
        return !model.library.templates.contains { $0.id != listId && normName($0.name) == clean }
    }

    private func saveName(_ list: PackList) {
        guard let wanted = renaming, nameFree(wanted, list) else { return }
        model.change { _ = $0.renameTemplate(id: listId, to: wanted) }
        renaming = nil
        writingName = false
    }

    /// "Take it off?" — in the middle of the screen, the rest dimmed: his ask (test
    /// H.5), "a confirmation and cancel button. Make it visually pleasing". The thing
    /// itself is never touched: it stays in Your things and on its other templates.
    private func takeOffCard(_ t: TakingOff, list: PackList) -> some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
                .onTapGesture { takingOff = nil }
            VStack(spacing: 14) {
                SVGPath.path("M6 6L18 18M18 6L6 18")
                    .stroke(style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                    .frame(width: 22, height: 22)
                    .foregroundStyle(AppSection.actions.color)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(AppSection.actions.color.opacity(0.14)))
                Text("Take \u{201C}\(t.name)\u{201D} off \u{201C}\(list.name)\u{201D}?")
                    .font(.system(size: 19, weight: .heavy)).foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("template-remove-question")
                Text("It stays in Your things and on your other templates.")
                    .font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 12) {
                    Button { takingOff = nil } label: {
                        Text("Keep it")
                    }
                    .buttonStyle(HeaderButtonStyle(tint: Theme.ink, filled: false, stretch: true)).focusEffectDisabled()
                    .accessibilityIdentifier("template-remove-no")
                    Button {
                        model.change { _ = $0.removeFromTemplate(templateId: listId, memId: t.memId) }
                        takingOff = nil
                    } label: {
                        Text("Take it off")
                    }
                    .buttonStyle(HeaderButtonStyle(tint: AppSection.actions.color, filled: true, stretch: true)).focusEffectDisabled()
                    .accessibilityIdentifier("template-remove-yes")
                }
                .padding(.top, 4)
            }
            .padding(22)
            .frame(maxWidth: 360)
            .background(RoundedRectangle(cornerRadius: 18).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.line, lineWidth: 1))
            .shadow(color: .black.opacity(0.25), radius: 20, y: 8)
            .padding(24)
        }
        .transition(.opacity)
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
    /// Only on some trips (his ask, 2 Oct 2026): none = always comes along.
    @State private var seasons: Set<String> = []
    @State private var contexts: Set<String> = []
    @State private var transports: Set<String> = []
    @State private var catering: Set<String> = []

    var body: some View {
        let found = model.library.row(templateId: templateId, memId: memId)
        let thing = found?.thing ?? Item()
        let list = model.library.templates.first { $0.id == templateId } ?? newList()
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(HeaderButtonStyle(tint: Theme.muted, filled: false)).focusEffectDisabled()
                    .font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.muted)
                    .accessibilityIdentifier("row-cancel")
                Spacer()
                Button("Save") { save() }
                    .buttonStyle(HeaderButtonStyle(tint: AppSection.templates.color, filled: true)).focusEffectDisabled()
                    .font(.system(size: 17, weight: .bold)).foregroundStyle(AppSection.templates.color)
                    .accessibilityIdentifier("row-save")
            }
            .padding(16)
            KeyboardAwayScroll {
                // Headings 20 apart, each field 4 under its own (his screenshot, 2026-09-28).
                VStack(alignment: .leading, spacing: 20) {
                    Text(thing.name).font(.system(size: 22, weight: .heavy)).foregroundStyle(Theme.ink)
                    Text("On \(list.name)").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.muted)
                    Pills(title: "Bag on this template", options: [("", "Same as the thing (\(thing.container))")]
                            + containerNames(model.library.resolvedTemplates()).map { ($0, $0) },
                          selected: [bag], id: "row-bag", tint: AppSection.templates.color) { bag = $0 }
                    Pills(title: "When, on this template", options: [("", "Same as the thing (\(phaseLabel(thing.phase)))")]
                            + PHASES.map { ($0.id, $0.label) },
                          selected: [when], id: "row-when", tint: AppSection.templates.color) { when = $0 }
                    if !list.sections.isEmpty {
                        Pills(title: "Section of this template", options: [("", "No section")] + list.sections.map { ($0.id, $0.name) },
                              selected: [section], id: "row-section", tint: AppSection.templates.color) { section = $0 }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                    Text("A new section").font(.system(size: 14, weight: .heavy)).foregroundStyle(Theme.muted)
                    HStack(spacing: 8) {
                        field($newSectionName, "e.g. Lights", "row-section-new")
                        Button { addSection() } label: {
                            Text("Add").font(.system(size: 16, weight: .bold))
                                .foregroundStyle(jsTrim(newSectionName).isEmpty ? Theme.muted : Color.white)
                                .padding(.horizontal, 16).frame(minHeight: 44)
                                .background(RoundedRectangle(cornerRadius: 10).fill(jsTrim(newSectionName).isEmpty ? Theme.line : AppSection.templates.color))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).focusEffectDisabled()
                        .disabled(jsTrim(newSectionName).isEmpty)
                        .accessibilityIdentifier("row-section-add")
                    }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("How many").font(.system(size: 14, weight: .heavy)).foregroundStyle(Theme.muted)
                        field($qty, "e.g. 2, or 2 pairs", "row-qty")
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Note").font(.system(size: 14, weight: .heavy)).foregroundStyle(Theme.muted)
                        field($note, "e.g. with the red filter", "row-note")
                    }
                    Text("Blank means the same as the thing itself, so a change to the thing still reaches this template.")
                        .font(.system(size: 14)).foregroundStyle(Theme.muted)

                    // Only on some trips — per template, as the web app keeps it: a towel
                    // can be summer-only on Beach and always on Swim (his ask, 2 Oct 2026).
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle(title: "Only on some trips", tint: AppSection.templates.color)
                        Text("Leave these off and it always comes along. Pick one or more and it comes only on trips that match — on this template.")
                            .font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        Pills(title: "Season", options: SEASONS.map { ($0, $0) }, selected: seasons,
                              id: "row-seasons", tint: AppSection.templates.color) { toggle(&seasons, $0) }
                        // Context narrows only workout (WET) templates, as the trip builder reads it.
                        if contextApplies(list) {
                            Pills(title: "Context", options: CONTEXTS.map { ($0, $0) }, selected: contexts,
                                  id: "row-contexts", tint: AppSection.templates.color) { toggle(&contexts, $0) }
                        }
                        Pills(title: "Transport", options: TRANSPORTS.map { ($0, $0) }, selected: transports,
                              id: "row-transports", tint: AppSection.templates.color) { toggle(&transports, $0) }
                        Pills(title: "Food", options: CATERING.map { ($0.id, HomeScreen.shortFood($0.id, $0.label)) },
                              selected: catering, id: "row-catering", tint: AppSection.templates.color) { toggle(&catering, $0) }
                    }
                    .padding(.top, 6)
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .onAppear {
            guard let f = model.library.row(templateId: templateId, memId: memId) else { return }
            bag = f.membership.container; when = f.membership.phase
            qty = f.membership.qty; note = f.membership.note; section = f.membership.section
            seasons = Set(f.membership.seasons); contexts = Set(f.membership.contexts)
            transports = Set(f.membership.transports); catering = Set(f.membership.catering)
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

    private func toggle(_ set: inout Set<String>, _ value: String) {
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
    }

    private func save() {
        let (b, w, q, n, s) = (bag, when, qty, note, section)
        // In the app's own order, so the stored lists read the same every time.
        let se = SEASONS.filter(seasons.contains), co = CONTEXTS.filter(contexts.contains)
        let tr = TRANSPORTS.filter(transports.contains), ca = CATERING.map(\.id).filter(catering.contains)
        model.change {
            _ = $0.updateMembership(memId: memId) { m in
                m.container = b; m.phase = w; m.qty = jsTrim(q); m.note = jsTrim(n); m.section = s
                m.seasons = se; m.contexts = co; m.transports = tr; m.catering = ca
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
