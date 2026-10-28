import Foundation
import PackingCore

// Grab lists by holding the app icon (0.86 — his yes, 15 Oct 2026: "Yes - grab lists by
// holding the app icon"). Hold the Packing icon on the iPhone's Home Screen and tap
// "Outdoor bike": the app opens straight on that list, ready to tick. iOS shows at most
// four such entries under an app's icon, so which four, and in what order, is decided here.
//
// The build's decision (spec 02 §13b): the four he OPENED most recently on this device —
// on Home, from Grab Lists, the Action button's menu, a Shortcut or the icon itself — shown
// in his Home order, so an entry keeps its place under the icon while he uses them. Before
// he has opened four, the first ones on Home fill the rest. The openings are this device's
// own (a list opened on the Mac says nothing about the iPhone's icon) and never synced.

/// How many entries iOS shows under an app's icon (`UIApplicationShortcutItem`s).
public let GRAB_QUICK_ACTIONS = 4
/// How many of them are grab lists since New Thing came first under the icon (0.105 — his words of 28 Oct 2026: "On
/// the iPhone: 'New thing' also goes into the menu when you hold the app icon"): iOS still shows four, so the three
/// grab lists opened most recently go with it — the fourth would be cut off.
public let GRAB_QUICK_ACTIONS_BESIDE_NEW_THING = GRAB_QUICK_ACTIONS - 1
/// How many openings a device remembers — more than four, so a list deleted (or taken off
/// every device) leaves the next most recent one to step up.
public let GRAB_OPENED_KEEP = 16

extension Library {
    /// Every grab list in Home's order: Home's (up to eight) as he arranged them, then the
    /// ones waiting in Grab Lists, in `allGrabLists()` order. What Shortcuts offers by name,
    /// the order of the entries under the icon, and the Mac's Dock menu.
    public func grabListsInHomeOrder() -> [GrabDefinition] {
        let home = homeGrabLists()
        let onHome = Set(home.map(\.id))
        return home + allGrabLists().filter { !onHome.contains($0.id) }
    }

    /// The grab lists under the app icon (at most `count`): the ones in `opened` — this
    /// device's openings, most recent first — that still exist, the most recent `count` of
    /// them; while fewer than `count` were opened, the first ones in Home's order fill the
    /// rest. Shown in Home's order, never in the order they were opened.
    public func quickActionGrabLists(opened: [String], count: Int = GRAB_QUICK_ACTIONS) -> [GrabDefinition] {
        guard count > 0 else { return [] }
        let order = grabListsInHomeOrder()
        let known = Set(order.map(\.id))
        var chosen: [String] = []
        for id in opened where known.contains(id) && !chosen.contains(id) {
            chosen.append(id)
            if chosen.count == count { break }
        }
        for d in order where chosen.count < count && !chosen.contains(d.id) {
            chosen.append(d.id)
        }
        let picked = Set(chosen)
        return order.filter { picked.contains($0.id) }
    }
}

/// This device's record of which grab lists were opened, most recent first.
public enum GrabOpenings {
    /// The record after `id` was opened: it first, every id once, at most `GRAB_OPENED_KEEP`.
    public static func opened(_ id: String, after record: [String]) -> [String] {
        guard !id.isEmpty else { return record }
        return Array(([id] + record.filter { $0 != id }).prefix(GRAB_OPENED_KEEP))
    }

    /// The title an entry carries — what Shortcuts calls the list too: its title ("Outdoor
    /// bike"), or the word on its tile when it has no title.
    public static func title(_ list: GrabDefinition) -> String {
        list.title.isEmpty ? list.label : list.title
    }
}
