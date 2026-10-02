import XCTest
@testable import PackingCore
@testable import PackingLibrary

/// A template's icon (his H.1, approved 2 Oct 2026): suggested from its role and
/// name, his choice kept through every later edit, a backup and the stored records.
final class TemplateIconTests: XCTestCase {
    override func setUp() { PackingEnv.freeze() }
    override func tearDown() { PackingEnv.reset() }

    private func list(_ name: String, role: String = "", group: String = "") -> PackList {
        var l = newList(name: name, group: group); l.role = role; return l
    }

    func testTheSuggestionsComeFromRoleAndName() {
        let cases: [(PackList, String?)] = [
            (list("Car (base)", role: "transport"), "car"), (list("Plane (base)", role: "transport"), "plane"),
            (list("RV something (base)", role: "transport"), "rv"), (list("Travel", role: "base"), "suitcase"),
            (list("Containers", role: CONTAINER_ROLE), "box"), (list("Diving"), "diving"),
            (list("Freediving"), "fin"), (list("Golf"), "golf"), (list("Hiking"), "hiking"),
            (list("Bike"), "bike"), (list("Mobility & Breath work"), "breath"), (list("Mobility"), "mobility"),
            (list("Run"), "run"), (list("Strength"), "strength"), (list("Swim"), "swim"),
            (list("Carry-on things"), nil), (list("Brunch"), nil), (list("Common base", role: "base"), "suitcase"),
        ]
        for (l, want) in cases { XCTAssertEqual(Library.suggestedIcon(for: l), want, l.name) }
    }

    func testHisChoiceIsKeptThroughEditsBackupsAndRecords() {
        var lib = Library()
        var hiking = list("Hiking", group: "GA"); hiking.items = [newItem(name: "Map")]
        lib.saveTemplate(hiking)
        let id = lib.templates[0].id
        XCTAssertEqual(lib.icon(for: lib.resolvedTemplate(id: id)!), "hiking", "the suggestion before any choice")

        XCTAssertTrue(lib.setTemplateIcon(id: id, key: "tent"))
        XCTAssertEqual(lib.icon(for: lib.resolvedTemplate(id: id)!), "tent")
        XCTAssertEqual(Library.icon(of: lib.resolvedTemplate(id: id)!), "tent", "a resolved template does not carry the choice")
        XCTAssertEqual(Library.icon(of: lib.resolvedTemplates()[0]), "tent")
        // Later edits save the whole template again — the choice must survive them.
        _ = lib.addToTemplate(templateId: id, name: "Headlamp")
        XCTAssertTrue(lib.renameTemplate(id: id, to: "Hiking & camping"))
        XCTAssertEqual(lib.chosenIcon(templateId: id), "tent", "an edit to the template lost the icon")
        // …and the stored records and a backup carry it.
        let back = Library(records: lib.records())
        XCTAssertEqual(back.chosenIcon(templateId: id), "tent", "the stored records lost the icon")
        let (restored, report) = Importer.library(from: lib.backupFile())
        XCTAssertTrue(report.isFaithful, "the backup does not come back the same: \(report.mismatches.prefix(3))")
        XCTAssertEqual(restored.chosenIcon(templateId: id), "tent", "a backup lost the icon")

        XCTAssertTrue(lib.setTemplateIcon(id: id, key: Library.letterIcon))
        XCTAssertNil(lib.icon(for: lib.resolvedTemplate(id: id)!), "letter means no icon")
        XCTAssertTrue(lib.setTemplateIcon(id: id, key: nil))
        XCTAssertEqual(lib.icon(for: lib.resolvedTemplate(id: id)!), "hiking", "back to the suggestion (the name says hiking first)")
        XCTAssertFalse(lib.setTemplateIcon(id: "nope", key: "tent"))
    }
}
