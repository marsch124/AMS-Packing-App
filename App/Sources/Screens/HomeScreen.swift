import SwiftUI
import PackingCore
import PackingLibrary

/// Home: build a trip. Name it, add the dates, pick what it is — press Create.
struct HomeScreen: View {
    /// His own words for the three food answers. The model keeps the web app's
    /// longer labels (the parity check compares them); the chips say what he wrote.
    static func shortFood(_ id: String, _ fallback: String) -> String {
        switch id {
        case "self": return "Self-sufficient"
        case "eatout": return "Eating out"
        case "mixed": return "Mix of both"
        default: return fallback
        }
    }

    @EnvironmentObject var model: LibraryModel
    @State private var name = ""
    @State private var hasDates = false
    @State private var start = Date()
    @State private var end = Date().addingTimeInterval(2 * 86400)
    @State private var transport = "Car"
    @State private var season = "Summer"
    @State private var catering = "mixed"
    @State private var activities: Set<String> = []
    @State private var contexts: Set<String> = []
    @State private var quick = false
    @State private var opened: String?
    @State private var grab: GrabDefinition?
    @State private var searching = false
    @State private var shelf = false

    var body: some View {
        let choices = model.library.activityChoices()
        let flat = choices.flatMap(\.lists)
        let anyWorkout = flat.contains { $0.group == "WET" && activities.contains($0.id) }
        KeyboardAwayScroll {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Grab and go").font(.system(size: 15, weight: .heavy)).foregroundStyle(Theme.muted)
                    Spacer()
                    SearchButton { searching = true }
                    // "Your lists" is the name of the TEMPLATES screen; this door
                    // opens the grab lists. His note on the Mac: "Your Grab Lists".
                    Button("Grab Lists") { shelf = true }
                        .buttonStyle(.plain).focusEffectDisabled()
                        .font(.system(size: 14, weight: .bold)).foregroundStyle(AppSection.home.color)
                        .accessibilityIdentifier("grab-shelf")
                }
                .padding(.top, 14)
                // Home holds six — HIS six, in his order (GrabShelf.swift).
                GrabButtons(lists: model.library.homeGrabLists()) { grab = $0 }

                Text("Create new trip").font(.system(size: 15, weight: .heavy)).foregroundStyle(Theme.muted).padding(.top, 8)
                VStack(alignment: .leading, spacing: 14) {
                    TextField("Name your trip", text: $name)
                        .textFieldStyle(.plain)
                        .font(.system(size: 20, weight: .semibold)).foregroundStyle(Theme.ink)
                        .padding(.horizontal, 12).frame(minHeight: 48)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.bg))
                        .accessibilityIdentifier("trip-name")

                    // Two answers about the SHAPE of the trip, on one line: his ask.
                    HStack(spacing: 12) {
                        Toggle(isOn: $hasDates) {
                            Text("Dates").font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.ink)
                        }
                        .fixedSize()
                        .accessibilityIdentifier("trip-dates")
                        Spacer(minLength: 8)
                        Toggle(isOn: $quick) {
                            Text("Quick").font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.ink)
                        }
                        .fixedSize()
                        .accessibilityIdentifier("trip-quick")
                    }
                    // The explanation only when it is on, so the line stays short.
                    if quick {
                        Text("Only the lists you tick — no common base, no transport kit.")
                            .font(.system(size: 14)).foregroundStyle(Theme.muted)
                            .accessibilityIdentifier("trip-quick-note")
                    }
                    if hasDates {
                        // Booking.com's way, his example (2026-09-26): one field, a month grid,
                        // first day then last day.
                        DateRangePicker(start: $start, end: $end)
                    }

                    ForEach(choices, id: \.group.id) { choice in
                        // Numbered across ALL groups, so "trip-activity-0" names one pill.
                        Pills(title: groupHeading(choice.group.id, choice.group.label),
                              options: choice.lists.map { ($0.id, $0.name) },
                              selected: activities, id: "trip-activity", tint: AppSection.templates.color,
                              startIndex: flat.firstIndex { $0.id == choice.lists[0].id } ?? 0) { id in
                            if activities.contains(id) { activities.remove(id) } else { activities.insert(id) }
                        }
                    }
                    if anyWorkout {
                        Pills(title: "Context", options: CONTEXTS.map { ($0, $0) }, selected: contexts, id: "trip-context") { id in
                            if contexts.contains(id) { contexts.remove(id) } else { contexts.insert(id) }
                        }
                    }
                    Pills(title: "Transport", options: TRANSPORTS.map { ($0, $0) }, selected: [transport], id: "trip-transport") { transport = $0 }
                    Pills(title: "Season", options: SEASONS.map { ($0, $0) }, selected: [season], id: "trip-season") { season = $0 }
                    Pills(title: "Food", options: CATERING.map { ($0.id, HomeScreen.shortFood($0.id, $0.label)) },
                          selected: [catering], id: "trip-catering") { catering = $0 }

                    Button { create(flat) } label: {
                        Text("Create Event")
                            .font(.system(size: 18, weight: .bold))
                            // White on the grey of a button that cannot be pressed is
                            // unreadable in daylight — his words: "cant read Create Event".
                            .foregroundStyle(canCreate ? Color.white : Theme.muted)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(RoundedRectangle(cornerRadius: 12).fill(canCreate ? AppSection.home.color : Theme.line))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .disabled(!canCreate)
                    .accessibilityIdentifier("trip-create")
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line, lineWidth: 1))

                // His marks on the Mac: the heading struck out and written down the
                // SIDE instead, and Trips and Templates swapped over.
                HStack(spacing: 10) {
                    Text("This Device")
                        .font(.system(size: 12, weight: .heavy)).foregroundStyle(Theme.muted)
                        .kerning(0.5)
                        .fixedSize()
                        .rotationEffect(.degrees(-90))
                        .frame(width: 16)
                        .accessibilityIdentifier("device-heading")
                    CountTile(number: model.library.trips.count, label: "Trips", id: "count-trips", color: AppSection.events.color)
                    CountTile(number: model.library.items.count, label: "Things", id: "count-things", color: AppSection.care.color)
                    CountTile(number: model.library.templates.count, label: "Templates", id: "count-templates", color: AppSection.templates.color)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 16).padding(.bottom, 24)
        }
        .sheet(isPresented: $searching) { SearchScreen().environmentObject(model) }
        .sheet(item: Binding(get: { opened.map { Opened(id: $0) } }, set: { opened = $0?.id })) { o in
            TripScreen(tripId: o.id).environmentObject(model)
        }
        .sheet(isPresented: $shelf) { GrabShelfScreen().environmentObject(model) }
        .sheet(item: Binding(get: { grab.map { GrabOpened(list: $0) } }, set: { grab = $0?.list })) { g in
            GrabScreen(listId: g.list.id).environmentObject(model)
        }
    }

    private struct GrabOpened: Identifiable { let list: GrabDefinition; var id: String { list.id } }

    private var canCreate: Bool { !jsTrim(name).isEmpty && !activities.isEmpty }

    private func create(_ flat: [PackList]) {
        guard canCreate else { return }
        var draft = newEvent(name: jsTrim(name), mode: quick ? "quick" : "trip")
        draft.transport = transport
        draft.season = season
        draft.catering = catering
        draft.activities = flat.map(\.id).filter { activities.contains($0) }   // in the order offered
        draft.contexts = CONTEXTS.filter { contexts.contains($0) }
        if hasDates {
            draft.startDate = HomeScreen.ymd(start)
            draft.endDate = HomeScreen.ymd(max(start, end))
        }
        var made: TripEvent?
        model.change { made = $0.createTrip(draft) }
        name = ""; activities = []; contexts = []; hasDates = false; quick = false
        opened = made?.id
    }

    static func ymd(_ d: Date) -> String {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone.current; f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }

    private struct Opened: Identifiable { let id: String }
}

/// A row of pills: one chosen (transport) or several (activities). Each pill's
/// identifier is `<id>-<n>`, its position — never its words.
struct Pills: View {
    let title: String
    let options: [(id: String, label: String)]
    let selected: Set<String>
    let id: String
    var tint: Color = AppSection.home.color
    var startIndex: Int = 0
    /// Smaller buttons under the same heading — the thing editor, where he found the
    /// headings drowned by the buttons (2026-09-26): "keep the headings and make the
    /// buttons' text size a bit smaller".
    var compact = false
    let choose: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 14, weight: .heavy)).foregroundStyle(Theme.muted)
            FlowRow(spacing: 8) {
                ForEach(Array(options.enumerated()), id: \.element.id) { n, o in
                    let on = selected.contains(o.id)
                    Button { choose(o.id) } label: {
                        Text(o.label)
                            .font(.system(size: compact ? 13 : 15, weight: on ? .bold : .semibold))
                            .foregroundStyle(on ? Color.white : Theme.ink)
                            .padding(.horizontal, compact ? 10 : 14).frame(minHeight: compact ? 32 : 36)
                            .background(Capsule().fill(on ? tint : Theme.bg))
                            .overlay(Capsule().stroke(on ? tint : Theme.line, lineWidth: 1))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("\(id)-\(startIndex + n)")
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
    }
}

/// Pills that wrap onto the next line when the row is full.
struct FlowRow: Layout {
    var spacing: Double = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 10_000
        var x = 0.0, y = 0.0, rowH = 0.0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > 0 && x + sz.width > width { x = 0; y += rowH + spacing; rowH = 0 }
            x += sz.width + spacing; rowH = max(rowH, sz.height)
        }
        return CGSize(width: width, height: y + rowH)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH = 0.0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > bounds.minX && x + sz.width > bounds.maxX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += sz.width + spacing; rowH = max(rowH, sz.height)
        }
    }
}

struct CountTile: View {
    let number: Int
    let label: String
    let id: String
    let color: Color
    var body: some View {
        VStack(spacing: 2) {
            Text("\(number)").font(.system(size: 30, weight: .heavy).monospacedDigit()).foregroundStyle(color)
                .accessibilityIdentifier(id)
            Text(label).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, minHeight: 76)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line, lineWidth: 1))
    }
}
