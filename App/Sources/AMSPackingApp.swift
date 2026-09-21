import SwiftUI

@main
struct AMSPackingApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                #if os(macOS)
                .frame(minWidth: 480, idealWidth: 760, minHeight: 600, idealHeight: 900)
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 760, height: 900)
        #endif
    }
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
