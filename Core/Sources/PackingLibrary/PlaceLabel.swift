import Foundation
import CoreGraphics
import CoreImage
import CoreText
import ImageIO
import UniformTypeIdentifiers

// A place's label for his label printer (0.69): a Brother P-touch CUBE (PT-P300BT) on
// 12 mm TZe tape — 180 dots to the inch, about 9 mm (64 dots) of it printable. He prints
// from Brother's own app, which takes a picture from Photos or Files, so the label is a
// PNG exactly as tall as the tape prints: the square code on the left, the place's name
// to its right, black on white.
//
// A square code shrinks to what fits only when each of its squares stays whole dots: at
// 64 dots, the smallest code (version 1, 21 × 21 squares) gets 3 dots a square — 63 dots,
// 8.8 mm — drawn square by square, never scaled smooth (a blurred square is a misread
// one). The link is made to fit that size (`PlaceLink.text`). Above and below, the
// tape's own unprinted edge is the code's quiet margin; left and right it gets two
// squares of white.

public enum PlaceLabel {
    /// The tape's printable height, in dots: 12 mm TZe tape on the P-touch CUBE.
    public static let height = 64
    /// The printer's dots to the inch — written into the PNG, so an app that reads it
    /// places it at its real size (64 dots = 9 mm).
    public static let dpi = 180
    /// Error correction: medium — 15 % of the code may be scuffed and it still reads,
    /// and the link (18 characters) still fits the smallest size, which holds 20.
    public static let correction = "M"
    /// White to the code's left and right, in squares (above and below: the tape's edge).
    public static let quiet = 2

    /// The code's squares, row by row from the top (true = black), without a margin —
    /// nil when the text cannot be made into a code.
    public static func squares(_ text: String) -> [[Bool]]? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(Data(text.utf8), forKey: "inputMessage")
        filter.setValue(correction, forKey: "inputCorrectionLevel")
        guard let out = filter.outputImage else { return nil }
        let extent = out.extent.integral
        let side = Int(extent.width)
        guard side > 2, Int(extent.height) == side,
              let cg = CIContext(options: [.useSoftwareRenderer: true]).createCGImage(out, from: extent) else { return nil }
        // Read one dot per square: the filter draws ONE pixel a square, with a margin of
        // one square all round.
        var pixels = [UInt8](repeating: 255, count: side * side)
        guard let ctx = CGContext(data: &pixels, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side,
                                  space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        ctx.interpolationQuality = .none
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))
        let n = side - 2
        // The bitmap's first row is the image's top row.
        return (0..<n).map { r in (0..<n).map { c in pixels[(r + 1) * side + (c + 1)] < 128 } }
    }

    /// Dots per square for a code `count` squares across: as many whole dots as the
    /// tape's height allows.
    public static func dotsPerSquare(_ count: Int) -> Int { max(1, height / max(1, count)) }

    /// The label as a picture: `height` dots tall, as wide as the name needs.
    public static func image(code: String, name: String) -> CGImage? {
        guard let grid = squares(PlaceLink.text(code: code)) else { return nil }
        let n = grid.count
        let m = dotsPerSquare(n)
        let codeSide = n * m
        let left = quiet * m
        let gap = 3 * m
        let font = boldCondensed(size: CGFloat(height) * 0.62)
        let words = NSAttributedString(string: name, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorFromContextAttributeName as String): true,
        ])
        let line = CTLineCreateWithAttributedString(words)
        let textWidth = Int(ceil(CTLineGetTypographicBounds(line, nil, nil, nil)))
        let width = left + codeSide + (name.isEmpty ? 0 : gap + textWidth) + left
        guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        ctx.setFillColor(gray: 1, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        // Whole dots only: no smoothing anywhere — a thermal printer prints a dot or none.
        ctx.setShouldAntialias(false)
        ctx.setAllowsAntialiasing(false)
        ctx.interpolationQuality = .none
        ctx.setFillColor(gray: 0, alpha: 1)
        // Centred top to bottom (64 dots, a 63-dot code: the spare dot goes below).
        let top = (height - codeSide) / 2
        for (r, row) in grid.enumerated() {
            for (c, black) in row.enumerated() where black {
                // The context counts from the bottom.
                ctx.fill(CGRect(x: left + c * m, y: height - top - (r + 1) * m, width: m, height: m))
            }
        }
        if !name.isEmpty {
            // The name's capitals centred on the tape.
            let cap = CTFontGetCapHeight(font)
            ctx.textMatrix = .identity
            ctx.textPosition = CGPoint(x: CGFloat(left + codeSide + gap), y: (CGFloat(height) - cap) / 2)
            CTLineDraw(line, ctx)
        }
        return ctx.makeImage()
    }

    /// The label as PNG bytes, marked 180 dots to the inch.
    public static func png(code: String, name: String) -> Data? {
        guard let image = image(code: code, name: name) else { return nil }
        let data = NSMutableData()
        guard let out = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(out, image, [kCGImagePropertyDPIWidth: dpi, kCGImagePropertyDPIHeight: dpi] as CFDictionary)
        guard CGImageDestinationFinalize(out) else { return nil }
        return data as Data
    }

    /// The file's name: "Garage label.png" — a "/" in a place's name ("Loft / attic")
    /// cannot be in a file's.
    public static func fileName(_ name: String) -> String {
        let clean = name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespaces)
        return "\(clean.isEmpty ? "Place" : clean) label.png"
    }

    /// A bold, narrow face, so a long name stays a short label: Helvetica Neue Condensed
    /// Bold (on both the iPhone and the Mac), else Avenir Next Condensed Bold, else the
    /// system's bold.
    static func boldCondensed(size: CGFloat) -> CTFont {
        for name in ["HelveticaNeue-CondensedBold", "AvenirNextCondensed-Bold"] {
            let font = CTFontCreateWithName(name as CFString, size, nil)
            if (CTFontCopyPostScriptName(font) as String) == name { return font }
        }
        return CTFontCreateUIFontForLanguage(.emphasizedSystem, size, nil) ?? CTFontCreateWithName("Helvetica-Bold" as CFString, size, nil)
    }
}
