import SwiftUI
import PackingCore
import PackingLibrary

/// The Templates tab: every template, grouped the way he organises his life —
/// always packed, by transport, then his activity groups.
struct TemplatesScreen: View {
    @EnvironmentObject var model: LibraryModel
    /// What the tab has open. ONE sheet with a destination, not three sheets (a
    /// template, Search, New): SwiftUI does not reliably present a second sheet on a
    /// view while the first is still closing — the trap met in Search (0.17), and
    /// flagged here by the spec pass (5 Oct 2026).
    @State private var opened: Opened?
    /// A template just made: opened as soon as New has closed.
    @State private var madeNow: String?

    enum Opened: Identifiable, Equatable {
        case template(String), search, new
        var id: String {
            switch self {
            case .template(let id): return "template:" + id
            case .search: return "search"
            case .new: return "new"
            }
        }
    }

    /// One activity area (GA, WET…, or Always packed, By transport, Other) and its
    /// templates. The template's stored field is still called `group`, as the web app
    /// reads it; only the word he sees changed (field test, Oct 2026).
    struct ActivityArea: Identifiable { let id: String; let title: String; let lists: [PackList] }

    static func activityAreas(_ all: [PackList]) -> [ActivityArea] {
        var out: [ActivityArea] = []
        func add(_ id: String, _ title: String, _ lists: [PackList]) { if !lists.isEmpty { out.append(ActivityArea(id: id, title: title, lists: lists)) } }
        add("base", "Always packed", all.filter { $0.role == "base" })
        add("transport", "By transport", all.filter { $0.role == "transport" })
        for g in GROUPS { add(g.id, g.label, orderActivities(g.id, all.filter { $0.role.isEmpty && $0.group == g.id })) }
        add("other", "Other templates", all.filter { $0.role.isEmpty && $0.group.isEmpty })
        // Bags are not an activity: they have their own screen, on Care (as in the
        // web app), where each gets a weight limit.
        return out
    }

    /// "GA · GOAL ACTIVITY" — his code, then the words, as he wrote them.
    static func areaHeading(_ area: ActivityArea) -> String {
        let code = GROUPS.first { $0.id == area.id }?.id ?? ""
        return groupHeading(code, area.title)
    }

    /// "15 templates · 431 things · 4 trips packed from them" — the things ON them
    /// and the trips packed FROM them, so the words match the numbers (the spec pass:
    /// it counted every thing he owns and every trip).
    static func summary(_ lists: [PackList], _ library: Library) -> String {
        let n = library.templateSummary(lists)
        var parts = ["\(n.templates) template\(n.templates == 1 ? "" : "s")",
                     "\(n.things) thing\(n.things == 1 ? "" : "s")"]
        if n.trips > 0 { parts.append("\(n.trips) trip\(n.trips == 1 ? "" : "s") packed from them") }
        return parts.joined(separator: " · ")
    }

    /// "Your templates", with the search and + New beside it — on ONE centre line
    /// (ScreenHeader; his note on 0.63, "Overall, icons are not aligned"): the tab's first
    /// line on the iPhone, pinned in the window's title bar strip on the Mac.
    private func header(_ flat: [PackList]) -> some View {
        ScreenHeader(title: "Your templates", tint: AppSection.templates.color, id: "templates-heading",
                     line: TemplatesScreen.summary(flat, model.library), lineId: "templates-summary") {
            SearchButton { opened = .search }
            Button { opened = .new } label: {
                Text("+ New")
                    .font(.system(.subheadline, weight: .semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 12).frame(minHeight: Metrics.chip)
                    .background(Capsule().fill(AppSection.templates.color))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain).focusEffectDisabled()
            .accessibilityIdentifier("templates-new")
        }
        .padding(.bottom, 4)
    }

    var body: some View {
        let areas = TemplatesScreen.activityAreas(model.library.shownTemplates())
        let flat = areas.flatMap(\.lists)
        let use = model.library.templateUse(today: Today.local)
        KeyboardAwayScroll {
            LazyVStack(alignment: .leading, spacing: 8) {
                // On the Mac the header is pinned in the window's title bar strip
                // instead (`headerOnTheMac`, below).
                #if !os(macOS)
                header(flat)
                #endif
                // What his trip reviews say a list carries for nothing (roadmap stop E).
                RefineDoor().environmentObject(model)
                    .padding(.bottom, 4)
                ForEach(areas) { area in
                    // His own code beside the name, as the web app has it:
                    // "GA · GOAL ACTIVITY".
                    Text(TemplatesScreen.areaHeading(area))
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                        .padding(.top, 16)
                        .accessibilityIdentifier("templates-area-\(area.id)")
                    // Two across: more of his lists at a glance, as the web app shows them.
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                              spacing: 8) {
                        ForEach(area.lists, id: \.id) { list in
                            Button { opened = .template(list.id) } label: { TemplateCard(list: list, use: use[list.id]) }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("template-row-\(flat.firstIndex { $0.id == list.id } ?? 0)")
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .headerOnTheMac { header(flat) }
        .sheet(item: $opened, onDismiss: {
            // Straight into a template just made: a list he cannot see the inside of
            // is not made yet. Opened once New has gone, never on top of it.
            if let id = madeNow { madeNow = nil; opened = .template(id) }
        }) { destination in
            switch destination {
            case .template(let id): TemplateDetail(listId: id).environmentObject(model)
            case .search: SearchScreen().environmentObject(model)
            case .new:
                NewList(made: { list in
                    model.change { $0.saveTemplate(list) }
                    madeNow = list.id
                }, library: model.library)
            }
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
                Text("\(list.items.filter { !Library.isReminder($0) }.count)")
                    .font(.system(.subheadline, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Theme.muted)
            }
            Text(list.name)
                .font(.system(.callout, weight: .semibold)).foregroundStyle(Theme.ink)
                .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            Text(Library.TemplateUse.line(use, today: Today.local))
                .font(.system(.caption))
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

/// A template's face: ITS colour, and the icon he chose — or the one its name
/// suggests (approved 2 Oct 2026) — drawn in the app's own hand; else its first
/// letter. Never an emoji, even one a template brought from the web app.
struct Cover: View {
    let list: PackList
    var size: Double = 40

    var body: some View {
        // White on the template's own colour (never teal: his colour notes).
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28).fill(Color(hexString: Library.coverColour(list)))
            if let icon = TemplateIcons.icon(Library.icon(of: list)) {
                IconMark(path: icon.path, size: size * 0.66).foregroundStyle(.white)
            } else {
                Text(Library.coverLetter(list))
                    .font(.system(size: size * 0.46, weight: .heavy))
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
        let tint = Color(hexString: Library.coverColour(list))
        let rows = stride(from: 0, to: TemplateIcons.all.count, by: columns).map {
            Array(TemplateIcons.all[$0..<min($0 + columns, TemplateIcons.all.count)])
        }
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Cover(list: list, size: 40)
                Text(list.name).font(.system(.title3, weight: .bold)).foregroundStyle(Theme.ink)
                    .lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                Button("Cancel") { dismiss() }
                    .buttonStyle(HeaderButtonStyle(tint: Theme.muted, filled: false)).focusEffectDisabled()
                    .keyboardShortcut(.cancelAction)            // Escape = Cancel, never Save (Escape everywhere, 5 Oct 2026)
                    .accessibilityIdentifier("icon-cancel")
            }
            .padding(16)
            KeyboardAwayScroll {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        choice(title: "Suggested", on: chosen == nil, id: "icon-suggested", tint: tint) {
                            if let s = Library.suggestedIcon(for: list), let icon = TemplateIcons.icon(s) {
                                IconMark(path: icon.path, size: 30)
                            } else { Text(Library.coverLetter(list)).font(.system(.title3, weight: .bold)) }
                        } pick: { pick(nil) }
                        choice(title: "Letter", on: chosen == Library.letterIcon, id: "icon-letter", tint: tint) {
                            Text(Library.coverLetter(list)).font(.system(.title3, weight: .bold))
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
                Text(title).font(.system(.caption, weight: .semibold))
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
    /// What Add was missing, said under the field (never a grey button).
    @State private var addNeeds = ""
    /// Why Rename could not take the name.
    @State private var renameNeeds = ""
    @State private var editingRow: String?
    /// What he is typing over the name, while he is typing it.
    @State private var renaming: String?
    @FocusState private var writingName: Bool
    @State private var askingToDelete = false
    /// The iPhone's keyboard is up: Counts as and the area / Delete row step aside, so the
    /// list keeps room for the field being typed in (a reminder's, at the list's top, was
    /// hidden under them once Counts as joined the foot — the 0.68–0.71 merge).
    @State private var keyboardUp = false
    /// Choosing the template's activity area again (the spec pass, 5 Oct 2026: New
    /// asks for it, and nothing could put a wrong answer right).
    @State private var choosingArea = false
    /// The row whose ✕ was pressed — it asks first (his test H.5).
    @State private var takingOff: TakingOff?
    /// How the things are grouped (his test H.3: "group and sort the items in a
    /// template in the same way as when you pack"). "" = the template's own way:
    /// its sections, or When when it has none. Remembered on this device.
    @AppStorage("ams.template.grouping") private var groupingRaw = ""
    /// What he is looking for on this template — his ask (4 Oct 2026): "add a search
    /// function so that the user can find a specific item without the need to scroll."
    @State private var finding = ""
    /// Arranging the template: a grip on every heading and every thing, held and
    /// dragged to its place — his choice of three pictures, "C" (5 Oct 2026).
    @State private var arranging = false
    /// The heading whose name is being changed while arranging, and what he typed.
    @State private var renamingHeading: String?
    @State private var headingName = ""
    /// Why Save could not take the heading's new name.
    @State private var headingNeeds = ""
    @FocusState private var writingHeading: Bool

    struct TakingOff: Equatable { let memId: String; let name: String }

    var body: some View {
        let list = model.library.resolvedTemplate(id: listId) ?? newList()
        // The things; the template's reminders have their own block (0.70, spec 07 part 12).
        let rows = list.items.filter { !Library.isReminder($0) }
        // His lists are built in SECTIONS (511 of his 538 rows sit in one), so that
        // is how a list reads here. A list with no sections falls back to "When".
        let sectioned = rows.contains { !$0.section.isEmpty }
        let ways: [ThingGrouping] = (sectioned ? [.section] : []) + [.when, .into, .fromWhere, .kind, .name]
        let grouping = ThingGrouping(rawValue: groupingRaw).flatMap { ways.contains($0) ? $0 : nil } ?? ways[0]
        // Arranging moves headings and the things under them, so it is offered while
        // the page reads by its headings — or on a template with none, arranged as
        // the one list a trip reads.
        let canArrange = grouping == .section || !ways.contains(.section)
        // Only the rows whose name holds what he typed, each still under its own
        // heading; a heading with none of them goes. The pills above are worked out
        // from the WHOLE template, so they stay put while he searches.
        let q = normName(finding)
        let found = q.isEmpty ? rows : rows.filter { normName($0.name).contains(q) }
        let groups: [(title: String, colour: Color?, items: [Item])] = grouping == .when
            ? entriesByPhase(found)
                .filter { !$0.entries.isEmpty }
                .map { ($0.phase.label, Color(hexString: readableHex($0.phase.color, dark: scheme == .dark)), $0.entries) }
            : grouping.groups(found, sections: list.sections)
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
                    .font(.system(.title3, weight: .bold)).foregroundStyle(Theme.ink)
                    .focused($writingName)
                    .onSubmit { saveName(list) }
                    .accessibilityIdentifier("template-name")
                // Always in colour; a name that cannot be taken is said under the row.
                if let wanted = renaming, jsTrim(wanted) != jsTrim(list.name) {
                    Button { saveName(list) } label: {
                        Text("Rename").font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(AppSection.templates.color)
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("template-rename")
                }
                Spacer()
                ShareDoor(id: "template-share", tint: AppSection.templates.color) {
                    ShareOffer(title: "Share \u{201C}\(list.name)\u{201D}", link: model.library.shareLink(templateId: list.id))
                }
                Button("Done") { dismiss() }
                    .buttonStyle(HeaderButtonStyle(tint: AppSection.templates.color, filled: true))
                    .focusEffectDisabled()
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(AppSection.templates.color)
                    // Escape closes it, as Done does (Escape everywhere, 5 Oct 2026) — except
                    // while arranging, when Escape ends Arrange instead (the Arrange pill).
                    .keyboardShortcut(arranging ? nil : .cancelAction)
                    .accessibilityIdentifier("template-detail-done")
            }
            .needsLine($renameNeeds, typed: renaming ?? "", id: "template-rename-needs")
            .padding(16)
            // Group the things the ways a trip sorts (his H.3), in sight above the list.
            FlowRow(spacing: 6) {
                Text("Group").font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.muted)
                    .frame(minHeight: Metrics.chip)
                        ForEach(ways, id: \.self) { way in
                            // While arranging, the page reads by its headings (or as one
                            // list, when it has none): no other way is lit.
                            let on = way == grouping && !(arranging && way != .section)
                            Button {
                                groupingRaw = way.rawValue
                                // Another way of reading the page ends arranging.
                                endArranging()
                            } label: {
                                Text(way.label).font(.system(.subheadline, weight: on ? .semibold : .regular))
                                    .foregroundStyle(on ? Color.white : Theme.ink)
                                    .padding(.horizontal, 12).frame(minHeight: Metrics.chip)
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
            if canArrange && (!rows.isEmpty || !list.sections.isEmpty) { arrangeDoor() }
            // Find a thing without scrolling (his ask, 4 Oct 2026). Not on a template
            // with nothing on it yet — there is nothing to find there. Not while
            // arranging: every heading and thing is in view then, in its place.
            if !arranging && (!rows.isEmpty || !finding.isEmpty) {
                HStack(spacing: 10) {
                    TextField("Find a thing on this template", text: $finding)
                        .textFieldStyle(.plain)
                        .font(.system(.body)).foregroundStyle(Theme.ink)
                        .clearButton($finding, id: "template-find")
                        .padding(.horizontal, 12).frame(minHeight: Metrics.compact)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                    // How many of the template's rows the search shows — only while it finds
                    // something; "0 of 4" would say again what the line under it says.
                    if !q.isEmpty && !found.isEmpty {
                        Text("\(found.count) of \(rows.count)")
                            .font(.system(.subheadline, weight: .semibold).monospacedDigit()).foregroundStyle(Theme.muted)
                            .fixedSize()
                            .accessibilityIdentifier("template-find-count")
                    }
                }
                .padding(.horizontal, 16).padding(.top, 6)
            }
            if arranging {
                arrangeList(list)
            } else {
                KeyboardAwayScroll {
                    VStack(alignment: .leading, spacing: 0) {
                    // His reminders for this template (0.70), above the things — outside the
                    // lazy stack, which would throw away what he is typing as it scrolls.
                    if q.isEmpty {
                        TemplateRemindersBlock(templateId: listId).environmentObject(model)
                            .padding(.horizontal, 16)
                    }
                    // No space between rows: each is as tall as its words (`Metrics.line`).
                    // His words (6 Oct 2026, testing 0.63): "Far too much line spacing between
                    // the items in a template … Change this dramatically, not only a bit" —
                    // 42 points top to top until 0.67.
                    LazyVStack(alignment: .leading, spacing: 0) {
                        // A search that finds nothing says so, quietly, where the rows were.
                        if !q.isEmpty && groups.isEmpty {
                            Text("Nothing on this template is called that.")
                                .font(.system(.callout)).foregroundStyle(Theme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 16)
                                .accessibilityIdentifier("template-find-none")
                        }
                        ForEach(Array(groups.enumerated()), id: \.offset) { g, group in
                            // Less air above a heading (16 points and a 6-point gap until 0.67).
                            Text(group.title)
                                .font(.headline)
                                .foregroundStyle(group.colour ?? AppSection.templates.color)
                                .padding(.top, 10).padding(.bottom, 2)
                                .accessibilityIdentifier("template-group-\(g)")
                            ForEach(group.items, id: \.memId) { item in
                                let n = index[item.memId ?? ""] ?? 0
                                HStack(spacing: 4) {
                                    Button { editingRow = item.memId } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 0) {
                                                Text(item.name).font(.system(.body)).foregroundStyle(Theme.ink)
                                                if !item.qty.isEmpty || !item.note.isEmpty {
                                                    Text([item.qty.isEmpty ? "" : "×\(item.qty)", item.note]
                                                            .filter { !$0.isEmpty }.joined(separator: " · "))
                                                        .font(.system(.footnote)).foregroundStyle(Theme.muted).lineLimit(1)
                                                }
                                                // Only on some trips, said on the row (field test 4.4, 3 Oct 2026)
                                                // — only what a trip reads on this template.
                                                let tags = Library.onlyOnWords(item, on: list)
                                                if !tags.isEmpty {
                                                    Text(tags).font(.system(.footnote, weight: .semibold))
                                                        .foregroundStyle(AppSection.templates.color).lineLimit(1)
                                                }
                                            }
                                            Spacer(minLength: 8)
                                            Text(item.container).font(.system(.subheadline)).foregroundStyle(Theme.muted).lineLimit(1)
                                        }
                                        .padding(.vertical, 2).frame(minHeight: Metrics.line).contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("template-item-\(n)")
                                    Button {
                                        if let mid = item.memId { withAnimation(.easeOut(duration: 0.15)) { takingOff = TakingOff(memId: mid, name: item.name) } }
                                    } label: {
                                        // ✕ beside the bag, on the row's own line, no taller than it.
                                        SVGPath.path("M6 6L18 18M18 6L6 18")
                                            .stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                                            .onGrid(Metrics.glyph).foregroundStyle(Theme.muted)
                                            .frame(width: Metrics.lineButton, height: Metrics.line).contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain).focusEffectDisabled()
                                    .accessibilityIdentifier("template-item-\(n)-remove")
                                    .accessibilityLabel("Take \(item.name) off this template")
                                }
                                .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
                                // A row whose number changes is built afresh: kept, it kept its
                                // OLD number — the Map, the only row a search left, still said
                                // "template-item-1" (4 Oct 2026), as the Mac did on Your things.
                                .id("\(item.memId ?? "")#\(n)")
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                    }
                }
            }
            // While a heading's name is being changed the keyboard is up: the foot
            // steps aside, so the name, Save and Remove heading stay in sight (seen
            // on the screen, 5 Oct 2026: the list was left a sliver).
            if renamingHeading == nil {
                // Things he already owns, picked from the whole list (his H.9 — the one red
                // box of the test); or a new one typed beside it.
                PickThingsDoor(templateId: listId).environmentObject(model)
                    .padding(.horizontal, 16).padding(.top, 10)
                HStack(spacing: 8) {
                    TextField("Or type a new thing", text: $newName)
                        .textFieldStyle(.plain)
                        .font(.system(.body)).foregroundStyle(Theme.ink)
                        .padding(.horizontal, 12).frame(minHeight: Metrics.tap)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                        .onSubmit { add() }
                        .accessibilityIdentifier("template-add-name")
                    Button { add() } label: { FieldButtonLabel(title: "Add", tint: AppSection.templates.color) }
                        .buttonStyle(.plain).focusEffectDisabled()
                        .accessibilityIdentifier("template-add")
                }
                .needsLine($addNeeds, typed: newName, id: "template-add-needs")
                .padding(.horizontal, 16).padding(.vertical, 10)

                if askingToDelete {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Delete “\(list.name)”?")
                            .font(.system(.callout, weight: .semibold)).foregroundStyle(Theme.ink)
                        Text("The template and its \(list.items.count) row\(list.items.count == 1 ? "" : "s") go. The THINGS stay — they are still in Your things and on any other template.")
                            .font(.system(.footnote)).foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 10) {
                            Button("Keep it") { askingToDelete = false }
                                .buttonStyle(.plain).focusEffectDisabled()
                                .font(.system(.callout, weight: .semibold)).foregroundStyle(Theme.ink)
                                .accessibilityIdentifier("template-delete-no")
                            Spacer()
                            Button {
                                model.change { _ = $0.deleteTemplate(id: listId) }
                                dismiss()
                            } label: {
                                Text("Delete the template")
                                    .font(.system(.callout, weight: .semibold)).foregroundStyle(.white)
                                    .padding(.horizontal, 12).frame(minHeight: Metrics.compact)
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
                } else if choosingArea {
                    areaCard(list)
                } else if !keyboardUp {
                    // Which Apple Health workout it meets in the trip review (0.70).
                    if list.role.isEmpty {
                        CountsAsField(list: list).environmentObject(model)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16).padding(.bottom, 6)
                    }
                    HStack(spacing: 8) {
                        // Only an activity template lives in an area; always packed and
                        // transport templates are filed by what they do.
                        if list.role.isEmpty { areaDoor(list) }
                        SmallDeleteButton(title: "Delete template", id: "template-delete") { askingToDelete = true }
                    }
                    .padding(.horizontal, 16).padding(.bottom, 8)
                }
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        #if os(iOS)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in keyboardUp = true }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in keyboardUp = false }
        #endif
        .overlay { if let t = takingOff { takeOffCard(t, list: list) } }
        .sheet(item: Binding(get: { editingRow.map { Editing(id: $0) } }, set: { editingRow = $0?.id })) { e in
            RowEditor(templateId: listId, memId: e.id).environmentObject(model)
        }
        .onChange(of: canArrange) { _, offered in if !offered { endArranging() } }
        // While arranging, the page is not swiped away — a drag that strays to its top
        // would close it mid-move — and the iPhone's own ⌘. (which closes an untouched
        // sheet by itself) leaves Escape to Arrange. Done still closes it.
        .interactiveDismissDisabled(arranging)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("template-detail")
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 600)
        #endif
    }

    // MARK: Arranging (his layout "C", 5 Oct 2026)

    /// "Arrange", a pill under the Group pills — filled while on — and, while on, how
    /// it works in one line under it.
    private func arrangeDoor() -> some View {
        let tint = AppSection.templates.color
        return VStack(alignment: .leading, spacing: 4) {
            Button {
                if arranging { endArranging() } else {
                    finding = ""
                    withAnimation(.easeOut(duration: 0.15)) { arranging = true }
                }
            } label: {
                Text("Arrange").font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(arranging ? Color.white : tint)
                    .padding(.horizontal, 12).frame(minHeight: Metrics.chip)
                    .background(Capsule().fill(arranging ? tint : tint.opacity(0.10)))
                    .overlay(Capsule().stroke(tint, lineWidth: 1))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain).focusEffectDisabled()
            // Escape while arranging ends it, as a second tap does — and a heading's
            // name typed but not saved is dropped, never saved (Escape everywhere: never a
            // save). The page itself stays open; a second Escape closes it.
            .keyboardShortcut(arranging ? .cancelAction : nil)
            .accessibilityIdentifier("template-arrange")
            .accessibilityAddTraits(arranging ? .isSelected : [])
            if arranging {
                Text("Hold \u{2261} and drag a heading or a thing to its place.")
                    .font(.system(.footnote)).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("template-arrange-hint")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16).padding(.bottom, 4)
    }

    private func endArranging() {
        renamingHeading = nil
        headingNeeds = ""
        writingHeading = false
        withAnimation(.easeOut(duration: 0.15)) { arranging = false }
    }

    /// The page while arranging: ONE list of headings and things, so one drag can
    /// carry a thing from under one heading to under another.
    ///
    /// SwiftUI's own `List` with `onMove`: the one way of dragging rows that works the
    /// same with a finger on the iPhone (hold, then drag) and with the mouse on the
    /// Mac, scrolls the list while a row is carried, and needs no edit mode — whose
    /// system grips and red delete buttons are Apple's art, not the app's. The grip
    /// drawn on each line is the app's own; the list does the carrying. The drop
    /// itself is read by the model (`dropLine`), where it is tested.
    private func arrangeList(_ list: PackList) -> some View {
        let lines = model.library.arrangeLines(templateId: listId)
        var rowsById: [String: Item] = [:]
        for item in list.items { if let m = item.memId, rowsById[m] == nil { rowsById[m] = item } }
        var place: [String: Int] = [:]          // a thing's number, as read top to bottom
        for line in lines { if case .row(let m) = line, place[m] == nil { place[m] = place.count } }
        return List {
            ForEach(lines, id: \.self) { line in
                arrangeLine(line, list: list, rows: rowsById, place: place)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Theme.bg)
                    // "Everything else" is where things under no heading are, not a
                    // heading of his: it stays put. A heading being renamed too.
                    .moveDisabled(line == .rest || (renamingHeading != nil && line == .heading(renamingHeading!)))
            }
            .onMove { from, to in
                guard let at = from.first else { return }
                model.change { _ = $0.dropLine(templateId: listId, from: at, to: to) }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 1)
        .background(Theme.bg)
        #if os(macOS)
        // The Mac's list takes Escape for itself as well when it has focus.
        .onExitCommand { endArranging() }
        #endif
        .accessibilityIdentifier("arrange-list")
    }

    @ViewBuilder
    private func arrangeLine(_ line: Library.ArrangeLine, list: PackList, rows: [String: Item], place: [String: Int]) -> some View {
        let tint = AppSection.templates.color
        switch line {
        case .heading(let id):
            if let k = list.sections.firstIndex(where: { $0.id == id }) {
                let section = list.sections[k]
                if renamingHeading == id {
                    headingEditor(section)
                } else {
                    HStack(spacing: 8) {
                        // The heading's name: tapped, it can be renamed or removed.
                        Button {
                            renamingHeading = id
                            headingName = section.name
                            headingNeeds = ""
                            writingHeading = true
                        } label: {
                            Text(section.name).font(.headline).foregroundStyle(tint)
                                .multilineTextAlignment(.leading)
                                .frame(minHeight: Metrics.tap).contentShape(Rectangle())
                        }
                        .buttonStyle(.borderless).focusEffectDisabled()
                        .accessibilityIdentifier("arrange-heading-\(k)")
                        .accessibilityHint("Rename or remove this heading")
                        Spacer(minLength: 8)
                        GripMark(id: "arrange-heading-\(k)-grip", label: "Move the heading \(section.name)",
                                 heading: true, tint: tint)
                    }
                    .padding(.top, 10)
                }
            }
        case .rest:
            Text("Everything else").font(.headline).foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity, minHeight: Metrics.tap, alignment: .leading)
                .padding(.top, 10)
                .accessibilityIdentifier("arrange-heading-rest")
        case .row(let id):
            if let item = rows[id] {
                let n = place[id] ?? 0
                HStack(spacing: 8) {
                    Text(item.name).font(.body).foregroundStyle(Theme.ink).lineLimit(1)
                        .accessibilityIdentifier("arrange-item-\(n)")
                    Spacer(minLength: 8)
                    GripMark(id: "arrange-item-\(n)-grip", label: "Move \(item.name)")
                }
                .frame(minHeight: Metrics.row)
                .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
                .contentShape(Rectangle())
            }
        }
    }

    /// A heading's name, being changed: the field with Save, and a quiet red "Remove
    /// heading" — which asks nothing, because nothing is lost: its things stay on
    /// the template, under no heading.
    private func headingEditor(_ section: TemplateSection) -> some View {
        let tint = AppSection.templates.color
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField("Heading", text: $headingName)
                    .textFieldStyle(.plain)
                    .font(.system(.body)).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 12).frame(minHeight: Metrics.tap)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.bg))
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(headingNeeds.isEmpty ? Theme.line : AppSection.actions.color, lineWidth: 1))
                    .focused($writingHeading)
                    .onSubmit { saveHeading(section) }
                    #if os(macOS)
                    // 🪤 On the Mac a text field takes Escape for itself, so the Arrange
                    // pill's shortcut never heard it (GitHub's Mac run, 6 Oct 2026): end
                    // Arrange here too — the half-typed name dropped, never saved.
                    .onExitCommand { endArranging() }
                    #endif
                    .accessibilityIdentifier("arrange-heading-field")
                Button { saveHeading(section) } label: { FieldButtonLabel(title: "Save", tint: tint) }
                    .buttonStyle(.borderless).focusEffectDisabled()
                    .accessibilityIdentifier("arrange-heading-save")
            }
            .needsLine($headingNeeds, typed: headingName, id: "arrange-heading-needs")
            HStack(spacing: 8) {
                Button {
                    model.change { _ = $0.removeSection(templateId: listId, sectionId: section.id) }
                    renamingHeading = nil
                    writingHeading = false
                } label: {
                    Text("Remove heading").font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(AppSection.actions.color)
                        .frame(minHeight: Metrics.compact).contentShape(Rectangle())
                }
                .buttonStyle(.borderless).focusEffectDisabled()
                .accessibilityIdentifier("arrange-heading-remove")
                Text("Its things stay, under no heading.")
                    .font(.system(.footnote)).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(tint, lineWidth: 1))
        .padding(.vertical, 6)
    }

    /// Save a heading's new name — never one the template already has (two
    /// "Lights" would read as one on a trip, which merges headings by name).
    private func saveHeading(_ section: TemplateSection) {
        let wanted = jsTrim(headingName)
        guard !wanted.isEmpty else { headingNeeds = "Type a name first."; return }
        guard !model.library.sectionNameTaken(templateId: listId, name: wanted, except: section.id) else {
            headingNeeds = "This template already has a heading called that."
            return
        }
        model.change { _ = $0.renameSection(templateId: listId, sectionId: section.id, to: wanted) }
        renamingHeading = nil
        writingHeading = false
    }

    /// Is this name free — nobody else's, and not blank?
    private func nameFree(_ wanted: String, _ list: PackList) -> Bool {
        !normName(wanted).isEmpty && !model.library.templateNameTaken(wanted, except: listId)
    }

    private func saveName(_ list: PackList) {
        guard let wanted = renaming else { return }
        guard nameFree(wanted, list) else {
            renameNeeds = normName(wanted).isEmpty ? "Type a name first." : "You already have a template called that."
            return
        }
        model.change { _ = $0.renameTemplate(id: listId, to: wanted) }
        renaming = nil
        writingName = false
    }

    /// The area it lives in, as a quiet button beside Delete — rarely wanted, never
    /// in the way of the rows.
    private func areaDoor(_ list: PackList) -> some View {
        Button { withAnimation(.easeOut(duration: 0.15)) { choosingArea = true } } label: {
            Text("Activity area: \(list.group.isEmpty ? "none" : list.group)")
                .font(.system(.subheadline, weight: .semibold)).foregroundStyle(AppSection.templates.color)
                .lineLimit(1)
                .frame(minHeight: Metrics.chip).contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier("template-area")
        .accessibilityValue(list.group.isEmpty ? "none" : list.group)
    }

    /// The question New asks, asked again: one press files it, and the card goes.
    private func areaCard(_ list: PackList) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("In which activity area should it live?")
                    .font(.system(.callout, weight: .semibold)).foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Button("Cancel") { choosingArea = false }
                    .buttonStyle(HeaderButtonStyle(tint: Theme.muted, filled: false)).focusEffectDisabled()
                    .accessibilityIdentifier("template-area-cancel")
            }
            .padding(.bottom, 6)
            ForEach(GROUPS.map { ($0.id, "\($0.id) · \($0.label)") } + [("", "No activity area")], id: \.0) { id, label in
                let on = list.group == id
                Button {
                    model.change { _ = $0.setTemplateArea(id: listId, area: id) }
                    choosingArea = false
                } label: {
                    HStack {
                        Text(label)
                            .font(.system(.callout, weight: on ? .semibold : .regular))
                            .foregroundStyle(on ? AppSection.templates.color : Theme.ink)
                        Spacer()
                    }
                    .frame(minHeight: Metrics.tap).contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
                .accessibilityIdentifier("template-area-\(id.isEmpty ? "none" : id)")
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppSection.templates.color, lineWidth: 1))
        .padding(.horizontal, 16).padding(.bottom, 10)
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
                    .font(.system(.body, weight: .semibold)).foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("template-remove-question")
                Text("It stays in Your things and on your other templates.")
                    .font(.system(.subheadline)).foregroundStyle(Theme.muted)
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
        guard !jsTrim(name).isEmpty else { addNeeds = "Type a thing first."; return }
        // Typed again, a thing already here would sit on the template twice — a slip,
        // so it is said instead (the spec pass, 5 Oct 2026).
        guard !model.library.isOnTemplate(templateId: listId, name: name) else {
            addNeeds = "\u{201C}\(jsTrim(name))\u{201D} is already on this template."
            return
        }
        model.change { _ = $0.addToTemplate(templateId: listId, name: name) }
        newName = ""
        // A search left on would hide the new thing unless its name happens to match
        // — and then Add looks as if it did nothing. So the whole template comes back.
        finding = ""
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
    /// A section typed here, waiting for Save: it is made only then, so Cancel leaves
    /// the template as it was (the spec pass, 5 Oct 2026 — it used to stay behind).
    @State private var pendingSection = ""
    /// Only on some trips (his ask, 2 Oct 2026): none = always comes along.
    @State private var seasons: Set<String> = []
    @State private var contexts: Set<String> = []
    @State private var transports: Set<String> = []
    @State private var catering: Set<String> = []

    /// The row of a section typed here and not made yet.
    static let newSectionKey = "\u{0}new-section"

    var body: some View {
        let found = model.library.row(templateId: templateId, memId: memId)
        let thing = found?.thing ?? Item()
        let stored = found?.membership ?? Membership()
        let list = model.library.templates.first { $0.id == templateId } ?? newList()
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(HeaderButtonStyle(tint: Theme.muted, filled: false)).focusEffectDisabled()
                    .font(.system(.body, weight: .semibold)).foregroundStyle(Theme.muted)
                    .keyboardShortcut(.cancelAction)            // Escape = Cancel, never Save (Escape everywhere, 5 Oct 2026)
                    .accessibilityIdentifier("row-cancel")
                Spacer()
                Button("Save") { save() }
                    .buttonStyle(HeaderButtonStyle(tint: AppSection.templates.color, filled: true)).focusEffectDisabled()
                    .font(.system(.body, weight: .semibold)).foregroundStyle(AppSection.templates.color)
                    .accessibilityIdentifier("row-save")
            }
            .padding(16)
            KeyboardAwayScroll {
                // Headings 20 apart, each field right under its own (his screenshot,
                // 2026-09-28). Each heading a band in the template colour, as in the thing
                // editor — their field test (3 Oct 2026) tapped a thing here and
                // found the headings (14, grey) smaller than the pills under them.
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(thing.name).font(.system(.title2, weight: .bold)).foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("row-thing-name")
                        Text("On \(list.name)").font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.muted)
                    }
                    // Each pick-one list a drop-down, as on the thing's page (his word, 6 Oct 2026:
                    // "Can we please make these kinds of drop-downs everywhere?").
                    // The first row says where a blank bag REALLY goes: the template's own
                    // bag when it came with one, else the thing's (the spec pass). A bag this
                    // row names that is none of his is shown on a row of its own, ticked.
                    DropDown(title: "Bag on this template", options: [("", model.library.sameBagWords(templateId: templateId, thing: thing))]
                                + model.library.bagNames().map { ($0, $0) },
                             selected: bag, id: "row-bag", tint: AppSection.templates.color, other: true) { bag = $0 }
                    DropDown(title: "When, on this template", options: [("", "Same as the thing (\(phaseLabel(thing.phase)))")]
                                + PHASES.map { ($0.id, $0.label) },
                             selected: when, id: "row-when", tint: AppSection.templates.color) { when = $0 }
                    // Always there since 0.64: "A new section" is the list's foot, as "A new
                    // place" is Kept at home's — it was a block of its own under the pills.
                    DropDown(title: "Section of this template",
                             options: [("", "No section")] + list.sections.map { ($0.id, $0.name) }
                                + (pendingSection.isEmpty ? [] : [(RowEditor.newSectionKey, pendingSection)]),
                             selected: section, id: "row-section", tint: AppSection.templates.color,
                             newEntry: DropDownNew(placeholder: "A new section", needs: "Type the section's name first.") { addSection($0) }
                    ) { section = $0 }
                    // Blank shows, in grey, what the thing itself says — so a blank field
                    // never looks as if the thing's note had gone.
                    VStack(alignment: .leading, spacing: 6) {
                        HeadingBand(title: "How many", tint: AppSection.templates.color, id: "row-heading-qty")
                        field($qty, RowEditor.sameAs(thing.qty, else: "e.g. 2, or 2 pairs"), "row-qty")
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        HeadingBand(title: "Note", tint: AppSection.templates.color, id: "row-heading-note")
                        field($note, RowEditor.sameAs(thing.note, else: "e.g. with the red filter"), "row-note")
                    }
                    Text("Blank means the same as the thing itself, so a change to the thing still reaches this template.")
                        .font(.system(.footnote)).foregroundStyle(Theme.muted)

                    // Only on some trips — per template, as the web app keeps it: a towel
                    // can be summer-only on Beach and always on Swim (his ask, 2 Oct 2026).
                    // A band like the others; its four parts are headings INSIDE it, a size down.
                    VStack(alignment: .leading, spacing: 14) {
                        HeadingBand(title: "Only on some trips", tint: AppSection.templates.color, id: "row-heading-some")
                        Text("Leave these off and it always comes along. Pick one or more and it comes only on trips that match — on this template.")
                            .font(.system(.subheadline)).foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, -6)
                        // A word the app does not know (a web-app "summer") is a pill of its
                        // own after the app's words: kept on Save, and switched off like any.
                        Pills(title: "Season", options: RowEditor.words(SEASONS, stored.seasons), selected: seasons,
                              id: "row-seasons", tint: AppSection.templates.color) { toggle(&seasons, $0) }
                        // Context narrows only workout (WET) templates, as the trip builder reads it.
                        if contextApplies(list) {
                            Pills(title: "Context", options: RowEditor.words(CONTEXTS, stored.contexts), selected: contexts,
                                  id: "row-contexts", tint: AppSection.templates.color) { toggle(&contexts, $0) }
                        }
                        Pills(title: "Transport", options: RowEditor.words(TRANSPORTS, stored.transports), selected: transports,
                              id: "row-transports", tint: AppSection.templates.color) { toggle(&transports, $0) }
                        Pills(title: "Food", options: CATERING.map { ($0.id, HomeScreen.shortFood($0.id, $0.label)) }
                                + Library.unknownConditions(stored.catering, CATERING.map(\.id)).map { ($0, $0) },
                              selected: catering, id: "row-catering", tint: AppSection.templates.color) { toggle(&catering, $0) }
                    }
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
            .font(.system(.body)).foregroundStyle(Theme.ink)
            .padding(.horizontal, 12).frame(minHeight: Metrics.tap)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
            .accessibilityIdentifier(id)
    }

    /// A section of that name already on the template is simply chosen; a new one
    /// waits for Save. (A blank name never gets here: the list's foot says so first.)
    private func addSection(_ typed: String) {
        let name = jsTrim(typed)
        guard !name.isEmpty else { return }
        let sections = model.library.templates.first { $0.id == templateId }?.sections ?? []
        if let there = sections.first(where: { normName($0.name) == normName(name) }) {
            section = there.id
            pendingSection = ""
        } else {
            pendingSection = name
            section = RowEditor.newSectionKey
        }
    }

    /// The pills of one "Only on" kind: the app's words, then any stored word it
    /// does not know.
    static func words(_ vocabulary: [String], _ stored: [String]) -> [(id: String, label: String)] {
        (vocabulary + Library.unknownConditions(stored, vocabulary)).map { ($0, $0) }
    }

    /// A blank field's grey words: the thing's own answer when it has one.
    static func sameAs(_ own: String, else example: String) -> String {
        let first = own.split(separator: "\n").first.map(String.init) ?? ""
        return jsTrim(first).isEmpty ? example : "Same as the thing: \(jsTrim(first))"
    }

    private func toggle(_ set: inout Set<String>, _ value: String) {
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
    }

    /// The model decides what is stored (`Library.saveRow`): the app's own words in
    /// the app's order, words it does not know kept, answers equal to the thing's
    /// left blank, a new section made now — and trips still ahead follow.
    private func save() {
        let fresh = section == RowEditor.newSectionKey
        let answers = Library.RowAnswers(bag: bag, when: when, qty: qty, note: note,
                                         section: fresh ? "" : section, newSection: fresh ? pendingSection : "",
                                         seasons: seasons, contexts: contexts, transports: transports, catering: catering)
        model.change { _ = $0.saveRow(templateId: templateId, memId: memId, answers) }
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

/// The grip, ≡, drawn by hand in the app's style (three strokes, round ends, a
/// 24-point box): hold it and drag — a heading with its things, or one thing (his
/// layout "C", 5 Oct 2026). Named for the tests; read as "Move …".
///
/// The two kinds look clearly different (his note on 0.63, 6 Oct 2026: "Too little
/// difference between the lilac grab handle and the black grab handle"): a HEADING's
/// grip — it carries the heading and all its things — is bolder, in the template's
/// colour, on a soft capsule of that colour; a THING's grip is thinner, a light grey
/// (`Theme.faint`), on nothing. Until 0.67 both were bare, the thing's in `muted`.
struct GripMark: View {
    let id: String
    let label: String
    var heading = false
    var tint: Color = AppSection.templates.color

    var body: some View {
        GridShape(d: "M5 8h14M5 12h14M5 16h14")
            .stroke(heading ? tint : Theme.faint,
                    style: StrokeStyle(lineWidth: heading ? 2.2 : 1.6, lineCap: .round))
            .frame(width: 24, height: 24)
            .frame(width: 34, height: Metrics.chip)
            .background(Capsule().fill(heading ? tint.opacity(0.16) : Color.clear))
            .frame(width: 36, height: Metrics.compact)
            .contentShape(Rectangle())
            .accessibilityElement()
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isImage)
            .accessibilityIdentifier(id)
    }
}
