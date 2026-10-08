import SwiftUI
import PackingCore
import PackingLibrary

/// "Reminders" on a template's page — his idea of 7 Oct 2026: "Add a list of simple
/// reminders for each Template" (spec 07, part 12). Above the things: each reminder a
/// line with its When and a grip ≡ to drag it to its place (0.72); a press opens it in
/// place to rename it, change its When, move it up or down (the Mac's arrows), or remove it. A new one is typed at the block's foot, with its When.
///
/// A reminder is the web app's own kind of line (`itemType` "reminder"): a trip made
/// from the template ticks it like a line, never weighs it, never puts it in a bag and
/// never asks about it in the review.
struct TemplateRemindersBlock: View {
    let templateId: String
    @EnvironmentObject var model: LibraryModel
    @Environment(\.colorScheme) private var scheme

    /// The reminder open for changes (its membership id), and what is typed over its name.
    @State private var open: String?
    @State private var name = ""
    @State private var nameNeeds = ""
    /// Remove was pressed: it asks first.
    @State private var askingToRemove = false
    /// The block's foot: a new reminder and its When ("" = the one it would get).
    @State private var adding = false
    @State private var newName = ""
    @State private var newWhen = ""
    @State private var addNeeds = ""
    @FocusState private var typing: Bool
    /// The reminder carried by its grip, and each line's height — one place (0.72).
    @State private var carried: ReorderDrag?
    @State private var heights: [String: CGFloat] = [:]

    private var tint: Color { AppSection.templates.color }

    var body: some View {
        let rows = model.library.reminders(templateId: templateId)
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text("Reminders").font(.headline).foregroundStyle(tint)
                    .accessibilityIdentifier("template-reminders-title")
                if !rows.isEmpty {
                    Text("\(rows.count)")
                        .font(.system(.footnote, weight: .semibold).monospacedDigit()).foregroundStyle(Theme.muted)
                        .accessibilityIdentifier("template-reminders-count")
                }
                Spacer()
                // With none yet, the block is one line: its name and this.
                if rows.isEmpty && !adding {
                    Button { adding = true } label: {
                        Text("Add a reminder").font(.system(.subheadline, weight: .semibold)).foregroundStyle(tint)
                            .padding(.horizontal, 10).frame(minHeight: Metrics.chip)
                            .overlay(Capsule().stroke(tint, lineWidth: 1.2))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("template-reminders-start")
                }
            }
            .padding(.top, 10).padding(.bottom, 2)
            ForEach(Array(rows.enumerated()), id: \.element.memId) { n, row in
                line(row, n: n, count: rows.count)
            }
            if !rows.isEmpty || adding { foot }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("template-reminders")
    }

    /// One reminder: its name, its When on the right; pressed, it opens in place.
    @ViewBuilder private func line(_ row: Item, n: Int, count: Int) -> some View {
        let mid = row.memId ?? ""
        let phase = phaseOrFallback(row.phase)
        VStack(alignment: .leading, spacing: 6) {
          HStack(spacing: 2) {
            // The grip (0.72, his "drag and drop on the phone as well"): hold and drag; each
            // place passed is one step, made at once as the Mac's ↑ ↓ are.
            if count > 1 {
                ReorderGrip(id: "template-reminder-\(n)-grip", label: "Move \(row.name)", key: mid,
                            step: heights[mid] ?? Metrics.line, drag: $carried,
                            canMove: { by in canStep(mid, by) },
                            move: { by in model.change { _ = $0.moveReminder(templateId: templateId, memId: mid, by: by) } })
                    .padding(.leading, -6)
            }
            Button {
                // The keyboard of the foot goes down, so the opened reminder is in sight.
                typing = false
                #if os(iOS)
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                #endif
                if open == mid { close() } else { open = mid; name = row.name; nameNeeds = ""; askingToRemove = false }
            } label: {
                HStack(spacing: 8) {
                    Text(row.name).font(.system(.body)).foregroundStyle(Theme.ink).lineLimit(2)
                    Spacer(minLength: 8)
                    Text(phase.label)
                        .font(.system(.footnote, weight: .semibold))
                        .foregroundStyle(Color(hexString: readableHex(phase.color, dark: scheme == .dark)))
                        .lineLimit(1)
                }
                .padding(.vertical, 2).frame(minHeight: Metrics.line).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("template-reminder-\(n)")
            .accessibilityValue(phase.label)
          }
          .reorderStep(mid, into: $heights)
          .reorderLift(carried, key: mid, tint: tint)
            if open == mid { panel(row, mid: mid, n: n, count: count) }
        }
        .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
    }

    /// The open reminder: its name, its When, up and down, Done — and Remove, last.
    @ViewBuilder private func panel(_ row: Item, mid: String, n: Int, count: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("The reminder", text: $name)
                .textFieldStyle(.plain)
                .font(.system(.body)).foregroundStyle(Theme.ink)
                .padding(.horizontal, 12).frame(minHeight: Metrics.tap)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                .onSubmit { done(row, mid: mid) }
                .accessibilityIdentifier("template-reminder-name")
                .needsLine($nameNeeds, typed: name, id: "template-reminder-name-needs")
            DropDown(title: "When", heading: .beside, options: PHASES.map { ($0.id, $0.label) },
                     selected: row.phase, id: "template-reminder-when", tint: tint, other: true) { when in
                model.change { _ = $0.setReminderWhen(templateId: templateId, memId: mid, when: when) }
            }
            HStack(spacing: 8) {
                // ↑ ↓ on the Mac only (0.72): the iPhone drags the line's grip.
                if ReorderArrows.shown {
                    arrow(up: true, enabled: n > 0, mid: mid)
                    arrow(up: false, enabled: n < count - 1, mid: mid)
                }
                Spacer()
                Button { done(row, mid: mid) } label: { FieldButtonLabel(title: "Done", tint: tint) }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("template-reminder-done")
            }
            if askingToRemove {
                HStack(spacing: 10) {
                    Text("Remove \u{201C}\(row.name)\u{201D} from this template?")
                        .font(.system(.footnote, weight: .semibold)).foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 6)
                    Button("Keep it") { askingToRemove = false }
                        .buttonStyle(.plain).focusEffectDisabled()
                        .font(.system(.footnote, weight: .semibold)).foregroundStyle(Theme.ink)
                        .accessibilityIdentifier("template-reminder-remove-no")
                    Button {
                        model.change { _ = $0.removeReminder(templateId: templateId, memId: mid) }
                        close()
                    } label: {
                        Text("Remove").font(.system(.footnote, weight: .semibold)).foregroundStyle(.white)
                            .padding(.horizontal, 12).frame(minHeight: Metrics.compact)
                            .background(Capsule().fill(AppSection.actions.color))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("template-reminder-remove-yes")
                }
            } else {
                SmallDeleteButton(title: "Remove reminder", id: "template-reminder-remove") { askingToRemove = true }
            }
        }
        .padding(.leading, 12).padding(.bottom, 8)
        #if os(macOS)
        .onExitCommand { close() }
        #endif
    }

    private func canStep(_ mid: String, _ by: Int) -> Bool {
        let rows = model.library.reminders(templateId: templateId)
        guard let n = rows.firstIndex(where: { $0.memId == mid }) else { return false }
        return rows.indices.contains(n + by)
    }

    private func arrow(up: Bool, enabled: Bool, mid: String) -> some View {
        Button {
            guard enabled else { return }
            model.change { _ = $0.moveReminder(templateId: templateId, memId: mid, by: up ? -1 : 1) }
        } label: {
            SVGPath.path(up ? "M6 15l6-6 6 6" : "M6 9l6 6 6-6")
                .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .onGrid(Metrics.glyph)
                .foregroundStyle(enabled ? tint : Theme.line)
                .frame(width: Metrics.tap, height: Metrics.tap)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(enabled ? tint : Theme.line, lineWidth: 1.2))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier(up ? "template-reminder-up" : "template-reminder-down")
        .accessibilityLabel(up ? "Move up" : "Move down")
    }

    /// The foot: When, then the new reminder's name and Add.
    private var foot: some View {
        let when = newWhen.isEmpty ? model.library.whenForNewReminder(templateId: templateId) : newWhen
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                TextField("Add a reminder", text: $newName)
                    .textFieldStyle(.plain)
                    .font(.system(.body)).foregroundStyle(Theme.ink)
                    .focused($typing)
                    .padding(.horizontal, 12).frame(minHeight: Metrics.tap)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                    .onSubmit { add(when) }
                    .accessibilityIdentifier("template-reminder-add-name")
                // Always in colour (his rule); pressed too early it says what is missing.
                Button { add(when) } label: { FieldButtonLabel(title: "Add", tint: tint) }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("template-reminder-add")
            }
            .needsLine($addNeeds, typed: newName, id: "template-reminder-add-needs")
            DropDown(title: "When", heading: .beside, options: PHASES.map { ($0.id, $0.label) },
                     selected: when, id: "template-reminder-add-when", tint: tint, other: true) { newWhen = $0 }
        }
        .padding(.top, 8)
        .onAppear { if adding { typing = true } }
    }

    private func add(_ when: String) {
        switch model.library.reminderNameProblem(templateId: templateId, name: newName) {
        case .blank?: addNeeds = "Type the reminder first."
        case .alreadyHere?: addNeeds = "This template has that reminder already."
        case .aThing?: addNeeds = "That is the name of one of your things."
        case nil:
            model.change { _ = $0.addReminder(templateId: templateId, name: newName, when: when) }
            newName = ""
            typing = true
        }
    }

    private func done(_ row: Item, mid: String) {
        if jsTrim(name) != row.name {
            switch model.library.reminderNameProblem(templateId: templateId, name: name, except: mid) {
            case .blank?: nameNeeds = "A reminder needs words."; return
            case .alreadyHere?: nameNeeds = "This template has that reminder already."; return
            case .aThing?: nameNeeds = "That is the name of one of your things."; return
            case nil: model.change { _ = $0.renameReminder(templateId: templateId, memId: mid, to: name) }
            }
        }
        close()
    }

    private func close() {
        open = nil; name = ""; nameNeeds = ""; askingToRemove = false
    }
}
