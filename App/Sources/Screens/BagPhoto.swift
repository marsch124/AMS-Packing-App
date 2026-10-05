import SwiftUI
import PhotosUI
import ImageIO
import UniformTypeIdentifiers
import PackingCore
import PackingLibrary

/// Pictures as the app keeps them: JPEG, at most 1600 points on the long side (a
/// photo travels to the other device through iCloud, and a camera's full size would
/// make every sync slow), read back from the data URL a photo record holds.
enum JPEG {
    static func make(from data: Data, maxSide: Int = 1600) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                        kCGImageSourceThumbnailMaxPixelSize: maxSide,
                                        kCGImageSourceCreateThumbnailWithTransform: true]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return encode(image)
    }

    static func encode(_ image: CGImage) -> Data? {
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: 0.75] as CFDictionary)
        return CGImageDestinationFinalize(dest) ? out as Data : nil
    }

    static func image(dataURL: String) -> CGImage? {
        guard let comma = dataURL.firstIndex(of: ","),
              let data = Data(base64Encoded: String(dataURL[dataURL.index(after: comma)...])),
              let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    /// A plain drawn picture for the UI tests, which cannot work a camera or a photo
    /// library: a bag-coloured block on blue.
    static func sample() -> Data? {
        let w = 400, h = 300
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        ctx.setFillColor(red: 0.16, green: 0.45, blue: 0.85, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.setFillColor(red: 0.95, green: 0.62, blue: 0.18, alpha: 1)
        ctx.fill(CGRect(x: 110, y: 70, width: 180, height: 160))
        return ctx.makeImage().flatMap(encode)
    }
}

/// Photos of the packed bag — his pre-trip idea 11 (2 Oct 2026): take one (iPhone)
/// or choose one, see it large, remove it. Kept with the trip, so the way home can be
/// packed from them. Up to three since the field test (3 Oct 2026): "maybe up to
/// three, because sometimes you would like a photo from different angles."
struct BagPhotoRow: View {
    let tripId: String
    let bag: String
    let n: Int
    @EnvironmentObject var model: LibraryModel
    @State private var picked: PhotosPickerItem?
    @State private var camera = false
    @State private var large: Shown?

    var body: some View {
        let shots = model.library.bagPhotos(tripId: tripId, bag: bag).compactMap { p in
            JPEG.image(dataURL: p.data).map { Shot(id: p.id, image: $0) }
        }
        // As stored: a photo still on its way from the other device takes its place too.
        let full = model.library.bagPhotoIds(tripId: tripId, bag: bag).count >= BAG_PHOTOS_MAX
        VStack(alignment: .leading, spacing: 10) {
            if !shots.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(Array(shots.enumerated()), id: \.element.id) { k, shot in
                        VStack(spacing: 2) {
                            Button { large = Shown(start: k) } label: {
                                Image(decorative: shot.image, scale: 1).resizable().scaledToFill()
                                    .frame(width: 80, height: 80).clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain).focusEffectDisabled()
                            .accessibilityIdentifier("bag-\(n)-photo-thumb-\(k)")
                            .accessibilityLabel("Photo \(k + 1) of the packed bag")
                            Button("Remove") {
                                let t = tripId, b = bag, id = shot.id
                                model.change { _ = $0.removeBagPhoto(tripId: t, bag: b, photoId: id) }
                            }
                            .buttonStyle(.plain).focusEffectDisabled()
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.muted)
                            .frame(minWidth: 80, minHeight: 34).contentShape(Rectangle())
                            .accessibilityIdentifier("bag-\(n)-photo-remove-\(k)")
                        }
                    }
                }
                .sheet(item: $large) { BigPhoto(images: shots.map(\.image), start: $0.start) }
            }
            if full {
                // No fourth: one has to go first, and it says so rather than hiding the way silently.
                Text("Three photos \u{2014} remove one to add another")
                    .font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("bag-\(n)-photo-full")
            } else {
                HStack(spacing: 10) {
                    if AMSPackingApp.testing {
                        pill(shots.isEmpty ? "Photo of the packed bag" : "Another photo", id: "bag-\(n)-photo") { keep(JPEG.sample()) }
                    } else {
                        #if os(iOS)
                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                            pill(shots.isEmpty ? "Take a photo" : "Take another", id: "bag-\(n)-photo") { camera = true }
                        }
                        #endif
                        PhotosPicker(selection: $picked, matching: .images) {
                            pillLabel(shots.isEmpty ? "Choose a photo" : "Choose another")
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("bag-\(n)-photo-pick")
                    }
                }
            }
        }
        .onChange(of: picked) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) { keep(JPEG.make(from: data)) }
                picked = nil
            }
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $camera) {
            CameraView { data in
                camera = false
                keep(data.flatMap { JPEG.make(from: $0) })
            }
            .ignoresSafeArea()
        }
        #endif
    }

    private struct Shot { let id: String; let image: CGImage }
    private struct Shown: Identifiable { let start: Int; var id: Int { start } }

    private func keep(_ jpeg: Data?) {
        guard let jpeg else { return }
        let t = tripId, b = bag
        model.change { _ = $0.addBagPhoto(tripId: t, bag: b, jpeg: jpeg) }
    }

    private func pill(_ title: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { pillLabel(title) }
            .buttonStyle(.plain).focusEffectDisabled()
            .accessibilityIdentifier(id)
    }

    private func pillLabel(_ title: String) -> some View {
        Text(title).font(.system(size: 15, weight: .bold)).foregroundStyle(AppSection.events.color)
            .padding(.horizontal, 12).frame(minHeight: 38)
            .overlay(Capsule().stroke(AppSection.events.color, lineWidth: 1.4))
            .contentShape(Capsule())
    }
}

/// The photos, as large as the screen allows — one at a time, Next (or a swipe on the
/// iPhone) for the next angle. A caption, when given, says whose photo it is (the way
/// home shows every bag's).
struct BigPhoto: View {
    let images: [CGImage]
    var captions: [String] = []
    @State private var at: Int
    @Environment(\.dismiss) private var dismiss

    init(images: [CGImage], captions: [String] = [], start: Int = 0) {
        self.images = images
        self.captions = captions
        _at = State(initialValue: min(max(0, start), max(0, images.count - 1)))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    if captions.indices.contains(at), !captions[at].isEmpty {
                        Text(captions[at]).font(.system(size: 17, weight: .heavy)).foregroundStyle(AppSection.events.color)
                            .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("bag-photo-caption")
                    }
                    if images.count > 1 {
                        Text("\(at + 1) of \(images.count)")
                            .font(.system(size: 15, weight: .bold).monospacedDigit()).foregroundStyle(Theme.muted)
                            .accessibilityIdentifier("bag-photo-count")
                    }
                }
                Spacer()
                if images.count > 1 {
                    Button("Next") { step(1) }
                        .buttonStyle(HeaderButtonStyle(tint: AppSection.events.color, filled: false)).focusEffectDisabled()
                        .font(.system(size: 17, weight: .bold))
                        .accessibilityIdentifier("bag-photo-next")
                }
                Button("Done") { dismiss() }
                    .buttonStyle(HeaderButtonStyle(tint: AppSection.events.color, filled: true)).focusEffectDisabled()
                    .font(.system(size: 17, weight: .bold))
                    .keyboardShortcut(.cancelAction)            // Escape closes it (the spec pass, 5 Oct 2026)
                    .accessibilityIdentifier("bag-photo-done")
            }
            .padding(16)
            if images.indices.contains(at) {
                Image(decorative: images[at], scale: 1).resizable().scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 8).padding(.bottom, 16)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 30).onEnded { drag in
                        guard abs(drag.translation.width) > abs(drag.translation.height) else { return }
                        step(drag.translation.width < 0 ? 1 : -1)
                    })
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 600)
        #endif
    }

    /// Round and round: after the last comes the first again.
    private func step(_ by: Int) {
        guard images.count > 1 else { return }
        at = (at + by + images.count) % images.count
    }
}

#if os(iOS)
/// The iPhone's camera, for the packed bag.
struct CameraView: UIViewControllerRepresentable {
    let done: (Data?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(done: done) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let done: (Data?) -> Void
        init(done: @escaping (Data?) -> Void) { self.done = done }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            done((info[.originalImage] as? UIImage)?.jpegData(compressionQuality: 0.9))
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { done(nil) }
    }
}
#endif
