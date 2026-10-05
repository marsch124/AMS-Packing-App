import SwiftUI
import PackingCore
import PackingLibrary

/// "Goes in the cabin", right on a trip's bag — field test 7.3/6.1 (3 Oct 2026):
/// their cabin bag was a name on the lines, not one of their bags, so there was
/// nowhere to say it goes on board, and the knife in it was never checked. Said
/// here, a name becomes a bag (and shows in Care → Bags too).
struct BagCabinRow: View {
    let bag: String
    let n: Int
    @EnvironmentObject var model: LibraryModel

    var body: some View {
        if bag != "Other" {
            Toggle(isOn: Binding(get: { model.library.isCabin(container: bag) },
                                 set: { on in model.change { _ = $0.setCabin(container: bag, on) } })) {
                Text("Goes in the cabin").font(.system(.subheadline, weight: .semibold)).foregroundStyle(Theme.ink)
            }
            .tint(AppSection.events.color)
            .accessibilityIdentifier("bag-\(n)-cabin")
        }
    }
}
