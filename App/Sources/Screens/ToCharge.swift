import SwiftUI
import PackingCore
import PackingLibrary

/// The drawn battery mark — To charge, a battery in the hold, Your things' filter, a thing's page.
enum ToChargeCard {
    /// A battery, drawn in the icons' style (one stroke, round ends, the 24-point grid; no
    /// stock art, his rule): the body, its terminal, a bolt inside.
    static let battery = "M5 7.5h11.5c.8 0 1.5.7 1.5 1.5v6c0 .8-.7 1.5-1.5 1.5H5c-.8 0-1.5-.7-1.5-1.5V9c0-.8.7-1.5 1.5-1.5Z M21 10.5v3 M11.6 9.3L9.2 12.4h3.4L10.2 15.1"
}

/// "To charge" — the last part of the trip's Before you go card (spec 07 part 15; spec 03,
/// "Before you go") — his ask of 13 Oct 2026: "implement a view where I can check all items
/// that need charging". From the day before the trip starts through its last day: every thing
/// on it that has a battery, the ones inside a kit too ("In the Camp pouch"), each with a
/// CHARGE tick of its own — apart from packing: charging does not pack it, packing does not
/// charge it. A card of its own in 0.75–0.76; a part of Before you go since 0.77.
///
/// Its heading "To charge · 1 of 2": the count orange while something is left to charge, the
/// trip's green once all is.
struct ToChargePart: View {
    let tripId: String
    /// `Library.chargeCard` — never empty here (the card leaves the part out).
    let rows: [ChargeRow]
    @EnvironmentObject var model: LibraryModel

    var body: some View {
        let left = rows.contains { !$0.charged }
        let tint = left ? AppSection.care.color : AppSection.events.color
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                IconMark(path: ToChargeCard.battery, size: 16).foregroundStyle(tint)
                    .accessibilityHidden(true)
                BeforeYouGoCard.partTitle("To charge")
                Text("\u{00B7}").font(.system(.footnote, weight: .semibold)).foregroundStyle(Theme.muted)
                    .accessibilityHidden(true)
                Text(Library.chargeWords(rows))
                    .font(.system(.footnote, weight: .semibold).monospacedDigit()).foregroundStyle(tint)
                    .accessibilityLabel("\(Library.chargeWords(rows)) charged")
                    .accessibilityIdentifier("trip-charge-count")
                Spacer()
            }
            ForEach(Array(rows.enumerated()), id: \.element.id) { n, row in
                line(row)
                    .accessibilityIdentifier("trip-charge-\(n)")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("trip-beforego-part-charge")
    }

    /// A thing to charge: its tick, its name, and the kit it is in. A press charges it for
    /// this trip, or takes the mark back — the line on the trip is not ticked.
    private func line(_ row: ChargeRow) -> some View {
        let tint = AppSection.care.color
        return Button {
            model.change { _ = $0.setCharged(!row.charged, tripId: tripId, lineId: row.lineId, contentId: row.contentId) }
        } label: {
            HStack(spacing: 10) {
                TickCircle(on: row.charged, tint: tint, ring: row.charged ? nil : Theme.line).frame(width: 22, height: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(row.name).font(.system(.callout, weight: .semibold))
                        .foregroundStyle(row.charged ? Theme.muted : Theme.ink)
                        .strikethrough(row.charged, color: Theme.muted)
                    if !row.kit.isEmpty {
                        Text("In the \(row.kit)").font(.system(.subheadline)).foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 6)
            }
            .frame(minHeight: Metrics.tap).contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityLabel(row.kit.isEmpty ? row.name : "\(row.name), in the \(row.kit)")
        .accessibilityValue(row.charged ? "charged" : "not charged")
        .accessibilityAddTraits(row.charged ? .isSelected : [])
    }
}
