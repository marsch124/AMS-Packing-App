import SwiftUI
import CoreText

// tools/grab-icons.sh compiles this with App/Sources/SVGPath.swift and GrabDoodle (copied out
// of GrabScreen.swift): every picture a grab list wears under the app icon, as a template PDF
// of 35 × 35 points in an image set of the asset catalog.

let box: CGFloat = 35          // a quick action's icon, in points
let margin: CGFloat = 2        // so a round end at the drawing's edge (the sun's rays) is not cut

@main
enum DrawGrabIcons {
    static func main() throws {
        let out = URL(fileURLWithPath: CommandLine.arguments[1])
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        try write(json: ["info": ["author": "xcode", "version": 1], "properties": ["provides-namespace": false]],
                  to: out.appendingPathComponent("Contents.json"))

        // The six doodles: the 64-unit drawing, stroked 4.5 units wide with round ends — as on a tile.
        for icon in ["swim", "bike", "run", "swim-sun", "bike-sun", "run-sun"] {
            let path = SVGPath.path(GrabDoodle.path(icon)).cgPath
            try pdf(named: "grab-\(icon)", in: out) { ctx in
                stroke(path, unit: 64, width: 4.5, in: ctx)
            }
        }

        // A list of his own wears its initial: the system font, heaviest weight, centred.
        let font = CTFontCreateWithFontDescriptor(
            NSFont.systemFont(ofSize: 23, weight: .heavy).fontDescriptor as CTFontDescriptor, 23, nil)
        for ch in "ABCDEFGHIJKLMNOPQRSTUVWXYZÅÄÖÜ0123456789" {
            let scalar = ch.unicodeScalars.first!
            var unit = UniChar(scalar.value)
            var glyph = CGGlyph()
            guard CTFontGetGlyphsForCharacters(font, &unit, &glyph, 1), let outline = CTFontCreatePathForGlyph(font, glyph, nil) else {
                throw NSError(domain: "grab-icons", code: 1, userInfo: [NSLocalizedDescriptionKey: "no glyph for \(ch)"])
            }
            let name = "grab-initial-\(String(scalar.value, radix: 16, uppercase: true))"
            try pdf(named: name, in: out) { ctx in
                // The glyph's own outline is y-up, as the PDF is: centre its bounds in the box.
                let b = outline.boundingBoxOfPath
                ctx.translateBy(x: (box - b.width) / 2 - b.minX, y: (box - b.height) / 2 - b.minY)
                ctx.addPath(outline)
                ctx.setFillColor(CGColor(gray: 0, alpha: 1))
                ctx.fillPath()
            }
        }

        // Any other initial: the Home tab's suitcase (Sections.swift, `AppSection.home.mark`).
        var suitcase = Path(roundedRect: CGRect(x: 4, y: 7.5, width: 16, height: 12.5), cornerRadius: 2.2)
        suitcase.addPath(SVGPath.path("M9 7.5V5.6A1.6 1.6 0 0 1 10.6 4h2.8A1.6 1.6 0 0 1 15 5.6V7.5M9.5 11v5.5M14.5 11v5.5"))
        try pdf(named: "grab-list", in: out) { ctx in
            stroke(suitcase.cgPath, unit: 24, width: 1.9, in: ctx)
        }
    }

    /// A drawing in a `unit`-wide square, y down as SVG draws it, stroked round in black.
    static func stroke(_ path: CGPath, unit: CGFloat, width: CGFloat, in ctx: CGContext) {
        let k = (box - 2 * margin) / unit
        ctx.translateBy(x: margin, y: box - margin)
        ctx.scaleBy(x: k, y: -k)
        ctx.addPath(path)
        ctx.setLineWidth(width)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.setStrokeColor(CGColor(gray: 0, alpha: 1))
        ctx.strokePath()
    }

    /// One image set: `<name>.imageset/<name>.pdf`, a template image.
    static func pdf(named name: String, in folder: URL, draw: (CGContext) -> Void) throws {
        let set = folder.appendingPathComponent("\(name).imageset")
        try FileManager.default.createDirectory(at: set, withIntermediateDirectories: true)
        let file = set.appendingPathComponent("\(name).pdf")
        var media = CGRect(x: 0, y: 0, width: box, height: box)
        guard let ctx = CGContext(file as CFURL, mediaBox: &media, nil) else {
            throw NSError(domain: "grab-icons", code: 2, userInfo: [NSLocalizedDescriptionKey: "cannot write \(file.path)"])
        }
        ctx.beginPDFPage(nil)
        ctx.saveGState()
        draw(ctx)
        ctx.restoreGState()
        ctx.endPDFPage()
        ctx.closePDF()
        try write(json: ["images": [["filename": "\(name).pdf", "idiom": "universal"]],
                         "info": ["author": "xcode", "version": 1],
                         "properties": ["template-rendering-intent": "template"]],
                  to: set.appendingPathComponent("Contents.json"))
    }

    static func write(json: [String: Any], to url: URL) throws {
        let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url)
    }
}
