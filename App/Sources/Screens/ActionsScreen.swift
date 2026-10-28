import SwiftUI
import PackingCore
import PackingLibrary

/// Actions: the central to-do list — open before done, high before normal,
/// sooner before later. A tick is permanent; it does not reset per trip.
///
/// In three parts since 0.101 (his list of 26 Oct 2026: "completed to-do's should be tucked away in
/// a toggle. Priority to-do's in a separate area"), each a run of that same order
/// (`Library.toDoParts`): Priority at the top — the web app's own `priority` "high", set by the add
/// bar's "!" or, held (right-clicked on the Mac), Mark as priority — then the others, then Done (n),
/// folded until he opens it. A tick sends a to-do into Done at once, and Undo under the list
/// brings it back.
struct ActionsScreen: View {
    @State private var searching = false
    @EnvironmentObject var model: LibraryModel
    @State private var text = ""
    /// The To buy side's own field: one shared text showed a half-typed to-do on
    /// the other side too (the spec pass, 5 Oct 2026). Kept here, so a half-typed
    /// buy line survives a look at To do.
    @State private var buyText = ""
    /// What Add was missing, said under the field (never a grey button).
    @State private var needs = ""
    @State private var high = false
    @State private var buying = false
    /// The to-do last removed with ✕, for Undo.
    @State private var removed: ActionItem?
    /// The to-do last ticked, for Undo (0.101: ticked, it goes into Done, folded away). One bar at a
    /// time: a tick puts away the ✕'s Undo, and the other way round.
    @State private var ticked: ActionItem?
    /// The step of that ✕ or tick in Edit ▸ Undo (0.105): the bar's Undo takes back that step, as ⌘Z does.
    @State private var step: UndoStep.ID?
    /// Done (n) opened (0.101) — folded each time the page opens.
    @State private var doneOpen = false

    var body: some View {
        let parts = model.library.toDoParts(kind: "todo")
        let todos = parts.all
        let open = parts.open
        VStack(spacing: 0) {
            // Two lists, one screen: things to DO and things to BUY. The buy-list
            // is the same store with kind "shopping", as the web app keeps it.
            HStack(spacing: 8) {
                sideButton("To do", on: !buying, id: "actions-tab-todo") { buying = false }
                sideButton("To buy", on: buying, id: "actions-tab-buy") { buying = true }
                Spacer()
                SearchButton { searching = true }
            }
            // Where every tab's first line is (0.67): under the status bar on the iPhone,
            // on the traffic lights' line in the window's title bar strip on the Mac.
            .headerLine()
            .padding(.horizontal, 16)
            #if os(macOS)
            .padding(.bottom, 6)                      // the page below never touches the strip (ScreenHeader.swift)
            #endif
            if buying {
                BuyList(text: $buyText).environmentObject(model)
            } else {
            KeyboardAwayScroll {
                // No space between to-dos: each is as tall as its words (`Metrics.line`). His
                // words (6 Oct 2026, testing 0.63): "Far too much line space in the To Do tab"
                // — 44 points top to top, with a 26-point circle, until 0.67.
                // A plain stack since 0.101: a to-do moves from one part to another (ticked: into
                // Done), and the lazy stack drew it there as the row it had cached under the same id
                // in the part it left — a ticked to-do shown unticked in Done.
                VStack(alignment: .leading, spacing: 0) {
                    Text(todos.isEmpty ? "Nothing to do." : (open == 0 ? "All done." : "\(open) to do"))
                        .font(.system(.callout, weight: .semibold).monospacedDigit()).foregroundStyle(Theme.muted)
                        .padding(.top, 12).padding(.bottom, 4)
                        .accessibilityIdentifier("actions-count")
                    // Priority (0.101): its own part at the top, with its heading — the others under
                    // theirs. With no priority the list is one run, as before.
                    if !parts.priority.isEmpty {
                        partTitle("Priority", count: parts.priority.count, tint: AppSection.actions.color, id: "actions-priority-title")
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(parts.priority.enumerated()), id: \.element.id) { n, a in row(a, n: n) }
                        }
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("actions-priority")
                        if !parts.others.isEmpty {
                            partTitle("Others", count: parts.others.count, tint: Theme.muted, id: "actions-others-title")
                        }
                    }
                    ForEach(Array(parts.others.enumerated()), id: \.element.id) { n, a in row(a, n: parts.priority.count + n) }
                    // Done (0.101): tucked away at the foot, folded until he opens it.
                    if !parts.done.isEmpty {
                        FoldHeading(title: "Done", count: parts.done.count, open: doneOpen, id: "actions-done-fold") {
                            withAnimation(.easeInOut(duration: 0.2)) { doneOpen.toggle() }
                        }
                        if doneOpen {
                            ForEach(Array(parts.done.enumerated()), id: \.element.id) { n, a in row(a, n: parts.open + n) }
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
            // Through Edit ▸ Undo's history (0.105): once ⌘Z has taken the step back the bar goes, and the
            // bar's Undo is ⌘Z's. Not in the history (a restore forgot it): its own undo, as before.
            if let removed, model.stillUndoable(step) {
                LineUndoBar(text: removed.text, id: "action-undo") {
                    if !model.undoStep(step) { model.change { _ = $0.putBackLine(removed) } }
                    self.removed = nil
                }
            } else if let ticked, model.stillUndoable(step), model.library.actions.contains(where: { $0.id == ticked.id && $0.done }) {
                LineUndoBar(text: ticked.text, says: "Done", id: "action-tick-undo") {
                    if !model.undoStep(step) { model.change { _ = $0.setActionDone(false, id: ticked.id) } }
                    self.ticked = nil
                }
            }
            HStack(spacing: 8) {
                TextField("Add a to-do", text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(.body)).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 12).frame(minHeight: Metrics.tap)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                    .onSubmit { add() }
                    .accessibilityIdentifier("action-add-text")
                Button { high.toggle() } label: {
                    Text("!").font(.system(.body, weight: .semibold))
                        .foregroundStyle(high ? Color.white : AppSection.actions.color)
                        .frame(width: Metrics.tap, height: Metrics.tap)
                        .background(RoundedRectangle(cornerRadius: 10).fill(high ? AppSection.actions.color : Theme.card))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppSection.actions.color.opacity(0.5), lineWidth: 1))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("action-add-high")
                .accessibilityLabel("High priority")
                .accessibilityAddTraits(high ? .isSelected : [])
                Button { add() } label: { FieldButtonLabel(title: "Add", tint: AppSection.actions.color) }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("action-add")
            }
            .needsLine($needs, typed: text, id: "action-add-needs")
            .padding(.horizontal, 16).padding(.vertical, 10)
            }
        }
        #if os(macOS)
        .titleBarSafeScroll()
        .ignoresSafeArea(.container, edges: .top)     // its first line sits in the title bar strip
        #endif
        .sheet(isPresented: $searching) { SearchScreen().environmentObject(model) }
    }

    /// One to-do: its tick and words (a press ticks it, or takes the tick back), and its ✕. Held —
    /// right-clicked on the Mac — Mark as priority, or Remove priority (0.101).
    private func row(_ a: ActionItem, n: Int) -> some View {
        HStack(spacing: 4) {
            Button { tick(a) } label: {
                HStack(spacing: 8) {
                    TickCircle(on: a.done, tint: AppSection.actions.color)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(a.text)
                            .font(.system(.body))
                            .foregroundStyle(a.done ? Theme.muted : Theme.ink)
                            .strikethrough(a.done, pattern: .solid, color: Theme.muted)
                        if !a.itemName.isEmpty || a.priority == "high" || !a.whenPhase.isEmpty {
                            Text([a.priority == "high" ? "High" : "", a.itemName, a.whenPhase.isEmpty ? "" : phaseLabel(a.whenPhase)]
                                    .filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(.system(.footnote, weight: .semibold))
                                .foregroundStyle(a.priority == "high" && !a.done ? AppSection.actions.color : Theme.muted)
                        }
                    }
                    Spacer(minLength: 8)
                }
                .padding(.vertical, 2).frame(minHeight: Metrics.line).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("action-\(n)")
            .accessibilityAddTraits(a.done ? .isSelected : [])
            Button { remove(a) } label: {
                SVGPath.path("M6 6L18 18M18 6L6 18")
                    .stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                    .onGrid(Metrics.glyph).foregroundStyle(Theme.muted)
                    .frame(width: Metrics.lineButton, height: Metrics.line).contentShape(Rectangle())
            }
            .buttonStyle(.plain).focusEffectDisabled()
            .accessibilityIdentifier("action-\(n)-remove")
            .accessibilityLabel("Remove")
        }
        .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
        // Held anywhere on the row (right-click on the Mac), as Reminders does.
        .contextMenu {
            Button(Library.isPriority(a) ? "Remove priority" : "Mark as priority") {
                let high = !Library.isPriority(a)
                withAnimation(.easeInOut(duration: 0.2)) { model.change { _ = $0.setActionPriority(high, id: a.id) } }
            }
            .accessibilityIdentifier("action-\(n)-priority")
        }
    }

    /// A part's heading — "Priority 2", "Others 3" (0.101): the trip's group headings' words.
    private func partTitle(_ title: String, count: Int, tint: Color, id: String) -> some View {
        HStack(spacing: 6) {
            Text(title).font(.system(.subheadline, weight: .semibold)).foregroundStyle(tint)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier(id)
            Text("\(count)").font(.system(.footnote, weight: .semibold).monospacedDigit()).foregroundStyle(Theme.muted)
                .accessibilityHidden(true)
        }
        .padding(.top, 10).padding(.bottom, 2)
    }

    /// Ticked: into Done, with Undo under the list (0.101). A tick taken back says nothing.
    private func tick(_ a: ActionItem) {
        withAnimation(.easeInOut(duration: 0.2)) { model.change { _ = $0.setActionDone(!a.done, id: a.id) } }
        if !a.done { ticked = a; removed = nil; step = model.lastStep } else if ticked?.id == a.id { ticked = nil }
    }

    /// One of the two sides at the top. Which one is showing is said by colour and
    /// by the selected trait, never by its words alone.
    private func sideButton(_ title: String, on: Bool, id: String, _ tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            Text(title).font(.system(.body, weight: .semibold))
                .foregroundStyle(on ? Color.white : Theme.ink)
                .frame(maxWidth: .infinity, minHeight: Metrics.tap)
                .background(RoundedRectangle(cornerRadius: 10).fill(on ? AppSection.actions.color : Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: on ? 0 : 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier(id)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    /// ✕ takes the to-do away at once, and Undo under the list brings it back — the
    /// gentle answer to his rule that things ask before they go: a quick list that
    /// asked each time would be slow (the spec pass, 5 Oct 2026).
    private func remove(_ a: ActionItem) {
        var gone: ActionItem?
        model.change { gone = $0.removeLine(id: a.id)?.line }
        removed = gone
        ticked = nil
        step = model.lastStep
    }

    private func add() {
        let t = text
        guard !jsTrim(t).isEmpty else { needs = "Type a to-do first."; return }
        model.change { _ = $0.addAction(text: t, priority: high ? "high" : "normal") }
        text = ""; high = false
    }
}

/// Under a list, after ✕: what went, and Undo to bring it back — and since 0.101 after a tick:
/// what was done ("Done", "Bought"), the line folded away with the rest of Done.
struct LineUndoBar: View {
    let text: String
    var says = "Removed"
    let id: String
    let undo: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text("\(says) \u{201C}\(text)\u{201D}")
                .font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.muted)
                .lineLimit(1)
                .accessibilityIdentifier("\(id)-says")
            Spacer(minLength: 8)
            Button(action: undo) {
                Text("Undo")
                    .font(.system(.subheadline, weight: .semibold)).foregroundStyle(AppSection.actions.color)
                    .padding(.horizontal, 12).frame(minHeight: Metrics.chip)
                    .overlay(Capsule().stroke(AppSection.actions.color, lineWidth: 1.4))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain).focusEffectDisabled()
            .accessibilityIdentifier(id)
        }
        .padding(.horizontal, 16).padding(.top, 8)
    }
}

/// The heading of a part tucked away at the foot of a list — Done (n) on To do, Bought (n) on To buy
/// (0.101): the trip's group heading's arrow (right folded, down open) and words, the count beside
/// them. The whole line is the button; selected while open.
struct FoldHeading: View {
    let title: String
    let count: Int
    let open: Bool
    let id: String
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 8) {
                SVGPath.path("M9 6l6 6-6 6")
                    .stroke(style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                    .onGrid(Metrics.glyph)
                    .rotationEffect(.degrees(open ? 90 : 0))
                    .foregroundStyle(Theme.ink)
                    .frame(width: Metrics.lineButton - 6, height: Metrics.line)
                Text(title).font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.muted)
                Text("\(count)").font(.system(.footnote, weight: .semibold).monospacedDigit()).foregroundStyle(Theme.muted)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .padding(.top, 6)
        .accessibilityLabel("\(title), \(count)")
        .accessibilityValue(open ? "open" : "folded")
        .accessibilityAddTraits(open ? .isSelected : [])
        .accessibilityIdentifier(id)
    }
}
