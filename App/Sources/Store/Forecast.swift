import Foundation
import PackingCore
import PackingLibrary

/// Where a forecast comes from. The app asks this, never the network directly, so
/// the tests can hand it a known day's weather instead.
protocol Forecaster: Sendable {
    /// A place name → a spot on the map, and the name as the map service says it.
    func place(named: String) async throws -> Place
    /// The daily forecast for a trip, as the model wants it.
    func forecast(at: Place, from startDate: String, nights: Int, today: String) async throws -> WeatherSnapshot
}

struct Place: Equatable, Sendable {
    var lat: Double
    var lon: Double
    var name: String
}

// What can go wrong, and what each says under the card: `ForecastTrouble`
// (PackingLibrary/ForecastAsk.swift), with the days to ask for — tested there.

/// Open-Meteo: free, no key, and the same two calls the web app makes, so both
/// apps read the same numbers for the same trip (`js/weather.js`).
struct OpenMeteo: Forecaster {
    func place(named name: String) async throws -> Place {
        var url = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        url.queryItems = [.init(name: "name", value: name), .init(name: "count", value: "1"),
                          .init(name: "language", value: "en"), .init(name: "format", value: "json")]
        let found = try await read(url)
        guard let first = found["results"]?.arrayValue?.first else { throw ForecastTrouble.noSuchPlace(name) }
        guard let lat = first["latitude"]?.numberValue, let lon = first["longitude"]?.numberValue else {
            throw ForecastTrouble.noSuchPlace(name)
        }
        let said = [first["name"]?.stringValue ?? "", first["country_code"]?.stringValue ?? ""]
            .filter { !$0.isEmpty }.joined(separator: ", ")
        return Place(lat: lat, lon: lon, name: said.isEmpty ? name : said)
    }

    func forecast(at place: Place, from startDate: String, nights: Int, today: String) async throws -> WeatherSnapshot {
        var url = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        var items: [URLQueryItem] = [
            .init(name: "latitude", value: String(place.lat)), .init(name: "longitude", value: String(place.lon)),
            .init(name: "timezone", value: "auto"),
            .init(name: "daily", value: "weathercode,temperature_2m_max,temperature_2m_min,precipitation_probability_max,windspeed_10m_max"),
        ]
        // A trip past the reach is never asked for the service's own days — this week's
        // weather shown as the trip's (0.75; `lookUpWeather` does not ask, this is the
        // second lock).
        if ForecastAsk.comesFrom(startDate: startDate, today: today, utcToday: todayYMD()) != nil {
            throw ForecastTrouble.nothingYet
        }
        // The trip's own dates when they are within reach (cut at the service's last
        // day, `ForecastAsk`); otherwise (under way, or no dates) whatever the service
        // gives by default — today on — as the web app does.
        if let days = ForecastAsk.days(startDate: startDate, nights: nights, today: today, utcToday: todayYMD()) {
            items.append(.init(name: "start_date", value: days.start))
            items.append(.init(name: "end_date", value: days.end))
        }
        url.queryItems = items
        let answer = try await read(url)
        let daily = answer["daily"] ?? .null
        let dates = daily["time"]?.arrayValue ?? []
        guard !dates.isEmpty else { throw ForecastTrouble.nothingYet }
        func at(_ key: String, _ n: Int) -> Double? { daily[key]?.arrayValue?[safe: n]?.numberValue }
        let days: [WeatherDay] = dates.enumerated().map { n, date in
            WeatherDay(date: date.stringValue ?? "", code: at("weathercode", n) ?? 0,
                       tmax: at("temperature_2m_max", n), tmin: at("temperature_2m_min", n),
                       precipProb: at("precipitation_probability_max", n) ?? 0,
                       wind: at("windspeed_10m_max", n) ?? 0)
        }
        return WeatherSnapshot(place: place.name, lat: place.lat, lon: place.lon, fetchedAt: nowISO(), daily: days)
    }

    /// One call. No answer at all is "offline"; an answer that is not a forecast says
    /// what it is (`ForecastAsk.trouble`) — the connection worked, so it is never
    /// "check the connection" (his report, 12 Oct 2026: the service had said no to the
    /// days, and he was sent to check a working internet).
    private func read(_ url: URLComponents) async throws -> JSONValue {
        guard let address = url.url else { throw ForecastTrouble.offline }
        let data: Data, answer: URLResponse
        do {
            (data, answer) = try await URLSession.shared.data(from: address)
        } catch {
            throw ForecastTrouble.offline
        }
        if let trouble = ForecastAsk.trouble(status: (answer as? HTTPURLResponse)?.statusCode ?? 0, body: data) {
            throw trouble
        }
        guard let parsed = try? JSONValue.parse(data) else { throw ForecastTrouble.serviceTrouble }
        return parsed
    }
}

/// The tests' weather: a fixed wet, cold few days at a fixed place, so a test can
/// say exactly what the trip should then show. Never used outside `-uiTesting`.
struct InventedForecast: Forecaster {
    func place(named name: String) async throws -> Place {
        if name.lowercased().contains("nowhere") { throw ForecastTrouble.noSuchPlace(name) }
        // A place that exists but has no forecast for the trip's dates (his G.6).
        if name.lowercased().contains("late") { return Place(lat: 57.71, lon: 11.97, name: "Lateville, SE") }
        return Place(lat: 61.5, lon: 14.25, name: "Testville, SE")
    }
    func forecast(at place: Place, from startDate: String, nights: Int, today: String) async throws -> WeatherSnapshot {
        if place.name.hasPrefix("Lateville") { throw ForecastTrouble.nothingYet }
        let first = startDate.isEmpty ? today : startDate
        let days = (0...max(1, nights)).map { n in
            WeatherDay(date: addDays(first, n), code: 61,     // rain
                       tmax: 8, tmin: 2, precipProb: 90, wind: 24)
        }
        return WeatherSnapshot(place: place.name, lat: place.lat, lon: place.lon, fetchedAt: nowISO(), daily: days)
    }
}

private extension Array {
    subscript(safe n: Int) -> Element? { indices.contains(n) ? self[n] : nil }
}
