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
    /// Ink a tad grey (0.92) — between `ink` and `muted`, for a heading that should not be "so super
    /// black" (his words on Create new trip, 19 Oct 2026). 10 : 1 on the light card, 10.6 : 1 on the dark.
    static let inkGreyPair: (light: UInt32, dark: UInt32) = (0x34444c, 0xc4cfd2)
    static let inkGrey = Color(light: inkGreyPair.light, dark: inkGreyPair.dark)
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
    static let contextName: CGFloat = 64   // a workout's name before its own Context pills
    #else
    static let row: CGFloat = 40
    static let tap: CGFloat = 36
    static let compact: CGFloat = 32
    static let chip: CGFloat = 28
    static let header: CGFloat = 30
    static let contextName: CGFloat = 72
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
    /// The Mac: where a tab's title may start, from the window's LEFT EDGE — just after
    /// the three window buttons, whose green one ends at 68 on macOS 26 (measured on his
    /// screenshot of 0.63; its accessibility frame ends at 70; the system's own title
    /// started at 84). The window has no title bar since 0.67: its header sits on the
    /// buttons' line.
    static let windowButtons: CGFloat = 80

    // A line of a list — a trip's, a template's, a to-do, a line to buy, a grab list's:
    // as tall as its words and a hair, the feel of the table "without air" he loved the
    // same day. His words (6 Oct 2026, testing 0.63): "Far too much space between the
    // lines … Change this dramatically, not only a bit." Until 0.67 a trip's line took
    // 44 points top to top, a template's 42, a to-do 44, a grab list's 46 — on both.
    #if os(macOS)
    static let line: CGFloat = 22     // a line, top to top (a longer name still wraps)
    static let mark: CGFloat = 14     // its tick circle
    static let glyph: CGFloat = 16    // its ✕ or ⊘, drawn on the 24-point grid
    static let lineButton: CGFloat = 30   // the width that takes a press on ✕ or ⊘
    #else
    static let line: CGFloat = 30
    static let mark: CGFloat = 18
    static let glyph: CGFloat = 20
    static let lineButton: CGFloat = 40
    #endif

    // A tad tighter (0.104) — his six arrows on two Mac screenshots (28 Oct 2026): "It uses too much
    // screen real estate. Could you compress this a tad?" The cards at the top of a trip (Before you
    // go, the weather, the Bags card), the loop strip's pills and a thing page's Notes and photo
    // buttons. Until 0.104 a card kept 12–14 inside (14 under an open one), the cards stood 10–14
    // apart, the loop's pills were 28 on both and Notes 11 above and below its words. Only the room
    // around things shrank: the words keep Apple's sizes, and on the iPhone nothing that takes a tap
    // got smaller — where a pill looks slimmer there, the room that takes the tap is as before.
    #if os(macOS)
    static let cardInset: CGFloat = 8     // inside a card, above and below what it holds
    static let cardGap: CGFloat = 4       // from one card to the next, over the list's own 4
    static let cardLine: CGFloat = 24     // a card's own line: Before you go's heading, the Bags fold
    static let loopPill: CGFloat = 22     // a step of the loop strip, the pill drawn
    static let loopReach: CGFloat = 1     // above and below it, still taking the tap
    static let notesInset: CGFloat = 5    // above and below the words of Notes: one line is as tall as Name
    static let photoButton: CGFloat = 26  // Choose a photo, Choose a file… (38 until 0.104)
    #else
    static let cardInset: CGFloat = 10
    static let cardGap: CGFloat = 6
    static let cardLine: CGFloat = 36     // Before you go's heading keeps a fingertip's tap (the Bags fold its 28)
    static let loopPill: CGFloat = 24
    static let loopReach: CGFloat = 2     // so the strip takes a tap 28 high, as it did
    static let notesInset: CGFloat = 11   // Notes stays 44 high: a field a fingertip finds
    static let photoButton: CGFloat = 38
    #endif
    static let cardSide: CGFloat = 12     // inside a card, left and right (14 on Before you go and Bags until 0.104)
}

extension View {
    /// A mark drawn on the 24-point grid, shown `size` points across: framed at 24 so
    /// it stays in the middle (framed smaller, it hangs off-centre), then scaled.
    func onGrid(_ size: CGFloat) -> some View {
        frame(width: 24, height: 24).scaleEffect(size / 24).frame(width: size, height: size)
    }
}
