import SwiftUI
import PackingCore
import PackingLibrary

/// Which grab list this time? — field test 2.3 (3 Oct 2026): "change the app so that I
/// can get a menu and, from the Action button, choose what grab list I want this time."
/// The Action button's "Choose a grab list" opens the app here: every grab list as a
/// big tile (Home's eight first, then the rest); one tap and it is open, ready to tick.
struct GrabMenuScreen: View {
    @EnvironmentObject var model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    @State private var chosen: GrabDefinition?

    var body: some View {
        if let chosen {
            GrabScreen(listId: chosen.id).environmentObject(model)
        } else {
            let home = model.library.homeGrabLists()
            let rest = model.library.allGrabLists().filter { g in !home.contains { $0.id == g.id } }
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Which grab list?").font(.system(size: 24, weight: .heavy)).foregroundStyle(AppSection.home.color)
                    Spacer()
                    Button("Close") { dismiss() }
                        .buttonStyle(HeaderButtonStyle(tint: Theme.muted, filled: false)).focusEffectDisabled()
                        .font(.system(size: 17, weight: .semibold))
                        .accessibilityIdentifier("grab-menu-close")
                }
                ScrollView {
                    GrabButtons(lists: home + rest, prefix: "grab-menu") { chosen = $0 }
                }
            }
            .padding(16)
            .background(Theme.bg.ignoresSafeArea())
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("grab-menu")
            #if os(macOS)
            .frame(minWidth: 520, minHeight: 520)
            #endif
        }
    }
}
