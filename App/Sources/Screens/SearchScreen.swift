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
    /// Send him to a tab (a to-do lives on Actions, not in a sheet of its own).
    var go: (AppSection) -> Void = { _ in }

    @State private var query = ""
    @FocusState private var writing: Bool
    @State private var thing: String?
    @State private var list: String?
    @State private var trip: String?

    /// How many things are listed before the rest are summed up in a line.
    private static let mostThings = 30

    var body: some View {
        let found = look()
        VStack(spacing: 0) {
            HStack {
                Text("Search").font(.system(size: 20, weight: .heavy)).foregroundStyle(Theme.ink)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .font(.system(size: 17, weight: .bold)).foregroundStyle(AppSection.home.color)
                    .accessibilityIdentifier("search-done")
            }
            .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 8)

            TextField("Things, lists, trips, to-dos…", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 17, weight: .medium)).foregroundStyle(Theme.ink)
                .padding(.horizontal, 12).frame(minHeight: 44)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                .focused($writing)
                .padding(.horizontal, 16)
                .accessibilityIdentifier("search-field")

            KeyboardAwayScroll {
                VStack(alignment: .leading, spacing: 0) {
                    if jsTrim(query).isEmpty {
                        note("Type to search across everything — your things, your lists, your trips and your to-dos.")
                    } else if found.isEmpty {
                        note("Nothing matches “\(jsTrim(query))”.")
                            .accessibilityIdentifier("search-none")
                    } else {
                        ForEach(found) { part in
                            heading(part.title, part.total)
                            ForEach(Array(part.rows.enumerated()), id: \.element.id) { n, row in
                                Button { chose(row) } label: { line(row) }
                                    .buttonStyle(.plain).focusEffectDisabled()
                                    .accessibilityIdentifier("search-\(part.id)-\(n)")
                            }
                            if part.total > part.rows.count {
                                Text("…and \(part.total - part.rows.count) more. Say more of the name.")
                                    .font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.muted)
                                    .padding(.vertical, 8)
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
        .sheet(item: Binding(get: { thing.map(Holder.init) }, set: { thing = $0?.id })) { held in
            ThingEditor(itemId: held.id).environmentObject(model)
        }
        .sheet(item: Binding(get: { list.map(Holder.init) }, set: { list = $0?.id })) { held in
            TemplateDetail(listId: held.id).environmentObject(model)
        }
        .sheet(item: Binding(get: { trip.map(Holder.init) }, set: { trip = $0?.id })) { held in
            TripScreen(tripId: held.id).environmentObject(model)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("search-detail")
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 560)
        #endif
    }

    private struct Holder: Identifiable { let id: String }

    // MARK: - what was found

    struct Row: Identifiable {
        let id: String
        let name: String
        let under: String
        let kind: Kind
        enum Kind { case thing, list, trip, todo }
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
        let things = library.items.filter {
            normName($0.name).contains(needle) || normName($0.swedish).contains(needle)
        }
        if !things.isEmpty {
            let rows = things.prefix(SearchScreen.mostThings).map { thing -> Row in
                var under = [String]()
                if !jsTrim(thing.storage).isEmpty { under.append(thing.storage) }
                if normName(thing.swedish).contains(needle), !jsTrim(thing.swedish).isEmpty {
                    under.append(thing.swedish)
                }
                let lists = library.memberships.filter { $0.itemId == thing.id }.count
                under.append(lists == 0 ? "on no list" : "on \(lists) list\(lists == 1 ? "" : "s")")
                return Row(id: thing.id, name: thing.name, under: under.joined(separator: " · "), kind: .thing)
            }
            out.append(Part(id: "things", title: "Things", rows: Array(rows), total: things.count))
        }

        // His lists. Containers are a screen of their own, as in the web app.
        let lists = library.resolvedTemplates().filter {
            $0.role != CONTAINER_ROLE && normName($0.name).contains(needle)
        }
        if !lists.isEmpty {
            out.append(Part(id: "lists", title: "Lists",
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
        case .thing: thing = row.id
        case .list: list = row.id
        case .trip: trip = row.id
        case .todo:
            // A to-do is not a thing to open; it lives on Actions.
            dismiss()
            go(.actions)
        }
    }

    // MARK: - the parts of the page

    private func heading(_ title: String, _ count: Int) -> some View {
        HStack(spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .heavy)).foregroundStyle(Theme.muted).kerning(0.6)
            Text("\(count)")
                .font(.system(size: 12, weight: .heavy).monospacedDigit()).foregroundStyle(Theme.muted)
        }
        .padding(.top, 18).padding(.bottom, 4)
    }

    private func line(_ row: Row) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(row.name)
                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.ink)
                    .lineLimit(1)
                if !row.under.isEmpty {
                    Text(row.under)
                        .font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            SVGPath.path("M9 6l6 6-6 6")
                .stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                .frame(width: 20, height: 20).foregroundStyle(Theme.muted)
        }
        .frame(minHeight: 48)
        .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
        .contentShape(Rectangle())
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.muted)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 24)
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
                .frame(width: 40, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier("search-open")
        .accessibilityLabel("Search everything")
    }
}
