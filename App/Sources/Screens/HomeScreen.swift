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
    @State private var laundry = false
    @State private var laundryNights = LAUNDRY_CAP_NIGHTS
    @State private var opened: String?
    @State private var grab: GrabDefinition?
    @State private var searching = false
    @State private var showingGrabLists = false
    /// "Which grab list?" — the Action button's menu, asked for through the model.
    @State private var menuShown = false
    /// What Create said was missing, after a press with something missing.
    @State private var stillNeeded = ""
    @FocusState private var naming: Bool

    var body: some View {
        let choices = model.library.activityChoices()
        let flat = choices.flatMap(\.lists)
        let anyWorkout = flat.contains { $0.group == "WET" && activities.contains($0.id) }
        KeyboardAwayScroll {
            VStack(alignment: .leading, spacing: 14) {
                // Home's two parts lead with real headings (field test, 3 Oct 2026: "the
                // headings … dominant"); they were small and grey, smaller than the
                // headings inside Create new trip.
                HStack(alignment: .firstTextBaseline) {
                    Text("Grab and go").font(.system(size: HeadingSize.band, weight: .heavy)).foregroundStyle(Theme.ink)
                        .accessibilityIdentifier("home-grab-heading")
                    Spacer()
                    SearchButton { searching = true }
                    // This door opens the grab lists — not the templates (whose screen
                    // is "Your templates"). His note on the Mac: "Your Grab Lists".
                    Button("Grab Lists") { showingGrabLists = true }
                        .buttonStyle(.plain).focusEffectDisabled()
                        .font(.system(size: 15, weight: .bold)).foregroundStyle(AppSection.home.color)
                        .accessibilityIdentifier("grab-lists")
                }
                .padding(.top, 14)
                // Home holds eight (4 × 2) — HIS, in his order; a free place takes only a
                // list new since he last arranged Home (GrabCollection.swift).
                let onHome = model.library.homeGrabLists()
                GrabButtons(lists: onHome) { grab = $0 }
                if onHome.isEmpty {
                    // Every list taken off Home: the heading is not left over nothing —
                    // it says where they are, and the line itself leads there (5 Oct 2026).
                    Button { showingGrabLists = true } label: {
                        Text("No grab lists on Home. They wait in Grab Lists \u{2014} tap here to put one back.")
                            .font(.system(size: 16, weight: .semibold)).foregroundStyle(AppSection.home.color)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppSection.home.color.opacity(0.5), lineWidth: 1.5))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("home-grab-none")
                }

                // The trip he leaves on next, counted down (his idea 6) — under the grab
                // lists, which keep their place at the top.
                if let next = model.library.nextTrip(today: Today.local) {
                    CountdownCard(next: next) { opened = next.id }
                        .padding(.top, 4)
                }

                Text("Create new trip").font(.system(size: HeadingSize.band, weight: .heavy)).foregroundStyle(Theme.ink).padding(.top, 8)
                    .accessibilityIdentifier("home-create-heading")
                VStack(alignment: .leading, spacing: 14) {
                    TextField("Name your trip", text: $name)
                        .textFieldStyle(.plain)
                        .font(.system(size: 20, weight: .semibold)).foregroundStyle(Theme.ink)
                        .padding(.horizontal, 12).frame(minHeight: 48)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.bg))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(stillNeeded.contains("name") ? AppSection.actions.color : Color.clear, lineWidth: 2))
                        .focused($naming)
                        .onChange(of: name) { _, _ in if !stillNeeded.isEmpty { stillNeeded = needs() } }
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
                    // In GREEN, like the switch that brought it (his test C.7: grey, "you
                    // almost don't see it, so you don't see that anything has changed").
                    if quick { QuickNote(id: "trip-quick-note") }
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
                              startIndex: flat.firstIndex { $0.id == choice.lists[0].id } ?? 0,
                              tones: choice.group.id == "WET" ? WorkoutTone.of : nil) { id in
                            if activities.contains(id) { activities.remove(id) } else { activities.insert(id) }
                            if !stillNeeded.isEmpty { stillNeeded = needs() }
                        }
                        if choice.group.id == "WET" && anyWorkout {
                            ContextPills(selected: contexts, id: "trip-context") { id in
                                if contexts.contains(id) { contexts.remove(id) } else { contexts.insert(id) }
                            }
                        }
                    }
                    Pills(title: "Transport", options: TRANSPORTS.map { ($0, $0) }, selected: [transport], id: "trip-transport") { transport = $0 }
                    Pills(title: "Season", options: SEASONS.map { ($0, $0) }, selected: [season], id: "trip-season") { season = $0 }
                    Pills(title: "Food", options: CATERING.map { ($0.id, HomeScreen.shortFood($0.id, $0.label)) },
                          selected: [catering], id: "trip-catering") { catering = $0 }
                    LaundrySwitch(on: $laundry, nights: $laundryNights, id: "trip-laundry")

                    // The app's main button is ALWAYS in full colour — his words (2026-09-26):
                    // "The create button is something that is central to the whole app,
                    // and you make it grayed out." A press with something missing
                    // creates nothing and says what is missing, right under it.
                    Button { create(flat) } label: {
                        Text("Create trip")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(RoundedRectangle(cornerRadius: 12).fill(AppSection.home.color))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("trip-create")
                    if !stillNeeded.isEmpty {
                        Text(stillNeeded)
                            .font(.system(size: 15, weight: .bold)).foregroundStyle(AppSection.actions.color)
                            .frame(maxWidth: .infinity)
                            .accessibilityIdentifier("trip-create-needs")
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line, lineWidth: 1))

                // His marks on the Mac: the heading struck out and written down the
                // SIDE instead, and Trips and Templates swapped over.
                HStack(spacing: 10) {
                    // 15 (it was 12): standing on its side it is 95 points long, so the
                    // tiles beside it are 96 tall (they were 76).
                    Text("This Device")
                        .font(.system(size: 15, weight: .heavy)).foregroundStyle(Theme.muted)
                        .kerning(0.5)
                        .fixedSize()
                        .rotationEffect(.degrees(-90))
                        .frame(width: 20)
                        .accessibilityIdentifier("device-heading")
                    CountTile(number: model.library.trips.count, label: "Trips", id: "count-trips", color: AppSection.events.color)
                    CountTile(number: model.library.items.count, label: "Things", id: "count-things", color: AppSection.care.color)
                    // The templates Your templates shows — not the hidden bags list or the
                    // web app's old bin, which made this number the higher one (5 Oct 2026).
                    CountTile(number: TemplatesScreen.activityAreas(model.library.templates).reduce(0) { $0 + $1.lists.count },
                              label: "Templates", id: "count-templates", color: AppSection.templates.color)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 16).padding(.bottom, 24)
        }
        .sheet(isPresented: $searching) { SearchScreen().environmentObject(model) }
        .sheet(item: Binding(get: { opened.map { Opened(id: $0) } }, set: { opened = $0?.id })) { o in
            TripScreen(tripId: o.id).environmentObject(model)
        }
        .sheet(isPresented: $showingGrabLists) { GrabCollectionScreen().environmentObject(model) }
        // The Action button's "Choose a grab list" (field test 2.3): the menu of them all.
        .sheet(isPresented: $menuShown) { GrabMenuScreen().environmentObject(model) }
        .onChange(of: model.grabMenuOpen, initial: true) { _, open in
            guard open else { return }
            model.grabMenuOpen = false
            if !menuShown { whenFree { menuShown = true } }
        }
        // A Shortcut (the Action button): its grab list.
        .onChange(of: model.grabToOpen, initial: true) { _, id in
            guard let id else { return }
            model.grabToOpen = nil
            if let list = model.library.allGrabLists().first(where: { $0.id == id }) { whenFree { grab = list } }
        }
        // A tapped packing reminder, or a Shortcut: its trip.
        .onChange(of: model.tripToOpen, initial: true) { _, id in
            guard let id else { return }
            model.tripToOpen = nil
            if model.library.trips.contains(where: { $0.id == id }) { whenFree { opened = id } }
        }
        .sheet(item: Binding(get: { grab.map { GrabOpened(list: $0) } }, set: { grab = $0?.list })) { g in
            GrabScreen(listId: g.list.id).environmentObject(model)
        }
    }

    private struct GrabOpened: Identifiable { let list: GrabDefinition; var id: String { list.id } }

    /// Something asked from outside — a Shortcut, the Action button, a tapped packing
    /// reminder — while one of Home's own windows is up (Grab Lists, Search, a trip,
    /// a grab list): that one closes first, then the asked-for one opens. SwiftUI does
    /// not present a second window from a view while another is up or still closing,
    /// so until 5 Oct 2026 such a request could open nothing.
    private func whenFree(_ open: @escaping () -> Void) {
        let busy = searching || showingGrabLists || opened != nil || grab != nil || menuShown
        guard busy else { open(); return }
        searching = false; showingGrabLists = false; opened = nil; grab = nil; menuShown = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { open() }
    }

    private var canCreate: Bool { !jsTrim(name).isEmpty && !activities.isEmpty }

    /// What is still missing before a trip can be made, in his words — "" when nothing.
    private func needs() -> String {
        let noName = jsTrim(name).isEmpty, noList = activities.isEmpty
        if noName && noList { return "Give the trip a name and pick at least one template." }
        if noName { return "Give the trip a name." }
        if noList { return "Pick at least one template." }
        return ""
    }

    private func create(_ flat: [PackList]) {
        guard canCreate else {
            stillNeeded = needs()
            if jsTrim(name).isEmpty { naming = true }
            return
        }
        stillNeeded = ""
        var draft = newEvent(name: jsTrim(name), mode: quick ? "quick" : "trip")
        draft.transport = transport
        draft.season = season
        draft.catering = catering
        draft.laundry = laundry
        draft.extra[LAUNDRY_NIGHTS_KEY] = .number(Double(laundryNights))
        draft.activities = flat.map(\.id).filter { activities.contains($0) }   // in the order offered
        draft.contexts = CONTEXTS.filter { contexts.contains($0) }
        if hasDates {
            draft.startDate = HomeScreen.ymd(start)
            draft.endDate = HomeScreen.ymd(max(start, end))
        }
        var made: TripEvent?
        model.change { made = $0.createTrip(draft) }
        name = ""; activities = []; contexts = []; hasDates = false; quick = false; laundry = false; laundryNights = LAUNDRY_CAP_NIGHTS
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
    /// How its heading reads. The heading always LEADS: their field test (3
    /// Oct 2026) found the pills drowning it — "the other buttons and pills are much
    /// smaller than the heading". Until then most pill rows had a small grey heading
    /// (14) over bigger buttons (15).
    var heading: PillsHeading = .title
    /// A colour of its own for some pills, by their words — the workouts (his
    /// colours, 2026-09-28). Picked: filled in it; not picked: outlined in it.
    var tones: ((String) -> PillTone?)? = nil
    let choose: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // In the colour of their own buttons, not grey (2026-09-27: "choose another
            // color that is more distinctive regarding the headings").
            switch heading {
            case .band: HeadingBand(title: title, tint: tint, id: "\(id)-title")     // his sketch (2026-09-27)
            case .title: HeadingTitle(title: title, tint: tint, id: "\(id)-title")
            case .question: HeadingTitle(title: title, tint: tint, id: "\(id)-title", question: true)
            }
            // The pills: 15 (his floor for reading without glasses), medium until
            // picked, a little less padding — smaller than any heading over them, and
            // still 36 tall to press.
            FlowRow(spacing: 6) {
                ForEach(Array(options.enumerated()), id: \.element.id) { n, o in
                    let on = selected.contains(o.id)
                    let tone = tones?(o.label)
                    Button { choose(o.id) } label: {
                        Text(o.label)
                            .font(.system(size: 15, weight: on ? .bold : .medium))
                            .foregroundStyle(on ? (tone?.ink ?? Color.white) : Theme.ink)
                            .padding(.horizontal, 12).frame(minHeight: 36)
                            .background(Capsule().fill(on ? (tone?.fill ?? tint) : Theme.bg))
                            .overlay(Capsule().stroke(on ? (tone?.fill ?? tint) : (tone?.fill ?? Theme.line),
                                                      lineWidth: tone == nil || on ? 1 : 1.8))
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

/// The heading over a row of pills: a band of its own (the editors), a title inside
/// a block (Create new trip, Trip settings), or a question inside one.
enum PillsHeading { case band, title, question }

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
            Text(label).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, minHeight: 96)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line, lineWidth: 1))
    }
}

/// What Quick means, shown while it is on — green like the switch, framed so the
/// change is seen (his test C.7).
struct QuickNote: View {
    let id: String
    var body: some View {
        // Field test 5.1/6.1 (3 Oct 2026): the old words made Transport look switched
        // off, the trip stayed "Car", and the plane's cabin check never ran.
        Text("Quick: only the templates you tick \u{2014} no common base, no transport kit. Transport still counts: pick Plane and the cabin is checked.")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(AppSection.events.color)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12).padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(AppSection.events.color.opacity(0.12)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppSection.events.color, lineWidth: 1.2))
            .accessibilityIdentifier(id)
    }
}

/// A pill's own colour: its fill, and the words on it.
struct PillTone {
    let fill: Color
    let ink: Color
}

/// The workout colours he chose (2026-09-28), the same in AMS Workout Sync — and
/// the same family in the grab lists, which draw them as mid-tones (`GrabTone`: a
/// bright fill would not read as a line on the light card). Written down in
/// docs/colours.md. Yellow and the light ones carry dark words: white is
/// unreadable on them. He does not like teal.
enum WorkoutTone {
    static func of(_ name: String) -> PillTone? {
        switch normName(name).filter({ !$0.isWhitespace }) {
        case "swim": return PillTone(fill: Color(hex: 0x0a84ff), ink: .white)
        case "bike": return PillTone(fill: Color(hex: 0xffd60a), ink: Color(hex: 0x3d3000))
        case "run": return PillTone(fill: Color(hex: 0x30d158), ink: Color(hex: 0x0b3a17))
        case "strength": return PillTone(fill: Color(hex: 0xff8c1a), ink: Color(hex: 0x4a2300))
        case "breathwork": return PillTone(fill: Color(hex: 0xbf9cff), ink: Color(hex: 0x2e1a5c))
        case "mobility": return PillTone(fill: Color(hex: 0xff6fa8), ink: Color(hex: 0x5a0f2e))
        default: return nil
        }
    }
}

/// Indoor / Outdoor / Race — set in under the workouts, with a line down its side,
/// so it reads as belonging to them (his ask, 2026-09-28), in a quiet grey: it
/// describes the workouts rather than being one.
struct ContextPills: View {
    let selected: Set<String>
    let id: String
    let choose: (String) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 1.5).fill(Theme.line).frame(width: 3)
            Pills(title: "Context", options: CONTEXTS.map { ($0, $0) }, selected: selected, id: id,
                  tint: AppSection.settings.color, heading: .question, choose: choose)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.leading, 18)
    }
}
