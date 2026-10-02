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

    var body: some View {
        let toSend = model.library.buyLinesToSend()
        VStack(alignment: .leading, spacing: 6) {
            if !toSend.isEmpty {
                Button { Task { await send(toSend) } } label: {
                    Text(toSend.count == 1 ? "Send 1 to Reminders" : "Send \(toSend.count) to Reminders")
                        .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 16).frame(minHeight: 44)
                        .background(Capsule().fill(AppSection.actions.color))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("buy-send")
            }
            if !says.isEmpty {
                Text(says)
                    .font(.system(size: 15, weight: .semibold))
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

    /// What was ticked in the shop is ticked here. Never asks for access: only reads
    /// when the app already may.
    private func readBack() async {
        let open = model.library.sentBuyLines().filter { !$0.line.done }
        guard !open.isEmpty, ShopReminders.shared.mayRead else { return }
        let ticked = await ShopReminders.shared.ticked(open.map(\.reminderId))
        if !ticked.isEmpty { model.change { _ = $0.takeBought(reminderIds: ticked) } }
    }
}
