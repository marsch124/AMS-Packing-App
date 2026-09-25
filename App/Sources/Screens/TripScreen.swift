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
    @State private var sweeping = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    static let views: [(id: String, label: String)] = [("when", "When"), ("container", "Where"), ("category", "Category")]

    var body: some View {
        let trip = model.library.trips.first { $0.id == tripId } ?? newEvent()
        let p = progress(trip.entries)
        // Nothing left to decide: every line ticked or set aside. Set aside counts
        // as handled (his choice, 2026-09-23), so it leaves the total.
        let allPacked = p.total > 0 && p.done == p.total
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
                        .accessibilityValue(allPacked ? "all packed" : "")
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
            // His mark (2026-09-25): "Sorting" on the left, the three buttons on the same line.
            HStack(spacing: 8) {
                Text("Sorting")
                    .font(.system(size: 15, weight: .heavy)).foregroundStyle(Theme.muted)
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .accessibilityIdentifier("trip-view-label")
                Spacer(minLength: 8)
                ForEach(Array(TripScreen.views.enumerated()), id: \.element.id) { n, o in
                    let on = view == o.id
                    Button { view = o.id } label: {
                        Text(o.label)
                            .font(.system(size: 15, weight: on ? .bold : .semibold))
                            .foregroundStyle(on ? Color.white : Theme.ink)
                            .lineLimit(1).fixedSize()
                            .padding(.horizontal, 14).frame(minHeight: 36)
                            .background(Capsule().fill(on ? AppSection.events.color : Theme.bg))
                            .overlay(Capsule().stroke(on ? AppSection.events.color : Theme.line, lineWidth: 1))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("trip-view-\(n)")
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            .padding(.horizontal, 16)
            KeyboardAwayScroll {
                // The card is deliberately OUTSIDE the lazy stack: a lazy row is
                // thrown away and rebuilt as it scrolls off, which loses what he
                // has typed into it (found by the test, 2026-09-23).
                VStack(alignment: .leading, spacing: 4) {
                WeatherCard(tripId: trip.id).environmentObject(model)
                    .padding(.top, 10).padding(.horizontal, 16)
                BagsCard(tripId: trip.id).environmentObject(model)
                    .padding(.top, 6).padding(.horizontal, 16)
                LazyVStack(alignment: .leading, spacing: 4) {
                    // The web app's nesting: When → by bag inside; Where / Category → by When inside.
                    ForEach(Array(groupBy(view, trip.entries).enumerated()), id: \.offset) { g, group in
                        if !group.entries.isEmpty {
                            // The heading, and one press to tick the whole section
                            // (his ask: "so that I could toggle all done").
                            let mine = group.entries.filter { !isSetAside($0) }
                            let sectionDone = !mine.isEmpty && mine.allSatisfy { $0.checked }
                            HStack(spacing: 8) {
                                Text(group.label)
                                    .font(.system(size: 15, weight: .heavy))
                                    .foregroundStyle(view == "when" ? Color(hexString: phaseColor(group.entries[0].phase)) : AppSection.events.color)
                                    .accessibilityIdentifier("trip-group-\(g)-label")
                                Text("\(mine.filter { $0.checked }.count)/\(mine.count)")
                                    .font(.system(size: 13, weight: .bold).monospacedDigit())
                                    .foregroundStyle(Theme.muted)
                                Spacer()
                                Button {
                                    model.change { lib in
                                        for line in mine { _ = lib.setChecked(!sectionDone, tripId: tripId, entryId: line.id) }
                                    }
                                } label: {
                                    ZStack {
                                        Circle().stroke(sectionDone ? AppSection.events.color : Theme.line, lineWidth: 2)
                                            .frame(width: 24, height: 24)
                                        if sectionDone {
                                            Circle().fill(AppSection.events.color).frame(width: 24, height: 24)
                                            Tick().stroke(Color.white, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                                                .frame(width: 24, height: 24)
                                        }
                                    }
                                    .frame(width: 40, height: 36).contentShape(Rectangle())
                                }
                                .buttonStyle(.plain).focusEffectDisabled()
                                .disabled(mine.isEmpty)
                                .accessibilityIdentifier("trip-group-\(g)-all")
                                .accessibilityLabel(sectionDone ? "Untick \(group.label)" : "Tick all of \(group.label)")
                                .accessibilityAddTraits(sectionDone ? .isSelected : [])
                            }
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
                }
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
                    Text("Add").font(.system(size: 16, weight: .bold))
                        .foregroundStyle(jsTrim(newName).isEmpty ? Theme.muted : Color.white)
                        .padding(.horizontal, 16).frame(minHeight: 44)
                        .background(RoundedRectangle(cornerRadius: 10).fill(jsTrim(newName).isEmpty ? Theme.line : AppSection.events.color))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .disabled(jsTrim(newName).isEmpty)
                .accessibilityIdentifier("trip-add")
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            // The green is the WHOLE screen, this bar included (his call: "we need
            // strong indicators").
            .background(allPacked ? Color.clear : Theme.bg)
        }
        .background {
            // Everything packed: the screen itself says so. The green is painted ON
            // the background, not under it, or the opaque one hides it.
            ZStack {
                Theme.bg
                if allPacked { AppSection.events.color.opacity(0.34) }
            }
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.5), value: allPacked)
        }
        .sheet(isPresented: $reviewing) { ReviewScreen(tripId: tripId).environmentObject(model) }
        .accessibilityElement(children: .contain)
        .overlay(alignment: .top) {
            // The moment: ONE sweep down the screen, never a blink — a blinking
            // screen keeps demanding attention after the news is delivered.
            if sweeping {
                LinearGradient(colors: [AppSection.events.color.opacity(0.55), AppSection.events.color.opacity(0.0)],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .accessibilityHidden(true)
            }
        }
        .onChange(of: allPacked) { _, packed in
            guard packed, !reduceMotion else { return }
            withAnimation(.easeOut(duration: 0.45)) { sweeping = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                withAnimation(.easeIn(duration: 0.55)) { sweeping = false }
            }
        }
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
