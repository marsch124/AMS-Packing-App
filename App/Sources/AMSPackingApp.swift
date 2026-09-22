import SwiftUI

@main
struct AMSPackingApp: App {
    @StateObject private var model = LibraryModel.forThisLaunch()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                #if os(macOS)
                .frame(minWidth: 480, idealWidth: 760, minHeight: 600, idealHeight: 900)
                .onAppear { AMSPackingApp.useTheRunnersWindowSize() }
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 760, height: 900)
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
}
