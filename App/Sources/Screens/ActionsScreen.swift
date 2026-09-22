import SwiftUI
import PackingCore
import PackingLibrary

/// Actions: the central to-do list — open before done, high before normal,
/// sooner before later. A tick is permanent; it does not reset per trip.
struct ActionsScreen: View {
    @EnvironmentObject var model: LibraryModel
    @State private var text = ""
    @State private var high = false

    var body: some View {
        let todos = model.library.sortedActions(kind: "todo")
        let open = todos.filter { !$0.done }.count
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    Text(todos.isEmpty ? "Nothing to do." : (open == 0 ? "All done." : "\(open) to do"))
                        .font(.system(size: 16, weight: .bold).monospacedDigit()).foregroundStyle(Theme.muted)
                        .padding(.top, 14)
                        .accessibilityIdentifier("actions-count")
                    ForEach(Array(todos.enumerated()), id: \.element.id) { n, a in
                        HStack(spacing: 4) {
                            Button { model.change { _ = $0.setActionDone(!a.done, id: a.id) } } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle().stroke(AppSection.actions.color, lineWidth: 2).frame(width: 26, height: 26)
                                        if a.done {
                                            Circle().fill(AppSection.actions.color).frame(width: 26, height: 26)
                                            Tick().stroke(Color.white, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round)).frame(width: 26, height: 26)
                                        }
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(a.text)
                                            .font(.system(size: 17, weight: a.done ? .regular : .medium))
                                            .foregroundStyle(a.done ? Theme.muted : Theme.ink)
                                            .strikethrough(a.done, pattern: .solid, color: Theme.muted)
                                        if !a.itemName.isEmpty || a.priority == "high" || !a.whenPhase.isEmpty {
                                            Text([a.priority == "high" ? "High" : "", a.itemName, a.whenPhase.isEmpty ? "" : phaseLabel(a.whenPhase)]
                                                    .filter { !$0.isEmpty }.joined(separator: " · "))
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundStyle(a.priority == "high" && !a.done ? AppSection.actions.color : Theme.muted)
                                        }
                                    }
                                    Spacer(minLength: 8)
                                }
                                .padding(.vertical, 10).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("action-\(n)")
                            .accessibilityAddTraits(a.done ? .isSelected : [])
                            Button { model.change { $0.deleteAction(id: a.id) } } label: {
                                SVGPath.path("M6 6L18 18M18 6L6 18")
                                    .stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                                    .frame(width: 24, height: 24).foregroundStyle(Theme.muted)
                                    .frame(width: 40, height: 40).contentShape(Rectangle())
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
            HStack(spacing: 8) {
                TextField("Add a to-do", text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 17, weight: .medium)).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 12).frame(minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                    .onSubmit { add() }
                    .accessibilityIdentifier("action-add-text")
                Button { high.toggle() } label: {
                    Text("!").font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(high ? Color.white : AppSection.actions.color)
                        .frame(width: 44, height: 44)
                        .background(RoundedRectangle(cornerRadius: 10).fill(high ? AppSection.actions.color : Theme.card))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppSection.actions.color.opacity(0.5), lineWidth: 1))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("action-add-high")
                .accessibilityLabel("High priority")
                .accessibilityAddTraits(high ? .isSelected : [])
                Button { add() } label: {
                    Text("Add").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 16).frame(minHeight: 44)
                        .background(RoundedRectangle(cornerRadius: 10).fill(jsTrim(text).isEmpty ? Theme.line : AppSection.actions.color))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .disabled(jsTrim(text).isEmpty)
                .accessibilityIdentifier("action-add")
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
    }

    private func add() {
        let t = text
        guard !jsTrim(t).isEmpty else { return }
        model.change { _ = $0.addAction(text: t, priority: high ? "high" : "normal") }
        text = ""; high = false
    }
}
