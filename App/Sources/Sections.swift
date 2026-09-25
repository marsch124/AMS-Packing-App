import SwiftUI
import PackingCore

/// The six sections of the app — the same six, in the same order and the same
/// colours, as the web app's tab bar. `rawValue` is what the accessibility
/// identifiers are built from ("tab-home", "screen-home"), so it never changes
/// when a label is reworded.
enum AppSection: String, CaseIterable, Identifiable {
    case home, events, templates, care, actions, settings
    var id: String { rawValue }

    var label: String {
        switch self {
        case .home: return "Home"
        // The screen says Trips, so the tab says Trips. (The identifier stays
        // "tab-events" — it is built from the case name, not the label.)
        case .events: return "Trips"
        case .templates: return "Templates"
        case .care: return "Care"
        case .actions: return "Actions"
        case .settings: return "Settings"
        }
    }

    /// Home = blue, Events = green, Templates = violet, Care = orange,
    /// Actions = red, Settings = slate.
    var color: Color {
        switch self {
        case .home: return Color(hex: 0x2f6fe0)
        case .events: return Color(hex: 0x2f9e63)
        case .templates: return Color(hex: 0x7c5cd6)
        case .care: return Color(hex: 0xdd7324)
        case .actions: return Color(hex: 0xdc3d43)
        case .settings: return Color(hex: 0x64748b)
        }
    }

    /// The mark, drawn in a 24-unit box — the web app's own SVG drawings.
    var mark: Path {
        switch self {
        case .home:        // a suitcase
            var p = Path(roundedRect: CGRect(x: 4, y: 7.5, width: 16, height: 12.5), cornerRadius: 2.2)
            p.addPath(SVGPath.path("M9 7.5V5.6A1.6 1.6 0 0 1 10.6 4h2.8A1.6 1.6 0 0 1 15 5.6V7.5M9.5 11v5.5M14.5 11v5.5"))
            return p
        case .events:      // a calendar
            var p = Path(roundedRect: CGRect(x: 3.5, y: 5, width: 17, height: 15), cornerRadius: 2)
            p.addPath(SVGPath.path("M3.5 9.5h17M8 3.5v3M16 3.5v3"))
            return p
        case .templates:   // a list
            return SVGPath.path("M8 6h11M8 12h11M8 18h11M4 6h.01M4 12h.01M4 18h.01")
        case .care:        // a spanner
            return SVGPath.path("M14.7 6.3a4 4 0 0 0-5.2 5.1L4 16.9 7.1 20l5.5-5.5a4 4 0 0 0 5.1-5.2l-2.4 2.4-2.1-.6-.6-2.1Z")
        case .actions:     // a ticked box
            var p = Path(roundedRect: CGRect(x: 4, y: 4, width: 16, height: 16), cornerRadius: 2.5)
            p.addPath(SVGPath.path("M8.5 12.2l2.4 2.4 4.6-5"))
            return p
        case .settings:    // a nut
            var p = SVGPath.path("M12 2.5L21.2 7.25L21.2 16.75L12 21.5L2.8 16.75L2.8 7.25Z")
            p.addEllipse(in: CGRect(x: 8, y: 8, width: 8, height: 8))
            return p
        }
    }
}

/// One of the section marks at any size, stroked in the colour around it.
struct SectionMark: View {
    let section: AppSection
    var size: Double = 24
    var weight: Double = 1.9

    var body: some View {
        let k = size / 24
        section.mark
            .applying(CGAffineTransform(scaleX: k, y: k))
            .stroke(style: StrokeStyle(lineWidth: weight * k, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
    }
}

/// "GA · GOAL ACTIVITY" — his own code for a group, then the words in capitals.
/// The trip builder and the shelves on Your lists both say it this way, from here,
/// so the two can never drift apart.
func groupHeading(_ id: String, _ label: String) -> String {
    let code = jsTrim(id)
    return code.isEmpty ? label.uppercased() : "\(code) · \(label.uppercased())"
}
