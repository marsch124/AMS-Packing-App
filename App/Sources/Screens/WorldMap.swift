import SwiftUI
import MapKit
import PackingCore
import PackingLibrary

/// Where he has been — the web app's world map (gap list, 2026-09-27): one pin per
/// place (repeat visits share it, and say how many), a line through the dated
/// trips oldest first, and under the map a card per place with its trips. A trip
/// gets its place when its weather is looked up; trips that name a place but were
/// never looked up can be found in one press.
struct WorldMapScreen: View {
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    @State private var camera: MapCameraPosition = .automatic
    @State private var picked: String?
    @State private var findNote = ""

    var body: some View {
        let pins = model.library.mapPlaces()
        let path = model.library.mapPath()
        let toFind = model.library.placesToFind()
        VStack(spacing: 0) {
            HStack {
                Text("Where you have been").font(.system(.title3, weight: .bold)).foregroundStyle(AppSection.events.color)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(HeaderButtonStyle(tint: AppSection.events.color, filled: true)).focusEffectDisabled()
                    .font(.system(.body, weight: .semibold)).foregroundStyle(AppSection.events.color)
                    .keyboardShortcut(.cancelAction)            // Escape closes it, as Done does (Escape everywhere, 5 Oct 2026)
                    .accessibilityIdentifier("map-done")
            }
            .padding(16)
            ScrollViewReader { reader in
                KeyboardAwayScroll {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(Library.mapSummary(pins))
                            .font(.system(.callout, weight: .semibold)).foregroundStyle(Theme.ink)
                            .accessibilityIdentifier("map-summary")
                        if let top = mostVisited(pins) {
                            Text("Most visited: \(top.place), \(top.events.count) trips")
                                .font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.muted)
                                .accessibilityIdentifier("map-most")
                        }
                        if pins.isEmpty {
                            Text("No places yet. A trip joins the map when it has a place: type it in Trip settings (the pen) or on its weather line.")
                                .font(.system(.subheadline)).foregroundStyle(Theme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("map-empty")
                        } else {
                            map(pins, path, reader)
                        }
                        if !toFind.isEmpty { findButton(toFind.count) }
                        ForEach(Array(pins.enumerated()), id: \.element.key) { n, pin in
                            card(pin, n).id(pin.key)
                        }
                    }
                    .padding(.horizontal, 16).padding(.bottom, 24)
                }
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("map-screen")
        #if os(macOS)
        .frame(minWidth: 560, minHeight: 600)
        #endif
    }

    private func map(_ pins: [PlacePin], _ path: [TripStop], _ reader: ScrollViewProxy) -> some View {
        Map(position: $camera) {
            if path.count >= 2 {
                MapPolyline(coordinates: path.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) })
                    .stroke(AppSection.events.color.opacity(0.55), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [6, 5]))
            }
            ForEach(Array(pins.enumerated()), id: \.element.key) { n, pin in
                Annotation(pin.place, coordinate: CLLocationCoordinate2D(latitude: pin.lat, longitude: pin.lon)) {
                    Button {
                        picked = pin.key
                        withAnimation { reader.scrollTo(pin.key, anchor: .top) }
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Circle().fill(AppSection.events.color)
                                .overlay(Circle().stroke(Color.white, lineWidth: 2.5))
                                .frame(width: picked == pin.key ? 22 : 16, height: picked == pin.key ? 22 : 16)
                            if pin.events.count > 1 {
                                Text("\(pin.events.count)")
                                    .font(.system(.caption2, weight: .semibold)).foregroundStyle(.white)
                                    .padding(.horizontal, 5).padding(.vertical, 1)
                                    .background(Capsule().fill(AppSection.care.color))
                                    .offset(x: 10, y: -10)
                            }
                        }
                        .frame(width: 40, height: 40).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("map-pin-\(n)")
                    .accessibilityLabel(pin.place)
                    .accessibilityValue("\(pin.events.count)")
                }
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .frame(height: 320)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
        // Named on a container: the Mac reports a bare map as its own kind of
        // element, and GitHub's Mac could not find it by this name (0.37).
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("map-view")
    }

    private func findButton(_ count: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                Task {
                    let missed = await model.findPlaces()
                    findNote = missed.isEmpty ? "Found." : "Not found: \(missed.joined(separator: ", "))"
                }
            } label: {
                Text(model.findingPlaces ? "Looking…" : "Find \(count) place\(count == 1 ? "" : "s") on the map")
                    .font(.system(.callout, weight: .semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: Metrics.tap)
                    .background(RoundedRectangle(cornerRadius: 12).fill(AppSection.events.color))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain).focusEffectDisabled()
            .accessibilityIdentifier("map-find")
            Text("Trips that name a place but are not on the map yet.")
                .font(.system(.footnote)).foregroundStyle(Theme.muted)
            if !findNote.isEmpty {
                Text(findNote).font(.system(.footnote, weight: .semibold)).foregroundStyle(Theme.muted)
                    .accessibilityIdentifier("map-find-note")
            }
        }
    }

    private func card(_ pin: PlacePin, _ n: Int) -> some View {
        let lit = picked == pin.key
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(pin.place.isEmpty ? "A place" : pin.place)
                    .font(.system(.body, weight: .semibold)).foregroundStyle(Theme.ink)
                    .accessibilityIdentifier("map-place-\(n)-name")
                Spacer()
                Text("\(pin.events.count) trip\(pin.events.count == 1 ? "" : "s")")
                    .font(.system(.footnote, weight: .semibold)).foregroundStyle(Theme.muted)
            }
            ForEach(pin.events, id: \.id) { e in
                Text(e.startDate.isEmpty ? e.name : "\(e.name) · \(WorldMapScreen.day(e.startDate))")
                    .font(.system(.subheadline)).foregroundStyle(Theme.ink)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(lit ? AppSection.events.color.opacity(0.14) : Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(lit ? AppSection.events.color : Theme.line, lineWidth: lit ? 2 : 1))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("map-place-\(n)")
        .accessibilityValue(lit ? "picked" : "")
    }

    /// "21 Sep 2026", in English as the rest of the app.
    static func day(_ ymd: String) -> String {
        let parts = ymd.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, (1...12).contains(parts[1]) else { return ymd }
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return "\(parts[2]) \(months[parts[1] - 1]) \(parts[0])"
    }
}

/// The way in, on Trips: a drawn map pin that owns its sheet.
struct WorldMapDoor: View {
    @EnvironmentObject var model: LibraryModel
    @State private var open = false

    var body: some View {
        Button { open = true } label: {
            SVGPath.path("M12 21s-6.5-6.2-6.5-11A6.5 6.5 0 0 1 18.5 10c0 4.8-6.5 11-6.5 11zM12 7.7a2.3 2.3 0 1 0 0 4.6a2.3 2.3 0 1 0 0-4.6")
                .stroke(style: StrokeStyle(lineWidth: 1.9, lineCap: .round, lineJoin: .round))
                // On its 24-pt grid, like the search beside it: framed at 26 it sat 1 pt
                // up and to the left of the button's middle.
                .frame(width: 24, height: 24)
                .foregroundStyle(AppSection.events.color)
                .frame(width: Metrics.tap, height: Metrics.tap).contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier("events-map")
        .accessibilityLabel("Map of your trips")
        .sheet(isPresented: $open) { WorldMapScreen().environmentObject(model) }
    }
}

/// The map on the Trips tab, under All your trips: every place he has been, as a
/// dot. It is a picture, not a thing to drag — a tap opens the whole map.
struct MiniWorldMap: View {
    @EnvironmentObject var model: LibraryModel
    @State private var open = false

    var body: some View {
        let pins = model.library.mapPlaces()
        Button { open = true } label: {
            ZStack(alignment: .bottomLeading) {
                if pins.isEmpty {
                    Text("Your trips appear here once they have a place.")
                        .font(.system(.subheadline)).foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity, minHeight: 90)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
                } else {
                    // One place alone would zoom to its streets — show its region instead.
                    Map(initialPosition: pins.count == 1
                            ? .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: pins[0].lat, longitude: pins[0].lon),
                                                         span: MKCoordinateSpan(latitudeDelta: 9, longitudeDelta: 12)))
                            : .automatic,
                        interactionModes: []) {
                        ForEach(Array(pins.enumerated()), id: \.element.key) { _, pin in
                            Annotation(pin.place, coordinate: CLLocationCoordinate2D(latitude: pin.lat, longitude: pin.lon)) {
                                Circle().fill(AppSection.events.color)
                                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                    .frame(width: 13, height: 13)
                            }
                        }
                    }
                    .mapStyle(.standard(pointsOfInterest: .excludingAll))
                    .frame(height: 210)
                    .allowsHitTesting(false)
                    Text(Library.mapSummary(pins))
                        .font(.system(.footnote, weight: .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(AppSection.events.color))
                        .padding(10)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier("events-minimap")
        .accessibilityLabel("Map of your trips")
        .accessibilityValue(Library.mapSummary(pins))
        .sheet(isPresented: $open) { WorldMapScreen().environmentObject(model) }
    }
}

