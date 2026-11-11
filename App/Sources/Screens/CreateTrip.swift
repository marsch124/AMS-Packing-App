import SwiftUI
import PackingCore
import PackingLibrary

/// Create new trip, as its own page (0.110, the redesign "B" — his pick, 11 Nov 2026): Home shows
/// one full-colour "＋ New trip" button, and this page holds what was Home's open form until 0.109 —
/// the name, Full trip | Quick, the calendar, the templates, Travelling by and More choices. Cancel
/// top left (Escape on the Mac), Create top right and at the foot, in full colour — as Trip settings.
/// A made trip closes the page and opens on Home (`created`).
struct CreateTripPage: View {
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    /// The made trip's id, handed to Home, which opens it once this page has gone.
    let created: (String) -> Void

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
    /// Season follows the dates (0.76, `Library.seasonFor`) until he taps a Season pill.
    @State private var seasonByHand = false
    /// More choices (0.76): Season, Food and Laundry folded away — remembered on this device.
    @AppStorage(HomeScreen.moreKey) private var moreOpen = false
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
    /// Flights and stay (0.80): only on a plane trip; Out and Home to begin with.
    @State private var travel = TripTravel(flights: [FlightLeg(), FlightLeg()])
    /// What Create said was missing, after a press with something missing.
    @State private var stillNeeded = ""
    @FocusState private var naming: Bool

    /// Something typed or picked: a swipe down asks first (spec 06 §20a).
    private var touched: Bool {
        !jsTrim(name).isEmpty || !activities.isEmpty || hasDates || quick || transport != Library.ordinaryTransport
    }

    var body: some View {
        let choices = model.library.activityChoices()
        let flat = choices.flatMap(\.lists)
        let anyWorkout = flat.contains { $0.group == "WET" && activities.contains($0.id) }
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(BarCancelStyle(tint: AppSection.home.color)).focusEffectDisabled()
                    .font(.system(.body, weight: .semibold))
                    .keyboardShortcut(.cancelAction)            // Escape = Cancel
                    .accessibilityIdentifier("trip-create-cancel")
                Spacer()
                Text("New trip").font(.system(.title3, weight: .bold)).foregroundStyle(Theme.ink)
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .accessibilityIdentifier("home-create-heading")
                Spacer()
                Button("Create") { create(flat) }
                    .buttonStyle(HeaderButtonStyle(tint: AppSection.home.color, filled: true)).focusEffectDisabled()
                    .keyboardShortcut("s", modifiers: .command)  // ⌘S = Create (0.103)
                    .accessibilityIdentifier("trip-create-top")
            }
            .padding(16)
            KeyboardAwayScroll {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Name your trip", text: $name)
                        .textFieldStyle(.plain)
                        .font(.system(.title3, weight: .semibold)).foregroundStyle(Theme.ink)
                        .padding(.horizontal, 12).frame(minHeight: Metrics.tap)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(stillNeeded.contains("name") ? AppSection.actions.color : Theme.line,
                                    lineWidth: stillNeeded.contains("name") ? 2 : 1))
                        .focused($naming)
                        .onChange(of: name) { _, _ in if !stillNeeded.isEmpty { stillNeeded = needs(flat) } }
                        .accessibilityIdentifier("trip-name")

                    // What KIND of trip, first, under the name (his ask, 6 Oct 2026).
                    TripKindChoice(quick: $quick, note: model.library.quickNote(), id: "trip-kind")
                    // The month grid itself, always open (0.67). First day, then last day.
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
                        Pills(title: Library.areaWords(ActivityArea(id: choice.group.id, name: choice.group.label)),
                              options: choice.lists.map { ($0.id, $0.name) },
                              selected: activities, id: "trip-activity", tint: AppSection.templates.color,
                              startIndex: flat.firstIndex { $0.id == choice.lists[0].id } ?? 0,
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
                    // His decision (13 Oct 2026): Plane or RV, both off for an ordinary trip (stored "Car").
                    TravellingBy(transport: $transport, note: model.library.travelNote(quick: quick), id: "trip-transport")
                    // The lost-luggage information (0.80): on a plane trip only, under the Plane pill.
                    if Library.travelLit(transport, "Plane") {
                        FlightsAndStay(travel: $travel,
                                       firstDay: hasDates ? HomeScreen.ymd(start) : "",
                                       lastDay: hasDates ? HomeScreen.ymd(max(start, end)) : "",
                                       place: "", id: "trip-flights", tint: AppSection.home.color, fill: Theme.card)
                    }
                    // Season, Food and Laundry fold away, said in one line (his ask, 13 Oct 2026).
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
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
            // Create stays in sight at the foot, above the keyboard — always in full colour (his rule
            // for the main button, 26 Sep 2026); a press with something missing says what, above it.
            VStack(spacing: 8) {
                if !stillNeeded.isEmpty {
                    Text(stillNeeded)
                        .font(.system(.subheadline, weight: .semibold)).foregroundStyle(AppSection.actions.color)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("trip-create-needs")
                }
                Button { create(flat) } label: {
                    Text("Create trip")
                        .font(.system(.body, weight: .semibold)).foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity, minHeight: Metrics.row)
                        .background(RoundedRectangle(cornerRadius: 12).fill(AppSection.home.color))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("trip-create")
            }
            .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 12)
            .background(Theme.bg)
            .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
        }
        .background(Theme.bg.ignoresSafeArea())
        // Full trip | Quick, and the answers that rule things in or out, decide whether Always
        // packed alone has something to pack (0.73): the line follows.
        .onChange(of: [quick ? "quick" : "trip", transport, season, catering]) { _, _ in
            if !stillNeeded.isEmpty { stillNeeded = needs(flat) }
        }
        // Season from the trip's first day (0.76) — until he picks a season himself.
        .onChange(of: hasDates) { _, _ in seasonFromDates() }
        .onChange(of: start) { _, _ in seasonFromDates() }
        .onAppear { seasonFromDates() }
        .asksBeforeDiscarding(touched) { dismiss() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screen-new-trip")
        #if os(macOS)
        .frame(minWidth: 540, minHeight: 600)
        #endif
    }

    /// What is still missing before a trip can be made, in his words — "" when nothing.
    /// No template ticked is fine when Always packed puts something on the trip (0.73).
    private func needs(_ flat: [PackList]) -> String {
        var said: [String] = []
        if jsTrim(name).isEmpty { said.append("Give the trip a name.") }
        if let missing = model.library.templateMissing(draft(flat)) { said.append(missing) }
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
        dismiss()
        if let id = stored?.id { created(id) }
    }

    private func seasonFromDates() {
        guard !seasonByHand else { return }
        season = Library.seasonFor(firstDay: hasDates ? HomeScreen.ymd(start) : "")
    }

    /// The trip Create makes from what the page holds now — also what `needs` asks
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
        if Library.travelLit(transport, "Plane") { Library.setFlightsAndStay(&draft, travel) }
        return draft
    }
}
