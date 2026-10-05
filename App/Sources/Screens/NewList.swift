import SwiftUI
import PackingCore
import PackingLibrary

/// Make a new list of his own.
///
/// The web app asks one question in a browser prompt — a name — and leaves the
/// list ungrouped, which means it lands in "Other" and he has to go and file it.
/// Here the activity area is asked for at the same time, because it is one tap and
/// it is the difference between a list that is where he expects it and one that is not.
///
/// It also REFUSES a name he already has. The web app allows two lists with one
/// name (identity is the id), but this app's own health check reads two lists
/// sharing a name as the sign that two libraries have met on one account — the
/// accident of 31 August. Letting him make one by hand would cry wolf.
struct NewList: View {
    /// What to do with the finished list: it is saved and then opened.
    let made: (PackList) -> Void
    let library: Library
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var group = ""
    /// What is still missing, said under the button once it is pressed too early.
    @State private var needs = ""
    @FocusState private var writing: Bool

    /// The bag list's stored name ("Containers") is not one he sees, so it is not
    /// taken (the spec pass, 5 Oct 2026).
    private var taken: Bool { library.templateNameTaken(name) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("A new template").font(.system(.title3, weight: .bold))
                    .foregroundStyle(AppSection.templates.color)
                    .accessibilityIdentifier("newlist-title")
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(HeaderButtonStyle(tint: Theme.muted, filled: false)).focusEffectDisabled()
                    .font(.system(.callout, weight: .semibold)).foregroundStyle(Theme.muted)
                    .accessibilityIdentifier("newlist-cancel")
            }
            .padding(16)

            KeyboardAwayScroll {
                VStack(alignment: .leading, spacing: 0) {
                    Text("WHAT IS IT CALLED")
                        .font(.system(.caption, weight: .semibold)).foregroundStyle(Theme.muted).kerning(0.6)
                        .padding(.bottom, 6)
                    TextField("", text: $name)
                        .textFieldStyle(.plain)
                        .font(.system(.body, weight: .semibold)).foregroundStyle(Theme.ink)
                        .padding(.horizontal, 12).frame(minHeight: Metrics.tap)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(taken ? AppSection.actions.color : Theme.line, lineWidth: 1))
                        .focused($writing)
                        .onSubmit { make() }
                        .accessibilityIdentifier("newlist-name")

                    if taken {
                        Text("You already have a template called that.")
                            .font(.system(.footnote, weight: .semibold))
                            .foregroundStyle(AppSection.actions.color)
                            .padding(.top, 6)
                            .accessibilityIdentifier("newlist-taken")
                    }

                    // His question (test H.6), in the word of the field test (Oct 2026):
                    // "Please change the word 'shelf' throughout the app and call it
                    // 'Activity area.' We understand that word much better."
                    SectionTitle(title: "In which activity area should it live?", id: "newlist-area-title")
                        .padding(.top, 4).padding(.bottom, 6)
                    ForEach(GROUPS, id: \.id) { area in
                        areaRow(area.id, "\(area.id) · \(area.label)")
                    }
                    areaRow("", "No activity area")

                    // Always ready, always in colour — his rule for a main button
                    // (2026-09-26); pressed too early, it says what is missing.
                    Button { make() } label: {
                        Text("Make the template")
                            .font(.system(.body, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity).frame(minHeight: 50)
                            .background(RoundedRectangle(cornerRadius: 12).fill(AppSection.templates.color))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("newlist-make")
                    // What a press was missing — gone as soon as the name changes, as
                    // under every other field (the spec pass, 5 Oct 2026).
                    .needsLine($needs, typed: name, id: "newlist-needs")
                    .padding(.top, 24)
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .onAppear { writing = true }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("newlist-detail")
        #if os(macOS)
        .frame(minWidth: 440, minHeight: 480)
        #endif
    }

    private func areaRow(_ id: String, _ label: String) -> some View {
        Button { group = id } label: {
            HStack {
                Text(label)
                    .font(.system(.callout, weight: group == id ? .semibold : .regular))
                    .foregroundStyle(group == id ? AppSection.templates.color : Theme.ink)
                Spacer()
            }
            .frame(minHeight: Metrics.tap)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
        .accessibilityIdentifier("newlist-area-\(id.isEmpty ? "none" : id)")
        .accessibilityAddTraits(group == id ? .isSelected : [])
    }

    private func make() {
        if jsTrim(name).isEmpty { needs = "Give the template a name."; return }
        if taken { needs = "Pick a name you do not have yet."; return }
        needs = ""
        made(newList(name: jsTrim(name), group: group))
        dismiss()
    }
}
