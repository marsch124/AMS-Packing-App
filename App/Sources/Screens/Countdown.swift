import SwiftUI
import PackingCore
import PackingLibrary

/// The trip he leaves on next, counted down on Home — his pre-trip idea 6 (2 Oct
/// 2026). The days in big figures, readable without glasses; the trip's name; the
/// next packing step and when it falls due. A tap opens the trip.
struct CountdownCard: View {
    let next: Library.NextTrip
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(alignment: .center, spacing: 14) {
                VStack(spacing: -2) {
                    Text(next.days == 0 ? "Today" : "\(next.days)")
                        .font(.system(size: next.days == 0 ? 26 : 44, weight: .heavy).monospacedDigit())
                        .foregroundStyle(AppSection.events.color)
                        .lineLimit(1).minimumScaleFactor(0.6)
                    if next.days > 0 {
                        Text(next.days == 1 ? "day" : "days")
                            .font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.muted)
                    }
                }
                .frame(minWidth: 72)
                VStack(alignment: .leading, spacing: 3) {
                    Text(next.name).font(.system(size: 18, weight: .heavy)).foregroundStyle(Theme.ink).lineLimit(1)
                    Text(CountdownCard.stepLine(next, today: Today.local))
                        .font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                SVGPath.path("M9 6l6 6-6 6").stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                    .frame(width: 20, height: 20).foregroundStyle(Theme.muted)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppSection.events.color, lineWidth: 1.2))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier("home-countdown")
    }

    /// "≥1 week ahead: 12 to pack, from 14 Oct" — or "now" once it is due.
    static func stepLine(_ next: Library.NextTrip, today: String) -> String {
        guard let s = next.step else { return next.left == 0 ? "All packed" : "\(next.left) to pack" }
        let when = jsStringLess(today, s.date) ? "from \(shortDay(s.date))" : "now"
        return "\(s.says), \(when)"
    }

    private static let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    /// "2026-10-14" → "14 Oct".
    static func shortDay(_ ymd: String) -> String {
        let p = ymd.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3, (1...12).contains(p[1]) else { return ymd }
        return "\(p[2]) \(months[p[1] - 1])"
    }
}

/// Settings: Remind me to pack — per device, off until he turns it on (his idea 7).
/// On, it names the next reminder, so he can see what it will say and when.
struct RemindersCard: View {
    @EnvironmentObject var model: LibraryModel
    @AppStorage(PackingReminders.onKey) private var on = false
    @State private var refused = false

    var body: some View {
        let next = PackingReminders.upcoming(model.library).first
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(get: { on }, set: { want in
                Task {
                    let ok = want ? await PackingReminders.shared.askToShow() : false
                    on = want && ok
                    refused = want && !ok
                    await PackingReminders.shared.reschedule(model.library)
                }
            })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Remind me to pack").font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.ink)
                    Text("On this device, at 9 in the morning of the day each packing step is due \u{2014} a week ahead, the day before, the morning.")
                        .font(.system(size: 14)).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            // Green when on, like every switch he knows: the Settings slate read as "off".
            .tint(AppSection.events.color)
            .accessibilityIdentifier("settings-reminders")
            if refused {
                Text("This device does not allow the app to remind you. Allow it in the device's Settings, under Notifications.")
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(AppSection.actions.color)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("settings-reminders-refused")
            } else if on {
                Text(next.map { "Next: \(CountdownCard.shortDay($0.date)) \u{00B7} \($0.tripName) \u{2014} \($0.says)" }
                     ?? "Nothing to remind you of yet: no trip with dates ahead.")
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(AppSection.settings.color)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("settings-reminders-next")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings-reminders-card")
    }
}
