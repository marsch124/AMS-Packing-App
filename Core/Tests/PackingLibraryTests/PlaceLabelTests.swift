import XCTest
import CoreImage
import ImageIO
@testable import PackingCore
@testable import PackingLibrary

/// A place's label for his P-touch CUBE (0.69): 12 mm tape, 180 dots to the inch, 64 of
/// them printable. The label is read back by a code reader, as the iPhone's Camera
/// would read it off the shelf.
final class PlaceLabelTests: XCTestCase {
    private let code = "G4R"
    private let place = "Loft / attic"

    private func decoded(_ png: Data) -> [String] {
        guard let image = CIImage(data: png) else { return [] }
        // As it is, dot for dot — not enlarged: a code that reads only when blown up
        // would not read off a 9 mm label either.
        let reader = CIDetector(ofType: CIDetectorTypeQRCode, context: CIContext(options: [.useSoftwareRenderer: true]),
                                options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        return (reader?.features(in: image) ?? []).compactMap { ($0 as? CIQRCodeFeature)?.messageString }
    }

    func testTheLabelReadsBackAsThePlacesLink() throws {
        let png = try XCTUnwrap(PlaceLabel.png(code: code, name: place), "no label made")
        XCTAssertEqual(decoded(png), ["AMSPACKING://P/G4R"], "the label does not read back as the place's link")
    }

    func testTheLabelIsAsTallAsTheTapePrintsAndMarked180Dots() throws {
        let png = try XCTUnwrap(PlaceLabel.png(code: code, name: place))
        let source = try XCTUnwrap(CGImageSourceCreateWithData(png as CFData, nil))
        let props = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        XCTAssertEqual(props[kCGImagePropertyPixelHeight] as? Int, 64, "not the tape's 64 printable dots")
        XCTAssertEqual((props[kCGImagePropertyDPIHeight] as? NSNumber)?.intValue, 180)
        XCTAssertGreaterThan(props[kCGImagePropertyPixelWidth] as? Int ?? 0, 64 + 40, "the name is not beside the code")
    }

    /// The smallest code there is (21 × 21 squares) — the only one 64 dots can hold with
    /// whole dots of 3 — and every square whole: no grey, no smoothing.
    func testTheCodeIsTheSmallestSizeInWholeDots() throws {
        let squares = try XCTUnwrap(PlaceLabel.squares(PlaceLink.text(code: "ZZZZ")))
        XCTAssertEqual(squares.count, 21, "a four-character code no longer fits the smallest square code")
        XCTAssertEqual(PlaceLabel.dotsPerSquare(21), 3)
        let image = try XCTUnwrap(PlaceLabel.image(code: code, name: place))
        XCTAssertEqual(image.height, 64)
        let width = image.width
        var pixels = [UInt8](repeating: 0, count: width * 64)
        let ctx = try XCTUnwrap(CGContext(data: &pixels, width: width, height: 64, bitsPerComponent: 8, bytesPerRow: width,
                                          space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue))
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: 64))
        XCTAssertTrue(pixels.allSatisfy { $0 == 0 || $0 == 255 }, "grey dots: a thermal printer prints a dot or none")
        // The code: 63 × 63 dots from 6 dots in, at the top; each square 3 × 3 of one colour,
        // and matching the code's own squares.
        let grid = try XCTUnwrap(PlaceLabel.squares(PlaceLink.text(code: code)))
        for r in 0..<21 {
            for c in 0..<21 {
                let want: UInt8 = grid[r][c] ? 0 : 255
                for dy in 0..<3 { for dx in 0..<3 {
                    let at = (r * 3 + dy) * width + (6 + c * 3 + dx)
                    if pixels[at] != want { return XCTFail("square \(r),\(c) is not whole at dot \(dx),\(dy)") }
                } }
            }
        }
        // Two squares of white to its left.
        for y in 0..<63 { for x in 0..<6 where pixels[y * width + x] != 255 { return XCTFail("no white to the code's left") } }
    }

    func testTheFileIsNamedAfterThePlace() {
        XCTAssertEqual(PlaceLabel.fileName("Garage"), "Garage label.png")
        XCTAssertEqual(PlaceLabel.fileName("Loft / attic"), "Loft - attic label.png")
    }
}
