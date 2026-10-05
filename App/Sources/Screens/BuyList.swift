import SwiftUI
import PackingCore
import PackingLibrary

/// The buy-list: what he has put down to buy, and what the library itself thinks
/// is worth buying — a consumable, something marked "needs replacing", something
/// past or near its replace-by date. An offer says WHY, and taking it up stops it
/// being offered again.
struct BuyList: View {
    @EnvironmentObject var model: LibraryModel
    @Binding var text: String
    /// What Add was missing, said under the field (never a grey button).
    @State private var needs = ""
    /// The line last removed with ✕, for Undo.
    @State private var removed: ActionItem?

    var body: some View {
        let lines = model.library.buyList()
        let open = lines.filter { !$0.done }.count
        let offers = model.library.buySuggestions(today: Today.local)
        VStack(spacing: 0) {
            KeyboardAwayScroll {
                LazyVStack(alignment: .leading, spacing: 4) {
                    Text(lines.isEmpty ? "Nothing to buy." : (open == 0 ? "All bought." : "\(open) to buy"))
                        .font(.system(size: 16, weight: .bold).monospacedDigit()).foregroundStyle(Theme.muted)
                        .padding(.top, 14)
                        .accessibilityIdentifier("buy-count")
                    // To buy → Apple Reminders (his idea 9), to take to the shop.
                    if !lines.isEmpty { RemindersSend().environmentObject(model) }

                    ForEach(Array(lines.enumerated()), id: \.element.id) { n, line in
                        HStack(spacing: 4) {
                            Button { tick(line) } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle().stroke(AppSection.actions.color, lineWidth: 2).frame(width: 26, height: 26)
                                        if line.done {
                                            Circle().fill(AppSection.actions.color).frame(width: 26, height: 26)
                                            Tick().stroke(Color.white, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                                                .frame(width: 26, height: 26)
                                        }
                                    }
                                    Text(line.text)
                                        .font(.system(size: 17, weight: line.done ? .regular : .medium))
                                        .foregroundStyle(line.done ? Theme.muted : Theme.ink)
                                        .strikethrough(line.done, pattern: .solid, color: Theme.muted)
                                        .accessibilityIdentifier("buy-\(n)-name")
                                    Spacer(minLength: 8)
                                }
                                .padding(.vertical, 10).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("buy-\(n)")
                            .accessibilityAddTraits(line.done ? .isSelected : [])
                            Button { remove(line) } label: {
                                SVGPath.path("M6 6L18 18M18 6L6 18")
                                    .stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                                    .frame(width: 24, height: 24).foregroundStyle(Theme.muted)
                                    .frame(width: 40, height: 40).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain).focusEffectDisabled()
                            .accessibilityIdentifier("buy-\(n)-remove")
                            .accessibilityLabel("Remove \(line.text)")
                        }
                        .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
                    }

                    if !offers.isEmpty {
                        Text("Worth buying").font(.system(size: 15, weight: .heavy))
                            .foregroundStyle(Theme.muted).padding(.top, 18)
                            .accessibilityIdentifier("buy-offers")
                        ForEach(Array(offers.enumerated()), id: \.element.item.id) { n, offer in
                            Button { model.change { _ = $0.addToBuyList(offer) } } label: {
                                HStack(spacing: 12) {
                                    Text("+").font(.system(size: 22, weight: .heavy))
                                        .foregroundStyle(AppSection.actions.color).frame(width: 26)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(offer.item.name).font(.system(size: 17, weight: .medium))
                                            .foregroundStyle(Theme.ink)
                                            .accessibilityIdentifier("buy-offer-\(n)-name")
                                        Text(offer.reason).font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(offer.reason == "Needs replacing" || offer.reason == "Expired"
                                                             ? AppSection.actions.color : Theme.muted)
                                            .accessibilityIdentifier("buy-offer-\(n)-why")
                                    }
                                    Spacer(minLength: 8)
                                }
                                .padding(.vertical, 10).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("buy-offer-\(n)")
                            .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
            if let removed {
                LineUndoBar(text: removed.text, id: "buy-undo") {
                    model.change { _ = $0.putBackLine(removed) }
                    self.removed = nil
                }
            }
            HStack(spacing: 8) {
                TextField("Add something to buy", text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 17, weight: .medium)).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 12).frame(minHeight: 44)
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

    /// Ticked or unticked here, its reminder follows: unticked here after the shop
    /// ticked it, the next read back ticked it again (the spec pass, 5 Oct 2026).
    private func tick(_ line: ActionItem) {
        let rid = model.library.reminderOf(actionId: line.id)
        model.change { _ = $0.setActionDone(!line.done, id: line.id) }
        if let rid { Task { await ShopReminders.shared.setDone(rid, !line.done) } }
    }

    /// Gone from here = gone from Reminders too (its reminder stayed behind until
    /// 0.62). Undo brings the line back, to be sent again.
    private func remove(_ line: ActionItem) {
        var gone: (line: ActionItem, reminderId: String?)?
        model.change { gone = $0.removeLine(id: line.id) }
        removed = gone?.line
        if let rid = gone?.reminderId { Task { await ShopReminders.shared.remove(rid) } }
    }

    private func add() {
        let t = text
        guard !jsTrim(t).isEmpty else { needs = "Type what to buy first."; return }
        model.change { _ = $0.addToBuyList(text: t) }
        text = ""
    }
}
