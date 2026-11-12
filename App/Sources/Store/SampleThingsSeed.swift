import SwiftUI
import PackingLibrary

/// The five sample things (0.122 — his ask of 12 Nov 2026): added ONCE, by the iPhone only (the Mac gets
/// them through iCloud, so two devices never add them twice), when his library is open and holds none of
/// them. Settings ▸ "Remove the sample things" takes them all away again.
enum SampleThingsSeed {
    static let key = "ams.sampleThings.0122"

    @MainActor static func addOnceIfDue(_ model: LibraryModel) async {
        #if os(iOS)
        guard !AMSPackingApp.testing, !UserDefaults.standard.bool(forKey: key) else { return }
        // Wait (up to two minutes) for his library to open and iCloud's first exchange to settle.
        for _ in 0..<120 where model.state != .ready { try? await Task.sleep(for: .seconds(1)) }
        guard model.state == .ready else { return }
        try? await Task.sleep(for: .seconds(8))
        UserDefaults.standard.set(true, forKey: key)
        guard model.library.sampleThings().isEmpty else { return }
        model.change(named: "Add the sample things", undoable: false) { lib in
            lib.addSampleThings(pictures: SamplePictures.all)
        }
        #endif
    }
}

/// Settings: take the sample things away (asks first). Shown only while there are some.
struct RemoveSampleThings: View {
    @EnvironmentObject var model: LibraryModel
    @State private var asking = false

    var body: some View {
        let n = model.library.sampleThings().count
        if n > 0 {
            Button { asking = true } label: {
                Text("Remove the sample things (\(n))")
                    .font(.system(.body, weight: .semibold)).foregroundStyle(AppSection.actions.color)
                    .frame(maxWidth: .infinity, minHeight: Metrics.tap)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain).focusEffectDisabled()
            .padding(.top, 10)
            .accessibilityIdentifier("settings-remove-samples")
            .confirmationDialog("Remove the \(n) sample things?", isPresented: $asking, titleVisibility: .visible) {
                Button("Remove them", role: .destructive) {
                    model.change(named: "Remove the sample things") { lib in _ = lib.removeSampleThings() }
                }
                .accessibilityIdentifier("settings-remove-samples-yes")
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Sofa, Fridge, Cordless drill, Robot vacuum and Espresso machine, with their pictures. Your own things stay.")
            }
        }
    }
}
