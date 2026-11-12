import SwiftUI
import PackingCore
import PackingLibrary
#if canImport(Vision)
import Vision
#endif

/// The room walk (0.116 — inventory step 2, his answers of 11 Nov 2026): pick a room, then photo +
/// name, photo + name… On the iPhone the camera opens at once and comes straight back after each
/// Save · next; the name is guessed on the device from the photo (Apple's image recognition — nothing
/// leaves the phone) and he confirms or types it; How many makes a set one thing × count. "12 in
/// Kitchen" counts as he goes; Done ends the room, and Done on the room list ends the walk.
struct RoomWalkScreen: View {
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    /// The room being walked; nil = the room list.
    @State private var room: String?
    /// What this walk added, per room (the room list shows it).
    @State private var added: [String: Int] = [:]
    @State private var name = ""
    @State private var count = 1
    @State private var staysHome = false
    @State private var photo: Data?
    @State private var guesses: [String] = []
    /// A serial read off the photo (0.122); "" = none or dropped.
    @State private var serial = ""
    @State private var needs = ""
    @State private var camera = false
    @FocusState private var nameFocus: Bool

    private var tint: Color { AppSection.care.color }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if room != nil {
                    BackArrow(title: "Rooms", tint: tint, id: "walk-back") { endRoom() }
                }
                Spacer()
                Button("Done") { room == nil ? dismiss() : endRoom() }
                    .buttonStyle(HeaderButtonStyle(tint: tint, filled: true)).focusEffectDisabled()
                    .font(.system(.body, weight: .semibold)).foregroundStyle(tint)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("walk-done")
            }
            .padding(.horizontal, 16).padding(.top, 8)
            Text(room ?? "Room walk").font(.system(.largeTitle, weight: .bold)).foregroundStyle(tint)
                .lineLimit(1).minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .accessibilityIdentifier("walk-title")
            ScrollView {
                if let room { walking(room) } else { rooms }
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        #if os(iOS)
        .fullScreenCover(isPresented: $camera) {
            CameraView { data in
                camera = false
                if let jpeg = data.flatMap({ JPEG.make(from: $0) }) { took(jpeg) }
            }
            .ignoresSafeArea()
        }
        #endif
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 560)
        #endif
    }

    // MARK: The room list

    private var rooms: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pick a room, then photo and name each thing in it.")
                .font(.subheadline).foregroundStyle(Theme.muted)
            VStack(spacing: 0) {
                let choices = model.library.roomChoices()
                ForEach(Array(choices.enumerated()), id: \.element) { n, r in
                    Button { start(r) } label: {
                        HStack {
                            Text(r).font(.body).foregroundStyle(Theme.ink)
                            Spacer()
                            if let k = added[r], k > 0 {
                                Text("\(k) added").font(.subheadline.monospacedDigit()).foregroundStyle(tint)
                                    .accessibilityIdentifier("walk-added-\(n)")
                            }
                            Text("›").foregroundStyle(Theme.muted)
                        }
                        .padding(.horizontal, 12).frame(minHeight: Metrics.tap)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityIdentifier("walk-room-\(n)")
                    if n < choices.count - 1 { Divider().padding(.leading, 12) }
                }
            }
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
    }

    // MARK: In a room

    private func walking(_ room: String) -> some View {
        let here = model.library.items.filter { normName($0.storage) == normName(room) }.count
        return VStack(alignment: .leading, spacing: 10) {
            Text("\(here) in \(room)")
                .font(.system(.headline).monospacedDigit()).foregroundStyle(tint)
                .accessibilityIdentifier("walk-count")
            if let photo, let img = UIImageish.image(photo) {
                img.resizable().scaledToFit().frame(maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .accessibilityIdentifier("walk-shot")
            }
            PhotoTakers(id: "walk-photo", testTitle: "Test photo", take: photo == nil ? "Take a photo" : "Take again",
                        tint: tint) { jpeg in if let jpeg { took(jpeg) } }
            TextField("What is it?", text: $name)
                .textFieldStyle(.plain).font(.body).foregroundStyle(Theme.ink)
                .padding(.horizontal, 12).frame(minHeight: Metrics.tap)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                .focused($nameFocus)
                .onSubmit { save(room) }
                .accessibilityIdentifier("walk-name")
            if !guesses.isEmpty {
                FlowRow(spacing: 8) {
                    ForEach(Array(guesses.enumerated()), id: \.element) { n, g in
                        Button { name = g } label: {
                            Text(g).font(.subheadline.weight(.semibold))
                                .foregroundStyle(normName(name) == normName(g) ? .white : tint)
                                .padding(.horizontal, 12).frame(minHeight: 32)
                                .background(Capsule().fill(normName(name) == normName(g) ? tint : .clear))
                                .overlay(Capsule().stroke(tint, lineWidth: 1.4))
                        }
                        .buttonStyle(.plain).focusEffectDisabled()
                        .accessibilityIdentifier("walk-guess-\(n)")
                    }
                }
            }
            if !serial.isEmpty {
                HStack(spacing: 10) {
                    Text("Serial").font(.body).foregroundStyle(Theme.ink)
                    Text(serial).font(.body.monospaced()).foregroundStyle(tint).lineLimit(1).truncationMode(.middle)
                        .accessibilityIdentifier("walk-serial")
                    Spacer()
                    Button { serial = "" } label: {
                        Text("\u{2715}").font(.body.weight(.semibold)).foregroundStyle(Theme.muted)
                            .frame(width: Metrics.tap, height: Metrics.tap).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .accessibilityLabel("Drop the serial")
                    .accessibilityIdentifier("walk-serial-clear")
                }
                .padding(.leading, 12)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
            }
            HStack(spacing: 10) {
                Text("How many").font(.body).foregroundStyle(Theme.ink)
                Spacer()
                stepButton("−", id: "walk-qty-minus") { count = max(1, count - 1) }
                Text("\(count)").font(.body.monospacedDigit()).foregroundStyle(Theme.ink)
                    .frame(minWidth: 28).accessibilityIdentifier("walk-qty")
                stepButton("+", id: "walk-qty-plus") { count += 1 }
            }
            Toggle("Stays at home", isOn: $staysHome).tint(tint)
                .accessibilityIdentifier("walk-stays-home")
            Button { save(room) } label: {
                Text("Save · next").font(.body.weight(.semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(minHeight: Metrics.tap + 4)
                    .background(RoundedRectangle(cornerRadius: 10).fill(tint))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain).focusEffectDisabled()
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier("walk-save")
            if !needs.isEmpty {
                Text(needs).font(.subheadline).foregroundStyle(AppSection.actions.color)
                    .accessibilityIdentifier("walk-needs")
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
    }

    private func stepButton(_ s: String, id: String, act: @escaping () -> Void) -> some View {
        Button(action: act) {
            Text(s).font(.title3.weight(.semibold)).foregroundStyle(tint)
                .frame(width: Metrics.tap, height: Metrics.tap)
                .overlay(Circle().stroke(tint, lineWidth: 1.4))
                .contentShape(Circle())
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityIdentifier(id)
    }

    // MARK: Steps

    private func start(_ r: String) {
        room = r
        fresh()
        openCamera()
    }

    private func endRoom() {
        room = nil
        fresh()
    }

    private func fresh() {
        name = ""; count = 1; photo = nil; guesses = []; serial = ""; needs = ""
    }

    /// The camera straight away (his pick) — on an iPhone with a camera, never under the tests.
    private func openCamera() {
        #if os(iOS)
        if !PhotoTakers.drawn, UIImagePickerController.isSourceTypeAvailable(.camera) { camera = true }
        #endif
    }

    private func took(_ jpeg: Data) {
        photo = jpeg
        serial = ""
        let have = Set(model.library.items.map { normName($0.name) })
        if PhotoTakers.drawn {
            guesses = Library.nameGuesses([("teapot", 0.8), ("coffee_mug", 0.5)], have: have)
            serial = Library.serialGuess(["Model X200", "S/N: TEST-4512 0877"]) ?? ""
        } else {
            Task.detached {
                let labels = RoomWalkScreen.labels(jpeg)
                let sn = Library.serialGuess(RoomWalkScreen.textLines(jpeg)) ?? ""
                await MainActor.run { guesses = Library.nameGuesses(labels, have: have); serial = sn }
            }
        }
    }

    private func save(_ room: String) {
        let clean = jsTrim(name)
        guard !clean.isEmpty else { needs = "Give it a name first."; nameFocus = true; return }
        if model.library.items.contains(where: { normName($0.name) == normName(clean) }) {
            needs = "You already have \(clean) — give it another name."; return
        }
        let shot = photo, n = count, home = staysHome, sn = serial
        model.change(named: "Add \(clean)") { lib in
            guard let it = lib.walkAdd(name: clean, room: room, count: n, staysHome: home, serial: sn) else { return }
            if let shot { _ = lib.addThingPhoto(id: it.id, jpeg: shot) }
        }
        added[room, default: 0] += 1
        fresh()
        openCamera()
    }

    /// What Apple's on-device recogniser sees in the photo, best first.
    nonisolated static func labels(_ jpeg: Data) -> [(String, Double)] {
        #if canImport(Vision)
        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(data: jpeg)
        guard (try? handler.perform([request])) != nil, let seen = request.results else { return [] }
        return seen.prefix(30).map { ($0.identifier, Double($0.confidence)) }
        #else
        return []
        #endif
    }

    /// The text Apple's on-device reader finds in the photo, line by line (0.122 — for a serial).
    nonisolated static func textLines(_ jpeg: Data) -> [String] {
        #if canImport(Vision)
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        let handler = VNImageRequestHandler(data: jpeg)
        guard (try? handler.perform([request])) != nil, let seen = request.results else { return [] }
        return seen.compactMap { $0.topCandidates(1).first?.string }
        #else
        return []
        #endif
    }
}

/// A JPEG as a SwiftUI image on both the iPhone and the Mac.
enum UIImageish {
    static func image(_ data: Data) -> Image? {
        #if os(iOS)
        return UIImage(data: data).map { Image(uiImage: $0) }
        #else
        return NSImage(data: data).map { Image(nsImage: $0) }
        #endif
    }
}
