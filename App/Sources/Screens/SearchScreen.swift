import SwiftUI
import PackingCore
import PackingLibrary

/// One search that reaches everything: his things, his lists, his trips and his
/// to-dos, from whichever screen he is on.
///
/// Two places where the web app's version is bettered, both for the same reason —
/// it should not quietly mislead:
///  · it stops at thirty things and says nothing, so a search that looks complete
///    may not be. This one says how many more there are.
///  · choosing a thing there jumps to whichever LIST happens to hold it first,
///    which is an arbitrary place to land; a thing on no list lands on the Care
///    screen instead of on the thing. Here a thing opens the THING.
struct SearchScreen: View {
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @FocusState private var writing: Bool
    /// Where a chosen result opens. ONE sheet with a destination, not three sheets:
    /// SwiftUI does not reliably present a second sheet on a view while the first is
    /// still closing, so "open a thing, close it, tap a list" opened nothing on
    /// GitHub's slower runner — and would have on his phone too.
    @State private var opened: Opened?

    enum Opened: Identifiable {
        case thing(String), list(String), trip(String)
        var id: String {
            switch self {
            case .thing(let x): return "thing:\(x)"
            case .list(let x): return "list:\(x)"
            case .trip(let x): return "trip:\(x)"
            }
        }
    }

    /// How many things are listed before the rest are summed up in a line.
    private static let mostThings = 30

    var body: some View {
        let found = look()
        VStack(spacing: 0) {
            HStack {
                Text("Search").font(.system(.title3, weight: .bold)).foregroundStyle(Theme.ink)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(HeaderButtonStyle(tint: AppSection.home.color, filled: true)).focusEffectDisabled()
                    .font(.system(.body, weight: .semibold)).foregroundStyle(AppSection.home.color)
                    .keyboardShortcut(.cancelAction)            // Escape closes it, as Done does (Escape everywhere, 5 Oct 2026)
                    .accessibilityIdentifier("search-done")
            }
            .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 8)

            TextField("Things, templates, trips, to-dos…", text: $query)
                .textFieldStyle(.plain)
                .font(.system(.body)).foregroundStyle(Theme.ink)
                .focused($writing)
                .clearButton($query, id: "search-field")
                .padding(.horizontal, 12).frame(minHeight: Metrics.tap)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                .padding(.horizontal, 16)

            KeyboardAwayScroll {
                VStack(alignment: .leading, spacing: 0) {
                    if jsTrim(query).isEmpty {
                        note("Type to search across everything — your things, your templates, your trips and your to-dos.")
                    } else if found.isEmpty {
                        note("Nothing matches “\(jsTrim(query))”.")
                            .accessibilityIdentifier("search-none")
                    } else {
                        // On a trip under way: where the thing is, first (0.69).
                        WhereCard(query: query).environmentObject(model)
                        ForEach(found) { part in
                            heading(part.title, part.total)
                            ForEach(Array(part.rows.enumerated()), id: \.element.id) { n, row in
                                VStack(alignment: .leading, spacing: 0) {
                                    Button { chose(row) } label: { line(row) }
                                        .buttonStyle(.plain).focusEffectDisabled()
                                        .accessibilityIdentifier("search-\(part.id)-\(n)")
                                    // Outside the button, so the Mac keeps it a text of its own.
                                    if let note = row.note {
                                        NoteHitLine(hit: note, query: query, tint: AppSection.home.color)
                                            .padding(.top, -2).padding(.bottom, 5)
                                            .contentShape(Rectangle())
                                            .onTapGesture { chose(row) }
                                            .accessibilityIdentifier("search-\(part.id)-\(n)-note")
                                    }
                                }
                                .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
                            }
                            if part.total > part.rows.count {
                                Text("…and \(part.total - part.rows.count) more. Say more of the name.")
                                    .font(.system(.footnote)).foregroundStyle(Theme.muted)
                                    .padding(.vertical, 4)
                                    .accessibilityIdentifier("search-\(part.id)-more")
                            }
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .onAppear { writing = true }
        .sheet(item: $opened) { destination in
            switch destination {
            case .thing(let id): ThingEditor(itemId: id).environmentObject(model)
            case .list(let id): TemplateDetail(listId: id).environmentObject(model)
            case .trip(let id): TripScreen(tripId: id).environmentObject(model)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("search-detail")
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 560)
        #endif
    }

    // MARK: - what was found

    struct Row: Identifiable {
        let id: String
        let name: String
        let under: String
        let kind: Kind
        enum Kind { case thing, list, trip, todo }
        /// The line of a thing's notes the search found it by (0.69).
        var note: NoteHit? = nil
    }

    struct Part: Identifiable {
        let id: String
        let title: String
        let rows: [Row]
        /// How many there are altogether, which can be more than are listed.
        let total: Int
    }

    private func look() -> [Part] {
        let needle = normName(query)
        guard !needle.isEmpty else { return [] }
        var out: [Part] = []
        let library = model.library

        // His things. The web app searches the Swedish wording too but never shows
        // it, so a hit can look inexplicable; here it is said in the line under.
        // …and its notes (0.69): its own Notes and the notes its templates keep for it.
        let hits = library.noteHits(query)
        let things = library.items.filter {
            normName($0.name).contains(needle) || normName($0.swedish).contains(needle) || hits[$0.id] != nil
        }
        if !things.isEmpty {
            let rows = things.prefix(SearchScreen.mostThings).map { thing -> Row in
                var under = [String]()
                if !jsTrim(thing.storage).isEmpty { under.append(thing.storage) }
                if normName(thing.swedish).contains(needle), !jsTrim(thing.swedish).isEmpty {
                    under.append(thing.swedish)
                }
                let lists = library.memberships.filter { $0.itemId == thing.id }.count
                under.append(lists == 0 ? "on no template" : "on \(lists) template\(lists == 1 ? "" : "s")")
                // Found by its notes, not its name: the line that matched goes under it.
                let byName = normName(thing.name).contains(needle) || normName(thing.swedish).contains(needle)
                return Row(id: thing.id, name: thing.name, under: under.joined(separator: " · "), kind: .thing,
                           note: byName ? nil : hits[thing.id])
            }
            out.append(Part(id: "things", title: "Things", rows: Array(rows), total: things.count))
        }

        // His templates — the ones the Templates tab shows: his bags are a screen of
        // their own (Care → Bags), and the web app's retired "Loose items" bin is no
        // template of his (the spec pass, 5 Oct 2026).
        let lists = library.shownTemplates().filter { normName($0.name).contains(needle) }
        if !lists.isEmpty {
            out.append(Part(id: "lists", title: "Templates",
                            rows: lists.map { Row(id: $0.id, name: $0.name,
                                                  under: "\($0.items.count) thing\($0.items.count == 1 ? "" : "s")",
                                                  kind: .list) },
                            total: lists.count))
        }

        let trips = library.trips.filter {
            normName($0.name).contains(needle) || normName($0.destination).contains(needle)
        }
        if !trips.isEmpty {
            out.append(Part(id: "trips", title: "Trips",
                            rows: trips.map { trip in
                                let when = trip.startDate.isEmpty ? "" : countdownLabel(daysUntil(trip.startDate, Today.local))
                                let where_ = jsTrim(trip.destination)
                                return Row(id: trip.id, name: trip.name,
                                           under: [where_, when].filter { !$0.isEmpty }.joined(separator: " · "),
                                           kind: .trip)
                            },
                            total: trips.count))
        }

        let todos = library.sortedActions().filter {
            normName($0.text).contains(needle) || normName($0.itemName).contains(needle)
        }
        if !todos.isEmpty {
            out.append(Part(id: "todos", title: "To-dos",
                            rows: todos.map { Row(id: $0.id, name: $0.text,
                                                  under: $0.done ? "done" : "still to do", kind: .todo) },
                            total: todos.count))
        }
        return out
    }

    private func chose(_ row: Row) {
        switch row.kind {
        case .thing: opened = .thing(row.id)
        case .list: opened = .list(row.id)
        case .trip: opened = .trip(row.id)
        case .todo:
            // A to-do is not a thing to open; it lives on the To do tab, which the
            // frame opens. (Until 5 Oct 2026 it asked a screen that was never told
            // where to send him, so Search only closed.)
            dismiss()
            model.tabToOpen = .actions
        }
    }

    // MARK: - the parts of the page

    private func heading(_ title: String, _ count: Int) -> some View {
        HStack(spacing: 6) {
            Text(title.uppercased())
                .font(.system(.caption, weight: .semibold)).foregroundStyle(Theme.muted).kerning(0.6)
            Text("\(count)")
                .font(.system(.caption, weight: .semibold).monospacedDigit()).foregroundStyle(Theme.muted)
        }
        .padding(.top, 18).padding(.bottom, 4)
    }

    private func line(_ row: Row) -> some View {
        HStack(spacing: 10) {
            // The name and its details on ONE line (his word, 5 Oct 2026).
            Text(row.name)
                .font(.body).foregroundStyle(Theme.ink)
                .lineLimit(1).layoutPriority(1)
            Spacer(minLength: 6)
            if !row.under.isEmpty {
                Text(row.under)
                    .font(.system(.footnote)).foregroundStyle(Theme.muted)
                    .lineLimit(1).truncationMode(.middle)
            }
            SVGPath.path("M9 6l6 6-6 6")
                .stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                .frame(width: 20, height: 20).foregroundStyle(Theme.muted)
        }
        .frame(minHeight: Metrics.compact)
        .contentShape(Rectangle())
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.system(.subheadline)).foregroundStyle(Theme.muted)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 24)
    }
}

/// The line of a thing's notes a search found it by (0.69), under the thing: muted, with
/// the words searched for in the screen's colour; a template's own note says whose it is
/// ("Hiking: …"). One line — `noteHits` cuts a long one so the words are in it.
struct NoteHitLine: View {
    let hit: NoteHit
    let query: String
    let tint: Color

    var body: some View {
        Text(said)
            .font(.system(.footnote))
            .lineLimit(1).truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var said: AttributedString {
        var s = AttributedString((hit.template.map { "\($0): " } ?? "") + hit.line)
        s.foregroundColor = Theme.muted
        // Spaces as the search counts them (`normName`): "blue  pouch" finds "blue pouch".
        let words = normName(query)
        guard !words.isEmpty else { return s }
        var from = s.startIndex
        while from < s.endIndex, let r = s[from...].range(of: words, options: [.caseInsensitive, .diacriticInsensitive]) {
            s[r].foregroundColor = tint
            s[r].font = .system(.footnote, weight: .semibold)
            from = r.upperBound
        }
        return s
    }
}

/// The magnifier that opens it — the same button on every screen that has one.
struct SearchButton: View {
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            SVGPath.path("M11 4a7 7 0 1 0 0 14 7 7 0 0 0 0-14ZM20 20l-4-4")
                .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .frame(width: 24, height: 24)
                .foregroundStyle(Theme.muted)
                // A tap's height, as the buttons beside it (36 on the iPhone, 26 on the
                // Mac — it was 36 on both, the tallest thing in the Mac's headers).
                .frame(width: Metrics.tap + 4, height: Metrics.tap)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier("search-open")
        .accessibilityLabel("Search everything")
    }
}
