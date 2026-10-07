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
    /// Whether the trip gets dates — set by tapping a day, taken away by Clear dates.
    @State private var hasDates = false
    /// The first day is tapped and the last is not yet: Create waits for it.
    @State private var pickingEnd = false
    @State private var start = Date()
    @State private var end = Date().addingTimeInterval(2 * 86400)
    @State private var transport = "Car"
    @State private var season = "Summer"
    @State private var catering = "mixed"
    @State private var activities: Set<String> = []
    /// Indoor / Outdoor / Race PER WORKOUT (0.67): template id → its contexts.
    @State private var workoutContexts: [String: Set<String>] = [:]
    @State private var quick = false
    @State private var laundry = false
    @State private var laundryNights = LAUNDRY_CAP_NIGHTS
    @State private var opened: String?
    /// The place a code opened the trip on (0.69): the trip shows only its lines.
    @State private var openedPlace: String?
    /// A place's list, opened by its code when no trip is being packed (0.69).
    @State private var placeShown: PlaceOpening?
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
            VStack(alignment: .leading, spacing: 10) {
                // Home's two parts lead with real headings (field test, 3 Oct 2026: "the
                // headings … dominant"); they were small and grey, smaller than the
                // headings inside Create new trip.
                //
                // Grab and go is Home's FIRST line, its search and Grab Lists beside it on
                // one centre line, and the grab lists right under it (his note on 0.63,
                // 6 Oct 2026: "The area above Grab and go is underused" — the row was
                // lined up on the heading's baseline, so the search button stood up above
                // it and left an empty band at the top).
                VStack(alignment: .leading, spacing: 6) {
                    // On the Mac the header is pinned in the window's title bar strip
                    // instead (`headerOnTheMac`, below).
                    #if !os(macOS)
                    grabHeader
                    #endif
                    // Home holds eight (4 × 2) — HIS, in his order; a free place takes only a
                    // list new since he last arranged Home (GrabCollection.swift).
                    let onHome = model.library.homeGrabLists()
                    GrabButtons(lists: onHome) { grab = $0 }
                    if onHome.isEmpty {
                        // Every list taken off Home: the heading is not left over nothing —
                        // it says where they are, and the line itself leads there (5 Oct 2026).
                        Button { showingGrabLists = true } label: {
                            Text("No grab lists on Home. They wait in Grab Lists \u{2014} tap here to put one back.")
                                .font(.system(.callout, weight: .semibold)).foregroundStyle(AppSection.home.color)
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
                }

                // The trip he leaves on next, counted down (his idea 6) — under the grab
                // lists, which keep their place at the top.
                if let next = model.library.nextTrip(today: Today.local) {
                    CountdownCard(next: next) { openedPlace = nil; opened = next.id }
                        .padding(.top, 4)
                }

                Text("Create new trip").font(.system(.title3, weight: .bold)).foregroundStyle(Theme.ink).padding(.top, 8)
                    .accessibilityIdentifier("home-create-heading")
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Name your trip", text: $name)
                        .textFieldStyle(.plain)
                        .font(.system(.title3, weight: .semibold)).foregroundStyle(Theme.ink)
                        .padding(.horizontal, 12).frame(minHeight: Metrics.tap)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.bg))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(stillNeeded.contains("name") ? AppSection.actions.color : Color.clear, lineWidth: 2))
                        .focused($naming)
                        .onChange(of: name) { _, _ in if !stillNeeded.isEmpty { stillNeeded = needs() } }
                        .accessibilityIdentifier("trip-name")

                    // What KIND of trip, first, under the name — his ask (6 Oct 2026): "the
                    // Quick check box to be placed somewhere else - more thought through".
                    // A two-way choice that says what it leaves out, not a lone switch.
                    TripKindChoice(quick: $quick, id: "trip-kind")
                    // The month grid itself, always open (0.67) — his words: "I would like the
                    // date picker to be present all the time, and then take away the Dates
                    // checkbox", and then "always having the date picker OPEN in Create new
                    // Trip". First day, then last day, set at once; no day tapped = no dates.
                    DateRangePicker(start: $start, end: $end, dated: $hasDates, inline: true, grid: "trip-range") { waiting in
                        pickingEnd = waiting
                        if !stillNeeded.isEmpty { stillNeeded = needs() }
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
                            WorkoutContexts(workouts: WorkoutContexts.ticked(choice.lists, activities, flat),
                                            selected: workoutContexts, id: "trip-context") { workout, context in
                                workoutContexts[workout, default: []].formSymmetricDifference([context])
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
                            .font(.system(.body, weight: .semibold))
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity, minHeight: Metrics.row)
                            .background(RoundedRectangle(cornerRadius: 12).fill(AppSection.home.color))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("trip-create")
                    if !stillNeeded.isEmpty {
                        Text(stillNeeded)
                            .font(.system(.subheadline, weight: .semibold)).foregroundStyle(AppSection.actions.color)
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
                    Text("This Device")
                        .font(.system(.caption, weight: .semibold)).foregroundStyle(Theme.muted)
                        .kerning(0.5)
                        .fixedSize()
                        .rotationEffect(.degrees(-90))
                        .frame(width: 16)
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
        .headerOnTheMac { grabHeader }
        .sheet(isPresented: $searching) { SearchScreen().environmentObject(model) }
        .sheet(item: Binding(get: { opened.map { Opened(id: $0) } }, set: { opened = $0?.id; if $0 == nil { openedPlace = nil } })) { o in
            TripScreen(tripId: o.id, place: openedPlace).environmentObject(model)
        }
        .sheet(item: $placeShown) { PlaceScreen(opening: $0).environmentObject(model) }
        // A place's printed code, read by the Camera (0.69): a trip being packed opens on
        // that place's lines; otherwise the place's own list.
        .onChange(of: model.placeToOpen, initial: true) { _, code in
            guard let code else { return }
            model.placeToOpen = nil
            let o = PlaceOpening.of(code: code, in: model.library, today: Today.local)
            if let trip = o.packingTrip { whenFree { openedPlace = o.place; opened = trip } }
            else { whenFree { placeShown = o } }
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
            if model.library.trips.contains(where: { $0.id == id }) { whenFree { openedPlace = nil; opened = id } }
        }
        .sheet(item: Binding(get: { grab.map { GrabOpened(list: $0) } }, set: { grab = $0?.list })) { g in
            GrabScreen(listId: g.list.id).environmentObject(model)
        }
    }

    private struct GrabOpened: Identifiable { let list: GrabDefinition; var id: String { list.id } }

    /// Grab and go, with the search and Grab Lists beside it: Home's first line on the
    /// iPhone, pinned in the window's title bar strip on the Mac.
    private var grabHeader: some View {
        ScreenHeader(title: "Grab and go", tint: Theme.ink, id: "home-grab-heading",
                     font: .system(.title3, weight: .bold)) {
            SearchButton { searching = true }
            // This door opens the grab lists — not the templates (whose screen
            // is "Your templates"). His note on the Mac: "Your Grab Lists".
            Button { showingGrabLists = true } label: {
                Text("Grab Lists")
                    .font(.system(.footnote, weight: .semibold)).foregroundStyle(AppSection.home.color)
                    .frame(minHeight: Metrics.tap).contentShape(Rectangle())
            }
            .buttonStyle(.plain).focusEffectDisabled()
            .accessibilityIdentifier("grab-lists")
        }
    }

    /// Something asked from outside — a Shortcut, the Action button, a tapped packing
    /// reminder — while one of Home's own windows is up (Grab Lists, Search, a trip,
    /// a grab list): that one closes first, then the asked-for one opens. SwiftUI does
    /// not present a second window from a view while another is up or still closing,
    /// so until 5 Oct 2026 such a request could open nothing.
    private func whenFree(_ open: @escaping () -> Void) {
        let busy = searching || showingGrabLists || opened != nil || grab != nil || menuShown || placeShown != nil
        guard busy else { open(); return }
        searching = false; showingGrabLists = false; opened = nil; grab = nil; menuShown = false; placeShown = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { open() }
    }

    private var canCreate: Bool { !jsTrim(name).isEmpty && !activities.isEmpty && !pickingEnd }

    /// What is still missing before a trip can be made, in his words — "" when nothing.
    private func needs() -> String {
        let noName = jsTrim(name).isEmpty, noList = activities.isEmpty
        var said: [String] = []
        if noName && noList { said.append("Give the trip a name and pick at least one template.") }
        else if noName { said.append("Give the trip a name.") }
        else if noList { said.append("Pick at least one template.") }
        // Only the first day tapped: never a day trip by accident (the spec pass, 5 Oct
        // 2026 — a grid closed on its first day stored one).
        if pickingEnd { said.append("Tap the trip's last day \u{2014} the same day again for a day trip.") }
        return said.joined(separator: " ")
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
        draft.activityContexts = WorkoutContexts.stored(draft.activities, flat, workoutContexts)
        draft.contexts = WorkoutContexts.union(draft.activityContexts)
        if hasDates {
            draft.startDate = HomeScreen.ymd(start)
            draft.endDate = HomeScreen.ymd(max(start, end))
        }
        var made: TripEvent?
        model.change { made = $0.createTrip(draft) }
        name = ""; activities = []; workoutContexts = [:]; hasDates = false; quick = false; laundry = false; laundryNights = LAUNDRY_CAP_NIGHTS
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
            // The pills: medium until
            // picked, a little less padding — smaller than any heading over them, and
            // still 36 tall to press.
            FlowRow(spacing: 6) {
                ForEach(Array(options.enumerated()), id: \.element.id) { n, o in
                    let on = selected.contains(o.id)
                    let tone = tones?(o.label)
                    Button { choose(o.id) } label: {
                        Text(o.label)
                            .font(.system(.subheadline, weight: on ? .semibold : .regular))
                            .foregroundStyle(on ? (tone?.ink ?? Color.white) : Theme.ink)
                            .padding(.horizontal, 12).frame(minHeight: Metrics.chip)
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
            Text("\(number)").font(.system(.title, weight: .bold).monospacedDigit()).foregroundStyle(color)
                .accessibilityIdentifier(id)
            Text(label).font(.system(.footnote, weight: .semibold)).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, minHeight: 76)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line, lineWidth: 1))
    }
}

/// Full trip | Quick — the KIND of trip, as a two-way choice under the name (0.67, his
/// ask: "the Quick check box to be placed somewhere else - more thought through").
/// Until then a "Quick" switch sat at the end of the Dates line, its meaning in a green
/// box that appeared only while it was on (his test C.7). Now both answers are always in
/// sight, the picked one filled, and one quiet line under them says what Quick leaves out.
/// Ids: `<id>-full`, `<id>-quick` (the picked one `.isSelected`), `<id>-note`.
struct TripKindChoice: View {
    @Binding var quick: Bool
    let id: String
    var tint: Color = AppSection.home.color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 2) {
                segment("Full trip", picked: !quick, id: "\(id)-full") { quick = false }
                segment("Quick", picked: quick, id: "\(id)-quick") { quick = true }
            }
            .padding(2)
            .background(Capsule().fill(Theme.bg))
            .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
            .frame(maxWidth: 360)
            // Field test 5.1/6.1 (3 Oct 2026): words that made Transport look switched
            // off left the trip on "Car" and the plane's cabin check never ran — so the
            // line says Transport still counts.
            Text("Quick packs only the templates you tick \u{2014} no common base, no transport kit. Transport still counts.")
                .font(.system(.footnote)).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("\(id)-note")
        }
    }

    private func segment(_ words: String, picked: Bool, id: String, _ pick: @escaping () -> Void) -> some View {
        Button(action: pick) {
            Text(words)
                .font(.system(.subheadline, weight: picked ? .semibold : .regular))
                .foregroundStyle(picked ? Color.white : Theme.ink)
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: Metrics.chip)
                .background(Capsule().fill(picked ? tint : Color.clear))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier(id)
        .accessibilityAddTraits(picked ? .isSelected : [])
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
    /// Fill and words, by the workout's name.
    private static func pair(_ name: String) -> (fill: UInt32, ink: UInt32)? {
        switch normName(name).filter({ !$0.isWhitespace }) {
        case "swim": return (0x0a84ff, 0xffffff)
        case "bike": return (0xffd60a, 0x3d3000)
        case "run": return (0x30d158, 0x0b3a17)
        case "strength": return (0xff8c1a, 0x4a2300)
        case "breathwork": return (0xbf9cff, 0x2e1a5c)
        case "mobility": return (0xff6fa8, 0x5a0f2e)
        default: return nil
        }
    }

    static func of(_ name: String) -> PillTone? {
        pair(name).map { PillTone(fill: Color(hex: $0.fill), ink: Color(hex: $0.ink)) }
    }

    /// The workout's colour as WORDS on the card (the per-workout Context lines, 0.67):
    /// its hue, darkened on a light screen or lightened on a dark one until it reads —
    /// the way his own colours are written (`readableHex`; Bike's bright yellow is
    /// unreadable on white as it is). Nil for a template with no colour of its own.
    static func words(_ name: String, dark: Bool) -> Color? {
        pair(name).map { Color(hexString: readableHex(String(format: "#%06x", $0.fill), dark: dark)) }
    }
}

/// Indoor / Outdoor / Race PER WORKOUT (0.67) — his ask: "the same context menu is
/// needed for all WET activities. Example: it could be outdoors Run and indoors Swim."
/// Set in under the workouts, with a line down its side, so it reads as belonging to
/// them (his ask, 2026-09-28), in a quiet grey: it describes the workouts rather than
/// being one. One compact line per TICKED workout: its name in its own colour, then its
/// own three pills. Until 0.67 one Indoor/Outdoor/Race set narrowed every workout.
///
/// Ids, by the workout's place among the template pills (`<activity id>-<n>`):
/// `<id>-<n>-name` (its name), `<id>-<n>-0…2` (Indoor, Outdoor, Race; picked = `.isSelected`);
/// the heading `<id>-title`.
struct WorkoutContexts: View {
    struct Workout: Identifiable { let id: String; let name: String; let index: Int }
    let workouts: [Workout]
    let selected: [String: Set<String>]
    let id: String
    let choose: (_ workout: String, _ context: String) -> Void
    @Environment(\.colorScheme) private var scheme

    /// The ticked templates of one group (the WET one), in the order offered, each with
    /// its place among ALL the template pills — the number its pill carries.
    static func ticked(_ lists: [PackList], _ ticked: Set<String>, _ flat: [PackList]) -> [Workout] {
        lists.filter { ticked.contains($0.id) }.map { l in
            Workout(id: l.id, name: l.name, index: flat.firstIndex { $0.id == l.id } ?? 0)
        }
    }

    /// What the trip stores (`activityContexts`): an entry for EVERY ticked workout,
    /// nothing picked = an empty one (narrows nothing) — in `CONTEXTS` order.
    static func stored(_ activities: [String], _ flat: [PackList], _ picked: [String: Set<String>]) -> [String: [String]] {
        let workouts = Set(flat.filter { $0.group == "WET" }.map(\.id))
        var out: [String: [String]] = [:]
        for a in activities where workouts.contains(a) {
            out[a] = CONTEXTS.filter { picked[a, default: []].contains($0) }
        }
        return out
    }

    /// The trip-wide `contexts`: every context picked for any workout — what a device
    /// still on 0.66, or the web app, reads (this build narrows each workout by its own).
    static func union(_ perWorkout: [String: [String]]) -> [String] {
        CONTEXTS.filter { c in perWorkout.values.contains { $0.contains(c) } }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 1.5).fill(Theme.line).frame(width: 3)
            VStack(alignment: .leading, spacing: 6) {
                HeadingTitle(title: "Context", tint: AppSection.settings.color, id: "\(id)-title", question: true)
                ForEach(workouts) { w in
                    HStack(alignment: .center, spacing: 8) {
                        Text(w.name)
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(WorkoutTone.words(w.name, dark: scheme == .dark) ?? Theme.ink)
                            .lineLimit(2).minimumScaleFactor(0.8)
                            .frame(width: Metrics.contextName, alignment: .leading)
                            .accessibilityIdentifier("\(id)-\(w.index)-name")
                        FlowRow(spacing: 6) {
                            ForEach(Array(CONTEXTS.enumerated()), id: \.element) { k, c in
                                let on = selected[w.id, default: []].contains(c)
                                Button { choose(w.id, c) } label: {
                                    Text(c)
                                        .font(.system(.subheadline, weight: on ? .semibold : .regular))
                                        .foregroundStyle(on ? Color.white : Theme.ink)
                                        .padding(.horizontal, 10).frame(minHeight: Metrics.chip)
                                        .background(Capsule().fill(on ? AppSection.settings.color : Theme.bg))
                                        .overlay(Capsule().stroke(on ? AppSection.settings.color : Theme.line, lineWidth: 1))
                                        .contentShape(Capsule())
                                }
                                .buttonStyle(.plain).focusEffectDisabled()
                                .accessibilityIdentifier("\(id)-\(w.index)-\(k)")
                                .accessibilityAddTraits(on ? .isSelected : [])
                            }
                        }
                    }
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.leading, 18)
    }
}
