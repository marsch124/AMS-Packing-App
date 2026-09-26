import Foundation

// Colours he chooses himself (his "When" steps: a pale green, a bright red, a
// light grey…) are used as TEXT on light screens, dark screens and the green
// "all packed" screen. His screenshot (2026-09-26): "Bad text color twice" — the
// pale green and the red were unreadable on the green. So a chosen colour keeps
// its hue but is darkened (light screens) or lightened (dark screens) until it
// reads.

/// How bright a colour is to the eye, 0 (black) … 1 (white): WCAG relative luminance.
public func relativeLuminance(_ hex: String) -> Double? {
    guard let (r, g, b) = rgb(hex) else { return nil }
    func lin(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
    return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
}

/// The colour, made readable: on a light screen no brighter than `text` 0.15
/// (a graphic, like a tick circle, 0.35); on a dark screen no darker than 0.25
/// (a graphic 0.15). A colour already readable comes back unchanged; one that is
/// not a colour comes back as it was.
public func readableHex(_ hex: String, dark: Bool, graphic: Bool = false) -> String {
    guard var (r, g, b) = rgb(hex), var l = relativeLuminance(hex) else { return hex }
    var steps = 0
    if dark {
        let floor = graphic ? 0.15 : 0.25
        while l < floor && steps < 40 {
            r += (1 - r) * 0.08; g += (1 - g) * 0.08; b += (1 - b) * 0.08
            l = relativeLuminance(hexOf(r, g, b)) ?? 1; steps += 1
        }
    } else {
        let ceiling = graphic ? 0.35 : 0.15
        while l > ceiling && steps < 40 {
            r *= 0.92; g *= 0.92; b *= 0.92
            l = relativeLuminance(hexOf(r, g, b)) ?? 0; steps += 1
        }
    }
    return steps == 0 ? hex : hexOf(r, g, b)
}

private func rgb(_ hex: String) -> (Double, Double, Double)? {
    var s = hex.trimmingCharacters(in: .whitespaces)
    if s.hasPrefix("#") { s.removeFirst() }
    if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
    guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
    return (Double((v >> 16) & 0xff) / 255, Double((v >> 8) & 0xff) / 255, Double(v & 0xff) / 255)
}

private func hexOf(_ r: Double, _ g: Double, _ b: Double) -> String {
    func c(_ x: Double) -> Int { max(0, min(255, Int((x * 255).rounded()))) }
    return String(format: "#%02x%02x%02x", c(r), c(g), c(b))
}
