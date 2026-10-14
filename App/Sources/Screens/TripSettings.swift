import SwiftUI
import PackingCore
import PackingLibrary

/// A trip's settings, changed after it is made — the gap list's first High item
/// (2026-09-27). The same choices as Create new trip; Save rebuilds the list the
/// web app's way: ticked and hand-added lines stay, new matches arrive, lines no
/// longer asked for go.
struct TripSettingsScreen: View {
    let tripId: String
    /// What the rebuild did, for the trip to say.
    var rebuilt: (Library.TripRebuilt) -> Void = { _ in }
    /// A new trip was started from this one (the web app's "same list, fresh ticks").
    var startedAgain: (TripEvent) -> Void = { _ in }
    /// Every tick was cleared (0.79): what changed, for the trip's Undo.
    var cleared: (TicksChanged) -> Void = { _ in }
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    @State private var loaded = false
    @State private var name = ""
    @State private var hasDates = false
    @State private var start = Date()
    @State private var end = Date()
    @State private var quick = false
    /// Where the trip goes — his test G.6: "the place is not shown in the edit view".
    @State private var place = ""
    @State private var laundry = false
    @State private var laundryNights = LAUNDRY_CAP_NIGHTS
    /// "I leave at" (0.69, the door check): on the first day, and on the last for home.
    @State private var leaveOut = ""
    @State private var leaveHome = ""
    /// Flights and stay (0.80, spec 07 part 18 B): the trip's own, padded to Out and Home.
    @State private var travel = TripTravel()
    @State private var activities: Set<String> = []
    /// Indoor / Outdoor / Race PER WORKOUT (0.67): template id → its contexts. A trip
    /// made before 0.67 opens with each workout showing the trip-wide ones — what its
    /// list was built with — so a Save without a change rebuilds the same list.
    @State private var workoutContexts: [String: Set<String>] = [:]
    /// The trip's own per-workout entries when the screen opened: kept on Save for the
    /// templates this screen does not show (`unshown`).
    @State private var storedContexts: [String: [String]] = [:]
    @State private var transport = "Car"
    @State private var season = "Summer"
    @State private var catering = "mixed"
    /// Weather gear packed whatever the forecast says (the trip's `weatherOn`) — the
    /// web app's "pack anyway". The spec pass (5 Oct 2026): no screen here showed it,
    /// so a trip that carried it (a backup, the web app, Start again) could not be seen
    /// or changed.
    @State private var weatherOn: Set<String> = []
    /// The trip's templates that this screen does not offer — one deleted since, or a
    /// trip someone sent naming THEIR templates. Kept on Save, never dropped unseen
    /// (the spec pass, 5 Oct 2026).
    @State private var unshown: [String] = []
    /// What the screen held when it opened: a swipe down must not throw changes away
    /// without a word (the spec pass, 5 Oct 2026), so it only closes the sheet while
    /// nothing has changed. Cancel always closes.
    @State private var opened: [String] = []
    @State private var stillNeeded = ""
    /// The new trip's name while Start a new trip is open; nil when closed.
    @State private var againName: String?
    @State private var againNeeds = ""

    var body: some View {
        let choices = model.library.activityChoices()
        let flat = choices.flatMap(\.lists)
        let anyWorkout = flat.contains { $0.group == "WET" && activities.contains($0.id) }
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(HeaderButtonStyle(tint: Theme.muted, filled: false)).focusEffectDisabled()
                    .font(.system(.body, weight: .semibold)).foregroundStyle(Theme.muted)
                    .keyboardShortcut(.cancelAction)            // Escape = Cancel (the spec pass, 5 Oct 2026)
                    .accessibilityIdentifier("tripset-cancel")
                Spacer()
                Text("Trip settings").font(.system(.title3, weight: .bold)).foregroundStyle(Theme.ink)
                Spacer()
                Color.clear.frame(width: 56, height: 1)
            }
            .padding(16)
            KeyboardAwayScroll {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Name your trip", text: $name)
                        .textFieldStyle(.plain)
                        .font(.system(.title3, weight: .semibold)).foregroundStyle(Theme.ink)
                        .padding(.horizontal, 12).frame(minHeight: Metrics.tap)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                        .accessibilityIdentifier("tripset-name")
                    // Full trip | Quick under the name, as on Create new trip (0.67).
                    TripKindChoice(quick: $quick, note: model.library.quickNote(), id: "tripset-kind", tint: AppSection.events.color)
                    // A heading like the pills' headings below (field test, 3 Oct 2026).
                    VStack(alignment: .leading, spacing: 6) {
                        HeadingTitle(title: "Place", tint: AppSection.events.color, id: "tripset-heading-place")
                        TextField("Where the trip goes, e.g. Kalmar", text: $place)
                            .textFieldStyle(.plain)
                            .font(.system(.body)).foregroundStyle(Theme.ink)
                            .padding(.horizontal, 12).frame(minHeight: Metrics.tap)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                            .accessibilityIdentifier("tripset-place")
                    }
                    // Always there, as on Create new trip (0.67). The Dates switch was also the
                    // only way to take a trip's dates away: that is Clear dates in the grid now.
                    DateRangePicker(start: $start, end: $end, dated: $hasDates, tint: AppSection.events.color, id: "tripset-dates")
                    // The door check (0.69): a time on a day needs the days.
                    if hasDates {
                        LeaveTimes(out: $leaveOut, home: $leaveHome, id: "tripset-leave", tint: AppSection.events.color)
                    }
                    ForEach(choices, id: \.group.id) { choice in
                        Pills(title: groupHeading(choice.group.id, choice.group.label),
                              options: choice.lists.map { ($0.id, $0.name) },
                              selected: activities, id: "tripset-activity", tint: AppSection.templates.color,
                              startIndex: flat.firstIndex { $0.id == choice.lists[0].id } ?? 0,
                              tones: choice.group.id == "WET" ? WorkoutTone.of : nil) { id in
                            if activities.contains(id) { activities.remove(id) } else { activities.insert(id) }
                            if !stillNeeded.isEmpty { stillNeeded = needs(flat) }
                        }
                        if choice.group.id == "WET" && anyWorkout {
                            WorkoutContexts(workouts: WorkoutContexts.ticked(choice.lists, activities, flat),
                                            selected: workoutContexts, id: "tripset-context") { workout, context in
                                workoutContexts[workout, default: []].formSymmetricDifference([context])
                            }
                        }
                    }
                    // Travelling by (0.76), as on Create new trip: a trip by "Car" — every ordinary
                    // trip, old ones too — shows both off and keeps its word unless a pill is tapped.
                    // Season does NOT follow the dates here: a made trip's season changes only by hand.
                    TravellingBy(transport: $transport, note: model.library.travelNote(quick: quick), id: "tripset-transport")
                    // Flights and stay (0.80): only while Plane is lit; Plane off keeps what is stored, unseen.
                    if Library.travelLit(transport, "Plane") {
                        FlightsAndStay(travel: $travel,
                                       firstDay: hasDates ? HomeScreen.ymd(start) : "",
                                       lastDay: hasDates ? HomeScreen.ymd(max(start, end)) : "",
                                       place: place, id: "tripset-flights", tint: AppSection.events.color, fill: Theme.card)
                    }
                    Pills(title: "Season", options: SEASONS.map { ($0, $0) }, selected: [season], id: "tripset-season",
                          icons: HomeScreen.seasonIcon) { season = $0 }
                    // Rain gear on a dry forecast, or long before any forecast exists: his
                    // own gear tagged for these comes onto the list, whatever the weather.
                    Pills(title: "Pack weather gear anyway", options: WEATHER_CONDITIONS.map { ($0.id, $0.label) },
                          selected: weatherOn, id: "tripset-weather") { id in
                        if weatherOn.contains(id) { weatherOn.remove(id) } else { weatherOn.insert(id) }
                    }
                    Pills(title: "Food", options: CATERING.map { ($0.id, HomeScreen.shortFood($0.id, $0.label)) },
                          selected: [catering], id: "tripset-catering") { catering = $0 }
                    LaundrySwitch(on: $laundry, nights: $laundryNights, id: "tripset-laundry")

                    Text("Save rebuilds the list: what you ticked, added yourself or were sent stays; new things arrive; things no longer asked for go.")
                        .font(.system(.footnote)).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    Rectangle().fill(Theme.line).frame(height: 1).padding(.vertical, 8)
                    startAgain
                    // Clear every tick (0.79, his decision of 13 Oct 2026): moved here from the foot
                    // of the trip, where it could be pressed by mistake half way through packing — a
                    // quiet row, last, only while something is ticked. It asks first; done, Trip
                    // settings closes and the trip offers Undo.
                    ClearTicksRow(tripId: tripId, unsaved: loaded && snapshot() != opened) { change in
                        cleared(change)
                        dismiss()
                    }
                    .environmentObject(model)
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
            // Save stays in sight at the bottom, above the keyboard — never scrolled
            // away at the end of a long sheet (the cloud test lost it, 2026-09-27).
            // Always ready, always in colour (his rule for a main button, 2026-09-26).
            VStack(spacing: 8) {
                if !stillNeeded.isEmpty {
                    Text(stillNeeded)
                        .font(.system(.subheadline, weight: .semibold)).foregroundStyle(AppSection.actions.color)
                        .multilineTextAlignment(.center)                // two sentences wrap (0.73): still centred
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("tripset-needs")
                }
                Button { save(flat) } label: {
                    Text("Save changes")
                        .font(.system(.body, weight: .semibold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: Metrics.row)
                        .background(RoundedRectangle(cornerRadius: 12).fill(AppSection.events.color))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("tripset-save")
            }
            .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 12)
            .background(Theme.bg)
            .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
        }
        .background(Theme.bg.ignoresSafeArea())
        .onAppear(perform: load)
        // Full trip | Quick, and the answers that rule things in or out, decide whether
        // Always packed alone has something to pack (0.73): the line follows them.
        .onChange(of: [quick ? "quick" : "trip", transport, season, catering, weatherOn.sorted().joined(separator: ",")]) { _, _ in
            if !stillNeeded.isEmpty { stillNeeded = needs(flat) }
        }
        .interactiveDismissDisabled(loaded && snapshot() != opened)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("tripset-screen")
        #if os(macOS)
        .frame(minWidth: 540, minHeight: 600)
        #endif
    }

    /// "Start a new trip from this one — same list, fresh ticks" (the web app's trip
    /// menu): the list as it ended up; no dates, ticks or review.
    @ViewBuilder private var startAgain: some View {
        if let draft = againName {
            VStack(alignment: .leading, spacing: 10) {
                Text("Name the new trip").font(.system(.callout, weight: .semibold)).foregroundStyle(Theme.ink)
                TextField("Name the new trip", text: Binding(get: { draft }, set: { againName = $0 }))
                    .textFieldStyle(.plain)
                    .font(.system(.body, weight: .semibold)).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 12).frame(minHeight: Metrics.tap)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.bg))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                    .onSubmit { startIt(againName ?? "") }
                    .accessibilityIdentifier("tripset-again-name")
                Text("The same list as this trip, nothing ticked, no dates.")
                    .font(.system(.footnote)).foregroundStyle(Theme.muted)
                HStack(spacing: 10) {
                    Button("Not now") { againName = nil; againNeeds = "" }
                        .buttonStyle(.plain).focusEffectDisabled()
                        .font(.system(.callout, weight: .semibold)).foregroundStyle(Theme.ink)
                        .accessibilityIdentifier("tripset-again-no")
                    Spacer()
                    // Always ready, always in colour; a missing name is said under it.
                    Button { startIt(draft) } label: {
                        Text("Start it")
                            .font(.system(.callout, weight: .semibold)).foregroundStyle(.white)
                            .padding(.horizontal, 18).frame(minHeight: 42)
                            .background(Capsule().fill(AppSection.events.color))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("tripset-again-yes")
                }
                if !againNeeds.isEmpty {
                    Text(againNeeds)
                        .font(.system(.subheadline, weight: .semibold)).foregroundStyle(AppSection.actions.color)
                        .accessibilityIdentifier("tripset-again-needs")
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppSection.events.color, lineWidth: 1))
        } else {
            Button {
                let saved = model.library.trips.first { $0.id == tripId }?.name ?? ""
                againName = Library.againName(saved)
            } label: {
                VStack(spacing: 2) {
                    Text("Start a new trip from this one")
                        .font(.system(.body, weight: .semibold)).foregroundStyle(AppSection.events.color)
                    Text("Same list, nothing ticked")
                        .font(.system(.footnote)).foregroundStyle(Theme.muted)
                }
                .frame(maxWidth: .infinity, minHeight: 56)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppSection.events.color, lineWidth: 1.4))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain).focusEffectDisabled()
            .accessibilityIdentifier("tripset-again")
        }
    }

    private func startIt(_ draft: String) {
        guard !jsTrim(draft).isEmpty else { againNeeds = "Give the new trip a name."; return }
        var made: TripEvent?
        let from = tripId
        model.change { lib in made = lib.startAgain(from: from, name: draft) }
        if let made { startedAgain(made) }
        dismiss()
    }

    private func load() {
        guard !loaded, let t = model.library.trips.first(where: { $0.id == tripId }) else { return }
        loaded = true
        name = t.name
        place = t.destination
        hasDates = !t.startDate.isEmpty
        start = DateRangePicker.date(t.startDate) ?? Date()
        end = DateRangePicker.date(t.endDate.isEmpty ? t.startDate : t.endDate) ?? start
        quick = t.mode == "quick"
        laundry = t.laundry
        laundryNights = PackingCore.laundryNights(t)
        leaveOut = Library.leaveTime(t, home: false)
        leaveHome = Library.leaveTime(t, home: true)
        var flights = Library.travel(t)
        flights.flights = flights.legsForEditing
        travel = flights
        activities = Set(t.activities)
        storedContexts = t.activityContexts
        // What each workout's things are narrowed by now (`contextsFor`): its own entry,
        // else the trip-wide contexts.
        workoutContexts = Dictionary(t.activities.map { ($0, Set(t.activityContexts[$0] ?? t.contexts)) },
                                     uniquingKeysWith: { first, _ in first })
        transport = t.transport.isEmpty ? "Car" : t.transport
        season = t.season.isEmpty ? "Summer" : t.season
        catering = t.catering.isEmpty ? "mixed" : t.catering
        weatherOn = Set(t.weatherOn)
        let offered = Set(model.library.activityChoices().flatMap(\.lists).map(\.id))
        unshown = t.activities.filter { !offered.contains($0) }
        opened = snapshot()
    }

    /// Everything the screen can change, in one comparable piece.
    private func snapshot() -> [String] {
        [name, place, "\(hasDates)", HomeScreen.ymd(start), HomeScreen.ymd(end), "\(quick)", "\(laundry)",
         "\(laundryNights)", activities.sorted().joined(separator: ","),
         activities.sorted().map { "\($0):\(workoutContexts[$0, default: []].sorted().joined(separator: "+"))" }.joined(separator: ","),
         transport, season, catering, weatherOn.sorted().joined(separator: ","), leaveOut, leaveHome,
         String(describing: travel)]
    }

    /// What is still missing before Save, in the words of Create new trip — "" when
    /// nothing. No template ticked is fine when Always packed (or the transport kit)
    /// puts something on the trip as it would be saved (0.73, `Library.templateMissing`).
    private func needs(_ flat: [PackList]) -> String {
        var said: [String] = []
        if jsTrim(name).isEmpty { said.append("Give the trip a name.") }
        if var trip = model.library.trips.first(where: { $0.id == tripId }) {
            edited(&trip, flat)
            if let missing = model.library.templateMissing(trip) { said.append(missing) }
        }
        return said.joined(separator: " ")
    }

    private func save(_ flat: [PackList]) {
        stillNeeded = needs(flat)
        guard stillNeeded.isEmpty else { return }
        var result: Library.TripRebuilt?
        model.change { lib in result = lib.changeTrip(id: tripId) { edited(&$0, flat) } }
        if let result { rebuilt(result) }
        dismiss()
    }

    /// The screen's answers written onto the trip: what Save stores, and what `needs`
    /// asks first whether it would pack anything.
    private func edited(_ t: inout TripEvent, _ flat: [PackList]) {
        // The ticked ones in the order offered — then the trip's templates this screen
        // does not show, as they were (see `unshown`).
        let acts = flat.map(\.id).filter { activities.contains($0) } + unshown.filter { activities.contains($0) }
        // Each ticked workout its own; a template not shown here keeps its entry as it was.
        var perWorkout = WorkoutContexts.stored(acts, flat, workoutContexts)
        for id in unshown where activities.contains(id) { if let kept = storedContexts[id] { perWorkout[id] = kept } }
        let pl = jsTrim(place)
        t.name = name
        // A NEW place: the old weather and map point were for somewhere else,
        // so they go; the weather line looks the new place up.
        if pl != jsTrim(t.destination) { t.destination = pl; t.weather = nil; t.geo = nil }
        t.mode = quick ? "quick" : "trip"
        t.activities = acts
        t.activityContexts = perWorkout
        t.contexts = WorkoutContexts.union(perWorkout)
        t.transport = transport
        t.season = season
        t.catering = catering
        t.weatherOn = WEATHER_CONDITION_IDS.filter { weatherOn.contains($0) }
        t.laundry = laundry
        t.extra[LAUNDRY_NIGHTS_KEY] = .number(Double(laundryNights))
        t.startDate = hasDates ? HomeScreen.ymd(start) : ""
        t.endDate = hasDates ? HomeScreen.ymd(max(start, end)) : ""
        _ = Library.setLeaveTime(&t, leaveOut, home: false)
        _ = Library.setLeaveTime(&t, leaveHome, home: true)
        // Flights and stay (0.80), after the dates (a leg without a day takes the trip's): only while
        // Plane is lit — saved with Plane off, what was stored stays. Bag-tag numbers are not touched.
        if Library.travelLit(transport, "Plane") { Library.setFlightsAndStay(&t, travel) }
    }
}

/// The pen on a trip: opens its settings, and owns its sheet (the trip already
/// has one for the review).
struct TripSettingsDoor: View {
    let tripId: String
    var rebuilt: (Library.TripRebuilt) -> Void
    var startedAgain: (TripEvent) -> Void = { _ in }
    var cleared: (TicksChanged) -> Void = { _ in }
    @EnvironmentObject var model: LibraryModel
    @State private var open = false

    var body: some View {
        Button { open = true } label: {
            // A pen, not a gear (his tests C.3 and D.1): this CHANGES the trip. In a ring
            // since 0.73 (12 Oct 2026: the bare pen did not read as a button).
            RoundIconLabel(tint: AppSection.events.color) { PenMark() }
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier("trip-settings")
        .accessibilityLabel("Trip settings")
        .sheet(isPresented: $open) {
            TripSettingsScreen(tripId: tripId, rebuilt: rebuilt, startedAgain: startedAgain, cleared: cleared)
                .environmentObject(model)
        }
    }
}
