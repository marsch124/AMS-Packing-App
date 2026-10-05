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
    @State private var activities: Set<String> = []
    @State private var contexts: Set<String> = []
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
                    HStack(spacing: 12) {
                        Toggle(isOn: $hasDates) {
                            Text("Dates").font(.system(.callout, weight: .semibold)).foregroundStyle(Theme.ink)
                        }
                        .fixedSize()
                        .accessibilityIdentifier("tripset-dates")
                        Spacer(minLength: 8)
                        Toggle(isOn: $quick) {
                            Text("Quick").font(.system(.callout, weight: .semibold)).foregroundStyle(Theme.ink)
                        }
                        .fixedSize()
                        .accessibilityIdentifier("tripset-quick")
                    }
                    if quick { QuickNote(id: "tripset-quick-note") }
                    if hasDates { DateRangePicker(start: $start, end: $end, tint: AppSection.events.color, open: false) }
                    ForEach(choices, id: \.group.id) { choice in
                        Pills(title: groupHeading(choice.group.id, choice.group.label),
                              options: choice.lists.map { ($0.id, $0.name) },
                              selected: activities, id: "tripset-activity", tint: AppSection.templates.color,
                              startIndex: flat.firstIndex { $0.id == choice.lists[0].id } ?? 0,
                              tones: choice.group.id == "WET" ? WorkoutTone.of : nil) { id in
                            if activities.contains(id) { activities.remove(id) } else { activities.insert(id) }
                            if !stillNeeded.isEmpty { stillNeeded = needs() }
                        }
                        if choice.group.id == "WET" && anyWorkout {
                            ContextPills(selected: contexts, id: "tripset-context") { id in
                                if contexts.contains(id) { contexts.remove(id) } else { contexts.insert(id) }
                            }
                        }
                    }
                    Pills(title: "Transport", options: TRANSPORTS.map { ($0, $0) }, selected: [transport], id: "tripset-transport") { transport = $0 }
                    Pills(title: "Season", options: SEASONS.map { ($0, $0) }, selected: [season], id: "tripset-season") { season = $0 }
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
        activities = Set(t.activities)
        contexts = Set(t.contexts)
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
         "\(laundryNights)", activities.sorted().joined(separator: ","), contexts.sorted().joined(separator: ","),
         transport, season, catering, weatherOn.sorted().joined(separator: ",")]
    }

    private func needs() -> String {
        let noName = jsTrim(name).isEmpty, noList = activities.isEmpty
        if noName && noList { return "Give the trip a name and pick at least one template." }
        if noName { return "Give the trip a name." }
        if noList { return "Pick at least one template." }
        return ""
    }

    private func save(_ flat: [PackList]) {
        stillNeeded = needs()
        guard stillNeeded.isEmpty else { return }
        let n = name, dated = hasDates, s = start, e = end, q = quick
        // The ticked ones in the order offered — then the trip's templates this screen
        // does not show, as they were (see `unshown`).
        let acts = flat.map(\.id).filter { activities.contains($0) } + unshown.filter { activities.contains($0) }
        let ctx = CONTEXTS.filter { contexts.contains($0) }
        let wx = WEATHER_CONDITION_IDS.filter { weatherOn.contains($0) }
        let tr = transport, se = season, ca = catering, la = laundry, pl = jsTrim(place), ln = laundryNights
        var result: Library.TripRebuilt?
        model.change { lib in
            result = lib.changeTrip(id: tripId) { t in
                t.name = n
                // A NEW place: the old weather and map point were for somewhere else,
                // so they go; the weather line looks the new place up.
                if pl != jsTrim(t.destination) { t.destination = pl; t.weather = nil; t.geo = nil }
                t.mode = q ? "quick" : "trip"
                t.activities = acts
                t.contexts = ctx
                t.transport = tr
                t.season = se
                t.catering = ca
                t.weatherOn = wx
                t.laundry = la
                t.extra[LAUNDRY_NIGHTS_KEY] = .number(Double(ln))
                t.startDate = dated ? HomeScreen.ymd(s) : ""
                t.endDate = dated ? HomeScreen.ymd(max(s, e)) : ""
            }
        }
        if let result { rebuilt(result) }
        dismiss()
    }
}

/// The pen on a trip: opens its settings, and owns its sheet (the trip already
/// has one for the review).
struct TripSettingsDoor: View {
    let tripId: String
    var rebuilt: (Library.TripRebuilt) -> Void
    var startedAgain: (TripEvent) -> Void = { _ in }
    @EnvironmentObject var model: LibraryModel
    @State private var open = false

    var body: some View {
        Button { open = true } label: {
            // A pen, not a gear (his tests C.3 and D.1): this CHANGES the trip.
            PenMark().frame(width: 24, height: 24)
                .foregroundStyle(AppSection.events.color)
                .frame(width: 36, height: 34).contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier("trip-settings")
        .accessibilityLabel("Trip settings")
        .sheet(isPresented: $open) {
            TripSettingsScreen(tripId: tripId, rebuilt: rebuilt, startedAgain: startedAgain).environmentObject(model)
        }
    }
}
