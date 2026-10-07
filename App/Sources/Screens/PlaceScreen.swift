import SwiftUI
import UniformTypeIdentifiers
import PackingCore
import PackingLibrary

// "Tap the garage, see the garage" — stop A of his idea plan (7 Oct 2026, "fantastic"),
// without stickers (his call the same day: "let's skip the NFC"). Each place in Your
// choices has a small square code, printed on a 12 mm label (his Brother P-touch CUBE,
// `PlaceLabel`) and stuck where the things are kept. The iPhone's Camera, pointed at it,
// offers to open Packing, and the app opens on that place — the link is
// AMSPACKING://P/<the place's code> (`PlaceLink`). What it opens depends on the day
// (`Library.placeVisit`): a trip being packed → that trip, only its lines from there;
// back from a trip → what goes back there; otherwise everything kept there. The Mac
// shows the same lists, from the place's page in Your choices (Open).

/// Where a place's link leads, decided once, as it opens.
struct PlaceOpening: Identifiable, Equatable {
    /// As his list spells it — or as the link said, when nothing knows that name.
    let place: String
    /// Something knows the place (his list, a renamed place, a thing).
    let known: Bool
    let visit: Library.PlaceVisit
    var id: String { place }

    /// A label's code: the place it was given to, as his list spells it today.
    static func of(code: String, in library: Library, today: String) -> PlaceOpening {
        guard let place = library.place(forCode: code) else {
            return PlaceOpening(place: "", known: false, visit: .keptThere)
        }
        return PlaceOpening(place: place, known: true, visit: library.placeVisit(today: today))
    }

    /// A place by its name (Open, on the place's page in Your choices).
    static func of(place asked: String, in library: Library, today: String) -> PlaceOpening {
        guard let place = library.placeNamed(asked) else {
            return PlaceOpening(place: jsTrim(asked), known: false, visit: .keptThere)
        }
        return PlaceOpening(place: place, known: true, visit: library.placeVisit(today: today))
    }

    /// The trip a code opens on this place's lines — a trip being packed. Every other
    /// case shows `PlaceScreen`.
    var packingTrip: String? {
        if known, case .packing(let id) = visit { return id }
        return nil
    }
}

/// One place's list, when no trip is being packed: what goes back there from a trip,
/// or everything kept there.
struct PlaceScreen: View {
    let opening: PlaceOpening
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    @State private var thing: ThingOpened?
    private struct ThingOpened: Identifiable { let id: String }

    private var tint: Color {
        if case .goingBack = opening.visit { return AppSection.events.color }
        return AppSection.care.color
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(opening.place.isEmpty ? "A place" : opening.place).font(.system(.title3, weight: .bold)).foregroundStyle(Theme.ink)
                    .lineLimit(2)
                    .accessibilityIdentifier("place-title")
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(HeaderButtonStyle(tint: tint, filled: true)).focusEffectDisabled()
                    .keyboardShortcut(.cancelAction)            // Escape closes it, as Done does
                    .accessibilityIdentifier("place-done")
            }
            .padding(16)
            KeyboardAwayScroll {
                VStack(alignment: .leading, spacing: 0) {
                    content
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .sheet(item: $thing) { ThingEditor(itemId: $0.id).environmentObject(model) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("place-detail")
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 480)
        #endif
    }

    @ViewBuilder private var content: some View {
        if !opening.known {
            says("This label\u{2019}s place is no longer in Your choices. Print a new label from the place\u{2019}s page there.")
        } else if case .goingBack(let tripId) = opening.visit {
            let trip = model.library.trip(tripId)
            let lines = model.library.goingBack(tripId: tripId, to: opening.place)
            says("Back from \u{201C}\(trip?.name ?? "")\u{201D}: " + (lines.isEmpty ? "nothing goes back here."
                 : lines.count == 1 ? "1 thing goes back here." : "\(lines.count) things go back here."))
            ForEach(Array(lines.enumerated()), id: \.element.id) { n, line in
                row(name: line.name, detail: Library.homeBag(line) == "Other" ? "Not in a bag" : Library.homeBag(line),
                    qty: PackLine.count(line, qtyNights(trip ?? newEvent()), washed: false), n: n) {
                    if let id = model.library.thingBehind(line) { thing = ThingOpened(id: id) }
                }
            }
        } else {
            let things = model.library.thingsKept(at: opening.place)
            says(things.isEmpty ? "Nothing is kept here yet. A thing\u{2019}s place is set on its page, under Kept at home."
                 : things.count == 1 ? "Everything kept here: 1 thing." : "Everything kept here: \(things.count) things.")
            ForEach(Array(things.enumerated()), id: \.element.id) { n, item in
                row(name: item.name, detail: item.container, qty: "", n: n) { thing = ThingOpened(id: item.id) }
            }
        }
    }

    private func says(_ text: String) -> some View {
        Text(text)
            .font(.system(.subheadline)).foregroundStyle(Theme.muted)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, 8)
            .accessibilityIdentifier("place-says")
    }

    /// One line: its name, how many, and its bag — as tall as its words (`Metrics.line`).
    private func row(name: String, detail: String, qty: String, n: Int, open: @escaping () -> Void) -> some View {
        Button(action: open) {
            HStack(spacing: 8) {
                Text(name).font(.system(.body)).foregroundStyle(Theme.ink).lineLimit(2)
                Spacer(minLength: 8)
                if !qty.isEmpty {
                    Text(qty).font(.system(.subheadline, weight: .semibold).monospacedDigit()).foregroundStyle(Theme.muted)
                }
                if !detail.isEmpty {
                    Text(detail).font(.system(.footnote)).foregroundStyle(Theme.muted).lineLimit(1)
                        .frame(maxWidth: 150, alignment: .trailing)
                }
            }
            .padding(.vertical, 2)
            .frame(minHeight: Metrics.line)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier("place-line-\(n)")
    }
}

/// A place's page in Your choices (0.69): its square code, its label for the P-touch,
/// and Open — what the code opens, which is how the Mac sees a place's list.
struct PlaceCodeSheet: View {
    let place: String
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    @State private var opening: PlaceOpening?
    @State private var tripOpened: TripOpened?
    private struct TripOpened: Identifiable { let id: String; let place: String }
    /// The label as a file, for Share (iPhone) — written as the page opens.
    @State private var labelFile: URL?
    #if os(macOS)
    @State private var saving = false
    @State private var saved = ""
    #endif

    var body: some View {
        let code = model.library.placeCode(for: place) ?? ""
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(place).font(.system(.title3, weight: .bold)).foregroundStyle(Theme.ink)
                    .lineLimit(2)
                    .accessibilityIdentifier("place-code-title")
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(HeaderButtonStyle(tint: AppSection.settings.color, filled: true)).focusEffectDisabled()
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("place-code-done")
            }
            .padding(16)
            KeyboardAwayScroll {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Print its label and stick it where these things are kept. Point the iPhone\u{2019}s Camera at the square and tap the link that appears: the app opens on this place.")
                        .font(.system(.subheadline)).foregroundStyle(Theme.ink.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                    if let big = PlaceLabel.codeImage(code: code) {
                        // Black on white whatever the screen's mode: a code is read dark on light.
                        Image(decorative: big, scale: 1)
                            .interpolation(.none).resizable().scaledToFit()
                            .frame(width: 200, height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                            .accessibilityElement()
                            .accessibilityLabel("Square code for \(place)")
                            .accessibilityIdentifier("place-code")
                            .frame(maxWidth: .infinity)
                    }
                    labelPart(code)
                    Button { open() } label: {
                        WideButtonLabel(title: "Open \(place)", tint: AppSection.settings.color) {
                            SVGPath.path("M9 6l6 6-6 6").stroke(style: StrokeStyle(lineWidth: 1.9, lineCap: .round, lineJoin: .round))
                                .frame(width: 24, height: 24)
                        }
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("place-code-open")
                    Text("What it opens: a trip you are packing, with only what to take from here; back from a trip, what goes back here; otherwise everything kept here.")
                        .font(.system(.footnote)).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("place-code-hint")
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        // The code is kept with the library the first time its page opens, so both
        // devices — and a backup — know it before a label is printed.
        .onAppear {
            PlaceLabels.keepCodes([place], in: model)
            labelFile = PlaceLabels.write([place], from: model.library).first
        }
        .sheet(item: $opening) { PlaceScreen(opening: $0).environmentObject(model) }
        .sheet(item: $tripOpened) { TripScreen(tripId: $0.id, place: $0.place).environmentObject(model) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("place-code-detail")
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 600)
        #endif
    }

    /// The label as it prints — 12 mm tape, the code and the name — and the main button
    /// that hands it on: Share on the iPhone (Save Image, then Brother's app takes it from
    /// Photos; or Files), a Save window on the Mac.
    @ViewBuilder private func labelPart(_ code: String) -> some View {
        if let label = PlaceLabel.image(code: code, name: place) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Label for P-touch, 12 mm tape")
                    .font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.ink)
                // Three quarters of a point a dot, never smoothed: the tape, as it prints.
                Image(decorative: label, scale: 1)
                    .interpolation(.none).resizable()
                    .frame(width: CGFloat(label.width) * 0.75, height: CGFloat(label.height) * 0.75)
                    .accessibilityElement()
                    .accessibilityLabel("Label for \(place)")
                    .accessibilityIdentifier("place-label")
                    .padding(.vertical, 8).padding(.horizontal, 10)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.line, lineWidth: 1))
                #if os(macOS)
                Button { saving = true } label: { mainLabel("Label for P-touch\u{2026}") }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("place-label-save")
                    .fileExporter(isPresented: $saving, document: labelFile.flatMap { PNGDocument(url: $0) },
                                  contentType: .png, defaultFilename: PlaceLabel.fileName(place)) { result in
                        if case .success(let url) = result { saved = "Saved: \(url.lastPathComponent)" } else { saved = "Not saved." }
                    }
                if !saved.isEmpty {
                    Text(saved).font(.system(.footnote)).foregroundStyle(Theme.muted)
                        .accessibilityIdentifier("place-label-saved")
                }
                #else
                if let file = labelFile {
                    ShareLink(item: file) { mainLabel("Label for P-touch") }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("place-label-share")
                }
                #endif
                Text("In Brother\u{2019}s app, add it as a picture, 12 mm tape.")
                    .font(.system(.footnote)).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func mainLabel(_ title: String) -> some View {
        Text(title).font(.system(.body, weight: .semibold)).foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: Metrics.row)
            .background(RoundedRectangle(cornerRadius: 12).fill(AppSection.settings.color))
            .contentShape(Rectangle())
    }

    /// What the code itself would open, here.
    private func open() {
        let o = PlaceOpening.of(place: place, in: model.library, today: Today.local)
        if let trip = o.packingTrip { tripOpened = TripOpened(id: trip, place: o.place) } else { opening = o }
    }
}

/// The places' labels as PNG files in the app's temporary folder, named after their
/// places ("Garage label.png") — what Share hands on, and what the Mac copies into the
/// folder he picks.
enum PlaceLabels {
    /// Keeps the places' codes with the library — but never on a device that holds
    /// nothing yet: a library with something in it shuts the first-run doors (bring in
    /// a backup, wait for iCloud). There the label shows the code the place WILL get;
    /// the name decides it, so it is the same code.
    @MainActor static func keepCodes(_ places: [String], in model: LibraryModel) {
        guard !model.library.isEmpty else { return }
        let missing = places.filter { p in model.library.placeCode(for: p).map { model.library.placeCodes()[$0] == nil } ?? false }
        guard !missing.isEmpty else { return }
        model.change { lib in for p in missing { _ = lib.givePlaceCode(p) } }
    }

    static func write(_ places: [String], from library: Library) -> [URL] {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Place labels", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return places.compactMap { place in
            guard let code = library.placeCode(for: place), let png = PlaceLabel.png(code: code, name: place) else { return nil }
            let url = folder.appendingPathComponent(PlaceLabel.fileName(place))
            return (try? png.write(to: url, options: .atomic)) != nil ? url : nil
        }
    }
}

/// A PNG for the Mac's Save window.
struct PNGDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.png] }
    var data: Data
    init?(url: URL) {
        guard let data = try? Data(contentsOf: url) else { return nil }
        self.data = data
    }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

/// A square code, drawn — three corner squares and two dots, on the 24-point grid.
struct CodeMark: View {
    var body: some View {
        GridShape(d: "M4.5 4.5h5v5h-5ZM14.5 4.5h5v5h-5ZM4.5 14.5h5v5h-5ZM14.5 14.5h1.5v1.5h-1.5ZM18 18h1.5v1.5H18Z")
            .stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
            .accessibilityHidden(true)
    }
}
