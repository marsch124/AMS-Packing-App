import SwiftUI
import PackingCore
import PackingLibrary

// His activity areas, made and changed on their own page (0.89). His words, 18 Oct 2026: "I
// would like the ability to add and adjust activity areas so that I can organize templates."
//
// Reached from the Templates tab's "Activity areas" pill, at the head of the headings it
// changes. The way his other lists are changed (Your choices, a drop-down's tools): each area
// a grip ≡ (on the Mac also ↑ ↓), a pen that turns its name into a field, and a quiet red
// Remove at the right that asks first — or, while templates are in it, names them and keeps
// it; the workout area is never removed. A new one is typed at the foot. Everything is held
// on the page — a removed area struck out, with Put back — until Save; Cancel leaves the list
// as it was. Written by the lists' own writes (`applyChoiceEditsNow`, kind "areas"), so a
// rename here is exactly a rename anywhere: the area keeps its id, its templates follow.
//
// Moving a TEMPLATE into an area is done on the template's page (Activity area); this page
// changes the areas themselves.
//
// Ids: the page `areas-detail`, its title `areas-title`, `areas-intro`, Cancel `areas-cancel`,
// Save `areas-save`, `areas-footer`; per area, n = its place as the page shows it: the row
// `areas-row-<n>`, its words `areas-row-<n>-label`, the number of templates in it
// `areas-row-<n>-count`, the grip `-grip`, the pen `-rename`, while renamed the field `-name`
// with OK `-rename-ok` and what is wrong `-name-needs`, ↑ ↓ (Mac) `-up` `-down`, Remove
// `-remove`; asked: `-ask` with `-remove-yes` and `-remove-no` (Keep); refused: `-refused`
// with `-remove-no` (OK); struck out: `-putback`. The foot: `areas-add-name`, `areas-add`,
// `areas-add-needs`.
struct AreasScreen: View {
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    /// Everything done on the page, written on Save.
    @State private var edits = ChoiceEdits(kind: "areas")
    /// The area whose name is a field (its key), what it says, and what was wrong with it.
    @State private var renaming: String?
    @State private var newName = ""
    @State private var nameNeeds = ""
    @FocusState private var naming: Bool
    /// The area whose Remove was pressed (its key): the question, or why it stays.
    @State private var asking: String?
    /// A new area typed at the foot, and what Add was missing.
    @State private var typed = ""
    @State private var addNeeds = ""
    /// The area being carried by its grip, and each row's height — one place.
    @State private var carried: ReorderDrag?
    @State private var heights: [String: CGFloat] = [:]

    private var tint: Color { AppSection.templates.color }
    private var rows: [ChoiceRow] { model.library.choicesAsEdited(edits) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .buttonStyle(HeaderButtonStyle(tint: Theme.muted, filled: false)).focusEffectDisabled()
                    .font(.system(.body, weight: .semibold)).foregroundStyle(Theme.muted)
                    .keyboardShortcut(.cancelAction)            // Escape = Cancel, never Save (Escape everywhere)
                    .accessibilityIdentifier("areas-cancel")
                Spacer(minLength: 4)
                Text("Activity areas").font(.system(.title3, weight: .bold)).foregroundStyle(tint)
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .accessibilityIdentifier("areas-title")
                Spacer(minLength: 4)
                // Always ready, always in colour: nothing changed, it simply closes.
                Button("Save") { save() }
                    .buttonStyle(HeaderButtonStyle(tint: tint, filled: true)).focusEffectDisabled()
                    .font(.system(.body, weight: .semibold)).foregroundStyle(tint)
                    .accessibilityIdentifier("areas-save")
            }
            .padding(16)
            KeyboardAwayScroll {
                VStack(alignment: .leading, spacing: 0) {
                    Text(ReorderArrows.shown
                         ? "Your templates are grouped under these areas on Templates and on Create new trip, in this order. Hold the grip \u{2261} and drag an area to its place, or use the arrows; the pen renames it. A template moves to another area on its own page (Activity area). Nothing changes until Save."
                         : "Your templates are grouped under these areas on Templates and on Create new trip, in this order. Hold the grip \u{2261} and drag an area to its place; the pen renames it. A template moves to another area on its own page (Activity area). Nothing changes until Save.")
                        .font(.system(.subheadline)).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 10)
                        .accessibilityIdentifier("areas-intro")
                    let shown = rows
                    ForEach(Array(shown.enumerated()), id: \.element.key) { n, row in
                        line(row, n: n, of: shown)
                    }
                    foot.padding(.top, 12)
                    Text("Your areas belong to your account, so both your devices show the same. Always Packed and By Transport stay where they are: those templates are filed by what they do.")
                        .font(.system(.footnote)).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 14)
                        .accessibilityIdentifier("areas-footer")
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("areas-detail")
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 520)
        #endif
    }

    // MARK: One area

    @ViewBuilder private func line(_ row: ChoiceRow, n: Int, of shown: [ChoiceRow]) -> some View {
        let id = "areas-row-\(n)"
        if renaming == row.key {
            nameField(row, id: id)
        } else if asking == row.key {
            question(row, id: id)
        } else {
            let gone = row.removed
            let words = Library.areaWords(ActivityArea(id: row.key, name: row.label))
            let count = row.added ? 0 : model.library.templatesIn(area: row.key).count
            HStack(spacing: 2) {
                if !gone {
                    ReorderGrip(id: "\(id)-grip", label: "Move \(words)", key: row.key, step: heights[row.key] ?? Metrics.tap,
                                drag: $carried, canMove: { canMove(row.key, $0) }, move: { move(row.key, $0) })
                }
                Text(words).font(.body).strikethrough(gone)
                    .foregroundStyle(gone ? Theme.muted : Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
                    .padding(.vertical, 6)
                    .accessibilityIdentifier("\(id)-label")
                if count > 0 && !gone {
                    Text("\(count)")
                        .font(.system(.footnote, weight: .semibold).monospacedDigit()).foregroundStyle(Theme.muted)
                        .padding(.leading, 6)
                        .accessibilityLabel(count == 1 ? "1 template" : "\(count) templates")
                        .accessibilityIdentifier("\(id)-count")
                }
                Spacer(minLength: 6)
                if gone {
                    tool(id: "\(id)-putback", label: "Put back \(words)") { putBack(row.key) } face: {
                        Text("Put back").font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.muted)
                    }
                } else {
                    tool(id: "\(id)-rename", label: "Rename \(words)") { startName(row) } face: {
                        PenMark().frame(width: 18, height: 18).foregroundStyle(Theme.muted)
                    }
                    if ReorderArrows.shown {
                        tool(id: "\(id)-up", label: "Move \(words) up") { move(row.key, -1) } face: {
                            glyph("M6 15l6-6 6 6", canMove(row.key, -1) ? tint : Theme.faint)
                        }
                        tool(id: "\(id)-down", label: "Move \(words) down") { move(row.key, 1) } face: {
                            glyph("M6 9l6 6 6-6", canMove(row.key, 1) ? tint : Theme.faint)
                        }
                    }
                    tool(id: "\(id)-remove", label: "Remove \(words)") { ask(row.key) } face: {
                        Text("Remove").font(.system(.subheadline, weight: .semibold)).foregroundStyle(AppSection.actions.color)
                    }
                }
            }
            .frame(minHeight: Metrics.tap)
            .background(carried?.key == row.key ? AnyShapeStyle(Theme.card) : AnyShapeStyle(Theme.bg))
            .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
            .reorderStep(row.key, into: $heights)
            .reorderLift(carried, key: row.key, tint: tint)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(id)
        }
    }

    /// The pen pressed: the name as a field — Return or OK takes it, Escape (Mac) leaves it.
    private func nameField(_ row: ChoiceRow, id: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                TextField("Name", text: Binding(get: { newName }, set: { newName = $0; nameNeeds = "" }))
                    .textFieldStyle(.plain)
                    .font(.body).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 10).frame(minHeight: Metrics.tap)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 8)
                        .stroke(nameNeeds.isEmpty ? tint : AppSection.actions.color, lineWidth: 1.5))
                    .focused($naming)
                    .onSubmit { takeName(row) }
                    #if os(macOS)
                    .onExitCommand { leaveName() }          // a text field keeps Escape for itself
                    #endif
                    .accessibilityIdentifier("\(id)-name")
                Button { takeName(row) } label: { FieldButtonLabel(title: "OK", tint: tint) }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("\(id)-rename-ok")
            }
            if !nameNeeds.isEmpty {
                Text(nameNeeds).font(.system(.subheadline, weight: .semibold)).foregroundStyle(AppSection.actions.color)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("\(id)-name-needs")
            }
        }
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(id)
    }

    /// Remove pressed: asked inside the list — or, while templates are in it (or it is the
    /// workout area), why it stays, naming them.
    private func question(_ row: ChoiceRow, id: String) -> some View {
        let words = Library.areaWords(ActivityArea(id: row.key, name: row.label))
        let refused = row.added ? nil : model.library.choiceRemoveProblem("areas", key: row.key, label: words)
        return VStack(alignment: .leading, spacing: 8) {
            Text(refused ?? "Remove \(words) from your activity areas? No template is in it.")
                .font(.system(.subheadline)).foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(refused == nil ? "\(id)-ask" : "\(id)-refused")
            HStack(spacing: 12) {
                if refused == nil {
                    Button { remove(row.key) } label: {
                        Text("Remove").font(.system(.subheadline, weight: .semibold)).foregroundStyle(.white)
                            .padding(.horizontal, 12).frame(minHeight: Metrics.compact)
                            .background(Capsule().fill(AppSection.actions.color))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("\(id)-remove-yes")
                }
                Button { asking = nil } label: {
                    Text(refused == nil ? "Keep" : "OK").font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.ink)
                        .padding(.horizontal, 8).frame(minHeight: Metrics.compact)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("\(id)-remove-no")
                Spacer(minLength: 0)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppSection.actions.color, lineWidth: 1))
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(id)
    }

    /// "A new area" + Add at the foot: made on Save, last unless moved.
    private var foot: some View {
        HStack(spacing: 8) {
            TextField("A new area", text: $typed)
                .textFieldStyle(.plain)
                .font(.body).foregroundStyle(Theme.ink)
                .padding(.horizontal, 12).frame(minHeight: Metrics.tap)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                .onSubmit { add() }
                .accessibilityIdentifier("areas-add-name")
            Button { add() } label: { FieldButtonLabel(title: "Add", tint: tint) }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("areas-add")
        }
        .needsLine($addNeeds, typed: typed, id: "areas-add-needs")
    }

    private func tool<Face: View>(id: String, label: String, _ action: @escaping () -> Void,
                                  @ViewBuilder face: () -> Face) -> some View {
        Button(action: action) {
            face()
                .fixedSize()
                .frame(minWidth: Metrics.compact, minHeight: Metrics.tap)
                .padding(.horizontal, 2)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }

    private func glyph(_ d: String, _ color: Color) -> some View {
        SVGPath.path(d)
            .stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
            .foregroundStyle(color)
            .onGrid(16)
            .accessibilityHidden(true)
    }

    // MARK: What the tools do (held until Save)

    private func startName(_ row: ChoiceRow) {
        asking = nil
        nameNeeds = ""
        newName = row.label
        renaming = row.key
        DispatchQueue.main.async { naming = true }
    }

    private func takeName(_ row: ChoiceRow) {
        let lib = model.library
        if let problem = lib.choiceNameProblem(edits, key: row.key, name: newName) { nameNeeds = problem; return }
        let clean = jsTrim(newName)
        let was = lib.choiceRows("areas").first { $0.key == row.key }?.label
            ?? (ChoiceEdits.isAdded(row.key) ? edits.added[Int(row.key.dropFirst(2)) ?? 0] : nil)
        edits.names[row.key] = clean == was ? nil : clean
        leaveName()
    }

    private func leaveName() {
        renaming = nil
        nameNeeds = ""
        naming = false
    }

    private func canMove(_ key: String, _ by: Int) -> Bool {
        let keys = rows.map(\.key)
        guard let at = keys.firstIndex(of: key), !(rows[at].removed) else { return false }
        return keys.indices.contains(at + by)
    }

    private func move(_ key: String, _ by: Int) {
        guard canMove(key, by) else { return }
        var keys = rows.map(\.key)
        let at = keys.firstIndex(of: key)!
        keys.swapAt(at, at + by)
        // Back in the stored order (with the added last): no order is held at all.
        let plain = model.library.choicesAsEdited(ChoiceEdits(kind: "areas")).map(\.key)
            + edits.added.indices.map(ChoiceEdits.addedKey)
        edits.order = keys == plain ? nil : keys
    }

    private func ask(_ key: String) {
        leaveName()
        asking = key
    }

    private func remove(_ key: String) {
        edits.removed.insert(key)
        asking = nil
    }

    private func putBack(_ key: String) { edits.removed.remove(key) }

    private func add() {
        let clean = jsTrim(typed)
        guard !clean.isEmpty else { addNeeds = "Type a name first."; return }
        if let reserved = Library.areaNameReserved(clean) { addNeeds = reserved; return }
        let want = Library.choiceKey(clean)
        if let twin = rows.first(where: { !$0.removed && Library.choiceKey($0.label) == want }) {
            addNeeds = "You already have \(twin.label)."
            return
        }
        edits.added.append(clean)
        typed = ""
        addNeeds = ""
    }

    private func save() {
        let held = edits
        if !held.isEmpty { model.change { lib in _ = lib.applyChoiceEditsNow(held) } }
        dismiss()
    }
}

/// A template's Activity area on its page (0.89): a pick-one drop-down — "Activity area" to
/// the left of the field, as Counts as above it — of Always packed, HIS areas in his order
/// under his names, and No activity area. A choice files the template at once
/// (`setTemplateArea`), as everything on a template's page is saved as it goes. At the foot of
/// the list "A new area" makes one at the end of his list and files the template in it — one
/// he already has is simply chosen. Renaming, moving and removing areas is the Activity areas
/// page's (Templates tab), not this list's.
///
/// Ids (a drop-down's): the field `template-area`, its list `template-area-list`, the rows
/// `template-area-<n>` — 0 = Always packed, then his areas, the last = No activity area — the
/// word beside it `template-area-title`, the foot `template-area-new` / `template-area-add` /
/// `template-area-add-needs`; a name the app keeps for a heading of its own is refused under
/// the field, `template-area-needs`.
struct TemplateAreaField: View {
    let list: PackList
    @EnvironmentObject var model: LibraryModel
    @State private var needs = ""

    static let alwaysWords = "Always packed"
    static let noneWords = "No activity area"

    var body: some View {
        let lib = model.library
        let always = list.role == Library.ALWAYS_PACKED_AREA
        let options: [(value: String, label: String)] = [(Library.ALWAYS_PACKED_AREA, TemplateAreaField.alwaysWords)]
            + lib.activityAreas().map { ($0.id, Library.areaWords($0)) }
            + [("", TemplateAreaField.noneWords)]
        VStack(alignment: .leading, spacing: 4) {
            DropDown(title: "Activity area", heading: .beside, options: options,
                     selected: always ? Library.ALWAYS_PACKED_AREA : lib.areaOf(list),
                     id: "template-area", tint: AppSection.templates.color,
                     newEntry: DropDownNew(placeholder: "A new area", needs: "Type the new area\u{2019}s name first.") { typed in
                         make(typed)
                     }) { value in
                needs = ""
                model.change { _ = $0.setTemplateArea(id: list.id, area: value) }
            }
            if !needs.isEmpty {
                Text(needs).font(.system(.subheadline, weight: .semibold)).foregroundStyle(AppSection.actions.color)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("template-area-needs")
            }
        }
    }

    /// A new area typed at the list's foot: made (one he has is found instead) and the
    /// template filed in it, in one change.
    private func make(_ typed: String) {
        if let reserved = Library.areaNameReserved(typed) { needs = reserved; return }
        needs = ""
        let id = list.id
        model.change { lib in
            let want = Library.choiceKey(typed)
            guard let area = lib.activityAreas().first(where: { Library.choiceKey($0.name) == want })?.id
                    ?? lib.addChoice("areas", typed) else { return }
            _ = lib.setTemplateArea(id: id, area: area)
        }
    }
}
