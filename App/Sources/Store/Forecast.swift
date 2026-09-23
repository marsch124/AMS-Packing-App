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

enum ForecastTrouble: LocalizedError {
    case noSuchPlace(String), offline, nothingYet
    var errorDescription: String? {
        switch self {
        case .noSuchPlace(let name): return "No place found for “\(name)”."
        case .offline: return "Could not reach the weather service — check the connection."
        case .nothingYet: return "No forecast for those dates yet."
        }
    }
}

/// Open-Meteo: free, no key, and the same two calls the web app makes, so both
/// apps read the same numbers for the same trip (`js/weather.js`).
struct OpenMeteo: Forecaster {
    /// The forecast only reaches about a fortnight ahead.
    static let reachDays = 16

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
        // The trip's own dates when they are within reach; otherwise whatever the
        // service gives by default, as the web app does.
        if !startDate.isEmpty, let ahead = OpenMeteo.days(from: today, to: startDate), ahead >= 0, ahead <= OpenMeteo.reachDays {
            let last = OpenMeteo.day(startDate, plus: max(0, nights))
            let lastAhead = OpenMeteo.days(from: today, to: last) ?? 0
            items.append(.init(name: "start_date", value: startDate))
            items.append(.init(name: "end_date",
                               value: lastAhead > OpenMeteo.reachDays ? OpenMeteo.day(today, plus: OpenMeteo.reachDays) : last))
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

    private func read(_ url: URLComponents) async throws -> JSONValue {
        guard let address = url.url else { throw ForecastTrouble.offline }
        do {
            let (data, answer) = try await URLSession.shared.data(from: address)
            guard (answer as? HTTPURLResponse)?.statusCode ?? 0 < 400 else { throw ForecastTrouble.offline }
            return try JSONValue.parse(data)
        } catch let trouble as ForecastTrouble {
            throw trouble
        } catch {
            throw ForecastTrouble.offline
        }
    }

    static func days(from: String, to: String) -> Int? {
        guard let a = Today.date(from), let b = Today.date(to) else { return nil }
        return Int((b.timeIntervalSince(a) / 86_400).rounded())
    }
    static func day(_ iso: String, plus n: Int) -> String {
        guard let d = Today.date(iso) else { return iso }
        return Today.iso(d.addingTimeInterval(Double(n) * 86_400))
    }
}

/// The tests' weather: a fixed wet, cold few days at a fixed place, so a test can
/// say exactly what the trip should then show. Never used outside `-uiTesting`.
struct InventedForecast: Forecaster {
    func place(named name: String) async throws -> Place {
        if name.lowercased().contains("nowhere") { throw ForecastTrouble.noSuchPlace(name) }
        return Place(lat: 58.59, lon: 16.18, name: "Testville, SE")
    }
    func forecast(at place: Place, from startDate: String, nights: Int, today: String) async throws -> WeatherSnapshot {
        let first = startDate.isEmpty ? today : startDate
        let days = (0...max(1, nights)).map { n in
            WeatherDay(date: OpenMeteo.day(first, plus: n), code: 61,     // rain
                       tmax: 8, tmin: 2, precipProb: 90, wind: 24)
        }
        return WeatherSnapshot(place: place.name, lat: place.lat, lon: place.lon, fetchedAt: nowISO(), daily: days)
    }
}

private extension Array {
    subscript(safe n: Int) -> Element? { indices.contains(n) ? self[n] : nil }
}
