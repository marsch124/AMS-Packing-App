import SwiftUI
import PackingCore
import PackingLibrary

/// A grab list's Icon (0.108) — his question, 2 Nov 2026: "Regarding grab lists: how do I change
/// icons?" Only Swim, Bike and Run wore drawings of their own, and a list he made its first letter.
/// The same picker a template's page has (`IconChoices`): the 132 drawings under their headings,
/// the search above them (⌘F on the Mac, Escape empties it, then closes). First, the choice that
/// is not a drawing: an original list's own doodle ("Its drawing"), or "Letter" for one of his.
/// A tap chooses and closes; Cancel (Escape) closes with nothing chosen. The choice goes to the
/// page's edit, which Save keeps and Cancel throws away.
struct GrabIconPicker: View {
    let list: GrabDefinition
    /// The icon the page's edit has now.
    let current: String
    let pick: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    /// What a list's icon is, in a few words: the drawing's name ("Kayak"), "Its own drawing", or
    /// "Its first letter".
    static func words(_ icon: String, list: GrabDefinition) -> String {
        if let t = Library.grabTemplateIcon(icon) { return t.label }
        if GRAB_ICONS.contains(icon) { return "Its own drawing" }
        return "Its first letter"
    }

    var body: some View {
        let tint = GrabTone.color(list.tone)
        // A ringed tile's mark and words: white on the deep tones, dark on the yellow.
        let ink = list.tone == "yellow" ? Color(hex: 0x16232a) : Color.white
        let original = GRAB_FACTORY.first { $0.id == list.id }
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                GrabDoodle(icon: current, size: 36, initial: list.label).foregroundStyle(tint)
                Text(list.title).font(.system(.title3, weight: .bold)).foregroundStyle(Theme.ink)
                    .lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                Button("Cancel") { dismiss() }
                    .buttonStyle(HeaderButtonStyle(tint: Theme.muted, filled: false)).focusEffectDisabled()
                    .keyboardShortcut(.cancelAction)            // Escape = Cancel (Escape everywhere, 5 Oct 2026)
                    .accessibilityIdentifier("grabicon-cancel")
            }
            .padding(16)
            KeyboardAwayScroll {
                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle(title: "Icon", id: "grabicon-title")
                    IconChoices(isOn: { Library.grabTemplateIcon(current)?.key == $0.key }, tint: tint, ink: ink,
                                pick: { choose(Library.grabIcon(templateKey: $0)) }, close: { dismiss() }) {
                        HStack(spacing: 10) {
                            if let original {
                                // An original list's own doodle — Swim's swimmer, Bike's bike …
                                IconChoiceTile(title: "Its drawing", on: GRAB_ICONS.contains(current) || current.isEmpty,
                                               id: "icon-doodle", tint: tint, ink: ink) {
                                    GrabDoodle(icon: original.icon, size: 32)
                                } pick: { choose(original.icon) }
                            } else {
                                IconChoiceTile(title: "Letter", on: Library.grabTemplateIcon(current) == nil,
                                               id: "icon-letter", tint: tint, ink: ink) {
                                    Text(String(list.label.prefix(1)).uppercased()).font(.system(.title3, weight: .heavy))
                                } pick: { choose("") }
                            }
                            // Half the row, as a template's two first choices are.
                            Color.clear.frame(maxWidth: .infinity, minHeight: 1)
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("grabicon-picker")
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 620)
        #endif
    }

    private func choose(_ icon: String) {
        pick(icon)
        dismiss()
    }
}
