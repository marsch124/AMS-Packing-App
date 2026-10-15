import SwiftUI
import PackingCore
import PackingLibrary

// Grab lists by holding the app icon (0.86 — his yes, 15 Oct 2026: "Yes - grab lists by
// holding the app icon"). The idea as it was put to him: "hold the AMS Packing icon on your
// iPhone and tap Outdoor bike or Indoor swim — straight into that list without opening the
// app first."
//
// iPhone: up to four entries under the icon on the Home Screen (`UIApplicationShortcutItem`)
// — the four grab lists opened most recently on this iPhone, in his Home order
// (`Library.quickActionGrabLists`); each wears its list's own drawing (assets `grab-<icon>`,
// or `grab-initial-<hex>` for a list of his own that wears its initial). Tapping one opens
// the app on that list through the same request Siri's "Open a grab list" sets
// (`LibraryModel.grabToOpen`). Mac: the Dock icon's menu lists every grab list.
// Spec 02 §13b.

@MainActor
enum GrabQuickActions {
    /// What every entry under the icon's kind starts with: "com.schabbauer.AMSPacking.grab.<list
    /// id>" — the id also rides in `userInfo["id"]`. The kind is what the Home Screen gives the
    /// entry as its accessibility identifier, so a test finds an entry by its list, not its words.
    static let type = "com.schabbauer.AMSPacking.grab"
    /// This device's openings, most recent first (`GrabOpenings`) — never synced.
    static let openedKey = "ams.grab.opened"

    /// Open the grab list an entry under the icon, or a Dock menu item, names: the request
    /// Siri's "Open a grab list" sets (RootView switches to Home, Home opens the list). A list
    /// that no longer exists opens nothing.
    @discardableResult
    static func open(id: String) -> Bool {
        let model = LibraryModel.shared
        guard model.library.allGrabLists().contains(where: { $0.id == id }) else { return false }
        model.grabToOpen = id
        return true
    }

    #if os(iOS)
    /// This device's openings, most recent first.
    static var opened: [String] { UserDefaults.standard.stringArray(forKey: openedKey) ?? [] }

    /// A grab list was opened here — from Home, Grab Lists, the Action button's menu, a
    /// Shortcut or the icon itself: it goes first in the record, and the entries follow.
    static func didOpen(_ id: String) {
        UserDefaults.standard.set(GrabOpenings.opened(id, after: opened), forKey: openedKey)
        refresh(LibraryModel.shared.library)
    }

    /// The entry for one grab list: its title, its drawing, its id.
    static func item(_ list: GrabDefinition) -> UIApplicationShortcutItem {
        UIApplicationShortcutItem(type: "\(type).\(list.id)", localizedTitle: GrabOpenings.title(list), localizedSubtitle: nil,
                                  icon: UIApplicationShortcutIcon(templateImageName: iconName(list)),
                                  userInfo: ["id": list.id as NSString])
    }

    /// What was last handed to the system, so an unchanged set is not handed over again.
    private static var lastHanded: [String]?

    /// Put the entries under the icon right: after every settled change of the library (a
    /// list added, renamed, removed or moved on Home — here or on the other device), when a
    /// list is opened, and when the app goes to the background. The system keeps them
    /// while the app is not running, so they are there at a cold start.
    static func refresh(_ library: Library) {
        let lists = library.quickActionGrabLists(opened: opened)
        let said = lists.map { "\($0.id)|\(GrabOpenings.title($0))|\(iconName($0))" }
        guard said != lastHanded else { return }
        lastHanded = said
        UIApplication.shared.shortcutItems = lists.map(item)
    }

    /// The drawing an entry wears — the one on the list's tile (`GrabDoodle`): its doodle,
    /// or, for a list of his own with no doodle, its initial. An initial the app has no
    /// drawing for, the Home tab's suitcase. Asset catalog, template images: drawn by
    /// `tools/grab-icons.sh` from the very same path data.
    static func iconName(_ list: GrabDefinition) -> String {
        let name: String
        if list.icon.isEmpty, let first = list.label.first {
            let initial = String(first).uppercased()
            let scalars = initial.unicodeScalars
            name = scalars.count == 1 ? "grab-initial-\(String(scalars.first!.value, radix: 16, uppercase: true))" : "grab-list"
        } else {
            // GrabDoodle draws the runner for a name it has no drawing for; so does the entry.
            name = "grab-" + (GRAB_ICONS.contains(list.icon) ? list.icon : "run")
        }
        return UIImage(named: name) != nil ? name : "grab-list"
    }

    /// An entry tapped under the icon — at a cold start (`PackingAppDelegate`) or while the
    /// app runs (`PackingSceneDelegate`). Not one of ours, or its list is gone: false.
    @discardableResult
    static func perform(_ item: UIApplicationShortcutItem) -> Bool {
        guard item.type.hasPrefix(type + "."),
              let id = item.userInfo?["id"] as? String ?? Optional(String(item.type.dropFirst(type.count + 1))) else { return false }
        return open(id: id)
    }

    /// UI tests only (`-quickAction <title>`): the entry with that title, as if he had tapped
    /// it under the icon to START the app — taken from the entries the app hands the system,
    /// so a list that is not among the four cannot be opened this way either.
    static func playedAtLaunch() -> UIApplicationShortcutItem? {
        let args = ProcessInfo.processInfo.arguments
        guard AMSPackingApp.testing, let n = args.firstIndex(of: "-quickAction"), n + 1 < args.count else { return nil }
        refresh(LibraryModel.shared.library)
        return UIApplication.shared.shortcutItems?.first { $0.localizedTitle == args[n + 1] }
    }

    /// UI tests only (`-quickActionOnReturn <title>`, played as the app comes back to the
    /// front): the entry with that title, handed to the scene's delegate as iOS hands it
    /// when he taps it while the app runs in the background.
    static func playWhileRunning(title: String) {
        guard let item = UIApplication.shared.shortcutItems?.first(where: { $0.localizedTitle == title }),
              let scene = UIApplication.shared.connectedScenes.first(where: { $0 is UIWindowScene }) as? UIWindowScene,
              let delegate = scene.delegate as? UIWindowSceneDelegate else { return }
        delegate.windowScene?(scene, performActionFor: item) { _ in }
    }
    #else
    static func didOpen(_ id: String) {}
    static func refresh(_ library: Library) {}

    /// The main window's `openWindow`, kept by RootView: a Dock menu choice made while no
    /// window of the app is open opens one first.
    static var openMainWindow: (() -> Void)?
    /// How many main windows are showing (RootView counts itself in and out).
    static var mainWindows = 0

    /// A grab list chosen in the Dock icon's menu: the app comes to the front — with a window
    /// if it had none — and the list opens on Home, as from Siri.
    static func openFromDock(_ id: String) {
        NSApp.activate()
        if mainWindows == 0 { openMainWindow?() }
        open(id: id)
    }

    /// UI tests only: the Dock menu's entry titled so, chosen — asked of the app's delegate
    /// and performed as the Dock does it. `-dockMenu <title>`: once the window is up;
    /// `-dockMenuWhenClosed <title>`: once its last main window has closed.
    static func playDockMenu(_ flag: String) {
        let args = ProcessInfo.processInfo.arguments
        guard AMSPackingApp.testing, let n = args.firstIndex(of: flag), n + 1 < args.count else { return }
        let title = args[n + 1]
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            guard let menu = NSApp.delegate?.applicationDockMenu?(NSApp),
                  let at = menu.items.firstIndex(where: { $0.title == title }) else { return }
            menu.performActionForItem(at: at)
        }
    }
    #endif
}

#if os(iOS)
/// The app's delegate on the iPhone — there only so that what he taps under the icon reaches
/// the app. SwiftUI makes it (`@UIApplicationDelegateAdaptor`) and keeps its own window.
final class PackingAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // A cold start from the icon: the entry comes with the scene, not to the scene's delegate.
        if let item = options.shortcutItem ?? GrabQuickActions.playedAtLaunch() { GrabQuickActions.perform(item) }
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = PackingSceneDelegate.self
        return configuration
    }
}

/// The scene's delegate: an entry tapped under the icon while the app is running (or waiting
/// in the background). SwiftUI makes it from the configuration above and sends it this.
final class PackingSceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        completionHandler(GrabQuickActions.perform(shortcutItem))
    }
}
#else
/// The app's delegate on the Mac — there only for the Dock icon's menu.
@MainActor
final class PackingMacDelegate: NSObject, NSApplicationDelegate {
    /// Right-click (or hold) the Dock icon while the app runs: every grab list, in Home's order,
    /// under a "Grab lists" heading. Choosing one opens it.
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let lists = LibraryModel.shared.library.grabListsInHomeOrder()
        guard !lists.isEmpty else { return nil }
        let menu = NSMenu()
        menu.addItem(.sectionHeader(title: "Grab lists"))
        for list in lists {
            let item = NSMenuItem(title: GrabOpenings.title(list), action: #selector(openGrab(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = list.id
            menu.addItem(item)
        }
        return menu
    }

    @objc private func openGrab(_ item: NSMenuItem) {
        guard let id = item.representedObject as? String else { return }
        GrabQuickActions.openFromDock(id)
    }
}
#endif
