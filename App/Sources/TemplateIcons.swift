import SwiftUI
import PackingLibrary

/// The template icons — 132 of my own, drawn in the app's style (one stroke, round
/// ends, a 24-point box). The first 50: he saw them on a sample sheet in day and
/// night mode and said (2 Oct 2026): "Your suggestions are fine. Please implement."
/// 40 more in 0.74 (his "Add approximately 40 new icons, specifically one that is
/// related to 'On the beach'", 12 Oct 2026), the weekend bag in 0.78, and 41 more in 0.92
/// (his "Could we add some icons again. Love the one we have.", 19 Oct 2026). No stock
/// art, no emoji (his rule).
///
/// The drawings live with the model (`PackingLibrary/TemplateIconCatalog.swift`) so
/// its tests can hold every one to the rules; this is the app's door to them — the
/// same `all`, `icon(_:)` and `Icon` (key, label, path) as before 0.74.
enum TemplateIcons {
    typealias Icon = TemplateIcon

    /// Every icon, in the picker's order (grouped: travel, outdoors, sport, beach, city, everyday).
    static var all: [Icon] { TemplateIconCatalog.all }

    /// The picker's headings with their icons.
    static var grouped: [(group: TemplateIconGroup, icons: [Icon])] { TemplateIconCatalog.grouped }

    /// The headings with the icons a search finds — by label or by hidden other words (0.91);
    /// every icon for an empty search.
    static func grouped(matching query: String) -> [(group: TemplateIconGroup, icons: [Icon])] {
        TemplateIconCatalog.grouped(matching: query)
    }

    static func icon(_ key: String?) -> Icon? { TemplateIconCatalog.icon(key) }
}
