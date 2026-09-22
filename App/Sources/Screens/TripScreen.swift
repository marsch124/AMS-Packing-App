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
    /// When / Where / Category — remembered on this device, as the web app does.
    @AppStorage("ams.view") private var view = "when"
    @State private var newName = ""
    @State private var reviewing = false
    static let views: [(id: String, label: String)] = [("when", "When"), ("container", "Where"), ("category", "Category")]

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
                // After the trip: what did I use, what did I miss. Once, then it says so.
                if trip.status == "done" {
                    Text("Reviewed").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.muted)
                        .accessibilityIdentifier("trip-reviewed")
                } else if !trip.entries.isEmpty {
                    Button("Review") { reviewing = true }
                        .buttonStyle(.plain).focusEffectDisabled()
                        .font(.system(size: 17, weight: .bold)).foregroundStyle(AppSection.events.color)
                        .accessibilityIdentifier("trip-review")
                }
                Button("Done") { dismiss() }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .font(.system(size: 17, weight: .bold)).foregroundStyle(AppSection.events.color)
                    .accessibilityIdentifier("trip-done")
            }
            .padding(16)
            Pills(title: "", options: TripScreen.views, selected: [view], id: "trip-view", tint: AppSection.events.color) { view = $0 }
                .padding(.horizontal, 16)
            KeyboardAwayScroll {
                LazyVStack(alignment: .leading, spacing: 4) {
                    // The web app's nesting: When → by bag inside; Where / Category → by When inside.
                    ForEach(Array(groupBy(view, trip.entries).enumerated()), id: \.offset) { _, group in
                        if !group.entries.isEmpty {
                            Text(group.label)
                                .font(.system(size: 15, weight: .heavy))
                                .foregroundStyle(view == "when" ? Color(hexString: phaseColor(group.entries[0].phase)) : AppSection.events.color)
                                .padding(.top, 12)
                            ForEach(group.entries, id: \.id) { line in
                                let n = index[line.id] ?? 0
                                let aside = isSetAside(line)
                                HStack(spacing: 4) {
                                    Button {
                                        if !aside { model.change { _ = $0.setChecked(!line.checked, tripId: tripId, entryId: line.id) } }
                                    } label: {
                                        PackLine(line: line, nights: trip.nights, tint: Color(hexString: phaseColor(line.phase)), showBag: view != "container")
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("trip-line-\(n)")
                                    .accessibilityAddTraits(line.checked ? .isSelected : [])
                                    // ⊘ "not this time" — one tap, his call, no confirmation; ↻ takes it back.
                                    Button {
                                        model.change { _ = $0.setAside(!aside, tripId: tripId, entryId: line.id) }
                                    } label: {
                                        AsideMark(back: aside)
                                            .frame(width: 40, height: 40)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain).focusEffectDisabled()
                                    .accessibilityIdentifier("trip-line-\(n)-aside")
                                    .accessibilityLabel(aside ? "Take it this time" : "Not this time")
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            // "Also the tripod" — a thing for THIS trip only, typed on the spot.
            HStack(spacing: 8) {
                TextField("Add a thing to this trip", text: $newName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 17, weight: .medium)).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 12).frame(minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                    .onSubmit { add() }
                    .accessibilityIdentifier("trip-add-name")
                Button { add() } label: {
                    Text("Add").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 16).frame(minHeight: 44)
                        .background(RoundedRectangle(cornerRadius: 10).fill(jsTrim(newName).isEmpty ? Theme.line : AppSection.events.color))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .disabled(jsTrim(newName).isEmpty)
                .accessibilityIdentifier("trip-add")
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Theme.bg)
        }
        .background(Theme.bg.ignoresSafeArea())
        .sheet(isPresented: $reviewing) { ReviewScreen(tripId: tripId).environmentObject(model) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("trip-detail")
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 640)
        #endif
    }

    private func add() {
        let name = newName
        guard !jsTrim(name).isEmpty else { return }
        model.change { _ = $0.addCustomLine(tripId: tripId, name: name) }
        newName = ""
    }
}

/// One line of a packing list. Ticked = a filled circle; set aside = greyed and
/// struck through (3px, his call), and it leaves the counts.
struct PackLine: View {
    let line: Item
    let nights: Int
    let tint: Color
    var showBag = true

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
            if showBag {
                Text(line.container)
                    .font(.system(size: 14)).foregroundStyle(Theme.muted).lineLimit(1)
                    .frame(maxWidth: 150, alignment: .trailing)
            }
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
    }
}

/// ⊘ (a circle with a slash) to set a line aside, ↻ (an arrow round) to take it
/// back — drawn, like every mark in this app.
struct AsideMark: View {
    let back: Bool
    var body: some View {
        let d = back
            ? "M17.5 9.5A6 6 0 1 0 18 13.5M18 8v3.5h-3.5"
            : "M12 4.5a7.5 7.5 0 1 0 0 15a7.5 7.5 0 1 0 0-15M7 17L17 7"
        SVGPath.path(d)
            .stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
            .frame(width: 24, height: 24)
            .foregroundStyle(Theme.muted)
    }
}

/// A tick mark, drawn — the web app's own (M8.5 12.2 l2.4 2.4 4.6-5), scaled.
struct Tick: Shape {
    func path(in rect: CGRect) -> Path {
        let k = rect.width / 24
        return SVGPath.path("M8.5 12.2l2.4 2.4 4.6-5").applying(CGAffineTransform(scaleX: k, y: k))
    }
}
