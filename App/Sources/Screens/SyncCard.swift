import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif
import PackingCore
import PackingLibrary

/// Settings: iCloud sync on this device — his field test, 3 Oct 2026 ("we need to get
/// the sync going because I need to work from the Mac"). When this device last sent
/// and received, what iCloud does not have yet, and why a send failed, in plain
/// words. Sync now checks in from this device; the OTHER device then shows it — a
/// direct test of each road.
struct SyncCard: View {
    @EnvironmentObject var model: LibraryModel
    @State private var check: SyncCheck?
    @State private var said = ""

    static var device: String {
        #if os(macOS)
        return "Mac"
        #else
        return "iPhone"
        #endif
    }
    static var other: String { device == "Mac" ? "iPhone" : "Mac" }

    var body: some View {
        let c = check
        let state = SyncCheck.state(usesICloud: model.usesICloud, check: c)
        let stuck = state == .stuck
        // Compact, as Settings' cards are (8 points between its lines, 14 inside, until 0.67).
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text("iCloud sync").font(.system(.body, weight: .semibold)).foregroundStyle(Theme.ink)
                Spacer()
                Text(state.word)
                    .font(.system(.footnote, weight: .semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 3)
                    .background(Capsule().fill(state == .working ? AppSection.events.color
                                               : stuck ? AppSection.actions.color : Theme.muted))
                    .accessibilityIdentifier("sync-state")
            }
            if !model.usesICloud {
                quiet("This copy of the app keeps its library on this device only.", id: "sync-off")
            } else if let c {
                quiet("Sent: \(SyncCard.when(c.lastSent)) \u{00B7} received: \(SyncCard.when(c.lastReceived))", id: "sync-times")
                if c.notSentTotal > 0 {
                    loud("Not in iCloud yet: \(c.notSentWords).", id: "sync-notsent")
                }
                if let p = c.problem {
                    loud("The last \(p.sending ? "send" : "receive") failed \(SyncCard.when(p.at)): \(SyncCheck.plain(domain: p.domain, code: p.code)).",
                         id: "sync-problem")
                }
            } else {
                // iCloud is on, but this device cannot read its own record of it: say
                // so, rather than a green "Working" over nothing (the spec pass, 2026-10-05).
                quiet("This device cannot tell right now how the sync is going.", id: "sync-unknown")
            }
            quiet(model.library.lastCheckIn(device: SyncCard.other).map { "The \(SyncCard.other) last checked in \(SyncCard.when(iso: $0))." }
                  ?? "The \(SyncCard.other) has not checked in yet \u{2014} press Sync now there.", id: "sync-other")
            quiet(model.library.lastCheckIn(device: SyncCard.device).map { "This \(SyncCard.device) checked in \(SyncCard.when(iso: $0))." }
                  ?? "This \(SyncCard.device) has not checked in yet.", id: "sync-self")
            HStack(spacing: 10) {
                Button { syncNow() } label: {
                    Text("Sync now").font(.system(.callout, weight: .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 12).frame(minHeight: Metrics.tap)
                        .background(Capsule().fill(AppSection.events.color))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("sync-now")
                Button("Copy details for Claude") { copyDetails() }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .font(.system(.subheadline, weight: .semibold)).foregroundStyle(AppSection.settings.color)
                    .accessibilityIdentifier("sync-copy")
            }
            if !said.isEmpty { quiet(said, id: "sync-said") }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(stuck ? AppSection.actions.color : Theme.line, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sync-card")
        .onAppear(perform: refresh)
        .onReceive(model.$library.debounce(for: .seconds(1), scheduler: RunLoop.main)) { _ in refresh() }
    }

    private func quiet(_ text: String, id: String) -> some View {
        Text(text).font(.system(.subheadline)).foregroundStyle(Theme.muted)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(id)
    }

    private func loud(_ text: String, id: String) -> some View {
        Text(text).font(.system(.subheadline, weight: .semibold)).foregroundStyle(AppSection.actions.color)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(id)
    }

    private func refresh() {
        guard model.usesICloud else { return }
        check = SyncCheck.read()
    }

    /// Check in: a small note that travels like everything else. Then look again.
    private func syncNow() {
        model.change { $0.checkIn(device: SyncCard.device) }
        said = "Checked in. On the \(SyncCard.other), Settings shows it within a minute or so if the road is open."
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            model.reload()
            refresh()
        }
    }

    private func copyDetails() {
        var text = check?.details(device: SyncCard.device, version: AppInfo.version)
            ?? "Sync details · \(SyncCard.device) · \(AppInfo.version)\nNo iCloud record on this device."
        text += "\nThis device holds: " + model.library.records().reduce(into: [String: Int]()) { $0[$1.table.rawValue, default: 0] += 1 }
            .sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: ", ")
        #if os(iOS)
        UIPasteboard.general.string = text
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
        said = "Copied. Paste it into the chat with Claude."
    }

    /// "today 13:52", "2 Oct 22:10", "never" (`SyncCheck.when`, held by the model tests).
    static func when(_ date: Date?) -> String { SyncCheck.when(date) }

    static func when(iso: String) -> String { SyncCheck.when(iso: iso) }
}
