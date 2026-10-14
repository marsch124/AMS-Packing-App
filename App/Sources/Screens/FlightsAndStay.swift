import SwiftUI
import PackingCore
import PackingLibrary

// Flights and stay — the lost-luggage information, part B (0.80, his yes of 13 Oct 2026; spec 07
// part 18 B). On a plane trip, Create new trip and Trip settings keep the flights (Out and Home,
// connections between), the destination and where he stays until when — what the airline's desk
// asks when a bag does not arrive. The Packing day's Tags and the Bags card keep each bag's tag
// number (`BagTagField`). The model is `PackingLibrary/TripTravel.swift`.

/// The framed block "Flights and stay" — the look of "I leave at" (`LeaveTimes`): a rounded frame in
/// the screen's tint over a very light fill of it, a drawing and a heading, the rows, a hairline and
/// a quiet note. Everything optional. Ids `<id>-…` (see spec 07 part 18 B).
struct FlightsAndStay: View {
    @Binding var travel: TripTravel
    /// The trip's first and last day as the screen holds them now ("" without dates): the days a
    /// leg and the stay show until he picks their own.
    let firstDay: String
    let lastDay: String
    /// The trip's Place: what the desk is given when Destination is left empty.
    let place: String
    let id: String
    let tint: Color
    /// The fields' fill: the card's on a page, the page's on a card.
    var fill: Color = Theme.bg

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                IconMark(path: TemplateIcons.icon("plane")?.path ?? "", size: Metrics.glyph, weight: 1.8)
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
                HeadingTitle(title: "Flights and stay", tint: tint, id: "\(id)-title")
                Spacer(minLength: 8)
                Text("for a lost bag")
                    .font(.system(.footnote)).foregroundStyle(Theme.muted)
                    .lineLimit(1).fixedSize()
                    .accessibilityIdentifier("\(id)-what")
            }
            ForEach(Array(travel.flights.indices), id: \.self) { n in leg(n) }
            Button(action: addFlight) {
                Text("Add a flight").font(.system(.footnote, weight: .semibold)).foregroundStyle(tint)
                    .lineLimit(1).fixedSize()
                    .padding(.horizontal, 10).frame(minHeight: Metrics.chip)
                    .overlay(Capsule().stroke(tint, lineWidth: 1.2))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain).focusEffectDisabled()
            .accessibilityIdentifier("\(id)-add")

            VStack(alignment: .leading, spacing: 4) {
                label("Destination")
                box(jsTrim(place).isEmpty ? "City" : jsTrim(place), $travel.destination, id: "\(id)-destination")
            }
            VStack(alignment: .leading, spacing: 6) {
                label("Where you stay")
                box("Hotel or flat", $travel.stay.name, id: "\(id)-stay-name")
                TextField("Address", text: $travel.stay.address, axis: .vertical)
                    .lineLimit(1...3)
                    .modifier(FieldLook(fill: fill, id: "\(id)-stay-address"))
                box("Phone", $travel.stay.phone, id: "\(id)-stay-phone", phone: true)
                HStack(spacing: 10) {
                    Text("Until").font(.system(.subheadline)).foregroundStyle(Theme.ink)
                        .lineLimit(1).fixedSize()
                    day(shown: isYMD(travel.stay.until) ? travel.stay.until : (isYMD(lastDay) ? lastDay : ""),
                        id: "\(id)-stay-until") { travel.stay.until = $0 }
                    Spacer(minLength: 0)
                }
            }
            Rectangle().fill(Theme.line).frame(height: 1)
                .accessibilityHidden(true)
            Text("Optional. What the airline\u{2019}s desk asks when a bag does not arrive. Each checked bag\u{2019}s tag number goes in on the Packing day, under Tags.")
                .font(.system(.footnote)).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("\(id)-note")
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(tint.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(tint, lineWidth: 1.5))
        // A container of its own: the frame has its id, and every line in it keeps its own.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("\(id)-frame")
    }

    /// Out, Home — and Connection for any between (spec rule 3).
    static func word(_ n: Int, of count: Int) -> String {
        n == 0 ? "Out" : (n == count - 1 ? "Home" : "Connection")
    }

    /// One flight: its word, number and day; under them From → To (and ✕ for a connection).
    private func leg(_ n: Int) -> some View {
        let count = travel.flights.count
        let p = "\(id)-leg-\(n)"
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(FlightsAndStay.word(n, of: count))
                    .font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.ink)
                    .lineLimit(1).fixedSize()
                    .accessibilityIdentifier("\(p)-label")
                box("Flight no.", legText(n, \.number), id: "\(p)-number", code: true)
                day(shown: Library.shownDay(travel.flights, n, firstDay: firstDay, lastDay: lastDay), id: "\(p)-date") { ymd in
                    if travel.flights.indices.contains(n) { travel.flights[n].date = ymd }
                }
            }
            HStack(spacing: 6) {
                box("From", legText(n, \.from), id: "\(p)-from")
                Text("\u{2192}").font(.system(.subheadline)).foregroundStyle(Theme.muted)
                    .accessibilityHidden(true)
                box("To", legText(n, \.to), id: "\(p)-to")
                if n > 0 && n < count - 1 {
                    Button { removeFlight(n) } label: {
                        SVGPath.path("M7 7l10 10M17 7L7 17")
                            .stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                            .onGrid(Metrics.glyph)
                            .foregroundStyle(Theme.muted)
                            .frame(width: Metrics.compact, height: Metrics.compact)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("\(p)-remove")
                    .accessibilityLabel("Remove this flight")
                }
            }
        }
    }

    /// A leg's text, safe against a leg removed under it.
    private func legText(_ n: Int, _ key: WritableKeyPath<FlightLeg, String>) -> Binding<String> {
        Binding(get: { travel.flights.indices.contains(n) ? travel.flights[n][keyPath: key] : "" },
                set: { v in if travel.flights.indices.contains(n) { travel.flights[n][keyPath: key] = v } })
    }

    /// A connection goes BEFORE Home, so what is typed under Out and Home stays under those words.
    private func addFlight() {
        if travel.flights.count < FLIGHT_LEGS_SHOWN { travel.flights = travel.legsForEditing }
        travel.flights.insert(FlightLeg(), at: travel.flights.count - 1)
    }

    private func removeFlight(_ n: Int) {
        guard travel.flights.indices.contains(n), n > 0, n < travel.flights.count - 1 else { return }
        travel.flights.remove(at: n)
    }

    /// A day: the compact system picker on the day shown — or, with none to show (a trip without
    /// dates, nothing picked), "Add a day", which picks today.
    @ViewBuilder
    private func day(shown: String, id: String, set: @escaping (String) -> Void) -> some View {
        if isYMD(shown) {
            DatePicker("", selection: Binding(get: { DateRangePicker.date(shown) ?? Date() },
                                              set: { set(HomeScreen.ymd($0)) }),
                       displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
                .fixedSize()
                .accessibilityIdentifier(id)
        } else {
            Button { set(HomeScreen.ymd(Date())) } label: {
                Text("Add a day").font(.system(.footnote, weight: .semibold)).foregroundStyle(tint)
                    .lineLimit(1).fixedSize()
                    .padding(.horizontal, 10).frame(minHeight: Metrics.chip)
                    .overlay(Capsule().stroke(tint, lineWidth: 1.2))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain).focusEffectDisabled()
            .accessibilityIdentifier("\(id)-add")
        }
    }

    private func label(_ words: String) -> some View {
        Text(words).font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.ink)
    }

    private func box(_ placeholder: String, _ text: Binding<String>, id: String, code: Bool = false, phone: Bool = false) -> some View {
        TextField(placeholder, text: text)
            .modifier(FieldLook(fill: fill, id: id, code: code, phone: phone))
    }
}

/// A field inside the block: Body, the fill given, a hairline border, corner 8. Flight and bag-tag
/// numbers in capitals (`code`), a phone on the phone keypad.
private struct FieldLook: ViewModifier {
    let fill: Color
    let id: String
    var code = false
    var phone = false

    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .font(.system(.body, design: code ? .monospaced : .default)).foregroundStyle(Theme.ink)
            .autocorrectionDisabled()
            #if os(iOS)
            .textInputAutocapitalization(code ? .characters : .words)
            .keyboardType(phone ? .phonePad : .default)
            #endif
            .padding(.horizontal, 8).padding(.vertical, 6)
            .frame(minHeight: Metrics.tap)
            .background(RoundedRectangle(cornerRadius: 8).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 1))
            .accessibilityIdentifier(id)
    }
}

/// The number on a bag's tag from check-in (0.80), for one bag on one trip — the Packing day's Tags
/// and the Bags card. Kept when Return is pressed, when the field loses focus and when it goes
/// away: one change to the library per number, not one per key.
struct BagTagField: View {
    let tripId: String
    let bag: String
    let id: String
    @EnvironmentObject var model: LibraryModel
    @State private var text = ""
    @State private var loaded = false
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text("Bag-tag no.").font(.system(.footnote, weight: .semibold)).foregroundStyle(Theme.muted)
                .lineLimit(1).fixedSize()
            TextField("from check-in", text: $text)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .monospaced)).foregroundStyle(Theme.ink)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.characters)
                #endif
                .padding(.horizontal, 8).frame(minHeight: Metrics.tap)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.bg))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 1))
                .focused($focused)
                .onSubmit(save)
                .accessibilityIdentifier(id)
        }
        .onAppear {
            guard !loaded else { return }
            text = stored
            loaded = true
        }
        .onChange(of: focused) { _, now in if !now { save() } }
        // Changed elsewhere (the other device, the other screen) while not being typed in.
        .onChange(of: stored) { _, new in if !focused { text = new } }
        .onDisappear(perform: save)
    }

    private var stored: String {
        model.library.trips.first { $0.id == tripId }.map { Library.bagTag($0, bag: bag) } ?? ""
    }

    private func save() {
        guard loaded else { return }
        let clean = Library.cleanCode(text)
        if clean != text { text = clean }
        guard clean != stored else { return }
        let t = tripId, b = bag
        model.change { _ = $0.setBagTag(clean, tripId: t, bag: b) }
    }
}
