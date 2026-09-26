import XCTest
@testable import PackingLibrary

/// His "When" colours as text (2026-09-26: "Bad text color twice"). Whatever he
/// picks, a heading must read — on a light screen, a dark one and the green
/// "all packed" one — and keep its hue.
final class ContrastTests: XCTestCase {
    // The kinds of colour he uses: a pale green, a bright red, a light grey, a blue.
    let chosen = ["#cce8b5", "#ff4013", "#c0c0c0", "#3b82f6", "#e32400"]

    func testEveryChosenColourReadsOnALightScreen() {
        for c in chosen {
            let l = relativeLuminance(readableHex(c, dark: false))!
            XCTAssertLessThanOrEqual(l, 0.15, "\(c) is still too pale for text: \(l)")
            // Against the green "all packed" screen (about #b4dcc4), at least 3 : 1.
            let green = relativeLuminance("#b4dcc4")!
            XCTAssertGreaterThanOrEqual((green + 0.05) / (l + 0.05), 3.0, "\(c) does not stand out on the green")
        }
    }

    func testEveryChosenColourReadsOnADarkScreen() {
        for c in chosen + ["#b51a00", "#1e3a8a"] {
            XCTAssertGreaterThanOrEqual(relativeLuminance(readableHex(c, dark: true))!, 0.25, "\(c) is too dark on a dark screen")
        }
    }

    func testTheHueStaysAndADarkColourIsLeftAlone() {
        let red = readableHex("#ff4013", dark: false)
        XCTAssertTrue(red.hasPrefix("#") && red.count == 7)
        let v = UInt32(red.dropFirst(), radix: 16)!
        XCTAssertGreaterThan((v >> 16) & 0xff, ((v >> 8) & 0xff) * 3, "the red stopped being red: \(red)")
        XCTAssertEqual(readableHex("#1e3a8a", dark: false), "#1e3a8a", "a colour that already reads is left alone")
        XCTAssertEqual(readableHex("not a colour", dark: false), "not a colour")
        XCTAssertLessThanOrEqual(relativeLuminance(readableHex("#cce8b5", dark: false, graphic: true))!, 0.35)
    }
}
