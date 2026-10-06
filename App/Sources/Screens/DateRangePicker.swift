import SwiftUI

/// The trip's dates, the way Booking.com picks them — his example (2026-09-26):
/// one field saying "Sat 26 Sep — Sun 27 Sep · 1 night", and under it a month
/// grid, Monday first: tap the first day, then the last; the two ends are filled,
/// the nights between shaded. Two months side by side where there is room (the
/// Mac), one on the iPhone. The grid then stays open on the range picked until OK
/// keeps it or Cancel puts the dates back (their field test, Oct 2026).
///
/// Always on the form since 0.67 — his words: "I would like the date picker to be
/// present all the time, and then take away the Dates checkbox." A trip may still
/// have no dates: until a day is tapped the field says "Add dates", and **Clear
/// dates** in the grid takes them away again (what switching Dates off used to do).
struct DateRangePicker: View {
    @Binding var start: Date
    @Binding var end: Date
    /// Whether the trip has dates at all. False: the field offers "Add dates", the
    /// grid marks no days, and the first tap picks the first day.
    @Binding var dated: Bool
    var tint: Color = AppSection.home.color
    /// The field's ids: `<id>-field`, `<id>-label`, `<id>-nights`. Create new trip keeps
    /// "trip-dates"; Trip settings says "tripset-dates" (0.67) — Home's field is now always
    /// there, and on the Mac its window stays in the tree behind the Trip settings sheet,
    /// so one id in both would name two fields.
    var id: String = "trip-dates"
    /// Open the grid straight away. Both forms start with it closed (0.67).
    @State var open = false
    /// The first month showing, "2026-09".
    @State private var month = ""
    /// Between the two taps: the first day is set, the last is not yet.
    @State private var waitingForEnd = false
    @State private var width: CGFloat = 0
    /// The dates as they were when the grid opened — Cancel puts them back (and an
    /// undated trip stays undated).
    @State private var before: (Date, Date, Bool)?
    /// OK was pressed with only the first day picked: say what is missing.
    @State private var okTooSoon = false

    private static let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2
        c.timeZone = .current
        return c
    }()
    private static let weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            field
            if open { grid }
        }
        .onAppear { if open && before == nil { before = (start, end, dated) } }
    }

    // MARK: The field

    private var field: some View {
        Button {
            // Open: opens on the month of the first day. Open already: the same as OK —
            // with only the first day picked it stays open and says what is missing (the
            // spec pass, 5 Oct 2026: it closed, keeping a one-day trip and "Now tap the
            // last day" on the field, and Create or Save stored the day trip).
            // With no dates yet it opens on this month, not on whatever day the form
            // last held.
            if open { ok() } else {
                open = true; month = dated ? "" : DateRangePicker.ym(Date()); before = (start, end, dated); okTooSoon = false
            }
        } label: {
            HStack(spacing: 12) {
                SectionMark(section: .events, size: 24, weight: 1.8)
                    .foregroundStyle(tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(waitingForEnd ? "Now tap the last day" : "Dates")
                        .font(.system(.footnote, weight: .semibold)).foregroundStyle(Theme.muted)
                    // No dates yet: an invitation in the tint, not a made-up range.
                    Text(!dated ? "Add dates"
                         : waitingForEnd ? DateRangePicker.pretty(start) : "\(DateRangePicker.pretty(start)) — \(DateRangePicker.pretty(end))")
                        .font(.system(.body, weight: .semibold)).foregroundStyle(dated ? Theme.ink : tint)
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .accessibilityIdentifier("\(id)-label")
                }
                Spacer(minLength: 8)
                if dated && !waitingForEnd {
                    Text(nightsText)
                        .font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.muted)
                        .accessibilityIdentifier("\(id)-nights")
                }
            }
            .padding(.horizontal, 12).frame(minHeight: 56)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.bg))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(open ? tint : Theme.line, lineWidth: open ? 2 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier("\(id)-field")
        // What the field says, as its VALUE: the Mac folds a button's texts into the
        // button itself, so "trip-dates-label" never exists there as a text of its own
        // (the Mac UI test on GitHub, 0.21).
        .accessibilityValue(!dated ? "No dates"
                            : waitingForEnd ? DateRangePicker.pretty(start)
                            : "\(DateRangePicker.pretty(start)) — \(DateRangePicker.pretty(end)) · \(nightsText)")
    }

    private var nightsText: String {
        let n = DateRangePicker.cal.dateComponents([.day], from: DateRangePicker.cal.startOfDay(for: start),
                                                   to: DateRangePicker.cal.startOfDay(for: end)).day ?? 0
        return n == 1 ? "1 night" : "\(max(0, n)) nights"
    }

    // MARK: The grid

    private var grid: some View {
        let first = month.isEmpty ? DateRangePicker.ym(start) : month
        let two = width >= 600
        return VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 24) {
                monthView(first, index: 0, showPrev: true, showNext: !two)
                if two { monthView(DateRangePicker.shift(first, by: 1), index: 1, showPrev: false, showNext: true) }
            }
            // What OK will keep, under the grid where the eye already is — or, when OK
            // came before the last day, what is still missing (in its place, not as
            // one more line).
            if okTooSoon && waitingForEnd {
                Text("Tap the last day first \u{2014} the same day again for a day trip.")
                    .font(.system(.callout, weight: .semibold)).foregroundStyle(AppSection.actions.color)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("range-needs")
            } else {
                Text(!dated ? "Tap the first day, then the last"
                     : waitingForEnd ? "Now tap the last day"
                     : "\(DateRangePicker.short(start)) \u{2013} \(DateRangePicker.short(end)) \u{00B7} \(nightsText)")
                    .font(.system(.body, weight: .semibold).monospacedDigit())
                    .foregroundStyle(waitingForEnd || !dated ? Theme.muted : Theme.ink)
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("range-summary")
            }
            // Their field test (Oct 2026): "When I choose the end date, don't
            // just pop out back, but stay there and present an OK button or a cancel
            // button." Cancel is the way out without picking (his test C.2: "I do not
            // come out of this date"): the dates go back to what they were. OK keeps
            // them — in full colour, always (his rule for a main button, 2026-09-26).
            HStack(spacing: 10) {
                // The way to a trip with NO dates, now that there is no Dates switch to
                // turn off (0.67): left, quiet, away from OK — Airbnb's place for it.
                if dated {
                    Button("Clear dates") { clear() }
                        .buttonStyle(.plain).focusEffectDisabled()
                        .font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.muted)
                        .frame(minHeight: Metrics.header).contentShape(Rectangle())
                        .accessibilityIdentifier("range-clear")
                }
                Spacer()
                Button("Cancel") { cancel() }
                    .buttonStyle(HeaderButtonStyle(tint: tint, filled: false)).focusEffectDisabled()
                    .accessibilityIdentifier("range-cancel")
                Button { ok() } label: { Text("OK").frame(minWidth: 44) }
                    .buttonStyle(HeaderButtonStyle(tint: tint, filled: true)).focusEffectDisabled()
                    .accessibilityIdentifier("range-ok")
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }

    private func monthView(_ ym: String, index: Int, showPrev: Bool, showNext: Bool) -> some View {
        let cells = DateRangePicker.cells(ym)
        let weeks = DateRangePicker.sixWeeks(cells)
        return VStack(spacing: 6) {
            HStack {
                if showPrev { arrow(-1, "M15 6l-6 6 6 6", "range-prev") } else { Color.clear.frame(width: 40, height: 36) }
                Spacer()
                Text(DateRangePicker.title(ym))
                    .font(.system(.body, weight: .semibold)).foregroundStyle(Theme.ink)
                    .accessibilityIdentifier("range-title-\(index)")
                Spacer()
                if showNext { arrow(1, "M9 6l6 6-6 6", "range-next") } else { Color.clear.frame(width: 40, height: 36) }
            }
            HStack(spacing: 0) {
                ForEach(DateRangePicker.weekdays, id: \.self) { d in
                    Text(d).font(.system(.caption, weight: .semibold)).foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity)
                }
            }
            // Plain rows, not a lazy grid: a lazy grid builds only what is on screen
            // (the care calendar's lesson on the Mac, 0.18).
            ForEach(weeks.indices, id: \.self) { w in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { i in
                        if i < weeks[w].count, let day = weeks[w][i] { dayCell(day) }
                        else { Color.clear.frame(maxWidth: .infinity, minHeight: Metrics.compact) }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func dayCell(_ day: Date) -> some View {
        let c = DateRangePicker.cal
        let d = c.startOfDay(for: day)
        let s = c.startOfDay(for: start), e = c.startOfDay(for: end)
        let isStart = dated && d == s
        let isEnd = dated && !waitingForEnd && d == e
        let between = dated && !waitingForEnd && d > s && d < e
        let today = d == c.startOfDay(for: Date())
        let past = d < c.startOfDay(for: Date())
        let key = DateRangePicker.ymd(day)
        return Button { pick(d) } label: {
            Text("\(c.component(.day, from: day))")
                .font(.system(.callout, weight: isStart || isEnd || between || today ? .semibold : .regular).monospacedDigit())
                .foregroundStyle(isStart || isEnd ? Color.white : (past ? Theme.muted : Theme.ink))
                .frame(maxWidth: .infinity, minHeight: Metrics.compact)
                .background {
                    ZStack {
                        // The shaded band runs edge to edge, so the nights read as one stretch.
                        if between { tint.opacity(0.14) }
                        if isStart && !waitingForEnd && e > s { tint.opacity(0.14).padding(.leading, 20) }
                        if isEnd && e > s { tint.opacity(0.14).padding(.trailing, 20) }
                        if isStart || isEnd { RoundedRectangle(cornerRadius: 8).fill(tint) }
                        if today && !(isStart || isEnd) { RoundedRectangle(cornerRadius: 8).stroke(tint, lineWidth: 1.5).padding(2) }
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier("range-day-\(key)")
        .accessibilityAddTraits(isStart || isEnd ? .isSelected : [])
    }

    private func cancel() {
        if let b = before { start = b.0; end = b.1; dated = b.2 }
        waitingForEnd = false
        okTooSoon = false
        open = false
    }

    /// No dates at all: the field says "Add dates" again, and the trip is made (or
    /// saved) without any.
    private func clear() {
        dated = false
        waitingForEnd = false
        okTooSoon = false
        open = false
    }

    /// Keeps the range picked. With only the first day picked it stays open and
    /// says what is missing, rather than guess.
    private func ok() {
        if waitingForEnd { okTooSoon = true; return }
        okTooSoon = false
        open = false
    }

    /// First tap: the first day. Second tap: the last day — or, if it is before the
    /// first, a new first day. A tap after a whole range starts a new one. The grid
    /// stays open until OK or Cancel.
    private func pick(_ d: Date) {
        okTooSoon = false
        dated = true
        if waitingForEnd && d >= DateRangePicker.cal.startOfDay(for: start) {
            end = d
            waitingForEnd = false
        } else {
            start = d
            end = d
            waitingForEnd = true
        }
    }

    private func arrow(_ by: Int, _ path: String, _ id: String) -> some View {
        Button {
            let base = month.isEmpty ? DateRangePicker.ym(start) : month
            month = DateRangePicker.shift(base, by: by)
        } label: {
            SVGPath.path(path)
                .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .frame(width: 22, height: 22).foregroundStyle(Theme.ink)
                .frame(width: 40, height: 36).contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier(id)
    }

    // MARK: Dates

    /// A month as SIX rows of seven, the blanks after its last day filled in — so the
    /// grid keeps one height from month to month and OK and Cancel never move under his
    /// finger (the spec pass, 5 Oct 2026; the model's `monthGrid` was made "so the panel
    /// never jumps" — a month drew four to six rows here, and the panel jumped).
    static func sixWeeks(_ cells: [Date?]) -> [[Date?]] {
        let padded = cells + Array(repeating: nil, count: max(0, 42 - cells.count))
        return stride(from: 0, to: 42, by: 7).map { Array(padded[$0..<$0 + 7]) }
    }

    /// The month's cells, Monday first: nil for the blanks before the 1st.
    static func cells(_ ym: String) -> [Date?] {
        guard let first = date(ym + "-01") else { return [] }
        let lead = (cal.component(.weekday, from: first) + 5) % 7        // Monday = 0
        let count = cal.range(of: .day, in: .month, for: first)?.count ?? 30
        let days = (0..<count).compactMap { cal.date(byAdding: .day, value: $0, to: first) }
        return Array(repeating: nil, count: lead) + days.map { Optional($0) }
    }

    static func date(_ ymd: String) -> Date? {
        let p = ymd.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return nil }
        return cal.date(from: DateComponents(year: p[0], month: p[1], day: p[2]))
    }

    static func ymd(_ d: Date) -> String {
        let c = cal.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year ?? 1970, c.month ?? 1, c.day ?? 1)
    }

    static func ym(_ d: Date) -> String { String(ymd(d).prefix(7)) }

    static func shift(_ ym: String, by months: Int) -> String {
        let y = Int(ym.prefix(4)) ?? 1970, m = Int(ym.dropFirst(5).prefix(2)) ?? 1
        let total = y * 12 + (m - 1) + months
        return String(format: "%04d-%02d", total / 12, total % 12 + 1)
    }

    private static let monthNames = ["January", "February", "March", "April", "May", "June", "July",
                                     "August", "September", "October", "November", "December"]
    private static let shortMonths = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    static func title(_ ym: String) -> String {
        let m = Int(ym.dropFirst(5).prefix(2)) ?? 1
        return "\(monthNames[max(0, min(11, m - 1))]) \(ym.prefix(4))"
    }

    /// "3 Nov" — the summary over OK.
    static func short(_ d: Date) -> String {
        let c = cal.dateComponents([.day, .month], from: d)
        return "\(c.day ?? 1) \(shortMonths[max(0, min(11, (c.month ?? 1) - 1))])"
    }

    /// "Sat 26 Sep" — English words, written the same on every device.
    static func pretty(_ d: Date) -> String {
        let c = cal.dateComponents([.weekday, .day, .month], from: d)
        let wd = weekdays[((c.weekday ?? 2) + 5) % 7]
        return "\(wd) \(c.day ?? 1) \(shortMonths[max(0, min(11, (c.month ?? 1) - 1))])"
    }
}
