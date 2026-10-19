import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// A template's colour, his to choose (0.90 — his words, 19 Oct 2026: "I would like the
/// ability to change the color of the table template icons … the color that I connect to a
/// specific template"): kept in the template's own `color`, through every later edit, the
/// stored records, a backup and a shared link; Automatic gives back the colour it had.
final class TemplateColourTests: XCTestCase {
    override func setUp() { PackingEnv.freeze() }
    override func tearDown() { PackingEnv.reset() }

    /// Light card, dark card — `docs/colours.md`.
    private let lightCard = "#ffffff", darkCard = "#161f22"

    func testThePaletteReadsDayAndNightAndHasNoTeal() {
        let palette = TemplateColour.palette
        XCTAssertGreaterThanOrEqual(palette.count, 10, "a palette of about ten")
        XCTAssertEqual(Set(palette.map(\.key)).count, palette.count, "two swatches share a key")
        XCTAssertEqual(Set(palette.map(\.hex)).count, palette.count, "two swatches share a colour")
        XCTAssertFalse(palette.contains { $0.key == Library.automaticColourKey }, "a colour took Automatic's key")
        // His six workout colours lead, with the dark words of their pills on the light ones.
        XCTAssertEqual(palette.prefix(6).map(\.hex), ["#0a84ff", "#ffd60a", "#30d158", "#ff8c1a", "#bf9cff", "#ff6fa8"])
        XCTAssertEqual(TemplateColour.of(hex: "#FFD60A")?.ink, "#3d3000", "Bike's yellow carries dark words")
        for c in palette {
            XCTAssertTrue(isHexColor(c.hex) && c.hex == c.hex.lowercased(), "\(c.key): \(c.hex) is no stored colour")
            // The icon on its own cover: 3.5 : 1 or better (a drawing, not small text).
            XCTAssertGreaterThanOrEqual(contrastRatio(c.ink, c.hex), 3.5, "\(c.key): its icon does not read on it")
            // Drawn on its own (a trip line's marks), day and night: as text reads.
            for (card, dark) in [(lightCard, false), (darkCard, true)] {
                let mark = readableHex(c.hex, dark: dark)
                XCTAssertGreaterThanOrEqual(contrastRatio(mark, card), 4.5,
                                            "\(c.key) as a mark on the \(dark ? "dark" : "light") card: \(mark)")
            }
        }
        // No teal (his colour notes) — the web app's teal and cyan, and the grab lists' teal.
        for teal in ["#14b8a6", "#06b6d4", "#17969b"] { XCTAssertNil(TemplateColour.of(hex: teal), "teal in the palette") }
    }

    func testHisColourIsKeptThroughEditsRecordsBackupsAndAShareAndAutomaticGivesTheOldOneBack() throws {
        var lib = Library()
        var hiking = newList(name: "Hiking", group: "GA"); hiking.items = [newItem(name: "Map")]
        lib.saveTemplate(hiking)
        let id = lib.templates[0].id
        let automatic = Library.coverColour(lib.resolvedTemplate(id: id))
        XCTAssertNil(lib.chosenColour(templateId: id), "a colour before any was chosen")
        XCTAssertEqual(Library.coverInk(lib.resolvedTemplate(id: id)), "#ffffff", "Automatic draws white, as before 0.90")
        XCTAssertNil(Library.markColour(lib.resolvedTemplate(id: id)!, dark: false), "Automatic marks keep their violet")

        XCTAssertTrue(lib.setTemplateColour(id: id, hex: "#0A84FF"))
        XCTAssertEqual(lib.chosenColour(templateId: id), "#0a84ff")
        XCTAssertEqual(Library.coverColour(lib.resolvedTemplate(id: id)), "#0a84ff", "the cover does not wear his colour")
        XCTAssertEqual(Library.coverColour(lib.resolvedTemplates()[0]), "#0a84ff")
        XCTAssertNotNil(Library.markColour(lib.resolvedTemplate(id: id)!, dark: true), "a trip line's mark ignores his colour")
        XCTAssertTrue(lib.setTemplateColour(id: id, hex: "#ffd60a"))
        XCTAssertEqual(Library.coverInk(lib.resolvedTemplate(id: id)), "#3d3000", "white on Bike's yellow")

        // Later edits save the whole template again — the colour must survive them, and the icon beside it.
        _ = lib.addToTemplate(templateId: id, name: "Headlamp")
        XCTAssertTrue(lib.renameTemplate(id: id, to: "Hiking & camping"))
        XCTAssertTrue(lib.setTemplateIcon(id: id, key: "tent"))
        XCTAssertTrue(lib.setTemplateArea(id: id, area: "OE"))
        XCTAssertEqual(lib.chosenColour(templateId: id), "#ffd60a", "an edit to the template lost its colour")
        XCTAssertEqual(lib.chosenIcon(templateId: id), "tent", "the colour took the icon's place")

        // The stored records (iCloud) and a backup carry it.
        let back = Library(records: lib.records())
        XCTAssertEqual(back.chosenColour(templateId: id), "#ffd60a", "the stored records lost the colour")
        let (restored, report) = Importer.library(from: lib.backupFile())
        XCTAssertTrue(report.isFaithful, "the backup does not come back the same: \(report.mismatches.prefix(3))")
        XCTAssertEqual(restored.chosenColour(templateId: id), "#ffd60a", "a backup lost the colour")
        // …and Restore from the file's bytes, as Settings reads it.
        let data = lib.backupData(exportedAt: "2026-10-19T08:00:00.000Z")
        let (fromBytes, bytesReport) = Importer.library(from: BackupFile(json: try JSONValue.parse(data)))
        XCTAssertTrue(bytesReport.isFaithful, "\(bytesReport.mismatches.prefix(3))")
        XCTAssertEqual(fromBytes.chosenColour(templateId: id), "#ffd60a", "Restore lost the colour")

        // A shared template takes it along (the web app's `c`); Replace keeps HIS colour.
        let link = try XCTUnwrap(lib.shareLink(templateId: id))
        guard case .template(let shared)? = Library.readShared(link) else { return XCTFail("not read as a template") }
        var friend = Library()
        let theirs = try XCTUnwrap(friend.importTemplate(shared))
        XCTAssertEqual(friend.chosenColour(templateId: theirs.id), "#ffd60a", "a shared template lost its colour")
        XCTAssertTrue(lib.setTemplateColour(id: id, hex: "#ff6fa8"))
        _ = lib.replaceTemplate(id: id, with: shared)
        XCTAssertEqual(lib.chosenColour(templateId: id), "#ff6fa8", "Replace took the sender's colour over his")

        // Automatic: the colour the app picked before, white on it again.
        XCTAssertTrue(lib.setTemplateColour(id: id, hex: nil))
        XCTAssertNil(lib.chosenColour(templateId: id))
        XCTAssertEqual(Library.coverColour(lib.resolvedTemplate(id: id)), automatic, "Automatic did not give the old colour back")
        XCTAssertEqual(Library.coverInk(lib.resolvedTemplate(id: id)), "#ffffff")
        XCTAssertEqual(Library(records: lib.records()).chosenColour(templateId: id), nil, "Automatic did not reach the store")

        // Nothing that is not a colour; no template that is not there.
        XCTAssertFalse(lib.setTemplateColour(id: id, hex: "blue"))
        XCTAssertFalse(lib.setTemplateColour(id: "nope", hex: "#0a84ff"))
        XCTAssertNil(lib.chosenColour(templateId: id), "a refused colour changed something")
    }

    /// A colour the web app gave a template that is none of the palette is kept and shown as
    /// it is — white on it, as every cover was drawn before 0.90.
    func testAWebAppColourIsKeptAsItIs() {
        var lib = Library()
        var odd = newList(name: "Picnic"); odd.color = "#123456"
        lib.saveTemplate(odd)
        let list = lib.resolvedTemplates()[0]
        XCTAssertEqual(Library.coverColour(list), "#123456")
        XCTAssertEqual(Library.coverInk(list), "#ffffff")
        XCTAssertEqual(lib.chosenColour(templateId: list.id), "#123456")
    }

    /// 0.91 (his "Yes, show the template colours on the Create new trip pills too", 19 Oct
    /// 2026): a template's pill wears the colour he chose, with words that read on it — the
    /// palette's ink, or for a web-app colour white or dark, whichever reads; Automatic = none.
    func testAPillWearsHisColourWithWordsThatRead() throws {
        var lib = Library()
        lib.saveTemplate(newList(name: "Hiking", group: "GA"))
        let id = lib.templates[0].id
        XCTAssertNil(Library.pillColour(try XCTUnwrap(lib.resolvedTemplate(id: id))), "an Automatic template's pill took a colour")

        XCTAssertTrue(lib.setTemplateColour(id: id, hex: "#ffd60a"))
        // What Create new trip offers is what the pill is drawn from.
        let offered = try XCTUnwrap(lib.activityChoices().flatMap(\.lists).first { $0.id == id })
        let yellow = try XCTUnwrap(Library.pillColour(offered), "the offered template lost his colour")
        XCTAssertEqual(yellow.fill, "#ffd60a")
        XCTAssertEqual(yellow.ink, "#3d3000", "white words on Bike's yellow")

        for c in TemplateColour.palette {
            var l = newList(name: "Any"); l.color = c.hex.uppercased()
            let pill = try XCTUnwrap(Library.pillColour(l), "\(c.key) gives the pill no colour")
            XCTAssertEqual(pill.fill, c.hex, "\(c.key): the pill is not its colour")
            XCTAssertEqual(pill.ink, c.ink, "\(c.key): the pill's words are not the cover's ink")
        }
        // A colour from the web app: its words read on it, a light one dark, a deep one white.
        for (hex, ink) in [("#f5e6a0", Library.pillDarkInk), ("#123456", "#ffffff"), ("#f59e0b", Library.pillDarkInk)] {
            var l = newList(name: "Web"); l.color = hex
            let pill = try XCTUnwrap(Library.pillColour(l))
            XCTAssertEqual(pill.ink, ink, "\(hex): the words on it")
            XCTAssertGreaterThanOrEqual(contrastRatio(pill.ink, hex), 4.5, "\(hex): its words do not read on it")
        }

        XCTAssertTrue(lib.setTemplateColour(id: id, hex: nil))
        XCTAssertNil(Library.pillColour(try XCTUnwrap(lib.resolvedTemplate(id: id))), "Automatic kept the pill's colour")
    }
}
