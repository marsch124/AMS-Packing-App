#if DEBUG
import SwiftUI
import PackingLibrary

// A SAMPLE SHEET, never shipped (DEBUG builds only, launched with `-phaseIconSheet`).
//
// His ask (13 Oct 2026): the trip's step pills "Plan › Pack › On site › Review › Refine"
// wear the tab marks (a suitcase, calendars, a list) — stock-looking. He wants them "not
// stock but cool": hand-drawn in the app's own line (one 1.9 stroke on the 24 grid, round
// caps and joins, no fill — like the template icons), calm, not childish, not glowing.
// Three candidates per step, A B C, shown beside today's mark in the real pill: lit (the
// step the trip is at), unlit (as the Mac shows every step), then the mark at 2× for detail.

enum PhaseIconCandidates {
    /// SVG path data on the 24-point grid, A B C for each step.
    static func paths(_ step: Library.LoopStep) -> [String] {
        switch step {
        case .plan: return [
            // A — a sketch map (the Map template icon's outline) with a dotted route to an X.
            "M3.5 6.5 9 4.5l6 2 5.5-2v13l-5.5 2-6-2-5.5 2Z M6.6 15.6h.01 M9.4 14.1h.01 M12.3 13h.01 M14.3 8.6l3 3 M17.3 8.6l-3 3",
            // B — a notepad with lines, a pencil beside it.
            "M4.5 3.5h7c.8 0 1.5.7 1.5 1.5v14c0 .8-.7 1.5-1.5 1.5h-7c-.8 0-1.5-.7-1.5-1.5V5c0-.8.7-1.5 1.5-1.5Z M6.2 8h3.6 M6.2 12h3.6 M6.2 16h1.8 M16.5 4.5c0-.6.4-1 1-1h1c.6 0 1 .4 1 1V16l-1.5 4.5L16.5 16Z M16.5 16h3",
            // C — a signpost, two boards pointing two ways.
            "M7 4.5h11l2.5 2.5L18 9.5H7Z M17 12.5H6l-2.5 2.5L6 17.5h11Z M12 2.5v2 M12 9.5v3 M12 17.5v4 M9.5 21.5h5",
        ]
        case .pack: return [
            // A — the suitcase (Home's own mark, without its straps) with a tick.
            "M6.2 7.5h11.6a2.2 2.2 0 0 1 2.2 2.2v8.1a2.2 2.2 0 0 1-2.2 2.2H6.2A2.2 2.2 0 0 1 4 17.8V9.7a2.2 2.2 0 0 1 2.2-2.2Z M9 7.5V5.6A1.6 1.6 0 0 1 10.6 4h2.8A1.6 1.6 0 0 1 15 5.6V7.5 M8.8 13.9l2.2 2.2 4.2-4.4",
            // B — a T-shirt (the Clothes template icon) with a tick: a thing gone in.
            "M9 3.5 4.5 5.5 2.5 10l3 1.5 1.5-2.2v11.2h10V9.3l1.5 2.2 3-1.5-2-4.5L15 3.5c-.4 1.3-1.6 2.2-3 2.2s-2.6-.9-3-2.2Z M9.4 14.6l1.8 1.8 3.5-3.7",
            // C — a carry-on on its wheels, handle up: ready to go.
            "M7 8.5h10c.8 0 1.5.7 1.5 1.5v8c0 .8-.7 1.5-1.5 1.5H7c-.8 0-1.5-.7-1.5-1.5v-8c0-.8.7-1.5 1.5-1.5Z M9.5 8.5V3.5h5v5 M8 19.5v1.5 M16 19.5v1.5 M9.5 11.5v5 M14.5 11.5v5",
        ]
        case .onSite: return [
            // A — a palm (the Palm tree template icon) and a low sun on the horizon.
            "M8 20.5c-.3-4.5.5-8.5 2.5-12 M10.5 8.5c-2.5-1.8-5.8-1.6-8 .8 M10.5 8.5c2.5-1.8 5.8-1.6 8 .8 M10.5 8.5c-1.5-2.8-4-4-7-3.6 M10.5 8.5c1.5-2.8 4-4 7-3.6 M14 20.5a3.5 3.5 0 0 1 7 0 M3 20.5h18",
            // B — a flag planted on a hill: arrived.
            "M2.5 20.5c2.6-3.1 5.8-4.7 9.5-4.7s6.9 1.6 9.5 4.7 M12 15.8V3.5 M12 4h6.5l-1.8 2.7 1.8 2.7H12",
            // C — a pin (the trip map's pin) standing on a folded map.
            "M3 17.5 8 16l8 2 5-1.5v3.5l-5 1.5-8-2-5 1.5Z M12 15s-4.6-4.2-4.6-7.8a4.6 4.6 0 0 1 9.2 0c0 3.6-4.6 7.8-4.6 7.8Z M12 5.9a1.3 1.3 0 1 0 0 2.6a1.3 1.3 0 1 0 0-2.6",
        ]
        case .review: return [
            // A — a list: one thing ticked (used), one crossed (not used).
            "M3.5 7.6l2 2 3.6-3.8 M12 7.8h8.5 M4 14l4 4 M8 14l-4 4 M12 16h8.5",
            // B — a magnifier over a list.
            "M3.5 6h11 M3.5 10.5h6.5 M3.5 15h4.5 M11.5 14a4 4 0 1 0 8 0a4 4 0 1 0 -8 0 M18.4 16.9l2.6 2.6",
            // C — a speech bubble with a tick: how it went.
            "M5 4.5h14c.8 0 1.5.7 1.5 1.5v9c0 .8-.7 1.5-1.5 1.5h-7.5L7.5 20v-3.5H5c-.8 0-1.5-.7-1.5-1.5V6c0-.8.7-1.5 1.5-1.5Z M8.6 10.6l2.3 2.3 4.5-4.6",
        ]
        case .refine: return [
            // A — the app's own pen (the edit buttons') with a small spark of three short rays.
            "M15.2 5.3L18.7 8.8L8.6 18.9L4.3 19.7L5.1 15.4Z M13 7.5L16.5 11 M5.1 15.4L8.6 18.9 M4 9.5 2.6 8.6 M6 6.6 5.3 5 M9 5V3.3",
            // B — steps going up with an arrow: the Refine card's own mark, at the app's weight.
            "M2.5 21.5H7V17H11.5V12.5H16V8H21.5M16 8V2.5M13.2 5.3L16 2.5L18.8 5.3",
            // C — a sprout: the templates grow better, trip after trip.
            "M12 20.5V11.2 M12 11.2c0-3.6 2.6-6 7-6 0 3.6-2.6 6-7 6Z M12 14.5c0-2.9-2.1-4.8-5.6-4.8 0 2.9 2.1 4.8 5.6 4.8Z M7.5 20.5h9",
        ]
        }
    }
}

/// One candidate (or today's mark, `path == nil`) at any size, stroked like `SectionMark`.
private struct StepMark: View {
    let step: Library.LoopStep
    let path: String?
    var size: Double

    var body: some View {
        if let path {
            let k = size / 24
            SVGPath.path(path)
                .applying(CGAffineTransform(scaleX: k, y: k))
                .stroke(style: StrokeStyle(lineWidth: 1.9 * k, lineCap: .round, lineJoin: .round))
                .frame(width: size, height: size)
        } else {
            SectionMark(section: step.tab, size: size, weight: 1.9)
        }
    }
}

struct PhaseIconSheet: View {
    static var wanted: Bool { ProcessInfo.processInfo.arguments.contains("-phaseIconSheet") }

    @Environment(\.colorScheme) private var scheme
    private let columns = ["Today", "A", "B", "C"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Step icons · \(scheme == .dark ? "night" : "day")")
                .font(.system(.subheadline, weight: .bold)).foregroundStyle(Theme.ink)
            Text("Each: lit (where the trip is), unlit (Mac), then 2×")
                .font(.system(.caption)).foregroundStyle(Theme.muted)
                .padding(.bottom, 6)
            HStack(spacing: 0) {
                ForEach(columns, id: \.self) { c in
                    Text(c).font(.system(.subheadline, weight: .bold)).foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 2)
            ForEach(Library.LoopStep.allCases, id: \.self) { step in
                Rectangle().fill(Theme.line).frame(height: 1).padding(.vertical, 5)
                Text(step.name)
                    .font(.system(.footnote, weight: .bold)).foregroundStyle(step.words(scheme))
                    .padding(.bottom, 3)
                HStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { c in
                        cell(step, c == 0 ? nil : PhaseIconCandidates.paths(step)[c - 1])
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10).padding(.top, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.bg.ignoresSafeArea())
        .accessibilityIdentifier("phase-icon-sheet")
    }

    private func cell(_ step: Library.LoopStep, _ path: String?) -> some View {
        VStack(spacing: 5) {
            pill(step, path, on: true)
            pill(step, path, on: false)
            HStack(spacing: 6) {
                disc(step, path, on: true)
                disc(step, path, on: false)
            }
            .padding(.top, 1)
        }
    }

    /// The step's pill exactly as `LoopDoor` draws it: the lit one as the iPhone shows the
    /// step a trip is at (its mark, padding 7), the unlit one as the Mac shows every step
    /// (with its mark, padding 8).
    private func pill(_ step: Library.LoopStep, _ path: String?, on: Bool) -> some View {
        HStack(spacing: 4) {
            StepMark(step: step, path: path, size: 13)
            Text(step.name)
                .font(.system(.footnote, weight: .semibold))
                .lineLimit(1).fixedSize()
        }
        .foregroundStyle(on ? Color.white : step.words(scheme))
        .padding(.horizontal, on ? 7 : 8).frame(minHeight: 28)
        .background(Capsule().fill(on ? step.tint : Theme.card))
        .overlay(Capsule().stroke(step.tint.opacity(on ? 0 : 0.7), lineWidth: 1.2))
    }

    /// The mark alone at 2× (26 points, the pill's 13 doubled), lit and unlit.
    private func disc(_ step: Library.LoopStep, _ path: String?, on: Bool) -> some View {
        StepMark(step: step, path: path, size: 26)
            .foregroundStyle(on ? Color.white : step.words(scheme))
            .frame(width: 40, height: 40)
            .background(Circle().fill(on ? step.tint : Theme.card))
            .overlay(Circle().stroke(step.tint.opacity(on ? 0 : 0.7), lineWidth: 2.4))
    }
}
#endif
