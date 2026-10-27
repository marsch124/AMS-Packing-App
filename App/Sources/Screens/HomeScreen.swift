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
        case "mixed": return "Mix"
        default: return fallback
        }
    }

    /// The drawing before a Season pill (0.78, his ask: "same idea as Travelling by") — the
    /// template catalog's own: Summer the sun, Winter the snowflake; nil for any other word.
    static func seasonIcon(_ word: String) -> String? {
        switch word {
        case "Summer": return "sun"
        case "Winter": return "snow"
        default: return nil
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
    /// Travelling by (0.76): "Plane", "RV" — or "Car", an ordinary trip, with both off.
    @State private var transport = Library.ordinaryTransport
    @State private var season = "Summer"
    /// Season follows the dates (0.76, `Library.seasonFor`) until he taps a Season pill on this
    /// form; from then his choice sticks. Create starts the form over.
    @State private var seasonByHand = false
    /// More choices (0.76): Season, Food and Laundry folded away — closed to begin with,
    /// open or closed remembered on this device.
    @AppStorage(HomeScreen.moreKey) private var moreOpen = false
    static let moreKey = "ams.create.more"
    @State private var catering = "mixed"
    @State private var activities: Set<String> = []
    /// Indoor / Outdoor / Race PER WORKOUT (0.67): template id → its contexts.
    @State private var workoutContexts: [String: Set<String>] = [:]
    @State private var quick = false
    @State private var laundry = false
    @State private var laundryNights = LAUNDRY_CAP_NIGHTS
    /// "I leave at" (0.69, the door check): on the first day, and on the last for home.
    @State private var leaveOut = ""
    @State private var leaveHome = ""
    /// Flights and stay (0.80, spec 07 part 18 B): only on a plane trip; Out and Home to begin with.
    @State private var travel = TripTravel(flights: [FlightLeg(), FlightLeg()])
    @State private var opened: String?
    /// The place a code opened the trip on (0.69): the trip shows only its lines.
    @State private var openedPlace: String?
    /// Pack by voice asked by that code (0.71, iPhone): started once THAT trip screen is up.
    @State private var voiceAsked: VoiceStartAt?
    /// A place's list, opened by its code when no trip is being packed (0.69).
    @State private var placeShown: PlaceOpening?
    @State private var grab: GrabDefinition?
    /// A thing's page, opened by its result tapped in Spotlight (0.92, Store/Spotlight.swift).
    @State private var thingShown: Opened?
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
                // Grab and go is Home's FIRST block, its Grab Lists (and on the iPhone its
                // search) beside it on one centre line, and the grab lists right under it (his
                // note on 0.63, 6 Oct 2026: "The area above Grab and go is underused").
                //
                // Since 0.91 ONE frame holds the heading and the grab lists, as Create new trip's
                // card holds its own — his words (19 Oct 2026): "I would like to have all
                // grab-and-go bags and grab bags within one frame, as the "Create New Trip" is in
                // a frame. I would like the "Grab and Go" heading to be inside this frame." Until
                // 0.91 the heading was Home's header line (on the Mac in the title bar strip) and
                // the tiles sat loose under it.
                VStack(alignment: .leading, spacing: 8) {
                    grabHeading
                    // Home holds eight (4 × 2) — HIS, in his order; a free place takes only a
                    // list new since he last arranged Home (GrabCollection.swift).
                    let onHome = model.library.homeGrabLists()
                    GrabButtons(lists: onHome, fill: Theme.bg) { grab = $0 }
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
                                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.bg))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppSection.home.color.opacity(0.5), lineWidth: 1.5))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).focusEffectDisabled()
                        .accessibilityIdentifier("home-grab-none")
                    }
                }
                .homeCard(id: "home-grab-frame")
                // The first block starts where every tab's first line does (as Settings' first card).
                .padding(.top, Metrics.screenTop)

                // The trip he leaves on next, counted down (his idea 6) — under the grab
                // lists, which keep their place at the top.
                if let next = model.library.nextTrip(today: Today.local, time: Today.time) {
                    CountdownCard(next: next) { openedPlace = nil; opened = next.id }
                }

                // This Device, right under the trip (0.91 — his words, 19 Oct 2026: "I would also
                // like the "This device" area to move up directly under the trip list."): under the
                // countdown card, or under Grab and go when no trip is ahead; until 0.91 it was
                // Home's last line, under Create new trip.
                thisDevice

                VStack(alignment: .leading, spacing: 10) {
                    // The heading inside its card, above the name (0.91 — his words: "I would also
                    // like to have the text "Create New Trip" within the "Name your trip" frame.").
                    // A tad smaller since 0.92 — his words (19 Oct 2026): "The text "Create new trip" on the
                    // home page, could we please make it a tad smaller? Not much, but a bit smaller." One
                    // step down Apple's text styles, Title 3 → Headline, still bold; Grab and go stays Title 3.
                    // And a tad grey — "Maybe a tad grayish, not so super black.": `Theme.inkGrey`.
                    let headingTone = Theme.inkGreyPair
                    Text("Create new trip").font(.system(.headline, weight: .bold))
                        .foregroundStyle(Color(light: headingTone.light, dark: headingTone.dark))
                        .accessibilityIdentifier("home-create-heading")
                        #if DEBUG && os(iOS)
                        // The colour it is written in, day/night, for the tests (the Mac reports a text's words).
                        .accessibilityValue(String(format: "#%06x/#%06x", headingTone.light, headingTone.dark))
                        #endif
                    TextField("Name your trip", text: $name)
                        .textFieldStyle(.plain)
                        .font(.system(.title3, weight: .semibold)).foregroundStyle(Theme.ink)
                        .padding(.horizontal, 12).frame(minHeight: Metrics.tap)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.bg))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(stillNeeded.contains("name") ? AppSection.actions.color : Color.clear, lineWidth: 2))
                        .focused($naming)
                        .onChange(of: name) { _, _ in if !stillNeeded.isEmpty { stillNeeded = needs(flat) } }
                        .accessibilityIdentifier("trip-name")

                    // What KIND of trip, first, under the name — his ask (6 Oct 2026): "the
                    // Quick check box to be placed somewhere else - more thought through".
                    // A two-way choice that says what it leaves out, not a lone switch.
                    TripKindChoice(quick: $quick, note: model.library.quickNote(), id: "trip-kind")
                    // The month grid itself, always open (0.67) — his words: "I would like the
                    // date picker to be present all the time, and then take away the Dates
                    // checkbox", and then "always having the date picker OPEN in Create new
                    // Trip". First day, then last day, set at once; no day tapped = no dates.
                    DateRangePicker(start: $start, end: $end, dated: $hasDates, inline: true, grid: "trip-range") { waiting in
                        pickingEnd = waiting
                        if !stillNeeded.isEmpty { stillNeeded = needs(flat) }
                    }
                    // The door check (0.69): a time on a day needs the days.
                    if hasDates {
                        LeaveTimes(out: $leaveOut, home: $leaveHome, id: "trip-leave", tint: AppSection.home.color)
                    }

                    ForEach(choices, id: \.group.id) { choice in
                        // Numbered across ALL groups, so "trip-activity-0" names one pill.
                        // His area's heading (0.89): "GA · Goal Activity", or his own words.
                        Pills(title: Library.areaWords(ActivityArea(id: choice.group.id, name: choice.group.label)),
                              options: choice.lists.map { ($0.id, $0.name) },
                              selected: activities, id: "trip-activity", tint: AppSection.templates.color,
                              startIndex: flat.firstIndex { $0.id == choice.lists[0].id } ?? 0,
                              // His colour for a template (0.91), else a workout's own colour.
                              tones: TemplateTone.byId(choice.lists, workouts: choice.group.id == "WET")) { id in
                            if activities.contains(id) { activities.remove(id) } else { activities.insert(id) }
                            if !stillNeeded.isEmpty { stillNeeded = needs(flat) }
                        }
                        if choice.group.id == "WET" && anyWorkout {
                            WorkoutContexts(workouts: WorkoutContexts.ticked(choice.lists, activities, flat),
                                            selected: workoutContexts, id: "trip-context") { workout, context in
                                workoutContexts[workout, default: []].formSymmetricDifference([context])
                            }
                        }
                    }
                    // His decision (13 Oct 2026, the Car template deleted — "the car is just go
                    // and drive"): Plane or RV, both off for an ordinary trip (stored "Car").
                    TravellingBy(transport: $transport, note: model.library.travelNote(quick: quick), id: "trip-transport")
                    // The lost-luggage information (0.80, his yes of 13 Oct 2026): on a plane trip only,
                    // right under the Plane pill that brings it. Optional — never asked for by Create.
                    if Library.travelLit(transport, "Plane") {
                        FlightsAndStay(travel: $travel,
                                       firstDay: hasDates ? HomeScreen.ymd(start) : "",
                                       lastDay: hasDates ? HomeScreen.ymd(max(start, end)) : "",
                                       place: "", id: "trip-flights", tint: AppSection.home.color)
                    }
                    // His ask (13 Oct 2026): the dates, the templates, Travelling by and "I leave
                    // at" stay in sight; Season, Food and Laundry fold away, said in one line.
                    MoreChoices(open: $moreOpen,
                                summary: HomeScreen.moreSummary(season: season, catering: catering,
                                                                laundry: laundry, nights: laundryNights),
                                id: "trip-more") {
                        Pills(title: "Season", options: SEASONS.map { ($0, $0) }, selected: [season], id: "trip-season",
                              icons: HomeScreen.seasonIcon) {
                            season = $0
                            seasonByHand = true
                        }
                        Pills(title: "Food", options: CATERING.map { ($0.id, HomeScreen.shortFood($0.id, $0.label)) },
                              selected: [catering], id: "trip-catering") { catering = $0 }
                        LaundrySwitch(on: $laundry, nights: $laundryNights, id: "trip-laundry")
                    }

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
                    // ⌘S = Create trip (0.103, Mac): a page open over Home is a window of its own, which has the keys.
                    .commandS { create(flat) }
                    .accessibilityIdentifier("trip-create")
                    if !stillNeeded.isEmpty {
                        Text(stillNeeded)
                            .font(.system(.subheadline, weight: .semibold)).foregroundStyle(AppSection.actions.color)
                            .multilineTextAlignment(.center)            // two sentences wrap (0.73): still centred
                            .frame(maxWidth: .infinity)
                            .accessibilityIdentifier("trip-create-needs")
                    }
                }
                .homeCard(id: "home-create-card")
                // Full trip | Quick, and the answers that rule things in or out, decide
                // whether Always packed alone has something to pack (0.73): the line follows.
                .onChange(of: [quick ? "quick" : "trip", transport, season, catering]) { _, _ in
                    if !stillNeeded.isEmpty { stillNeeded = needs(flat) }
                }
                // Season from the trip's first day (0.76): set at the first tap, at a new first
                // day and at Clear dates — until he picks a season himself.
                .onChange(of: hasDates) { _, _ in seasonFromDates() }
                .onChange(of: start) { _, _ in seasonFromDates() }

            }
            .padding(.horizontal, 16).padding(.bottom, 24)
        }
        // The Mac keeps Home's search in the window's title bar strip, where every tab's search
        // is; the strip holds nothing else on Home since 0.91 (Grab and go is in its frame).
        .headerOnTheMac { searchStrip }
        .sheet(isPresented: $searching) { SearchScreen().environmentObject(model) }
        .sheet(item: Binding(get: { opened.map { Opened(id: $0) } }, set: { opened = $0?.id; if $0 == nil { openedPlace = nil; voiceAsked = nil } })) { o in
            TripScreen(tripId: o.id, place: openedPlace).environmentObject(model)
                .onAppear { startVoiceAsked(on: o.id) }
        }
        .sheet(item: $placeShown) { PlaceScreen(opening: $0).environmentObject(model) }
        // A place's printed code, read by the Camera (0.69): a trip being packed opens on
        // that place's lines; otherwise the place's own list.
        .onChange(of: model.placeToOpen, initial: true) { _, code in
            guard let code else { return }
            model.placeToOpen = nil
            let o = PlaceOpening.of(code: code, in: model.library, today: Today.local)
            if let trip = o.packingTrip {
                // Pack by voice starts there by itself (0.71, his yes; off by its switch on
                // the panel) — asked once this trip screen is up (`startVoiceAsked`).
                whenFree { openedPlace = o.place; opened = trip; voiceAsked = o.voiceStart }
            }
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
        // A thing's result tapped in Spotlight (0.92): its page, over whatever was up.
        .sheet(item: $thingShown) { ThingEditor(itemId: $0.id).environmentObject(model) }
        .onChange(of: model.thingToOpen, initial: true) { _, id in
            guard let id else { return }
            model.thingToOpen = nil
            if model.library.items.contains(where: { $0.id == id }) { whenFree { thingShown = Opened(id: id) } }
        }
    }

    private struct GrabOpened: Identifiable { let list: GrabDefinition; var id: String { list.id } }

    /// Grab and go's line, the first inside its frame (0.91): the heading, then — on one
    /// centre line with it — the search (iPhone; the Mac's is in the title bar strip) and
    /// Grab Lists. Until 0.91 this line was Home's header (`ScreenHeader`), on the Mac pinned
    /// in the title bar strip.
    private var grabHeading: some View {
        HStack(alignment: .center, spacing: 8) {
            Text("Grab and go").font(.system(.title3, weight: .bold)).foregroundStyle(Theme.ink)
                .lineLimit(1).minimumScaleFactor(0.8)
                .accessibilityIdentifier("home-grab-heading")
            Spacer(minLength: 8)
            #if !os(macOS)
            SearchButton { searching = true }
            #endif
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
        .frame(minHeight: Metrics.tap)
    }

    /// The Mac's title bar strip on Home: the search at its right, on the traffic lights'
    /// line (`headerOnTheMac`); nothing at all on the iPhone, where the search is in Grab
    /// and go's line.
    private var searchStrip: some View {
        HStack(spacing: 8) {
            Spacer(minLength: 0)
            SearchButton { searching = true }
        }
        .headerLine()
    }

    /// This Device: how many trips, things and templates. His marks on the Mac: the heading
    /// struck out and written down the SIDE instead, and Trips and Templates swapped over.
    /// At the foot of that side heading, the sync dot (0.92, `SyncLight` — his pick B: "put the
    /// sync dot under the This Device label"): in the same 16-point column, the block no taller.
    /// The heading is Caption 2 since 0.92 (Caption 1 until then) so the dot fits under it in the
    /// tiles' 76 points; the column wraps it up the side at its own length (`SideLabel`).
    private var thisDevice: some View {
        HStack(spacing: 10) {
            VStack(spacing: 3) {
                SideLabel(text: "This Device")
                    .accessibilityIdentifier("device-heading")
                SyncLight()
            }
            .frame(width: 16)
            CountTile(number: model.library.trips.count, label: "Trips", id: "count-trips", color: AppSection.events.color)
            CountTile(number: model.library.ownThings().count, label: "Things", id: "count-things", color: AppSection.care.color)
            // The templates Your templates shows — not the hidden bags list or the
            // web app's old bin, which made this number the higher one (5 Oct 2026).
            CountTile(number: TemplatesScreen.activityAreas(model.library.templates, model.library).reduce(0) { $0 + $1.lists.count },
                      label: "Templates", id: "count-templates", color: AppSection.templates.color)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home-device")
    }

    /// The code's Pack by voice, asked only now that Home's trip screen is up (spec 07 part
    /// 10): asked at once, the trip screen still on its way out — Home's own, or the Trips
    /// tab's when the code came in over it — took the request and lost it with itself.
    private func startVoiceAsked(on trip: String) {
        guard let v = voiceAsked else { return }
        voiceAsked = nil
        #if os(iOS)
        if v.tripId == trip, openedPlace != nil { VoiceStarts.shared.startVoiceAt(place: v.place, tripId: v.tripId) }
        #endif
    }

    /// Something asked from outside — a Shortcut, the Action button, a tapped packing
    /// reminder — while one of Home's own windows is up (Grab Lists, Search, a trip,
    /// a grab list): that one closes first, then the asked-for one opens. SwiftUI does
    /// not present a second window from a view while another is up or still closing,
    /// so until 5 Oct 2026 such a request could open nothing.
    private func whenFree(_ open: @escaping () -> Void) {
        let busy = searching || showingGrabLists || opened != nil || grab != nil || menuShown || placeShown != nil
            || thingShown != nil
        guard busy else { open(); return }
        searching = false; showingGrabLists = false; opened = nil; grab = nil; menuShown = false; placeShown = nil
        thingShown = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { open() }
    }

    /// What is still missing before a trip can be made, in his words — "" when nothing.
    ///
    /// No template ticked is fine when Always packed (or the transport kit) puts
    /// something on a Full trip — his short trip of the small core alone (0.73, his
    /// must-fix: it said "Pick at least one template."). Only a trip with nothing to
    /// pack at all is asked for one (`Library.templateMissing`).
    private func needs(_ flat: [PackList]) -> String {
        var said: [String] = []
        if jsTrim(name).isEmpty { said.append("Give the trip a name.") }
        if let missing = model.library.templateMissing(draft(flat)) { said.append(missing) }
        // Only the first day tapped: never a day trip by accident (the spec pass, 5 Oct
        // 2026 — a grid closed on its first day stored one).
        if pickingEnd { said.append("Tap the trip's last day \u{2014} the same day again for a day trip.") }
        return said.joined(separator: " ")
    }

    private func create(_ flat: [PackList]) {
        let missing = needs(flat)
        guard missing.isEmpty else {
            stillNeeded = missing
            if jsTrim(name).isEmpty { naming = true }
            return
        }
        stillNeeded = ""
        let made = draft(flat)
        var stored: TripEvent?
        model.change { stored = $0.createTrip(made) }
        name = ""; activities = []; workoutContexts = [:]; hasDates = false; quick = false; laundry = false; laundryNights = LAUNDRY_CAP_NIGHTS
        leaveOut = ""; leaveHome = ""
        travel = TripTravel(flights: [FlightLeg(), FlightLeg()])
        // The form starts over: the next trip's dates choose its season again (0.76).
        seasonByHand = false
        seasonFromDates()
        opened = stored?.id
    }

    /// Season as the dates say (`Library.seasonFor`: Winter from November to March, Summer
    /// otherwise and with no dates) — unless he has picked one himself on this form.
    private func seasonFromDates() {
        guard !seasonByHand else { return }
        season = Library.seasonFor(firstDay: hasDates ? HomeScreen.ymd(start) : "")
    }

    /// What More choices holds, in one line while it is closed: "Summer · Mix · No laundry".
    static func moreSummary(season: String, catering: String, laundry: Bool, nights: Int) -> String {
        let food = shortFood(catering, CATERING.first { $0.id == catering }?.label ?? catering)
        return [season, food, laundry ? "Laundry, \(nights) nights" : "No laundry"].joined(separator: " \u{00B7} ")
    }

    /// The trip Create makes from what the screen holds now — also what `needs` asks
    /// whether it would pack anything.
    private func draft(_ flat: [PackList]) -> TripEvent {
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
            _ = Library.setLeaveTime(&draft, leaveOut, home: false)
            _ = Library.setLeaveTime(&draft, leaveHome, home: true)
        }
        // Flights and stay: stored only while Plane is lit — what the form shows (cleaned: empty legs go).
        if Library.travelLit(transport, "Plane") { Library.setFlightsAndStay(&draft, travel) }
        return draft
    }

    static func ymd(_ d: Date) -> String {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone.current; f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }

    private struct Opened: Identifiable { let id: String }
}

/// Travelling by (0.76) — his decision of 13 Oct 2026, after he deleted his Car transport
/// template ("the car is just go and drive"; mostly by car, every weekend by RV, a plane a
/// couple of times a year). Two pills, Plane and RV, each with its drawing from the template
/// icons, both off to begin with; at most one on, and the lit one tapped goes off again. The
/// stored word is unchanged: neither = "Car" (`Library.travelling`). Under them, a quiet line
/// that names his own transport templates, read from the library (`Library.travelNote`).
/// Ids: `<id>-title`, `<id>-1` (Plane) and `<id>-2` (RV) — their places in `TRANSPORTS`, the
/// ids they had as Transport pills — and `<id>-note`.
struct TravellingBy: View {
    @Binding var transport: String
    let note: String
    let id: String
    var tint: Color = AppSection.home.color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HeadingTitle(title: "Travelling by", tint: tint, id: "\(id)-title")
            HStack(spacing: 6) {
                ForEach(Library.travelPills, id: \.self) { word in pill(word) }
            }
            Text(note)
                .font(.system(.footnote)).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("\(id)-note")
        }
    }

    private func pill(_ word: String) -> some View {
        let on = Library.travelLit(transport, word)
        let icon = TemplateIcons.icon(word == "RV" ? "rv" : "plane")?.path ?? ""
        return Button { transport = Library.travelling(transport, tapped: word) } label: {
            HStack(spacing: 5) {
                IconMark(path: icon, size: Metrics.glyph, weight: 1.8)
                    .accessibilityHidden(true)
                Text(word).font(.system(.subheadline, weight: on ? .semibold : .regular))
            }
            .foregroundStyle(on ? Color.white : Theme.ink)
            .padding(.horizontal, 12).frame(minHeight: Metrics.chip)
            .background(Capsule().fill(on ? tint : Theme.bg))
            .overlay(Capsule().stroke(on ? tint : Theme.line, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier("\(id)-\(TRANSPORTS.firstIndex(of: word) ?? 0)")
        .accessibilityValue(on ? "On" : "Off")
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// More choices (0.76, his ask of 13 Oct 2026): what is asked less often — Season, Food and
/// Laundry on Create new trip — folded under one row, with a quiet line of what is picked
/// while it is closed. The row is a button of its own (`<id>`, value "Open"/"Closed"), the line
/// a text beside it (`<id>-summary`, a tap opens too): the Mac folds a button's words into it.
struct MoreChoices<Content: View>: View {
    @Binding var open: Bool
    let summary: String
    let id: String
    var tint: Color = AppSection.home.color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                Button { open.toggle() } label: {
                    HStack(spacing: 6) {
                        SVGPath.path("M9 6l6 6-6 6")
                            .stroke(style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                            .onGrid(Metrics.glyph)
                            .rotationEffect(.degrees(open ? 90 : 0))
                            .foregroundStyle(Theme.ink)
                            .accessibilityHidden(true)
                        Text("More choices").font(.system(.subheadline, weight: .semibold)).foregroundStyle(tint)
                    }
                    .frame(minHeight: 28).contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier(id)
                .accessibilityValue(open ? "Open" : "Closed")
                if !open {
                    Text(summary)
                        .font(.system(.footnote)).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, Metrics.glyph + 6)
                        .contentShape(Rectangle())
                        .onTapGesture { open = true }
                        .accessibilityIdentifier("\(id)-summary")
                }
            }
            if open { content() }
        }
    }
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
    /// A colour of its own for some pills, by the option's id — a template's pill on Create
    /// new trip and Trip settings: the colour he chose for it (0.91), else a workout's own (his
    /// colours, 2026-09-28; `TemplateTone`). Picked: filled in it; not picked: outlined in it.
    var tones: ((String) -> PillTone?)? = nil
    /// The pill the Mac's arrows are on (a thing's On these templates, 0.68): ringed in
    /// the pills' colour, just outside it. nil = none (everywhere else).
    var cursor: Int? = nil
    /// The picked pills are an answer BORROWED from elsewhere — on a template's row, the
    /// thing's own "Only on some trips" (0.73, OnlySomeTrips.swift): drawn with a wash and
    /// an outline in the tint and the words in ink, instead of filled.
    var borrowed = false
    /// A drawing before the words of some pills, by the pill's stored word: the catalog key
    /// (the seasons, 0.78 — `HomeScreen.seasonIcon`), drawn as Travelling by draws Plane and
    /// RV. Such a pill's accessibility value is that key, so a test can see the drawing is there.
    var icons: ((String) -> String?)? = nil
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
                    let tone = tones?(o.id)
                    let lent = on && borrowed
                    let mark = icons?(o.id).flatMap { key in TemplateIcons.icon(key).map { (key: key, path: $0.path) } }
                    Button { choose(o.id) } label: {
                        HStack(spacing: 5) {
                            if let mark {
                                IconMark(path: mark.path, size: Metrics.glyph, weight: 1.8)
                                    .accessibilityHidden(true)
                            }
                            Text(o.label)
                                .font(.system(.subheadline, weight: on ? .semibold : .regular))
                        }
                        .foregroundStyle(lent ? Theme.ink : on ? (tone?.ink ?? Color.white) : Theme.ink)
                        .padding(.horizontal, 12).frame(minHeight: Metrics.chip)
                        .background(Capsule().fill(lent ? tint.opacity(0.18) : on ? (tone?.fill ?? tint) : Theme.bg))
                        .overlay(Capsule().stroke(on ? (tone?.fill ?? tint) : (tone?.fill ?? Theme.line),
                                                  lineWidth: lent ? 1.6 : tone == nil || on ? 1 : 1.8))
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .focusRing(cursor == n, tint: tint, radius: 11, gap: 2)
                    .accessibilityIdentifier("\(id)-\(startIndex + n)")
                    #if DEBUG
                    // The tests' only way to see the colour a pill is drawn in (0.91): its fill and
                    // words, "#ffd60a/#3d3000" — read from the very tone it is drawn with. None in
                    // the release build, where a pill says only its drawing's key, as before.
                    .accessibilityValue(mark?.key ?? tone.map { "\($0.fillHex)/\($0.inkHex)" } ?? "")
                    #else
                    .accessibilityValue(mark?.key ?? "")
                    #endif
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

extension View {
    /// One of Home's frames (0.91): Grab and go and Create new trip, the same card — padding 14,
    /// corner 14, `Theme.card`, a 1-pt `Theme.line` border — a container of its own named `id`,
    /// every line in it keeping its own name.
    func homeCard(id: String) -> some View {
        padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line, lineWidth: 1))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(id)
    }
}

/// Words written up the side, bottom to top (This Device, 0.92): laid out at their own length,
/// so what stands under them in the column starts where they end.
struct SideLabel: View {
    let text: String
    @State private var size = CGSize.zero

    var body: some View {
        Text(text)
            .font(.system(.caption2, weight: .semibold)).foregroundStyle(Theme.muted)
            .kerning(0.3)
            .fixedSize()
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
            .rotationEffect(.degrees(-90))
            .frame(width: size.height, height: size.width)
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
        // The tile itself, for the tests' measuring (0.92); its number keeps its own name.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("\(id)-tile")
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
    /// What Quick leaves out, naming his always-packed templates (`Library.quickNote`, 0.78).
    let note: String
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
            // As wide as the name field above it (0.91 — his words, 19 Oct 2026: "Could you also
            // please broaden the two pills "Full trip" and "Quick" so that they are in line with
            // the name field above."); until 0.91 at most 360 wide.
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("\(id)-track")
            // Field test 5.1/6.1 (3 Oct 2026): words that made Transport look switched
            // off left the trip on "Car" and the plane's cabin check never ran — so the
            // line says it still counts (0.76: Plane and RV, under Travelling by). Plain words
            // since 0.78 — he did not understand "Plane and RV still count" (13 Oct 2026) — and
            // his always-packed templates by their own names (`Library.quickNote`).
            Text(note)
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

/// A pill's own colour: its fill, and the words on it (hex, "#rrggbb").
struct PillTone {
    let fillHex: String
    let inkHex: String
    var fill: Color { Color(hexString: fillHex) }
    var ink: Color { Color(hexString: inkHex) }
}

/// A template pill's own colour on Create new trip and Trip settings (0.91 — his "Yes, show the
/// template colours on the Create new trip pills too", 19 Oct 2026): the colour he chose for the
/// template, with words that read on it (`Library.pillColour` — the cover's own fill and ink);
/// else, in the workouts' area, the workout's colour by its name (`WorkoutTone`); else none, and
/// the pill keeps the Templates violet when ticked. His choice wins over a workout's colour: it is
/// the colour the template's cover and marks already wear. Drawn as the workouts always were —
/// picked: filled in it, its words; not picked: outlined in it, ink words.
enum TemplateTone {
    static func of(_ list: PackList?, workout: Bool) -> PillTone? {
        guard let list else { return nil }
        if let c = Library.pillColour(list) { return PillTone(fillHex: c.fill, inkHex: c.ink) }
        return workout ? WorkoutTone.of(list.name) : nil
    }

    /// `Pills.tones` for one area's templates: a pill's colour by its id.
    static func byId(_ lists: [PackList], workouts: Bool) -> (String) -> PillTone? {
        { id in of(lists.first { $0.id == id }, workout: workouts) }
    }
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
        pair(name).map { PillTone(fillHex: String(format: "#%06x", $0.fill), inkHex: String(format: "#%06x", $0.ink)) }
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
    /// `fill`: its pill's colour (`TemplateTone` — his colour for it, else the workout's), nil = none.
    struct Workout: Identifiable { let id: String; let name: String; let index: Int; var fill: String? = nil }
    let workouts: [Workout]
    let selected: [String: Set<String>]
    let id: String
    let choose: (_ workout: String, _ context: String) -> Void
    @Environment(\.colorScheme) private var scheme

    /// The ticked templates of one group (the WET one), in the order offered, each with
    /// its place among ALL the template pills — the number its pill carries.
    static func ticked(_ lists: [PackList], _ ticked: Set<String>, _ flat: [PackList]) -> [Workout] {
        lists.filter { ticked.contains($0.id) }.map { l in
            Workout(id: l.id, name: l.name, index: flat.firstIndex { $0.id == l.id } ?? 0,
                    fill: TemplateTone.of(l, workout: true)?.fillHex)
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
                    // Its name in its pill's colour, as WORDS on the card: the hue darkened on a light
                    // screen or lightened on a dark one until it reads (`readableHex`; Bike's bright
                    // yellow is unreadable on white as it is) — his own colour for it since 0.91.
                    let words = w.fill.map { readableHex($0, dark: scheme == .dark) }
                    HStack(alignment: .center, spacing: 8) {
                        Text(w.name)
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(words.map { Color(hexString: $0) } ?? Theme.ink)
                            .lineLimit(2).minimumScaleFactor(0.8)
                            .frame(width: Metrics.contextName, alignment: .leading)
                            .accessibilityIdentifier("\(id)-\(w.index)-name")
                            #if DEBUG && os(iOS)
                            // The colour its name is written in, for the tests (0.91). Not on the Mac,
                            // which reports a text's words as its value.
                            .accessibilityValue(words ?? "")
                            #endif
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
