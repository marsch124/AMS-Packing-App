import SwiftUI
#if os(iOS)
import EventKit
import EventKitUI
#else
import AppKit
#endif
import PackingCore
import PackingLibrary

// Take a break (0.77, spec 07 part 16) — his yes of 13 Oct 2026, from his own packing
// walk-through: "then I get tired and just want to relax… if it is the day after I would like
// a reminder or a calendar event so that I feel calm. In this state I would like an overview
// of how far I have come."
//
// On a trip at Pack, a quiet "Take a break" on the count's line in the trip's header opens a
// sheet: how far he has come (the trip's count, its groups in his Sorting, To charge and To do
// left), then "Continue when?" — In an hour · This evening · Tomorrow (a time, 18:00 to start)
// · Just pause. A time puts "🎒 Back to packing <trip>: 22 things left" in the iPhone's list (the
// backpack since 0.84, his ask of 15 Oct 2026), and
// Add to Calendar puts it in his calendar too: the system's own New Event window on the
// iPhone (no calendar permission is asked — iOS 17 and later lets an app hand it an event),
// a calendar file handed to Calendar on the Mac (no permission either).

/// The trip header's door to the break. Since 0.84 (his ask of 15 Oct 2026, from a Mac trip
/// at Pack) a round button that is ONLY the drawn cup, as big as the trip's pen beside the name
/// (`RoundIconLabel`, `Metrics.tap` across), in the break's warm amber (0.81) — label "Take a
/// break". While a break is waiting it grows into a compact capsule: the cup and, small, the
/// time he comes back — "19:00" today, "Fri 18:00" on another day (`short`). Shown only while
/// the trip is at Pack with something left (the trip screen decides).
struct TakeABreakButton: View {
    let tripId: String
    @EnvironmentObject var model: LibraryModel
    @State private var open = false

    /// A warm coffee amber (0.81, his pick of variant A, 14 Oct 2026): the ring and its 10 % fill,
    /// and words made to read on that fill, day and night (`TripHeaderTone`).
    private var tint: Color { TripHeaderTone.takeABreak.ringColour }

    var body: some View {
        let until = model.library.trips.first { $0.id == tripId }.map(Library.breakUntil) ?? ""
        let now = Today.stamp(Today.now)
        let says = TakeABreakButton.words(until, now: now)
        let time = TakeABreakButton.short(until, now: now)
        Button { open = true } label: {
            if time.isEmpty {
                RoundIconLabel(tint: tint) { CupMark() }
            } else {
                HStack(spacing: 4) {
                    CupMark().frame(width: Metrics.glyph, height: Metrics.glyph).foregroundStyle(tint)
                    Text(time).font(.system(.footnote, weight: .semibold).monospacedDigit())
                        .foregroundStyle(TripHeaderTone.takeABreak.wordsColour)
                        .lineLimit(1).fixedSize()
                }
                .padding(.leading, (Metrics.tap - Metrics.glyph) / 2).padding(.trailing, 10)
                .frame(height: Metrics.tap)
                .background(Capsule().fill(tint.opacity(0.10)))
                .overlay(Capsule().stroke(tint, lineWidth: 1.4))
                .contentShape(Capsule())
            }
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier("trip-break")
        .accessibilityLabel("Take a break")
        // With a break waiting, when he comes back ("Back at 19:00") as its value; none without.
        .accessibilityValue(says == "Take a break" ? "" : says)
        .sheet(isPresented: $open) { TakeABreakSheet(tripId: tripId).environmentObject(model) }
        // The iPhone's one question, the first time a trip at Pack is opened (TripMessages).
        .task { await TripMessages.shared.askOnce(model.library) }
    }

    /// The capsule's time while a break waits (0.84): "19:00" today, "Fri 18:00" on another day
    /// (a break is at most tomorrow when it is taken); "" with none waiting — the round cup.
    static func short(_ until: String, now: String) -> String {
        guard !until.isEmpty, jsStringLess(now, until) else { return "" }
        let day = String(until.prefix(10)), time = String(until.suffix(5))
        if day == String(now.prefix(10)) { return time }
        let p = day.split(separator: "-").compactMap { Int($0) }
        let cal = Calendar(identifier: .gregorian)
        guard p.count == 3, let date = cal.date(from: DateComponents(year: p[0], month: p[1], day: p[2])) else { return time }
        let names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return "\(names[(cal.component(.weekday, from: date) + 6) % 7]) \(time)"
    }

    /// "Take a break"; with a break still ahead, "Back at 19:00", "Back tomorrow 18:00",
    /// "Back 15 Oct 18:00".
    static func words(_ until: String, now: String) -> String {
        guard !until.isEmpty, jsStringLess(now, until) else { return "Take a break" }
        return "Back \(TakeABreakButton.when(until, now: now))"
    }

    /// "at 19:00" today, "tomorrow 18:00", "15 Oct 18:00".
    static func when(_ moment: String, now: String) -> String {
        let day = String(moment.prefix(10)), time = String(moment.suffix(5)), today = String(now.prefix(10))
        if day == today { return "at \(time)" }
        if day == addDays(today, 1) { return "tomorrow \(time)" }
        return "\(CountdownCard.shortDay(day)) \(time)"
    }
}

/// The sheet: how far he has come, and when he goes on.
struct TakeABreakSheet: View {
    let tripId: String
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    /// The trip's Sorting on this device — its groups are the overview's.
    @AppStorage("ams.view") private var sorting = "when"
    /// Now, when the sheet opened (the tests' clock too): the choices' times are read from it.
    @State private var now = Today.stamp(Today.now)
    /// Tomorrow's time, 18:00 until he picks another.
    @State private var tomorrowAt = BREAK_TOMORROW_AT
    /// The choice made on this visit; nil = none yet (a break already waiting shows by its line).
    @State private var chosen: Library.BreakChoice?
    /// Why a choice could not be (it passed, or he leaves before then), in red under the choices.
    @State private var needs = ""
    /// The iPhone does not allow the app's notifications.
    @State private var refused = false
    /// The system's New Event window (iPhone).
    @State private var adding = false
    /// Under the tests: what Add to Calendar would hand over (no test can see the system's window).
    @State private var calendarSaid = ""

    private var tint: Color { AppSection.events.color }

    var body: some View {
        let lib = model.library
        let trip = lib.trips.first { $0.id == tripId }
        let view = TripScreen.views.contains { $0.id == sorting } ? sorting : "when"
        let overview = lib.breakOverview(tripId: tripId, sorting: view, today: String(now.prefix(10)))
        let until = trip.map(Library.breakUntil) ?? ""
        let waiting = !until.isEmpty && jsStringLess(Today.stamp(Today.now), until)
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Take a break").font(.system(.title3, weight: .bold)).foregroundStyle(tint)
                    Text(trip?.name ?? "").font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(HeaderButtonStyle(tint: tint, filled: true)).focusEffectDisabled()
                    .keyboardShortcut(.cancelAction)            // Escape closes it, as Done does
                    .accessibilityIdentifier("break-done")
            }
            .padding(16)
            KeyboardAwayScroll {
                VStack(alignment: .leading, spacing: 10) {
                    if let overview { howFar(overview) }
                    SectionTitle(title: "Continue when?", id: "break-when")
                    choices
                    if !needs.isEmpty {
                        Text(needs).font(.system(.subheadline, weight: .semibold)).foregroundStyle(AppSection.actions.color)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("break-needs")
                    }
                    if waiting {
                        said("Back to packing \(TakeABreakButton.when(until, now: Today.stamp(Today.now))) \u{2014} \(TakeABreakSheet.whoReminds)")
                    } else if chosen == .pause {
                        said("Paused \u{2014} no reminder. The list waits for you.")
                    }
                    if refused {
                        Text("This device does not allow the app to remind you. Allow it in the device's Settings, under Notifications \u{2014} or put the break in your calendar.")
                            .font(.system(.subheadline, weight: .semibold)).foregroundStyle(AppSection.actions.color)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("break-refused")
                    }
                    if waiting {
                        // Filled once a time is chosen (0.84, his ask of 15 Oct 2026: it pops) — the
                        // break's amber, white words; outlined in that amber while no time shows as
                        // chosen (a break waiting from before that is none of the choices: In an hour).
                        let pops = chosen != nil && chosen != .pause
                        Button { addToCalendar() } label: { calendarLabel(filled: pops) }
                        .buttonStyle(.plain).focusEffectDisabled()
                        .padding(.top, 4)
                        .accessibilityIdentifier("break-calendar")
                        #if DEBUG
                        // The tests' only way to see its look.
                        .accessibilityValue(pops ? "filled" : "outlined")
                        #endif
                    }
                    #if DEBUG
                    if !calendarSaid.isEmpty {
                        Text(calendarSaid).font(.system(.caption)).foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("break-calendar-said")
                    }
                    #endif
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .onAppear { recall(until) }
        #if os(iOS)
        .sheet(isPresented: $adding) {
            if let e = lib.breakEvent(tripId: tripId), let start = Today.moment(e.start), let end = Today.moment(e.end) {
                BreakEventEditor(title: e.title, notes: e.notes, start: start, end: end, shown: $adding)
                    .ignoresSafeArea()
            }
        }
        #endif
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("break-sheet")
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 560)
        #endif
    }

    /// Who reminds him: this iPhone, or — taken on the Mac — his iPhone (the break is kept on
    /// the trip, so the iPhone has it a moment later).
    static var whoReminds: String {
        #if os(macOS)
        "your iPhone will remind you."
        #else
        "the iPhone will remind you."
        #endif
    }

    // MARK: How far he has come

    private func howFar(_ o: BreakOverview) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How far you have come").font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.muted)
            Text(o.packedWords)
                .font(.system(.title2, weight: .bold).monospacedDigit()).foregroundStyle(tint)
                .accessibilityIdentifier("break-packed")
            // The bar: done of all, in the trip's green.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(tint.opacity(0.15))
                    Capsule().fill(tint).frame(width: o.total > 0 ? geo.size.width * CGFloat(o.done) / CGFloat(o.total) : 0)
                }
            }
            .frame(height: 8)
            .accessibilityHidden(true)
            // Each group of his Sorting: done (a tick), or how many are left.
            FlowRow(spacing: 6) {
                ForEach(Array(o.groups.enumerated()), id: \.offset) { n, g in groupPill(g, n: n) }
            }
            .padding(.top, 2)
            if !o.chargeWords.isEmpty {
                Text(o.chargeWords).font(.system(.callout, weight: .semibold))
                    .foregroundStyle(o.charged == o.toCharge ? tint : AppSection.care.color)
                    .accessibilityIdentifier("break-charge")
            }
            if !o.todoWords.isEmpty {
                Text(o.todoWords).font(.system(.callout, weight: .semibold))
                    .foregroundStyle(o.todoDone == o.todo ? tint : Theme.ink)
                    .accessibilityIdentifier("break-todo")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(tint, lineWidth: 1.2))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("break-overview")
    }

    private func groupPill(_ g: BreakOverview.Group, n: Int) -> some View {
        let done = g.left == 0
        return HStack(spacing: 5) {
            Text(g.label).font(.system(.footnote, weight: .semibold)).lineLimit(1)
            if done {
                Tick().stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .frame(width: 11, height: 9)
            } else {
                Text("\(g.left) left").font(.system(.footnote).monospacedDigit())
                    .foregroundStyle(Theme.muted)
            }
        }
        .foregroundStyle(done ? tint : Theme.ink)
        .padding(.horizontal, 10).frame(minHeight: Metrics.chip)
        .background(Capsule().fill(done ? tint.opacity(0.14) : Theme.bg))
        .overlay(Capsule().stroke(done ? tint : Theme.line, lineWidth: 1))
        // One element saying it all — "Bike ✓", "Golf 3 left" — as the tests read it.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(g.words)
        .accessibilityIdentifier("break-group-\(n)")
    }

    // MARK: Continue when?

    @ViewBuilder private var choices: some View {
        VStack(alignment: .leading, spacing: 6) {
            choice(.hour, "In an hour", detail: Library.breakMoment(.hour, now: now).map { String($0.suffix(5)) } ?? "")
            if Library.breakMoment(.evening, now: now) != nil {
                choice(.evening, "This evening", detail: BREAK_EVENING_AT)
            }
            // Tomorrow: the time beside it, 18:00 to start; a new time is taken at once when
            // Tomorrow is the choice.
            HStack(spacing: 8) {
                choiceButton(.tomorrow, "Tomorrow", detail: "")
                DatePicker("", selection: Binding(get: { LeaveTimes.date(tomorrowAt) },
                                                  set: { tomorrowAt = LeaveTimes.words($0) }),
                           displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .fixedSize()
                    .accessibilityIdentifier("break-tomorrow-time")
            }
            .onChange(of: tomorrowAt) { _, _ in if chosen == .tomorrow { choose(.tomorrow) } }
            choice(.pause, "Just pause", detail: "no reminder")
        }
    }

    private func choice(_ c: Library.BreakChoice, _ title: String, detail: String) -> some View {
        choiceButton(c, title, detail: detail)
    }

    /// One choice: a full-width row in the trip's green — outlined, filled once chosen. Its
    /// time is its value (the Mac folds a button's texts into the button).
    private func choiceButton(_ c: Library.BreakChoice, _ title: String, detail: String) -> some View {
        let on = chosen == c
        return Button { choose(c) } label: {
            HStack(spacing: 8) {
                Text(title).font(.system(.body, weight: .semibold))
                Spacer(minLength: 8)
                if !detail.isEmpty {
                    Text(detail).font(.system(.callout).monospacedDigit()).opacity(0.85)
                }
            }
            .foregroundStyle(on ? Color.white : tint)
            .padding(.horizontal, 12).frame(maxWidth: .infinity, minHeight: Metrics.tap)
            .background(RoundedRectangle(cornerRadius: 10).fill(on ? tint : tint.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(tint, lineWidth: 1.2))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier("break-\(c.rawValue)")
        .accessibilityLabel(title)
        .accessibilityValue(detail)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func said(_ words: String) -> some View {
        Text(words).font(.system(.callout, weight: .semibold)).foregroundStyle(tint)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("break-said")
    }

    /// A choice: the break kept on the trip (one per trip — it replaces the last), or taken
    /// away (Just pause); refused, with why, when its time has passed or he leaves before it.
    private func choose(_ c: Library.BreakChoice) {
        let id = tripId
        let at = Today.stamp(Today.now)
        needs = ""
        guard c != .pause else {
            model.change { _ = $0.setBreak(until: nil, tripId: id) }
            chosen = .pause
            Task { await TripMessages.shared.reschedule(model.library) }
            return
        }
        guard let until = Library.breakMoment(c, now: at, tomorrowAt: tomorrowAt) else {
            needs = "That time has passed \u{2014} pick a later one."
            return
        }
        if let why = model.library.breakRefusal(tripId: id, until: until, now: at) {
            needs = why
            return
        }
        model.change { _ = $0.setBreak(until: until, tripId: id) }
        chosen = c
        calendarSaid = ""
        Task {
            #if os(iOS)
            refused = !(await PackingReminders.shared.askToShow())
            #endif
            await TripMessages.shared.reschedule(model.library)
        }
    }

    /// A break already waiting, when the sheet opens: This evening or Tomorrow (at its time)
    /// show as chosen when it is one of them.
    private func recall(_ until: String) {
        guard !until.isEmpty, jsStringLess(now, until) else { return }
        if until == Library.breakMoment(.evening, now: now) { chosen = .evening }
        else if String(until.prefix(10)) == addDays(String(now.prefix(10)), 1) {
            tomorrowAt = String(until.suffix(5))
            chosen = .tomorrow
        }
    }

    // MARK: Add to Calendar

    /// Add to Calendar (0.84): a wide button with the drawn calendar, in the break's amber —
    /// outlined (its words on the amber at 10 %, `TripHeaderTone.takeABreak`) or, once a time is
    /// chosen, FILLED (`TripHeaderTone.breakFilled`, white words and mark), day and night.
    private func calendarLabel(filled: Bool) -> some View {
        let tone = TripHeaderTone.takeABreak
        let fill = TripHeaderTone.breakFilledColour
        return HStack(spacing: 10) {
            CalendarMark().frame(width: 22, height: 22)
            Text("Add to Calendar").font(.system(.body, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
        }
        .foregroundStyle(filled ? Color.white : tone.wordsColour)
        .frame(maxWidth: .infinity, minHeight: Metrics.tap)
        .background(RoundedRectangle(cornerRadius: 12).fill(filled ? fill : tone.ringColour.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(filled ? fill : tone.ringColour, lineWidth: 1.4))
        .contentShape(Rectangle())
    }

    private func addToCalendar() {
        let lib = model.library
        // `-breakRealCalendar` (testing only): the real hand-over, to look at it by hand.
        if AMSPackingApp.testing && !ProcessInfo.processInfo.arguments.contains("-breakRealCalendar") {
            // No test can see the system's window (iPhone) or Calendar (Mac): what it would get.
            if let e = lib.breakEvent(tripId: tripId) { calendarSaid = "\(e.title) \u{00B7} \(e.start)\u{2013}\(String(e.end.suffix(5))) \u{00B7} \(e.notes)" }
            return
        }
        #if os(iOS)
        adding = true
        #else
        // The Mac: a calendar file handed to the app that opens calendar files (Calendar, unless
        // he chose another); it asks which calendar, and nothing is added until he says.
        guard let ics = lib.breakCalendarFile(tripId: tripId) else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Back to packing.ics")
        do {
            try Data(ics.utf8).write(to: url, options: .atomic)
            NSWorkspace.shared.open(url)
        } catch {
            needs = "The calendar file could not be made."
        }
        #endif
    }
}

#if os(iOS)
/// The system's own New Event window, filled in: "Back to packing <trip>", the break's time,
/// half an hour, an alert at the start, what is left as its note. He adds it (or cancels) —
/// nothing reaches his calendar until he does. Since iOS 17 it runs outside the app, and an
/// app that only hands it an event needs no calendar permission (the app asks for none).
struct BreakEventEditor: UIViewControllerRepresentable {
    let title: String
    let notes: String
    let start: Date
    let end: Date
    @Binding var shown: Bool

    func makeCoordinator() -> Coordinator { Coordinator(shown: $shown) }

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        event.title = title
        event.notes = notes
        event.startDate = start
        event.endDate = end
        event.addAlarm(EKAlarm(relativeOffset: 0))
        let editor = EKEventEditViewController()
        editor.eventStore = store
        editor.event = event
        editor.editViewDelegate = context.coordinator
        return editor
    }

    func updateUIViewController(_ controller: EKEventEditViewController, context: Context) {}

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        let shown: Binding<Bool>
        init(shown: Binding<Bool>) { self.shown = shown }
        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            shown.wrappedValue = false
        }
    }
}
#endif

/// A cup on its saucer, steam rising — the break's mark. The app's own stroke on the 24-point
/// grid (`GridShape`), never a stock symbol.
struct CupMark: View {
    var body: some View {
        GridShape(d: "M5.5 9.5h10v4.5a4.5 4.5 0 0 1-4.5 4.5h-1a4.5 4.5 0 0 1-4.5-4.5zM15.5 11h1.25a2.25 2.25 0 0 1 0 4.5H15.2M4 21h13M9 7c0-1.2 1-1.3 1-2.5M12.5 7c0-1.2 1-1.3 1-2.5")
            .stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
            .accessibilityHidden(true)
    }
}

/// A calendar page with two rings and one day marked — Add to Calendar's mark.
struct CalendarMark: View {
    var body: some View {
        GridShape(d: "M5.5 6h13a1.5 1.5 0 0 1 1.5 1.5v11a1.5 1.5 0 0 1-1.5 1.5h-13A1.5 1.5 0 0 1 4 18.5v-11A1.5 1.5 0 0 1 5.5 6zM4 10.5h16M8.5 4v3.5M15.5 4v3.5M14 14.5h2.5v2.5H14z")
            .stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
            .accessibilityHidden(true)
    }
}

/// Settings → "Messages when a trip moves on" — this iPhone's own switch, on until he turns it
/// off (spec 07 part 16). Inside the Remind me to pack card. Not on the Mac: the messages come
/// on the iPhone only. Since 0.87 it holds "Charge tonight" too — the app's own trip messages.
struct MovesOnSwitch: View {
    @EnvironmentObject var model: LibraryModel
    @AppStorage(TripMessages.onKey) private var on = true

    var body: some View {
        Toggle(isOn: Binding(get: { on }, set: { want in
            on = want
            Task {
                if want { _ = await PackingReminders.shared.askToShow() }
                await TripMessages.shared.reschedule(model.library)
            }
        })) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Messages when a trip moves on").font(.system(.body, weight: .semibold)).foregroundStyle(Theme.ink)
                Text("On this iPhone: \u{201C}Charge tonight\u{201D} at 20:00 the evening before a trip, if something still needs charging; \u{201C}Have a good trip\u{201D} when a trip sets off \u{2014} at the time you leave, else at 8 \u{2014} and the morning after its last day, at 10, a word to review it.")
                    .font(.system(.footnote)).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(AppSection.events.color)
        .accessibilityIdentifier("settings-moves-on")
    }
}

// MARK: - The trip messages, for the tests

#if DEBUG
/// UI tests only (`-showTripMessages`): what the device would have in its list for this trip
/// — a test cannot see a notification. One line per message, `trip-message-break` /
/// `trip-message-onsite` / `trip-message-review` / `trip-message-charge` (0.87), saying its
/// id, day and time, title and words; `trip-message-none` when there is none.
struct TripMessageList: View {
    let tripId: String
    @ObservedObject private var messages = TripMessages.shared

    var body: some View {
        let mine = messages.planned.filter { $0.tripId == tripId }
        VStack(alignment: .leading, spacing: 2) {
            if mine.isEmpty {
                Text("No trip message").font(.system(.caption)).foregroundStyle(Theme.muted)
                    .accessibilityIdentifier("trip-message-none")
            }
            ForEach(mine) { m in
                Text("\(m.id) \u{00B7} \(m.day) \(m.time) \u{00B7} \(m.title) \(m.body)")
                    .font(.system(.caption)).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("trip-message-\(m.kind.rawValue)")
            }
        }
    }
}
#endif
