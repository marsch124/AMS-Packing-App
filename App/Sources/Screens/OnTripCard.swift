import SwiftUI
import PackingCore
import PackingLibrary

/// "On your trip" on Home (0.108) — his words, 2 Nov 2026, on a trip: "I am currently on a trip,
/// but I can't see it on the home page." He saw the picture and said "excellent"; this is it as
/// drawn. ONE card, first on Home while he is away and once he is back, that changes with the
/// moment (`Library.onTripCard`):
///  • Under way: a green band — ON YOUR TRIP, the trip, today's weather there, a segment a day and
///    "Day 3 of 7 · home on Sunday" — then To do today, Where is my…? and Pack to go home.
///  • Going home (the last day or the day before): GOING HOME TOMORROW / TODAY, "you leave at
///    10:00"; Pack to go home with what is still to pack, Charge tonight, and a green Pack to go
///    home button.
///  • Back home, not reviewed: a violet band, WELCOME HOME, how long and how much went along;
///    Review the trip and a violet Review button.
/// Green is the trip's, violet the review's — the trip's own steps (Pack, On site green; Review
/// violet). Every mark is drawn in the app's own hand (his rule: never stock art or emoji).
struct OnTripCard: View {
    let card: Library.OnTripCard
    /// The band, or (back home) its row and button: the trip at On site — or its review.
    let openTrip: () -> Void
    /// Pack to go home — its row, and its button on the way home.
    let packHome: () -> Void
    /// Where is my…? — the app's Search, which answers it first on a trip under way (0.69).
    let whereIs: () -> Void
    /// To do today and Charge tonight: the trip, at what is to do (its To charge for Charge tonight).
    let openToDo: () -> Void
    let openCharge: () -> Void
    let review: () -> Void

    /// The band: the trip's green — a shade deeper at the top, so white words read on it (4.9 : 1)
    /// — or the review's violet.
    private var band: [Color] {
        card.moment == .backHome
            ? [Color(hex: 0x6548c0), AppSection.templates.color]
            : [Color(hex: 0x24834f), AppSection.events.color]
    }
    private var tint: Color { card.moment == .backHome ? AppSection.templates.color : AppSection.events.color }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: card.moment == .backHome ? review : openTrip) { bandView }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("home-ontrip-open")
                .accessibilityLabel("\(card.title): \(card.name)")
                .accessibilityValue([card.dayLine, card.weather.map { "\($0.label), \($0.says) in \(card.place)" } ?? ""]
                    .filter { !$0.isEmpty }.joined(separator: " \u{00B7} "))
                .accessibilityHint(card.moment == .backHome ? "Opens its review" : "Opens the trip at On site")
            VStack(spacing: 0) {
                switch card.moment {
                case .underWay:
                    if !card.due.isEmpty {
                        row(mark: Self.tick, hex: Self.orange, title: "To do today",
                            under: card.due.joined(separator: " \u{00B7} "), count: card.due.count, id: "home-ontrip-todo",
                            action: openToDo)
                        divider
                    }
                    row(mark: Self.lens, hex: Self.blue, title: "Where is my\u{2026}?",
                        under: "Which bag and pocket a thing is in", count: nil, id: "home-ontrip-where", action: whereIs)
                    divider
                    row(mark: Self.suitcase, hex: Self.green, title: "Pack to go home",
                        under: card.packHomeLine, count: nil, id: "home-ontrip-packhome", action: packHome)
                case .goingHome:
                    row(mark: Self.suitcase, hex: Self.green, title: "Pack to go home",
                        under: card.packHomeLine, count: card.homeLeft > 0 ? card.homeLeft : nil,
                        id: "home-ontrip-packhome", action: packHome)
                    if !card.charge.isEmpty {
                        divider
                        row(mark: ToChargeCard.battery, hex: Self.orange, title: "Charge tonight",
                            under: Library.chargeTonightNames(card.charge), count: card.charge.count,
                            id: "home-ontrip-charge", action: openCharge)
                    }
                    wide("Pack to go home", tint: AppSection.events.color, id: "home-ontrip-gohome", action: packHome)
                case .backHome:
                    row(mark: Library.LoopStep.review.mark.path, hex: Self.violet, title: "Review the trip",
                        under: "What you used, and what stayed in the bag", count: nil, id: "home-ontrip-review", action: review)
                    wide("Review", tint: AppSection.templates.color, id: "home-ontrip-review-go", action: review)
                }
            }
            .padding(.horizontal, 12).padding(.top, 2).padding(.bottom, card.moment == .underWay ? 4 : 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(tint.opacity(0.4), lineWidth: 1.5))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home-ontrip")
        .accessibilityValue(card.moment.rawValue)
    }

    // MARK: The band

    private var bandView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(card.title.uppercased())
                        .font(.system(.caption, weight: .semibold)).tracking(0.8)
                        .opacity(0.92)
                    Text(card.name)
                        .font(.system(.title3, weight: .bold))
                        .lineLimit(2).minimumScaleFactor(0.8)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                if let sky = card.weather {
                    VStack(alignment: .trailing, spacing: 0) {
                        HStack(spacing: 4) {
                            IconMark(path: WeatherMark.path(sky.icon), size: 22, weight: 2)
                            Text(sky.says).font(.system(.title2, weight: .bold).monospacedDigit())
                        }
                        if !card.place.isEmpty {
                            Text(card.place).font(.system(.footnote, weight: .semibold))
                                .lineLimit(1).minimumScaleFactor(0.8)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(sky.label), \(sky.says)")
                }
            }
            if card.moment != .backHome {
                days.padding(.top, 10)
            }
            Text(card.dayLine)
                .font(.system(.footnote, weight: .semibold).monospacedDigit())
                .padding(.top, card.moment == .backHome ? 6 : 6)
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: band, startPoint: .topLeading, endPoint: .bottomTrailing))
        .contentShape(Rectangle())
    }

    /// A segment a day, the days up to today lit — one bar for a trip too long for segments.
    @ViewBuilder
    private var days: some View {
        if let lit = card.segments {
            HStack(spacing: 4) {
                ForEach(Array(lit.enumerated()), id: \.offset) { _, on in
                    Capsule().fill(Color.white.opacity(on ? 1 : 0.35)).frame(height: 5)
                }
            }
            .accessibilityHidden(true)
        } else {
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.35))
                    Capsule().fill(Color.white).frame(width: g.size.width * min(1, Double(card.day) / Double(max(1, card.days))))
                }
            }
            .frame(height: 5)
            .accessibilityHidden(true)
        }
    }

    // MARK: Rows

    private var divider: some View { Theme.line.frame(height: 1).padding(.leading, 42) }

    /// One row under the band: its drawn mark on a soft tile, what it is, a line under it, and a
    /// count in a pill — or a chevron where the row opens a page.
    private func row(mark: String, hex: String, title: String, under: String, count: Int?, id: String,
                     action: @escaping () -> Void) -> some View {
        let tint = Color(hexString: hex)
        return Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(tint.opacity(0.14))
                    IconMark(path: mark, size: 18, weight: 1.9).foregroundStyle(Self.readable(hex))
                }
                .frame(width: 30, height: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(.body, weight: .semibold)).foregroundStyle(Theme.ink)
                    Text(under).font(.system(.subheadline)).foregroundStyle(Theme.muted)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 6)
                if let count {
                    Text("\(count)").font(.system(.subheadline, weight: .bold).monospacedDigit())
                        .foregroundStyle(Self.readable(hex))
                        .padding(.horizontal, 9).frame(minHeight: 22)
                        .background(Capsule().fill(tint.opacity(0.16)))
                } else {
                    SVGPath.path("M9 6l6 6-6 6").stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                        .frame(width: 16, height: 16).foregroundStyle(Theme.faint)
                }
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier(id)
        .accessibilityLabel(title)
        .accessibilityValue([under, count.map { "\($0)" } ?? ""].filter { !$0.isEmpty }.joined(separator: " \u{00B7} "))
    }

    /// The card's main button, full width and always in full colour (his rule: never grey).
    private func wide(_ title: String, tint: Color, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(.body, weight: .semibold)).foregroundStyle(Color.white)
                .frame(maxWidth: .infinity, minHeight: Metrics.row)
                .background(RoundedRectangle(cornerRadius: 12).fill(tint))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .padding(.top, 8)
        .accessibilityIdentifier(id)
    }

    /// The section colours (docs/colours.md): Trips green, Templates violet, Care orange, Home blue.
    static let green = "#2f9e63", violet = "#7c5cd6", orange = "#dd7324", blue = "#2f6fe0"

    /// A section colour made readable as words and marks on the card, day and night (`readableHex`).
    static func readable(_ hex: String) -> Color {
        func n(_ s: String) -> UInt32 { UInt32(s.dropFirst(), radix: 16) ?? 0 }
        return Color(light: n(readableHex(hex, dark: false)), dark: n(readableHex(hex, dark: true)))
    }

    // MARK: Drawings — the app's own (one stroke, round ends, the 24-point grid)

    /// To do today: a tick, as the To do tab's ticked box has inside it.
    static let tick = "M5.5 12.5l4.2 4.2L18.5 7.5"
    /// Where is my…?: Search's own magnifier.
    static let lens = "M11 4a7 7 0 1 0 0 14 7 7 0 0 0 0-14ZM20 20l-4-4"
    /// Pack to go home: the Home tab's suitcase.
    static let suitcase = "M6.2 7.5h11.6a2.2 2.2 0 0 1 2.2 2.2v8.1a2.2 2.2 0 0 1-2.2 2.2H6.2A2.2 2.2 0 0 1 4 17.8V9.7a2.2 2.2 0 0 1 2.2-2.2Z M9 7.5V5.6A1.6 1.6 0 0 1 10.6 4h2.8A1.6 1.6 0 0 1 15 5.6V7.5 M9.5 11v5.5 M14.5 11v5.5"
}
