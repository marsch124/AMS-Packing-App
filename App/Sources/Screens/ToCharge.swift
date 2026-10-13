import SwiftUI
import PackingCore
import PackingLibrary

/// "To charge" on a trip (spec 07 part 15; spec 03, "To charge") — his ask of 13 Oct 2026:
/// "implement a view where I can check all items that need charging". From the day before
/// the trip starts through its last day: every thing on it that has a battery, the ones
/// inside a kit too ("In the Camp pouch"), each with a CHARGE tick of its own — apart from
/// packing: charging does not pack it, packing does not charge it.
///
/// Under Check before you go (what would stop him at the airport stays first), above the
/// weather. Orange while something is left to charge, the trip's green once all is.
struct ToChargeCard: View {
    let tripId: String
    @EnvironmentObject var model: LibraryModel

    /// A battery, drawn in the icons' style (one stroke, round ends, the 24-point grid; no
    /// stock art, his rule): the body, its terminal, a bolt inside.
    static let battery = "M5 7.5h11.5c.8 0 1.5.7 1.5 1.5v6c0 .8-.7 1.5-1.5 1.5H5c-.8 0-1.5-.7-1.5-1.5V9c0-.8.7-1.5 1.5-1.5Z M21 10.5v3 M11.6 9.3L9.2 12.4h3.4L10.2 15.1"

    var body: some View {
        let rows = model.library.chargeCard(tripId: tripId, today: Today.local)
        if !rows.isEmpty {
            let left = rows.contains { !$0.charged }
            let tint = left ? AppSection.care.color : AppSection.events.color
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    IconMark(path: ToChargeCard.battery, size: 22).foregroundStyle(tint)
                        .accessibilityHidden(true)
                    Text("To charge").font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.ink)
                    Text(Library.chargeWords(rows))
                        .font(.system(.footnote, weight: .semibold).monospacedDigit()).foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Capsule().fill(tint))
                        .accessibilityLabel("\(Library.chargeWords(rows)) charged")
                        .accessibilityIdentifier("trip-charge-count")
                    Spacer()
                }
                ForEach(Array(rows.enumerated()), id: \.element.id) { n, row in
                    line(row)
                        .accessibilityIdentifier("trip-charge-\(n)")
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(tint, lineWidth: 1.2))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("trip-charge")
        }
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
