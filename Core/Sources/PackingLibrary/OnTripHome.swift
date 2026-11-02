import Foundation
import PackingCore

// "On your trip" on Home (0.108) — his words, 2 Nov 2026, on a trip: "I am currently on a trip,
// but I can't see it on the home page." Home counted down only a trip still to leave
// (`nextTrip`: "A trip under way is no countdown"), so while he was away Home said nothing of
// the trip at all. He saw the picture of one card that follows the moment and said
// "excellent":
//
//  • Under way — set off (`hasSetOff`: its first day, from the time he leaves) and its last day
//    not passed: "On your trip", the day of the trip ("Day 3 of 7 · home on Sunday"), what is to
//    do today, Where is my…?, and Pack to go home ("Opens on Saturday").
//  • Going home — the trip's last day or the day before it (its end date; "you leave at 10:00"
//    from the time he leaves for home, `leaveHomeAt`): what is still to pack for home, and
//    Charge tonight while the To charge card has something left.
//  • Back home — the day after the last day, until the trip is reviewed (or two weeks have
//    gone by): "Welcome home", how long it was and how much went along, and Review.
//
// The moment is worked out here, from the dates and this device's clock (`today`, `time`);
// Home draws it (`OnTripCard`). `nextTrip` stays as it was for the trips ahead.

/// How long after its last day a trip not yet reviewed is still welcomed home on Home. After
/// that Home lets it go: a trip from a month ago is no "Welcome home".
public let BACK_HOME_DAYS = 14

extension Library {
    /// Where the trip on Home's card stands.
    public enum TripMoment: String, Sendable, CaseIterable {
        case underWay, goingHome, backHome
    }

    /// Home's "On your trip" card: the trip, its moment, and what the card says.
    public struct OnTripCard: Equatable, Sendable {
        public var moment: TripMoment
        public var id: String
        public var name: String
        /// Where it is — the trip's place, else the forecast's ("Torremolinos").
        public var place: String
        public var firstDay: String
        /// The trip's last day — its end date, else its start (a day trip).
        public var lastDay: String
        /// Today's day of the trip, 1 = the first; on the way home after the last, `days`.
        public var day: Int
        /// How many days the trip has, the first and the last included.
        public var days: Int
        /// "I leave at" for home on the last day, "16:00" — "" when none is set.
        public var leaveHome: String
        /// Going home today and the time he leaves for home has come.
        public var hasLeft: Bool
        /// What is to do today: the trip's reminders that are due (`dueReminders`), then his
        /// things' own (`dueThingReminders`), by name.
        public var due: [String]
        /// Pack to go home in numbers (`homeProgress`).
        public var homeDone: Int
        public var homeTotal: Int
        /// The To charge card's things still to charge today, by name (`chargeCard`).
        public var charge: [String]
        /// The things that went along: ticked on the way out, not set aside, not reminders.
        public var went: Int
        /// Today's weather at the trip's place, from the forecast the trip holds — nil when it
        /// holds none for today.
        public var weather: TodaysWeather?
        /// The day `today` was, so the words below can say "tomorrow" and "Saturday".
        public var today: String

        /// The band's first line (Home writes it in capitals).
        public var title: String {
            switch moment {
            case .underWay: return "On your trip"
            case .goingHome: return today == lastDay ? "Going home today" : "Going home tomorrow"
            case .backHome: return "Welcome home"
            }
        }

        /// The band's last line: "Day 3 of 7 · home on Sunday", "Day 6 of 7 · you leave at 10:00",
        /// "Day 7 of 7 · you left at 10:00", "7 days · 64 things went along".
        public var dayLine: String {
            switch moment {
            case .underWay:
                return "Day \(day) of \(days) \u{00B7} home \(Library.onDay(lastDay, from: today))"
            case .goingHome:
                let head = "Day \(day) of \(days)"
                guard !leaveHome.isEmpty else { return head }
                return "\(head) \u{00B7} \(hasLeft ? "you left" : "you leave") at \(leaveHome)"
            case .backHome:
                let long = days == 1 ? "1 day" : "\(days) days"
                guard went > 0 else { return long }
                return "\(long) \u{00B7} \(went == 1 ? "1 thing went" : "\(went) things went") along"
            }
        }

        /// The day Pack to go home leads the card: the day before the last.
        public var packHomeOpens: String { Library.ymd(lastDay, plusDays: -1) }

        /// Pack to go home's line: "Opens on Saturday" while under way; then "18 of 64 still to
        /// pack", "All 64 packed", or "Nothing to bring home yet".
        public var packHomeLine: String {
            if moment == .underWay {
                let when = Library.onDay(packHomeOpens, from: today)
                return "Opens \(when)"
            }
            if homeTotal == 0 { return "Nothing to bring home yet" }
            if homeLeft == 0 { return "All \(homeTotal) packed" }
            return "\(homeLeft) of \(homeTotal) still to pack"
        }

        /// What is still to pack for home.
        public var homeLeft: Int { max(0, homeTotal - homeDone) }

        /// The day segments of the band: one per day, the days up to today lit. Nil for a trip
        /// too long to draw a segment a day (`DAY_SEGMENTS_MOST`): Home draws one bar instead.
        public var segments: [Bool]? {
            guard moment != .backHome, days <= DAY_SEGMENTS_MOST else { return nil }
            return (1...max(1, days)).map { $0 <= day }
        }
    }

    /// Today's weather on the card: the forecast's drawing for the day, its highest
    /// temperature, and the place.
    public struct TodaysWeather: Equatable, Sendable {
        /// The forecast's icon key — "sun", "sun-cloud", "cloud", "fog", "rain", "snow", "storm".
        public var icon: String
        /// What the sky does, "Partly cloudy".
        public var label: String
        /// Today's highest, whole degrees Celsius.
        public var high: Int
        /// "23°".
        public var says: String { "\(high)\u{00B0}" }
    }

    /// The last day of a trip: its end date, else its start (a day trip).
    public static func lastDay(_ trip: TripEvent) -> String {
        let end = jsTrim(trip.endDate)
        return isYMD(end) ? end : jsTrim(trip.startDate)
    }

    /// Home's trip card for now — `today` ("YYYY-MM-DD") at `time` ("HH:mm", this device's
    /// clock) — or nil when no trip is under way, going home or just back.
    ///
    /// A trip under way or going home comes first: of several, the one that set off last. Else a
    /// trip back home and not reviewed whose last day was at most `BACK_HOME_DAYS` ago and that has
    /// lines (there is nothing to review on an empty one): of several, the one back most recently.
    /// A reviewed trip, an undated one, and one still to leave are never on it.
    public func onTripCard(today: String, time: String = END_OF_DAY) -> OnTripCard? {
        guard isYMD(today) else { return nil }
        let dated = trips.filter { !Library.isReviewed($0) && isYMD(jsTrim($0.startDate)) }
        let away = dated.filter { t in
            Library.hasSetOff(t, today: today, time: time) && !jsStringLess(Library.lastDay(t), today)
        }
        .stableSorted(by: { a, b in jsStringLess(b.startDate, a.startDate) })
        if let t = away.first {
            let last = Library.lastDay(t)
            let moment: TripMoment = jsStringLess(today, Library.ymd(last, plusDays: -1)) ? .underWay : .goingHome
            return card(t, moment, today: today, time: time)
        }
        let back = dated.filter { t in
            let last = Library.lastDay(t)
            return !t.entries.isEmpty && jsStringLess(last, today)
                && !jsStringLess(Library.ymd(last, plusDays: BACK_HOME_DAYS), today)
        }
        .stableSorted(by: { a, b in jsStringLess(Library.lastDay(b), Library.lastDay(a)) })
        return back.first.map { card($0, .backHome, today: today, time: time) }
    }

    private func card(_ t: TripEvent, _ moment: TripMoment, today: String, time: String) -> OnTripCard {
        let first = jsTrim(t.startDate), last = Library.lastDay(t)
        let days = max(1, (nightsBetween(first, last) ?? 0) + 1)
        let since = max(0, -(daysUntil(first, today) ?? 0))
        let leave = Library.leaveTime(t, home: true)
        let home = homeProgress(tripId: t.id)
        let went = t.entries.filter { $0.checked && !isSetAside($0) && !Library.isReminder($0) }.count
        let due = moment == .backHome ? [] : dueReminders(tripId: t.id, today: today).map(\.name)
            + dueThingReminders(tripId: t.id, today: today).map(\.name)
        let charge = moment == .goingHome ? chargeCard(tripId: t.id, today: today).filter { !$0.charged }.map(\.name) : []
        let left = moment == .goingHome && today == last && !leave.isEmpty
            && !jsStringLess(Library.cleanTime(time) ?? END_OF_DAY, leave)
        return OnTripCard(moment: moment, id: t.id, name: t.name, place: tripPlace(t), firstDay: first, lastDay: last,
                          day: min(days, since + 1), days: days, leaveHome: leave, hasLeft: left, due: due,
                          homeDone: home.done, homeTotal: home.total, charge: charge, went: went,
                          weather: moment == .backHome ? nil : todaysWeather(t, today: today), today: today)
    }

    /// The trip's place in a word or two: the place he gave it, else the forecast's name before
    /// its country ("Testville, SE" → "Testville").
    private func tripPlace(_ t: TripEvent) -> String {
        let own = jsTrim(t.destination)
        if !own.isEmpty { return own }
        let sky = jsTrim(t.weather?.place ?? "")
        return jsTrim(String(sky.split(separator: ",").first ?? ""))
    }

    /// Today's day of the forecast the trip holds, when it holds one with a temperature.
    func todaysWeather(_ t: TripEvent, today: String) -> TodaysWeather? {
        guard let sky = deriveWeather(t), let d = sky.days.first(where: { $0.date == today }), let high = d.tmax,
              high.isFinite else { return nil }
        return TodaysWeather(icon: d.icon, label: d.label, high: Int(high.rounded()))
    }

    // MARK: - The words for a day

    private static let weekdays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    private static let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    /// The day of the week a "YYYY-MM-DD" falls on, "Sunday" — "" when it is not a date.
    public static func weekdayName(_ ymd: String) -> String {
        guard isYMD(ymd), let n = daysUntil(ymd, "1970-01-04") else { return "" }   // 4 Jan 1970 was a Sunday
        return weekdays[((n % 7) + 7) % 7]
    }

    /// A day as the card says it, seen from `today`: "today", "tomorrow", "on Saturday" within the
    /// week ahead, else "on 12 Nov".
    public static func onDay(_ ymd: String, from today: String) -> String {
        guard let n = daysUntil(ymd, today) else { return "" }
        if n == 0 { return "today" }
        if n == 1 { return "tomorrow" }
        if (2...6).contains(n) { return "on \(weekdayName(ymd))" }
        let p = ymd.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3, (1...12).contains(p[1]) else { return "on \(ymd)" }
        return "on \(p[2]) \(months[p[1] - 1])"
    }
}

/// The most days the band draws one segment each for; a longer trip gets one bar.
public let DAY_SEGMENTS_MOST = 21

// The forecast's drawings (0.108), for today's weather on Home's trip card. His rule: drawn in the
// app's own hand, never stock art or emoji — one 1.9 stroke on the 24-point grid, round caps and
// joins, no fill, only the path commands the app draws (M L H V C S Q A Z). The sun, the rain and
// the snow are the template icons' own; the cloud is the rain's without its drops.

/// A forecast's mark: `key` is the forecast's icon key (`weatherCode`), `path` the drawing.
public struct WeatherMark: Equatable, Sendable {
    public let key: String
    public let path: String

    static let cloud = "M7 18a4 4 0 0 1-.5-8 5.5 5.5 0 0 1 10.6 1.3 3.4 3.4 0 0 1 .4 6.7Z"

    /// Every key `weatherCode` gives, with its drawing.
    public static let all: [WeatherMark] = [
        WeatherMark(key: "sun", path: TemplateIconCatalog.icon("sun")?.path ?? ""),
        WeatherMark(key: "sun-cloud", path: "M5 8a3 3 0 1 0 6 0a3 3 0 1 0 -6 0 M8 2.5v1.3 M2.5 8h1.3 M4.1 4.1l.9.9 M11.9 4.1l-.9.9"
                    + " M10.5 20.5a3.3 3.3 0 0 1-.4-6.6 4.5 4.5 0 0 1 8.7 1 2.8 2.8 0 0 1 .3 5.6Z"),
        WeatherMark(key: "cloud", path: cloud),
        WeatherMark(key: "fog", path: "M5 8h14 M3.5 12h17 M5 16h14 M8 20h8"),
        WeatherMark(key: "rain", path: TemplateIconCatalog.icon("rain")?.path ?? ""),
        WeatherMark(key: "snow", path: TemplateIconCatalog.icon("snow")?.path ?? ""),
        WeatherMark(key: "storm", path: "M7 14a4 4 0 0 1-.5-8 5.5 5.5 0 0 1 10.6 1.3 3.4 3.4 0 0 1 .4 6.7Z M12.8 15.8 10.6 18.6h3l-2.2 3"),
    ]

    /// The drawing for a forecast's icon key; the cloud for one it does not know.
    public static func path(_ key: String) -> String {
        all.first { $0.key == key }?.path ?? cloud
    }
}
