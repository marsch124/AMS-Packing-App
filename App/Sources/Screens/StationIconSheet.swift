#if DEBUG
import SwiftUI
import PackingLibrary

// A SAMPLE SHEET, never shipped (DEBUG builds only, launched with `-stationIconSheet`; the last
// three rows with `-stationIconPage 2` as well — seven rows do not fit one iPhone screen).
//
// His ask (13 Oct 2026), for 0.79's guided "Packing day" inside the Pack step — a row of
// stations, Bags out → Pack → Weigh → Tags → Photos → Ready, each turning green when done:
// "cool icons for the packing day stations and even for the Packing day itself". Hand-drawn in
// the app's own line, like the template icons and the step marks he picked for 0.77: one 1.9
// stroke on the 24-point grid, round caps and joins, no fill, only M L H V C S Q A Z. Calm, not
// childish; no stock symbols, no emoji. The Pack STATION must not look like the Pack STEP's
// suitcase with a tick. Three candidates each, A B C, on a station chip at 17 points — lit
// (done) and unlit — then the mark alone at 2× for detail.

/// The Packing day and its six stations, in the row's order.
enum StationIconSample: CaseIterable {
    case day, bagsOut, pack, weigh, tags, photos, ready

    var name: String {
        switch self {
        case .day: return "Packing day"
        case .bagsOut: return "Bags out"
        case .pack: return "Pack"
        case .weigh: return "Weigh"
        case .tags: return "Tags"
        case .photos: return "Photos"
        case .ready: return "Ready"
        }
    }
}

enum StationIconCandidates {
    /// A B C for each: what it shows, and its SVG path data on the 24-point grid.
    static func all(_ station: StationIconSample) -> [(label: String, path: String)] {
        switch station {
        case .day: return [
            // A — a metro line: two stops passed, the stop you are at (a ring round a dot), one still ahead.
            ("A metro line, the stop you are at ringed",
             "M2.5 17H7L12 12 M17.2 12H20.6 M3.4 17a.9 .9 0 1 0 1.8 0a.9 .9 0 1 0 -1.8 0 M8.6 14.5a.9 .9 0 1 0 1.8 0a.9 .9 0 1 0 -1.8 0 M12 12a2.6 2.6 0 1 0 5.2 0a2.6 2.6 0 1 0 -5.2 0 M14.6 12h.01 M19.7 12a.9 .9 0 1 0 1.8 0a.9 .9 0 1 0 -1.8 0"),
            // B — a sun rising out of an open case.
            ("A sun rising out of an open case",
             "M4 12.5h16 M4 12.5v5.8c0 1.2 1 2.2 2.2 2.2h11.6c1.2 0 2.2-1 2.2-2.2v-5.8 M8.4 12.5a3.6 3.6 0 0 1 7.2 0 M12 6.9L12 4.7 M7.71 8.9L6.02 7.49 M16.29 8.9L17.98 7.49"),
            // C — a calendar page (the Trips tab's) with a small suitcase on it.
            ("A calendar page with a suitcase",
             "M5.5 5h13a2 2 0 0 1 2 2v11.5a2 2 0 0 1 -2 2h-13a2 2 0 0 1 -2 -2v-11.5a2 2 0 0 1 2 -2Z M3.5 9.5h17 M8 3.5v3 M16 3.5v3 M9 13.8h6a1 1 0 0 1 1 1v2.4a1 1 0 0 1 -1 1h-6a1 1 0 0 1 -1 -1v-2.4a1 1 0 0 1 1 -1Z M10.3 13.8v-1.3h3.4v1.3"),
        ]
        case .bagsOut: return [
            // A — two bags side by side on the floor: a carry-on, handle up, and a duffel.
            ("Two bags on the floor",
             "M2.5 20.5h19 M5.1 9.5h4.8a1.3 1.3 0 0 1 1.3 1.3v6.4a1.3 1.3 0 0 1 -1.3 1.3h-4.8a1.3 1.3 0 0 1 -1.3 -1.3v-6.4a1.3 1.3 0 0 1 1.3 -1.3Z M6 9.5V5.5h3v4 M5.6 18.5v2 M9.4 18.5v2 M13.5 20.5v-3.7a2.8 2.8 0 0 1 2.8-2.8h2.4a2.8 2.8 0 0 1 2.8 2.8v3.7 M15.6 14c0-1.7.8-2.7 1.9-2.7s1.9 1 1.9 2.7"),
            // B — a cupboard, its door swung open, a duffel on its floor.
            ("A cupboard open, a bag inside",
             "M2.5 20.5h19 M9 20.5V3.5h11.5v17 M9 3.5 4.5 5.8v12.4L9 20.5 M9 9h11.5 M11.5 20.5v-3a2.5 2.5 0 0 1 2.5-2.5h1.5a2.5 2.5 0 0 1 2.5 2.5v3 M13.4 15c0-1.4.6-2.3 1.35-2.3s1.35.9 1.35 2.3"),
            // C — a bag lifted off the floor by a small arrow at its handle.
            ("A bag lifted off the floor",
             "M6.5 10.5h11a2 2 0 0 1 2 2v3.5a2 2 0 0 1 -2 2h-11a2 2 0 0 1 -2 -2v-3.5a2 2 0 0 1 2 -2Z M9.5 10.5V9c0-.6.4-1 1-1h3c.6 0 1 .4 1 1v1.5 M12 6V2.6 M9.8 4.8 12 2.6l2.2 2.2 M3 21.2h18"),
        ]
        case .pack: return [
            // A — a folded shirt going into an open case, an arrow down beside it.
            ("A folded shirt going into an open case",
             "M4 12.5h16 M4 12.5v5.8c0 1.2 1 2.2 2.2 2.2h11.6c1.2 0 2.2-1 2.2-2.2v-5.8 M6.5 12.5V7.3c0-.6.4-1 1-1h5c.6 0 1 .4 1 1v5.2 M8.5 6.3 10 8l1.5-1.7 M18 3v5.6 M16 6.6l2 2 2-2"),
            // B — an open case with two things in it: a folded shirt and a bottle.
            ("An open case, a shirt and a bottle in it",
             "M4 12.5h16 M4 12.5v5.8c0 1.2 1 2.2 2.2 2.2h11.6c1.2 0 2.2-1 2.2-2.2v-5.8 M5.2 12.5V8.7c0-.6.4-1 1-1h5c.6 0 1 .4 1 1v3.8 M7.4 7.7l1.3 1.5 1.3-1.5 M14.6 12.5v-3c0-.8.6-1.4 1.4-1.4h1c.8 0 1.4.6 1.4 1.4v3 M15.8 8.1V5.3h1.4v2.8"),
            // C — a list curving into an open case: packing from the list.
            ("A list going into an open case",
             "M4 12.5h16 M4 12.5v5.8c0 1.2 1 2.2 2.2 2.2h11.6c1.2 0 2.2-1 2.2-2.2v-5.8 M4 4h6 M4 7.2h4.5 M13 4.5c3.2 0 5 1.6 5 5 M16 7.5l2 2 2-2"),
        ]
        case .weigh: return [
            // A — a luggage scale held up: grip, round dial, a bag hanging from it.
            ("A luggage scale, a bag hanging from it",
             "M9 2.8h6 M12 2.8v2.3 M8.8 8.3a3.2 3.2 0 1 0 6.4 0a3.2 3.2 0 1 0 -6.4 0 M12 8.3l1.3-1.3 M12 11.5v1.8 M6.6 16h10.8a1.6 1.6 0 0 1 1.6 1.6v1.8a1.6 1.6 0 0 1 -1.6 1.6h-10.8a1.6 1.6 0 0 1 -1.6 -1.6v-1.8a1.6 1.6 0 0 1 1.6 -1.6Z M9.5 16v-1.7c0-.6.4-1 1-1h3c.6 0 1 .4 1 1V16"),
            // B — a carry-on standing on a floor scale.
            ("A bag on a floor scale",
             "M4.2 16.5h15.6a1.2 1.2 0 0 1 1.2 1.2v2.1a1.2 1.2 0 0 1 -1.2 1.2h-15.6a1.2 1.2 0 0 1 -1.2 -1.2v-2.1a1.2 1.2 0 0 1 1.2 -1.2Z M10.5 18.75h3 M9 7.5h6a1.5 1.5 0 0 1 1.5 1.5v6a1.5 1.5 0 0 1 -1.5 1.5h-6a1.5 1.5 0 0 1 -1.5 -1.5v-6a1.5 1.5 0 0 1 1.5 -1.5Z M10 7.5V4h4v3.5"),
            // C — a dial with a needle and tick marks.
            ("A dial with a needle",
             "M3.5 15.5A8.5 8.5 0 0 1 20.5 15.5 M3.5 15.5h17 M7.5 12.9L6.11 12.1 M9.4 11L8.6 9.61 M12 10.3L12 8.7 M14.6 11L15.4 9.61 M16.5 12.9L17.89 12.1 M12 15.5l3-4.2 M7 20.5h10"),
        ]
        case .tags: return [
            // A — a luggage tag on its string, a round AirTag beside it.
            ("A luggage tag and an AirTag",
             "M3.5 10.5 7.75 6.5 12 10.5V19.5c0 .6-.4 1-1 1H4.5c-.6 0-1-.4-1-1Z M7.75 10h.01 M7.75 10c0-3 1.5-5.5 4.5-6 M6 15h3.5 M6 17.5h2.5 M14.25 16a3.5 3.5 0 1 0 7 0a3.5 3.5 0 1 0 -7 0 M17.75 16h.01"),
            // B — a luggage tag, tilted: strap loop, slot, address window.
            ("A luggage tag",
             "M7.47 10.21L14.99 7.47A2 2 -20 0 1 17.55 8.67L20.12 15.72A2 2 -20 0 1 18.92 18.28L11.41 21.02A2 2 -20 0 1 8.84 19.82L6.28 12.77A2 2 -20 0 1 7.47 10.21Z M10.21 11.87L13.97 10.51 M10.68 11.7L8.8 6.54A1.5 1.5 -20 0 1 11.62 5.51L13.5 10.68 M10.57 14.62L15.45 12.84A.6 .6 -20 0 1 16.22 13.2L17.04 15.45A.6 .6 -20 0 1 16.68 16.22L11.8 18A.6 .6 -20 0 1 11.03 17.64L10.21 15.39A.6 .6 -20 0 1 10.57 14.62Z"),
            // C — a round AirTag with a soft signal.
            ("An AirTag with a signal",
             "M3.8 15a5.2 5.2 0 1 0 10.4 0a5.2 5.2 0 1 0 -10.4 0 M7.6 15a1.4 1.4 0 1 0 2.8 0a1.4 1.4 0 1 0 -2.8 0 M10.75 6.78A8.4 8.4 0 0 1 17.22 13.25 M12.58 3.97A11.6 11.6 0 0 1 20.03 11.42"),
        ]
        case .photos: return [
            // A — viewfinder corners round a bag.
            ("A viewfinder round a bag",
             "M3.5 8V5c0-.8.7-1.5 1.5-1.5h3 M16 3.5h3c.8 0 1.5.7 1.5 1.5v3 M20.5 16v3c0 .8-.7 1.5-1.5 1.5h-3 M8 20.5H5c-.8 0-1.5-.7-1.5-1.5v-3 M8.8 10h6.4a1.3 1.3 0 0 1 1.3 1.3v3.9a1.3 1.3 0 0 1 -1.3 1.3h-6.4a1.3 1.3 0 0 1 -1.3 -1.3v-3.9a1.3 1.3 0 0 1 1.3 -1.3Z M10.3 10V8.9c0-.4.3-.8.8-.8h1.8c.5 0 .8.4.8.8V10"),
            // B — a camera (the Camera template icon's body) with a bag in its lens.
            ("A camera with a bag in the lens",
             "M2.5 7.5h4L8 5h8l1.5 2.5h4V21h-19Z M7.4 14.25a4.6 4.6 0 1 0 9.2 0a4.6 4.6 0 1 0 -9.2 0 M10.4 13.7h3.2a.5 .5 0 0 1 .5 .5v1.6a.5 .5 0 0 1 -.5 .5h-3.2a.5 .5 0 0 1 -.5 -.5v-1.6a.5 .5 0 0 1 .5 -.5Z M11.2 13.7v-.9h1.6v.9"),
            // C — a photo print, slightly tilted, a bag in the picture.
            ("A photo print with a bag",
             "M4.81 3.92L16.69 2.25A1.5 1.5 -8 0 1 18.38 3.53L20.47 18.38A1.5 1.5 -8 0 1 19.19 20.08L7.31 21.75A1.5 1.5 -8 0 1 5.62 20.47L3.53 5.62A1.5 1.5 -8 0 1 4.81 3.92Z M5.13 17L19.98 14.92 M8.96 9.8L14.31 9.05A1 1 -8 0 1 15.44 9.9L15.72 11.88A1 1 -8 0 1 14.87 13.01L9.52 13.76A1 1 -8 0 1 8.39 12.91L8.11 10.93A1 1 -8 0 1 8.96 9.8Z M10.25 9.62L10.1 8.53C10.04 8.13 10.3 7.8 10.69 7.74L12.08 7.55C12.48 7.49 12.82 7.75 12.87 8.14L13.02 9.23"),
        ]
        case .ready: return [
            // A — the app's own door (the "I leave at" mark), a bag standing by it.
            ("A bag by the door",
             "M2.5 20.5h19 M4.5 20.5V4.8A1.3 1.3 0 0 1 5.8 3.5h6.4A1.3 1.3 0 0 1 13.5 4.8V20.5 M10.5 12.5h1.2 M16.7 11h3.1a1.2 1.2 0 0 1 1.2 1.2v5.1a1.2 1.2 0 0 1 -1.2 1.2h-3.1a1.2 1.2 0 0 1 -1.2 -1.2v-5.1a1.2 1.2 0 0 1 1.2 -1.2Z M17 11V8h2.5v3 M16.8 18.5v2 M19.7 18.5v2"),
            // B — a carry-on rolling, pulled by its handle, two motion lines behind.
            ("A rolling bag",
             "M10.02 8.27L17.85 9.93L15.98 18.73L8.15 17.07Z M11.98 8.68L13.12 3.3L17.04 4.13L15.89 9.51 M7.66 19.04a1.1 1.1 0 1 0 2.2 0a1.1 1.1 0 1 0 -2.2 0 M13.52 20.29a1.1 1.1 0 1 0 2.2 0a1.1 1.1 0 1 0 -2.2 0 M2.5 11h3.5 M3.5 15h3"),
            // C — a chequered flag at the finish line.
            ("A flag at the finish",
             "M6 21V3.5 M6 4.2c2.2-1.2 4.4-1.2 6.6 0s4.4 1.2 6.6 0v7.2c-2.2 1.2-4.4 1.2-6.6 0s-4.4-1.2-6.6 0 M12.6 4.2v7.2 M6 7.8c2.2-1.2 4.4-1.2 6.6 0s4.4 1.2 6.6 0 M3 21h18"),
        ]
        }
    }
}

struct StationIconSheet: View {
    static var wanted: Bool { ProcessInfo.processInfo.arguments.contains("-stationIconSheet") }
    /// 1: the title and the first four rows; 2: the last three.
    static var page: Int { UserDefaults.standard.integer(forKey: "stationIconPage") == 2 ? 2 : 1 }

    @Environment(\.colorScheme) private var scheme
    /// The Pack step's green — the stations live inside it.
    private var tint: Color { Library.LoopStep.pack.tint }
    private var words: Color { Library.LoopStep.pack.words(scheme) }

    private var rows: [StationIconSample] {
        let all = StationIconSample.allCases
        return StationIconSheet.page == 1 ? Array(all.prefix(4)) : Array(all.dropFirst(4))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if StationIconSheet.page == 1 {
                Text("Packing day icons · \(scheme == .dark ? "night" : "day")")
                    .font(.system(.subheadline, weight: .bold)).foregroundStyle(Theme.ink)
                Text("Each: on its station chip, lit (done) and unlit, then 2×")
                    .font(.system(.caption)).foregroundStyle(Theme.muted)
                    .padding(.bottom, 6)
                HStack(spacing: 0) {
                    ForEach(["A", "B", "C"], id: \.self) { c in
                        Text(c).font(.system(.subheadline, weight: .bold)).foregroundStyle(Theme.ink)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.bottom, 2)
            }
            ForEach(rows, id: \.self) { station in
                Rectangle().fill(Theme.line).frame(height: 1).padding(.vertical, 5)
                Text(station == .day ? "Packing day — the whole" : station.name)
                    .font(.system(.footnote, weight: .bold)).foregroundStyle(words)
                    .padding(.bottom, 4)
                HStack(spacing: 0) {
                    ForEach(Array(StationIconCandidates.all(station).enumerated()), id: \.offset) { _, c in
                        cell(station, c.path).frame(maxWidth: .infinity)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10).padding(.top, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.bg.ignoresSafeArea())
        .accessibilityIdentifier("station-icon-sheet")
    }

    private func cell(_ station: StationIconSample, _ path: String) -> some View {
        VStack(spacing: 5) {
            chip(station, path, on: true)
            chip(station, path, on: false)
            HStack(spacing: 6) {
                disc(path, on: true)
                disc(path, on: false)
            }
            .padding(.top, 1)
        }
    }

    /// A station chip: its mark at 17 points before its name — green and white when the
    /// station is done, the green line on the card while it is not.
    private func chip(_ station: StationIconSample, _ path: String, on: Bool) -> some View {
        HStack(spacing: 5) {
            IconMark(path: path, size: 17, weight: 1.9)
            Text(station.name)
                .font(.system(.footnote, weight: .semibold))
                .lineLimit(1).fixedSize()
        }
        .foregroundStyle(on ? Color.white : words)
        .padding(.horizontal, 9).frame(minHeight: 30)
        .background(Capsule().fill(on ? tint : Theme.card))
        .overlay(Capsule().stroke(tint.opacity(on ? 0 : 0.7), lineWidth: 1.2))
    }

    /// The mark alone at 2× (34 points, the chip's 17 doubled), lit and unlit.
    private func disc(_ path: String, on: Bool) -> some View {
        IconMark(path: path, size: 34, weight: 1.9)
            .foregroundStyle(on ? Color.white : words)
            .frame(width: 50, height: 50)
            .background(Circle().fill(on ? tint : Theme.card))
            .overlay(Circle().stroke(tint.opacity(on ? 0 : 0.7), lineWidth: 2.4))
    }
}
#endif
