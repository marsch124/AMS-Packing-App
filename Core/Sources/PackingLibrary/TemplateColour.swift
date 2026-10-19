import PackingCore

// A template's colour, his to choose (0.90 — his words, 19 Oct 2026: "I would like the
// ability to change the color of the table template icons. That way, I can more easily
// find the templates if they have the color that I connect to a specific template.").
//
// Stored in the template's own `color` — the web app's field for its cover colour (spec 04
// §10), which until 0.90 no screen here set. So it travels as every field of a template
// does: the store's records and iCloud, a backup and Restore, a shared template (`c`) and
// the web app, whose model reads it the same way; the parity check is untouched. Blank =
// Automatic: the stable pick of `coverColour`, the colour every template had before 0.90.
// A colour is chosen from the palette below; a colour a template brought from the web app
// that is none of them is kept and shown as it is.

/// One colour of the template-colour palette: its fill (what the template stores) and the
/// colour its icon or letter is drawn in on that fill.
public struct TemplateColour: Equatable, Sendable, Identifiable {
    /// The swatch's name in the picker's ids (`template-colour-<key>`).
    public let key: String
    /// Its word — said by VoiceOver and written under the swatch.
    public let name: String
    /// The fill, as stored in the template's `color`.
    public let hex: String
    /// The icon or letter on it: white on the deep colours; on the light ones (Bike's yellow,
    /// Run's green …) the dark words of his workout pills — white is unreadable there.
    public let ink: String
    public var id: String { key }

    /// The palette, in the picker's order: first his six workout colours (decided 28 Sep
    /// 2026, the same as AMS Workout Sync and the Create new trip pills, with their dark
    /// words), then five calm deep ones. No teal (his colour notes: "Do not use teal for
    /// anything new"). Every ink reads on its fill at 3.6 : 1 or better.
    public static let palette: [TemplateColour] = [
        TemplateColour(key: "blue", name: "Blue", hex: "#0a84ff", ink: "#ffffff"),            // Swim
        TemplateColour(key: "yellow", name: "Yellow", hex: "#ffd60a", ink: "#3d3000"),        // Bike
        TemplateColour(key: "green", name: "Green", hex: "#30d158", ink: "#0b3a17"),          // Run
        TemplateColour(key: "orange", name: "Orange", hex: "#ff8c1a", ink: "#4a2300"),        // Strength
        TemplateColour(key: "lavender", name: "Lavender", hex: "#bf9cff", ink: "#2e1a5c"),    // Breath work
        TemplateColour(key: "pink", name: "Pink", hex: "#ff6fa8", ink: "#5a0f2e"),            // Mobility
        TemplateColour(key: "red", name: "Red", hex: "#dc3d43", ink: "#ffffff"),
        TemplateColour(key: "violet", name: "Violet", hex: "#7c5cd6", ink: "#ffffff"),
        TemplateColour(key: "indigo", name: "Indigo", hex: "#4f46e5", ink: "#ffffff"),
        TemplateColour(key: "brown", name: "Brown", hex: "#8b5e3c", ink: "#ffffff"),
        TemplateColour(key: "slate", name: "Grey", hex: "#64748b", ink: "#ffffff"),
    ]

    /// The palette colour of a stored hex (capitals ignored), if it is one.
    public static func of(hex: String?) -> TemplateColour? {
        guard let hex else { return nil }
        let h = hex.lowercased()
        return palette.first { $0.hex == h }
    }
}

extension Library {
    /// The swatch that goes back to the colour the app picks (`template-colour-auto`).
    public static let automaticColourKey = "auto"

    /// The colour he chose for this template (a hex), or nil = Automatic.
    public func chosenColour(templateId: String) -> String? {
        guard let c = templates.first(where: { $0.id == templateId })?.color, isHexColor(c) else { return nil }
        return c
    }

    /// Choose a template's colour; nil (or blank) goes back to Automatic. False for a
    /// template that is not there or a value that is not a colour.
    @discardableResult
    public mutating func setTemplateColour(id: String, hex: String?) -> Bool {
        guard let n = templates.firstIndex(where: { $0.id == id }) else { return false }
        let value = jsTrim(hex ?? "")
        guard value.isEmpty || isHexColor(value) else { return false }
        templates[n].color = value.lowercased()
        templates[n].updatedAt = nowISO()
        return true
    }

    /// The colour a cover draws its icon or letter in: the palette's ink for a palette
    /// colour, white for every other (the Automatic ones and a colour from the web app —
    /// white, as every cover was drawn before 0.90).
    public static func coverInk(_ list: PackList?) -> String {
        TemplateColour.of(hex: list.map(coverColour))?.ink ?? "#ffffff"
    }

    /// A template's icon drawn on its own, on the page (a trip line's "from" marks, 0.74):
    /// his chosen colour, darkened on a light screen or lightened on a dark one until it
    /// reads as text does (`readableHex`); nil when he chose none — the mark keeps the
    /// Templates violet it had before 0.90.
    public static func markColour(_ list: PackList, dark: Bool) -> String? {
        guard isHexColor(list.color) else { return nil }
        return readableHex(list.color, dark: dark)
    }

    /// The dark words a pill takes on a light colour from the web app — `Theme.ink` by day.
    public static let pillDarkInk = "#16232a"

    /// A template's pill on Create new trip and Trip settings (0.91 — his "Yes, show the
    /// template colours on the Create new trip pills too", 19 Oct 2026): the colour he chose
    /// and the words on it. The palette's own ink on a palette colour (the cover's: dark on
    /// Bike's yellow); on a colour from the web app that is none of the palette, white or
    /// `pillDarkInk`, whichever reads better on it — words, unlike a cover's icon, must read.
    /// nil = Automatic: the pill keeps the look it had (the app's pick is no colour of his).
    public static func pillColour(_ list: PackList) -> (fill: String, ink: String)? {
        guard isHexColor(list.color) else { return nil }
        let fill = list.color.lowercased()
        if let p = TemplateColour.of(hex: fill) { return (p.hex, p.ink) }
        let white = "#ffffff"
        return (fill, contrastRatio(white, fill) >= contrastRatio(pillDarkInk, fill) ? white : pillDarkInk)
    }
}
