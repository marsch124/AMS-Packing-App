import SwiftUI
import PackingCore
import PackingLibrary

// The Packing day (0.79, spec 07 part 17) — his yes of 13 Oct 2026, from his own packing
// walk-through: the bags out on the floor, pack, weigh, name tags and AirTags, photos for lost
// luggage, ready. On a trip being packed, a slim row of STATIONS under the loop strip — Bags out
// · Pack · Weigh · Tags · Photos · Ready — each green when done; a tap opens it in the Packing
// day sheet (Pack goes to the list), and the sheet offers the next open one. What each station
// asks and when it is done is the model's (`PackingLibrary/PackingDay.swift`); the weighing and
// the bag photos are the Bags card's own.

/// A station's (or the day's) mark, drawn like the loop's step marks: one 1.9 stroke on the
/// 24-point grid, in the colour around it.
struct StationMark: View {
    let mark: LoopStepMark
    var size: Double

    var body: some View { IconMark(path: mark.path, size: size, weight: 1.9).accessibilityHidden(true) }
}

/// One station chip: its mark and its short name — Pack with its count. Done: green, white
/// words; the one highlighted (the next to do on the trip, the one shown in the sheet): a light
/// green with a stronger ring — done and highlighted, green with a white ring inside; open: the
/// card with a green line; cannot (no bags): muted, dashed.
struct StationChip: View {
    enum Look { case done, doneHere, here, open, cannot }
    let station: PackingDayStation
    let look: Look
    /// "12/40" after Pack's name; "" for the others.
    var count = ""
    @Environment(\.colorScheme) private var scheme

    #if os(macOS)
    static let markSize: Double = 13
    #else
    static let markSize: Double = 15
    #endif

    var body: some View {
        let tint = Library.LoopStep.pack.tint
        let words: Color = switch look {
        case .done, .doneHere: .white
        case .cannot: Theme.muted
        default: Library.LoopStep.pack.words(scheme)
        }
        HStack(spacing: 5) {
            StationMark(mark: station.mark, size: StationChip.markSize)
            Text(station.name).font(.system(.footnote, weight: .semibold)).lineLimit(1).fixedSize()
            if !count.isEmpty {
                Text(count).font(.system(.footnote, weight: .semibold).monospacedDigit()).lineLimit(1).fixedSize()
                    .opacity(look == .done || look == .doneHere ? 1 : 0.85)
            }
        }
        .foregroundStyle(words)
        .padding(.horizontal, 9).frame(minHeight: Metrics.chip)
        .background(Capsule().fill(look == .done || look == .doneHere ? tint : look == .here ? tint.opacity(0.14) : Theme.card))
        .overlay {
            switch look {
            case .done: EmptyView()
            // Done AND the one highlighted (shown in the sheet; on the trip, Ready once all is
            // green): a white ring just inside the green, so it never grows past its row.
            case .doneHere: Capsule().strokeBorder(Color.white.opacity(0.85), lineWidth: 1.5).padding(2.5)
            case .here: Capsule().stroke(tint, lineWidth: 2)
            case .open: Capsule().stroke(tint.opacity(0.7), lineWidth: 1.2)
            case .cannot: Capsule().stroke(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
        }
        .contentShape(Capsule())
    }
}

/// The six chips. `highlight` is the station lit as "here"; a tap gives the station. In the
/// sheet they wrap (`FlowRow`); on the trip screen they stand in ONE line (`PackingDayRow`).
struct StationChips: View {
    let day: PackingDay
    let highlight: PackingDayStation
    /// "day-station" on the trip screen, "day-sheet-station" in the sheet: `<prefix>-<key>`.
    let idPrefix: String
    var wraps = false
    let tap: (PackingDayStation) -> Void

    var body: some View {
        if wraps {
            FlowRow(spacing: 6) { chips }
        } else {
            HStack(spacing: 6) { chips }
        }
    }

    @ViewBuilder private var chips: some View {
        ForEach(PackingDayStation.allCases) { s in
            let look: StationChip.Look = !day.usable(s) ? .cannot : s == highlight ? .here : day.done(s) ? .done : .open
            Button { tap(s) } label: {
                StationChip(station: s, look: s == highlight && day.done(s) ? .doneHere : look,
                            count: s == .pack && day.total > 0 ? "\(day.packed)/\(day.total)" : "")
            }
            .buttonStyle(.plain).focusEffectDisabled()
            .id(s.rawValue)
            .accessibilityIdentifier("\(idPrefix)-\(s.rawValue)")
            .accessibilityLabel(s.name)
            .accessibilityValue(day.state(s))
            .accessibilityAddTraits(s == highlight ? .isSelected : [])
        }
    }
}

/// The trip screen's row: the day's mark and "Packing day", then the chips — the next station
/// to do highlighted. ONE line where it fits (a wide Mac window); else, on the iPhone, the whole
/// line scrolls sideways, from one edge of the screen to the other, and keeps the next station
/// (and the one after it) in view; on a narrow Mac window the chips wrap onto a second line.
struct PackingDayRow: View {
    let day: PackingDay
    /// The screen's margin: the sideways scroll reaches past it to the edges.
    var margin: CGFloat = 16
    let tap: (PackingDayStation) -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ViewThatFits(in: .horizontal) {
            line.fixedSize()
                .frame(maxWidth: .infinity, alignment: .leading)
            #if os(macOS)
            // A narrow Mac window: the chips wrap onto a second line — a mouse wheel does not
            // scroll sideways (GitHub's Mac, 0.79: the trip's 520-point window cut Ready off).
            HStack(alignment: .top, spacing: 8) {
                title
                StationChips(day: day, highlight: day.current, idPrefix: "day-station", wraps: true, tap: tap)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            #else
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    line.padding(.horizontal, margin).padding(.vertical, 1)
                }
                .padding(.horizontal, -margin)
                // The least scrolling that shows the next station and the one after it: at the start
                // nothing moves (the title stays in view), towards the end it comes along.
                .onAppear { proxy.scrollTo(PackingDayRow.inView(day.current)) }
                .onChange(of: day.current) { _, now in withAnimation { proxy.scrollTo(PackingDayRow.inView(now)) } }
            }
            #endif
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("day-row")
    }

    /// The chip to keep in view for the next station: the one after it (so both show), or Ready.
    static func inView(_ next: PackingDayStation) -> String {
        let all = PackingDayStation.allCases
        let k = all.firstIndex(of: next) ?? 0
        return all[min(k + 1, all.count - 1)].rawValue
    }

    private var line: some View {
        HStack(spacing: 8) {
            title
            StationChips(day: day, highlight: day.current, idPrefix: "day-station", tap: tap)
        }
    }

    private var title: some View {
        HStack(spacing: 5) {
            StationMark(mark: PackingDayStation.dayMark, size: 17)
            Text("Packing day").font(.system(.footnote, weight: .semibold)).lineLimit(1).fixedSize()
        }
        .foregroundStyle(Library.LoopStep.pack.words(scheme))
        .frame(minHeight: Metrics.chip)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Packing day")
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("day-title")
    }
}

// MARK: - The sheet

/// The Packing day: the row again, the station shown, and the next open one offered.
struct PackingDaySheet: View {
    let tripId: String
    /// Pack is the trip's list: the sheet closes and the trip goes to it.
    let toList: () -> Void
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var shown: PackingDayStation
    /// Weigh: the bag whose reading is being typed, what is typed, what Save was missing.
    @State private var weighing: String?
    @State private var scaleText = ""
    @State private var weighNeeds = ""
    @FocusState private var typing: Bool
    /// The bag whose Lost bag page is open, from Photos or Ready (0.80, spec 07 part 18 C).
    @State private var lost: LostBagOpen?

    /// Opened by itself, on Weigh, when the last thing was ticked: the trip keeps that it was
    /// offered once it is really on screen — never again on this trip.
    let byItself: Bool

    /// Told when the sheet is really on screen.
    let appeared: () -> Void

    init(tripId: String, start: PackingDayStation, byItself: Bool = false, appeared: @escaping () -> Void = {},
         toList: @escaping () -> Void) {
        self.tripId = tripId
        self.byItself = byItself
        self.appeared = appeared
        self.toList = toList
        _shown = State(initialValue: start == .pack ? .bagsOut : start)
    }

    private var tint: Color { AppSection.events.color }

    var body: some View {
        let day = model.library.packingDay(tripId: tripId) ?? PackingDay(bags: [], packed: 0, total: 0)
        let trip = model.library.trips.first { $0.id == tripId }
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        StationMark(mark: PackingDayStation.dayMark, size: 22)
                            .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] + 6 }
                        Text("Packing day").font(.system(.title3, weight: .bold))
                    }
                    .foregroundStyle(Library.LoopStep.pack.words(scheme))
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("day-heading")
                    Text(trip?.name ?? "").font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(HeaderButtonStyle(tint: tint, filled: true)).focusEffectDisabled()
                    .keyboardShortcut(.cancelAction)            // Escape closes it, as Done does
                    .accessibilityIdentifier("day-done")
            }
            .padding(16)
            StationChips(day: day, highlight: shown, idPrefix: "day-sheet-station", wraps: true) { go($0) }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16).padding(.bottom, 6)
            KeyboardAwayScroll {
                VStack(alignment: .leading, spacing: 10) {
                    Group {
                        if !day.usable(shown) {
                            noBags
                        } else {
                            switch shown {
                            case .bagsOut, .pack: bagsOut(day)
                            case .weigh: weigh(day)
                            case .tags: tags(day)
                            case .photos: photos(day)
                            case .ready: ready(day, trip)
                            }
                        }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("day-view-\(shown.rawValue)")
                    if let next = day.next(after: shown) {
                        Button { go(next) } label: {
                            Text("Next: \(next.name)").font(.system(.body, weight: .semibold)).foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: Metrics.tap)
                                .background(RoundedRectangle(cornerRadius: 12).fill(tint))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).focusEffectDisabled()
                        .padding(.top, 8)
                        .accessibilityIdentifier("day-next")
                        .accessibilityValue(next.rawValue)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 24)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .onAppear {
            openFirstUnweighed(day)
            appeared()
            if byItself {
                let id = tripId
                model.change { _ = $0.setWeighOffered(tripId: id) }
            }
        }
        .onChange(of: shown) { _, _ in openFirstUnweighed(model.library.packingDay(tripId: tripId)) }
        .sheet(item: $lost) { open in LostBagScreen(tripId: tripId, bag: open.bag).environmentObject(model) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("day-sheet")
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 600)
        #endif
    }

    /// Pack is the list: the sheet closes and the trip goes there. The others show here.
    private func go(_ s: PackingDayStation) {
        if s == .pack {
            dismiss()
            toList()
        } else {
            weighNeeds = ""
            shown = s
        }
    }

    private func lead(_ words: String) -> some View {
        Text(words).font(.system(.footnote)).foregroundStyle(Theme.muted)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func said(_ words: String, id: String) -> some View {
        HStack(spacing: 6) {
            Tick().stroke(style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                .frame(width: 14, height: 12)
            Text(words).font(.system(.subheadline, weight: .semibold))
        }
        .foregroundStyle(tint)
        .padding(.top, 2)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(id)
    }

    private var noBags: some View {
        Text("No bags on this trip yet. Give its things a bag \u{2014} Usually packed in, on a thing\u{2019}s page \u{2014} and they show here.")
            .font(.system(.subheadline)).foregroundStyle(Theme.ink)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("day-nobags")
    }

    /// A row with a tick: the tick circle, the words, and something quiet at the right.
    private func tickRow(_ title: String, on: Bool, detail: String = "", id: String, value: (on: String, off: String),
                         font: Font = .system(.body), _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            HStack(spacing: 8) {
                TickCircle(on: on, tint: tint, ring: on ? nil : Theme.line)
                Text(title).font(font).foregroundStyle(Theme.ink).lineLimit(2)
                Spacer(minLength: 8)
                if !detail.isEmpty {
                    Text(detail).font(.system(.footnote).monospacedDigit()).foregroundStyle(Theme.muted).lineLimit(1)
                }
            }
            .padding(.vertical, 2)
            .frame(minHeight: Metrics.line)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier(id)
        .accessibilityValue(on ? value.on : value.off)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    // MARK: Bags out

    private func bagsOut(_ day: PackingDay) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            lead("Lay every bag out where you pack, and tick it as it comes out.")
            VStack(spacing: 0) {
                ForEach(Array(day.bags.enumerated()), id: \.element.name) { n, bag in
                    tickRow(bag.name, on: bag.out, detail: "\(bag.things) thing\(bag.things == 1 ? "" : "s")",
                            id: "day-bag-\(n)", value: ("out", "not out")) {
                        let t = tripId, name = bag.name, on = !bag.out
                        model.change { _ = $0.setBagOut(on, tripId: t, bag: name) }
                    }
                    .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
                }
            }
            if day.done(.bagsOut) { said("All bags are out.", id: "day-bags-said") }
        }
    }

    // MARK: Weigh — the Bags card's luggage scale, one bag after another

    private func openFirstUnweighed(_ day: PackingDay?) {
        guard shown == .weigh, let day else { return }
        weighing = day.bags.first { ($0.scaleGrams ?? 0) <= 0 }?.name
        scaleText = ""
    }

    private func weigh(_ day: PackingDay) -> some View {
        let rows = model.library.weighedBags(tripId: tripId)
        return VStack(alignment: .leading, spacing: 10) {
            lead("One bag after another: hang it on the luggage scale and type what it says.")
            ForEach(Array(day.bags.enumerated()), id: \.element.name) { n, bag in
                if let w = rows.first(where: { $0.load.container == bag.name }) {
                    VStack(alignment: .leading, spacing: 8) {
                        Button { open(w) } label: { BagWeightRow(bag: w) }
                            .buttonStyle(.plain).focusEffectDisabled()
                            .accessibilityIdentifier("day-weigh-\(n)")
                            .accessibilityValue(BagsCard.gauge(w))
                        if weighing == bag.name { scaleField(w, n: n, day: day) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(w.over ? AppSection.actions.color : Theme.line, lineWidth: 1))
                }
            }
            if day.done(.weigh) { said("Every bag is weighed.", id: "day-weigh-said") }
        }
    }

    private func open(_ w: WeighedBag) {
        weighNeeds = ""
        if weighing == w.load.container { weighing = nil; return }
        weighing = w.load.container
        scaleText = w.scaleGrams.map { BagsCard.number(($0 / 100).rounded() / 10) } ?? ""
    }

    private func scaleField(_ w: WeighedBag, n: Int, day: PackingDay) -> some View {
        HStack(spacing: 8) {
            TextField("kg on the scale", text: $scaleText)
                .textFieldStyle(.plain)
                .font(.system(.body, weight: .semibold).monospacedDigit()).foregroundStyle(Theme.ink)
                .padding(.horizontal, 10).frame(height: 40)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bg))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 1))
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
                .focused($typing)
                .onSubmit { save(w, day: day) }
                .accessibilityIdentifier("day-weigh-\(n)-scale")
            // Always in full colour (his rule); with nothing typed it says so under it.
            Button { save(w, day: day) } label: {
                Text("Save").font(.system(.callout, weight: .semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 12).frame(minHeight: Metrics.compact)
                    .background(Capsule().fill(tint))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain).focusEffectDisabled()
            .accessibilityIdentifier("day-weigh-\(n)-save")
            if w.scaleGrams != nil {
                Button("Clear") {
                    let t = tripId, bag = w.load.container
                    model.change { _ = $0.setWeighed(tripId: t, bag: bag, grams: nil) }
                    scaleText = ""
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.muted)
                .accessibilityIdentifier("day-weigh-\(n)-clear")
            }
        }
        .needsLine($weighNeeds, typed: scaleText, id: "day-weigh-needs")
    }

    /// Keep what the scale says, and open the next bag that has no reading yet.
    private func save(_ w: WeighedBag, day: PackingDay) {
        let clean = jsTrim(scaleText).replacingOccurrences(of: ",", with: ".")
        guard let kg = Double(clean), kg > 0, kg.isFinite else {
            weighNeeds = "Type what the scale says, in kg."
            return
        }
        let t = tripId, bag = w.load.container
        model.change { _ = $0.setWeighed(tripId: t, bag: bag, grams: kg * 1000) }
        weighNeeds = ""
        scaleText = ""
        let after = model.library.packingDay(tripId: tripId)?.bags ?? day.bags
        let next = after.first { $0.name != bag && ($0.scaleGrams ?? 0) <= 0 }
        weighing = next?.name
        if next == nil { typing = false }
    }

    // MARK: Tags

    private func tags(_ day: PackingDay) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            lead("A name tag on every bag, and the AirTag in each bag that has one.")
            ForEach(Array(day.bags.enumerated()), id: \.element.name) { n, bag in
                VStack(alignment: .leading, spacing: 2) {
                    Text(bag.name).font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.ink)
                        .padding(.bottom, 2)
                    tickRow("Name tag", on: bag.nameTag, id: "day-tag-\(n)-name", value: ("on", "off")) {
                        let t = tripId, name = bag.name, on = !bag.nameTag
                        model.change { _ = $0.setNameTag(on, tripId: t, bag: name) }
                    }
                    if bag.hasAirTag {
                        tickRow("AirTag in it", on: bag.airTag, id: "day-tag-\(n)-air", value: ("on", "off")) {
                            let t = tripId, name = bag.name, on = !bag.airTag
                            model.change { _ = $0.setAirTagIn(on, tripId: t, bag: name) }
                        }
                    }
                    Toggle(isOn: Binding(get: { bag.hasAirTag },
                                         set: { on in let name = bag.name; model.change { _ = $0.setAirTag(container: name, on) } })) {
                        Text("Has an AirTag").font(.system(.footnote, weight: .semibold)).foregroundStyle(Theme.muted)
                    }
                    .tint(tint)
                    #if os(iOS)
                    .controlSize(.mini)
                    #else
                    .controlSize(.small)
                    #endif
                    .padding(.top, 4)
                    .accessibilityIdentifier("day-tag-\(n)-has")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
            }
            if day.done(.tags) { said("Every tag is on.", id: "day-tags-said") }
        }
    }

    // MARK: Photos

    private func photos(_ day: PackingDay) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if day.groupPhotoAsked {
                VStack(alignment: .leading, spacing: 6) {
                    Text("All your bags").font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.ink)
                    lead("One photo of all of them side by side: for the airline desk if one goes missing.")
                    GroupPhotoRow(tripId: tripId).environmentObject(model)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
            } else {
                lead("A photo of the bag packed \u{2014} to repack from, and for the airline desk if it goes missing.")
            }
            ForEach(Array(day.bags.enumerated()), id: \.element.name) { n, bag in
                VStack(alignment: .leading, spacing: 6) {
                    Text(bag.name).font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.ink)
                    BagPhotoRow(tripId: tripId, bag: bag.name, n: n, prefix: "day-photo-\(n)").environmentObject(model)
                    // The photos are for the airline desk: the bag's whole Lost bag page is one tap away (0.80).
                    HStack {
                        Spacer(minLength: 0)
                        LostBagDoor(id: "day-photo-\(n)-lost") { lost = LostBagOpen(bag: bag.name) }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
            }
            if day.done(.photos) { said("Every photo is taken.", id: "day-photos-said") }
        }
    }

    // MARK: Ready — and the door check

    private func ready(_ day: PackingDay, _ trip: TripEvent?) -> some View {
        let others = PackingDayStation.allCases.filter { $0 != .ready }
        let left = others.filter { day.usable($0) && !day.done($0) }.count
        return VStack(alignment: .leading, spacing: 10) {
            VStack(spacing: 0) {
                ForEach(others) { s in
                    Button { go(s) } label: {
                        HStack(spacing: 8) {
                            StationMark(mark: s.mark, size: 18)
                                .foregroundStyle(day.done(s) ? tint : day.usable(s) ? Theme.ink : Theme.muted)
                            Text(s.name).font(.system(.body)).foregroundStyle(day.usable(s) ? Theme.ink : Theme.muted)
                            Spacer(minLength: 8)
                            if day.done(s) {
                                HStack(spacing: 5) {
                                    Tick().stroke(style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                                        .frame(width: 13, height: 11)
                                    Text("done").font(.system(.subheadline, weight: .semibold))
                                }
                                .foregroundStyle(tint)
                            } else {
                                Text(day.usable(s) ? day.words(s) : "no bags yet")
                                    .font(.system(.subheadline).monospacedDigit()).foregroundStyle(day.usable(s) ? Theme.ink : Theme.muted)
                            }
                        }
                        .frame(minHeight: Metrics.row)
                        .contentShape(Rectangle())
                        .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("day-ready-\(s.rawValue)")
                    .accessibilityLabel(s.name)
                    .accessibilityValue(day.state(s))
                }
            }
            if day.ready {
                Text("Ready to go").font(.system(.title2, weight: .bold)).foregroundStyle(tint)
                    .accessibilityIdentifier("day-ready-go")
            } else {
                Text("Not yet \u{2014} \(left) station\(left == 1 ? "" : "s") left.")
                    .font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.muted)
                    .accessibilityIdentifier("day-ready-left")
            }
            // If a bag goes missing (0.80, spec 07 part 18 C): each bag's Lost bag page, and how much
            // of it is still not filled in — ready means the desk's answers are ready too.
            if !day.bags.isEmpty { lostRows(day) }
            // The door check, right here: the trip's "I leave at", saved at once.
            if let trip {
                LeaveTimes(out: leaveBinding(trip, home: false), home: leaveBinding(trip, home: true),
                           id: "day-leave", tint: tint)
                    .padding(.top, 4)
            }
        }
    }

    private func lostRows(_ day: PackingDay) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("If a bag goes missing").font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.ink)
                .padding(.bottom, 2)
                .accessibilityAddTraits(.isHeader)
            ForEach(Array(day.bags.enumerated()), id: \.element.name) { n, bag in
                let page = model.library.lostBag(tripId: tripId, bag: bag.name)
                let words = page?.shortWords ?? ""
                Button { lost = LostBagOpen(bag: bag.name) } label: {
                    HStack(spacing: 8) {
                        Text("Lost bag: \(bag.name)").font(.system(.body)).foregroundStyle(Theme.ink).lineLimit(1)
                        Spacer(minLength: 8)
                        Text(words).font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(page?.missing == 0 ? tint : AppSection.care.color).lineLimit(1)
                        SVGPath.path("M9 6l6 6-6 6").stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                            .onGrid(Metrics.glyph).foregroundStyle(Theme.faint)
                    }
                    .frame(minHeight: Metrics.row)
                    .contentShape(Rectangle())
                    .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("day-ready-lost-\(n)")
                .accessibilityLabel("Lost bag: \(bag.name)")
                .accessibilityValue(words)
            }
        }
        .padding(.top, 6)
    }

    private func leaveBinding(_ trip: TripEvent, home: Bool) -> Binding<String> {
        let id = trip.id
        return Binding(get: { model.library.trips.first { $0.id == id }.map { Library.leaveTime($0, home: home) } ?? "" },
                       set: { time in model.change { _ = $0.setLeaveTime(time, home: home, tripId: id) } })
    }
}

/// The ONE photo of all a trip's bags together (the Packing day's Photos, spec 07 part 17): its
/// thumbnail and Remove, or the way to take or choose one — as a bag's own photos are taken.
struct GroupPhotoRow: View {
    let tripId: String
    @EnvironmentObject var model: LibraryModel
    @State private var large = false

    var body: some View {
        let photo = model.library.groupPhoto(tripId: tripId).flatMap { JPEG.image(dataURL: $0.data) }
        HStack(alignment: .top, spacing: 12) {
            if let photo {
                VStack(spacing: 2) {
                    Button { large = true } label: {
                        Image(decorative: photo, scale: 1).resizable().scaledToFill()
                            .frame(width: 80, height: 80).clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("day-group-thumb")
                    .accessibilityLabel("Photo of all your bags")
                    Button("Remove") {
                        let t = tripId
                        model.change { _ = $0.removeGroupPhoto(tripId: t) }
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.muted)
                    .frame(minWidth: 80, minHeight: 34).contentShape(Rectangle())
                    .accessibilityIdentifier("day-group-remove")
                }
                .sheet(isPresented: $large) { BigPhoto(images: [photo], captions: ["All your bags"]) }
            } else {
                PhotoTakers(id: "day-group-photo", testTitle: "Photo of all the bags") { keep($0) }
            }
        }
    }

    private func keep(_ jpeg: Data?) {
        guard let jpeg else { return }
        let t = tripId
        model.change { _ = $0.setGroupPhoto(tripId: t, jpeg: jpeg) }
    }
}

/// The Bags card's first row, opened, when the trip has a photo of all its bags: the thumbnail
/// and "All your bags"; a tap shows it large — at every step, for the airline desk.
struct GroupPhotoLine: View {
    let tripId: String
    @EnvironmentObject var model: LibraryModel
    @State private var large = false

    var body: some View {
        if let photo = model.library.groupPhoto(tripId: tripId).flatMap({ JPEG.image(dataURL: $0.data) }) {
            Button { large = true } label: {
                HStack(spacing: 10) {
                    Image(decorative: photo, scale: 1).resizable().scaledToFill()
                        .frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 6))
                    Text("All your bags").font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.ink)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain).focusEffectDisabled()
            .accessibilityIdentifier("bags-group-thumb")
            .accessibilityLabel("Photo of all your bags")
            .sheet(isPresented: $large) { BigPhoto(images: [photo], captions: ["All your bags"]) }
        }
    }
}

// MARK: - How it works

/// The Packing day's part of How it works (0.79) — his ask of 13 Oct 2026: "remember to write
/// about the Packing-Day-Stations in the How-this-works". What it is and where it sits; each
/// station in order, with its own mark, what the mark shows, what it does and what turns it green;
/// how to get from one to the next; a trip without bags. Container `guide-packingday`; each
/// station one element `guide-day-<key>` (its name, what its mark shows, its words), its mark
/// an element of its own, `guide-day-<key>-mark` (label = what it shows), as the loop's marks are.
struct PackingDayGuideCard: View {
    @Environment(\.colorScheme) private var scheme

    /// What each station does and when it turns green — the card's words, one per station.
    static func says(_ s: PackingDayStation) -> String {
        switch s {
        case .bagsOut:
            return "Lay every bag out where you pack, and tick it as it comes out. The bags are the ones your list packs into \u{2014} \u{201C}Not in a bag\u{201D} is not one. Green when every bag is out."
        case .pack:
            return "The trip\u{2019}s own list. Its station shows how far you are \u{2014} 12/40 \u{2014} and a tap takes you straight to the list. Green when everything is packed; a thing set aside \u{2298} counts as done."
        case .weigh:
            return "The luggage scale, one bag after another: hang it on the scale, type what it says, Save \u{2014} the next bag comes up. It is the same weight as in Bags. When you tick the last thing on the list, Weigh opens by itself \u{2014} once per trip. Green when every bag is weighed."
        case .tags:
            return "A Name tag tick for every bag, and an AirTag tick for each bag that has one. Has an AirTag is the bag\u{2019}s own switch \u{2014} under the bag here, or on its page in Care \u{2192} Bags; switch it on once and every trip asks for it. Green when every tick is on."
        case .photos:
            return "One photo of all your bags side by side, and each bag\u{2019}s own photo (the same ones as in Bags) \u{2014} for the airline desk if a bag goes missing. With one bag, its own photo is enough. The photo of all of them stays in Bags after you leave. Green when every photo is there."
        case .ready:
            return "Every station, done or what is left \u{2014} tap one to open it \u{2014} and Ready to go once all are green. I leave at is right there: 15 minutes before, the iPhone names what is still unticked."
        }
    }

    var body: some View {
        let tint = Library.LoopStep.pack.tint
        let words = Library.LoopStep.pack.words(scheme)
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                StationMark(mark: PackingDayStation.dayMark, size: 24).foregroundStyle(words)
                Text("Packing day").font(.system(.body, weight: .semibold)).foregroundStyle(Theme.ink)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("guide-day-title")
            Text("On a trip you are packing, a row sits right under the loop: Packing day, then six stations in the order you go through them. A station turns green when it is done; the next one to do is lit. On the iPhone the row slides sideways.")
                .font(.system(.callout)).foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(Array(PackingDayStation.allCases.enumerated()), id: \.element) { n, s in
                HStack(alignment: .top, spacing: 10) {
                    // The station as it looks when done — its mark in white on the green.
                    StationMark(mark: s.mark, size: 20)
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(tint))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(s.mark.label)
                        .accessibilityIdentifier("guide-day-\(s.rawValue)-mark")
                    VStack(alignment: .leading, spacing: 2) {
                        // "2 · Pack — a list going into an open case": the name, and what its mark shows.
                        (Text("\(n + 1) \u{00B7} \(s.name)").font(.system(.body, weight: .semibold)).foregroundStyle(words)
                         + Text(" \u{2014} \(s.mark.label.prefix(1).lowercased() + s.mark.label.dropFirst())").font(.system(.footnote)).foregroundStyle(Theme.muted))
                            .fixedSize(horizontal: false, vertical: true)
                        Text(PackingDayGuideCard.says(s)).font(.system(.callout)).foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("guide-day-\(s.rawValue)")
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                line("Getting around: tap a station in the row to open it \u{2014} Pack goes straight to the list. At the foot of each station, Next offers the next one still to do; in the sheet the stations are at the top too. Done closes it.")
                line("A trip with no bags yet has nothing to lay out, weigh, tag or photograph: those four stations are faded with a dashed edge and say \u{201C}no bags yet\u{201D}; opened, they say how to give things a bag (Usually packed in, on a thing\u{2019}s page). Ready then waits only for the packing.")
                line("Once the trip sets off, the row is gone \u{2014} the weights and photos stay in Bags. A trip you share, or start again from this one, begins its Packing day afresh.")
            }
            .padding(.top, 2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(tint.opacity(0.7), lineWidth: 1.2))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("guide-packingday")
    }

    private func line(_ words: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle().fill(AppSection.events.color).frame(width: 6, height: 6).offset(y: -2)
            Text(words).font(.system(.callout)).foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
