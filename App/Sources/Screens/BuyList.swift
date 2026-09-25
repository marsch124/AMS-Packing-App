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

                    ForEach(Array(lines.enumerated()), id: \.element.id) { n, line in
                        HStack(spacing: 4) {
                            Button { model.change { _ = $0.setActionDone(!line.done, id: line.id) } } label: {
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
                            Button { model.change { $0.deleteAction(id: line.id) } } label: {
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
                                        Text(offer.reason).font(.system(size: 14, weight: .semibold))
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
            HStack(spacing: 8) {
                TextField("Add something to buy", text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 17, weight: .medium)).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 12).frame(minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                    .onSubmit { add() }
                    .accessibilityIdentifier("buy-add-text")
                Button { add() } label: {
                    Text("Add").font(.system(size: 16, weight: .bold))
                        .foregroundStyle(jsTrim(text).isEmpty ? Theme.muted : Color.white)
                        .padding(.horizontal, 16).frame(minHeight: 44)
                        .background(RoundedRectangle(cornerRadius: 10)
                            .fill(jsTrim(text).isEmpty ? Theme.line : AppSection.actions.color))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .disabled(jsTrim(text).isEmpty)
                .accessibilityIdentifier("buy-add")
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
    }

    private func add() {
        let t = text
        guard !jsTrim(t).isEmpty else { return }
        model.change { _ = $0.addToBuyList(text: t) }
        text = ""
    }
}
