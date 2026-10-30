import SwiftUI
import PackingCore
import PackingLibrary

/// Your choices on its own copy of the library (0.92, Cancel everywhere — `PageDraft`): what is
/// added, renamed, moved or removed here is kept by Done and thrown away by Cancel, Escape or a
/// swipe down.
struct ListsScreen: View {
    @EnvironmentObject var model: LibraryModel

    var body: some View {
        DraftedPage(live: model) { page in
            ListsPage(page: page)
                .onAppear { page.stepName = { "Change Your Choices" } }       // Edit ▸ Undo's name (0.105)
        }
    }
}

/// The lists he authors himself: storage places, kinds of thing (0.107), owners, packers,
/// conditions and the "When" timeline. They belong to the account, so both devices show the
/// same; an entry still in use cannot be removed by accident — but a kind of thing can, once he
/// has said where its things go (0.107). Every part folds, and starts folded (0.107).
struct ListsPage: View {
    /// The copy this page works on (0.92): Done hands it over, Cancel throws it away. Since 0.98 (the
    /// Apple way, his decision of 21 Oct 2026) nothing of it is kept when the app is put away or ended.
    let page: PageDraft
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    @State private var adding: [String: String] = [:]
    /// What each part's Add was missing, said under its field (never a grey button).
    @State private var needs: [String: String] = [:]
    /// Why an entry stays, said right under the entry whose ✕ was pressed — not at the
    /// top of the page, where on a phone it was off screen when Remove was pressed far
    /// down the "When" steps and it looked as if nothing happened (the spec pass, 5 Oct 2026).
    @State private var problem: (kind: String, key: String, says: String)?
    /// The entry whose pen is open: its rename field and, where its order is his to
    /// set, its ▲ ▼. Followed by its KEY, so it stays open on the entry as it moves.
    @State private var editing: (kind: String, key: String)?
    @State private var renaming = ""
    @State private var editSays = ""
    /// The place whose square code is open (0.69).
    @State private var coding: CodeFor?
    /// Every place's label as a file, for Share (iPhone, 0.69).
    @State private var labelFiles: [URL] = []
    /// What saving every label into a folder did (Mac, 0.69).
    @State private var labelsSaid = ""
    private struct CodeFor: Identifiable { let id: String }
    /// The entry being carried by its grip (0.70), and each entry's row height — one place.
    @State private var carried: ReorderDrag?
    @State private var heights: [String: CGFloat] = [:]
    /// The parts open now (0.107 — his words, 30 Oct 2026: "Could we design the Your choices areas with a toggle
    /// so that the user can fold. The list is too long unfolded."): every part starts folded and keeps its own
    /// fold on this device (`ChoicesFold`).
    @State private var open: Set<String> = ChoicesFold.opened()
    /// A kind of thing in use whose ✕ was pressed (0.107): the card asks where its things go.
    @State private var removing: KindRemoving?
    private struct KindRemoving: Equatable {
        let key: String
        let label: String
        let use: KindUse
        /// Where its things go — his Other, the app's catch-all or the first of his kinds until he chooses.
        var to: String
    }

    enum Kind: String, CaseIterable {
        case places, categories, owners, people, conditions, phases
        var title: String {
            switch self {
            case .places: return "Storage places"
            case .categories: return "Kinds of thing"
            case .owners: return "Owners"
            case .people: return "Packers"
            case .conditions: return "Item conditions"
            case .phases: return "\"When\" steps"
            }
        }
        /// What it is, where it is used, what it is good for — his test K.3 (1 Oct
        /// 2026): "a line or two of explanations for each choice … so that this is
        /// totally clear to the user".
        var hint: String {
            switch self {
            case .places: return "Where a thing is kept at home — a cupboard, the garage, the basement. You give a thing its place under Kept at home; a trip grouped by From where then lists what to fetch room by room. The square beside a place is its code: print its label, and the iPhone\u{2019}s Camera opens the app on that place."
            case .categories: return "What a thing is — clothing, footwear, electronics. You pick it under Kind of thing on a thing. Remove one your things still have, and you choose the kind they move to; Documents & money stays, as Before you go reads it."
            case .owners: return "Whose a thing is — you, your partner, a child. You pick it under Whose it is on a thing, so on a shared trip everyone sees which things are theirs."
            case .people: return "Who packs a thing. You set it in the All your things table (Packed by), so you can see who is in charge of what."
            case .conditions: return "How worn a thing is: New, Good, Worn, Needs replacing. You set it under Condition on a thing; a thing that needs replacing is suggested on To buy."
            case .phases: return "The steps of packing, from a week ahead to the day you leave. Every thing has its When, and a trip shows its list in this order, step by step."
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Cancel throws away everything changed here since the page opened; Done keeps it (0.92).
            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .buttonStyle(HeaderButtonStyle(tint: Theme.muted, filled: false)).focusEffectDisabled()
                    .font(.system(.body, weight: .semibold)).foregroundStyle(Theme.muted)
                    // Escape = Cancel, never Done (0.92) — while the Remove card asks, Escape is the card's (0.107).
                    .keyboardShortcut(removing == nil ? .cancelAction : nil)
                    .accessibilityIdentifier("lists-cancel")
                Spacer(minLength: 4)
                Text("Your choices").font(.system(.title3, weight: .bold)).foregroundStyle(Theme.ink)
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .accessibilityIdentifier("choices-title")
                Spacer(minLength: 4)
                // A save the store refused (0.94) leaves the page open, holding it, for Done again.
                Button("Done") { page.done { dismiss() } }
                    .buttonStyle(HeaderButtonStyle(tint: AppSection.settings.color, filled: true)).focusEffectDisabled()
                    .font(.system(.body, weight: .semibold)).foregroundStyle(AppSection.settings.color)
                    .keyboardShortcut(removing == nil ? KeyboardShortcut("s", modifiers: .command) : nil)  // ⌘S = Done (0.92)
                    .accessibilityIdentifier("lists-done")
            }
            .padding(16)
            KeyboardAwayScroll {
                VStack(alignment: .leading, spacing: 8) {
                    // What this page is, once, at the top (K.3). Since 0.107 a kind of thing in use can be removed:
                    // it asks where its things go.
                    Text(ReorderArrows.shown
                         ? "The words the app offers you as buttons. A tap on a heading opens its part. Add your own with the field under each part; hold the grip ≡ and drag one to its place; the pen renames one or moves it up or down. A kind of thing your things still have asks where they go when you remove it; anything else still in use stays."
                         : "The words the app offers you as buttons. A tap on a heading opens its part. Add your own with the field under each part; hold the grip ≡ and drag one to its place; the pen renames one. A kind of thing your things still have asks where they go when you remove it; anything else still in use stays.")
                        .font(.system(.subheadline)).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("choices-intro")
                    ForEach(Kind.allCases, id: \.rawValue) { kind in
                        let entries = entries(kind)
                        // The heading leads, as the editors' headings do (field test, 3 Oct 2026: "dominant"), with
                        // the chevron that folds the part at its left (0.107, the look of Before a trip on a thing).
                        heading(kind, count: entries.count)
                        if isOpen(kind) {
                            Text(kind.hint).font(.system(.subheadline)).foregroundStyle(Theme.ink.opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("choices-hint-\(kind.rawValue)")
                            if kind == .places { allLabels }
                            // Followed by its key (by its place until 0.70): an entry carried by its
                            // grip keeps its gesture while the others change places.
                            ForEach(Array(entries.enumerated()), id: \.element.key) { n, entry in
                                HStack {
                                    // The grip (0.70): hold and drag; each place passed is one press
                                    // of the pen's ▲ or ▼, made at once as they are. Owners stay A–Z.
                                    if Library.canMove(kind.rawValue) {
                                        ReorderGrip(id: "list-\(kind.rawValue)-grip-\(n)", label: "Move \(entry.label)",
                                                    key: "\(kind.rawValue)/\(entry.key)",
                                                    step: heights["\(kind.rawValue)/\(entry.key)"] ?? Metrics.tap, drag: $carried,
                                                    canMove: { by in canStep(kind, entry.key, by) },
                                                    move: { by in move(kind, entry, by: by) })
                                            .padding(.leading, -8)
                                    }
                                    Text(entry.label).font(.system(.body)).foregroundStyle(Theme.ink)
                                        .accessibilityIdentifier("list-\(kind.rawValue)-name-\(n)")
                                    // "This is me" (0.70): a small tag on his own row.
                                    if kind == .owners, let me = model.library.me(), normName(me) == normName(entry.key) {
                                        MeTag().accessibilityIdentifier("list-owners-me-\(n)")
                                    }
                                    // The THINGS that use it — for a "When" step its trips and
                                    // templates are said when Remove is refused (the spec pass).
                                    if entry.uses.things > 0 {
                                        Text("\(entry.uses.things)").font(.system(.footnote, weight: .semibold).monospacedDigit())
                                            .foregroundStyle(Theme.muted)
                                            .accessibilityIdentifier("list-\(kind.rawValue)-uses-\(n)")
                                    }
                                    Spacer()
                                    // A place's square code, to print and put where its things are
                                    // kept (0.69): the Camera, pointed at it, opens the app there.
                                    if kind == .places {
                                        Button { coding = CodeFor(id: entry.label) } label: {
                                            CodeMark().frame(width: 22, height: 22)
                                                .foregroundStyle(Theme.muted)
                                                .frame(width: Metrics.tap, height: Metrics.tap)
                                                .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain).focusEffectDisabled()
                                        .accessibilityIdentifier("list-places-code-\(n)")
                                        .accessibilityLabel("Square code for \(entry.label)")
                                    }
                                    // His own lists could only be added to and taken from (the spec
                                    // pass, 5 Oct 2026: "no rename, no reorder"). The pen opens the
                                    // entry: a new name, and ▲ ▼ where its order is his to set.
                                    Button { toggleEditing(kind, entry) } label: {
                                        // Open: the slate on a slate tint, so it is plain which entry the
                                        // editor under it belongs to (colour as the message).
                                        PenMark().frame(width: 22, height: 22)
                                            .foregroundStyle(isEditing(kind, entry.key) ? AppSection.settings.color : Theme.muted)
                                            .frame(width: Metrics.tap, height: Metrics.tap)
                                            .background(RoundedRectangle(cornerRadius: 10)
                                                .fill(isEditing(kind, entry.key) ? AppSection.settings.color.opacity(0.16) : Color.clear))
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain).focusEffectDisabled()
                                    .accessibilityIdentifier("list-\(kind.rawValue)-edit-\(n)")
                                    .accessibilityLabel("Change \(entry.label)")
                                    Button { remove(kind, n) } label: {
                                        SVGPath.path("M6 6L18 18M18 6L6 18")
                                            .stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                                            .frame(width: 22, height: 22).foregroundStyle(Theme.muted)
                                            .frame(width: 40, height: 40).contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain).focusEffectDisabled()
                                    .accessibilityIdentifier("list-\(kind.rawValue)-remove-\(n)")
                                    .accessibilityLabel("Remove \(entry.label)")
                                }
                                .background(carried?.key == "\(kind.rawValue)/\(entry.key)" ? Theme.card : Theme.bg)
                                .accessibilityElement(children: .contain)
                                .accessibilityIdentifier("list-\(kind.rawValue)-row-\(n)")
                                .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
                                .reorderStep("\(kind.rawValue)/\(entry.key)", into: $heights)
                                .reorderLift(carried, key: "\(kind.rawValue)/\(entry.key)", tint: AppSection.settings.color)
                                if let p = problem, p.kind == kind.rawValue, p.key == entry.key {
                                    Text(p.says).font(.system(.subheadline, weight: .semibold)).foregroundStyle(AppSection.actions.color)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .accessibilityIdentifier("lists-problem")
                                }
                                if isEditing(kind, entry.key) { editor(kind, entry) }
                            }
                            HStack(spacing: 8) {
                                TextField("Add to \(kind.title.lowercased())", text: Binding(
                                    get: { adding[kind.rawValue] ?? "" }, set: { adding[kind.rawValue] = $0 }))
                                    .textFieldStyle(.plain)
                                    .font(.system(.body)).foregroundStyle(Theme.ink)
                                    .padding(.horizontal, 12).frame(minHeight: Metrics.tap)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                                    .onSubmit { add(kind) }
                                    .accessibilityIdentifier("list-\(kind.rawValue)-add-name")
                                Button { add(kind) } label: { FieldButtonLabel(title: "Add", tint: AppSection.settings.color) }
                                    .buttonStyle(.plain).focusEffectDisabled()
                                    .accessibilityIdentifier("list-\(kind.rawValue)-add")
                            }
                            .needsLine(Binding(get: { needs[kind.rawValue] ?? "" }, set: { needs[kind.rawValue] = $0 }),
                                       typed: adding[kind.rawValue] ?? "", id: "list-\(kind.rawValue)-add-needs")
                            .padding(.bottom, 10)
                        }
                    }
                    Text("These belong to your account, so both your devices show the same.")
                        .font(.system(.footnote)).foregroundStyle(Theme.muted).padding(.top, 14)
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        // A kind of thing in use: where its things go, asked in the middle of the page (0.107).
        .overlay { if let r = removing { removeKindCard(r) } }
        .sheet(item: $coding) { PlaceCodeSheet(place: $0.id).environmentObject(model) }
        // A swipe down with something changed asks first (0.92, the app's rule; spec 06 §20a).
        .asksBeforeDiscarding(page.changed) { dismiss() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("lists-detail")
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 600)
        #endif
    }

    /// Every place's label for the P-touch at once (0.69): on the Mac into a folder he
    /// picks, on the iPhone through Share (Save Images, or Files).
    @ViewBuilder private var allLabels: some View {
        #if os(macOS)
        VStack(alignment: .leading, spacing: 4) {
            Button { saveAllLabels() } label: { allLabelsLabel }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("list-places-labels")
            if !labelsSaid.isEmpty {
                Text(labelsSaid).font(.system(.footnote)).foregroundStyle(Theme.muted)
                    .accessibilityIdentifier("list-places-labels-said")
            }
        }
        #else
        // Two steps on the iPhone: the labels are made (and the places' codes kept) on a
        // press, never just by opening this page — then Share hands them all on.
        if labelFiles.isEmpty {
            Button { labelFiles = allLabelFiles() } label: { allLabelsLabel }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("list-places-labels")
        } else {
            ShareLink(items: labelFiles) {
                Text(labelFiles.count == 1 ? "Share 1 label" : "Share \(labelFiles.count) labels")
                    .font(.system(.body, weight: .semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: Metrics.tap)
                    .background(RoundedRectangle(cornerRadius: 12).fill(AppSection.settings.color))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("list-places-labels-share")
        }
        #endif
    }

    private var allLabelsLabel: some View {
        WideButtonLabel(title: "Labels for P-touch, all places", tint: AppSection.settings.color) { CodeMark() }
    }

    /// Every place's code kept first (so a label never shows a code the library does
    /// not know), then each label written as a file.
    private func allLabelFiles() -> [URL] {
        let places = model.library.storagePlaces()
        PlaceLabels.keepCodes(places, in: model)
        return PlaceLabels.write(places, from: model.library)
    }

    #if os(macOS)
    private func saveAllLabels() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Save labels here"
        panel.message = "Choose a folder for the P-touch labels of your places."
        guard panel.runModal() == .OK, let folder = panel.url else { labelsSaid = "Not saved."; return }
        var n = 0
        for file in allLabelFiles() {
            let to = folder.appendingPathComponent(file.lastPathComponent)
            try? FileManager.default.removeItem(at: to)
            if (try? FileManager.default.copyItem(at: file, to: to)) != nil { n += 1 }
        }
        labelsSaid = n == 1 ? "1 label saved in \(folder.lastPathComponent)." : "\(n) labels saved in \(folder.lastPathComponent)."
    }
    #endif

    // MARK: - Folding (0.107)

    private func isOpen(_ kind: Kind) -> Bool { open.contains(kind.rawValue) }

    private func fold(_ kind: Kind) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if open.remove(kind.rawValue) == nil { open.insert(kind.rawValue) }
        }
        ChoicesFold.keep(kind.rawValue, open: isOpen(kind))
    }

    /// A part's heading (0.107 — his words, 30 Oct 2026: "Could we design the Your choices areas with a toggle so
    /// that the user can fold"): the chevron at the LEFT, as Before a trip's on a thing's page (0.104), the part's
    /// name in the Settings slate and — folded — how many entries it holds, muted: "Storage places · 12". A tap
    /// anywhere on the line folds or opens it. Not a button round its words: on the Mac a button folds its words
    /// into its own, and the heading and the count are read on their own.
    private func heading(_ kind: Kind, count: Int) -> some View {
        let open = isOpen(kind)
        return HStack(spacing: 8) {
            Button { fold(kind) } label: {
                SVGPath.path(open ? "M6 9l6 6 6-6" : "M9 6l6 6-6 6")
                    .stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                    .frame(width: 22, height: 22).foregroundStyle(Theme.muted)
                    .frame(height: Metrics.tap).contentShape(Rectangle())
            }
            .buttonStyle(.plain).focusEffectDisabled()
            .accessibilityLabel(open ? "Fold \(kind.title)" : "Show \(kind.title)")
            .accessibilityValue(open ? "open" : "folded")
            .accessibilityIdentifier("choices-fold-\(kind.rawValue)")
            Text(kind.title).font(.headline).foregroundStyle(AppSection.settings.color)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("choices-heading-\(kind.rawValue)")
            if !open {
                // Close to its name, as one heading: "Storage places · 12".
                Text("\u{00B7} \(count)").font(.headline.monospacedDigit()).foregroundStyle(Theme.muted)
                    .lineLimit(1).fixedSize()
                    .padding(.leading, -3)
                    .accessibilityIdentifier("choices-count-\(kind.rawValue)")
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: Metrics.tap)
        .contentShape(Rectangle())
        .onTapGesture { fold(kind) }
        .padding(.top, 4)
    }

    // MARK: - Removing a kind of thing in use (0.107)

    /// ✕ on a kind of thing (0.107 — his words, 30 Oct 2026: "I need the ability to delete a Kind of thing, even
    /// if there are items that are connected to this very Kind of thing choice"). Documents & money and the last
    /// kind are refused under the row, as any refusal here; one nothing has goes at once, as any entry here; one
    /// his things have asks first — the card says how many and where they go.
    private func removeKind(_ entry: Entry) {
        if let why = model.library.kindRemoveProblem(entry.key) {
            problem = (Kind.categories.rawValue, entry.key, why)
            return
        }
        problem = nil
        let use = model.library.kindUse(entry.key)
        guard use.inUse else {
            if isEditing(.categories, entry.key) { editing = nil }
            model.change { lib in _ = lib.removeKind(entry.key, moveTo: "") }
            return
        }
        withAnimation(.easeOut(duration: 0.15)) {
            removing = KindRemoving(key: entry.key, label: entry.label, use: use, to: model.library.fallbackKind(without: entry.key))
        }
    }

    /// Remove: on the page's copy, as everything here — every thing and trip line of the kind takes the one chosen,
    /// and Done keeps it in one change (Cancel throws it away).
    private func confirmRemove(_ r: KindRemoving) {
        if isEditing(.categories, r.key) { editing = nil }
        editSays = ""
        model.change { lib in _ = lib.removeKind(r.key, moveTo: r.to) }
        withAnimation(.easeOut(duration: 0.15)) { removing = nil }
    }

    /// The card (`KindRemoveCard`, shared with a thing's Kind of thing): his other kinds as the page shows them.
    private func removeKindCard(_ r: KindRemoving) -> some View {
        let away = Library.choiceKey(r.key)
        let options = model.library.categories().filter { Library.choiceKey($0) != away }.map { (value: $0, label: $0) }
        return KindRemoveCard(label: r.label, use: r.use, options: options,
                              to: Binding(get: { removing?.to ?? r.to }, set: { removing?.to = $0 }), keptBy: "Done",
                              cancel: { withAnimation(.easeOut(duration: 0.15)) { removing = nil } },
                              remove: { confirmRemove(r) })
    }

    /// One entry's editor, under its row: a new name with Rename, and ▲ ▼ (44 × 44,
    /// drawn) where the list's order is his — on the Mac; the iPhone says to drag the grip
    /// instead (0.72). What a press could not do is said under it.
    private func editor(_ kind: Kind, _ entry: Entry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                TextField("New name", text: $renaming)
                    .textFieldStyle(.plain)
                    .font(.system(.body)).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 12).frame(minHeight: Metrics.tap)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.bg))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                    .onSubmit { rename(kind, entry) }
                    .accessibilityIdentifier("list-\(kind.rawValue)-rename-name")
                Button { rename(kind, entry) } label: { FieldButtonLabel(title: "Rename", tint: AppSection.settings.color) }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("list-\(kind.rawValue)-rename")
            }
            if Library.canMove(kind.rawValue) && !ReorderArrows.shown {
                // The iPhone (0.72): no ▲ ▼ — the grip at the row's left moves it.
                Text(kind == .phases ? "To move it up or down the timeline, hold the grip \u{2261} at its left and drag it: every trip follows this order."
                                     : "To move it, hold the grip \u{2261} at its left and drag it.")
                    .font(.system(.subheadline)).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("list-\(kind.rawValue)-drag-hint")
            } else if Library.canMove(kind.rawValue) {
                HStack(spacing: 12) {
                    moveButton(kind, entry, by: -1, mark: "M6 15l6-6 6 6", id: "list-\(kind.rawValue)-up", says: "Move \(entry.label) up")
                    moveButton(kind, entry, by: 1, mark: "M6 9l6 6 6-6", id: "list-\(kind.rawValue)-down", says: "Move \(entry.label) down")
                    Text(kind == .phases ? "Up or down the timeline: every trip follows this order." : "Up or down the list.")
                        .font(.system(.subheadline)).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text("Owners are always in A\u{2013}Z order.")
                    .font(.system(.subheadline)).foregroundStyle(Theme.muted)
            }
            if kind == .owners { ThisIsMeButton(owner: entry.key).environmentObject(model) }
        }
        .needsLine($editSays, typed: renaming, id: "list-\(kind.rawValue)-edit-needs")
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppSection.settings.color, lineWidth: 1.4))
        .padding(.vertical, 3)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("list-\(kind.rawValue)-editor")
    }

    private func moveButton(_ kind: Kind, _ entry: Entry, by step: Int, mark: String, id: String, says: String) -> some View {
        Button { move(kind, entry, by: step) } label: {
            SVGPath.path(mark)
                .stroke(style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                .frame(width: 24, height: 24).foregroundStyle(AppSection.settings.color)
                .frame(width: Metrics.tap, height: Metrics.tap)
                .background(RoundedRectangle(cornerRadius: 10).fill(AppSection.settings.color.opacity(0.10)))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppSection.settings.color, lineWidth: 1.4))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier(id)
        .accessibilityLabel(says)
    }

    private typealias Entry = (label: String, key: String, uses: ChoiceUse)

    private func entries(_ kind: Kind) -> [Entry] {
        let uses = model.library.usesOf(kind.rawValue)
        func use(_ key: String) -> ChoiceUse { uses[normName(key)] ?? ChoiceUse() }
        switch kind {
        case .places: return model.library.storagePlaces().map { (label: $0, key: $0, uses: use($0)) }
        case .categories: return model.library.categories().map { (label: $0, key: $0, uses: use($0)) }
        case .owners: return model.library.owners().map { (label: $0, key: $0, uses: use($0)) }
        case .people: return model.library.people().map { (label: $0.name, key: $0.name, uses: use($0.name)) }
        case .conditions: return model.library.conditions().map { (label: $0.label, key: $0.id, uses: use($0.id)) }
        case .phases: return model.library.timeline().map { (label: $0.label, key: $0.id, uses: use($0.id)) }
        }
    }

    private func isEditing(_ kind: Kind, _ key: String) -> Bool { editing?.kind == kind.rawValue && editing?.key == key }

    private func toggleEditing(_ kind: Kind, _ entry: Entry) {
        problem = nil
        editSays = ""
        if isEditing(kind, entry.key) { editing = nil; return }
        editing = (kind.rawValue, entry.key)
        renaming = entry.label
    }

    private func rename(_ kind: Kind, _ entry: Entry) {
        var said: String?
        model.change { lib in said = lib.renameChoice(kind.rawValue, key: entry.key, to: renaming) }
        if let said { editSays = said; return }
        editing = nil
        editSays = ""
    }

    private func move(_ kind: Kind, _ entry: Entry, by step: Int) {
        var moved = false
        model.change { lib in moved = lib.moveChoice(kind.rawValue, key: entry.key, by: step) }
        // Pressed where it cannot go, it says so — a press always answers.
        editSays = moved ? "" : (step < 0 ? "\(entry.label) is already at the top." : "\(entry.label) is already at the bottom.")
    }

    /// Whether an entry has a place to go, up (−1) or down (1) — the grip's question.
    private func canStep(_ kind: Kind, _ key: String, _ by: Int) -> Bool {
        let keys = entries(kind).map(\.key)
        guard Library.canMove(kind.rawValue), let at = keys.firstIndex(of: key) else { return false }
        return keys.indices.contains(at + by)
    }

    private func add(_ kind: Kind) {
        let name = jsTrim(adding[kind.rawValue] ?? "")
        guard !name.isEmpty else { needs[kind.rawValue] = "Type a name first."; return }
        // One he already has is said, never dropped or doubled in silence (the spec pass,
        // 5 Oct 2026). What he typed stays, so the line stays until he changes it.
        if let twin = model.library.existingChoice(kind.rawValue, name) {
            needs[kind.rawValue] = "You already have \(twin)."
            return
        }
        problem = nil
        // The one way an entry is added — the same a drop-down's "A new …" takes (0.69).
        // A new "When" step gets its colour from the app's own cover colours (`newStep`):
        // the web app's pick made the eighth step teal (his colour notes: "Not teal").
        model.change { lib in _ = lib.addChoice(kind.rawValue, name) }
        adding[kind.rawValue] = ""
    }

    private func remove(_ kind: Kind, _ n: Int) {
        let all = entries(kind)
        guard n < all.count else { return }
        let entry = all[n]
        if kind == .categories { return removeKind(entry) }
        guard !entry.uses.inUse else {
            problem = (kind.rawValue, entry.key, entry.uses.refusal(entry.label))
            return
        }
        problem = nil
        if isEditing(kind, entry.key) { editing = nil }
        // The one way an entry is taken away — a drop-down's Remove takes it too (0.69).
        model.change { lib in _ = lib.removeChoice(kind.rawValue, key: entry.key) }
    }
}

/// Each part of Your choices folded or open, on this device (0.107): every part starts folded — "The list is too
/// long unfolded" (his words, 30 Oct 2026) — and keeps its own fold, as Before a trip on a thing does
/// (`BeforeATripFold`). One key per part, holding true while it is open; the UI tests start from none.
enum ChoicesFold {
    static func key(_ part: String) -> String { "ams.choices.open.\(part)" }
    static var keys: [String] { ListsPage.Kind.allCases.map { key($0.rawValue) } }
    static func opened() -> Set<String> {
        Set(ListsPage.Kind.allCases.map(\.rawValue).filter { UserDefaults.standard.bool(forKey: key($0)) })
    }
    static func keep(_ part: String, open: Bool) {
        if open { UserDefaults.standard.set(true, forKey: key(part)) } else { UserDefaults.standard.removeObject(forKey: key(part)) }
    }
}
