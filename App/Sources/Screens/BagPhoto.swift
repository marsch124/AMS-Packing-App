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
    /// Its ids start so: "bag-<n>" on the Bags card, "day-photo-<n>" in the Packing day (0.79).
    var prefix: String? = nil
    @EnvironmentObject var model: LibraryModel
    @State private var large: Shown?

    var body: some View {
        let shots = model.library.bagPhotos(tripId: tripId, bag: bag).compactMap { p in
            JPEG.image(dataURL: p.data).map { Shot(id: p.id, image: $0) }
        }
        // As stored: a photo still on its way from the other device takes its place too.
        let full = model.library.bagPhotoIds(tripId: tripId, bag: bag).count >= BAG_PHOTOS_MAX
        let p = prefix ?? "bag-\(n)"
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
                            .accessibilityIdentifier("\(p)-photo-thumb-\(k)")
                            .accessibilityLabel("Photo \(k + 1) of the packed bag")
                            Button("Remove") {
                                let t = tripId, b = bag, id = shot.id
                                model.change { _ = $0.removeBagPhoto(tripId: t, bag: b, photoId: id) }
                            }
                            .buttonStyle(.plain).focusEffectDisabled()
                            .font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.muted)
                            .frame(minWidth: 80, minHeight: 34).contentShape(Rectangle())
                            .accessibilityIdentifier("\(p)-photo-remove-\(k)")
                        }
                    }
                }
                .sheet(item: $large) { BigPhoto(images: shots.map(\.image), start: $0.start) }
            }
            if full {
                // No fourth: one has to go first, and it says so rather than hiding the way silently.
                Text("Three photos \u{2014} remove one to add another")
                    .font(.system(.subheadline)).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("\(p)-photo-full")
            } else {
                PhotoTakers(id: "\(p)-photo", testTitle: shots.isEmpty ? "Photo of the packed bag" : "Another photo",
                            take: shots.isEmpty ? "Take a photo" : "Take another",
                            choose: shots.isEmpty ? "Choose a photo" : "Choose another") { keep($0) }
            }
        }
    }

    private struct Shot { let id: String; let image: CGImage }
    private struct Shown: Identifiable { let start: Int; var id: Int { start } }

    private func keep(_ jpeg: Data?) {
        guard let jpeg else { return }
        let t = tripId, b = bag
        model.change { _ = $0.addBagPhoto(tripId: t, bag: b, jpeg: jpeg) }
    }

}

/// The ways to take a photo (0.79: one place for a bag's own photos and the Packing day's photo
/// of all the bags): on the iPhone "Take a photo" when it has a camera (`id`) and "Choose a
/// photo" (`<id>-pick`, the photo library); on the Mac only Choose; under the UI tests ONE pill,
/// `testTitle` (`id`), that keeps a drawn picture — no test can work a camera or a library.
/// `keep` gets the JPEG the app keeps (at most 1600 on the long side), or nil.
struct PhotoTakers: View {
    let id: String
    let testTitle: String
    var take = "Take a photo"
    var choose = "Choose a photo"
    /// The pills' colour: a trip's blue, or (a thing's page, 0.90) Care's orange.
    var tint: Color = AppSection.events.color
    let keep: (Data?) -> Void
    @State private var picked: PhotosPickerItem?
    @State private var camera = false

    var body: some View {
        HStack(spacing: 10) {
            if AMSPackingApp.testing {
                pill(testTitle, id: id) { keep(JPEG.sample()) }
            } else {
                #if os(iOS)
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    pill(take, id: id) { camera = true }
                }
                #endif
                PhotosPicker(selection: $picked, matching: .images) { pillLabel(choose) }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("\(id)-pick")
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

    private func pill(_ title: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { pillLabel(title) }
            .buttonStyle(.plain).focusEffectDisabled()
            .accessibilityIdentifier(id)
    }

    private func pillLabel(_ title: String) -> some View {
        Text(title).font(.system(.subheadline, weight: .semibold)).foregroundStyle(tint)
            .padding(.horizontal, 12).frame(minHeight: 38)
            .overlay(Capsule().stroke(tint, lineWidth: 1.4))
            .contentShape(Capsule())
    }
}

/// The photos, as large as the screen allows — one at a time, Next (or a swipe on the
/// iPhone) for the next angle. A caption, when given, says whose photo it is (the way
/// home shows every bag's).
struct BigPhoto: View {
    let images: [CGImage]
    var captions: [String] = []
    /// The caption's and buttons' colour: a trip's blue, or (a thing's photos, 0.90) Care's orange.
    var tint: Color = AppSection.events.color
    @State private var at: Int
    @Environment(\.dismiss) private var dismiss

    init(images: [CGImage], captions: [String] = [], start: Int = 0, tint: Color = AppSection.events.color) {
        self.images = images
        self.captions = captions
        self.tint = tint
        _at = State(initialValue: min(max(0, start), max(0, images.count - 1)))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    if captions.indices.contains(at), !captions[at].isEmpty {
                        Text(captions[at]).font(.system(.body, weight: .semibold)).foregroundStyle(tint)
                            .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("bag-photo-caption")
                    }
                    if images.count > 1 {
                        Text("\(at + 1) of \(images.count)")
                            .font(.system(.subheadline, weight: .semibold).monospacedDigit()).foregroundStyle(Theme.muted)
                            .accessibilityIdentifier("bag-photo-count")
                    }
                }
                Spacer()
                if images.count > 1 {
                    Button("Next") { step(1) }
                        .buttonStyle(HeaderButtonStyle(tint: tint, filled: false)).focusEffectDisabled()
                        .font(.system(.body, weight: .semibold))
                        .accessibilityIdentifier("bag-photo-next")
                }
                Button("Done") { dismiss() }
                    .buttonStyle(HeaderButtonStyle(tint: tint, filled: true)).focusEffectDisabled()
                    .font(.system(.body, weight: .semibold))
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

/// Small pictures for rows and pages, made once per photo and size and kept while the app runs:
/// a photo record never changes (a new picture is a new record), and decoding a 1600-point
/// JPEG on every drawing of a list would be felt (0.90).
enum PhotoThumbs {
    private static let made = NSCache<NSString, CGImage>()

    /// The photo at most `side` points on its long side (three pixels a point), or nil while
    /// it has no picture (still on its way from the other device).
    static func image(_ photo: PhotoRecord, side: CGFloat) -> CGImage? {
        let key = "\(photo.id)@\(Int(side))" as NSString
        if let hit = made.object(forKey: key) { return hit }
        guard let comma = photo.data.firstIndex(of: ","),
              let data = Data(base64Encoded: String(photo.data[photo.data.index(after: comma)...])),
              let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                        kCGImageSourceThumbnailMaxPixelSize: Int(side * 3),
                                        kCGImageSourceCreateThumbnailWithTransform: true]
        guard let small = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        made.setObject(small, forKey: key)
        return small
    }
}

/// Photos of a THING on its page (0.90 — his ask of 19 Oct 2026: "A photo or two for each item"),
/// right under Notes: how it looks, so it is found at a glance. Two at most, the thing's own
/// photos (`Library.addThingPhoto`) — for a bag the same two as its page's photos of the bag.
/// Taken as every photo is (`PhotoTakers`: Take a photo on the iPhone, Choose a photo on both),
/// kept the moment they are taken (Cancel does not take one back — Remove does); a tap shows
/// it large; Remove asks first.
struct ThingPhotos: View {
    let thingId: String
    @EnvironmentObject var model: LibraryModel
    @State private var large: Int?
    /// The photo whose Remove was pressed: the question under the photos.
    @State private var removing: String?

    private static let side: CGFloat = 80

    var body: some View {
        let shots = model.library.thingPhotos(id: thingId).compactMap { p in
            PhotoThumbs.image(p, side: ThingPhotos.side).map { (p.id, $0) }
        }
        // As stored: a photo still on its way from the other device takes its place too.
        let full = !model.library.takesThingPhoto(id: thingId)
        let tint = AppSection.care.color
        VStack(alignment: .leading, spacing: 8) {
            if !shots.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(Array(shots.enumerated()), id: \.element.0) { k, shot in
                        VStack(spacing: 2) {
                            Button { large = k } label: {
                                Image(decorative: shot.1, scale: 1).resizable().scaledToFill()
                                    .frame(width: ThingPhotos.side, height: ThingPhotos.side)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 1))
                            }
                            .buttonStyle(.plain).focusEffectDisabled()
                            .accessibilityIdentifier("thing-photo-thumb-\(k)")
                            .accessibilityLabel("Photo \(k + 1) of the thing")
                            Button("Remove") { removing = shot.0 }
                                .buttonStyle(.plain).focusEffectDisabled()
                                .font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.muted)
                                .frame(minWidth: ThingPhotos.side, minHeight: 34).contentShape(Rectangle())
                                .accessibilityIdentifier("thing-photo-remove-\(k)")
                        }
                    }
                }
                .sheet(item: Binding(get: { large.map(Shown.init) }, set: { large = $0?.start })) { shown in
                    // Full size only when asked for: the page itself draws the small ones.
                    let name = model.library.items.first { $0.id == thingId }?.name ?? ""
                    let images = model.library.thingPhotos(id: thingId).compactMap { JPEG.image(dataURL: $0.data) }
                    BigPhoto(images: images, captions: images.map { _ in name }, start: shown.start, tint: tint)
                }
            }
            if let removing, let k = shots.firstIndex(where: { $0.0 == removing }) {
                askToRemove(photoId: removing, n: k, of: shots.count)
            }
            if full {
                // No third: one has to go first, and it says so rather than hiding the way silently.
                Text("Two photos \u{2014} remove one to add another")
                    .font(.system(.subheadline)).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("thing-photo-full")
            } else {
                PhotoTakers(id: "thing-photo", testTitle: shots.isEmpty ? "Photo of the thing" : "Another photo",
                            take: shots.isEmpty ? "Take a photo" : "Take another",
                            choose: shots.isEmpty ? "Choose a photo" : "Choose another", tint: tint) { jpeg in
                    guard let jpeg else { return }
                    let t = thingId
                    model.change { _ = $0.addThingPhoto(id: t, jpeg: jpeg) }
                }
            }
        }
        // The other device took the photo away while the question stood: no question left.
        .onChange(of: shots.map(\.0)) { _, ids in if let r = removing, !ids.contains(r) { removing = nil } }
    }

    /// Remove asks first (his ask, 19 Oct 2026: a photo is gone from every device once removed):
    /// Keep it, and the red Remove photo last.
    private func askToRemove(photoId: String, n: Int, of count: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(count > 1 ? "Remove photo \(n + 1)?" : "Remove the photo?")
                .font(.system(.callout, weight: .semibold)).foregroundStyle(Theme.ink)
                .accessibilityIdentifier("thing-photo-remove-ask")
            HStack {
                Button("Keep it") { removing = nil }
                    .buttonStyle(.plain).focusEffectDisabled()
                    .font(.system(.callout, weight: .semibold)).foregroundStyle(Theme.ink)
                    .frame(minHeight: Metrics.compact).contentShape(Rectangle())
                    .accessibilityIdentifier("thing-photo-remove-no")
                Spacer()
                Button {
                    let t = thingId
                    removing = nil
                    model.change { _ = $0.removeThingPhoto(id: t, photoId: photoId) }
                } label: {
                    Text("Remove photo").font(.system(.callout, weight: .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 12).frame(minHeight: Metrics.compact)
                        .background(Capsule().fill(AppSection.actions.color))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("thing-photo-remove-yes")
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppSection.actions.color, lineWidth: 1))
    }

    private struct Shown: Identifiable { let start: Int; var id: Int { start } }
}

/// A thing's first photo, small, at the END of its row in Your things and in Search (0.90) —
/// at the end, so the names still line up A–Z whether a thing has a photo or not. Nothing
/// when it has none. Its own element beside the row's button (a button folds what it holds
/// into itself), so a tap on it opens the thing as the row does.
struct ThingPhotoThumb: View {
    let item: Item
    let id: String
    let open: () -> Void
    @EnvironmentObject var model: LibraryModel

    #if os(macOS)
    static let side: CGFloat = 20
    #else
    static let side: CGFloat = 24
    #endif

    var body: some View {
        let refs = photoRefs(item)
        if !refs.isEmpty,
           let photo = refs.lazy.compactMap({ ref in model.library.photos.first { $0.id == ref } }).first,
           let small = PhotoThumbs.image(photo, side: ThingPhotoThumb.side) {
            Image(decorative: small, scale: 1).resizable().scaledToFill()
                .frame(width: ThingPhotoThumb.side, height: ThingPhotoThumb.side)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Theme.line, lineWidth: 1))
                .contentShape(Rectangle())
                .onTapGesture(perform: open)
                .accessibilityElement()
                .accessibilityAddTraits(.isImage)
                .accessibilityLabel("Photo of \(item.name)")
                .accessibilityIdentifier(id)
        }
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
