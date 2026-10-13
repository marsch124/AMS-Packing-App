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
struct BeforeYouGoCard: View {
    let tripId: String
    /// Open the thing (the trip holds the sheet: a flag goes when it is put right).
    let open: (String) -> Void
    @EnvironmentObject var model: LibraryModel
    /// All set, the card is folded unless he opened it (never kept: a trip opens folded).
    @State private var unfolded = false

    var body: some View {
        let card = model.library.beforeYouGo(tripId: tripId, today: Today.local)
        if !card.isEmpty {
            let tint = BeforeYouGoCard.color(card.tone)
            let folded = card.allSet && !unfolded
            VStack(alignment: .leading, spacing: 6) {
                header(card, tint: tint, folded: folded)
                if !folded {
                    if !card.cabin.isEmpty || !card.dates.isEmpty {
                        flags(card)
                    }
                    if !card.due.isEmpty {
                        if !card.cabin.isEmpty || !card.dates.isEmpty { rule }
                        toDo(card.due)
                    }
                    if !card.charge.isEmpty {
                        if !card.cabin.isEmpty || !card.dates.isEmpty || !card.due.isEmpty { rule }
                        ToChargePart(tripId: tripId, rows: card.charge).environmentObject(model)
                    }
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(tint, lineWidth: 1.2))
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

    /// "Before you go" and one count capsule: everything left, or "All set". All set, a
    /// chevron at the right folds and opens the card (and so does a tap on the line).
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
            if card.allSet {
                Button { fold() } label: {
                    SVGPath.path(folded ? "M9 6l6 6-6 6" : "M6 9l6 6 6-6")
                        .stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                        .frame(width: 22, height: 22).foregroundStyle(Theme.muted)
                        .frame(width: Metrics.tap, height: Metrics.tap).contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityLabel(folded ? "Show what is charged" : "Fold")
                .accessibilityValue(folded ? "folded" : "open")
                .accessibilityIdentifier("trip-beforego-fold")
            }
        }
        .frame(minHeight: card.allSet ? Metrics.tap : nil)
        .contentShape(Rectangle())
        .onTapGesture { if card.allSet { fold() } }
    }

    private func fold() {
        withAnimation(.easeInOut(duration: 0.2)) { unfolded.toggle() }
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

    private func toDo(_ due: [Item]) -> some View {
        // Where each comes from (0.75, his yes of 13 Oct 2026): the templates' icons, as on
        // the trip's lines — the same answer (`lineTemplates`), asked only when one is due.
        let from = model.library.lineTemplates(tripId: tripId)
        return VStack(alignment: .leading, spacing: 2) {
            BeforeYouGoCard.partTitle("To do")
            ForEach(Array(due.enumerated()), id: \.element.id) { n, line in
                reminder(line, n: n, from: from[line.id] ?? [])
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
                        Text(phaseOrFallback(line.phase).label).font(.system(.subheadline)).foregroundStyle(tint)
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
