import SwiftUI
import PackingCore
import PackingLibrary

/// The weather on a trip: one line of what it will be like, and under it the gear
/// that weather calls for which is not on the trip yet — each with one press to
/// take it along. It looks the forecast up by itself when the trip is near enough
/// for one to exist; otherwise it waits to be asked.
struct WeatherCard: View {
    let tripId: String
    @EnvironmentObject var model: LibraryModel
    @State private var place = ""
    @State private var asked = false

    private var trip: TripEvent? { model.library.trip(tripId) }
    private var busy: Bool { model.lookingUpWeather.contains(tripId) }

    var body: some View {
        let sky = model.library.weather(tripId: tripId)
        let missing = sky == nil ? [] : model.library.weatherMissing(tripId: tripId)
        VStack(alignment: .leading, spacing: 8) {
            if let sky {
                Text(WeatherCard.line(sky))
                    .font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.ink)
                    .accessibilityIdentifier("weather-line")
                HStack(spacing: 10) {
                    Text(sky.place).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.muted)
                    Spacer()
                    Button { Task { await model.lookUpWeather(tripId: tripId) } } label: {
                        Text(busy ? "Looking…" : "Look again")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(busy ? Theme.muted : AppSection.events.color)
                    }
                    .buttonStyle(.plain).focusEffectDisabled().disabled(busy)
                    .accessibilityIdentifier("weather-again")
                }
                ForEach(Array(missing.enumerated()), id: \.element.name) { n, gear in
                    Button { model.change { _ = $0.addWeatherGear(tripId: tripId, gear) } } label: {
                        HStack(spacing: 12) {
                            Text("+").font(.system(size: 22, weight: .heavy))
                                .foregroundStyle(AppSection.events.color).frame(width: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(gear.name).font(.system(size: 16, weight: .medium)).foregroundStyle(Theme.ink)
                                Text(WeatherCard.why(gear)).font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Theme.muted)
                            }
                            Spacer(minLength: 8)
                        }
                        .padding(.vertical, 6).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("weather-gear-\(n)")
                }
                if missing.isEmpty {
                    Text("You have what this weather asks for.")
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.muted)
                        .accessibilityIdentifier("weather-nothing-missing")
                }
            } else {
                HStack(spacing: 8) {
                    TextField("Where is this trip?", text: $place)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16, weight: .medium)).foregroundStyle(Theme.ink)
                        .padding(.horizontal, 12).frame(minHeight: 40)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.bg))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                        .onSubmit { look() }
                        .accessibilityIdentifier("weather-place")
                    Button { look() } label: {
                        Text(busy ? "Looking…" : "Weather")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(jsTrim(place).isEmpty || busy ? Theme.muted : Color.white)
                            .padding(.horizontal, 14).frame(minHeight: 40)
                            .background(RoundedRectangle(cornerRadius: 10)
                                .fill(jsTrim(place).isEmpty || busy ? Theme.line : AppSection.events.color))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .disabled(jsTrim(place).isEmpty || busy)
                    .accessibilityIdentifier("weather-look")
                }
            }
            if let trouble = model.weatherTrouble[tripId], !trouble.isEmpty {
                Text(trouble).font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppSection.actions.color)
                    .accessibilityIdentifier("weather-trouble")
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("weather-card")
        .onAppear {
            if place.isEmpty { place = trip?.destination ?? "" }
            guard !asked else { return }
            asked = true
            if model.forecastWorthFetching(tripId: tripId) {
                Task { await model.lookUpWeather(tripId: tripId) }
            }
        }
    }

    private func look() {
        let name = jsTrim(place)
        guard !name.isEmpty else { return }
        Task { await model.lookUpWeather(tripId: tripId, place: name) }
    }

    /// "Rain and cold, 2–8°C" — what it will be like, in his words, not a code.
    static func line(_ sky: DerivedWeather) -> String {
        let said = sky.conditions.map { WeatherCard.word($0) }.filter { !$0.isEmpty }
        let head: String
        switch said.count {
        case 0: head = "Nothing to watch out for"
        case 1: head = said[0]
        case 2: head = "\(said[0]) and \(said[1].lowercased())"
        default: head = said.dropLast().joined(separator: ", ") + " and " + said.last!.lowercased()
        }
        return sky.rangeLabel.contains("NaN") || sky.rangeLabel.isEmpty ? head : "\(head), \(sky.rangeLabel)"
    }

    static func word(_ condition: String) -> String {
        switch condition {
        case "rain": return "Rain"
        case "snow": return "Snow"
        case "cold": return "Cold"
        case "hot": return "Heat"
        case "wind": return "Wind"
        default: return condition.isEmpty ? "" : condition.prefix(1).uppercased() + condition.dropFirst()
        }
    }

    /// Why a piece of gear is being offered: the condition, in the same words.
    static func why(_ gear: WeatherGearSpec) -> String {
        let reason = WeatherCard.word(gear.reason ?? "")
        let whose = gear.own ? "yours" : ""
        return [reason.isEmpty ? "" : "for the \(reason.lowercased())", whose]
            .filter { !$0.isEmpty }.joined(separator: " · ")
    }
}
