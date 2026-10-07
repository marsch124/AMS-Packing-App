import SwiftUI
import PackingCore
import PackingLibrary

/// "Check before you go" at the top of a trip — his ideas 4 and 5 (2 Oct 2026). Only
/// there when something needs him: on a plane trip, what in a cabin bag the airport
/// stops; and what runs out before he is home (a passport six months ahead). A tap
/// opens the thing to put it right — its bag, its flags, its date.
///
/// Colour is the message: red will stop him (not allowed on board, out of date
/// before he is home); orange wants a look (a liquid, a document short of six months).
struct TripChecksCard: View {
    let tripId: String
    /// Open the thing (the trip holds the sheet: this card goes when the last line is put right).
    let open: (String) -> Void
    @EnvironmentObject var model: LibraryModel

    /// An hourglass, drawn in the icons' style (no stock art, his rule).
    static let hourglass = "M7 3.5H17 M7 20.5H17 M8 3.5C8 8 16 8 16 12C16 16 8 16 8 20.5 M16 3.5C16 8 8 8 8 12C8 16 16 16 16 20.5"

    var body: some View {
        let cabin = model.library.cabinCheck(tripId: tripId)
        let dates = model.library.dateCheck(tripId: tripId, todayISO: Today.local)
        // His reminders whose step has come and that are not ticked yet (0.70, spec 07 part 12).
        let due = model.library.dueReminders(tripId: tripId, today: Today.local)
        let red = cabin.contains { $0.why == .notAllowed } || dates.contains { $0.alreadyOut || $0.beforeHome }
        // Only reminders to see to: the trip's own colour, not a warning's.
        let tint = red ? AppSection.actions.color : (cabin.isEmpty && dates.isEmpty ? AppSection.events.color : AppSection.care.color)
        if !cabin.isEmpty || !dates.isEmpty || !due.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("Check before you go").font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.ink)
                    Text("\(cabin.count + dates.count + due.count)")
                        .font(.system(.footnote, weight: .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Capsule().fill(tint))
                        .accessibilityIdentifier("trip-checks-count")
                    Spacer()
                }
                ForEach(Array(cabin.enumerated()), id: \.offset) { n, f in
                    line(f.line.name, TripChecksCard.says(f), red: f.why == .notAllowed,
                         mark: TemplateIcons.icon("plane")?.path ?? "", thing: f.thingId)
                        .accessibilityIdentifier("trip-check-cabin-\(n)")
                }
                ForEach(Array(dates.enumerated()), id: \.offset) { n, f in
                    line(f.line.name, TripChecksCard.says(f), red: f.alreadyOut || f.beforeHome,
                         mark: f.document ? (TemplateIcons.icon("passport")?.path ?? "") : TripChecksCard.hourglass,
                         thing: f.thingId)
                        .accessibilityIdentifier("trip-check-date-\(n)")
                }
                ForEach(Array(due.enumerated()), id: \.element.id) { n, line in
                    reminder(line)
                        .accessibilityIdentifier("trip-check-todo-\(n)")
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(tint, lineWidth: 1.2))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("trip-checks")
        }
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

    /// A reminder due: its tick, its name, and the step it belongs to. A press ticks it
    /// — on the trip's list too, it is the same line — and it leaves the card.
    private func reminder(_ line: Item) -> some View {
        let tint = AppSection.events.color
        return Button {
            model.change { _ = $0.setChecked(true, tripId: tripId, entryId: line.id) }
        } label: {
            HStack(spacing: 10) {
                TickCircle(on: false, tint: tint).frame(width: 22, height: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(line.name).font(.system(.callout, weight: .semibold)).foregroundStyle(Theme.ink)
                    Text("To do \u{00B7} \(phaseOrFallback(line.phase).label)").font(.system(.subheadline)).foregroundStyle(tint)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 6)
            }
            .frame(minHeight: Metrics.tap).contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityLabel("\(line.name), to do. Tick it")
    }

    static func says(_ f: CabinFlag) -> String {
        let bag = f.line.container
        switch f.why {
        case .notAllowed: return "Not allowed in the cabin \u{00B7} in \(bag)"
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
