import SwiftUI

// The web app's colours, light and dark. He runs everything in DARK mode, so
// every colour here is a pair — never a single hex.

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xff) / 255,
                  green: Double((hex >> 8) & 0xff) / 255,
                  blue: Double(hex & 0xff) / 255,
                  opacity: 1)
    }

    /// One colour for light, one for dark, following the system.
    init(light: UInt32, dark: UInt32) {
        #if os(macOS)
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(Color(hex: isDark ? dark : light))
        })
        #else
        self.init(uiColor: UIColor { traits in
            UIColor(Color(hex: traits.userInterfaceStyle == .dark ? dark : light))
        })
        #endif
    }
}

enum Theme {
    static let bg    = Color(light: 0xf4f6f7, dark: 0x0e1416)
    static let card  = Color(light: 0xffffff, dark: 0x161f22)
    static let ink   = Color(light: 0x16232a, dark: 0xe7edee)
    static let muted = Color(light: 0x5f7078, dark: 0x94a6ac)
    static let line  = Color(light: 0xe2e8ea, dark: 0x26343a)
}
