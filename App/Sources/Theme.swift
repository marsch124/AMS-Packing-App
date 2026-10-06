import SwiftUI

// The web app's colours, light and dark. He runs everything in DARK mode, so
// every page and text colour here is a pair — never a single hex. (The six
// section colours, Sections.swift, are ONE mid-tone each on purpose: each reads at
// 3.2 : 1 or better on the light card and the dark one alike — docs/colours.md.)

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
    /// Quieter than `muted`: a mark that is there to be found, not read — a thing's
    /// grip ≡ while arranging (his note on 0.63, 6 Oct 2026: the things' grips in
    /// `muted` looked "black", too close to the headings' lilac ones).
    static let faint = Color(light: 0xa9b5ba, dark: 0x5a6a71)
}

/// A ScrollView that puts the keyboard away when it is dragged — on the phone
/// the keyboard covers the tab bar, and dragging the list is how a person gets
/// it out of the way.
struct KeyboardAwayScroll<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        ScrollView { content() }.scrollDismissesKeyboard(.immediately)
    }
}

/// Heights of buttons, fields, pills and rows — Apple's standard sizes, slim (his
/// words, 5 Oct 2026: "efficient, fluid, and Apple-standard … make the buttons even
/// slimmer, smaller when possible"). The Mac's are smaller again, as its own are.
enum Metrics {
    #if os(macOS)
    static let row: CGFloat = 30      // a door or a card's row
    static let tap: CGFloat = 26      // a button or a field
    static let compact: CGFloat = 24  // a smaller button
    static let chip: CGFloat = 22     // a pill
    static let header: CGFloat = 24   // Done, Cancel, Share … at the top of a page
    #else
    static let row: CGFloat = 40
    static let tap: CGFloat = 36
    static let compact: CGFloat = 32
    static let chip: CGFloat = 28
    static let header: CGFloat = 30
    #endif
    /// The touch area of the table's column arrows and Hide, on both: his ask (4 Oct
    /// 2026), "These arrows are rather difficult to hit. Could you please enlarge the
    /// hotspots". The arrows themselves stay small; only the area that takes the tap is.
    static let fingertip: CGFloat = 44
    /// From the top of a tab (under the status bar, or the Mac's title bar) to its
    /// first line, the header. Was 14 on most tabs, and the header lined up on the
    /// title's baseline stood a 36-pt search button up above that — his note on 0.63
    /// (6 Oct 2026), "The area above Grab and go is underused".
    static let screenTop: CGFloat = 4
}
