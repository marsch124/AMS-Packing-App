import SwiftUI
import PackingCore
import PackingLibrary

/// One trip, in Packing Mode: its lines under his "When" headings, a tap ticks
/// a line — and that tick is ONE small record, so the other device can tick
/// another line at the same moment and both survive.
struct TripScreen: View {
    /// The trip that was opened. A new trip started from it (Trip settings → Start a
    /// new trip from this one) takes its place on this screen.
    private let openedId: String
    @State private var startedId: String?
    private var tripId: String { startedId ?? openedId }
    /// `place`: opened from a place's code (0.69) — sorted From where, showing only the
    /// lines kept there until its chip is tapped.
    init(tripId: String, place: String? = nil) {
        self.openedId = tripId
        _placeFilter = State(initialValue: place)
    }
    /// Only the lines kept at this place (a place's code, 0.69); nil = every line.
    @State private var placeFilter: String?
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    /// His "When" colours are HIS — pale or bright — so they are made readable for
    /// the screen they land on ("Bad text color twice", 2026-09-26).
    @Environment(\.colorScheme) private var scheme
    /// When / Into / From where / Category / Section — remembered on this device, as
    /// the web app does.
    @AppStorage("ams.view") private var view = "when"
    /// Sections folded away — his ask (2026-09-26): "the list is extremely long".
    /// Remembered per trip and per sorting, one "trip|sorting|heading" per line.
    @AppStorage("ams.trip.folded") private var foldedRaw = ""
    @State private var newName = ""
    /// What Add was missing, said under the field (never a grey button).
    @State private var addNeeds = ""
    @State private var reviewing = false
    @State private var sweeping = false
    @State private var askingToDelete = false
    /// The line whose place is being chosen (his ask, 2026-09-26: set a place for
    /// "No place set" in one or two taps, without leaving the trip).
    @State private var placing: String?
    /// What the last Trip settings save did to the list, said under the loop.
    @State private var rebuiltNote = ""
    @State private var newPlace = ""
    /// What Save in Set place was missing, said under it (never a grey button).
    @State private var placeNeeds = ""
    /// The thing opened from Check before you go.
    @State private var checking: CheckedThing?
    /// On site is open (their field test, 3 Oct 2026) — Pack to go home is inside it.
    @State private var onSite = false
    /// Kits opened or folded on this visit (0.70); a kit not in here is open only while
    /// it is checked before each trip and not packed yet.
    @State private var kitOpen: [String: Bool] = [:]
    /// The line just ticked whose bag has pockets: its pockets show under it (0.69) —
    /// "<group>|<line id>", the copy tapped (under Template a line can stand twice, 0.74).
    @State private var pocketing: String?
    /// Only the lines still unticked — a tapped door check opens the trip so (0.69).
    @State private var onlyUnticked = false
    /// A tapped door check for the way home: On site opens, and in it Pack to go home.
    @State private var homeFromDoor = false
    struct CheckedThing: Identifiable { let id: String }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // His words (2026-09-25): "Where" → "Into" (the bag it goes into), and "From where" —
    // where it is kept at home — "so that I can pick all stuff from a specific location".
    // Section since 0.64 (his ask, 6 Oct 2026): sections "give a visual structure to the
    // packing" — the lines under their templates' section NAMES, in the order they first
    // come, "Everything else" last (`groupBySection`).
    // Template since 0.74 (his ask, 12 Oct 2026): "pack focused on e.g. Bike, Run or Golf" — the lines
    // under the templates they come from, a line on two templates under both (`linesByTemplate`).
    static let views: [(id: String, label: String)] = [("when", "When"), ("container", "Into"), ("stored", "From where"),
                                                       ("category", "Category"), ("section", "Section"),
                                                       ("template", "Template")]

    /// The lines as a sorting reads them: sorted by Into, a reminder goes in no bag —
    /// it stands under "To do" (spec 07, part 12). Every other sorting reads them as
    /// they are.
    static func grouped(_ view: String, _ lines: [Item]) -> [Item] {
        guard view == "container" else { return lines }
        return lines.map { line in
            guard Library.isReminder(line) else { return line }
            var l = line
            l.container = "To do"
            return l
        }
    }

    /// The middle of a text's FIRST line: its height less the distance between its first
    /// and last baselines is one line's height. A one-line name is centred as before.
    static func firstLineCentre(_ d: ViewDimensions) -> CGFloat {
        (d.height - (d[.lastTextBaseline] - d[.firstTextBaseline])) / 2
    }

    /// Laundry is on AND the trip is long enough for it to cap anything.
    private func washes(_ trip: TripEvent) -> Bool { laundryWashes(trip) }

    /// What a settings save did, in a few words.
    static func saying(_ r: Library.TripRebuilt) -> String {
        switch (r.added, r.removed) {
        case (0, 0): return "Saved. The list is the same."
        case (let a, 0): return "Saved: \(a) new on the list."
        case (0, let g): return "Saved: \(g) no longer on the list."
        case (let a, let g): return "Saved: \(a) new, \(g) no longer on the list."
        }
    }

    private func foldKey(_ label: String) -> String { TripFolds.key(trip: tripId, view: view, heading: label) }
    private func isFolded(_ label: String) -> Bool { TripFolds.isFolded(foldedRaw, foldKey(label)) }
    /// Folding also sweeps out the folds of trips this device no longer has (the spec
    /// pass, 5 Oct 2026: a deleted trip's folds were kept for ever).
    private func toggleFold(_ label: String) {
        foldedRaw = TripFolds.toggled(foldedRaw, foldKey(label), trips: Set(model.library.trips.map(\.id)))
    }

    /// Sorting: ONE drop-down since 0.64 — five pills do not fit an iPhone's line, and he
    /// asked for drop-downs everywhere (6 Oct 2026). "Sorting" stays to the left of its
    /// field, on the same line (his marks, 2026-09-25). Its rows keep the pills' ids,
    /// `trip-view-0…4`; the field is `trip-view`, the word `trip-view-label`.
    /// The groups the lines stand in under the chosen sorting: Template is the library's
    /// (it reads the templates); every other sorting is the web app's `groupBy`.
    private func groups(_ lines: [Item]) -> [EntryGroup] {
        view == "template" ? model.library.linesByTemplate(tripId: tripId, lines: lines)
                           : groupBy(view, TripScreen.grouped(view, lines))
    }

    /// A heading's colour: under When the colour of its first line's "When"; under
    /// Template the Templates violet (the colour template names have in Your things) —
    /// the trip's green for "Added on the trip"; otherwise the trip's green.
    private func headingColour(_ group: EntryGroup) -> Color {
        switch view {
        case "when": return Color(hexString: readableHex(phaseColor(group.entries[0].phase), dark: scheme == .dark))
        case "template" where group.label != Library.addedOnTheTrip: return ThingDetailLine.violet(scheme)
        default: return AppSection.events.color
        }
    }

    private var sorting: some View {
        DropDown(title: "Sorting", heading: .beside, options: TripScreen.views.map { ($0.id, $0.label) },
                 selected: TripScreen.views.contains { $0.id == view } ? view : "when",
                 id: DropDownIds(field: "trip-view", list: "trip-view-list", row: "trip-view", title: "trip-view-label"),
                 tint: AppSection.events.color) { view = $0 }
    }

    var body: some View {
        let trip = model.library.trips.first { $0.id == tripId } ?? newEvent()
        let p = progress(trip.entries)
        // Nothing left to decide: every line ticked or set aside. Set aside counts
        // as handled (his choice, 2026-09-23), so it leaves the total.
        let allPacked = p.total > 0 && p.done == p.total
        // Never trap on a repeated id (his E.6 crash, 28 Sep): the first line keeps it.
        let index: [String: Int] = Dictionary(trip.entries.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { first, _ in first })
        // Opened from a place's code: its lines only — and nothing else on the page, so
        // they are what he sees first (his plan, stop A: "the trip opens showing only
        // what to take from the garage"). The chip under Sorting shows everything again.
        // A tapped door check (0.69) shows only the lines still unticked; both may hold.
        let placeLines = placeFilter.map { place in trip.entries.filter { Library.isKept($0.storage, at: place) } } ?? trip.entries
        let shownLines = onlyUnticked ? placeLines.filter { !$0.checked && !isSetAside($0) } : placeLines
        // Its kits, read once for every line (0.70, TripKitLine.swift).
        let kits = model.library.kitLines(tripId: tripId)
        // Every bag's pockets, asked once for all the lines (0.69).
        let pockets = model.library.pocketsByBag()
        // Where each line comes from (0.74): its templates' icons, before its bag — not when
        // sorted by Template, whose headings say it.
        let from = view == "template" ? [:] : model.library.lineTemplates(tripId: tripId)
        VStack(spacing: 0) {
            // ONE centre line (0.73, his ask of 12 Oct 2026): the name, its pen right
            // beside it, and at the right the state and Done — "Reviewed" sat in grey
            // words on the line's top, off Done's centre, and the bare pen on the count's
            // line did not read as a button. A name on two lines keeps them all on its
            // FIRST line (`firstLineCentre`), Done where the thumb expects it.
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .center, spacing: 8) {
                    Text(trip.name.isEmpty ? "Untitled event" : trip.name)
                        .font(.system(.title3, weight: .bold)).foregroundStyle(Theme.ink)
                        .lineLimit(2).minimumScaleFactor(0.85)          // the whole name, not "Weekend in the…"
                        .alignmentGuide(VerticalAlignment.center, computeValue: TripScreen.firstLineCentre)
                        .layoutPriority(1)
                        .accessibilityIdentifier("trip-name")
                    // Its settings, after it is made (the gap list's first High item): a pen
                    // in a ring, beside the name it changes.
                    TripSettingsDoor(tripId: tripId, rebuilt: { rebuiltNote = TripScreen.saying($0) },
                                     startedAgain: { new in
                        let from = trip.name
                        startedId = new.id
                        rebuiltNote = "New trip from \u{201C}\(from)\u{201D}: \(new.entries.count) things, nothing ticked. Its dates are under the pen."
                    })
                    .environmentObject(model)
                    Spacer(minLength: 8)
                    // After the trip: what did I use, what did I miss. Once, then it says so —
                    // by the one rule every screen uses (the spec pass, 5 Oct 2026: a trip with
                    // only a review time looked reviewed on its card and offered Review here) —
                    // in the Trips row's own badge (0.73).
                    if Library.isReviewed(trip) {
                        TripStateBadge(state: .reviewed).fixedSize()
                            .accessibilityIdentifier("trip-reviewed")
                    } else if !trip.entries.isEmpty {
                        Button("Review") { reviewing = true }
                            .buttonStyle(HeaderButtonStyle(tint: AppSection.events.color, filled: false)).focusEffectDisabled()
                            .font(.system(.body, weight: .semibold)).foregroundStyle(AppSection.events.color)
                            .accessibilityIdentifier("trip-review")
                    }
                    Button("Done") { dismiss() }
                        .buttonStyle(HeaderButtonStyle(tint: AppSection.events.color, filled: true)).focusEffectDisabled()
                        .font(.system(.body, weight: .semibold)).foregroundStyle(AppSection.events.color)
                        // Escape closes it, as Done does (the spec pass, 5 Oct 2026 — on the Mac,
                        // and on an iPhone with a keyboard).
                        .keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier("trip-done")
                }
                Text(p.aside > 0 ? "\(p.done)/\(p.total) · \(p.aside) set aside" : "\(p.done)/\(p.total)")
                    .font(.system(.callout, weight: .semibold).monospacedDigit())
                    .foregroundStyle(p.total > 0 && p.done == p.total ? AppSection.events.color : Theme.muted)
                    .accessibilityIdentifier("trip-progress")
                    .accessibilityValue(allPacked ? "all packed" : "")
            }
            .padding(16)
            // Where this trip stands in the loop (his picture, 2026-09-27); a tap shows it whole.
            LoopDoor(here: model.library.loopStep(tripId: tripId, today: Today.local))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16).padding(.top, -6).padding(.bottom, 10)
            if !rebuiltNote.isEmpty {
                Text(rebuiltNote)
                    .font(.system(.subheadline, weight: .semibold)).foregroundStyle(AppSection.events.color)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).padding(.bottom, 8)
                    .accessibilityIdentifier("trip-rebuilt")
            }
            KeyboardAwayScroll {
                // The card is deliberately OUTSIDE the lazy stack: a lazy row is
                // thrown away and rebuilt as it scrolls off, which loses what he
                // has typed into it (found by the test, 2026-09-23).
                VStack(alignment: .leading, spacing: 4) {
                if placeFilter == nil {
                // Check before you go (his ideas 4 and 5): first, and only when something needs him.
                TripChecksCard(tripId: trip.id) { checking = CheckedThing(id: $0) }.environmentObject(model)
                    .padding(.top, 10).padding(.horizontal, 16)
                // To charge (0.75, spec 07 part 15): from the day before the trip through its last
                // day, the things with a battery — under what would stop him at the airport.
                ToChargeCard(tripId: trip.id).environmentObject(model)
                    .padding(.top, 10).padding(.horizontal, 16)
                WeatherCard(tripId: trip.id).environmentObject(model)
                    .padding(.top, 10).padding(.horizontal, 16)
                BagsCard(tripId: trip.id).environmentObject(model)
                    .padding(.top, 6).padding(.horizontal, 16)
                // On site (their field test, 3 Oct 2026; Pack to go home, his idea 13, is in
                // it now): once the trip has begun, or something was bought on site.
                if model.library.onSiteBegun(tripId: trip.id, today: Today.local) {
                    onSiteDoor(trip)
                        .padding(.top, 6).padding(.horizontal, 16)
                }
                }
                // The sorting, DIRECTLY above the list it sorts (0.74, his ask of 12 Oct 2026:
                // under the loop strip it sat far above the lines, "disconnected from it").
                // His marks (2026-09-25): "Sorting" on the left, the choice on the same line —
                // and on the iPhone, Pack by voice at its end (0.71, a test: spec 07 part 10).
                Group {
                    #if os(iOS)
                    VoiceSortingRow(tripId: tripId) { sorting }
                    #else
                    sorting
                    #endif
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16).padding(.top, 10)
                if let place = placeFilter { placeChip(place) }
                #if DEBUG
                if AMSPackingApp.testing && ProcessInfo.processInfo.arguments.contains("-showDoorChecks") {
                    DoorCheckList(tripId: tripId).padding(.horizontal, 16).padding(.top, 4)
                }
                #endif
                if onlyUnticked { untickedBar }
                if placeFilter != nil && shownLines.isEmpty {
                    Text("Nothing on this trip is kept here. Tap the place above to see every line.")
                        .font(.system(.subheadline)).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 16).padding(.top, 10)
                        .accessibilityIdentifier("trip-place-none")
                }
                // No space between lines: each is as tall as its words (`Metrics.line`).
                LazyVStack(alignment: .leading, spacing: 0) {
                    // One level of groups; inside a group the lines keep the trip's own order.
                    // (The web app nests: When → by bag inside; the others → by When inside.)
                    ForEach(Array(groups(shownLines).enumerated()), id: \.offset) { g, group in
                        if !group.entries.isEmpty {
                            // The heading, and one press to tick the whole section
                            // (his ask: "so that I could toggle all done").
                            let mine = group.entries.filter { !isSetAside($0) }
                            let sectionDone = !mine.isEmpty && mine.allSatisfy { $0.checked }
                            let folded = isFolded(group.label)
                            HStack(spacing: 8) {
                                // Fold the section away, or open it again. The arrow is its own
                                // button: the Mac folds a button's texts into the button, and the
                                // heading's name must stay a text of its own.
                                Button { toggleFold(group.label) } label: {
                                    SVGPath.path("M9 6l6 6-6 6")
                                        .stroke(style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                                        .onGrid(Metrics.glyph)
                                        .rotationEffect(.degrees(folded ? 0 : 90))
                                        .foregroundStyle(Theme.ink)
                                        .frame(width: Metrics.lineButton - 6, height: Metrics.line).contentShape(Rectangle())
                                }
                                .buttonStyle(.plain).focusEffectDisabled()
                                .accessibilityIdentifier("trip-group-\(g)-fold")
                                .accessibilityLabel(folded ? "Open \(group.label)" : "Fold \(group.label)")
                                Text(group.label)
                                    .font(.system(.subheadline, weight: .semibold))
                                    .foregroundStyle(headingColour(group))
                                    .accessibilityIdentifier("trip-group-\(g)-label")
                                    .onTapGesture { toggleFold(group.label) }
                                Text("\(mine.filter { $0.checked }.count)/\(mine.count)")
                                    .font(.system(.footnote, weight: .semibold).monospacedDigit())
                                    .foregroundStyle(Theme.muted)
                                Spacer()
                                // Only while the section has something to tick: with every line set
                                // aside there is nothing, and a switched-off grey circle is what his
                                // rule forbids (the spec pass, 5 Oct 2026) — the space stays, so the
                                // heading does not jump.
                                if mine.isEmpty {
                                    Color.clear.frame(width: Metrics.lineButton, height: Metrics.line)
                                } else {
                                    Button {
                                        model.change { lib in
                                            for line in mine { _ = lib.setChecked(!sectionDone, tripId: tripId, entryId: line.id) }
                                        }
                                    } label: {
                                        TickCircle(on: sectionDone, tint: AppSection.events.color, ring: sectionDone ? nil : Theme.line)
                                            .frame(width: Metrics.lineButton, height: Metrics.line).contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain).focusEffectDisabled()
                                    .accessibilityIdentifier("trip-group-\(g)-all")
                                    .accessibilityLabel(sectionDone ? "Untick \(group.label)" : "Tick all of \(group.label)")
                                    .accessibilityAddTraits(sectionDone ? .isSelected : [])
                                }
                            }
                            // A little air above a heading, none under it (12 points above,
                            // and 36-point buttons, until 0.67).
                            .padding(.top, 6)
                            if !folded {
                            ForEach(group.entries, id: \.id) { line in
                                let n = index[line.id] ?? 0
                                let aside = isSetAside(line)
                                let needsPlace = view == "stored" && group.label == "No place set"
                                VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Button {
                                        if !aside {
                                            let on = !line.checked
                                            model.change { _ = $0.setChecked(on, tripId: tripId, entryId: line.id) }
                                            // Its bag has pockets: they show under it, the usual one chosen (0.69).
                                            // Under the copy tapped only: under Template a line can stand twice.
                                            pocketing = on && pockets[normName(line.container)] != nil ? "\(g)|\(line.id)" : nil
                                        }
                                    } label: {
                                        PackLine(line: line, nights: qtyNights(trip), tint: Color(hexString: readableHex(phaseColor(line.phase), dark: scheme == .dark, graphic: true)),
                                                 showBag: view != "container", washed: washes(trip),
                                                 kitWords: kits[line.id]?.insideWords ?? "",
                                                 from: from[line.id] ?? [], fromId: "trip-line-\(n)-from")
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("trip-line-\(n)")
                                    .accessibilityValue(PackLine.count(line, qtyNights(trip), washed: washes(trip)))
                                    .accessibilityAddTraits(line.checked ? .isSelected : [])
                                    // A kit: the arrow that shows what is inside it (0.70).
                                    if let kit = kits[line.id] {
                                        KitFoldButton(open: kitIsOpen(kit, line), name: line.name, id: "trip-line-\(n)-kit") {
                                            kitOpen[line.id] = !kitIsOpen(kit, line)
                                        }
                                    }
                                    // ⊘ "not this time" — one tap, his call, no confirmation; ↻ takes it back.
                                    Button {
                                        model.change { _ = $0.setAside(!aside, tripId: tripId, entryId: line.id) }
                                    } label: {
                                        // As tall as the line, no taller; wide enough to hit.
                                        AsideMark(back: aside).onGrid(Metrics.glyph)
                                            .frame(width: Metrics.lineButton, height: Metrics.line)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain).focusEffectDisabled()
                                    .accessibilityIdentifier("trip-line-\(n)-aside")
                                    .accessibilityLabel(aside ? "Take it this time" : "Not this time")
                                }
                                // A kit (0.70): what is missing from it, what is worth saying, what is inside.
                                if let kit = kits[line.id] { kitParts(kit, line, n: n, trip: trip) }
                                // Which pocket (0.69): one short row of small pills under the line just
                                // ticked — tap one, or ignore it.
                                if pocketing == "\(g)|\(line.id)", line.checked, let choices = pockets[normName(line.container)] {
                                    PocketPills(pockets: choices, chosen: Library.pocket(line), tint: AppSection.events.color,
                                                id: "trip-line-\(n)-pocket") { picked in
                                        let id = tripId, entry = line.id
                                        model.change { _ = $0.setPocket(picked, tripId: id, entryId: entry) }
                                        pocketing = nil
                                    }
                                    .padding(.leading, Metrics.mark + 8).padding(.bottom, 4)
                                }
                                // On its own line under the name, so the name keeps its width.
                                if needsPlace {
                                    if placing == line.id { placePanel(line) }
                                    else {
                                        Button { placing = line.id; newPlace = ""; placeNeeds = "" } label: {
                                            Text("Set place").font(.system(.footnote, weight: .semibold))
                                                .foregroundStyle(AppSection.events.color)
                                                .padding(.horizontal, 10).frame(minHeight: Metrics.chip)
                                                .overlay(Capsule().stroke(AppSection.events.color, lineWidth: 1.2))
                                                .contentShape(Capsule())
                                        }
                                        .buttonStyle(.plain).focusEffectDisabled()
                                        .padding(.leading, Metrics.mark + 8).padding(.bottom, 4)
                                        .accessibilityIdentifier("trip-line-\(n)-place")
                                    }
                                }
                                }
                                // Bug B1 (his Mac, 2026-09-26): a row kept showing NO tick while the
                                // stored trip — and the section's own count — had it ticked. Not
                                // reproduced on demand; this makes a row rebuild whenever its tick
                                // or its set-aside changes, so it cannot be left showing an old state.
                                // …and when it moves to another section, or its place panel opens or
                                // closes: a lazy row that MOVED kept its old face ("Set place" still
                                // showing under the place just chosen — the same staleness, seen
                                // 2026-09-26 in the Set place test).
                                .id("\(line.id)|\(line.checked)|\(aside)|\(group.label)|\(placing == line.id)|\(qtyNights(trip))|\(pocketing == "\(g)|\(line.id)")|\(Library.pocket(line))")
                            }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)

                if placeFilter == nil {
                // The web app's "Mark everything packed" / "Clear every tick", under the list.
                TickAllRow(tripId: tripId, done: p.done, total: p.total).environmentObject(model)
                    .padding(.horizontal, 16).padding(.top, 18)
                // The web app's Excel button (the trip as a spreadsheet) and its Share (a
                // link, a QR code when it fits, or a file) — two real buttons side by side,
                // his test D.22.
                HStack(alignment: .top, spacing: 12) {
                    TripExcelButton(tripId: tripId).environmentObject(model)
                    ShareDoor(id: "trip-share", wide: true) {
                        ShareOffer(title: "Share \u{201C}\(trip.name)\u{201D}", link: model.library.shareLink(tripId: tripId),
                                   file: model.library.shareFile(tripId: tripId))
                    }
                }
                .padding(.horizontal, 16).padding(.top, 12)
                // After the review: the trip's page in his Obsidian vault (0.70, spec 07 part 8)
                // — at the foot since 0.73, under Excel and Share and in their style (his ask,
                // 12 Oct 2026; until then a card at the top). Only Delete comes after it.
                if Library.isReviewed(trip) {
                    VaultCard(tripId: trip.id).environmentObject(model)
                        .padding(.horizontal, 16).padding(.top, 12)
                }
                // Last on the screen, quiet and red, and it asks first — his rule for
                // removing anything. His two test trips had no way out (2026-09-26).
                deleteTrip(trip)
                    .padding(.horizontal, 16).padding(.top, 18)
                }
                }
                .padding(.bottom, 24)
            }
            .sheet(item: $checking) { c in ThingEditor(itemId: c.id).environmentObject(model) }
            // "Also the tripod" — a thing for THIS trip only, typed on the spot. Not while
            // one place's lines are shown: a line typed here has no place, and would vanish.
            if placeFilter == nil {
            HStack(spacing: 8) {
                TextField("Add a thing to this trip", text: $newName)
                    .textFieldStyle(.plain)
                    .font(.system(.body)).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 12).frame(minHeight: Metrics.tap)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                    .onSubmit { add() }
                    .accessibilityIdentifier("trip-add-name")
                // Always in colour (his rule for a main button); pressed with nothing
                // typed it says so under the field.
                Button { if jsTrim(newName).isEmpty { addNeeds = "Type a thing first." } else { add() } } label: {
                    FieldButtonLabel(title: "Add", tint: AppSection.events.color)
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("trip-add")
                // Bought on site (his idea 12): on the list in one go, in hand already.
                // "On site", not "there" — their word from the field test (Oct 2026).
                if !jsTrim(newName).isEmpty {
                    Button { addBought() } label: {
                        Text("Bought on site").font(.system(.callout, weight: .semibold))
                            .lineLimit(1).fixedSize()
                            .foregroundStyle(AppSection.events.color)
                            .padding(.horizontal, 12).frame(minHeight: Metrics.tap)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppSection.events.color, lineWidth: 1.4))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("trip-add-bought")
                }
            }
            .needsLine($addNeeds, typed: newName, id: "trip-add-needs")
            .padding(.horizontal, 16).padding(.vertical, 10)
            // The green is the WHOLE screen, this bar included (his call: "we need
            // strong indicators").
            .background(allPacked ? Color.clear : Theme.bg)
            }
        }
        .onAppear { if placeFilter != nil { view = "stored" } }
        .background {
            // Everything packed: the screen itself says so. The green is painted ON
            // the background, not under it, or the opaque one hides it.
            ZStack {
                Theme.bg
                if allPacked { AppSection.events.color.opacity(0.34) }
            }
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.5), value: allPacked)
        }
        .sheet(isPresented: $reviewing) { ReviewScreen(tripId: tripId).environmentObject(model) }
        .accessibilityElement(children: .contain)
        .overlay(alignment: .top) {
            // The moment: ONE sweep down the screen, never a blink — a blinking
            // screen keeps demanding attention after the news is delivered.
            if sweeping {
                LinearGradient(colors: [AppSection.events.color.opacity(0.55), AppSection.events.color.opacity(0.0)],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .accessibilityHidden(true)
            }
        }
        .onChange(of: allPacked) { _, packed in
            guard packed, !reduceMotion else { return }
            withAnimation(.easeOut(duration: 0.45)) { sweeping = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                withAnimation(.easeIn(duration: 0.55)) { sweeping = false }
            }
        }
        .accessibilityIdentifier("trip-detail")
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 640)
        #endif
        .onAppear(perform: takeFocus)
        .onChange(of: model.tripFocus) { _, _ in takeFocus() }
    }

    /// A tapped door check opened this trip (0.69): on just its unticked lines — or, for
    /// the way home, On site opens and in it Pack to go home, on what is not in a bag yet.
    private func takeFocus() {
        guard let focus = model.tripFocus, focus.tripId == tripId else { return }
        model.tripFocus = nil
        if focus.home {
            homeFromDoor = true
            // After this window has finished arriving: one cannot come up while another still is.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { onSite = true }
        } else {
            onlyUnticked = true
        }
    }

    /// "Only what is still unticked", and Show all — while a door check's view is on.
    private var untickedBar: some View {
        HStack(spacing: 8) {
            Text("Only what is still unticked")
                .font(.system(.subheadline, weight: .semibold)).foregroundStyle(AppSection.events.color)
                .accessibilityIdentifier("trip-unticked-only")
            Spacer(minLength: 8)
            Button { onlyUnticked = false } label: {
                Text("Show all").font(.system(.subheadline, weight: .semibold)).foregroundStyle(AppSection.events.color)
                    .padding(.horizontal, 10).frame(minHeight: Metrics.chip)
                    .overlay(Capsule().stroke(AppSection.events.color, lineWidth: 1.2))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain).focusEffectDisabled()
            .accessibilityIdentifier("trip-show-all")
        }
        .padding(.horizontal, 16).padding(.top, 6)
    }

    /// The place a code opened the trip on (0.69), as a chip under Sorting: its name and
    /// an ✕ — a tap shows every line again. Its words are the button's value, so a test
    /// reads them on the Mac too (a button folds its texts into itself there).
    private func placeChip(_ place: String) -> some View {
        Button { placeFilter = nil } label: {
            HStack(spacing: 6) {
                Text(place).font(.system(.subheadline, weight: .semibold)).lineLimit(1)
                SVGPath.path("M7 7L17 17M17 7L7 17")
                    .stroke(style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                    .onGrid(14)
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 12).frame(minHeight: Metrics.chip)
            .background(Capsule().fill(AppSection.events.color))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16).padding(.top, 6)
        .accessibilityIdentifier("trip-place-filter")
        .accessibilityLabel("Only \(place). Show every line")
        .accessibilityValue(place)
    }

    /// A kit shows what is inside it while it is checked before each trip and not packed
    /// yet — until he folds it; any other kit when he opens it (0.70).
    private func kitIsOpen(_ kit: KitOnLine, _ line: Item) -> Bool {
        kitOpen[line.id] ?? (kit.check && !line.checked && !isSetAside(line))
    }

    private func kitParts(_ kit: KitOnLine, _ line: Item, n: Int, trip: TripEvent) -> some View {
        let open = kitIsOpen(kit, line)
        let id = tripId, entry = line.id
        // A past trip's kit (0.73) is what was inside it then: nothing to warn about now.
        return KitLineParts(kit: kit, line: line, n: n, open: open,
                            warnings: kit.kept ? [] : model.library.kitWarnings(kitId: kit.kit.id, today: Today.local, before: trip.endDate),
                            tint: Color(hexString: readableHex(phaseColor(line.phase), dark: scheme == .dark, graphic: true)),
                            tick: { thing, on in
                                model.change { _ = $0.setKitContentTicked(on, tripId: id, entryId: entry, contentId: thing) }
                            },
                            takeOut: { thing, out in model.change { _ = $0.setTakenOut(thingId: thing, out) } })
            // Rebuilt whenever what it shows changes (the lazy list's stale rows, B1).
            .id("kit|\(line.id)|\(open)|\(line.checked)|\(kit.ticked.sorted())|\(kit.missing.count)|\(kit.contents.count)|\(kit.kept)")
    }

    /// His places, one tap each; or a new one typed. The thing keeps the place.
    private func placePanel(_ line: Item) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Where is \(line.name) kept?")
                    .font(.system(.footnote, weight: .semibold)).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Button("Close") { placing = nil; newPlace = ""; placeNeeds = "" }
                    .buttonStyle(HeaderButtonStyle(tint: Theme.muted, filled: false)).focusEffectDisabled()
                    .font(.system(.footnote, weight: .semibold)).foregroundStyle(Theme.muted)
                    .accessibilityIdentifier("trip-place-close")
            }
            FlowRow(spacing: 6) {
                ForEach(Array(model.library.storagePlaces().enumerated()), id: \.offset) { i, place in
                    Button { putAway(line, place) } label: {
                        Text(place).font(.system(.footnote, weight: .semibold)).foregroundStyle(Theme.ink)
                            .padding(.horizontal, 10).frame(minHeight: 32)
                            .background(Capsule().fill(Theme.bg))
                            .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("trip-place-\(i)")
                }
            }
            HStack(spacing: 8) {
                TextField("A new place", text: $newPlace)
                    .textFieldStyle(.plain)
                    .font(.system(.subheadline)).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 10).frame(minHeight: Metrics.chip)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bg))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 1))
                    .onSubmit { putAway(line, newPlace) }
                    .accessibilityIdentifier("trip-place-new")
                // Always in colour (his rule for a main button, 2026-09-26 — it sat grey and
                // switched off until the spec pass, 5 Oct 2026); pressed with nothing typed
                // it says so under the field.
                Button {
                    if jsTrim(newPlace).isEmpty { placeNeeds = "Type a place first, or tap one above." } else { putAway(line, newPlace) }
                } label: {
                    Text("Save").font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 12).frame(minHeight: Metrics.chip)
                        .background(RoundedRectangle(cornerRadius: 8).fill(AppSection.events.color))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("trip-place-save")
            }
            .needsLine($placeNeeds, typed: newPlace, id: "trip-place-save-needs")
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppSection.events.color.opacity(0.5), lineWidth: 1))
        .padding(.leading, Metrics.mark + 8).padding(.bottom, 6)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("trip-place-panel")
    }

    private func putAway(_ line: Item, _ place: String) {
        guard !jsTrim(place).isEmpty else { return }
        let id = tripId, entry = line.id
        model.change { _ = $0.setPlace(place, tripId: id, entryId: entry) }
        placing = nil
        newPlace = ""
    }

    @ViewBuilder private func deleteTrip(_ trip: TripEvent) -> some View {
        if askingToDelete {
            VStack(alignment: .leading, spacing: 8) {
                Text("Delete \u{201C}\(trip.name)\u{201D}?")
                    .font(.system(.callout, weight: .semibold)).foregroundStyle(Theme.ink)
                Text("The trip and its \(trip.entries.count) line\(trip.entries.count == 1 ? "" : "s") go. Your things and your templates stay.")
                    .font(.system(.footnote)).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    Button("Keep it") { askingToDelete = false }
                        .buttonStyle(.plain).focusEffectDisabled()
                        .font(.system(.callout, weight: .semibold)).foregroundStyle(Theme.ink)
                        .accessibilityIdentifier("trip-delete-no")
                    Spacer()
                    Button {
                        let id = tripId
                        dismiss()
                        model.change { _ = $0.deleteTrip(id: id) }
                        foldedRaw = TripFolds.without(trip: id, in: foldedRaw)     // its folds go with it
                    } label: {
                        Text("Delete the trip")
                            .font(.system(.callout, weight: .semibold)).foregroundStyle(.white)
                            .padding(.horizontal, 12).frame(minHeight: Metrics.compact)
                            .background(Capsule().fill(AppSection.actions.color))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("trip-delete-yes")
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppSection.actions.color, lineWidth: 1))
        } else {
            SmallDeleteButton(title: "Delete trip", id: "trip-delete") { askingToDelete = true }
        }
    }

    private func add() {
        let name = newName
        guard !jsTrim(name).isEmpty else { return }
        model.change { _ = $0.addCustomLine(tripId: tripId, name: name) }
        newName = ""
    }

    /// The door to On site: what it holds in one line — "2 bought · 1 left · 3 notes ·
    /// home 4/9" — short enough for an iPhone. The line is also the button's value:
    /// the Mac folds a button's words into the button.
    private func onSiteDoor(_ trip: TripEvent) -> some View {
        let says = model.library.onSiteSummary(tripId: trip.id)
        return Button { onSite = true } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("On site").font(.system(.body, weight: .semibold)).foregroundStyle(Theme.ink)
                    Text(says)
                        .font(.system(.footnote).monospacedDigit()).foregroundStyle(Theme.muted)
                        .lineLimit(1).minimumScaleFactor(0.85)
                }
                Spacer()
                SVGPath.path("M9 6l6 6-6 6").stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                    .frame(width: 22, height: 22).foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 14).frame(minHeight: 58)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppSection.events.color, lineWidth: 1.2))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier("trip-onsite")
        .accessibilityValue(says)
        .sheet(isPresented: $onSite, onDismiss: { homeFromDoor = false }) {
            OnSiteScreen(tripId: trip.id, openHome: homeFromDoor).environmentObject(model)
        }
    }

    private func addBought() {
        let name = newName
        guard !jsTrim(name).isEmpty else { return }
        model.change { _ = $0.addBoughtOnSite(tripId: tripId, name: name) }
        newName = ""
    }
}

/// One line of a packing list. Ticked = a filled circle; set aside = greyed and
/// struck through (3px, his call), and it leaves the counts.
struct PackLine: View {
    let line: Item
    let nights: Int
    let tint: Color
    var showBag = true
    /// Laundry capped the nights: a per-night line says so with the washtub.
    var washed = false
    /// A kit's "3 inside", after its name (0.70).
    var kitWords = ""
    /// The templates it comes from (0.74): their icons, before the bag. Empty = nothing.
    var from: [PackList] = []
    var fromId = ""

    /// "×4 · laundry", "×7", or nothing — what the line says about how many.
    static func count(_ line: Item, _ nights: Int, washed: Bool) -> String {
        let qty = effectiveQty(line, nights)
        guard qty > 1 else { return "" }
        let n = qty.rounded() == qty ? String(Int(qty)) : String(qty)
        return washed && line.perNight ? "×\(n) · laundry" : "×\(n)"
    }

    var body: some View {
        let aside = isSetAside(line)
        let qty = effectiveQty(line, nights)
        // A line as tall as its words (`Metrics.line`, 30 / 22 top to top), a small tick
        // circle (`Metrics.mark`). His words, 5 Oct 2026: "slimmer rows in the trip,
        // smaller tick circles and less space between lines"; 6 Oct, testing 0.63: "Far
        // too much space between the lines" — 44 points top to top until 0.67.
        HStack(spacing: 8) {
            TickCircle(on: line.checked && !aside, tint: tint, ring: aside ? Theme.line : nil)
            VStack(alignment: .leading, spacing: 0) {
                (Text(line.name) + (kitWords.isEmpty ? Text("") : Text(" \u{00B7} \(kitWords)").foregroundStyle(Theme.muted)))
                    .font(.system(.body))
                    .foregroundStyle(aside ? Theme.muted : (line.checked ? Theme.muted : Theme.ink))
                    .strikethrough(aside, pattern: .solid, color: Theme.muted)
                    .lineLimit(2)
                if Library.isBoughtOnSite(line) {
                    Text("Bought on site").font(.system(.footnote, weight: .semibold)).foregroundStyle(AppSection.events.color)
                }
            }
            Spacer(minLength: 8)
            // A reminder (spec 07, part 12) is something to DO: no count, no bag.
            if Library.isReminder(line) {
                if !from.isEmpty { TemplateMarks(from: from, id: fromId) }
                if showBag {
                    Text("To do").font(.system(.footnote, weight: .semibold)).foregroundStyle(Theme.muted).lineLimit(1)
                }
            } else {
            if qty > 1 {
                Text("×\(qty.rounded() == qty ? String(Int(qty)) : String(qty))")
                    .font(.system(.subheadline, weight: .semibold).monospacedDigit()).foregroundStyle(Theme.muted)
                if washed && line.perNight {
                    LaundryMark().onGrid(Metrics.glyph).foregroundStyle(Theme.muted)
                }
            }
            // The pocket it went into, once ticked (0.69): "Backpack · Front pocket" — just
            // the pocket when the list is sorted by bag (the heading names the bag).
            let pocket = line.checked && !aside ? Library.pocket(line) : ""
            let bag = showBag ? Library.bagAndPocket(line.container, pocket) : pocket
            let cap: CGFloat = pocket.isEmpty ? 150 : 200
            if !from.isEmpty {
                // Where it comes from (0.74): its templates' icons, right before the bag —
                // the bag's words are cut first, never the icons.
                MarksBeforeBag(cap: cap) {
                    TemplateMarks(from: from, id: fromId)
                    if showBag || !pocket.isEmpty {
                        Text(bag).font(.system(.footnote)).foregroundStyle(Theme.muted).lineLimit(1)
                    }
                }
            } else if showBag || !pocket.isEmpty {
                Text(bag)
                    .font(.system(.footnote)).foregroundStyle(Theme.muted).lineLimit(1)
                    .frame(maxWidth: cap, alignment: .trailing)
            }
            }
        }
        // A hair above and below, so a name on two lines keeps off the hairline.
        .padding(.vertical, 2)
        .frame(minHeight: Metrics.line)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
    }
}

/// Where a trip's line comes from (0.74, his ask of 12 Oct 2026 — "valuable to know from
/// which template the item comes"; of three looks he picked the template's OWN icon): the
/// icon of each template, small and in the Templates violet, in the trip's template order.
/// Up to three; four or more = two and "+N". A template that shows a letter on its cover
/// is its name's first word. Never squeezed: the bag's words are cut first. ONE element
/// for VoiceOver and the tests — the template NAMES, never icon ids — and a tooltip on the Mac.
struct TemplateMarks: View {
    let from: [PackList]
    let id: String
    @Environment(\.colorScheme) private var scheme

    #if os(macOS)
    static let size: CGFloat = 12
    #else
    static let size: CGFloat = 15
    #endif

    static func names(_ from: [PackList]) -> String {
        from.map { jsTrim($0.name).isEmpty ? "Untitled template" : $0.name }.joined(separator: ", ")
    }

    var body: some View {
        let violet = ThingDetailLine.violet(scheme)
        let shown = from.count > 3 ? Array(from.prefix(2)) : from
        HStack(spacing: 3) {
            ForEach(Array(shown.enumerated()), id: \.offset) { _, list in
                if let icon = TemplateIcons.icon(Library.icon(of: list)) {
                    IconMark(path: icon.path, size: TemplateMarks.size, weight: 1.9)
                } else {
                    Text(String(jsTrim(list.name).split(separator: " ").first ?? ""))
                        .font(.system(.footnote, weight: .semibold)).lineLimit(1)
                }
            }
            if from.count > 3 {
                Text("+\(from.count - 2)").font(.system(.footnote, weight: .semibold).monospacedDigit())
            }
        }
        .foregroundStyle(violet)
        .fixedSize()
        .layoutPriority(1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("From \(TemplateMarks.names(from))")
        .accessibilityValue(TemplateMarks.names(from))
        .accessibilityIdentifier(id)
        #if os(macOS)
        .help("From \(TemplateMarks.names(from))")
        #endif
    }
}

/// A line's template icons and its bag's words, side by side at the line's right: the
/// words at most `cap` wide and cut first when the line is short of room, the icons always
/// whole, right beside them (a bag text framed at its full cap would leave a gap between).
struct MarksBeforeBag: Layout {
    var cap: CGFloat
    var spacing: CGFloat = 6

    private func sizes(_ proposal: ProposedViewSize, _ subviews: Subviews) -> [CGSize] {
        guard let marks = subviews.first else { return [] }
        let m = marks.sizeThatFits(.unspecified)
        guard subviews.count > 1 else { return [m] }
        let room = max(0, min(cap, (proposal.width ?? .infinity) - m.width - spacing))
        let t = subviews[1].sizeThatFits(ProposedViewSize(width: room, height: proposal.height))
        return [m, CGSize(width: min(t.width, room), height: t.height)]
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let all = sizes(proposal, subviews)
        let width = all.reduce(0) { $0 + $1.width } + spacing * CGFloat(max(0, all.count - 1))
        return CGSize(width: width, height: all.map(\.height).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let all = sizes(proposal, subviews)
        var x = bounds.maxX
        for (i, sub) in subviews.enumerated().reversed() where i < all.count {
            x -= all[i].width
            sub.place(at: CGPoint(x: x, y: bounds.midY), anchor: .leading, proposal: ProposedViewSize(all[i]))
            x -= spacing
        }
    }
}

/// The round tick of a list's line — a ring, or filled with a white tick — as wide as
/// `Metrics.mark` (18 on the iPhone, 14 on the Mac; until 0.67 a trip's was 20, a
/// to-do's and a grab list's 26). Drawn, like every mark in this app.
struct TickCircle: View {
    let on: Bool
    let tint: Color
    /// The empty ring's colour when it is not the tint (a line set aside: the hairline's).
    var ring: Color? = nil

    var body: some View {
        let s = Metrics.mark
        ZStack {
            Circle().stroke(ring ?? tint, lineWidth: 1.6)
            if on {
                Circle().fill(tint)
                Tick().stroke(Color.white, style: StrokeStyle(lineWidth: s / 10, lineCap: .round, lineJoin: .round))
            }
        }
        .frame(width: s, height: s)
        .accessibilityHidden(true)
    }
}

/// ⊘ (a circle with a slash) to set a line aside, ↻ (an arrow round) to take it
/// back — drawn, like every mark in this app.
struct AsideMark: View {
    let back: Bool
    var body: some View {
        let d = back
            ? "M17.5 9.5A6 6 0 1 0 18 13.5M18 8v3.5h-3.5"
            : "M12 4.5a7.5 7.5 0 1 0 0 15a7.5 7.5 0 1 0 0-15M7 17L17 7"
        SVGPath.path(d)
            .stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
            .frame(width: 24, height: 24)
            .foregroundStyle(Theme.muted)
    }
}

/// A tick mark, drawn — the web app's own (M8.5 12.2 l2.4 2.4 4.6-5), scaled.
struct Tick: Shape {
    func path(in rect: CGRect) -> Path {
        let k = rect.width / 24
        return SVGPath.path("M8.5 12.2l2.4 2.4 4.6-5").applying(CGAffineTransform(scaleX: k, y: k))
    }
}
