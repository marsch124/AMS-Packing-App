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
    init(tripId: String) { self.openedId = tripId }
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    /// His "When" colours are HIS — pale or bright — so they are made readable for
    /// the screen they land on ("Bad text color twice", 2026-09-26).
    @Environment(\.colorScheme) private var scheme
    /// When / Where / Category — remembered on this device, as the web app does.
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
    struct CheckedThing: Identifiable { let id: String }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // His words (2026-09-25): "Where" → "Into" (the bag it goes into), and "From where" —
    // where it is kept at home — "so that I can pick all stuff from a specific location".
    static let views: [(id: String, label: String)] = [("when", "When"), ("container", "Into"), ("stored", "From where"), ("category", "Category")]

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

    private var sortingLabel: some View {
        Text("Sorting")
            .font(.system(size: 15, weight: .heavy)).foregroundStyle(Theme.muted)
            .lineLimit(1).fixedSize()
            .accessibilityIdentifier("trip-view-label")
    }

    /// When · Into · From where · Category — `compact` trims the padding; the words stay
    /// 15 either way (his floor: nothing under 15 — compact used to drop them to 14).
    @ViewBuilder private func sortButtons(compact: Bool) -> some View {
        ForEach(Array(TripScreen.views.enumerated()), id: \.element.id) { n, o in
            let on = view == o.id
            Button { view = o.id } label: {
                Text(o.label)
                    .font(.system(size: 15, weight: on ? .bold : .semibold))
                    .foregroundStyle(on ? Color.white : Theme.ink)
                    .lineLimit(1).fixedSize()
                    .padding(.horizontal, compact ? 8 : 14).frame(minHeight: 36)
                    .background(Capsule().fill(on ? AppSection.events.color : Theme.bg))
                    .overlay(Capsule().stroke(on ? AppSection.events.color : Theme.line, lineWidth: 1))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain).focusEffectDisabled()
            .accessibilityIdentifier("trip-view-\(n)")
            .accessibilityAddTraits(on ? .isSelected : [])
        }
    }

    var body: some View {
        let trip = model.library.trips.first { $0.id == tripId } ?? newEvent()
        let p = progress(trip.entries)
        // Nothing left to decide: every line ticked or set aside. Set aside counts
        // as handled (his choice, 2026-09-23), so it leaves the total.
        let allPacked = p.total > 0 && p.done == p.total
        // Never trap on a repeated id (his E.6 crash, 28 Sep): the first line keeps it.
        let index: [String: Int] = Dictionary(trip.entries.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { first, _ in first })
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(trip.name.isEmpty ? "Untitled event" : trip.name)
                        .font(.system(size: 22, weight: .heavy)).foregroundStyle(Theme.ink)
                        .lineLimit(2).minimumScaleFactor(0.85)          // the whole name, not "Weekend in the…"
                        .accessibilityIdentifier("trip-name")
                    HStack(spacing: 10) {
                        Text(p.aside > 0 ? "\(p.done)/\(p.total) · \(p.aside) set aside" : "\(p.done)/\(p.total)")
                            .font(.system(size: 16, weight: .bold).monospacedDigit())
                            .foregroundStyle(p.total > 0 && p.done == p.total ? AppSection.events.color : Theme.muted)
                            .accessibilityIdentifier("trip-progress")
                            .accessibilityValue(allPacked ? "all packed" : "")
                        // Its settings, after it is made (the gap list's first High item):
                        // beside the count, where there is room even on a small iPhone.
                        TripSettingsDoor(tripId: tripId, rebuilt: { rebuiltNote = TripScreen.saying($0) },
                                         startedAgain: { new in
                            let from = trip.name
                            startedId = new.id
                            rebuiltNote = "New trip from \u{201C}\(from)\u{201D}: \(new.entries.count) things, nothing ticked. Its dates are under the pen."
                        })
                        .environmentObject(model)
                    }
                }
                Spacer()
                // After the trip: what did I use, what did I miss. Once, then it says so —
                // by the one rule every screen uses (the spec pass, 5 Oct 2026: a trip with
                // only a review time looked reviewed on its card and offered Review here).
                if Library.isReviewed(trip) {
                    Text("Reviewed").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.muted)
                        .accessibilityIdentifier("trip-reviewed")
                } else if !trip.entries.isEmpty {
                    Button("Review") { reviewing = true }
                        .buttonStyle(HeaderButtonStyle(tint: AppSection.events.color, filled: false)).focusEffectDisabled()
                        .font(.system(size: 17, weight: .bold)).foregroundStyle(AppSection.events.color)
                        .accessibilityIdentifier("trip-review")
                }
                Button("Done") { dismiss() }
                    .buttonStyle(HeaderButtonStyle(tint: AppSection.events.color, filled: true)).focusEffectDisabled()
                    .font(.system(size: 17, weight: .bold)).foregroundStyle(AppSection.events.color)
                    // Escape closes it, as Done does (the spec pass, 5 Oct 2026 — on the Mac,
                    // and on an iPhone with a keyboard).
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("trip-done")
            }
            .padding(16)
            // Where this trip stands in the loop (his picture, 2026-09-27); a tap shows it whole.
            LoopDoor(here: model.library.loopStep(tripId: tripId, today: Today.local))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16).padding(.top, -6).padding(.bottom, 10)
            if !rebuiltNote.isEmpty {
                Text(rebuiltNote)
                    .font(.system(size: 15, weight: .bold)).foregroundStyle(AppSection.events.color)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).padding(.bottom, 8)
                    .accessibilityIdentifier("trip-rebuilt")
            }
            // His marks (2026-09-25): "Sorting" on the left, the buttons on the same line —
            // now four of them. They fit on the Mac and a wide iPhone; a narrower screen
            // gets slimmer buttons, and failing that "Sorting" moves just above them.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { sortingLabel; Spacer(minLength: 8); sortButtons(compact: false) }
                HStack(spacing: 6) { sortingLabel; Spacer(minLength: 6); sortButtons(compact: true) }
                VStack(alignment: .leading, spacing: 6) {
                    sortingLabel
                    HStack(spacing: 6) { sortButtons(compact: true) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            KeyboardAwayScroll {
                // The card is deliberately OUTSIDE the lazy stack: a lazy row is
                // thrown away and rebuilt as it scrolls off, which loses what he
                // has typed into it (found by the test, 2026-09-23).
                VStack(alignment: .leading, spacing: 4) {
                // Check before you go (his ideas 4 and 5): first, and only when something needs him.
                TripChecksCard(tripId: trip.id) { checking = CheckedThing(id: $0) }.environmentObject(model)
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
                LazyVStack(alignment: .leading, spacing: 4) {
                    // One level of groups; inside a group the lines keep the trip's own order.
                    // (The web app nests: When → by bag inside; the others → by When inside.)
                    ForEach(Array(groupBy(view, trip.entries).enumerated()), id: \.offset) { g, group in
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
                                        .frame(width: 20, height: 20)
                                        .rotationEffect(.degrees(folded ? 0 : 90))
                                        .foregroundStyle(Theme.ink)
                                        .frame(width: 34, height: 36).contentShape(Rectangle())
                                }
                                .buttonStyle(.plain).focusEffectDisabled()
                                .accessibilityIdentifier("trip-group-\(g)-fold")
                                .accessibilityLabel(folded ? "Open \(group.label)" : "Fold \(group.label)")
                                Text(group.label)
                                    .font(.system(size: 15, weight: .heavy))
                                    .foregroundStyle(view == "when" ? Color(hexString: readableHex(phaseColor(group.entries[0].phase), dark: scheme == .dark)) : AppSection.events.color)
                                    .accessibilityIdentifier("trip-group-\(g)-label")
                                    .onTapGesture { toggleFold(group.label) }
                                Text("\(mine.filter { $0.checked }.count)/\(mine.count)")
                                    .font(.system(size: 15, weight: .bold).monospacedDigit())
                                    .foregroundStyle(Theme.muted)
                                Spacer()
                                // Only while the section has something to tick: with every line set
                                // aside there is nothing, and a switched-off grey circle is what his
                                // rule forbids (the spec pass, 5 Oct 2026) — the space stays, so the
                                // heading does not jump.
                                if mine.isEmpty {
                                    Color.clear.frame(width: 40, height: 36)
                                } else {
                                    Button {
                                        model.change { lib in
                                            for line in mine { _ = lib.setChecked(!sectionDone, tripId: tripId, entryId: line.id) }
                                        }
                                    } label: {
                                        ZStack {
                                            Circle().stroke(sectionDone ? AppSection.events.color : Theme.line, lineWidth: 2)
                                                .frame(width: 24, height: 24)
                                            if sectionDone {
                                                Circle().fill(AppSection.events.color).frame(width: 24, height: 24)
                                                Tick().stroke(Color.white, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                                                    .frame(width: 24, height: 24)
                                            }
                                        }
                                        .frame(width: 40, height: 36).contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain).focusEffectDisabled()
                                    .accessibilityIdentifier("trip-group-\(g)-all")
                                    .accessibilityLabel(sectionDone ? "Untick \(group.label)" : "Tick all of \(group.label)")
                                    .accessibilityAddTraits(sectionDone ? .isSelected : [])
                                }
                            }
                            .padding(.top, 12)
                            if !folded {
                            ForEach(group.entries, id: \.id) { line in
                                let n = index[line.id] ?? 0
                                let aside = isSetAside(line)
                                let needsPlace = view == "stored" && group.label == "No place set"
                                VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 4) {
                                    Button {
                                        if !aside { model.change { _ = $0.setChecked(!line.checked, tripId: tripId, entryId: line.id) } }
                                    } label: {
                                        PackLine(line: line, nights: qtyNights(trip), tint: Color(hexString: readableHex(phaseColor(line.phase), dark: scheme == .dark, graphic: true)),
                                                 showBag: view != "container", washed: washes(trip))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("trip-line-\(n)")
                                    .accessibilityValue(PackLine.count(line, qtyNights(trip), washed: washes(trip)))
                                    .accessibilityAddTraits(line.checked ? .isSelected : [])
                                    // ⊘ "not this time" — one tap, his call, no confirmation; ↻ takes it back.
                                    Button {
                                        model.change { _ = $0.setAside(!aside, tripId: tripId, entryId: line.id) }
                                    } label: {
                                        AsideMark(back: aside)
                                            .frame(width: 40, height: 40)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain).focusEffectDisabled()
                                    .accessibilityIdentifier("trip-line-\(n)-aside")
                                    .accessibilityLabel(aside ? "Take it this time" : "Not this time")
                                }
                                // On its own line under the name, so the name keeps its width.
                                if needsPlace {
                                    if placing == line.id { placePanel(line) }
                                    else {
                                        Button { placing = line.id; newPlace = ""; placeNeeds = "" } label: {
                                            Text("Set place").font(.system(size: 15, weight: .bold))
                                                .foregroundStyle(AppSection.events.color)
                                                .padding(.horizontal, 10).frame(minHeight: 30)
                                                .overlay(Capsule().stroke(AppSection.events.color, lineWidth: 1.2))
                                                .contentShape(Capsule())
                                        }
                                        .buttonStyle(.plain).focusEffectDisabled()
                                        .padding(.leading, 44).padding(.bottom, 4)
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
                                .id("\(line.id)|\(line.checked)|\(aside)|\(group.label)|\(placing == line.id)|\(qtyNights(trip))")
                            }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)

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
                // Last on the screen, quiet and red, and it asks first — his rule for
                // removing anything. His two test trips had no way out (2026-09-26).
                deleteTrip(trip)
                    .padding(.horizontal, 16).padding(.top, 18)
                }
                .padding(.bottom, 24)
            }
            .sheet(item: $checking) { c in ThingEditor(itemId: c.id).environmentObject(model) }
            // "Also the tripod" — a thing for THIS trip only, typed on the spot.
            HStack(spacing: 8) {
                TextField("Add a thing to this trip", text: $newName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 17, weight: .medium)).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 12).frame(minHeight: 44)
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
                        Text("Bought on site").font(.system(size: 16, weight: .bold))
                            .lineLimit(1).fixedSize()
                            .foregroundStyle(AppSection.events.color)
                            .padding(.horizontal, 12).frame(minHeight: 44)
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
    }

    /// His places, one tap each; or a new one typed. The thing keeps the place.
    private func placePanel(_ line: Item) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Where is \(line.name) kept?")
                    .font(.system(size: 15, weight: .heavy)).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Button("Close") { placing = nil; newPlace = ""; placeNeeds = "" }
                    .buttonStyle(HeaderButtonStyle(tint: Theme.muted, filled: false)).focusEffectDisabled()
                    .font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.muted)
                    .accessibilityIdentifier("trip-place-close")
            }
            FlowRow(spacing: 6) {
                ForEach(Array(model.library.storagePlaces().enumerated()), id: \.offset) { i, place in
                    Button { putAway(line, place) } label: {
                        Text(place).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink)
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
                    .font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 10).frame(minHeight: 36)
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
                    Text("Save").font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 14).frame(minHeight: 36)
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
        .padding(.leading, 44).padding(.bottom, 6)
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
                    .font(.system(size: 16, weight: .heavy)).foregroundStyle(Theme.ink)
                Text("The trip and its \(trip.entries.count) line\(trip.entries.count == 1 ? "" : "s") go. Your things and your templates stay.")
                    .font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    Button("Keep it") { askingToDelete = false }
                        .buttonStyle(.plain).focusEffectDisabled()
                        .font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.ink)
                        .accessibilityIdentifier("trip-delete-no")
                    Spacer()
                    Button {
                        let id = tripId
                        dismiss()
                        model.change { _ = $0.deleteTrip(id: id) }
                        foldedRaw = TripFolds.without(trip: id, in: foldedRaw)     // its folds go with it
                    } label: {
                        Text("Delete the trip")
                            .font(.system(size: 16, weight: .heavy)).foregroundStyle(.white)
                            .padding(.horizontal, 14).frame(minHeight: 40)
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
                    Text("On site").font(.system(size: 17, weight: .heavy)).foregroundStyle(Theme.ink)
                    // 15 (it was 14, shrinking to 85 %): it wraps rather than shrinks.
                    Text(says)
                        .font(.system(size: 15, weight: .medium).monospacedDigit()).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
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
        .sheet(isPresented: $onSite) { OnSiteScreen(tripId: trip.id).environmentObject(model) }
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
        HStack(spacing: 12) {
            ZStack {
                Circle().stroke(aside ? Theme.line : tint, lineWidth: 2).frame(width: 26, height: 26)
                if line.checked && !aside {
                    Circle().fill(tint).frame(width: 26, height: 26)
                    Tick().stroke(Color.white, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                        .frame(width: 26, height: 26)
                }
            }
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(line.name)
                    .font(.system(size: 17, weight: line.checked ? .regular : .medium))
                    .foregroundStyle(aside ? Theme.muted : (line.checked ? Theme.muted : Theme.ink))
                    .strikethrough(aside, pattern: .solid, color: Theme.muted)
                    .lineLimit(2)
                if Library.isBoughtOnSite(line) {
                    Text("Bought on site").font(.system(size: 15, weight: .bold)).foregroundStyle(AppSection.events.color)
                }
            }
            Spacer(minLength: 8)
            if qty > 1 {
                Text("×\(qty.rounded() == qty ? String(Int(qty)) : String(qty))")
                    .font(.system(size: 15, weight: .bold).monospacedDigit()).foregroundStyle(Theme.muted)
                if washed && line.perNight {
                    LaundryMark().frame(width: 18, height: 18).foregroundStyle(Theme.muted)
                }
            }
            if showBag {
                Text(line.container)
                    .font(.system(size: 15)).foregroundStyle(Theme.muted).lineLimit(2)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 150, alignment: .trailing)
            }
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
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
