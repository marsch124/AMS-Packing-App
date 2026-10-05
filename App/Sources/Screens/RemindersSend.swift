import SwiftUI
import PackingCore
import PackingLibrary

/// To buy → Apple Reminders, at the top of the buy list (his idea 9, 2 Oct 2026). One
/// press sends the open lines not sent yet; it then says where they went. Opening the
/// list reads Reminders back: what was ticked in the shop is ticked here.
struct RemindersSend: View {
    @EnvironmentObject var model: LibraryModel
    @State private var says = ""
    @State private var trouble = false
    /// Sent lines whose reminder is no longer in Reminders (deleted there): offered
    /// for sending again — only when he presses Send, so one that has merely not
    /// reached this device yet is never doubled behind his back (the spec pass,
    /// 5 Oct 2026; they used to stay "sent" for ever).
    @State private var gone: Set<String> = []

    var body: some View {
        let toSend = model.library.buyLinesToSend(gone: gone)
        VStack(alignment: .leading, spacing: 6) {
            if !toSend.isEmpty {
                Button { Task { await send(toSend) } } label: {
                    Text(toSend.count == 1 ? "Send 1 to Reminders" : "Send \(toSend.count) to Reminders")
                        .font(.system(.callout, weight: .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 12).frame(minHeight: Metrics.tap)
                        .background(Capsule().fill(AppSection.actions.color))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("buy-send")
            }
            if !says.isEmpty {
                Text(says)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(trouble ? AppSection.actions.color : Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("buy-send-says")
            }
        }
        .padding(.top, 6)
        .task { await readBack() }
    }

    private func send(_ lines: [ActionItem]) async {
        guard await ShopReminders.shared.askAccess() else {
            trouble = true
            says = "This device does not let the app into Reminders. Allow it in the device's Settings, under Reminders."
            return
        }
        do {
            let sent = try await ShopReminders.shared.send(lines)
            model.change { lib in for s in sent { _ = lib.markSent(actionId: s.actionId, reminderId: s.reminderId) } }
            trouble = false
            says = "\(sent.count) in Reminders, in the list \u{201C}\(ShopReminders.listName)\u{201D}. Tick them there in the shop \u{2014} they tick here too."
        } catch {
            trouble = true
            says = "Reminders did not take them. Try again in a moment."
        }
    }

    /// What was ticked in the shop is ticked here (also whenever the app comes back to
    /// the front — RootView). Never asks for access: only reads when the app already may.
    private func readBack() async {
        await ShopReminders.shared.readBack(into: model)
        gone = await ShopReminders.shared.gone(model.library.sentBuyLines().filter { !$0.line.done }.map(\.reminderId))
    }
}
