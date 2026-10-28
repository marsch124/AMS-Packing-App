import SwiftUI
import PackingCore
import PackingLibrary

/// "Before you go" at the top of a trip — ONE card (0.77, his yes of 13 Oct 2026, a picture
/// approved) where two stood: "Check before you go" (his ideas 4 and 5, 2 Oct 2026) and "To
/// charge" (0.75). Three parts, in this order, each only when it has something
/// (`Library.beforeYouGo`, each part by its own rules as before):
///  1. the flags — on a plane trip what in a cabin bag the airport stops and a thing with a
///     battery in a checked bag; what runs out before he is home (a passport six months
///     ahead). A tap opens the thing to put it right — its bag, its flags, its date;
///  2. "To do" — his reminders whose step has come; a tap ticks one;
///  3. "To charge · n of m" — from the day before the trip through its last day (`ToCharge.swift`).
///
/// Colour is the message. A line: red will stop him (not allowed on board, a battery in the
/// hold, out of date before he is home); orange wants a look (a liquid, a document short of six
/// months). The card — its count capsule and its border — red when any line is red, else orange
/// while anything is left, green "All set" once nothing is (only To charge can get there: every
/// thing charged). All set, the card folds to its one line; a tap on it opens it again.
///
/// Folds whenever he likes (0.101, his list of 26 Oct 2026: "I would like that to be collapsible so
/// I can toggle it into one line"): the chevron is always at the right of its line — folded, the
/// card is that one line, "Before you go", the count in its colour and the chevron. A tap on the
/// line folds it or opens it, and this device keeps that per trip (`TripFolds.beforeYouGoFolded`,
/// in the trip's folds); until he chooses, it folds only All set, as before.
struct BeforeYouGoCard: View {
    let tripId: String
    /// Open the thing (the trip holds the sheet: a flag goes when it is put right).
    let open: (String) -> Void
    @EnvironmentObject var model: LibraryModel
    /// His fold, kept with the trip's folded headings (0.101; `TripFolds.beforeYouGoFolded`).
    @AppStorage("ams.trip.folded") private var foldedRaw = ""

    var body: some View {
        let card = model.library.beforeYouGo(tripId: tripId, today: Today.local)
        if !card.isEmpty {
            let tint = BeforeYouGoCard.color(card.tone)
            let folded = TripFolds.beforeYouGoFolded(foldedRaw, trip: tripId, allSet: card.allSet)
            VStack(alignment: .leading, spacing: 4) {      // 6 until 0.104
                header(card, tint: tint, folded: folded)
                if !folded {
                    if !card.cabin.isEmpty || !card.dates.isEmpty {
                        flags(card)
                    }
                    if card.hasToDo {
                        if !card.cabin.isEmpty || !card.dates.isEmpty { rule }
                        toDo(card.due, things: card.thingDue)
                    }
                    if !card.charge.isEmpty {
                        if !card.cabin.isEmpty || !card.dates.isEmpty || card.hasToDo { rule }
                        ToChargePart(tripId: tripId, rows: card.charge).environmentObject(model)
                            // Where a tapped "Charge tonight" brings the trip (0.87).
                            .id(TripScreen.chargeAnchor)
                    }
                }
            }
            // Folded, one line as slim as the Bags card's: the chevron's square is tap room enough.
            // Open, the header line is the chevron's square too: 4 above it, as folded. A tad tighter
            // (0.104, his arrows of 28 Oct 2026): 14 at the sides and 6 above until then, 14 under an
            // open card — `Metrics.cardSide` and `cardInset` now, as the weather's and the Bags card's.
            .padding(.horizontal, Metrics.cardSide).padding(.top, 4).padding(.bottom, folded ? 4 : Metrics.cardInset)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
            // The border takes no click (0.104, as the Bags card's): folded, the card is 32 high on the Mac.
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(tint, lineWidth: 1.2).allowsHitTesting(false))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("trip-beforego")
        }
    }

    static func color(_ tone: BeforeYouGo.Tone) -> Color {
        switch tone {
        case .red: return AppSection.actions.color
        case .orange: return AppSection.care.color
        case .green: return AppSection.events.color
        }
    }

    /// "Before you go" and one count capsule: everything left, or "All set". A chevron at the
    /// right folds and opens the card (and so does a tap on the line) — since 0.101 always, not
    /// only All set.
    private func header(_ card: BeforeYouGo, tint: Color, folded: Bool) -> some View {
        HStack(spacing: 8) {
            Text("Before you go").font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.ink)
            Text(card.countWords)
                .font(.system(.footnote, weight: .semibold).monospacedDigit()).foregroundStyle(.white)
                .padding(.horizontal, 8).padding(.vertical, 2)
                .background(Capsule().fill(tint))
                .accessibilityLabel(card.allSet ? "All set" : "\(card.left) left")
                .accessibilityIdentifier("trip-beforego-count")
            Spacer()
            Button { fold(card) } label: {
                SVGPath.path(folded ? "M9 6l6 6-6 6" : "M6 9l6 6 6-6")
                    .stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                    .frame(width: 22, height: 22).foregroundStyle(Theme.muted)
                    .frame(width: Metrics.cardLine, height: Metrics.cardLine).contentShape(Rectangle())
            }
            .buttonStyle(.plain).focusEffectDisabled()
            .accessibilityLabel(folded ? "Show Before you go" : "Fold Before you go")
            .accessibilityValue(folded ? "folded" : "open")
            .accessibilityIdentifier("trip-beforego-fold")
        }
        .frame(minHeight: Metrics.cardLine)      // `Metrics.tap` until 0.104: 24 on the Mac now, the iPhone's 36 kept
        .contentShape(Rectangle())
        .onTapGesture { fold(card) }
    }

    /// The other way from how it shows, kept on this device for this trip (0.101).
    private func fold(_ card: BeforeYouGo) {
        let trips = Set(model.library.trips.map(\.id))
        withAnimation(.easeInOut(duration: 0.2)) {
            foldedRaw = TripFolds.beforeYouGoToggled(foldedRaw, trip: tripId, allSet: card.allSet, trips: trips)
        }
    }

    /// A hairline between two parts.
    private var rule: some View {
        Rectangle().fill(Theme.line).frame(height: 1).padding(.vertical, 2).accessibilityHidden(true)
    }

    /// A part's own heading: "To do", "To charge · 1 of 2" (`ToChargePart`).
    static func partTitle(_ words: String) -> some View {
        Text(words).font(.system(.footnote, weight: .semibold)).foregroundStyle(Theme.muted)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: - The flags

    private func flags(_ card: BeforeYouGo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(card.cabin.enumerated()), id: \.offset) { n, f in
                // A battery in the hold: the drawn battery mark of To charge (0.76).
                line(f.line.name, TripChecksCard.says(f), red: f.isRed,
                     mark: f.why == .battery ? ToChargeCard.battery : (TemplateIcons.icon("plane")?.path ?? ""),
                     thing: f.thingId)
                    .accessibilityIdentifier("trip-check-cabin-\(n)")
            }
            ForEach(Array(card.dates.enumerated()), id: \.offset) { n, f in
                line(f.line.name, TripChecksCard.says(f), red: f.isRed,
                     mark: f.document ? (TemplateIcons.icon("passport")?.path ?? "") : TripChecksCard.hourglass,
                     thing: f.thingId)
                    .accessibilityIdentifier("trip-check-date-\(n)")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("trip-beforego-part-flags")
    }

    private func line(_ name: String, _ says: String, red: Bool, mark: String, thing: String?) -> some View {
        let tint = red ? AppSection.actions.color : AppSection.care.color
        return Button { if let thing { open(thing) } } label: {
            HStack(spacing: 10) {
                IconMark(path: mark, size: 22).foregroundStyle(tint)
                VStack(alignment: .leading, spacing: 1) {
                    Text(name).font(.system(.callout, weight: .semibold)).foregroundStyle(Theme.ink)
                    Text(says).font(.system(.subheadline)).foregroundStyle(tint)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 6)
                if thing != nil {
                    SVGPath.path("M9 6l6 6-6 6").stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                        .frame(width: 18, height: 18).foregroundStyle(Theme.muted)
                }
            }
            .frame(minHeight: Metrics.tap).contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
    }

    // MARK: - To do

    private func toDo(_ due: [Item], things: [ThingReminderOnTrip]) -> some View {
        // Where each comes from (0.75, his yes of 13 Oct 2026): the templates' icons, as on
        // the trip's lines — the same answer (`lineTemplates`), asked only when one is due.
        let from = due.isEmpty ? [:] : model.library.lineTemplates(tripId: tripId)
        return VStack(alignment: .leading, spacing: 2) {
            BeforeYouGoCard.partTitle("To do")
            ForEach(Array(due.enumerated()), id: \.element.id) { n, line in
                reminder(line, n: n, from: from[line.id] ?? [])
            }
            // A reminder on one of his things (0.101): "Camera: Empty the SD card", after his templates'.
            ForEach(Array(things.enumerated()), id: \.element.id) { n, r in
                thingReminder(r, n: n)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("trip-beforego-part-todo")
    }

    /// A reminder due: its tick, its name, and the step it belongs to (the part's heading
    /// says "To do") — and at its right the icons of the templates it comes from (0.75, his
    /// yes of 13 Oct 2026: "could not tell which template each comes from"), drawn as on the
    /// trip's lines (`TemplateMarks`). A press ticks it — on the trip's list too, it is the
    /// same line — and it leaves the card. The icons sit BESIDE the button, not in it: the
    /// button's own label ("…, to do. Tick it") would swallow their "From …" for VoiceOver
    /// and on the Mac.
    private func reminder(_ line: Item, n: Int, from: [PackList]) -> some View {
        let tint = AppSection.events.color
        return HStack(spacing: 8) {
            Button {
                model.change { _ = $0.setChecked(true, tripId: tripId, entryId: line.id) }
            } label: {
                HStack(spacing: 10) {
                    TickCircle(on: false, tint: tint).frame(width: 22, height: 22)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(line.name).font(.system(.callout, weight: .semibold)).foregroundStyle(Theme.ink)
                        // A To do written on the trip (Packing Stations, 0.81) is due at once: it says
                        // where it came from instead of a step that has not come.
                        Text(Library.isTripTodo(line) ? Library.addedOnTheTrip : phaseOrFallback(line.phase).label)
                            .font(.system(.subheadline)).foregroundStyle(tint)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 6)
                }
                .frame(minHeight: Metrics.tap).contentShape(Rectangle())
            }
            .buttonStyle(.plain).focusEffectDisabled()
            .accessibilityLabel("\(line.name), to do. Tick it")
            .accessibilityIdentifier("trip-check-todo-\(n)")
            if !from.isEmpty {
                TemplateMarks(from: from, id: "trip-check-todo-\(n)-from")
            }
        }
    }
}

extension BeforeYouGoCard {
    /// A reminder on a thing, due (0.101): its tick, "Camera: Empty the SD card", its step. A press
    /// ticks it — the same tick as under the thing's line — and it leaves the card.
    func thingReminder(_ r: ThingReminderOnTrip, n: Int) -> some View {
        let tint = AppSection.events.color
        return Button {
            model.change { _ = $0.setThingReminderDone(true, tripId: tripId, lineId: r.lineId, reminderId: r.reminder.id) }
        } label: {
            HStack(spacing: 10) {
                TickCircle(on: false, tint: tint).frame(width: 22, height: 22)
                VStack(alignment: .leading, spacing: 1) {
                    (Text("\(r.thingName): ").foregroundStyle(Theme.muted) + Text(r.reminder.text).foregroundStyle(Theme.ink))
                        .font(.system(.callout, weight: .semibold))
                    Text(phaseOrFallback(r.reminder.when).label)
                        .font(.system(.subheadline)).foregroundStyle(tint)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 6)
            }
            .frame(minHeight: Metrics.tap).contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityLabel("\(r.name), to do. Tick it")
        .accessibilityIdentifier("trip-check-remind-\(n)")
    }
}

/// The flags' words, marks and dates — read by the card above, the trip list and the weather.
enum TripChecksCard {
    /// An hourglass, drawn in the icons' style (no stock art, his rule).
    static let hourglass = "M7 3.5H17 M7 20.5H17 M8 3.5C8 8 16 8 16 12C16 16 8 16 8 20.5 M16 3.5C16 8 8 8 8 12C8 16 16 16 16 20.5"

    static func says(_ f: CabinFlag) -> String {
        let bag = f.line.container
        switch f.why {
        case .notAllowed: return "Not allowed in the cabin \u{00B7} in \(bag)"
        case .battery: return "Battery: carry it in the cabin \u{00B7} in \(bag)"
        case .liquid: return "Liquid: 100 ml at most, in the clear bag \u{00B7} in \(bag)"
        }
    }

    static func says(_ f: DateFlag) -> String {
        let day = TripChecksCard.day(f.expiry)
        if f.alreadyOut { return "Out of date since \(day)" }
        if f.beforeHome { return "Runs out \(day), before you are home" }
        return "Valid until \(day): less than 6 months after you are home"
    }

    private static let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    /// "2027-03-03" → "3 Mar 2027", the same words on every device.
    static func day(_ ymd: String) -> String {
        let p = ymd.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3, (1...12).contains(p[1]) else { return ymd }
        return "\(p[2]) \(months[p[1] - 1]) \(p[0])"
    }
}
