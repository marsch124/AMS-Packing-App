import SwiftUI
import PackingCore
import PackingLibrary

/// "Before you start" (spec 07 part 19) — his words of 14 Oct 2026, from his own packing
/// walk-through: "Think if there is anything I need to buy or prepare well in advance." On a trip
/// not yet being packed (the Plan step, and Pack until the first thing is ticked), ONE door, first
/// in the scroll area, with what it holds in a few words — "2 to buy · 3 to prepare · 4 to charge";
/// a tap opens the sheet below. A door and not a card (decided by the build): Before you go stands
/// right under it with its own To do and dates, and a second list of the same at the top of the
/// trip would push the list he packs from down by a screen.
///
/// The door's sheet is held by a view that is always there, so ticking the last thing to prepare
/// inside the sheet does not snatch the sheet away when the door goes.
struct BeforeYouStartDoor: View {
    let tripId: String
    /// The trip screen's clock — the day and the time of day its loop step is read by.
    let today: String
    let time: String
    @EnvironmentObject var model: LibraryModel
    @State private var open = false

    var body: some View {
        let start = model.library.beforeYouStart(tripId: tripId, today: today, time: time)
        VStack(spacing: 0) {
            if !start.isEmpty { door(start).padding(.top, 10) }
        }
        .sheet(isPresented: $open) { BeforeYouStartSheet(tripId: tripId).environmentObject(model) }
    }

    /// The name, the words and the chevron on one line when they fit; else the words under the name.
    private func door(_ start: BeforeYouStart) -> some View {
        let title = Text("Before you start").font(.system(.body, weight: .semibold)).foregroundStyle(Theme.ink)
            .lineLimit(1)
        let words = Text(start.words).font(.system(.footnote).monospacedDigit()).foregroundStyle(Theme.muted)
            .lineLimit(1)
        let chevron = SVGPath.path("M9 6l6 6-6 6").stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
            .frame(width: 20, height: 20).foregroundStyle(Theme.muted)
        return Button { open = true } label: {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    title.fixedSize()
                    Spacer(minLength: 8)
                    words.fixedSize()
                    chevron
                }
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        title
                        words.minimumScaleFactor(0.85)
                    }
                    Spacer(minLength: 6)
                    chevron
                }
                .padding(.vertical, 6)
            }
            .padding(.horizontal, 14).frame(minHeight: Metrics.row)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppSection.events.color, lineWidth: 1.2))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        // The Mac folds a button's words into the button: what a test reads is the value.
        .accessibilityLabel("Before you start")
        .accessibilityValue(start.words)
        .accessibilityIdentifier("trip-beforestart")
    }
}

/// The sheet: To buy, To prepare, To charge — each only when it has something (spec 07 part 19).
/// A To buy row opens its thing; a To prepare row's tick ticks the trip's line (and its arrow opens
/// the template a reminder comes from, or the thing behind a Preparations line); To charge is the
/// names only — charging is ticked in Before you go, from the day before.
struct BeforeYouStartSheet: View {
    let tripId: String
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    @State private var opened: Opened?

    /// What a row opened, over this sheet.
    enum Opened: Identifiable {
        case thing(String), template(String)
        var id: String {
            switch self {
            case .thing(let id): return "thing-\(id)"
            case .template(let id): return "template-\(id)"
            }
        }
    }

    var body: some View {
        let today = Today.local
        let start = model.library.beforeYouStart(tripId: tripId, today: today, time: Today.time)
        let name = model.library.trips.first { $0.id == tripId }?.name ?? ""
        VStack(spacing: 0) {
            HStack {
                Text("Before you start").font(.system(.title3, weight: .bold)).foregroundStyle(Theme.ink)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(HeaderButtonStyle(tint: AppSection.events.color, filled: true)).focusEffectDisabled()
                    .font(.system(.body, weight: .semibold)).foregroundStyle(AppSection.events.color)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("beforestart-done")
            }
            .padding(16)
            KeyboardAwayScroll {
                VStack(alignment: .leading, spacing: 12) {
                    Text(jsTrim(name).isEmpty ? "What to buy and get ready before you start packing."
                         : "What to buy and get ready for \u{201C}\(name)\u{201D} before you start packing.")
                        .font(.system(.subheadline)).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("beforestart-says")
                    if start.isEmpty {
                        Text("Nothing left to buy or get ready.")
                            .font(.system(.callout, weight: .semibold)).foregroundStyle(AppSection.events.color)
                            .accessibilityIdentifier("beforestart-none")
                    }
                    if !start.buy.isEmpty { buyPart(start.buy) }
                    if !start.prepare.isEmpty { preparePart(start.prepare, today: today) }
                    if !start.charge.isEmpty { chargePart(start.charge) }
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .sheet(item: $opened) { o in
            switch o {
            case .thing(let id): ThingEditor(itemId: id).environmentObject(model)
            case .template(let id): TemplateDetail(listId: id).environmentObject(model)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("beforestart-sheet")
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 560)
        #endif
    }

    // MARK: - A part

    /// A part: its heading — the name and how many — and its rows, in a card.
    private func part<Rows: View>(_ title: String, count: Int, id: String, mark: String? = nil,
                                  @ViewBuilder rows: () -> Rows) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if let mark {
                    IconMark(path: mark, size: 16).foregroundStyle(AppSection.care.color).accessibilityHidden(true)
                }
                Text(title).font(.headline).foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(.isHeader)
                Text("\(count)").font(.system(.footnote, weight: .semibold).monospacedDigit()).foregroundStyle(Theme.muted)
                    .accessibilityIdentifier("\(id)-count")
                Spacer()
            }
            .padding(.bottom, 2)
            rows()
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("beforestart-part-\(id.replacingOccurrences(of: "beforestart-", with: ""))")
    }

    private var chevron: some View {
        SVGPath.path("M9 6l6 6-6 6").stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
            .frame(width: 18, height: 18).foregroundStyle(Theme.muted)
    }

    // MARK: - To buy

    /// "On To buy · Needs replacing · Runs out 31 Oct 2026, before you are home · Used up on “Summer hike”".
    static func reasons(_ row: BeforeYouStart.Buy) -> String {
        row.why.map { w -> String in
            switch w {
            case .onToBuy: return "On To buy"
            case .needsReplacing: return "Needs replacing"
            case .date(let f): return TripChecksCard.says(f)
            case .usedUp(let trip): return "Used up on \u{201C}\(trip)\u{201D}"
            }
        }.joined(separator: " \u{00B7} ")
    }

    private func buyPart(_ rows: [BeforeYouStart.Buy]) -> some View {
        part("To buy", count: rows.count, id: "beforestart-buy") {
            ForEach(Array(rows.enumerated()), id: \.element.id) { n, row in
                if n > 0 { Theme.line.frame(height: 1).accessibilityHidden(true) }
                buyRow(row, n: n)
            }
        }
    }

    /// A thing to buy: its name, why under it (red when it will stop him, orange when it wants a
    /// look), and the chevron when there is a thing to open.
    private func buyRow(_ row: BeforeYouStart.Buy, n: Int) -> some View {
        let says = BeforeYouStartSheet.reasons(row)
        let tint = row.red ? AppSection.actions.color : (row.orange ? AppSection.care.color : Theme.muted)
        return Button { if let thing = row.thingId { opened = .thing(thing) } } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(row.name).font(.system(.callout, weight: .semibold)).foregroundStyle(Theme.ink)
                    Text(says).font(.system(.subheadline)).foregroundStyle(tint)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 6)
                if row.thingId != nil { chevron }
            }
            .padding(.vertical, 2)
            .frame(minHeight: Metrics.tap).contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityLabel(row.name)
        .accessibilityValue(says)
        .accessibilityIdentifier("beforestart-buy-\(n)")
    }

    // MARK: - To prepare

    /// "≥1 week ahead · from 23 Oct", "Preparations · now", "Added on the trip".
    static func when(_ row: BeforeYouStart.Prepare, today: String) -> String {
        if row.tripTodo { return Library.addedOnTheTrip }
        let label = phaseLabel(row.line.phase)
        guard !row.due.isEmpty else { return label }
        return "\(label) \u{00B7} " + (jsStringLess(today, row.due) ? "from \(CountdownCard.shortDay(row.due))" : "now")
    }

    private func preparePart(_ rows: [BeforeYouStart.Prepare], today: String) -> some View {
        // Where each comes from: its templates' icons, as on the trip's lines (`lineTemplates`).
        let from = model.library.lineTemplates(tripId: tripId)
        return part("To prepare", count: rows.count, id: "beforestart-prepare") {
            ForEach(Array(rows.enumerated()), id: \.element.line.id) { n, row in
                if n > 0 { Theme.line.frame(height: 1).accessibilityHidden(true) }
                prepareRow(row, n: n, today: today, from: row.tripTodo ? [] : (from[row.line.id] ?? []))
            }
        }
    }

    /// A thing to get ready: its tick, its name and its When — a press ticks the trip's line (it
    /// leaves the sheet) — then the icons of its templates and the arrow to what it comes from. The
    /// icons and the arrow sit BESIDE the tick, not in it (Before you go's own reason: the button's
    /// label would swallow their words for VoiceOver and on the Mac).
    private func prepareRow(_ row: BeforeYouStart.Prepare, n: Int, today: String, from: [PackList]) -> some View {
        let tint = AppSection.events.color
        let says = BeforeYouStartSheet.when(row, today: today)
        let target: Opened? = row.templateId.map { .template($0) } ?? row.thingId.map { .thing($0) }
        let targetName = row.templateId.flatMap { t in model.library.templates.first { $0.id == t }?.name } ?? row.line.name
        return HStack(spacing: 8) {
            Button {
                let id = tripId, entry = row.line.id
                // A thing's reminder (0.101): the trip's one tick for it, kept on the thing's line.
                if let r = row.thing {
                    model.change { _ = $0.setThingReminderDone(true, tripId: id, lineId: r.lineId, reminderId: r.reminder.id) }
                } else {
                    model.change { _ = $0.setChecked(true, tripId: id, entryId: entry) }
                }
            } label: {
                HStack(spacing: 10) {
                    TickCircle(on: false, tint: tint).frame(width: 22, height: 22)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(row.line.name).font(.system(.callout, weight: .semibold)).foregroundStyle(Theme.ink)
                        Text(says).font(.system(.subheadline)).foregroundStyle(tint)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 6)
                }
                .padding(.vertical, 2)
                .frame(minHeight: Metrics.tap).contentShape(Rectangle())
            }
            .buttonStyle(.plain).focusEffectDisabled()
            .accessibilityLabel("\(row.line.name), to prepare. Tick it")
            .accessibilityValue(says)
            .accessibilityIdentifier("beforestart-prepare-\(n)")
            if !from.isEmpty {
                TemplateMarks(from: from, id: "beforestart-prepare-\(n)-from")
            }
            if let target {
                Button { opened = target } label: {
                    chevron.frame(width: Metrics.lineButton, height: Metrics.tap).contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityLabel("Open \(targetName)")
                .accessibilityIdentifier("beforestart-prepare-\(n)-open")
            }
        }
    }

    // MARK: - To charge

    /// The names and the count; the ticks are Before you go's, from the day before the trip.
    private func chargePart(_ rows: [ChargeRow]) -> some View {
        part("To charge", count: rows.count, id: "beforestart-charge", mark: ToChargeCard.battery) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { n, row in
                (Text(row.name).foregroundStyle(Theme.ink)
                 + (row.kit.isEmpty ? Text("") : Text(" \u{00B7} in the \(row.kit)").foregroundStyle(Theme.muted)))
                    .font(.system(.callout))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: Metrics.line, alignment: .leading)
                    .accessibilityIdentifier("beforestart-charge-\(n)")
            }
            Text("Tick them in Before you go as they are charged, from the day before the trip.")
                .font(.system(.footnote)).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
                .accessibilityIdentifier("beforestart-charge-note")
        }
    }
}
