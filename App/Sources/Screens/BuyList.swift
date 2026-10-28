import SwiftUI
import PackingCore
import PackingLibrary

/// The buy-list: what he has put down to buy, and what the library itself thinks
/// is worth buying — a consumable, something marked "needs replacing", something
/// past or near its replace-by date. An offer says WHY, and taking it up stops it
/// being offered again.
///
/// What is bought goes into Bought (n) at the foot, folded until he opens it (0.101, his list of
/// 26 Oct 2026, as To do's Done) — with Undo under the list after the tick.
struct BuyList: View {
    @EnvironmentObject var model: LibraryModel
    @Binding var text: String
    /// What Add was missing, said under the field (never a grey button).
    @State private var needs = ""
    /// The line last removed with ✕, for Undo.
    @State private var removed: ActionItem?
    /// The line last ticked as bought, for Undo (0.101); one bar at a time, as on To do.
    @State private var ticked: ActionItem?
    /// The step of that ✕ or tick in Edit ▸ Undo (0.105): the bar's Undo takes back that step, as ⌘Z does.
    @State private var step: UndoStep.ID?
    /// Bought (n) opened (0.101) — folded each time the page opens.
    @State private var boughtOpen = false

    var body: some View {
        let parts = model.library.toDoParts(kind: "shopping")
        let lines = parts.all
        let open = parts.open
        let offers = model.library.buySuggestions(today: Today.local)
        VStack(spacing: 0) {
            KeyboardAwayScroll {
                // No space between lines: each is as tall as its words (`Metrics.line`), as on
                // To do (44 points top to top until 0.67). A plain stack since 0.101, as on To do: a
                // bought line moves into Bought, and the lazy stack drew it there unticked.
                VStack(alignment: .leading, spacing: 0) {
                    Text(lines.isEmpty ? "Nothing to buy." : (open == 0 ? "All bought." : "\(open) to buy"))
                        .font(.system(.callout, weight: .semibold).monospacedDigit()).foregroundStyle(Theme.muted)
                        .padding(.top, 12).padding(.bottom, 4)
                        .accessibilityIdentifier("buy-count")
                    // To buy → Apple Reminders (his idea 9), to take to the shop.
                    if !lines.isEmpty { RemindersSend().environmentObject(model).padding(.bottom, 6) }

                    ForEach(Array(parts.others.enumerated()), id: \.element.id) { n, line in row(line, n: n) }
                    // Bought (0.101): tucked away under the open lines, folded until he opens it.
                    if !parts.done.isEmpty {
                        FoldHeading(title: "Bought", count: parts.done.count, open: boughtOpen, id: "buy-done-fold") {
                            withAnimation(.easeInOut(duration: 0.2)) { boughtOpen.toggle() }
                        }
                        if boughtOpen {
                            ForEach(Array(parts.done.enumerated()), id: \.element.id) { n, line in row(line, n: open + n) }
                        }
                    }

                    if !offers.isEmpty {
                        Text("Worth buying").font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(Theme.muted).padding(.top, 12).padding(.bottom, 2)
                            .accessibilityIdentifier("buy-offers")
                        ForEach(Array(offers.enumerated()), id: \.element.item.id) { n, offer in
                            Button { model.change { _ = $0.addToBuyList(offer) } } label: {
                                HStack(spacing: 8) {
                                    Text("+").font(.system(.body, weight: .bold))
                                        .foregroundStyle(AppSection.actions.color).frame(width: Metrics.mark)
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text(offer.item.name).font(.system(.body))
                                            .foregroundStyle(Theme.ink)
                                            .accessibilityIdentifier("buy-offer-\(n)-name")
                                        Text(offer.reason).font(.system(.footnote, weight: .semibold))
                                            .foregroundStyle(offer.reason == "Needs replacing" || offer.reason == "Expired"
                                                             ? AppSection.actions.color : Theme.muted)
                                            .accessibilityIdentifier("buy-offer-\(n)-why")
                                    }
                                    Spacer(minLength: 8)
                                }
                                .padding(.vertical, 3).frame(minHeight: Metrics.line).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("buy-offer-\(n)")
                            .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
            // Through Edit ▸ Undo's history (0.105), as on To do; its reminder follows (`ShopReminders.follow`).
            if let removed, model.stillUndoable(step) {
                LineUndoBar(text: removed.text, id: "buy-undo") {
                    if !model.undoStep(step) { model.change { _ = $0.putBackLine(removed) } }
                    self.removed = nil
                }
            } else if let ticked, model.stillUndoable(step), let now = model.library.actions.first(where: { $0.id == ticked.id }), now.done {
                LineUndoBar(text: ticked.text, says: "Bought", id: "buy-tick-undo") {
                    if model.undoStep(step) { self.ticked = nil } else { tick(now) }
                }
            }
            HStack(spacing: 8) {
                TextField("Add something to buy", text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(.body)).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 12).frame(minHeight: Metrics.tap)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                    .onSubmit { add() }
                    .accessibilityIdentifier("buy-add-text")
                Button { add() } label: { FieldButtonLabel(title: "Add", tint: AppSection.actions.color) }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("buy-add")
            }
            .needsLine($needs, typed: text, id: "buy-add-needs")
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
    }

    /// One line: its tick and words, and its ✕.
    private func row(_ line: ActionItem, n: Int) -> some View {
                    HStack(spacing: 4) {
                        Button { tick(line) } label: {
                            HStack(spacing: 8) {
                                TickCircle(on: line.done, tint: AppSection.actions.color)
                                Text(line.text)
                                    .font(.system(.body))
                                    .foregroundStyle(line.done ? Theme.muted : Theme.ink)
                                    .strikethrough(line.done, pattern: .solid, color: Theme.muted)
                                    .accessibilityIdentifier("buy-\(n)-name")
                                Spacer(minLength: 8)
                            }
                            .padding(.vertical, 2).frame(minHeight: Metrics.line).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("buy-\(n)")
                        .accessibilityAddTraits(line.done ? .isSelected : [])
                        Button { remove(line) } label: {
                            SVGPath.path("M6 6L18 18M18 6L6 18")
                                .stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                                .onGrid(Metrics.glyph).foregroundStyle(Theme.muted)
                                .frame(width: Metrics.lineButton, height: Metrics.line).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).focusEffectDisabled()
                        .accessibilityIdentifier("buy-\(n)-remove")
                        .accessibilityLabel("Remove \(line.text)")
                    }
                    .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
    }

    /// Ticked or unticked here, its reminder follows: unticked here after the shop
    /// ticked it, the next read back ticked it again (the spec pass, 5 Oct 2026).
    private func tick(_ line: ActionItem) {
        let rid = model.library.reminderOf(actionId: line.id)
        withAnimation(.easeInOut(duration: 0.2)) { model.change { _ = $0.setActionDone(!line.done, id: line.id) } }
        if let rid { Task { await ShopReminders.shared.setDone(rid, !line.done) } }
        // Bought: into Bought, with Undo under the list (0.101). A tick taken back says nothing.
        if !line.done { ticked = line; removed = nil; step = model.lastStep } else if ticked?.id == line.id { ticked = nil }
    }

    /// Gone from here = gone from Reminders too (its reminder stayed behind until
    /// 0.62). Undo brings the line back, to be sent again.
    private func remove(_ line: ActionItem) {
        var gone: (line: ActionItem, reminderId: String?)?
        model.change { gone = $0.removeLine(id: line.id) }
        removed = gone?.line
        ticked = nil
        step = model.lastStep
        if let rid = gone?.reminderId { Task { await ShopReminders.shared.remove(rid) } }
    }

    private func add() {
        let t = text
        guard !jsTrim(t).isEmpty else { needs = "Type what to buy first."; return }
        model.change { _ = $0.addToBuyList(text: t) }
        text = ""
    }
}
