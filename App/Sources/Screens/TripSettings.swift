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
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    @State private var loaded = false
    @State private var name = ""
    @State private var hasDates = false
    @State private var start = Date()
    @State private var end = Date()
    @State private var quick = false
    @State private var activities: Set<String> = []
    @State private var contexts: Set<String> = []
    @State private var transport = "Car"
    @State private var season = "Summer"
    @State private var catering = "mixed"
    @State private var stillNeeded = ""

    var body: some View {
        let choices = model.library.activityChoices()
        let flat = choices.flatMap(\.lists)
        let anyWorkout = flat.contains { $0.group == "WET" && activities.contains($0.id) }
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.muted)
                    .accessibilityIdentifier("tripset-cancel")
                Spacer()
                Text("Trip settings").font(.system(size: 17, weight: .heavy)).foregroundStyle(Theme.ink)
                Spacer()
                Color.clear.frame(width: 56, height: 1)
            }
            .padding(16)
            KeyboardAwayScroll {
                VStack(alignment: .leading, spacing: 14) {
                    TextField("Name your trip", text: $name)
                        .textFieldStyle(.plain)
                        .font(.system(size: 20, weight: .semibold)).foregroundStyle(Theme.ink)
                        .padding(.horizontal, 12).frame(minHeight: 48)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                        .accessibilityIdentifier("tripset-name")
                    HStack(spacing: 12) {
                        Toggle(isOn: $hasDates) {
                            Text("Dates").font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.ink)
                        }
                        .fixedSize()
                        .accessibilityIdentifier("tripset-dates")
                        Spacer(minLength: 8)
                        Toggle(isOn: $quick) {
                            Text("Quick").font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.ink)
                        }
                        .fixedSize()
                        .accessibilityIdentifier("tripset-quick")
                    }
                    if hasDates { DateRangePicker(start: $start, end: $end, tint: AppSection.events.color, open: false) }
                    ForEach(choices, id: \.group.id) { choice in
                        Pills(title: groupHeading(choice.group.id, choice.group.label),
                              options: choice.lists.map { ($0.id, $0.name) },
                              selected: activities, id: "tripset-activity", tint: AppSection.templates.color,
                              startIndex: flat.firstIndex { $0.id == choice.lists[0].id } ?? 0) { id in
                            if activities.contains(id) { activities.remove(id) } else { activities.insert(id) }
                            if !stillNeeded.isEmpty { stillNeeded = needs() }
                        }
                    }
                    if anyWorkout {
                        Pills(title: "Context", options: CONTEXTS.map { ($0, $0) }, selected: contexts, id: "tripset-context") { id in
                            if contexts.contains(id) { contexts.remove(id) } else { contexts.insert(id) }
                        }
                    }
                    Pills(title: "Transport", options: TRANSPORTS.map { ($0, $0) }, selected: [transport], id: "tripset-transport") { transport = $0 }
                    Pills(title: "Season", options: SEASONS.map { ($0, $0) }, selected: [season], id: "tripset-season") { season = $0 }
                    Pills(title: "Food", options: CATERING.map { ($0.id, HomeScreen.shortFood($0.id, $0.label)) },
                          selected: [catering], id: "tripset-catering") { catering = $0 }

                    Text("Save rebuilds the list: what you ticked or added yourself stays; new things arrive; things no longer asked for go.")
                        .font(.system(size: 14)).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    // Always ready, always in colour (his rule for a main button, 2026-09-26).
                    Button { save(flat) } label: {
                        Text("Save changes")
                            .font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(RoundedRectangle(cornerRadius: 12).fill(AppSection.events.color))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("tripset-save")
                    if !stillNeeded.isEmpty {
                        Text(stillNeeded)
                            .font(.system(size: 15, weight: .bold)).foregroundStyle(AppSection.actions.color)
                            .frame(maxWidth: .infinity)
                            .accessibilityIdentifier("tripset-needs")
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .onAppear(perform: load)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("tripset-screen")
        #if os(macOS)
        .frame(minWidth: 540, minHeight: 600)
        #endif
    }

    private func load() {
        guard !loaded, let t = model.library.trips.first(where: { $0.id == tripId }) else { return }
        loaded = true
        name = t.name
        hasDates = !t.startDate.isEmpty
        start = DateRangePicker.date(t.startDate) ?? Date()
        end = DateRangePicker.date(t.endDate.isEmpty ? t.startDate : t.endDate) ?? start
        quick = t.mode == "quick"
        activities = Set(t.activities)
        contexts = Set(t.contexts)
        transport = t.transport.isEmpty ? "Car" : t.transport
        season = t.season.isEmpty ? "Summer" : t.season
        catering = t.catering.isEmpty ? "mixed" : t.catering
    }

    private func needs() -> String {
        let noName = jsTrim(name).isEmpty, noList = activities.isEmpty
        if noName && noList { return "Give the trip a name and pick at least one list." }
        if noName { return "Give the trip a name." }
        if noList { return "Pick at least one list." }
        return ""
    }

    private func save(_ flat: [PackList]) {
        stillNeeded = needs()
        guard stillNeeded.isEmpty else { return }
        let n = name, dated = hasDates, s = start, e = end, q = quick
        let acts = flat.map(\.id).filter { activities.contains($0) }
        let ctx = CONTEXTS.filter { contexts.contains($0) }
        let tr = transport, se = season, ca = catering
        var result: Library.TripRebuilt?
        model.change { lib in
            result = lib.changeTrip(id: tripId) { t in
                t.name = n
                t.mode = q ? "quick" : "trip"
                t.activities = acts
                t.contexts = ctx
                t.transport = tr
                t.season = se
                t.catering = ca
                t.startDate = dated ? HomeScreen.ymd(s) : ""
                t.endDate = dated ? HomeScreen.ymd(max(s, e)) : ""
            }
        }
        if let result { rebuilt(result) }
        dismiss()
    }
}

/// The gear on a trip: opens its settings, and owns its sheet (the trip already
/// has one for the review).
struct TripSettingsDoor: View {
    let tripId: String
    var rebuilt: (Library.TripRebuilt) -> Void
    @EnvironmentObject var model: LibraryModel
    @State private var open = false

    var body: some View {
        Button { open = true } label: {
            SectionMark(section: .settings, size: 22, weight: 1.9)
                .foregroundStyle(AppSection.events.color)
                .frame(width: 36, height: 34).contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier("trip-settings")
        .accessibilityLabel("Trip settings")
        .sheet(isPresented: $open) { TripSettingsScreen(tripId: tripId, rebuilt: rebuilt).environmentObject(model) }
    }
}
