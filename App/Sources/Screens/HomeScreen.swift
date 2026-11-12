import SwiftUI
import PackingCore
import PackingLibrary

/// Home: the next trip, Grab and go, the library — and ＋ New trip (0.110, redesign B).
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

    /// More choices on Create new trip, open or closed, remembered on this device (0.76).
    static let moreKey = "ams.create.more"

    @EnvironmentObject var model: LibraryModel
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
    /// A bag's printed label scanned (0.126): the bag's own page, with what is in it now.
    @State private var bagShown: BagPageId?
    @State private var searching = false
    @State private var showingGrabLists = false
    /// "Which grab list?" — the Action button's menu, asked for through the model.
    @State private var menuShown = false
    /// Create new trip, its own page since 0.110 (`CreateTripPage`).
    @State private var creating = false
    /// The minute Home was last drawn at (0.108): "On your trip" turns with the clock.
    @State private var minute = Date()
    @Environment(\.scenePhase) private var scenePhase

    /// Home in the redesign "B" (0.110 — his pick, 11 Nov 2026: Apple's order, his own look): the big
    /// blue title with the nut for Settings; the search; Next trip; Grab and go; Library; and one
    /// full-colour "＋ New trip" button that opens Create new trip as its own page.
    var body: some View {
        // On a trip, going home, or just back (0.108). Read at this minute (`minute`).
        let _ = (minute, scenePhase)
        let onTrip = model.library.onTripCard(today: Today.local, time: Today.time)
        let away = onTrip != nil && onTrip?.moment != .backHome
        KeyboardAwayScroll {
            VStack(alignment: .leading, spacing: 8) {
                #if !os(macOS)
                header
                #endif
                searchField

                // The trip he is on, first (0.108, his "excellent"): while away, going home, back home.
                if let card = onTrip {
                    OnTripCard(card: card,
                               openTrip: { openTrip(card.id, LibraryModel.TripFocus(tripId: card.id, home: false, onSite: true)) },
                               packHome: { openTrip(card.id, LibraryModel.TripFocus(tripId: card.id, home: true)) },
                               whereIs: { searching = true },
                               openToDo: { openTrip(card.id, nil) },
                               openCharge: { openTrip(card.id, LibraryModel.TripFocus(tripId: card.id, home: false, charge: true)) },
                               review: { openTrip(card.id, LibraryModel.TripFocus(tripId: card.id, home: false, review: true)) })
                }

                // Unpack (0.126): a quiet line while things from a trip are still in the bag.
                if let nudge = model.library.unpackNudge(today: Today.local) {
                    Button { openTrip(nudge.tripId, LibraryModel.TripFocus(tripId: nudge.tripId, home: false, unpack: true)) } label: {
                        HStack(spacing: 8) {
                            Text(nudge.says).font(.system(.subheadline)).foregroundStyle(Theme.muted)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 4)
                            Text("Unpack").font(.system(.subheadline, weight: .semibold)).foregroundStyle(AppSection.events.color)
                        }
                        .padding(.horizontal, 12).frame(minHeight: Metrics.tap)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("home-unpack")
                }

                // Next trip, counted down (his idea 6) — never the trip on the card itself.
                if let next = model.library.nextTrip(today: Today.local, time: Today.time),
                   onTrip == nil || (onTrip?.moment == .backHome && onTrip?.id != next.id) {
                    sectionHeading("Next trip", id: "home-next-heading")
                    CountdownCard(next: next) { openedPlace = nil; opened = next.id }
                }

                // Grab and go: heading and lists in ONE frame (his words, 19 Oct 2026 — kept in B).
                VStack(alignment: .leading, spacing: 8) {
                    grabHeading
                    // Home holds eight (4 × 2) — HIS, in his order (GrabCollection.swift).
                    let onHome = model.library.homeGrabLists()
                    GrabButtons(lists: onHome, fill: Theme.bg) { grab = $0 }
                    if onHome.isEmpty {
                        Button { showingGrabLists = true } label: {
                            Text("No grab lists on Home. They wait in Grab Lists \u{2014} tap here to put one back.")
                                .font(.system(.callout, weight: .semibold)).foregroundStyle(AppSection.home.color)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(12)
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

                library

                // The main button, always in full colour (his rule, 26 Sep 2026). While he is away
                // or going home it is ONE quiet line instead (0.109, his words: a new trip is "not
                // highly sannolikt" then) — both open the same page.
                if away {
                    Button { creating = true } label: {
                        HStack(spacing: 6) {
                            plusMark
                            Text("New trip").font(.system(.subheadline, weight: .semibold))
                        }
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity, minHeight: 28)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("home-create-folded")
                    .padding(.top, 4)
                } else {
                    Button { creating = true } label: {
                        HStack(spacing: 6) {
                            plusMark
                            Text("New trip").font(.system(.body, weight: .semibold))
                        }
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity, minHeight: Metrics.row)
                        .background(Capsule().fill(AppSection.home.color))
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("home-new-trip")
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 24)
        }
        .headerOnTheMac { header }
        .sheet(isPresented: $creating) {
            CreateTripPage { id in
                // The page goes first; then the made trip opens (one sheet at a time).
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { openedPlace = nil; opened = id }
            }
            .environmentObject(model)
        }
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
                whenFree { openedPlace = o.place; opened = trip; voiceAsked = o.voiceStart }
            }
            else { whenFree { placeShown = o } }
        }
        // "On your trip" turns with the clock (0.108): Home is drawn again each minute.
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { minute = $0 }
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
        .sheet(item: $bagShown) { BagDetail(bagId: $0.id).environmentObject(model) }
        .onChange(of: model.thingToOpen, initial: true) { _, id in
            guard let id else { return }
            model.thingToOpen = nil
            if model.library.isBag(id) { whenFree { bagShown = BagPageId(id: id) } }
            else if model.library.items.contains(where: { $0.id == id }) { whenFree { thingShown = Opened(id: id) } }
        }
        // New Thing under the app icon or in the Dock's menu (0.105): a new, empty thing's page.
        .onChange(of: model.newThingToOpen, initial: true) { _, asked in
            guard asked else { return }
            model.newThingToOpen = false
            whenFree { thingShown = Opened(id: ThingEditor.newThing) }
        }
    }

    private struct GrabOpened: Identifiable { let list: GrabDefinition; var id: String { list.id } }

    /// "Home", big and blue, and at its right the nut that opens Settings (0.110 — Settings is no
    /// longer a tab), with the version under it, small. On the Mac pinned at the top of the page.
    private var header: some View {
        ScreenHeader(title: "Home", tint: AppSection.home.color, id: "home-heading",
                     font: .system(.largeTitle, weight: .bold)) {
            VStack(spacing: 0) {
                Button { model.tabToOpen = .settings } label: {
                    SectionMark(section: .settings, size: 22, weight: 1.9)
                        .foregroundStyle(AppSection.settings.color)
                        .frame(width: Metrics.tap + 4, height: Metrics.tap)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("home-settings")
                .accessibilityLabel("Settings")
                Text(AppInfo.version)
                    .font(.system(.caption2, weight: .semibold))
                    .foregroundStyle(Theme.muted.opacity(0.7))
                    .lineLimit(1).fixedSize()
                    .allowsHitTesting(false)
                    .accessibilityIdentifier("app-version")
            }
        }
    }

    /// The search, as a field across the page (B): a tap opens the same search as before.
    private var searchField: some View {
        Button { searching = true } label: {
            HStack(spacing: 6) {
                SVGPath.path("M11 4a7 7 0 1 0 0 14 7 7 0 0 0 0-14ZM20 20l-4-4")
                    .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .onGrid(Metrics.glyph)
                    .accessibilityHidden(true)
                Text("Search things and trips").font(.system(.body))
                Spacer(minLength: 0)
            }
            .foregroundStyle(Theme.muted)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: Metrics.tap)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.line.opacity(0.7)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier("search-open")
    }

    /// A part's heading on Home, in Home's blue (B): Next trip, Library.
    private func sectionHeading(_ title: String, id: String) -> some View {
        Text(title).font(.system(.headline, weight: .bold)).foregroundStyle(AppSection.home.color)
            .padding(.top, 4)
            .accessibilityIdentifier(id)
    }

    private var plusMark: some View {
        SVGPath.path("M12 5v14M5 12h14")
            .stroke(style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
            .onGrid(Metrics.glyph)
            .accessibilityHidden(true)
    }

    /// The trip on Home's "On your trip" card, opened (0.108).
    private func openTrip(_ id: String, _ focus: LibraryModel.TripFocus?) {
        model.tripFocus = focus
        openedPlace = nil
        opened = id
    }

    /// Grab and go's line, the first inside its frame (0.91): the heading and Grab Lists.
    private var grabHeading: some View {
        HStack(alignment: .center, spacing: 8) {
            Text("Grab and go").font(.system(.headline, weight: .bold)).foregroundStyle(AppSection.home.color)
                .lineLimit(1).minimumScaleFactor(0.8)
                .accessibilityIdentifier("home-grab-heading")
            Spacer(minLength: 8)
            // This door opens the grab lists — not the templates. His note on the Mac: "Your Grab Lists".
            Button { showingGrabLists = true } label: {
                Text("Grab Lists")
                    .font(.system(.footnote, weight: .semibold)).foregroundStyle(AppSection.home.color)
                    .frame(minHeight: Metrics.compact).contentShape(Rectangle())
            }
            .buttonStyle(.plain).focusEffectDisabled()
            .accessibilityIdentifier("grab-lists")
        }
    }

    /// Library (B, 0.110): Trips, Things and Templates — each with its count and its own mark and
    /// colour — in one card; a row opens its tab. These replace This Device's three count tiles; the
    /// sync dot (his pick, 0.92) stays on Home, at the right of the Library heading.
    private var library: some View {
        let templates = TemplatesScreen.activityAreas(model.library.templates, model.library).reduce(0) { $0 + $1.lists.count }
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                sectionHeading("Library", id: "device-heading")
                Spacer(minLength: 8)
                SyncLight().padding(.top, 4)
            }
            VStack(spacing: 0) {
                libraryRow(.events, "Trips", model.library.trips.count, id: "count-trips")
                CardHairline()
                libraryRow(.care, "Things", model.library.ownThings().count, id: "count-things")
                CardHairline()
                libraryRow(.templates, "Templates", templates, id: "count-templates")
            }
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home-device")
    }

    private func libraryRow(_ section: AppSection, _ title: String, _ count: Int, id: String) -> some View {
        Button { model.tabToOpen = section } label: {
            HStack(spacing: 10) {
                SectionMark(section: section, size: 18, weight: 1.9).foregroundStyle(section.color)
                Text(title).font(.system(.body)).foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
                Text("\(count)").font(.system(.body).monospacedDigit()).foregroundStyle(Theme.muted)
                    .accessibilityIdentifier(id)
                SVGPath.path("M9 6l6 6-6 6")
                    .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .onGrid(12)
                    .foregroundStyle(Theme.faint)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: Metrics.row)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier("home-library-\(section.rawValue)")
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
        // A page the window opened over its tab with ⌘N or Quick open (0.105, `RootPages`) makes way too.
        let busy = searching || showingGrabLists || opened != nil || grab != nil || menuShown || placeShown != nil
            || thingShown != nil || bagShown != nil || creating || RootPages.anyOpen
        guard busy else { open(); return }
        searching = false; showingGrabLists = false; opened = nil; grab = nil; menuShown = false; placeShown = nil
        thingShown = nil; creating = false
        RootPages.closeAll()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { open() }
    }

    /// What More choices holds, in one line while it is closed: "Summer · Mix · No laundry".
    static func moreSummary(season: String, catering: String, laundry: Bool, nights: Int) -> String {
        let food = shortFood(catering, CATERING.first { $0.id == catering }?.label ?? catering)
        return [season, food, laundry ? "Laundry, \(nights) nights" : "No laundry"].joined(separator: " \u{00B7} ")
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
