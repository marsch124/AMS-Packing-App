import SwiftUI
import PackingCore
import PackingLibrary

/// Settings: Show my things in Spotlight (0.92 — his yes of 19 Oct 2026). Per device, on unless he
/// switches it off; off takes every thing out of this device's Spotlight at once. Under the switch,
/// how many things Spotlight holds on this device — "10 things in Spotlight on this iPhone" — which
/// is also how a test sees the index filled and emptied (`settings-spotlight-count`).
struct SpotlightCard: View {
    @EnvironmentObject var model: LibraryModel
    @ObservedObject private var spotlight = ThingSpotlight.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: Binding(get: { spotlight.on }, set: { spotlight.set(on: $0, library: model.library) })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show my things in Spotlight").font(.system(.body, weight: .semibold)).foregroundStyle(Theme.ink)
                    Text("Type a thing\u{2019}s name in Spotlight on this \(SyncCard.device) to see where it is \u{2014} tap it and its page opens.")
                        .font(.system(.footnote)).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            // Green when on, like every switch he knows (as Remind me to pack).
            .tint(AppSection.events.color)
            .accessibilityIdentifier("settings-spotlight")
            Text(SpotlightCard.says(on: spotlight.on, count: spotlight.count, unavailable: spotlight.unavailable))
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(spotlight.on && !spotlight.unavailable ? AppSection.settings.color : Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("settings-spotlight-count")
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings-spotlight-card")
    }

    /// The line under the switch: how many things this device's Spotlight holds — read from what
    /// was handed over, so off says "none" only once they are really out.
    static func says(on: Bool, count: Int, unavailable: Bool) -> String {
        let device = SyncCard.device
        if on && unavailable { return "This \(device)\u{2019}s Spotlight cannot take them." }
        if count == 0 { return on ? "Putting your things in Spotlight\u{2026}" : "None of your things are in Spotlight on this \(device)." }
        if !on { return "Taking your things out of Spotlight\u{2026}" }
        return "\(count) \(count == 1 ? "thing" : "things") in Spotlight on this \(device)"
    }
}
