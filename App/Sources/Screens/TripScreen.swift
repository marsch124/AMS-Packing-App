import SwiftUI
import PackingCore
import PackingLibrary

/// One trip, in Packing Mode: its lines under his "When" headings, a tap ticks
/// a line — and that tick is ONE small record, so the other device can tick
/// another line at the same moment and both survive.
struct TripScreen: View {
    let tripId: String
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let trip = model.library.trips.first { $0.id == tripId } ?? newEvent()
        let p = progress(trip.entries)
        let index: [String: Int] = Dictionary(uniqueKeysWithValues: trip.entries.enumerated().map { ($1.id, $0) })
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(trip.name.isEmpty ? "Untitled event" : trip.name)
                        .font(.system(size: 22, weight: .heavy)).foregroundStyle(Theme.ink).lineLimit(1)
                    Text(p.aside > 0 ? "\(p.done)/\(p.total) · \(p.aside) set aside" : "\(p.done)/\(p.total)")
                        .font(.system(size: 16, weight: .bold).monospacedDigit())
                        .foregroundStyle(p.total > 0 && p.done == p.total ? AppSection.events.color : Theme.muted)
                        .accessibilityIdentifier("trip-progress")
                }
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .font(.system(size: 17, weight: .bold)).foregroundStyle(AppSection.events.color)
                    .accessibilityIdentifier("trip-done")
            }
            .padding(16)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(entriesByPhase(trip.entries).enumerated()), id: \.offset) { _, group in
                        if !group.entries.isEmpty {
                            Text(group.phase.label)
                                .font(.system(size: 15, weight: .heavy))
                                .foregroundStyle(Color(hexString: group.phase.color))
                                .padding(.top, 12)
                            ForEach(group.entries, id: \.id) { line in
                                let n = index[line.id] ?? 0
                                Button {
                                    model.change { _ = $0.setChecked(!line.checked, tripId: tripId, entryId: line.id) }
                                } label: {
                                    PackLine(line: line, nights: trip.nights, tint: Color(hexString: group.phase.color))
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("trip-line-\(n)")
                                .accessibilityAddTraits(line.checked ? .isSelected : [])
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("trip-detail")
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 640)
        #endif
    }
}

/// One line of a packing list. Ticked = a filled circle; set aside = greyed and
/// struck through (3px, his call), and it leaves the counts.
struct PackLine: View {
    let line: Item
    let nights: Int
    let tint: Color

    var body: some View {
        let aside = isSetAside(line)
        let qty = effectiveQty(line, nights)
        HStack(spacing: 12) {
            ZStack {
                Circle().stroke(aside ? Theme.line : tint, lineWidth: 2).frame(width: 26, height: 26)
                if line.checked && !aside {
                    Circle().fill(tint).frame(width: 26, height: 26)
                    Tick().stroke(Color.white, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                        .frame(width: 26, height: 26)
                }
            }
            .accessibilityHidden(true)
            Text(line.name)
                .font(.system(size: 17, weight: line.checked ? .regular : .medium))
                .foregroundStyle(aside ? Theme.muted : (line.checked ? Theme.muted : Theme.ink))
                .strikethrough(aside, pattern: .solid, color: Theme.muted)
                .lineLimit(2)
            Spacer(minLength: 8)
            if qty > 1 {
                Text("×\(qty.rounded() == qty ? String(Int(qty)) : String(qty))")
                    .font(.system(size: 15, weight: .bold).monospacedDigit()).foregroundStyle(Theme.muted)
            }
            Text(line.container)
                .font(.system(size: 14)).foregroundStyle(Theme.muted).lineLimit(1)
                .frame(maxWidth: 150, alignment: .trailing)
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
    }
}

/// A tick mark, drawn — the web app's own (M8.5 12.2 l2.4 2.4 4.6-5), scaled.
struct Tick: Shape {
    func path(in rect: CGRect) -> Path {
        let k = rect.width / 24
        return SVGPath.path("M8.5 12.2l2.4 2.4 4.6-5").applying(CGAffineTransform(scaleX: k, y: k))
    }
}
