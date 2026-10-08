import SwiftUI
import PackingCore
import PackingLibrary

/// "Travel, Hiking · Chest of drawers" — a thing's templates and where it is kept, on its
/// row in Your things. The TEMPLATE names are in the Templates tab's violet, made readable
/// day and night (`readableHex`, as his "When" colours are), so the list pops; the place
/// stays muted. His ask, testing 0.69 (8 Oct 2026): "Let's make the Templates text on each
/// row Lilac (the same color as the Templates) so that the list pops a bit." On no
/// template stays in Care's orange, as before.
struct ThingDetailLine: View {
    let templates: [String]
    let place: String
    @Environment(\.colorScheme) private var scheme

    /// The Templates tab's violet as words on this screen.
    static func violet(_ scheme: ColorScheme) -> Color {
        Color(hexString: readableHex("#7c5cd6", dark: scheme == .dark))
    }

    var body: some View {
        let lists = templates.isEmpty
            ? Text("On no template").foregroundStyle(AppSection.care.color)
            : Text(templates.joined(separator: ", ")).foregroundStyle(ThingDetailLine.violet(scheme))
        let kept = jsTrim(place).isEmpty ? Text("") : Text(" · \(place)").foregroundStyle(Theme.muted)
        (lists + kept)
            .font(.system(.footnote))
            .lineLimit(1).truncationMode(.middle)
    }
}
