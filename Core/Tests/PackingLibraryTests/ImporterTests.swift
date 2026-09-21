import XCTest
import PackingCore
@testable import PackingLibrary

/// Invented data only — this repository is public.
final class ImporterTests: XCTestCase {

    override func setUp() { PackingEnv.freeze() }
    override func tearDown() {
        PackingEnv.reset()
        _ = setPhases(DEFAULT_PHASES)
        _ = setItemConditions(DEFAULT_ITEM_CONDITIONS)
    }

    /// A backup file as the web app writes one: resolved templates whose rows carry
    /// the ids of their item and membership.
    static func backup(of lib: Library, phases: [Phase] = [], prefs: JSONValue? = nil) -> BackupFile {
        var o: [String: JSONValue] = [
            "app": "ams-packing-list", "version": 2, "exportedAt": "2026-09-01T08:00:00.000Z",
            "lists": .array(lib.resolvedTemplates().map(\.json)),
            "events": .array(lib.trips.map(\.json)),
            "actions": [], "kits": [], "photos": [],
            "things": .array(lib.thingsOnNoList().map(\.json)),
            "phases": .array(phases.map(\.json)),
        ]
        if let prefs = prefs { o["prefs"] = prefs }
        return BackupFile(json: .object(o))
    }

    func testTheImportBringsBackEveryRowExactly() {
        let lib = LibraryTests.sample()
        let (got, report) = Importer.library(from: ImporterTests.backup(of: lib))
        XCTAssertEqual(report.mismatches, [])
        XCTAssertTrue(report.isFaithful)
        XCTAssertEqual(got.resolvedTemplates(), lib.resolvedTemplates())
        XCTAssertEqual(Set(got.items.map(\.id)), Set(lib.items.map(\.id)), "item ids survive: trip lines point at them")
        XCTAssertEqual(Set(got.memberships.map(\.id)), Set(lib.memberships.map(\.id)))
        XCTAssertEqual(report.items, 2)
        XCTAssertEqual(report.memberships, 4)
    }

    /// The web app's own replace-restore loses exactly these (it goes through
    /// `buildCatalog`). This import must not.
    func testWhatTheWebAppsRestoreLosesComesAcross() {
        var lib = LibraryTests.sample()
        let n = lib.items.firstIndex { $0.name == "Headlamp" }!
        lib.items[n].retired = true
        lib.items[n].retiredReason = "sold"
        lib.items[n].stats = ItemStats(packed: 4, used: 3, unused: 1, skipped: 0, lastReviewed: "2026-08-01")
        let file = ImporterTests.backup(of: lib)

        let (got, report) = Importer.library(from: file)
        let lamp = got.items.first { $0.name == "Headlamp" }!
        XCTAssertTrue(lamp.consumable)
        XCTAssertEqual(lamp.packer, "Anna")
        XCTAssertTrue(lamp.retired)
        XCTAssertEqual(lamp.retiredReason, "sold")
        XCTAssertEqual(lamp.stats.packed, 4)
        XCTAssertEqual(lamp.stats.lastReviewed, "2026-08-01")
        XCTAssertEqual(got.resolvedTemplates().flatMap(\.items).filter { $0.kit == "Light kit" }.count, 2)
        XCTAssertEqual(report.fragile, report.fragileAfter)
        XCTAssertEqual(report.fragile["reviewed"], 2, "the headlamp's history, counted once per row it sits on")

        // …and this is the loss being guarded against, shown on the same file:
        let rebuilt = buildCatalog(file.lists)
        XCTAssertEqual(rebuilt.items.first { $0.name == "Headlamp" }?.packer, "", "buildCatalog drops the packer — never import through it")
    }

    func testATripsLinesStillPointAtTheirThings() {
        let lib = LibraryTests.sample()
        let (got, _) = Importer.library(from: ImporterTests.backup(of: lib))
        let ids = Set(got.items.map(\.id))
        let lines = got.trips[0].entries
        XCTAssertFalse(lines.isEmpty)
        XCTAssertTrue(lines.allSatisfy { $0.sourceItemId.map(ids.contains) ?? false })
        // So regenerating the trip adds nothing and loses nothing.
        XCTAssertEqual(regenerateEntries(got.trips[0], got.resolvedTemplates()).count, lines.count)
    }

    func testNothingFactoryMadeIsEverStored() {
        let lib = LibraryTests.sample()
        let prefs: JSONValue = [
            "people": .array(defaultListFor("people")),
            "conditions": .array(defaultListFor("conditions")),
            "storageLocations": .array(defaultListFor("places")),
        ]
        let (got, report) = Importer.library(from: ImporterTests.backup(of: lib, phases: DEFAULT_PHASES, prefs: prefs))
        XCTAssertEqual(got.phases, [], "the factory timeline lives in the code")
        XCTAssertEqual(got.shared, [], "factory people, conditions and places live in the code")
        XCTAssertEqual(report.sharedRows, 0)
    }

    func testHisOwnTimelineAndListsAreStored() {
        let lib = LibraryTests.sample()
        var own = DEFAULT_PHASES
        own.append(newPhase("Load the van", own.map(\.id)))
        let prefs: JSONValue = ["storageLocations": ["Garage shelf", "Loft"], "owners": ["Anna", "Jonas"]]
        let (got, _) = Importer.library(from: ImporterTests.backup(of: lib, phases: own, prefs: prefs))
        XCTAssertEqual(got.phases.count, 8)
        XCTAssertEqual(orderedNamesFromRows(got.shared, "places"), ["Garage shelf", "Loft"])
        XCTAssertEqual(namesFromRows(got.shared, "owners"), ["Anna", "Jonas"])
    }

    func testTheImportLeavesItsMark() {
        let (got, _) = Importer.library(from: ImporterTests.backup(of: LibraryTests.sample()))
        XCTAssertEqual(got.meta["import"]?["exportedAt"]?.stringValue, "2026-09-01T08:00:00.000Z")
        XCTAssertEqual(got.meta["import"]?["items"]?.numberValue, 2)
        // And the mark survives the store.
        XCTAssertEqual(Library(records: got.records()).meta["import"], got.meta["import"])
    }

    func testAThingOnNoListComesAcross() {
        var lib = LibraryTests.sample()
        lib.items.append(newItem(name: "Snow shovel", storage: "Garage"))
        let (got, report) = Importer.library(from: ImporterTests.backup(of: lib))
        XCTAssertEqual(report.things, 1)
        XCTAssertEqual(got.thingsOnNoList().map(\.name), ["Snow shovel"])
        XCTAssertEqual(got.thingsOnNoList().first?.storage, "Garage")
    }
}
