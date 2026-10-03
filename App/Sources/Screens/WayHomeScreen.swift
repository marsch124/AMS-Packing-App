import SwiftUI
import PackingCore
import PackingLibrary

/// Pack to go home — his pre-trip idea 13 (2 Oct 2026). What went, and what was
/// bought there, bag by bag, with ticks of its own; Used up takes a thing off. The
/// photos of the packed bags sit at the top, to repack from.
///
/// Their field test (Martin and Anna, 3 Oct 2026) added: a search, "1 used up" in the
/// heading, Tick everything, Undo for Used up, a note per line for maintenance ("zip
/// broken"), and Open — change the thing and "come straight back here when done".
struct WayHomeScreen: View {
    let tripId: String
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    /// What is open on top of the way home. ONE sheet with a destination, as on the
    /// Search screen: SwiftUI does not reliably present a second sheet on a view while
    /// the first is still closing. Closing it leaves everything here as it was — the
    /// search included — because this screen stays alive underneath.
    @State private var opened: Opened?
    @State private var query = ""
    /// The line whose note is being written (its id), and what is written so far.
    @State private var noting: String?
    @State private var noteDraft = ""
    @FocusState private var writingNote: Bool

    private enum Opened: Identifiable {
        case photo(CGImage), thing(String)
        var id: String {
            switch self {
            case .photo(let image): return "photo:\(ObjectIdentifier(image).hashValue)"
            case .thing(let id): return "thing:\(id)"
            }
        }
    }

    var body: some View {
        let lines = model.library.homeLines(tripId: tripId)
        let p = model.library.homeProgress(tripId: tripId)
        let usedUp = model.library.homeUsedUp(tripId: tripId)
        let needle = normName(query)
        let shown = needle.isEmpty ? lines : lines.filter { normName($0.name).contains(needle) }
        // A line keeps its number while the search narrows the list, so it is the same
        // line to a test (and to the eye) whatever is typed.
        let number = Dictionary(lines.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { a, _ in a })
        let bags = Self.bags(shown)
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Way home").font(.system(size: 24, weight: .heavy)).foregroundStyle(AppSection.events.color)
                    // "I think there should be '1 used up' in the heading counting" (Anna, 3 Oct 2026).
                    Text(usedUp > 0 ? "\(p.done)/\(p.total) · \(usedUp) used up" : "\(p.done)/\(p.total)")
                        .font(.system(size: 15, weight: .bold).monospacedDigit()).foregroundStyle(Theme.muted)
                        .accessibilityIdentifier("wayhome-progress")
                }
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(HeaderButtonStyle(tint: AppSection.events.color, filled: true)).focusEffectDisabled()
                    .font(.system(size: 17, weight: .bold))
                    .accessibilityIdentifier("wayhome-done")
            }
            .padding(16)
            if !lines.isEmpty {
                searchField.padding(.horizontal, 16).padding(.bottom, 6)
            }
            KeyboardAwayScroll {
                VStack(alignment: .leading, spacing: 4) {
                    // The photos are for repacking the whole of a bag; a search is after one thing.
                    if needle.isEmpty { photos(Self.bags(lines)) }
                    if lines.isEmpty {
                        Text("Nothing to bring home yet: tick what you pack on the way out, and add what you buy there with Bought there.")
                            .font(.system(size: 16, weight: .medium)).foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("wayhome-empty")
                    } else if shown.isEmpty {
                        Text("Nothing on the way home is called \u{201C}\(jsTrim(query))\u{201D}.")
                            .font(.system(size: 16, weight: .medium)).foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 12)
                            .accessibilityIdentifier("wayhome-search-none")
                    }
                    ForEach(bags, id: \.self) { bag in
                        Text(bag.isEmpty || bag == "Other" ? "Not in a bag" : bag)
                            .font(.system(size: 15, weight: .heavy)).foregroundStyle(AppSection.events.color)
                            .padding(.top, 12)
                        ForEach(shown.filter { $0.container == bag }, id: \.id) { line in
                            row(line, number[line.id] ?? 0)
                        }
                    }
                    // It ticks the WHOLE way home, so it is not offered on a narrowed list,
                    // where it would seem to tick only what is shown.
                    if needle.isEmpty { tickAll(p) }
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .sheet(item: $opened) { what in
            switch what {
            case .photo(let image): BigPhoto(image: image)
            case .thing(let id): ThingEditor(itemId: id).environmentObject(model)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("wayhome-screen")
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 640)
        #endif
    }

    /// The bags in the list's order, each once.
    private static func bags(_ lines: [Item]) -> [String] {
        lines.reduce(into: [String]()) { if !$0.contains($1.container) { $0.append($1.container) } }
    }

    /// "I would like a search function in the 'Pack to go home'" (their field test,
    /// 3 Oct 2026). It narrows the list by name as he types; the cross empties it.
    private var searchField: some View {
        TextField("Search the way home", text: $query)
            .textFieldStyle(.plain)
            .font(.system(size: 17, weight: .medium)).foregroundStyle(Theme.ink)
            .padding(.leading, 12).padding(.trailing, 44).frame(minHeight: 44)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
            .accessibilityIdentifier("wayhome-search")
            .overlay(alignment: .trailing) {
                if !query.isEmpty {
                    Button { query = "" } label: {
                        SVGPath.path("M6 6L18 18M18 6L6 18")
                            .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            .frame(width: 24, height: 24).foregroundStyle(Theme.muted)
                            .frame(width: 44, height: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("wayhome-search-clear")
                    .accessibilityLabel("Clear the search")
                }
            }
    }

    /// The packed bags' photos, to repack from.
    @ViewBuilder private func photos(_ bags: [String]) -> some View {
        let shots = bags.compactMap { bag in
            model.library.bagPhoto(tripId: tripId, bag: bag).flatMap { JPEG.image(dataURL: $0.data) }.map { (bag, $0) }
        }
        if !shots.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(shots.enumerated()), id: \.offset) { n, shot in
                        Button { opened = .photo(shot.1) } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Image(decorative: shot.1, scale: 1).resizable().scaledToFill()
                                    .frame(width: 120, height: 90).clipShape(RoundedRectangle(cornerRadius: 10))
                                Text(shot.0).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.muted).lineLimit(1)
                            }
                            .frame(width: 120)
                        }
                        .buttonStyle(.plain).focusEffectDisabled()
                        .accessibilityIdentifier("wayhome-photo-\(n)")
                    }
                }
            }
            .padding(.bottom, 4)
        }
    }

    private func row(_ line: Item, _ n: Int) -> some View {
        let used = Library.isUsedUp(line)
        let packed = Library.isPackedHome(line)
        let note = Library.homeNote(line)
        let thing = model.library.thingBehind(line)
        let tint = AppSection.events.color
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Button {
                    guard !used else { return }
                    model.change { _ = $0.setPackedHome(!packed, tripId: tripId, entryId: line.id) }
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().stroke(used ? Theme.line : tint, lineWidth: 2).frame(width: 26, height: 26)
                            if packed {
                                Circle().fill(tint).frame(width: 26, height: 26)
                                Tick().stroke(Color.white, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                                    .frame(width: 26, height: 26)
                            }
                        }
                        .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(line.name)
                                .font(.system(size: 17, weight: packed ? .regular : .medium))
                                .foregroundStyle(used || packed ? Theme.muted : Theme.ink)
                                .strikethrough(used, pattern: .solid, color: Theme.muted)
                                .lineLimit(2)
                            if used {
                                Text("Used up").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.muted)
                            } else if Library.isBoughtThere(line) {
                                Text("Bought there").font(.system(size: 13, weight: .bold)).foregroundStyle(tint)
                            }
                        }
                        Spacer(minLength: 4)
                    }
                    .padding(.vertical, 9).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("wayhome-line-\(n)")
                .accessibilityAddTraits(packed ? .isSelected : [])
                // Small, quiet words at the side, in the same places on every line.
                small("Note", id: "wayhome-line-\(n)-note") {
                    if noting == line.id { noting = nil; return }
                    noteDraft = note
                    noting = line.id
                }
                if let thing {
                    small("Open", id: "wayhome-line-\(n)-open") { opened = .thing(thing) }
                } else {
                    // Something bought there has no thing to open; the space is kept so
                    // the words stay lined up down the list.
                    smallWords("Open").hidden()
                }
                // "The user could change his or her mind… I think it should be called
                // something else, such as Undo" (their field test, 3 Oct 2026).
                small(used ? "Undo" : "Used up", id: "wayhome-line-\(n)-usedup", keepsRoomFor: "Used up") {
                    model.change { _ = $0.setUsedUp(!used, tripId: tripId, entryId: line.id) }
                }
            }
            // The note sits under the name, OUTSIDE the line's button: a button folds
            // its words into itself on the Mac, and the note is read on its own.
            if !note.isEmpty && noting != line.id {
                Text(note)
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(AppSection.care.color)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 38).padding(.top, -6).padding(.bottom, 9)
                    .accessibilityIdentifier("wayhome-line-\(n)-notetext")
            }
            if noting == line.id { noteEditor(line) }
        }
        .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
    }

    /// "A button for each item to write maintenance in the comment" (their field test,
    /// 3 Oct 2026): the note stays on this trip's line — the thing itself is untouched.
    private func noteEditor(_ line: Item) -> some View {
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
                .accessibilityIdentifier("wayhome-note-field")
            Button { saveNote(line) } label: {
                Text("Save").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                    .padding(.horizontal, 16).frame(minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: 10).fill(AppSection.events.color))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain).focusEffectDisabled()
            .accessibilityIdentifier("wayhome-note-save")
        }
        .padding(.leading, 38).padding(.bottom, 10)
    }

    private func saveNote(_ line: Item) {
        let text = noteDraft, id = line.id
        model.change { _ = $0.setHomeNote(text, tripId: tripId, entryId: id) }
        writingNote = false
        noting = nil
    }

    /// "While packing, we need a button to check off all items" (their field test,
    /// 3 Oct 2026). Once everything is ticked the same place clears the ticks again.
    @ViewBuilder private func tickAll(_ p: (done: Int, total: Int)) -> some View {
        if p.total > 0 {
            let all = p.done == p.total
            Button {
                let id = tripId
                model.change { _ = $0.setAllPackedHome(!all, tripId: id) }
            } label: {
                Group {
                    if all {
                        Text("Clear the ticks")
                            .font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.ink)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1.4))
                    } else {
                        HStack(spacing: 6) {
                            Tick().stroke(style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                                .frame(width: 22, height: 22)
                            Text("Tick everything").font(.system(size: 16, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(RoundedRectangle(cornerRadius: 12).fill(AppSection.events.color))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain).focusEffectDisabled()
            .padding(.top, 18)
            .accessibilityIdentifier("wayhome-tickall")
        }
    }

    private func smallWords(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.muted)
            .padding(.horizontal, 7).frame(minHeight: 40)
    }

    /// A small, quiet word-button at the side of a line. `keepsRoomFor`: the widest
    /// thing it ever says, so "Undo" takes the room of "Used up" and nothing shifts.
    private func small(_ title: String, id: String, keepsRoomFor widest: String? = nil,
                       action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                if let widest { smallWords(widest).hidden() }
                smallWords(title)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier(id)
    }
}
