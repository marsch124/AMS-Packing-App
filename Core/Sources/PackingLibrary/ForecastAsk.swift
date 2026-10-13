import Foundation
import PackingCore

// Asking Open-Meteo for a trip's forecast: which days to ask for, and what its answer
// means when it is not a forecast. Pure — the app's `OpenMeteo`
// (App/Sources/Store/Forecast.swift) does the asking — so every edge is tested here,
// without the network.
//
// 0.73, his report of 12 Oct 2026: a trip to Spain about two weeks ahead said "Could not
// reach the weather service — check the connection." while the internet worked. The app
// asked for one day more than the service forecasts (the reach was 16 days, the service
// stops at 15), the service said no to the dates, and ANY "no" was read as no connection.

/// What went wrong with a look-up, in his words — said under the weather card.
public enum ForecastTrouble: LocalizedError, Equatable {
    /// The map service knows no place by that name.
    case noSuchPlace(String)
    /// No answer at all: no connection, or the service could not be reached.
    case offline
    /// The service answered, but has no forecast for the trip's days (too far ahead).
    case nothingYet
    /// The service answered with a "no" of its own that is not about the days.
    case serviceTrouble

    public var errorDescription: String? {
        switch self {
        case .noSuchPlace(let name): return "No place found for “\(name)”."
        case .offline: return "Could not reach the weather service — check the connection."
        case .nothingYet: return "No forecast for those dates yet."
        case .serviceTrouble: return "The weather service could not answer just now — try again later."
        }
    }
}

/// The days of a forecast request: `start_date` … `end_date`, both YYYY-MM-DD.
public struct ForecastDays: Equatable, Sendable {
    public var start: String
    public var end: String
    public init(start: String, end: String) { self.start = start; self.end = end }
}

public enum ForecastAsk {
    /// Open-Meteo forecasts today and the 15 days after it — 16 days in all. A day past
    /// that is refused with "Parameter 'end_date' is out of allowed range from … to
    /// <today + 15>" (checked 12 Oct 2026). Until 0.73 this was 16: one day too many.
    public static let reachDays = 15

    /// The last day the service forecasts. Its "today" is the UTC date wherever the place
    /// is (the same last day at UTC−10, UTC+0 and UTC+14, checked 12 Oct 2026); in Sweden
    /// the date on the phone is a day ahead of that from midnight until 01:00 (02:00 in
    /// summer). So the reach is counted from the EARLIER of the two dates.
    /// `today` = his date (`Today.local`), `utcToday` = the UTC date (`todayYMD()`).
    public static func lastDay(today: String, utcToday: String) -> String {
        let from = (daysBetween(utcToday, today) ?? 0) > 0 ? utcToday : today
        return addDays(from, reachDays)
    }

    /// A trip that starts past the service's last day has no forecast yet: the day one
    /// first exists, `reachDays` before the trip starts (start − 15). nil when a forecast
    /// can be asked for now — the trip starts within reach, is under way or over, or has
    /// no date (an undated trip is asked for the service's own days: today's weather on).
    ///
    /// 0.75: such a trip was asked for the service's DEFAULT days — this week — and the card
    /// showed this week's weather as if it were the trip's. It is no longer asked at all.
    public static func comesFrom(startDate: String, today: String, utcToday: String) -> String? {
        guard !startDate.isEmpty, let left = daysBetween(startDate, lastDay(today: today, utcToday: utcToday)),
              left < 0 else { return nil }
        return addDays(startDate, -reachDays)
    }

    /// The trip's own days to ask for: from its start to its last day (start + nights),
    /// cut at the reach. nil when the trip does not start between today and the reach —
    /// then the service's default days are asked for, as the web app does (but never for
    /// a trip past the reach: `comesFrom`, 0.75).
    public static func days(startDate: String, nights: Int, today: String, utcToday: String) -> ForecastDays? {
        guard !startDate.isEmpty, let ahead = daysBetween(today, startDate), ahead >= 0 else { return nil }
        let reach = lastDay(today: today, utcToday: utcToday)
        guard let left = daysBetween(startDate, reach), left >= 0 else { return nil }
        let last = addDays(startDate, max(0, nights))
        let beyond = (daysBetween(reach, last) ?? 0) > 0
        return ForecastDays(start: startDate, end: beyond ? reach : last)
    }

    /// Can a forecast exist for this trip at all — so it is worth looking up by itself as
    /// the trip opens? It starts no later than the reach, and is not over yet (it started
    /// at most `nights` days ago). Whether the forecast held is stale is the library's
    /// other half of that question (`forecastIsStale`).
    public static func inReach(startDate: String, nights: Int, today: String, utcToday: String) -> Bool {
        guard let ahead = daysBetween(today, startDate) else { return false }
        guard ahead >= -max(0, nights) else { return false }
        guard let left = daysBetween(startDate, lastDay(today: today, utcToday: utcToday)) else { return false }
        return left >= 0
    }

    /// What an answer from the service means when it is not a forecast; nil when it is one
    /// (a status below 400). An answer is never "offline": the connection worked. The
    /// service says why in `{"error": true, "reason": "…"}` — days it does not forecast are
    /// "No forecast for those dates yet."; any other "no" (busy, broken, refused) is
    /// trouble on the service's side. (Never shown as the service wrote it: his rule, no
    /// computer talk.)
    public static func trouble(status: Int, body: Data) -> ForecastTrouble? {
        guard status >= 400 else { return nil }
        let reason = (try? JSONValue.parse(body))?["reason"]?.stringValue ?? ""
        let aboutTheDays = reason.contains("out of allowed range")
            && (reason.contains("start_date") || reason.contains("end_date"))
        return aboutTheDays ? .nothingYet : .serviceTrouble
    }
}
