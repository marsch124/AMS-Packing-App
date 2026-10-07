import SwiftUI

@main
struct AMSPackingApp: App {
    @StateObject private var model = LibraryModel.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                #if os(macOS)
                .frame(minWidth: 480, idealWidth: 760, minHeight: 600, idealHeight: 900)
                .onAppear { AMSPackingApp.useTheRunnersWindowSize() }
                // A place's label link (0.69) goes to the window that is open: without these
                // the Mac opens a NEW window for every link that reaches the app.
                .handlesExternalEvents(preferring: ["*"], allowing: ["*"])
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 760, height: 900)
        // No title bar (0.67, his note on 0.63: the strip at the top was "underused"): the
        // tab's own header sits on the traffic lights' line (`TitleBarStrip`). The window
        // still moves when the empty parts of that strip are dragged, as by its title bar —
        // the Mac does that itself (`testTheWindowMovesByItsEmptyStrip`) — but not by the
        // rest of its background: a drag on a page's empty space should not carry it.
        .windowStyle(.hiddenTitleBar)
        .windowBackgroundDragBehavior(.disabled)
        .handlesExternalEvents(matching: ["*"])
        #endif

        #if os(macOS)
        // All your things · table, in a window of its own on the Mac — his ask, 4 Oct
        // 2026: "I would like it wider in order to see more columns". Drag it as wide
        // as you like or make it full screen; the app stays open beside it, and both
        // show the same library.
        Window("All your things", id: ThingsTable.windowId) {
            ThingsTable(inWindow: true)
                .environmentObject(model)
        }
        .defaultSize(width: AMSPackingApp.testing ? 760 : 1180, height: AMSPackingApp.testing ? 620 : 780)
        .windowResizability(.contentMinSize)
        // Opened only from Care, never by itself: left open when the app quit, the
        // Mac brought it back at the next start, in front of the app — every UI test
        // after the first one that opened it failed on GitHub (0.58, 4 Oct 2026).
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(.suppressed)
        // Never the window a link opens in (0.69): links go to the app's own window.
        .handlesExternalEvents(matching: [])
        #endif
    }
}

extension AMSPackingApp {
    /// Under the UI tests the Mac window is held to GitHub's runner size (a
    /// 674-point window there), so a test that passes here passes there: a
    /// control below the fold on the runner is below the fold here too.
    static let testing = ProcessInfo.processInfo.arguments.contains { $0.hasPrefix("-uiTesting") }

    #if os(macOS)
    /// Set, not suggested: macOS restores a window's last size and ignores size
    /// limits on the content, so under the tests the window is SET to exactly the
    /// runner's (760 × 674, read off its TAP-REPORT), keeping its top edge.
    static func useTheRunnersWindowSize() {
        guard testing else { return }
        DispatchQueue.main.async {
            for w in NSApplication.shared.windows where w.isVisible && w.styleMask.contains(.titled) {
                let f = w.frame
                w.setFrame(NSRect(x: f.minX, y: f.maxY - 674, width: 760, height: 674), display: true)
            }
        }
    }
    #endif
}

/// What the app says about itself. The version comes from the bundle, so the
/// number on screen and the number TestFlight shows can never disagree.
enum AppInfo {
    static var version: String {
        let info = Bundle.main.infoDictionary
        let v = info?["CFBundleShortVersionString"] as? String ?? "?"
        let b = info?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }
    /// Just the version, "0.23" — what What's new marks as "On this device".
    static var marketing: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }
}
