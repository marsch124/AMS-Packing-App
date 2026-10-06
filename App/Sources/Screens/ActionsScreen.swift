import SwiftUI
import PackingCore
import PackingLibrary

/// Actions: the central to-do list — open before done, high before normal,
/// sooner before later. A tick is permanent; it does not reset per trip.
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

    var body: some View {
        let todos = model.library.sortedActions(kind: "todo")
        let open = todos.filter { !$0.done }.count
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
                LazyVStack(alignment: .leading, spacing: 0) {
                    Text(todos.isEmpty ? "Nothing to do." : (open == 0 ? "All done." : "\(open) to do"))
                        .font(.system(.callout, weight: .semibold).monospacedDigit()).foregroundStyle(Theme.muted)
                        .padding(.top, 12).padding(.bottom, 4)
                        .accessibilityIdentifier("actions-count")
                    ForEach(Array(todos.enumerated()), id: \.element.id) { n, a in
                        HStack(spacing: 4) {
                            Button { model.change { _ = $0.setActionDone(!a.done, id: a.id) } } label: {
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
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
            if let removed {
                LineUndoBar(text: removed.text, id: "action-undo") {
                    model.change { _ = $0.putBackLine(removed) }
                    self.removed = nil
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
    }

    private func add() {
        let t = text
        guard !jsTrim(t).isEmpty else { needs = "Type a to-do first."; return }
        model.change { _ = $0.addAction(text: t, priority: high ? "high" : "normal") }
        text = ""; high = false
    }
}

/// Under a list, after ✕: what went, and Undo to bring it back.
struct LineUndoBar: View {
    let text: String
    let id: String
    let undo: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text("Removed \u{201C}\(text)\u{201D}")
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
