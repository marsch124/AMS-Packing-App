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

/// A photo of the packed bag — his pre-trip idea 11 (2 Oct 2026): take one (iPhone)
/// or choose one, see it large, replace or remove it. Kept with the trip, so the way
/// home can be packed from it.
struct BagPhotoRow: View {
    let tripId: String
    let bag: String
    let n: Int
    @EnvironmentObject var model: LibraryModel
    @State private var picked: PhotosPickerItem?
    @State private var camera = false
    @State private var large = false

    var body: some View {
        let photo = model.library.bagPhoto(tripId: tripId, bag: bag)
        let image = photo.flatMap { JPEG.image(dataURL: $0.data) }
        HStack(spacing: 10) {
            if let image {
                Button { large = true } label: {
                    Image(decorative: image, scale: 1).resizable().scaledToFill()
                        .frame(width: 56, height: 56).clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .accessibilityIdentifier("bag-\(n)-photo-thumb")
                .accessibilityLabel("The photo of the packed bag")
                .sheet(isPresented: $large) { BigPhoto(image: image) }
            }
            if AMSPackingApp.testing {
                pill(image == nil ? "Photo of the packed bag" : "New photo", id: "bag-\(n)-photo") { keep(JPEG.sample()) }
            } else {
                #if os(iOS)
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    pill(image == nil ? "Take a photo" : "New photo", id: "bag-\(n)-photo") { camera = true }
                }
                #endif
                PhotosPicker(selection: $picked, matching: .images) {
                    pillLabel(image == nil ? "Choose a photo" : "Choose another")
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("bag-\(n)-photo-pick")
            }
            Spacer(minLength: 4)
            if image != nil {
                Button("Remove") {
                    let t = tripId, b = bag
                    model.change { _ = $0.setBagPhoto(tripId: t, bag: b, jpeg: nil) }
                }
                .buttonStyle(.plain).focusEffectDisabled()
                .font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.muted)
                .accessibilityIdentifier("bag-\(n)-photo-remove")
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

    private func keep(_ jpeg: Data?) {
        guard let jpeg else { return }
        let t = tripId, b = bag
        model.change { _ = $0.setBagPhoto(tripId: t, bag: b, jpeg: jpeg) }
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

/// The photo, as large as the screen allows.
struct BigPhoto: View {
    let image: CGImage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(HeaderButtonStyle(tint: AppSection.events.color, filled: true)).focusEffectDisabled()
                    .font(.system(size: 17, weight: .bold))
                    .accessibilityIdentifier("bag-photo-done")
            }
            .padding(16)
            Image(decorative: image, scale: 1).resizable().scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 8).padding(.bottom, 16)
        }
        .background(Theme.bg.ignoresSafeArea())
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 600)
        #endif
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
