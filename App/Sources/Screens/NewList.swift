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
    /// The main button's words — and a line under it saying when the template is made: on a
    /// thing's page (0.90) it is made when the thing is saved.
    var makeWords = "Make the template"
    var madeWhen: String? = nil
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
                    .keyboardShortcut(.cancelAction)            // Escape = Cancel, never Save (Escape everywhere, 5 Oct 2026)
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
                        Text(makeWords)
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
                    if let madeWhen {
                        Text(madeWhen)
                            .font(.system(.footnote)).foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 8)
                            .accessibilityIdentifier("newlist-made-when")
                    }
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

/// "+ New template…" at the foot of a thing's "On these templates" (0.90 — his words, 19 Oct
/// 2026: "Add New Template from within Item view"): A new template, as + New on the Templates
/// tab asks for it — its name and its activity area — and the thing goes on it. Like every
/// other new entry on a thing's page (a place, a section) it waits for the thing's Save: the
/// page shows it as a lit template pill, Save makes it and puts the thing on it, Cancel leaves
/// no template behind. Owns its sheet, so the page keeps the one it has.
struct NewTemplateDoor: View {
    /// His templates and the ones made on the page so far, so a name he has is refused.
    let library: Library
    let made: (PackList) -> Void
    @State private var open = false

    var body: some View {
        let tint = AppSection.templates.color
        Button { open = true } label: {
            Text("+ New template\u{2026}")
                .font(.system(.subheadline, weight: .semibold)).foregroundStyle(tint)
                .padding(.horizontal, 12).frame(minHeight: Metrics.chip)
                .background(Capsule().fill(tint.opacity(0.10)))
                .overlay(Capsule().stroke(tint, lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier("thing-lists-new")
        .sheet(isPresented: $open) {
            NewList(made: made, library: library, makeWords: "Add the template",
                    madeWhen: "It is made, with this thing on it, when you save the thing.")
        }
    }
}
