import SwiftUI
import PackingCore
import PackingLibrary

/// On site — the step after Pack (their field test, 3 Oct 2026,
/// mission 9.1): "During this phase, we could add stuff as: items bought there; items
/// discarded there (not more needed); maintenance or other actions." He chose that it
/// holds all four, each under its own heading:
///   Bought on site · Left on site · Maintenance notes · Pack to go home.
/// Calm and readable without glasses: four headings, short lines, colour as the
/// message — green for the trip, orange for what goes on to Care.
struct OnSiteScreen: View {
    let tripId: String
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    @State private var boughtName = ""
    /// Bought on site pressed with nothing typed: it says what is missing (his rule,
    /// 2026-09-26 — a main button is never grey).
    @State private var boughtTooSoon = false
    @State private var leaving = false
    @State private var choosingNote = false
    /// The line whose note is being written (its id), and what is written so far.
    @State private var noting: String?
    @State private var noteDraft = ""
    @State private var noteTooSoon = false
    @FocusState private var writingNote: Bool
    @State private var goingHome = false

    private var tint: Color { AppSection.events.color }
    private var care: Color { AppSection.care.color }

    var body: some View {
        let lib = model.library
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("On site").font(.system(size: 24, weight: .heavy)).foregroundStyle(tint)
                    Text(lib.onSiteSummary(tripId: tripId))
                        .font(.system(size: 15, weight: .bold).monospacedDigit()).foregroundStyle(Theme.muted)
                        .accessibilityIdentifier("onsite-summary")
                }
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(HeaderButtonStyle(tint: tint, filled: true)).focusEffectDisabled()
                    .font(.system(size: 17, weight: .bold))
                    .keyboardShortcut(.cancelAction)            // Escape closes it (the spec pass, 5 Oct 2026)
                    .accessibilityIdentifier("onsite-done")
            }
            .padding(16)
            KeyboardAwayScroll {
                VStack(alignment: .leading, spacing: 6) {
                    bought(lib.boughtOnSite(tripId: tripId))
                    left(lib.leftOnSite(tripId: tripId), lib.homeLines(tripId: tripId).filter { !Library.isUsedUp($0) })
                    notes(lib.onSiteNotes(tripId: tripId), lib.homeLines(tripId: tripId))
                    wayHome(lib.homeProgress(tripId: tripId), lib.homeUsedUp(tripId: tripId))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .sheet(isPresented: $goingHome) { WayHomeScreen(tripId: tripId).environmentObject(model) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onsite-screen")
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 640)
        #endif
    }

    // MARK: Bought on site

    /// What was bought on the trip, and the field to add one more — the trip's own
    /// Bought on site, here too: on the list in one go, ticked, marked.
    private func bought(_ lines: [Item]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionTitle(title: "Bought on site", tint: tint, id: "onsite-bought-title")
            if lines.isEmpty {
                quiet("Nothing bought yet.", id: "onsite-bought-none")
            }
            ForEach(Array(lines.enumerated()), id: \.element.id) { n, line in
                row { name(line.name, id: "onsite-bought-\(n)") }
            }
            HStack(spacing: 8) {
                TextField("What did you buy?", text: $boughtName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 17, weight: .medium)).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 12).frame(minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                    .onSubmit { addBought() }
                    .onChange(of: boughtName) { _, _ in boughtTooSoon = false }
                    .accessibilityIdentifier("onsite-bought-name")
                Button { addBought() } label: {
                    Text("Bought on site").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                        .lineLimit(1).fixedSize()
                        .padding(.horizontal, 14).frame(minHeight: 44)
                        .background(RoundedRectangle(cornerRadius: 10).fill(tint))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("onsite-bought-add")
            }
            .padding(.top, 6)
            if boughtTooSoon { needs("Type what you bought first.", id: "onsite-bought-needs") }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onsite-bought")
    }

    private func addBought() {
        let name = boughtName
        guard !jsTrim(name).isEmpty else { boughtTooSoon = true; return }
        let id = tripId
        model.change { _ = $0.addBoughtOnSite(tripId: id, name: name) }
        boughtName = ""
    }

    // MARK: Left on site

    /// "Items discarded there (not more needed)": used up or left behind — it does not
    /// come home. The same mark as Used up on the way home, so both always agree.
    private func left(_ lines: [Item], _ candidates: [Item]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionTitle(title: "Left on site", tint: Theme.ink, id: "onsite-left-title")
            if lines.isEmpty {
                quiet("Nothing left on site.", id: "onsite-left-none")
            }
            ForEach(Array(lines.enumerated()), id: \.element.id) { n, line in
                row {
                    name(line.name, id: "onsite-left-\(n)")
                    Spacer(minLength: 8)
                    small("Undo", id: "onsite-left-\(n)-undo") {
                        let id = tripId, entry = line.id
                        model.change { _ = $0.setUsedUp(false, tripId: id, entryId: entry) }
                    }
                }
            }
            if leaving {
                LinePicker(title: "What stays on site?", prefix: "onsite-leave", lines: candidates,
                           emptyWords: "Nothing to leave: what went is ticked on the way out.", tint: tint,
                           pick: { line in
                               let id = tripId, entry = line.id
                               model.change { _ = $0.setUsedUp(true, tripId: id, entryId: entry) }
                               leaving = false
                           }, close: { leaving = false })
                    .padding(.top, 6)
            } else {
                wide("Leave something here", id: "onsite-leave", tint: tint) {
                    leaving = true; choosingNote = false
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onsite-left")
    }

    // MARK: Maintenance notes

    /// A note per thing — "zip broken", "wash before next trip". Kept on the trip's
    /// line, and it also lands on the thing itself, dated, for Care (his choice).
    private func notes(_ lines: [Item], _ candidates: [Item]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionTitle(title: "Maintenance notes", tint: care, id: "onsite-notes-title")
            if lines.isEmpty && noting == nil {
                quiet("No notes yet. A note goes onto the thing too, for Care.", id: "onsite-notes-none")
            }
            ForEach(Array(lines.enumerated()), id: \.element.id) { n, line in
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(line.name).font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.ink)
                                .lineLimit(2)
                                .accessibilityIdentifier("onsite-note-\(n)")
                            if noting != line.id {
                                Text(Library.homeNote(line))
                                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(care)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .accessibilityIdentifier("onsite-note-\(n)-text")
                            }
                        }
                        Spacer(minLength: 8)
                        if noting != line.id {
                            small("Change", id: "onsite-note-\(n)-change") { startNote(line) }
                        }
                    }
                    .padding(.vertical, 9)
                    if noting == line.id { noteEditor(line) }
                }
                .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
            }
            // A new note for a line that has none yet: the editor comes under the list.
            if let id = noting, !lines.contains(where: { $0.id == id }),
               let line = candidates.first(where: { $0.id == id }) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(line.name).font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.ink)
                        .accessibilityIdentifier("onsite-note-for")
                    noteEditor(line)
                }
                .padding(.top, 8)
            }
            if choosingNote {
                LinePicker(title: "A note for which thing?", prefix: "onsite-note", lines: candidates,
                           emptyWords: "Nothing to note yet: what went is ticked on the way out.", tint: care,
                           pick: { line in choosingNote = false; startNote(line) },
                           close: { choosingNote = false })
                    .padding(.top, 6)
            } else if noting == nil {
                wide("Add a note", id: "onsite-note-add", tint: care) {
                    choosingNote = true; leaving = false
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onsite-notes")
    }

    private func startNote(_ line: Item) {
        noteDraft = Library.homeNote(line)
        noteTooSoon = false
        noting = line.id
    }

    private func noteEditor(_ line: Item) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                TextField("e.g. Zip broken", text: $noteDraft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 17, weight: .medium)).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 12).frame(minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                    .focused($writingNote)
                    .onSubmit { saveNote(line) }
                    .onAppear { writingNote = true }
                    .onChange(of: noteDraft) { _, _ in noteTooSoon = false }
                    .accessibilityIdentifier("onsite-note-field")
                Button { saveNote(line) } label: {
                    Text("Save").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 16).frame(minHeight: 44)
                        .background(RoundedRectangle(cornerRadius: 10).fill(care))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("onsite-note-save")
            }
            if noteTooSoon { needs("Type the note first.", id: "onsite-note-needs") }
            HStack(spacing: 12) {
                Text(model.library.thingBehind(line) == nil ? "Kept with this trip."
                     : "Also goes onto the thing, for Care.")
                    .font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                small("Cancel", id: "onsite-note-cancel") { writingNote = false; noting = nil }
            }
        }
        .padding(.bottom, 10)
    }

    private func saveNote(_ line: Item) {
        let text = noteDraft, id = tripId, entry = line.id
        // A new note with nothing typed says what is missing; an existing one emptied
        // is taken away, as on the way home.
        if jsTrim(text).isEmpty && Library.homeNote(line).isEmpty { noteTooSoon = true; return }
        model.change { _ = $0.noteOnSite(text, tripId: id, entryId: entry, today: Today.local) }
        writingNote = false
        noting = nil
    }

    // MARK: Pack to go home

    private func wayHome(_ p: (done: Int, total: Int), _ usedUp: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(title: "Pack to go home", tint: tint, id: "onsite-wayhome-title")
            Text(p.total == 0 ? "Nothing to bring home yet." : "\(p.done) of \(p.total) packed")
                .font(.system(size: 17, weight: .bold).monospacedDigit())
                .foregroundStyle(p.total > 0 && p.done == p.total ? tint : Theme.ink)
                .accessibilityIdentifier("onsite-wayhome-progress")
            Button { goingHome = true } label: {
                HStack(spacing: 8) {
                    Text("Pack to go home").font(.system(size: 17, weight: .bold))
                    SVGPath.path("M9 6l6 6-6 6").stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        .frame(width: 20, height: 20)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(RoundedRectangle(cornerRadius: 12).fill(tint))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain).focusEffectDisabled()
            .accessibilityIdentifier("onsite-wayhome-open")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onsite-wayhome")
    }

    // MARK: Pieces

    private func row<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 8) { content() }
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
    }

    private func name(_ text: String, id: String) -> some View {
        Text(text).font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.ink)
            .lineLimit(2)
            .accessibilityIdentifier(id)
    }

    private func quiet(_ text: String, id: String) -> some View {
        Text(text).font(.system(size: 16, weight: .medium)).foregroundStyle(Theme.muted)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 4)
            .accessibilityIdentifier(id)
    }

    private func needs(_ text: String, id: String) -> some View {
        Text(text).font(.system(size: 16, weight: .bold)).foregroundStyle(AppSection.actions.color)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(id)
    }

    /// A small, quiet word-button at the side of a line, as on the way home.
    private func small(_ title: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.muted)
                .padding(.horizontal, 8).frame(minHeight: 40).contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier(id)
    }

    /// A section's own button, across the width, framed in its colour — never grey.
    private func wide(_ title: String, id: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 16, weight: .bold)).foregroundStyle(tint)
                .frame(maxWidth: .infinity, minHeight: 48)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(tint, lineWidth: 1.4))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .padding(.top, 8)
        .accessibilityIdentifier(id)
    }
}

/// A short, searchable list of the trip's lines to pick one from — Leave something
/// here and Add a note. A real trip has hundreds of lines, so it shows the first few
/// that match and says how many more a word would find.
private struct LinePicker: View {
    let title: String
    let prefix: String
    let lines: [Item]
    let emptyWords: String
    let tint: Color
    let pick: (Item) -> Void
    let close: () -> Void
    @State private var query = ""
    private static let most = 8

    var body: some View {
        let needle = normName(query)
        let matches = needle.isEmpty ? lines : lines.filter { normName($0.name).contains(needle) }
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.system(size: 17, weight: .heavy)).foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
                Button("Close") { close() }
                    .buttonStyle(HeaderButtonStyle(tint: Theme.muted, filled: false)).focusEffectDisabled()
                    .accessibilityIdentifier("\(prefix)-close")
            }
            if !lines.isEmpty {
                TextField("Search what went", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 17, weight: .medium)).foregroundStyle(Theme.ink)
                    .clearButton($query, id: "\(prefix)-search")
                    .padding(.horizontal, 12).frame(minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.bg))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
            }
            ForEach(Array(matches.prefix(LinePicker.most).enumerated()), id: \.element.id) { n, line in
                Button { pick(line) } label: {
                    HStack(spacing: 8) {
                        Text(line.name).font(.system(size: 17, weight: .medium)).foregroundStyle(Theme.ink).lineLimit(2)
                        Spacer(minLength: 8)
                        Text(line.container.isEmpty || line.container == "Other" ? "" : line.container)
                            .font(.system(size: 14)).foregroundStyle(Theme.muted).lineLimit(1)
                    }
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
                .accessibilityIdentifier("\(prefix)-pick-\(n)")
            }
            if matches.isEmpty {
                Text(lines.isEmpty ? emptyWords : "Nothing that went is called \u{201C}\(jsTrim(query))\u{201D}.")
                    .font(.system(size: 16, weight: .medium)).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("\(prefix)-none")
            } else if matches.count > LinePicker.most {
                Text("\(matches.count - LinePicker.most) more \u{2014} type a word to find them")
                    .font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.muted)
                    .accessibilityIdentifier("\(prefix)-more")
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(tint.opacity(0.6), lineWidth: 1.2))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("\(prefix)-picker")
    }
}
