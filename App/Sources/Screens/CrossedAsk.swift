import SwiftUI
import PackingCore
import PackingLibrary

// Warn instead of merge (0.102 — his decision of 26 Oct 2026, option B of spec 01 Open question 32;
// `SavesThatCross.swift`). A page's Done (Save) that changed a block iCloud keeps whole — a grab
// list, a template's head, what a kit holds, a list of Your choices — when the other device changed
// the same block since the page opened, does not write silently: it asks, as an Apple alert on the
// iPhone and on the Mac — "Changed on your iPhone meanwhile", what (one line), and two answers:
// Keep both (what each device added and took off, the merge of 0.95/0.97) or Keep mine (the page's
// version, whole). No third answer: the page's own Cancel is still there, behind the alert. The
// alert is UIKit's / AppKit's own, so its buttons carry identifiers for the tests
// (`crossed-both`, `crossed-mine`; the alert `crossed-ask`).

@MainActor
enum CrossedAsk {
    /// Ask it. `answer(true)` = Keep mine, `answer(false)` = Keep both — also when there is no window
    /// to ask in (the merge, as before 0.102).
    static func ask(title: String, what: String, answer: @escaping (Bool) -> Void) {
        #if os(iOS)
        guard let front = frontController() else { answer(false); return }
        let alert = UIAlertController(title: title, message: what, preferredStyle: .alert)
        let both = UIAlertAction(title: "Keep both", style: .default) { _ in answer(false) }
        let mine = UIAlertAction(title: "Keep mine", style: .default) { _ in answer(true) }
        both.accessibilityIdentifier = "crossed-both"
        mine.accessibilityIdentifier = "crossed-mine"
        alert.addAction(both)
        alert.addAction(mine)
        alert.preferredAction = both                       // the one that loses nothing
        alert.view.accessibilityIdentifier = "crossed-ask"
        front.present(alert, animated: true)
        #else
        guard let front = sheetInFront() else { answer(false); return }
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = what
        let both = alert.addButton(withTitle: "Keep both")   // first: Return
        let mine = alert.addButton(withTitle: "Keep mine")
        both.setAccessibilityIdentifier("crossed-both")
        mine.setAccessibilityIdentifier("crossed-mine")
        alert.window.setAccessibilityIdentifier("crossed-ask")
        alert.beginSheetModal(for: front) { reply in answer(reply == .alertSecondButtonReturn) }
        #endif
    }

    #if os(iOS)
    /// The controller on top — the page's sheet.
    private static func frontController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        var top = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
            ?? scene?.windows.first?.rootViewController
        while let up = top?.presentedViewController, !up.isBeingDismissed { top = up }
        return top
    }
    #else
    /// The sheet on top, in the window in front — where the page is.
    private static func sheetInFront() -> NSWindow? {
        let front = NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first { $0.isVisible }
        var window = front.map { $0.sheetParent ?? $0 }
        while let sheet = window?.attachedSheet { window = sheet }
        return window
    }
    #endif
}

extension LibraryModel {
    /// The question for these blocks, in this library's words.
    func askCrossed(_ blocks: [Block], answer: @escaping (Bool) -> Void) {
        CrossedAsk.ask(title: library.crossedTitle(thisDevice: SyncCard.device),
                       what: library.words(for: blocks), answer: answer)
    }
}

#if DEBUG
/// UI tests only (0.102): the other device's save of what a page holds, arriving while it is open
/// (`-otherDeviceOnOpen <page>`: just after it opened) or just after its Save
/// (`-otherDeviceAfterSave <page>`: built on the page as it OPENED — a save that crossed this one).
/// Pages: `grab` (the grab list's editor), `template` (a template's page), `kit` (a kit's page).
/// It arrives as iCloud brings it — through the store, as a remote change — with the other
/// device's check-in, so the question can name it.
@MainActor
enum OtherDeviceForTests {
    static func opened(_ page: String, _ model: LibraryModel, _ change: @escaping (inout Library) -> Void) {
        play("-otherDeviceOnOpen", page, model, change)
    }

    static func saved(_ page: String, _ model: LibraryModel, _ change: @escaping (inout Library) -> Void) {
        play("-otherDeviceAfterSave", page, model, change)
    }

    /// Once per launch: a page opened again finds no new change of the other device.
    private static var played: Set<String> = []

    private static func play(_ flag: String, _ page: String, _ model: LibraryModel, _ change: @escaping (inout Library) -> Void) {
        let args = ProcessInfo.processInfo.arguments
        guard AMSPackingApp.testing, let n = args.firstIndex(of: flag), n + 1 < args.count, args[n + 1] == page,
              played.insert(flag).inserted else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { model.arriveFromTheOtherDevice(change) }
    }
}
#endif
