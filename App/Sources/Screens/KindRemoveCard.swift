import SwiftUI
import PackingCore
import PackingLibrary

/// "Remove “Reminders”?" (0.107 — his words, 30 Oct 2026: "I need the ability to delete a Kind of thing, even if there
/// are items that are connected to this very Kind of thing choice. Example: I don't understand why I defined
/// Reminders. I want them gone"). Asked in the middle of the page, the rest dimmed — the look of a template's "Take
/// it off?" card: how many have the kind, "Move them to" (the app's drop-down: his other kinds, in his order), that
/// nothing is kept until the page's own Done or Save, and Cancel (outlined; Escape on the Mac) · Remove (filled, the
/// removal red). A tap beside the card is Cancel. ONE card for the two places a kind is removed: Your choices
/// (Done) and a thing's Kind of thing drop-down (Save). The page holds what Remove does until its Done or Save.
struct KindRemoveCard: View {
    let label: String
    let use: KindUse
    /// His other kinds, as the page shows them (value = the page's key for it).
    let options: [(value: String, label: String)]
    /// Where its things go — the page's key.
    @Binding var to: String
    /// The page's own button that keeps it: "Done" (Your choices) or "Save" (a thing's page).
    let keptBy: String
    let cancel: () -> Void
    let remove: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
                .onTapGesture { cancel() }
            VStack(spacing: 14) {
                SVGPath.path("M6 6L18 18M18 6L6 18")
                    .stroke(style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                    .frame(width: 22, height: 22)
                    .foregroundStyle(AppSection.actions.color)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(AppSection.actions.color.opacity(0.14)))
                    .accessibilityHidden(true)
                Text("Remove \u{201C}\(label)\u{201D}?")
                    .font(.system(.body, weight: .semibold)).foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("choices-remove-question")
                Text(use.says)
                    .font(.system(.subheadline)).foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("choices-remove-says")
                DropDown(title: use.moveTo, heading: .title, options: options, selected: to,
                         id: "choices-remove-to", tint: AppSection.settings.color) { to = $0 }
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Nothing is kept until you press \(keptBy).")
                    .font(.system(.footnote)).foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("choices-remove-kept")
                HStack(spacing: 12) {
                    Button { cancel() } label: { Text("Cancel") }
                        .buttonStyle(HeaderButtonStyle(tint: Theme.ink, filled: false, stretch: true)).focusEffectDisabled()
                        .keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier("choices-remove-no")
                    Button { remove() } label: { Text("Remove") }
                        .buttonStyle(HeaderButtonStyle(tint: AppSection.actions.color, filled: true, stretch: true)).focusEffectDisabled()
                        .accessibilityIdentifier("choices-remove-yes")
                }
                .padding(.top, 4)
            }
            .padding(22)
            .frame(maxWidth: 360)
            .background(RoundedRectangle(cornerRadius: 18).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.line, lineWidth: 1))
            .shadow(color: .black.opacity(0.25), radius: 20, y: 8)
            .padding(24)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("choices-remove-card")
        }
        .transition(.opacity)
    }
}
