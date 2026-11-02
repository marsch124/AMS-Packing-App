import Foundation
import PackingCore

// A grab list's icon, chosen from the template icons (0.108) — his question, 2 Nov 2026:
// "Regarding grab lists: how do I change icons?" He could not: only the original Swim, Bike and
// Run wear drawings of their own (`GrabDoodle`), and a list he made wears its first letter. Now a
// list's page has Icon, with the same 132 drawings and the same search a template's page has.
//
// Kept where a list's look always was — its `icon`: in the `grab` row of an original list (the
// row the web app reads, which falls back to its own drawing for a name it does not know), in
// the library's `meta` for one of his own. No new field, so nothing new for iCloud. A template
// icon is stored as "icon:<key>": the template icons have a "swim", a "bike" and a "run" of
// their own, which must not be read as the doodles.
//
//   ""              his own list: its initial · an original list: its own doodle
//   "swim" … "run-sun"  the six doodles (`GRAB_ICONS`)
//   "icon:<key>"    a template icon (`TemplateIconCatalog`)

/// What a template icon's key is stored behind in a grab list's `icon`.
public let GRAB_TEMPLATE_ICON_PREFIX = "icon:"

extension Library {
    /// The template icon a grab list wears, when one was chosen for it; nil = its doodle or its
    /// initial (an icon this app does not know included).
    public static func grabTemplateIcon(_ icon: String) -> TemplateIcon? {
        guard icon.hasPrefix(GRAB_TEMPLATE_ICON_PREFIX) else { return nil }
        return TemplateIconCatalog.icon(String(icon.dropFirst(GRAB_TEMPLATE_ICON_PREFIX.count)))
    }

    /// A grab list's `icon` for a template icon: "icon:plane".
    public static func grabIcon(templateKey key: String) -> String { GRAB_TEMPLATE_ICON_PREFIX + key }

    /// Is this a look the app draws for a grab list — none, one of the six doodles, or a template
    /// icon it has? A list received from elsewhere with anything else gets the standard look.
    public static func isGrabIcon(_ icon: String) -> Bool {
        icon.isEmpty || GRAB_ICONS.contains(icon) || grabTemplateIcon(icon) != nil
    }

    /// Give a grab list another icon: a template icon ("icon:<key>"), one of the doodles, or ""
    /// — for an original list its own doodle again, for one of his own its initial. An original
    /// list's choice goes into its `grab` row (made now if the list was never changed, with the
    /// things it has); his own list's into its entry in `meta`. Its things, name and colour stay.
    /// False when there is no such list or the app cannot draw the icon.
    @discardableResult
    public mutating func setGrabListIcon(id: String, icon: String) -> Bool {
        guard Library.isGrabIcon(icon) else { return false }
        guard let at = GRAB_FACTORY.firstIndex(where: { $0.id == id }) else {
            guard var own = ownGrabLists().first(where: { $0.id == id }) else { return false }
            guard own.icon != icon else { return true }
            own.icon = icon
            return saveOwnGrabList(own)
        }
        let before = grabFromRows(shared).first { $0.id == id }
        // An original list as it came, given its own doodle: nothing to write.
        if before == nil, icon.isEmpty || icon == GRAB_FACTORY[at].icon { return true }
        let stored = icon == GRAB_FACTORY[at].icon ? "" : icon
        let items = before.map(\.items).flatMap { $0.isEmpty ? nil : $0 } ?? GrabLine.stored(GRAB_FACTORY[at].lines)
        var rows = grabToRows([GrabList(id: id, items: items, label: before?.label ?? "", icon: stored,
                                        tone: before?.tone ?? "")])
        guard !rows.isEmpty else { return false }
        rows[0].order = Double(at)   // the Home-row order, as the web app keeps it
        shared.removeAll { $0.kind == "grab" && $0.id == rows[0].id }
        shared.append(rows[0])
        return true
    }
}
